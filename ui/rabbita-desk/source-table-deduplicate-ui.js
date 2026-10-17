import { parseTaskCsv } from './specialist-task-csv.js'
import { prepareDuplicateKeys, applyDuplicateKeys } from './source-table-deduplicate.js'
const states = new WeakMap()
const field = (p, n) => p.querySelector(`[data-table-deduplicate-${n}]`)
const button = (p, n) => p.querySelector(`[data-action="source-table-deduplicate-${n}"]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '', parts.surface.dataset.sourcePath || ''])
const supported = parts => /\.(csv|tsv)$/i.test(parts.surface.dataset.sourcePath || '')
const separator = parts => /\.tsv$/i.test(parts.surface.dataset.sourcePath || '') ? '\t' : ','
function clear(panel, state, message) {
  state.plan = null; button(panel, 'apply').disabled = true
  field(panel, 'preview').textContent = ''; field(panel, 'status').textContent = message
}
export function syncTableDeduplicate(parts) {
  let panel = parts.surface.querySelector('[data-table-deduplicate]')
  if (!supported(parts)) { if (panel) { panel.hidden = true; states.delete(panel) } return }
  if (!panel) {
    panel = document.createElement('section'); panel.setAttribute('data-table-deduplicate', '')
    const heading = document.createElement('h3'); heading.textContent = 'Resolve duplicate table keys'; panel.append(heading)
    const help = document.createElement('p'); help.textContent = 'Select exact key columns and explicitly keep the first or last record for each nonblank duplicate key. All values and original record numbers are shown below. Blank keys remain unresolved and retained. Apply changes only this unsaved draft; Save is your choice. Output quotes cells and uses LF. Limits: 512 KiB, 100 data records, 32 columns. Record numbers include the header as record 1, not physical lines.'; panel.append(help)
    const keys = document.createElement('fieldset'); keys.setAttribute('data-table-deduplicate-keys', ''); panel.append(keys)
    for (const [name, label] of [['first', 'Keep first'], ['last', 'Keep last'], ['apply', 'Apply to unsaved draft'], ['cancel', 'Cancel preview'], ['undo', 'Undo key resolution']]) {
      const control = document.createElement('button'); control.type = 'button'; control.dataset.action = `source-table-deduplicate-${name}`; control.textContent = name === 'first' || name === 'last' ? `Preview: ${label}` : label; panel.append(control)
    }
    for (const name of ['status', 'preview']) { const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-table-deduplicate-${name}`, ''); if (name === 'status') item.setAttribute('role', 'status'); panel.append(item) }
    parts.surface.append(panel)
  }
  panel.hidden = false
  let state = states.get(panel)
  if (!state || state.identity !== identity(parts)) {
    state = {identity: identity(parts), text: null, disabled: parts.editor.disabled, plan: null, undo: null, headers: null, policy: null}; states.set(panel, state)
  }
  if (state.text !== parts.editor.value || state.disabled !== parts.editor.disabled) {
    clear(panel, state, 'Choose key columns, then preview keep first or keep last.'); state.undo = null
    state.text = parts.editor.value; state.disabled = parts.editor.disabled
  }
  try {
    const headers = parseTaskCsv(parts.editor.value, separator(parts)).headers
    if (JSON.stringify(headers) !== JSON.stringify(state.headers)) {
      field(panel, 'keys').replaceChildren()
      for (const name of headers) { const label = document.createElement('label'), input = document.createElement('input'); input.type = 'checkbox'; input.setAttribute('data-table-deduplicate-key', ''); input.value = name; label.textContent = name + ' '; label.append(input); field(panel, 'keys').append(label) }
      state.headers = headers
    }
  } catch (error) { field(panel, 'keys').replaceChildren(); state.headers = null; clear(panel, state, String(error.message || error)) }
  for (const input of panel.querySelectorAll('[data-table-deduplicate-key]')) input.disabled = parts.editor.disabled
  for (const name of ['first', 'last']) button(panel, name).disabled = parts.editor.disabled || !state.headers
  button(panel, 'apply').disabled = parts.editor.disabled || !state.plan
  button(panel, 'undo').disabled = parts.editor.disabled || !state.undo
}
export function changeTableDeduplicate(parts) {
  const panel = parts?.surface.querySelector('[data-table-deduplicate]'), state = states.get(panel)
  if (state) clear(panel, state, 'Key settings changed. Preview again.')
}
export function actTableDeduplicate(parts, action) {
  if (!parts || !supported(parts)) return
  syncTableDeduplicate(parts)
  const panel = parts.surface.querySelector('[data-table-deduplicate]'), state = states.get(panel), kind = action.dataset.action.slice('source-table-deduplicate-'.length)
  if (parts.editor.disabled) return
  if (kind === 'cancel') { clear(panel, state, 'Preview cancelled. Draft unchanged.'); return }
  const args = () => [parts.editor.value, separator(parts), [...panel.querySelectorAll('[data-table-deduplicate-key]')].filter(i => i.checked).map(i => i.value), state.policy]
  function replace(output) {
    const before = parts.editor.value, selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
    try { parts.editor.setRangeText(output, 0, before.length, 'select'); if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared table.') }
    catch (error) { parts.editor.value = before; parts.editor.setSelectionRange(...selection); throw error }
    state.text = output; parts.editor.dispatchEvent(new Event('input', {bubbles: true})); parts.editor.focus()
  }
  try {
    if (kind === 'first' || kind === 'last') {
      state.policy = kind; state.plan = prepareDuplicateKeys(...args()); field(panel, 'preview').textContent = JSON.stringify(state.plan.preview, null, 2)
      field(panel, 'status').textContent = `Keep ${kind}: ${state.plan.preview.retained.length} retained, ${state.plan.preview.removed.length} removed, ${state.plan.preview.unresolvedBlankKeys.length} blank-key records unresolved and retained. Review every group before Apply.`; button(panel, 'apply').disabled = false
    } else if (kind === 'apply') {
      const output = applyDuplicateKeys(state.plan, ...args()), before = parts.editor.value
      replace(output); state.undo = {before, after: output}; clear(panel, state, 'Key resolution applied to unsaved draft. Blank keys remain for explicit correction. Save explicitly to persist.'); button(panel, 'undo').disabled = false
    } else if (kind === 'undo') {
      if (!state.undo || parts.editor.value !== state.undo.after) throw new Error('Draft changed; scoped undo is unavailable.')
      replace(state.undo.before); state.undo = null; clear(panel, state, 'Original draft restored.'); button(panel, 'undo').disabled = true
    }
  } catch (error) { clear(panel, state, String(error.message || error)) }
}
