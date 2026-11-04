import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import { JSDOM } from 'jsdom'
import { localDateTime, zonedInputSeconds, scheduleOccurrences } from './mooncode-calendar-runtime.js'
import { iconMarkup, setIconButton } from './ui-icons.js'
import { renderKnowledge, syncKnowledgeActions, captureKnowledgeDraft } from './mooncode-knowledge-runtime.js'
import { syncSetupActions } from './mooncode-setup-runtime.js'

const read = file => readFileSync(new URL(file, import.meta.url), 'utf8')
const tick = () => new Promise(resolve => setTimeout(resolve, 0))

function surfaceRuntime(file, exports) {
  const dom = new JSDOM('<main></main>', { url: 'http://localhost/?locale=zh-Hans', runScripts: 'outside-only' })
  const { window } = dom
  const requests = []
  window.fetch = (url, options) => new Promise(resolve => requests.push({ url, options, resolve }))
  Object.assign(window, { localDateTime, zonedInputSeconds, scheduleOccurrences, iconMarkup, setIconButton, syncKnowledgeActions, captureKnowledgeDraft, requestAnimationFrame: () => {} })
  const localeSource = read('./ui-locale.js').replaceAll('export ', '')
  let source = read(file).replace(/^import .*$/gm, '').replace(/export \{[\s\S]*?\}\s*$/m, '').replace(/^export /gm, '')
  if (file.includes('workspace-features')) source = source.slice(0, source.lastIndexOf("if (typeof document !== 'undefined')"))
  window.eval(`${localeSource}\n${source}\nwindow.surface = { ${exports} };`)
  return { dom, window, requests, api: window.surface }
}

test('calendar presents pending, error, retry and empty states in order', async () => {
  const h = surfaceRuntime('./book-calendar-runtime.js', 'renderBookCalendar')
  try {
    const root = h.api.renderBookCalendar({ workspace_id: 'calendar-test' })
    h.window.document.body.append(root)
    assert.equal(root.querySelector('[role="status"]').textContent, 'Loading calendar…')
    assert.equal(root.querySelector('.document-tool-empty'), null, 'pending is not an empty result')
    h.requests[0].resolve({ ok: false })
    await tick()
    assert.match(root.querySelector('[role="status"]').textContent, /could not be loaded/)
    assert.equal(root.querySelector('.document-tool-empty'), null)
    root.querySelector('button[aria-label="Refresh"]').click()
    assert.equal(h.requests.length, 2)
    h.requests[1].resolve({ ok: true, json: async () => ({ events: [] }) })
    await tick()
    assert.equal(root.querySelector('[role="status"]').textContent, '')
    assert.match(root.querySelector('.document-tool-empty').textContent, /No upcoming events/)
  } finally { h.dom.window.close() }
})

test('setup failure ends loading and refresh recovers without showing stale failure', async () => {
  const h = surfaceRuntime('./mooncode-setup-runtime.js', 'mount')
  try {
    const root = h.window.document.querySelector('main'); root.dataset.workspaceId = 'setup-retry'
    h.api.mount(root)
    assert.match(root.textContent, /Loading setup/)
    assert.equal(root.querySelector('[data-action="refresh"]').disabled, true)
    h.requests[0].resolve({ ok: false, json: async () => ({}) }); await tick()
    assert.doesNotMatch(root.textContent, /Loading setup/)
    assert.match(root.querySelector('[data-setup-status]').textContent, /could not be loaded/)
    root.querySelector('[data-action="refresh"]').click()
    assert.match(root.textContent, /Loading setup/)
    h.requests[1].resolve({ ok: true, json: async () => ({ skills: [], instructions: 'Saved instructions' }) }); await tick()
    assert.doesNotMatch(root.textContent, /Loading setup|could not be loaded/)
    assert.equal(root.querySelector('[data-setup-status]').dataset.error, 'false')
  } finally { h.dom.window.close() }
})

