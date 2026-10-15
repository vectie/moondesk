import { taskArtifacts } from './work-journey-runtime.js'
import { taskScheduleBindings, linkedScheduleResults } from './task-schedule-runtime.js'
// A result keeps its output files and conversation together after work finishes.
const views = new Map()
const receiptsKey = 'moondesk.result-inbox.read.v1'

function resultTimestamp(value) {
  if (/^\d+$/.test(String(value || ''))) {
    const number = Number(value)
    return number < 100_000_000_000 ? number * 1000 : number
  }
  return Date.parse(value || '') || 0
}

function resultBundles(state = {}, threads = [], background = [], codeSchedules = []) {
  const work = Array.isArray(state.work) ? state.work : []
  const bundles = new Map()
  for (const run of work.filter(item => item.type === 'run')) {
    const artifacts = work.filter(item => item.type === 'artifact' && item.run_id === run.run_id)
      .map(item => ({ title: item.title || item.path, path: item.path }))
    bundles.set(`run:${run.run_id}`, {
      id: `run:${run.run_id}`, run_id: run.run_id, title: run.title || 'Completed work',
      summary: run.detail || '', status: run.status || 'completed', phase: run.phase || '',
      artifacts, conversation_id: '', created_at: run.created_at || '',
      attention: /fail|error|review|blocked/i.test(run.status || ''),
    })
  }
  const results = [...background]
  for (const thread of threads) {
    const artifacts = taskArtifacts({ chat: (thread.chat || []).filter(entry => entry.role === 'artifact_ref') })
    if (artifacts.length) {
      const linked = [...bundles.values()].find(bundle => bundle.artifacts.some(file => artifacts.some(artifact => artifact.path === file.path)))
      if (linked) linked.conversation_id = thread.id
      else bundles.set(`task:${thread.id}`, {
        id: `task:${thread.id}`, title: thread.title || 'Task output', summary: '',
        artifacts, conversation_id: thread.id, status: 'Ready', created_at: thread.updated_at,
      })
    }
    for (const entry of thread.chat || []) {
      if (entry.role !== 'background_result') continue
      try { results.push({ ...JSON.parse(entry.content), conversation_id: thread.id }) } catch {}
    }
  }
  for (const result of results) {
    const key = result.run_id ? `run:${result.run_id}` : `background:${result.id}`
    const previous = bundles.get(key)
    const paths = new Map((previous?.artifacts || []).map(item => [item.path, item]))
    if (result.path) paths.set(result.path, { path: result.path, title: result.path.split('/').pop() })
    for (const path of result.output_paths || []) paths.set(path, { path, title: path.split('/').pop() })
    bundles.set(key, {
      ...previous, id: key, run_id: result.run_id || '',
      title: previous?.title || result.summary || 'Scheduled work',
      summary: result.summary || previous?.summary || '', status: result.decision || previous?.status || 'Completed',
      conversation_id: result.conversation_id || previous?.conversation_id || '',
      code_session_id: result.code_session_id || '',
      conversation_kind: result.conversation_kind || '',
      document_path: result.document_path || '', artifacts: [...paths.values()],
      created_at: result.created_at || previous?.created_at || '',
      attention: Boolean(result.warning || previous?.attention),
    })
  }
  for (const schedule of codeSchedules) {
    if (!Number(schedule.last_finished_at)) continue
    if (results.some(result => result.goal_id === schedule.id)) continue
    const key = `code:${schedule.id}:${schedule.last_command_id}`
    bundles.set(key, {
      id: key, run_id: schedule.last_command_id, title: schedule.title || schedule.id,
      summary: schedule.prompt, status: schedule.last_status, artifacts: [],
      conversation_id: schedule.session_id, conversation_kind: 'code',
      created_at: new Date(Number(schedule.last_finished_at) * 1000).toISOString(),
      attention: schedule.last_status === 'failed',
    })
  }
  return [...bundles.values()].map(bundle => ({
    ...bundle,
    // Reading an earlier result does not hide a newer outcome for the same run.
    revision: JSON.stringify([bundle.status, bundle.summary, bundle.artifacts, bundle.created_at]),
  })).sort((a, b) => resultTimestamp(b.created_at) - resultTimestamp(a.created_at))
}

function filterResultBundles(bundles, filter, query, receipts = {}) {
  const needle = query.toLocaleLowerCase().trim()
  return bundles.filter(bundle =>
    (filter !== 'unread' || receipts[bundle.id] !== bundle.revision) &&
    (filter !== 'attention' || bundle.attention) &&
    (!needle || [bundle.title, bundle.summary, ...bundle.artifacts.map(item => item.path)].join(' ').toLocaleLowerCase().includes(needle)))
}

function el(tag, className = '', text = '') {
  const node = document.createElement(tag)
  node.className = className
  node.textContent = text
  return node
}

function action(label, onClick) {
  const button = el('button', 'secondary-button', label)
  button.type = 'button'
  button.addEventListener('click', onClick)
  return button
}

