import { prepareJsonMove, applyJsonMove } from './source-json-move.js'
import { jsonPointerTokens } from './source-json-values.js'

const edits = new WeakMap()
const field = (panel, name) => panel.querySelector(`[data-json-move-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-json-move-${name}"]`)

export function createJsonMovePanel(panel, makeButton) {
  panel.append(makeButton('move-open', 'Move displayed member or item'))
  const section = document.createElement('div'); section.setAttribute('data-json-move-section', ''); section.hidden = true
  const help = document.createElement('p')
  help.textContent = 'Move this exact value to another container, or reorder it within its current container. Destination pointer refers to the current draft. Position is zero-based AFTER removing the source; zero means first. Object destinations require a new unique key. Preview both stages before applying once to the unsaved draft.'
  section.append(help)
  for (const [name, label] of [['destination', 'Destination container JSON Pointer (empty means root)'], ['key', 'Destination object key (ignored for arrays)'], ['position', 'Position after removal (zero-based)']]) {
    const item = document.createElement('input'); item.setAttribute(`data-json-move-${name}`, ''); item.setAttribute('aria-label', label); item.placeholder = label; section.append(item)
  }
  section.append(makeButton('move-review', 'Preview move'), makeButton('move-apply', 'Move in draft'), makeButton('move-cancel', 'Cancel move'))
  for (const name of ['status', 'source', 'destination-preview']) {
    const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-json-move-${name}`, '')
    if (name === 'status') item.setAttribute('role', 'status')
    else { item.style.maxHeight = '16rem'; item.style.overflow = 'auto'; item.style.whiteSpace = 'pre-wrap' }
    section.append(item)
  }
  panel.append(section)
}

export function resetJsonMove(panel) {
  edits.delete(panel); field(panel, 'section').hidden = true; button(panel, 'apply').disabled = true
  for (const name of ['destination', 'key', 'position']) field(panel, name).value = ''
}
function clear(panel, edit, message) {
  edit.plan = null; button(panel, 'apply').disabled = true; field(panel, 'status').textContent = message
  field(panel, 'source').textContent = ''; field(panel, 'destination-preview').textContent = ''
}
export function syncJsonMove(parts, panel, state) {
  let edit = edits.get(panel)
  if (edit && (edit.identity !== state.identity || edit.pointer !== state.pointer)) { resetJsonMove(panel); edit = null }
  if (edit && (edit.text !== state.text || edit.disabled !== parts.editor.disabled)) {
    clear(panel, edit, 'Draft or editor availability changed. Preview the move again.'); edit.text = state.text; edit.disabled = parts.editor.disabled
  }
  const unavailable = parts.editor.disabled || !state.node || !state.pointer
  button(panel, 'open').disabled = unavailable; field(panel, 'section').hidden = !edit
  for (const name of ['destination', 'key', 'position']) field(panel, name).disabled = unavailable
  button(panel, 'review').disabled = unavailable; button(panel, 'apply').disabled = unavailable || !edit?.plan
}
export function changeJsonMove(parts) {
  const panel = parts?.surface.querySelector('[data-json-explorer]'), edit = edits.get(panel)
  if (edit) clear(panel, edit, 'Move fields changed. Preview again before applying.')
}
export function actJsonMove(parts, panel, state, kind) {
  let edit = edits.get(panel)
  if (kind === 'open' && state.node && state.pointer) {
    edit = { identity: state.identity, pointer: state.pointer, text: state.text, disabled: parts.editor.disabled, plan: null }; edits.set(panel, edit)
    field(panel, 'destination').value = state.pointer.slice(0, state.pointer.lastIndexOf('/'))
    field(panel, 'key').value = jsonPointerTokens(state.pointer).at(-1); field(panel, 'position').value = '0'
    clear(panel, edit, 'Choose the destination and final position. The draft is unchanged.'); syncJsonMove(parts, panel, state); field(panel, 'destination').focus(); return
  }
  if (!edit || edit.identity !== state.identity || edit.pointer !== state.pointer) return
  if (kind === 'cancel') { resetJsonMove(panel); return }
  try {
    const args = [parts.editor.value, state.pointer, field(panel, 'destination').value, field(panel, 'key').value, field(panel, 'position').value]
    if (kind === 'review') {
      const plan = prepareJsonMove(...args); edit.plan = plan
      field(panel, 'source').textContent = `Source container before removal:\n${plan.sourceBefore.slice(0, 4000)}\nAfter removal (intermediate):\n${plan.sourceAfter.slice(0, 4000)}`
      field(panel, 'destination-preview').textContent = `Destination after removal:\n${plan.destinationBefore.slice(0, 4000)}\nAfter insertion (final):\n${plan.destinationAfter.slice(0, 4000)}`
      field(panel, 'status').textContent = `Move ${state.pointer} to ${plan.movedPointer}. The value's exact JSON text is kept.` +
        ([plan.sourceBefore, plan.sourceAfter, plan.destinationBefore, plan.destinationAfter].some(value => value.length > 4000) ? ' Each preview is shortened at 4,000 units; apply uses the complete draft.' : '')
      button(panel, 'apply').disabled = false
    } else if (kind === 'apply') {
      const plan = edit.plan, output = applyJsonMove(plan, ...args), selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try { parts.editor.setRangeText(output, 0, parts.editor.value.length, 'select'); if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared move.') }
      catch (error) { parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error }
      resetJsonMove(panel); state.pointer = plan.movedPointer; state.page = 0; panel.querySelector('[data-json-pointer]').value = state.pointer
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      panel.querySelector('[data-json-status]').textContent = `Moved to ${plan.movedPointer} in the unsaved draft. Inspect the result and use the existing Save controls when ready.`
    }
  } catch (error) { clear(panel, edit, error.message) }
}
