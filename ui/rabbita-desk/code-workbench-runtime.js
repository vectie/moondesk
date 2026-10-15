// Presentation state only. Submitted context travels through the ordinary
// MoonClaw command, so this module never owns conversation or execution state.
const drafts = new Map()
const pending = new Map()
const promptDrafts = new Map()
let lastSelection = null
let historyCursor = -1
let historyDraft = ''
let scheduled = false
let pendingNavigationDraft = null
let pendingTaskDraft = null
let pendingContext = null
let announcementTimer = null
const VIEWS = ['source', 'review', 'browser', 'terminal', 'compare']

// The conversation is the starting surface. A tool becomes a side pane only
// when there is enough room to keep both columns useful.
export function initialWorkbenchLayout(stored = {}) {
  return {
    view: VIEWS.includes(stored.view) ? stored.view : 'source',
    focus: stored.focus === 'split' ? 'split' : 'chat',
  }
}

function syncNavigation(surface) {
  const shell = surface.closest('.code-main')
  if (!shell) return
  const stored = readStored('moondesk.code-navigation', null)
  const open = stored === null ? window.matchMedia('(min-width: 1100px)').matches : stored === true
  shell.dataset.navigation = open ? 'open' : 'closed'
  const rail = shell.querySelector('.mooncode-rail')
  if (rail) rail.id = 'code-chat-navigation'
  surface.querySelector('[data-workbench-action="navigation"]')?.setAttribute('aria-expanded', String(open))
}

// Arrow keys activate adjacent tabs; Tab leaves the tablist for its panel.
// Workbench and file tabs share this behavior without intercepting editor keys.
export function navigateTabList(event, tabs, activate) {
  if (event.altKey || event.ctrlKey || event.metaKey || event.shiftKey || event.isComposing) return false
  const enabled = [...tabs].filter(tab => !tab.disabled)
  const current = enabled.indexOf(event.target)
  if (current < 0 || !enabled.length) return false
  let next
  if (event.key === 'ArrowRight') next = (current + 1) % enabled.length
  else if (event.key === 'ArrowLeft') next = (current + enabled.length - 1) % enabled.length
  else if (event.key === 'Home') next = 0
  else if (event.key === 'End') next = enabled.length - 1
  else return false
  event.preventDefault()
  const tab = enabled[next]
  activate(tab)
  tab.focus({ preventScroll: true })
  tab.scrollIntoView?.({ block: 'nearest', inline: 'nearest' })
  return true
}

function syncPanelTabs(surface) {
  const view = surface.dataset.workbenchView || 'source'
  const panelOpen = surface.dataset.workbenchFocus === 'split'
  for (const tab of surface.querySelectorAll('button[data-workbench-view]')) {
    const active = tab.dataset.workbenchView === view
    tab.setAttribute('role', panelOpen ? 'tab' : 'button')
    if (panelOpen) {
      tab.setAttribute('aria-selected', String(active))
      tab.removeAttribute('aria-expanded')
    } else {
      tab.removeAttribute('aria-selected')
      tab.setAttribute('aria-expanded', 'false')
    }
    tab.removeAttribute('aria-pressed')
    tab.tabIndex = !panelOpen || active ? 0 : -1
  }
  surface.querySelector('.code-workbench-tabs')?.setAttribute('role', panelOpen ? 'tablist' : 'group')
  const panel = surface.querySelector('.code-workbench-work')
  if (panel) {
    panel.id = 'code-workbench-panel'
    panel.setAttribute('role', 'tabpanel')
    panel.setAttribute('aria-labelledby', `code-workbench-tab-${view}`)
    panel.tabIndex = 0
  }
  const fileTabs = [...surface.querySelectorAll('.source-editor-tab-select')]
  for (const tab of fileTabs) {
    tab.id = `source-buffer-${encodeURIComponent(tab.dataset.testid || '')}`
    tab.tabIndex = tab.getAttribute('aria-selected') === 'true' ? 0 : -1
  }
  const activeFile = fileTabs.find(tab => tab.getAttribute('aria-selected') === 'true')
  const sourcePanel = surface.querySelector('.source-editor-workbench')
  if (sourcePanel && activeFile) {
    sourcePanel.id = 'source-buffer-panel'
    sourcePanel.setAttribute('role', 'tabpanel')
    sourcePanel.setAttribute('aria-labelledby', activeFile.id)
  } else if (sourcePanel) {
    sourcePanel.removeAttribute('role')
    sourcePanel.removeAttribute('aria-labelledby')
  }
  const fileList = surface.querySelector('.source-editor-tabs')
  if (fileList && activeFile && fileList.dataset.activeTab !== activeFile.id) {
    fileList.dataset.activeTab = activeFile.id
    activeFile.scrollIntoView?.({ block: 'nearest', inline: 'nearest' })
  }
}

