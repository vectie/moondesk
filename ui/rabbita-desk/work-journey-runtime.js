const panelGroups = [
  [['review', 'Review'], ['sources', 'Sources'], ['history', 'History'], ['packs', 'Checks']],
  [['results', 'Results'], ['artifacts', 'Artifacts'], ['schedules', 'Schedules']],
  [['threads', 'Recent tasks']],
  [['room', 'Book room']], [['calendar', 'Calendar']], [['inbox', 'Inbox']],
  [['learning', 'Learning']], [['preferences', 'Preferences']], [['tasks', 'Start a task']],
]

export function workPanelItems(active) {
  return panelGroups.find(group => group.some(([id]) => id === active)) || panelGroups[0]
}

export const codingTaskPresets = [
  { id: 'fix-bug', title: 'Fix a bug', prompt: 'Investigate and fix this bug. Reproduce the issue, make a focused change, and verify the result.\n\nBug: ' },
  { id: 'build-feature', title: 'Build a feature', prompt: 'Implement this feature. Follow the existing product and code conventions, then show the result and verify the main user journey.\n\nFeature: ' },
  { id: 'review-code', title: 'Review code', prompt: 'Review the code for actionable correctness and product issues. Explain findings with file locations and suggested fixes.\n\nScope: ' },
]

export function taskDraft(prompt, kind, title = '') {
  const text = String(prompt || '').trim()
  return { prompt: text, kind: kind === 'code' ? 'code' : 'document', title: title || text.split('\n')[0].slice(0, 72) }
}

// The server owns the conversation. The desktop remembers where the user left
// it, including an unsent draft, without replacing newer server messages.
export function mergeTaskThreads(remote, local) {
  const saved = new Map(local.map(thread => [thread.id, thread]))
  const merged = remote.map(thread => ({ ...thread, position: saved.get(thread.id)?.position || thread.position }))
  const ids = new Set(merged.map(thread => thread.id))
  return [...merged, ...local.filter(thread => !ids.has(thread.id))]
    .sort((a, b) => Number(b.position?.updated_at || b.updated_at) - Number(a.position?.updated_at || a.updated_at))
}

export function taskPosition(state, previous = {}) {
  return {
    ...previous,
    title: state.work_title || previous.title || '',
    prompt: state.request_prompt || '',
    status: state.request_status || 'ready', cursor: state.chat_revision || 'start',
    files: state.task_files || [], context: state.task_context || [],
    materials: state.task_materials || [],
    directory: state.current_directory || '', filter: state.directory_filter || '',
    document: state.selected_document || '',
  }
}

export function taskArtifacts(thread) {
  const files = new Map()
  for (const entry of thread?.chat || []) {
    if (!['artifact_ref', 'background_result'].includes(entry.role)) continue
    try {
      const value = JSON.parse(entry.content)
      const path = value.workspace_path || value.path
      if (path) files.set(path, { path, title: value.label || value.title || path.split('/').pop() })
      for (const output of value.output_paths || []) files.set(output, { path: output, title: output.split('/').pop() })
    } catch {}
  }
  return [...files.values()]
}

export function taskSources(thread) {
  const sources = new Map((thread?.position?.files || []).map(path => [path, { path, title: path.split('/').pop(), kind: 'workspace' }]))
  for (const entry of thread?.chat || []) {
    if (entry.role !== 'source_ref') continue
    try {
      const value = JSON.parse(entry.content)
      const path = value.workspace_path || value.path || value.url
      if (path) sources.set(path, { path, title: value.label || path.split('/').pop(), kind: value.url ? 'web' : 'workspace' })
    } catch {}
  }
  return [...sources.values()]
}

export function taskResultPackage(state, bundle, thread) {
  return {
    contract: 'moondesk.work-package.v1', title: bundle.title,
    workspace: state.workspace || '', selected_document: bundle.artifacts[0]?.path || thread?.document || '',
    chat: thread?.chat || [], conversations: thread ? [thread] : [], runs: [bundle],
    sources: taskSources(thread),
    reviews: [], warnings: [],
  }
}

export function taskFileUrl(workspaceId, path) {
  return `/api/workspaces/${encodeURIComponent(workspaceId)}/file/${String(path).split('/').map(encodeURIComponent).join('/')}`
}