function renderResultInbox(state, options = {}) {
  const key = state.workspace_id || ''
  let view = views.get(key)
  if (!view) {
    view = { filter: 'all', query: '', background: [], codeSchedules: [], loaded: false, loading: false, error: '' }
    views.set(key, view)
  }
  const root = el('div', 'document-tool-content result-inbox')
  root.dataset.testid = 'result-inbox'
  let receipts = {}
  try { receipts = JSON.parse(localStorage.getItem(receiptsKey) || '{}')[key] || {} } catch {}
  const mark = bundle => {
    receipts[bundle.id] = bundle.revision
    try {
      const all = JSON.parse(localStorage.getItem(receiptsKey) || '{}')
      all[key] = receipts
      localStorage.setItem(receiptsKey, JSON.stringify(all))
    } catch {}
  }
  const load = async () => {
    if (!key || view.loading) return
    view.loading = true
    view.error = ''
    draw()
    try {
      const [documents, code] = await Promise.allSettled([
        fetch(`/api/document-automation-results?workspace_id=${encodeURIComponent(key)}`),
        fetch('/api/mooncode/schedules'),
      ])
      if (code.status === 'fulfilled' && code.value.ok) {
        const payload = await code.value.json()
        view.codeSchedules = (payload.schedules || []).filter(schedule => schedule.book_id === key)
      }
      if (documents.status !== 'fulfilled') throw new Error('load failed')
      const response = documents.value
      if (!response.ok) throw new Error('load failed')
      const payload = await response.json()
      view.background = Array.isArray(payload.results) ? payload.results : []
      view.loaded = true
    } catch { view.error = 'Scheduled results could not be loaded. Your existing work is still available.' }
    view.loading = false
    draw()
  }
  const draw = () => {
    root.replaceChildren()
    const bundles = resultBundles(state, options.threads, [...view.background, ...linkedScheduleResults(view.codeSchedules, taskScheduleBindings(), key)], view.codeSchedules)
    const unread = bundles.filter(bundle => receipts[bundle.id] !== bundle.revision).length
    const header = el('div', 'document-tool-intro with-action')
    const copy = el('div')
    copy.append(el('p', '', `${unread} unread`))
    const refresh = action(view.loading ? 'Refreshing…' : 'Refresh', load)
    refresh.disabled = view.loading
    header.append(copy, refresh)
    const controls = el('div', 'result-inbox-controls')
    for (const [id, label] of [['all', 'All results'], ['unread', 'Unread'], ['attention', 'Needs attention']]) {
      const button = action(label, () => { view.filter = id; draw() })
      button.setAttribute('aria-pressed', String(view.filter === id))
      controls.append(button)
    }
    const search = el('input')
    search.type = 'search'
    search.placeholder = 'Find a result or file'
    search.setAttribute('aria-label', 'Find a result or file')
    search.value = view.query
    search.addEventListener('change', () => { view.query = search.value; draw() })
    controls.append(search)
    root.append(header, controls)
    const status = el('p', 'status-line', view.error || (view.loading ? 'Loading scheduled results…' : ''))
    status.setAttribute('role', 'status')
    root.append(status)
    const visible = filterResultBundles(bundles, view.filter, view.query, receipts)
    if (!visible.length) root.append(el('p', 'document-tool-empty', bundles.length ? 'No results match this view.' : 'Completed work and scheduled results will appear here with their output files.'))
    for (const bundle of visible) {
      const row = el('article', `result-bundle${bundle.attention ? ' needs-attention' : ''}`)
      const heading = el('div', 'result-bundle-heading')
      heading.append(el('h4', '', bundle.title), el('span', '', `${receipts[bundle.id] !== bundle.revision ? 'Unread · ' : ''}${bundle.status}`))
      row.append(heading, el('p', '', bundle.summary))
      if (resultTimestamp(bundle.created_at)) row.append(el('small', '', new Date(resultTimestamp(bundle.created_at)).toLocaleString()))
      for (const file of bundle.artifacts) row.append(action(file.title || file.path, () => { mark(bundle); options.openFile?.(file.path, bundle) }))
      const actions = el('div', 'result-bundle-actions')
      if (bundle.artifacts.length && options.revise) actions.append(action('Revise', () => options.revise(bundle)))
      if (bundle.artifacts.length && options.downloadFile) actions.append(action('Download output', () => options.downloadFile(bundle.artifacts[0])))
      if (options.schedule && bundle.conversation_id) actions.append(action('Schedule…', () => options.schedule(bundle)))
      if (bundle.conversation_id) actions.append(action('Open conversation', () => {
        mark(bundle)
        if (bundle.conversation_kind === 'code') {
          const url = new URL(globalThis.location.href)
          for (const name of [...url.searchParams.keys()]) if (name.startsWith('work_') || ['command', 'book_root', 'return_to', 'path'].includes(name)) url.searchParams.delete(name)
          url.searchParams.set('activity', 'code'); url.searchParams.set('workspace', key); url.searchParams.set('session', bundle.conversation_id)
          globalThis.location.assign(url)
        } else options.openConversation?.(bundle.conversation_id)
      }))
      actions.append(action('View work', () => { mark(bundle); options.openWork?.(bundle) }))
      if (bundle.code_session_id) actions.append(action('Open run', () => options.openCodeSession?.(bundle.code_session_id)))
      actions.append(action('Add to task', () => globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: {
        kind: 'result', label: bundle.title, workspaceId: key,
        text: [bundle.summary, ...bundle.artifacts.map(file => file.path)].join('\n'),
      } }))))
      actions.append(action('Export result', () => options.exportBundle?.(bundle)))
      if (receipts[bundle.id] !== bundle.revision) actions.append(action('Mark read', () => { mark(bundle); draw() }))
      row.append(actions)
      root.append(row)
    }
  }
  draw()
  if (!view.loaded && !view.loading && !view.error) void load()
  return root
}

export { resultTimestamp, resultBundles, filterResultBundles, renderResultInbox }