export function contextKey(workspace = '', session = '') {
  return JSON.stringify([workspace, session || 'draft'])
}

export function normalizeCodeContext(value) {
  if (!value || typeof value.text !== 'string' || !value.text.trim()) return null
  return {
    kind: String(value.kind || 'selection'),
    label: String(value.label || value.path || 'Selected text'),
    text: value.text,
    path: String(value.path || ''),
    line: Number.isInteger(value.line) && value.line > 0 ? value.line : null,
    workspaceId: String(value.workspaceId || ''),
  }
}

export function composeCodeContext(prompt, contexts) {
  if (!contexts.length) return prompt
  const blocks = contexts.map(item => {
    const location = item.path ? `\nSource: ${item.path}${item.line ? `:${item.line}` : ''}` : ''
    return `### ${item.label}${location}\n${item.text}`
  })
  return `${prompt.trim()}\n\nAttached context\n${blocks.join('\n\n')}`.trim()
}

export function addContextToList(contexts, value) {
  const item = normalizeCodeContext(value)
  if (!item || contexts.some(entry => entry.kind === item.kind && entry.path === item.path && entry.text === item.text)) return contexts
  return [...contexts, item]
}

function root() { return document.querySelector('[data-testid="mooncode-center"]') }
function identity(surface = root()) {
  return { workspace: surface?.dataset.workspaceId || '', session: surface?.dataset.sessionId || '' }
}
function key(surface = root()) {
  const current = identity(surface)
  return contextKey(current.workspace, current.session)
}
function layoutKey(surface) { return `moondesk.workbench.${key(surface)}` }
function readLayout(surface) { return readStored(layoutKey(surface), readStored(`moondesk.workbench.${identity(surface).workspace}`, {})) }
function readStored(name, fallback) {
  try { return JSON.parse(localStorage.getItem(name)) ?? fallback } catch { return fallback }
}
function saveStored(name, value) {
  try { localStorage.setItem(name, JSON.stringify(value)) } catch { /* Session still works without storage. */ }
}
function promptInput() { return document.querySelector('[data-testid="mooncode-input"]') }
function writePrompt(value) {
  const input = promptInput()
  if (!input) return
  input.value = value
  input.dispatchEvent(new Event('input', { bubbles: true }))
  input.focus()
  input.setSelectionRange(value.length, value.length)
}
function announce(message) {
  const surface = root()
  if (!surface) return
  let status = surface.querySelector('.code-workbench-status')
  if (!status) {
    status = document.createElement('span')
    status.className = 'code-workbench-status'
    status.setAttribute('role', 'status')
    surface.querySelector('.code-workbench-toolbar')?.append(status)
  }
  if (status.textContent !== message) status.textContent = message
  clearTimeout(announcementTimer)
  announcementTimer = setTimeout(() => {
    if (status.isConnected && status.textContent === message) status.textContent = ''
  }, 8000)
}

function renderContexts() {
  const tray = root()?.querySelector('[data-testid="code-context-tray"]')
  if (!tray) return
  const contexts = drafts.get(key()) || []
  const signature = JSON.stringify(contexts)
  if (tray.dataset.signature === signature) return
  tray.dataset.signature = signature
  tray.replaceChildren(...contexts.map((item, index) => {
    const chip = document.createElement('span')
    chip.className = 'code-context-chip'
    const inspect = document.createElement('button')
    inspect.type = 'button'
    inspect.textContent = item.label
    inspect.title = item.text
    inspect.addEventListener('click', () => {
      let preview = tray.querySelector('.code-context-preview')
      if (preview) { preview.remove(); return }
      preview = document.createElement('pre')
      preview.className = 'code-context-preview'
      preview.textContent = item.text
      tray.append(preview)
    })
    const remove = document.createElement('button')
    remove.type = 'button'
    const closeIcon = document.createElement('span')
    closeIcon.className = 'moon-icon'
    closeIcon.dataset.icon = 'close'
    closeIcon.setAttribute('aria-hidden', 'true')
    remove.append(closeIcon)
    remove.setAttribute('aria-label', `Remove ${item.label}`)
    remove.title = `Remove ${item.label}`
    remove.addEventListener('click', () => {
      drafts.set(key(), (drafts.get(key()) || []).filter((_, position) => position !== index))
      saveStored(`moondesk.contexts.${key()}`, drafts.get(key()))
      renderContexts()
      promptInput()?.focus()
    })
    chip.append(inspect, remove)
    return chip
  }))
}