test('room refresh clears an error even when the successful payload is unchanged', async () => {
  const h = surfaceRuntime('./workspace-room-runtime.js', 'renderWorkspaceRoom')
  try {
    const root = h.api.renderWorkspaceRoom({ workspace_id: 'room-retry' }); h.window.document.body.append(root)
    const payload = { channels: [{ id: 'general', title: 'General' }], messages: [], presence: [] }
    h.requests[0].resolve({ ok: true, json: async () => payload }); await tick()
    root.querySelector('[aria-label="Refresh"]').click()
    assert.equal(root.querySelector('.document-tool-empty'), null)
    h.requests[1].resolve({ ok: false }); await tick()
    assert.match(root.querySelector('[role="status"]').textContent, /could not be loaded/)
    assert.equal(root.querySelector('.document-tool-empty'), null)
    root.querySelector('[aria-label="Refresh"]').click()
    h.requests[2].resolve({ ok: true, json: async () => payload }); await tick()
    assert.equal(root.querySelector('[role="status"]').textContent, '')
    assert.match(root.querySelector('.document-tool-empty').textContent, /No messages/)
    assert.equal(root.querySelector('[aria-label="Refresh"]').disabled, false)
  } finally { h.dom.window.close() }
})

test('room follows a channel selected during an earlier refresh without flashing emptiness', async () => {
  const h = surfaceRuntime('./workspace-room-runtime.js', 'renderWorkspaceRoom')
  try {
    const root = h.api.renderWorkspaceRoom({ workspace_id: 'room-channels' }); h.window.document.body.append(root)
    const payload = { channels: [{ id: 'general', title: 'General' }, { id: 'design', title: 'Design' }], messages: [], presence: [] }
    h.requests[0].resolve({ ok: true, json: async () => payload }); await tick()
    root.querySelector('[aria-label="Refresh"]').click()
    const design = [...root.querySelectorAll('button')].find(button => button.textContent === 'Design')
    design.click()
    assert.equal(root.querySelector('.document-tool-empty'), null)
    h.requests[1].resolve({ ok: true, json: async () => payload }); await tick()
    assert.match(h.requests[2].url, /channel=design/)
    assert.equal(root.querySelector('.document-tool-empty'), null)
    h.requests[2].resolve({ ok: true, json: async () => payload }); await tick()
    assert.equal([...root.querySelectorAll('button')].find(button => button.textContent === 'Design').getAttribute('aria-pressed'), 'true')
    assert.ok(root.querySelector('.document-tool-empty'))
  } finally { h.dom.window.close() }
})

test('background shell redraw retains local tool inputs, focus and scroll without reloading it', () => {
  const h = surfaceRuntime('./workspace-features-runtime.js', 'renderLocalTool, localToolPosition, restoreLocalToolPosition')
  try {
    const root = h.window.document.querySelector('main')
    let loads = 0
    const create = () => { loads++; const body = h.window.document.createElement('div'); body.append(h.window.document.createElement('input')); return body }
    const state = { workspace_id: 'book-a', selected_document: 'wiki/report.md' }
    const body = h.api.renderLocalTool(state, 'calendar', create); root.append(body)
    const input = body.querySelector('input'); input.value = 'Unsent event'; input.focus(); body.scrollTop = 240
    const position = h.api.localToolPosition()
    root.replaceChildren()
    root.append(h.api.renderLocalTool({ ...state, code_status: 'poll updated' }, 'calendar', create))
    h.api.restoreLocalToolPosition(position)
    assert.equal(loads, 1)
    assert.equal(h.window.document.activeElement, input)
    assert.equal(input.value, 'Unsent event')
    assert.equal(body.scrollTop, 240)
    root.replaceChildren(h.api.renderLocalTool({ workspace_id: 'book-b' }, 'calendar', create))
    h.api.restoreLocalToolPosition(position)
    assert.equal(loads, 2)
    assert.equal(root.querySelector('input').value, '')
  } finally { h.dom.window.close() }
})

