import { parseJsonDocument, resolveJsonPointer, jsonChildPointers } from './source-json-values.js'
import { createJsonReplacementPanel, syncJsonReplacement, resetJsonReplacement, actJsonReplacement } from './source-json-replacement-ui.js'
export { changeJsonReplacement } from './source-json-replacement-ui.js'

const states = new WeakMap()
const PAGE_SIZE = 50
const PREVIEW_SIZE = 4000
const control = (panel, name) => panel.querySelector(`[data-json-${name}]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '', parts.surface.dataset.sourcePath || ''])

function button(action, label) {
  const item = document.createElement('button')
  item.type = 'button'; item.className = 'secondary-button'
  item.dataset.action = `source-json-${action}`; item.textContent = label
  return item
}

function createPanel(surface) {
  const panel = document.createElement('details')
  panel.setAttribute('data-json-explorer', '')
  const summary = document.createElement('summary'); summary.textContent = 'Explore JSON values'
  const help = document.createElement('p')
  help.textContent = 'Inspect the current draft, including unsaved changes. Downloads contain only the chosen value; they do not save the source.'
  const pointer = document.createElement('input'); pointer.setAttribute('data-json-pointer', '')
  pointer.setAttribute('aria-label', 'JSON Pointer; empty means root'); pointer.placeholder = '/orders/0'
  const status = document.createElement('p'); status.setAttribute('data-json-status', ''); status.setAttribute('role', 'status')
  const preview = document.createElement('pre'); preview.setAttribute('data-json-preview', '')
  preview.style.maxHeight = '12rem'; preview.style.overflow = 'auto'; preview.style.whiteSpace = 'pre-wrap'
  const children = document.createElement('div'); children.setAttribute('data-json-children', '')
  children.setAttribute('aria-label', 'JSON child values')
  panel.append(summary, help, pointer, button('go', 'Inspect pointer'), button('parent', 'Parent'), button('root', 'Root'),
    status, button('select', 'Select value in editor'), button('download', 'Download value JSON'), button('replace-open', 'Replace displayed value'), preview,
    children, button('previous', 'Previous values'), button('next', 'Next values'))
  createJsonReplacementPanel(panel, button)
  surface.append(panel)
  return panel
}

export function syncJsonExplorer(parts) {
  let panel = parts.surface.querySelector('[data-json-explorer]')
  if (parts.language !== 'JSON') {
    if (panel) { panel.hidden = true; states.delete(panel); resetJsonReplacement(panel) }
    return
  }
  if (!panel) panel = createPanel(parts.surface)
  panel.hidden = false
  let state = states.get(panel)
  const key = identity(parts)
  if (!state || state.identity !== key) {
    state = { identity: key, pointer: '', page: 0, text: null, root: null, node: null, generation: 0 }
    states.set(panel, state); control(panel, 'pointer').value = ''; resetJsonReplacement(panel)
  }
  const signature = JSON.stringify([parts.editor.value, parts.editor.disabled, state.pointer, state.page])
  if (state.signature === signature) return
  state.signature = signature
  state.generation += 1
  let error = ''
  if (state.text !== parts.editor.value) {
    state.text = parts.editor.value; state.root = null; state.parseError = ''; state.page = 0
    try { state.root = parseJsonDocument(state.text) } catch (problem) { state.parseError = problem.message }
  }
  state.node = null
  try {
    if (state.parseError) throw new Error(state.parseError)
    state.node = resolveJsonPointer(state.root, state.pointer)
  } catch (problem) { error = problem.message }
  const children = state.node ? jsonChildPointers(state.node, state.pointer) : []
  state.page = Math.min(state.page, Math.max(0, Math.ceil(children.length / PAGE_SIZE) - 1))
  const start = state.page * PAGE_SIZE
  const raw = state.node ? state.text.slice(state.node.start, state.node.end) : ''
  const message = error || `${state.pointer || '(root)'} · ${state.node.type} · ${raw.length} UTF-16 units · ` +
    (children.length ? `children ${start + 1}–${Math.min(start + PAGE_SIZE, children.length)} of ${children.length}` : 'no child values') +
    (raw.length > PREVIEW_SIZE ? ' · preview shortened; selection and download include the full value' : '')
  control(panel, 'status').textContent = message
  control(panel, 'preview').textContent = raw.slice(0, PREVIEW_SIZE)
  control(panel, 'pointer').disabled = parts.editor.disabled
  const setDisabled = (action, unavailable) => { panel.querySelector(`[data-action="source-json-${action}"]`).disabled = parts.editor.disabled || unavailable }
  setDisabled('go', false); setDisabled('parent', !state.pointer); setDisabled('root', !state.pointer)
  setDisabled('select', !state.node); setDisabled('download', !state.node); setDisabled('replace-open', !state.node)
  setDisabled('previous', state.page === 0); setDisabled('next', start + PAGE_SIZE >= children.length)
  state.signature = JSON.stringify([parts.editor.value, parts.editor.disabled, state.pointer, state.page])
  control(panel, 'children').replaceChildren(...children.slice(start, start + PAGE_SIZE).map(child => {
    const item = button('child', `${JSON.stringify(child.key)} · ${child.node.type}${child.ambiguous ? ' · duplicate key; inspect parent' : ''}`)
    item.dataset.jsonTarget = child.pointer
    item.dataset.jsonSnapshot = String(state.generation)
    item.disabled = parts.editor.disabled || child.ambiguous
    return item
  }))
  syncJsonReplacement(parts, panel, state)
}

export function actJsonExplorer(parts, action, reveal) {
  if (!parts || parts.language !== 'JSON' || parts.editor.disabled || !parts.surface.isConnected) return
  const panel = parts.surface.querySelector('[data-json-explorer]')
  const before = states.get(panel)
  if (!before || before.identity !== identity(parts) || before.text !== parts.editor.value) {
    syncJsonExplorer(parts)
    if (panel) control(panel, 'status').textContent = 'Draft changed. Inspect the refreshed value before selecting, downloading or replacing.'
    return
  }
  const kind = action.dataset.action.slice('source-json-'.length)
  if (kind.startsWith('replace-')) { actJsonReplacement(parts, panel, before, kind.slice('replace-'.length)); return }
  if (kind === 'go') { before.pointer = control(panel, 'pointer').value; before.page = 0 }
  else if (kind === 'root') { before.pointer = ''; before.page = 0 }
  else if (kind === 'parent') { before.pointer = before.pointer.slice(0, before.pointer.lastIndexOf('/')); before.page = 0 }
  else if (kind === 'child') {
    if (action.disabled || action.dataset.jsonSnapshot !== String(before.generation)) return
    before.pointer = action.dataset.jsonTarget; before.page = 0
  } else if (kind === 'previous') before.page = Math.max(0, before.page - 1)
  else if (kind === 'next') before.page += 1
  else if (kind === 'select' && before.node) {
    const line = before.text.slice(0, before.node.start).split('\n').length
    reveal(parts, { path: parts.surface.dataset.sourcePath, start: before.node.start, end: before.node.end, line })
    return
  } else if (kind === 'download' && before.node) {
    let url
    try {
      const raw = before.text.slice(before.node.start, before.node.end)
      url = URL.createObjectURL(new Blob([raw], { type: 'application/json;charset=utf-8' }))
      const link = document.createElement('a'); link.href = url; link.download = 'json-value.json'
      document.body.append(link); link.click(); link.remove()
      control(panel, 'status').textContent = 'JSON value download requested from the current draft. The source is unchanged.'
    } catch (error) { control(panel, 'status').textContent = `Could not download JSON value: ${error.message}` }
    finally { if (url) setTimeout(() => URL.revokeObjectURL(url), 1000) }
    return
  } else return
  control(panel, 'pointer').value = before.pointer
  syncJsonExplorer(parts)
}