function addContext(detail) {
  const surface = root()
  if (!surface) {
    if (!normalizeCodeContext(detail)) return
    pendingContext = detail
    document.querySelector('button[title="Open Code"]')?.click()
    return
  }
  const item = normalizeCodeContext(detail)
  if (!item) { announce('Select text, code or output first.'); return }
  if (item.workspaceId && item.workspaceId !== identity(surface).workspace) {
    announce('Open the source book before adding this selection.'); return
  }
  drafts.set(key(surface), addContextToList(drafts.get(key(surface)) || [], item))
  saveStored(`moondesk.contexts.${key(surface)}`, drafts.get(key(surface)))
  surface.querySelector('.code-selection-actions')?.remove()
  renderContexts()
  if (pendingContext) {
    const context = pendingContext
    pendingContext = null
    addContext(context)
  }
  const input = promptInput()
  if (input && !input.value.trim()) {
    const initial = detail.action === 'change' ? 'Change this selection: ' : detail.action === 'explain' ? 'Explain this selection.' : 'About this selection: '
    writePrompt(initial)
  } else input?.focus()
  surface.dataset.workbenchFocus = 'chat'
  surface.dataset.workbenchMobile = 'chat'
  saveStored(layoutKey(surface), { view: surface.dataset.workbenchView, focus: 'chat' })
  announce(`${item.label} added to your next message.`)
}

function captureSelection(target) {
  const surface = root()
  if (!surface) return null
  if (target instanceof HTMLTextAreaElement && target.matches('[data-testid="source-editor-input"]')) {
    const text = target.value.slice(target.selectionStart, target.selectionEnd)
    if (!text.trim()) return null
    const source = target.closest('[data-testid="source-editor"]')
    const path = source?.dataset.sourcePath || ''
    const line = target.value.slice(0, target.selectionStart).split('\n').length
    return { kind: 'code', text, path, line, label: `${path || 'Source'}:${line}`, workspaceId: identity(surface).workspace }
  }
  const selection = window.getSelection()
  if (!selection || selection.isCollapsed || !surface.contains(selection.anchorNode)) return null
  const element = selection.anchorNode?.parentElement
  if (element?.closest('input, textarea, .code-context-tray, .code-selection-actions')) return null
  const transcript = element?.closest('.mooncode-message')
  const documentView = element?.closest('.office-editor')
  return { kind: transcript ? 'quote' : documentView ? 'document' : 'selection', text: selection.toString(), label: transcript ? 'Conversation quote' : documentView ? 'Document selection' : 'Workspace selection', workspaceId: identity(surface).workspace }
}

function showSelectionActions(selection) {
  const surface = root()
  if (!surface || !selection?.text.trim()) return
  lastSelection = selection
  let actions = surface.querySelector('.code-selection-actions')
  if (!actions) {
    actions = document.createElement('div')
    actions.className = 'code-selection-actions'
    actions.setAttribute('aria-label', 'Use selected content')
    for (const [action, label] of [['ask', 'Ask'], ['change', 'Change'], ['explain', 'Explain']]) {
      const button = document.createElement('button')
      button.type = 'button'
      button.textContent = label
      button.addEventListener('pointerdown', event => event.preventDefault())
      button.addEventListener('click', () => { addContext({ ...lastSelection, action }); actions.remove() })
      actions.append(button)
    }
    surface.querySelector('.code-workbench-toolbar')?.append(actions)
  }
}