test('document and workflow pickers keep file names and secondary actions local', () => {
  const h = surfaceRuntime('./workspace-features-runtime.js', 'renderSearch')
  try {
    for (const purpose of ['document', 'workflow']) {
      const panel = h.api.renderSearch({ purpose, mode: 'files', query: 'Skills', hits: [{ title: 'Skills', path: 'Skills', kind: 'text', workspace_name: 'Review', workspace_id: 'book' }] })
      assert.equal(panel.querySelector('.universal-search-modes'), null)
      assert.equal(panel.querySelector('.universal-result-pin'), null)
      assert.equal(panel.querySelector('.universal-result-main strong').dataset.i18nScope, 'content')
      assert.equal(panel.querySelector('.universal-result-main strong').textContent, 'Skills')
      assert.equal(panel.querySelector('.universal-search-more').open, false)
      assert.equal(panel.querySelector('.universal-search-more summary').getAttribute('aria-label'), 'More file actions')
    }
  } finally { h.dom.window.close() }
})

test('calendar requires a meaningful title and increasing times before saving', () => {
  const h = surfaceRuntime('./book-calendar-runtime.js', 'renderBookCalendar')
  try {
    const root = h.api.renderBookCalendar({ workspace_id: 'calendar-inputs' })
    Array.from(root.querySelectorAll('button')).find(button => button.textContent === 'New event').click()
    const [title, , start, end] = root.querySelectorAll('input')
    const submit = root.querySelector('button[type="submit"]')
    const input = (node, value) => { node.value = value; node.dispatchEvent(new h.window.Event('input')) }
    assert.equal(submit.disabled, true)
    input(title, '  ')
    assert.equal(submit.disabled, true)
    input(title, 'Review report')
    assert.equal(submit.disabled, false)
    input(end, start.value)
    assert.equal(submit.disabled, true)
    root.querySelector('form').dispatchEvent(new h.window.Event('submit', { cancelable: true }))
    assert.equal(h.requests.filter(request => request.options?.method === 'POST').length, 0)
    input(end, '2099-12-31T23:59')
    assert.equal(submit.disabled, false)
  } finally { h.dom.window.close() }
})

test('knowledge operations enable only when their matching field has content', () => {
  const dom = new JSDOM('<main></main>')
  try {
    const root = dom.window.document.querySelector('main')
    root.innerHTML = renderKnowledge({ workspaceId: 'book', data: { knowledge: [] } })
    syncKnowledgeActions(root)
    for (const action of ['knowledge-index', 'knowledge-save', 'knowledge-search']) assert.equal(root.querySelector(`[data-action="${action}"]`).disabled, true)
    root.querySelector('[name="knowledge-path"]').value = 'Skills/report.md'
    root.querySelector('[name="knowledge-query"]').value = '  '
    syncKnowledgeActions(root)
    assert.equal(root.querySelector('[data-action="knowledge-index"]').disabled, false)
    assert.equal(root.querySelector('[data-action="knowledge-search"]').disabled, true)
    root.querySelector('[name="knowledge-text"]').value = 'Original source text'
    root.querySelector('[name="knowledge-query"]').value = 'Find source'
    syncKnowledgeActions(root)
    assert.equal(root.querySelector('[data-action="knowledge-save"]').disabled, false)
    assert.equal(root.querySelector('[data-action="knowledge-search"]').disabled, false)
    assert.equal(root.querySelector('[name="knowledge-path"]').value, 'Skills/report.md')
  } finally { dom.window.close() }
})

test('empty schedules offer a working results action after loading completes', async () => {
  const h = surfaceRuntime('./task-schedule-runtime.js', 'renderTaskSchedules')
  try {
    let chosen = 0
    const el = (tag, className = '', text = '') => { const node = h.window.document.createElement(tag); node.className = className; node.textContent = text; return node }
    const root = h.api.renderTaskSchedules({ workspaceId: 'schedule-empty' }, { el, onChooseResult: () => { chosen++ } })
    h.window.document.body.append(root)
    assert.equal(root.querySelector('.document-tool-empty'), null)
    h.requests[0].resolve({ ok: true, json: async () => ({ schedules: [] }) })
    await tick()
    assert.equal(root.querySelector('.document-tool-empty').textContent, 'No scheduled work')
    Array.from(root.querySelectorAll('button')).find(button => button.textContent === 'View results').click()
    assert.equal(chosen, 1)
  } finally { h.dom.window.close() }
})