export async function downloadTaskFile(workspaceId, file) {
  const response = await fetch(taskFileUrl(workspaceId, file.path))
  if (!response.ok) throw new Error('This output could not be downloaded. Try again.')
  const url = URL.createObjectURL(await response.blob())
  const link = document.createElement('a')
  link.href = url; link.download = file.path.split('/').pop() || file.title || 'output'
  document.body.append(link); link.click()
  setTimeout(() => { link.remove(); URL.revokeObjectURL(url) }, 1000)
}

export function renderTaskDraft({ draft, workspace, onContinue, onPreset, el }) {
  const form = el('form', 'task-start-form')
  const label = el('label', '', 'What do you want to produce?')
  const input = el('textarea')
  input.name = 'goal'; input.rows = 3; input.value = draft.prompt || ''
  input.placeholder = 'Describe a result, a change, or a question…'
  label.append(input)
  const tools = el('div', 'task-start-controls')
  const mode = el('select')
  mode.setAttribute('aria-label', 'Working view')
  for (const [value, text] of [['document', 'Book · documents & research'], ['code', 'Code · software']]) {
    const option = el('option', '', text); option.value = value; mode.append(option)
  }
  mode.value = draft.kind || 'document'
  const next = el('button', 'primary-button', 'Continue')
  next.type = 'submit'; next.disabled = !workspace || !input.value.trim()
  input.addEventListener('input', () => { draft.prompt = input.value; next.disabled = !workspace || !input.value.trim() })
  mode.addEventListener('change', () => { draft.kind = mode.value })
  tools.append(mode, next)
  form.append(label, tools)
  form.addEventListener('submit', event => {
    event.preventDefault()
    if (!next.disabled) onContinue(taskDraft(input.value, mode.value, draft.title))
  })
  const presets = el('div', 'task-start-presets')
  for (const preset of codingTaskPresets) {
    const button = el('button', 'task-start-preset', preset.title)
    button.type = 'button'; button.addEventListener('click', () => onPreset(preset))
    presets.append(button)
  }
  const root = el('div', 'task-start-draft')
  root.append(form, presets)
  return root
}