function setView(surface, view, remember = true) {
  if (!VIEWS.includes(view)) return
  surface.dataset.workbenchView = view
  surface.dataset.workbenchFocus = 'split'
  surface.dataset.workbenchMobile = 'work'
  surface.querySelector('[data-workbench-action="focus"]')?.setAttribute('aria-pressed', 'false')
  syncPanelTabs(surface)
  if (view === 'source') {
    const editor = surface.querySelector('.mooncode-workspace-editors')
    if (editor && !editor.open) editor.querySelector('summary')?.click()
  }
  if (['terminal', 'browser', 'compare'].includes(view)) {
    const tools = surface.querySelector('.mooncode-developer-tools')
    if (tools && !tools.open) tools.open = true
    // The developer tool panel is lazily mounted on open.
    requestAnimationFrame(() => surface.querySelector(`[data-developer-tool-tab="${view}"]`)?.click())
  }
  if (remember) saveStored(layoutKey(surface), { view, focus: surface.dataset.workbenchFocus || 'split' })
}

function enhance() {
  const surface = root()
  if (!surface) return
  const scope = key(surface)
  if (surface.dataset.workbenchScope !== scope) {
    surface.dataset.workbenchScope = scope
    const stored = initialWorkbenchLayout(readLayout(surface))
    setView(surface, stored.view, false)
    surface.dataset.workbenchFocus = stored.focus
    surface.dataset.workbenchMobile = stored.focus === 'chat' ? 'chat' : 'work'
    surface.querySelector('[data-workbench-action="focus"]')?.setAttribute('aria-pressed', String(stored.focus === 'chat'))
    if (!drafts.has(scope)) drafts.set(scope, readStored(`moondesk.contexts.${scope}`, []))
    historyCursor = -1
    lastSelection = null
  }
  if (!surface.dataset.workbenchInstalled) {
    surface.dataset.workbenchInstalled = 'true'
    surface.addEventListener('keydown', event => {
      const tab = event.target.closest?.('[role="tab"]')
      if (!tab || tab !== event.target) return
      if (tab.matches('button[data-workbench-view]')) {
        navigateTabList(event, surface.querySelectorAll('button[data-workbench-view]'), next => setView(surface, next.dataset.workbenchView))
      } else if (tab.matches('.source-editor-tab-select')) {
        navigateTabList(event, surface.querySelectorAll('.source-editor-tab-select'), next => {
          const id = next.dataset.testid
          next.click()
          // The typed view can replace a source tab while changing buffers.
          requestAnimationFrame(() => [...surface.querySelectorAll('.source-editor-tab-select')].find(item => item.dataset.testid === id)?.focus({ preventScroll: true }))
        })
      }
    })
    surface.addEventListener('click', event => {
      const tab = event.target.closest('button[data-workbench-view]')
      if (tab) { setView(surface, tab.dataset.workbenchView); tab.scrollIntoView?.({ block: 'nearest', inline: 'nearest' }); return }
      if (event.target.closest('.source-editor-tab-close')) {
        requestAnimationFrame(() => surface.querySelector('.source-editor-tab-select[aria-selected="true"]')?.focus({ preventScroll: true }))
        return
      }
      const action = event.target.closest('[data-workbench-action]')?.dataset.workbenchAction
      if (action === 'navigation') {
        const open = surface.closest('.code-main')?.dataset.navigation !== 'open'
        saveStored('moondesk.code-navigation', open)
        syncNavigation(surface)
        if (open) surface.closest('.code-main')?.querySelector('.mooncode-session-search-input')?.focus()
        return
      }
      if (action === 'selection') { addContext(lastSelection); return }
      if (action === 'focus' || action === 'restore') {
        surface.dataset.workbenchFocus = action === 'focus' ? 'chat' : 'split'
        surface.dataset.workbenchMobile = action === 'focus' ? 'chat' : 'work'
        surface.querySelector('[data-workbench-action="focus"]')?.setAttribute('aria-pressed', String(action === 'focus'))
        saveStored(layoutKey(surface), { view: surface.dataset.workbenchView, focus: surface.dataset.workbenchFocus })
        syncPanelTabs(surface)
        if (action === 'focus') promptInput()?.focus()
        else surface.querySelector('button[data-workbench-view][aria-selected="true"]')?.focus({ preventScroll: true })
      }
    })
  }
  renderContexts()
  syncNavigation(surface)
  // The typed view may replace attributes or buttons while applying new task
  // state. Restore the user's chosen presentation on every enhancement pass.
  const layout = readLayout(surface)
  if (layout.focus === 'chat') {
    surface.dataset.workbenchFocus = 'chat'
    surface.dataset.workbenchMobile = 'chat'
  }
  surface.querySelector('[data-workbench-action="focus"]')?.setAttribute('aria-pressed', String(surface.dataset.workbenchFocus === 'chat'))
  syncPanelTabs(surface)
  if (pendingContext) { const context = pendingContext; pendingContext = null; addContext(context) }
  const composerInput = promptInput()
  if (composerInput && composerInput.dataset.draftScope !== scope) {
    composerInput.dataset.draftScope = scope
    const saved = promptDrafts.has(scope) ? promptDrafts.get(scope) : readStored(`moondesk.draft.${scope}`, null)
    if (typeof saved === 'string' && composerInput.value !== saved) {
      composerInput.value = saved
      composerInput.dispatchEvent(new Event('input', { bubbles: true }))
    }
  }
  if (pendingNavigationDraft && identity(surface).session === pendingNavigationDraft.sessionId) {
    writePrompt(pendingNavigationDraft.draft)
    const files = (pendingNavigationDraft.images || []).filter(image => image.type === 'image' && image.data_base64).map((image, index) => {
      const bytes = Uint8Array.from(atob(image.data_base64), value => value.charCodeAt(0))
      return new File([bytes], image.name || `Earlier image ${index + 1}`, { type: image.media_type })
    })
    if (files.length) window.dispatchEvent(new CustomEvent('moondesk:code-images', { detail: { files, source: 'earlier turn' } }))
    pendingNavigationDraft = null
  }
  if (pendingTaskDraft && identity(surface).workspace === pendingTaskDraft.workspaceId && !identity(surface).session) {
    writePrompt(pendingTaskDraft.prompt)
    pendingTaskDraft = null
  }
  const browserToolbar = surface.querySelector('.mooncode-developer-browser-toolbar')
  if (browserToolbar && !browserToolbar.querySelector('[data-pick-code-element]')) {
    const button = document.createElement('button')
    button.type = 'button'
    button.className = 'mooncode-developer-browser-button'
    button.dataset.pickCodeElement = 'true'
    button.textContent = 'Select element'
    button.title = 'Select an element in a MoonDesk-served preview to discuss it'
    button.addEventListener('click', () => {
      surface.querySelector('[data-testid="mooncode-developer-browser-frame"]')?.contentWindow?.postMessage({ protocol: 'moondesk-preview-v1', type: 'pick-element' }, '*')
      announce('Click an element in the preview. Escape cancels. Available on MoonDesk-served previews.')
    })
    browserToolbar.append(button)
  }
}