test('a schedule exposes its last run only when it has a conversation to open', async () => {
  const h = surfaceRuntime('./task-schedule-runtime.js', 'renderTaskSchedules')
  try {
    h.window.localStorage.setItem('moondesk.task-schedules.v1', JSON.stringify({ missing: { title: 'Missing' }, valid: { title: 'Valid' } }))
    const opened = []
    const el = (tag, className = '', text = '') => { const node = h.window.document.createElement(tag); node.className = className; node.textContent = text; return node }
    const root = h.api.renderTaskSchedules({ workspaceId: 'run-links' }, { el, onOpenRun: id => opened.push(id) })
    h.requests[0].resolve({ ok: true, json: async () => ({ schedules: [
      { id: 'missing', book_id: 'run-links', last_command_id: 'command-a', session_id: '', next_due_at: 1 },
      { id: 'valid', book_id: 'run-links', last_command_id: 'command-b', session_id: 'chat-b', next_due_at: 1 },
    ] }) })
    await tick()
    const links = [...root.querySelectorAll('button')].filter(button => button.textContent === 'Open last run')
    assert.equal(links.length, 1)
    links[0].click()
    assert.deepEqual(opened, ['chat-b'])
  } finally { h.dom.window.close() }
})

test('room shows initial loading and preserves authored messages after load', async () => {
  const h = surfaceRuntime('./workspace-room-runtime.js', 'renderWorkspaceRoom')
  try {
    const root = h.api.renderWorkspaceRoom({ workspace_id: 'room-test' })
    h.window.document.body.append(root)
    assert.equal(root.querySelector('[role="status"]').textContent, 'Loading book room…')
    assert.equal(root.querySelector('.document-tool-empty'), null)
    h.requests[0].resolve({ ok: true, json: async () => ({ channels: [], presence: [], messages: [{ id: 'one', author: 'Review', text: 'Results', created_at: 1 }] }) })
    await tick()
    assert.equal(root.querySelector('[role="status"]').textContent, '')
    assert.deepEqual([...root.querySelectorAll('.workspace-room-message [data-i18n-scope="content"]')].map(node => node.textContent), ['Review', 'Results'])
  } finally { h.dom.window.close() }
})

test('room send and channel creation require a name and meaningful input', async () => {
  const h = surfaceRuntime('./workspace-room-runtime.js', 'renderWorkspaceRoom')
  try {
    const root = h.api.renderWorkspaceRoom({ workspace_id: 'room-input-test' })
    h.window.document.body.append(root)
    h.requests[0].resolve({ ok: true, json: async () => ({ channels: [], presence: [], messages: [] }) }); await tick()
    const submit = root.querySelector('.workspace-room-compose-actions button')
    const create = root.querySelector('.workspace-room-new-channel button')
    assert.equal(submit.disabled, true)
    assert.equal(create.disabled, true)
    const name = root.querySelector('.workspace-room-profile input')
    name.value = 'Local reviewer'; name.dispatchEvent(new h.window.Event('input'))
    const body = root.querySelector('textarea')
    body.value = '  '; body.dispatchEvent(new h.window.Event('input'))
    assert.equal(submit.disabled, true)
    body.value = 'An unsent question'; body.dispatchEvent(new h.window.Event('input'))
    assert.equal(submit.disabled, false)
    const channel = root.querySelector('.workspace-room-new-channel input')
    channel.value = 'Review'; channel.dispatchEvent(new h.window.Event('input'))
    assert.equal(create.disabled, false)
    assert.ok(h.requests.slice(1).every(request => JSON.parse(request.options.body).action === 'presence'), 'typing never posts a message or creates a channel')
  } finally { h.dom.window.close() }
})