// Pack apps run within a persistent host surface, so their own navigation does
// not replace the user's MoonDesk conversation or its drafts.
export function installPackWorkspace({ onResults, onAttach, getOrigin, onReturn, onImport }) {
  let surface = null
  let opener = null
  const close = () => {
    surface?.remove(); surface = null
    opener?.focus(); opener = null
  }
  document.addEventListener('click', event => {
    const link = event.target.closest?.('a[data-testid="pack-open"], a[data-testid="template-start"]')
    if (!link || event.metaKey || event.ctrlKey || event.shiftKey || event.altKey || event.button !== 0) return
    const url = new URL(link.href, location.href)
    if (url.origin !== location.origin || !url.pathname.startsWith('/pack-apps/')) return
    event.preventDefault()
    close(); opener = link
    const origin = getOrigin?.()
    const book = document.querySelector('.work-book-switcher summary > span:not(.moon-icon)')?.textContent || 'MoonBook'
    const title = link.getAttribute('aria-label')?.replace(/^Open /, '') || link.closest('article')?.querySelector('h2,h3')?.textContent || 'App'
    const el = (tag, text = '') => { const node = document.createElement(tag); node.textContent = text; return node }
    surface = el('section'); surface.className = 'pack-app-workspace'; surface.setAttribute('aria-label', title)
    const header = el('header')
    const back = el('button', '← Packs'); back.type = 'button'; back.setAttribute('aria-label', 'Back to Packs'); back.addEventListener('click', close)
    const identity = el('strong', title); identity.title = title
    const context = el('span', origin?.title || book)
    context.title = `${book} · ${origin?.title || 'New task'}`
    const returnTask = el('button', 'Return to task'); returnTask.type = 'button'; returnTask.addEventListener('click', () => { close(); onReturn?.(origin) })
    const attach = el('button', 'Attach file…'); attach.type = 'button'; attach.title = 'Return to this book and choose a saved output'; attach.addEventListener('click', () => { close(); onAttach() })
    const results = el('button', 'Results'); results.type = 'button'; results.addEventListener('click', () => { close(); onResults() })
    const external = el('a', '↗'); external.href = url.href; external.target = '_blank'; external.rel = 'noopener'; external.setAttribute('aria-label', `Open ${title} in a separate window`)
    header.append(back, identity, context, returnTask, attach, results, external)
    const frame = el('iframe'); frame.src = url.href; frame.title = title
    surface.append(header, frame); document.body.append(surface)
    if (url.pathname.includes('/moonfish/')) {
      attach.textContent = 'Use output…'
      const oldAttach = attach.cloneNode(true)
      attach.replaceWith(oldAttach)
      oldAttach.addEventListener('click', async () => {
        const host = surface
        host.querySelector('.pack-output-picker')?.remove()
        const picker = el('section'); picker.className = 'pack-output-picker'; picker.setAttribute('aria-label', 'App outputs')
        const status = el('p', 'Loading outputs…'); status.setAttribute('role', 'status')
        picker.append(status); host.append(picker)
        try {
          const api = new URL('apps/moonfish/api/v1/', url)
          const response = await fetch(new URL('bootstrap', api))
          if (!response.ok) throw new Error('Outputs could not be loaded. Try again.')
          const payload = await response.json()
          const files = (payload.files || []).filter(file => file.kind === 'export').sort((a, b) => String(b.created || '').localeCompare(String(a.created || '')))
          let currentIds = new Set()
          try { currentIds = new Set([...frame.contentDocument.querySelectorAll('.answer-result-file[data-preview-file]')].map(button => button.dataset.previewFile)) } catch {}
          const current = files.filter(file => currentIds.has(file.id))
          status.textContent = files.length ? (current.length ? 'This conversation’s outputs' : 'Recent outputs') : 'No outputs yet. Create a result in the app first.'
          const search = el('input'); search.type = 'search'; search.placeholder = 'Find an output'; search.setAttribute('aria-label', 'Find an app output')
          const list = el('div'); let showAll = !current.length; let limit = 20
          picker.append(search, list)
          const draw = () => {
            list.replaceChildren()
            const query = search.value.toLocaleLowerCase().trim()
            const matches = (query || showAll ? files : current).filter(file => !query || file.name.toLocaleLowerCase().includes(query))
            for (const file of matches.slice(0, limit)) {
            const use = el('button', file.name || file.id); use.type = 'button'
            use.title = `${file.name} · ${file.created || ''}`
            use.addEventListener('click', async () => {
              use.disabled = true; status.textContent = 'Adding to task…'
              try {
                const download = await fetch(new URL(`files/${encodeURIComponent(file.id)}`, api))
                if (!download.ok) throw new Error('This output could not be read.')
                const blob = await download.blob()
                const content = await new Promise((resolve, reject) => {
                  const reader = new FileReader(); reader.onload = () => resolve(reader.result); reader.onerror = reject; reader.readAsDataURL(blob)
                })
                if (surface !== host) return
                await onImport(origin, { name: file.name, media_type: blob.type, content })
                if (surface === host) close()
              } catch (error) { status.textContent = error.message || 'The output could not be added. Try again.'; use.disabled = false }
            })
            list.append(use)
            }
            if (matches.length > limit) { const more = el('button', 'Show more'); more.type = 'button'; more.onclick = () => { limit += 20; draw() }; list.append(more) }
          }
          search.oninput = () => { limit = 20; draw() }
          if (current.length) { const all = el('button', 'Browse all outputs'); all.type = 'button'; all.onclick = () => { showAll = true; status.textContent = 'Recent outputs'; all.remove(); draw() }; picker.append(all) }
          draw()
        } catch (error) { status.textContent = error.message }
        const cancel = el('button', 'Close'); cancel.type = 'button'; cancel.addEventListener('click', () => picker.remove()); picker.append(cancel)
      })
    }
  })
  document.addEventListener('click', event => {
    if (event.target.closest?.('.primary-nav-desktop button, .primary-nav-compact-menu button, .work-book-option, .work-shortcuts button')) close()
    if (event.target.closest?.('.work-book-option, .work-tools-options button')) {
      event.target.closest('details')?.removeAttribute('open')
    }
  })
  document.addEventListener('keydown', event => { if (event.key === 'Escape' && surface) close() })
}