function scheduleEnhance() {
  if (scheduled) return
  scheduled = true
  requestAnimationFrame(() => { scheduled = false; enhance() })
}

if (typeof document !== 'undefined') {
  window.addEventListener('moondesk:task-draft', event => { pendingTaskDraft = event.detail; scheduleEnhance() })
  window.addEventListener('resize', scheduleEnhance)
  document.addEventListener('click', event => {
    if (!event.target.closest?.('[data-close-code-navigation]')) return
    const surface = root()
    if (!surface) return
    saveStored('moondesk.code-navigation', false)
    syncNavigation(surface)
    surface.querySelector('[data-workbench-action="navigation"]')?.focus()
  })
  document.addEventListener('keydown', event => {
    const surface = root()
    const shell = surface?.closest('.code-main')
    if (event.key !== 'Escape' || !shell || shell.dataset.navigation !== 'open' ||
        !event.target.closest?.('.mooncode-rail') || window.matchMedia('(min-width: 1100px)').matches) return
    event.preventDefault()
    saveStored('moondesk.code-navigation', false)
    syncNavigation(surface)
    surface.querySelector('[data-workbench-action="navigation"]')?.focus()
  })
  document.addEventListener('pointerdown', event => {
    const surface = root()
    const shell = surface?.closest('.code-main')
    if (!shell || shell.dataset.navigation !== 'open' || window.matchMedia('(min-width: 1100px)').matches ||
        event.target.closest?.('.mooncode-rail, [data-workbench-action="navigation"]')) return
    saveStored('moondesk.code-navigation', false)
    syncNavigation(surface)
  })
  window.__moonDeskComposeContext = value => {
    const currentKey = key()
    pending.set(currentKey, { value, contexts: drafts.get(currentKey) || [] })
    return composeCodeContext(value, drafts.get(currentKey) || [])
  }
  window.__moonDeskContextSubmitted = (workspace, sourceSession, session, turn) => {
    const currentKey = contextKey(workspace, sourceSession)
    const submitted = pending.get(currentKey)
    if (!submitted) return
    const historyKey = `moondesk.prompts.${workspace}`
    const history = readStored(historyKey, [])
    if (submitted.value.trim()) saveStored(historyKey, [submitted.value, ...history.filter(value => value !== submitted.value)].slice(0, 50))
    window.dispatchEvent(new CustomEvent('moondesk:context-submitted', { detail: { workspaceId: workspace, sessionId: session, clientTurnId: turn, contexts: submitted.contexts, prompt: submitted.value } }))
    pending.delete(currentKey)
    if (promptDrafts.get(currentKey) === submitted.value) {
      promptDrafts.delete(currentKey)
      saveStored(`moondesk.draft.${currentKey}`, '')
    }
    drafts.set(currentKey, (drafts.get(currentKey) || []).filter(item => !submitted.contexts.includes(item)))
    saveStored(`moondesk.contexts.${currentKey}`, drafts.get(currentKey))
    historyCursor = -1
    renderContexts()
  }
  window.addEventListener('moondesk:add-context', event => addContext(event.detail))
  document.addEventListener('input', event => {
    if (!event.target.matches?.('[data-testid="mooncode-input"]')) return
    const currentKey = key()
    promptDrafts.set(currentKey, event.target.value)
    saveStored(`moondesk.draft.${currentKey}`, event.target.value)
  })
  window.addEventListener('moondesk:open-code-session', event => {
    const id = event.detail?.sessionId
    const input = document.querySelector('[data-testid="code-session-navigation"]')
    if (typeof id !== 'string' || !id || !input) return
    pendingNavigationDraft = typeof event.detail.draft === 'string' ? { sessionId: id, draft: event.detail.draft, images: event.detail.images } : null
    input.value = id
    input.dispatchEvent(new Event('input', { bubbles: true }))
  })
  window.addEventListener('moondesk:open-workspace', event => {
    const id = event.detail?.workspaceId
    const input = document.querySelector('[data-testid="code-workspace-navigation"]')
    if (typeof id !== 'string' || !id || !input) return
    input.value = id
    input.dispatchEvent(new Event('input', { bubbles: true }))
  })
  window.addEventListener('message', event => {
    const frame = root()?.querySelector('[data-testid="mooncode-developer-browser-frame"]')
    if (!frame || event.source !== frame.contentWindow || event.data?.protocol !== 'moondesk-preview-v1') return
    if (event.data.type === 'element-pick-cancelled') { announce('Element selection cancelled.'); return }
    if (event.data.type !== 'element-picked') return
    const item = event.data
    addContext({ kind: 'browser', label: item.label || item.selector || 'Preview element', action: 'change', text: `Preview: ${item.url}\nElement: ${item.selector}\nRole: ${item.role}\nText: ${item.text}\nMarkup:\n${item.html}`, workspaceId: identity().workspace })
  })
  document.addEventListener('select', event => showSelectionActions(captureSelection(event.target)))
  document.addEventListener('mouseup', event => {
    if (!event.target.closest('.code-selection-actions, .code-workbench-actions')) showSelectionActions(captureSelection(event.target))
  })
  document.addEventListener('keydown', event => {
    const input = event.target
    if (!(input instanceof HTMLTextAreaElement) || !input.matches('[data-testid="mooncode-input"]') || event.isComposing || event.shiftKey || event.ctrlKey || event.metaKey) return
    const history = readStored(`moondesk.prompts.${identity().workspace}`, [])
    if (event.key === 'ArrowUp' && input.selectionStart === 0 && input.selectionEnd === 0 && history.length) {
      event.preventDefault()
      if (historyCursor === -1) historyDraft = input.value
      historyCursor = Math.min(historyCursor + 1, history.length - 1)
      writePrompt(history[historyCursor])
      input.setSelectionRange(0, 0)
    } else if (event.key === 'ArrowDown' && historyCursor >= 0 && input.selectionStart === 0) {
      event.preventDefault()
      historyCursor -= 1
      writePrompt(historyCursor < 0 ? historyDraft : history[historyCursor])
      input.setSelectionRange(0, 0)
    }
  }, true)
  new MutationObserver(scheduleEnhance).observe(document.getElementById('app') || document.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-session-id', 'data-workspace-id'] })
  scheduleEnhance()
}