test('preference load failure remains stable until explicit Refresh', async () => {
  const h = surfaceRuntime('./workspace-features-runtime.js', 'featureState, renderPreferencesTab, setWorkspace: id => { serverState.workspace_id = id }, attach: () => { render = () => document.body.replaceChildren(renderPreferencesTab()); render() }')
  try {
    h.api.setWorkspace('preference-test')
    h.api.attach()
    assert.equal(h.api.featureState.preferences_status, 'Loading preferences…')
    h.requests[0].resolve({ ok: false })
    await tick()
    await tick()
    assert.equal(h.requests.length, 1, 'failure must not cause a render/retry loop')
    assert.equal(h.api.featureState.preferences_status, 'Preferences could not be loaded')
    h.window.document.querySelector('button[aria-label="Refresh"]').click()
    assert.equal(h.requests.length, 2)
    h.requests[1].resolve({ ok: true, json: async () => ({ preferences: [] }) })
    await tick()
    assert.equal(h.api.featureState.preferences_status, '')
    assert.equal(h.window.document.querySelector('select[aria-label="Preference type"]').value, 'preference')
  } finally { h.dom.window.close() }
})

test('preference inputs survive redraws and remain scoped to their book without saving', async () => {
  const h = surfaceRuntime('./workspace-features-runtime.js', 'featureState, setWorkspace: id => { serverState.workspace_id = id }, draw: () => { render = () => document.body.replaceChildren(renderPreferencesTab()); render() }')
  try {
    h.api.setWorkspace('draft-A'); h.api.draw()
    h.requests[0].resolve({ ok: true, json: async () => ({ preferences: [] }) }); await tick()
    const input = h.window.document.querySelector('.agent-preference-form input')
    const detail = h.window.document.querySelector('.agent-preference-form textarea')
    const save = h.window.document.querySelector('button[type="submit"]')
    assert.equal(save.disabled, true)
    input.value = 'Skills'; input.dispatchEvent(new h.window.Event('input', { bubbles: true }))
    detail.value = '  '; detail.dispatchEvent(new h.window.Event('input', { bubbles: true }))
    assert.equal(save.disabled, true)
    detail.value = 'Keep filenames intact'; detail.dispatchEvent(new h.window.Event('input', { bubbles: true }))
    assert.equal(save.disabled, false)
    h.api.draw()
    assert.equal(h.window.document.querySelector('input').value, 'Skills')
    h.api.setWorkspace('draft-B'); h.api.draw()
    assert.equal(h.window.document.querySelector('input').value, '')
    h.requests[1].resolve({ ok: true, json: async () => ({ preferences: [] }) }); await tick()
    h.api.setWorkspace('draft-A'); h.api.draw()
    assert.equal(h.window.document.querySelector('textarea').value, 'Keep filenames intact')
    assert.equal(h.requests.length, 3, 'only the expected book reads occurred')
    assert.ok(h.requests.every(request => String(request.url).includes('/api/preferences/agent-memory?')))
  } finally { h.dom.window.close() }
})

test('setup save actions require the corresponding fields and allow clearing instructions', () => {
  const dom = new JSDOM(`<input name="prompt-name"><textarea name="prompt-text"></textarea><button data-action="save-template"></button>
    <input name="preset-name"><select name="preset-model"><option value="model">Model</option></select><button data-action="save-preset"></button>
    <textarea name="instructions"></textarea><button data-action="save-instructions"></button>`)
  try {
    const root = dom.window.document.body
    syncSetupActions(root)
    assert.equal(root.querySelector('[data-action="save-template"]').disabled, true)
    assert.equal(root.querySelector('[data-action="save-preset"]').disabled, true)
    assert.equal(root.querySelector('[data-action="save-instructions"]').disabled, false)
    root.querySelector('[name="prompt-name"]').value = 'Review'
    root.querySelector('[name="prompt-text"]').value = '  '
    syncSetupActions(root)
    assert.equal(root.querySelector('[data-action="save-template"]').disabled, true)
    root.querySelector('[name="prompt-text"]').value = 'Review the diff'
    root.querySelector('[name="preset-name"]').value = 'Careful'
    syncSetupActions(root)
    assert.equal(root.querySelector('[data-action="save-template"]').disabled, false)
    assert.equal(root.querySelector('[data-action="save-preset"]').disabled, false)
  } finally { dom.window.close() }
})
