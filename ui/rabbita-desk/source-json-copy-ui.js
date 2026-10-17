import { prepareJsonCopy, applyJsonCopy } from './source-json-copy.js'
import { jsonPointerTokens } from './source-json-values.js'

const edits = new WeakMap()
const field = (panel, name) => panel.querySelector(`[data-json-copy-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-json-copy-${name}"]`)

export function createJsonCopyPanel(panel, makeButton) {
  panel.append(makeButton('copy-open', 'Copy displayed value into container'))
  const section = document.createElement('div'); section.setAttribute('data-json-copy-section', ''); section.hidden = true
  const help = document.createElement('p')
  help.textContent = 'Duplicate the exact displayed JSON value within this draft. The source is not removed. Destination is a JSON Pointer in the current draft; position is zero-based before insertion. Object destinations need a unique key. Copying into a descendant inserts a snapshot, not a recursive reference. Preview before applying to the unsaved draft.'
  section.append(help)
  for (const [name, label] of [['destination', 'Copy destination container JSON Pointer (empty means root)'], ['key', 'Copy destination object key (ignored for arrays)'], ['position', 'Copy position before insertion (zero-based)']]) {
    const item = document.createElement('input'); item.setAttribute(`data-json-copy-${name}`, ''); item.setAttribute('aria-label', label); item.placeholder = label; section.append(item)
  }
  section.append(makeButton('copy-review', 'Preview copy'), makeButton('copy-apply', 'Copy in draft'), makeButton('copy-cancel', 'Cancel copy'))
  for (const name of ['status', 'source', 'before', 'after']) {
    const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-json-copy-${name}`, '')
    if (name === 'status') item.setAttribute('role', 'status')
    else { item.style.maxHeight = '16rem'; item.style.overflow = 'auto'; item.style.whiteSpace = 'pre-wrap' }
    section.append(item)
  }
  panel.append(section)
}

export function resetJsonCopy(panel) {
  edits.delete(panel); field(panel, 'section').hidden = true; button(panel, 'apply').disabled = true
  for (const name of ['destination', 'key', 'position']) field(panel, name).value = ''
}
function clear(panel, edit, message) {
  edit.plan = null; button(panel, 'apply').disabled = true; field(panel, 'status').textContent = message
  for (const name of ['source', 'before', 'after']) field(panel, name).textContent = ''
}
export function syncJsonCopy(parts, panel, state) {
  let edit = edits.get(panel)
  if (edit && (edit.identity !== state.identity || edit.pointer !== state.pointer)) { resetJsonCopy(panel); edit = null }
  if (edit && (edit.text !== state.text || edit.disabled !== parts.editor.disabled)) {
    clear(panel, edit, 'Draft or editor availability changed. Preview the copy again.'); edit.text = state.text; edit.disabled = parts.editor.disabled
  }
  const unavailable = parts.editor.disabled || !state.node
  button(panel, 'open').disabled = unavailable; field(panel, 'section').hidden = !edit
  for (const name of ['destination', 'key', 'position']) field(panel, name).disabled = unavailable
  button(panel, 'review').disabled = unavailable; button(panel, 'apply').disabled = unavailable || !edit?.plan
}
export function changeJsonCopy(parts) {
  const panel = parts?.surface.querySelector('[data-json-explorer]'), edit = edits.get(panel)
  if (edit) clear(panel, edit, 'Copy fields changed. Preview again before applying.')
}
export function actJsonCopy(parts, panel, state, kind) {
  let edit = edits.get(panel)
  if (kind === 'open' && state.node) {
    edit = { identity: state.identity, pointer: state.pointer, text: state.text, disabled: parts.editor.disabled, plan: null }; edits.set(panel, edit)
    field(panel, 'destination').value = state.pointer.slice(0, state.pointer.lastIndexOf('/'))
    field(panel, 'key').value = state.pointer ? jsonPointerTokens(state.pointer).at(-1) + '-copy' : 'copy'; field(panel, 'position').value = '0'
    clear(panel, edit, 'Choose the destination and position. The draft is unchanged.'); syncJsonCopy(parts, panel, state); field(panel, 'destination').focus(); return
  }
  if (!edit || edit.identity !== state.identity || edit.pointer !== state.pointer) return
  if (kind === 'cancel') { resetJsonCopy(panel); return }
  try {
    const args = [parts.editor.value, state.pointer, field(panel, 'destination').value, field(panel, 'key').value, field(panel, 'position').value]
    if (kind === 'review') {
      const plan = prepareJsonCopy(...args); edit.plan = plan
      field(panel, 'source').textContent = `Exact value to copy:\n${plan.raw.slice(0, 4000)}`
      field(panel, 'before').textContent = `Destination before:\n${plan.before.slice(0, 4000)}`
      field(panel, 'after').textContent = `Destination after:\n${plan.after.slice(0, 4000)}`
      field(panel, 'status').textContent = `Copy ${state.pointer || '(root)'} to ${plan.copiedPointer}. Source is retained; the copied value keeps its exact JSON text.` +
        ([plan.raw, plan.before, plan.after].some(value => value.length > 4000) ? ' Each preview is shortened at 4,000 units; apply uses the complete draft.' : '')
      button(panel, 'apply').disabled = false
    } else if (kind === 'apply') {
      const plan = edit.plan, output = applyJsonCopy(plan, ...args), selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try { parts.editor.setRangeText(output, 0, parts.editor.value.length, 'select'); if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared copy.') }
      catch (error) { parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error }
      resetJsonCopy(panel); state.pointer = plan.copiedPointer; state.page = 0; panel.querySelector('[data-json-pointer]').value = state.pointer
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      panel.querySelector('[data-json-status]').textContent = `Copied to ${plan.copiedPointer} in the unsaved draft. Inspect the result and use the existing Save controls when ready.`
    }
  } catch (error) { clear(panel, edit, error.message) }
}
