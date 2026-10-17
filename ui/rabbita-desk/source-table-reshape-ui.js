import { parseTaskCsv } from './specialist-task-csv.js'
import { prepareTableReshape, applyTableReshape } from './source-table-reshape.js'

const states = new WeakMap()
const field = (panel, name) => panel.querySelector(`[data-table-reshape-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-table-reshape-${name}"]`)
const identity = parts => JSON.stringify([parts.surface.dataset.workspaceId || '', parts.surface.dataset.sourcePath || ''])
const supported = parts => /\.(csv|tsv)$/i.test(parts.surface.dataset.sourcePath || '')
const separator = parts => /\.tsv$/i.test(parts.surface.dataset.sourcePath || '') ? '\t' : ','
const blocked = parts => Boolean(parts.editor.disabled || parts.editor.readOnly)
const settings = panel => JSON.stringify([[...panel.querySelectorAll('[data-table-reshape-measure]')].filter(input => input.checked).map(input => input.value), field(panel, 'variable').value, field(panel, 'value').value])

function clear(panel, state, message) {
  state.plan = null; button(panel, 'apply').disabled = true
  field(panel, 'preview').textContent = ''; field(panel, 'status').textContent = message
}
function invalidate(panel, state, message) {
  clear(panel, state, message); state.undo = null; button(panel, 'undo').disabled = true
}
export function syncTableReshape(parts) {
  let panel = parts.surface.querySelector('[data-table-reshape]')
  if (!supported(parts)) { if (panel) { panel.hidden = true; states.delete(panel) } return }
  if (!panel) {
    panel = document.createElement('section'); panel.setAttribute('data-table-reshape', '')
    const heading = document.createElement('h3'); heading.textContent = 'Reshape draft columns into rows'; panel.append(heading)
    const help = document.createElement('p'); help.textContent = 'Choose exact measurement columns; unchecked columns remain identifiers. Enter variable and value output names. Preview shows every output record in source-record then source-column order, retaining blanks and literal text. Apply edits only this unsaved CSV/TSV draft; Save is your choice. Output quotes cells and uses LF. Limits: 512 KiB input/output, 100 input/output records, 32 input/output columns. Source record numbers include the header as record 1, not physical lines. Spreadsheet apps may reinterpret exported formula-like text.'; panel.append(help)
    const measures = document.createElement('fieldset'); measures.setAttribute('data-table-reshape-measures', '')
    const legend = document.createElement('legend'); legend.textContent = 'Measurement columns'; measures.append(legend); panel.append(measures)
    for (const [name, label] of [['variable', 'Variable output name'], ['value', 'Value output name']]) {
      const wrapper = document.createElement('label'), input = document.createElement('input')
      wrapper.textContent = label + ' '; input.type = 'text'; input.setAttribute(`data-table-reshape-${name}`, ''); input.setAttribute('aria-label', label); wrapper.append(input); panel.append(wrapper)
    }
    for (const [name, label] of [['review', 'Preview reshape'], ['apply', 'Apply to unsaved draft'], ['cancel', 'Cancel preview'], ['undo', 'Undo reshape']]) {
      const control = document.createElement('button'); control.type = 'button'; control.dataset.action = `source-table-reshape-${name}`; control.textContent = label; panel.append(control)
    }
    for (const name of ['status', 'preview']) { const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-table-reshape-${name}`, ''); if (name === 'status') item.setAttribute('role', 'status'); panel.append(item) }
    parts.surface.append(panel)
  }
  panel.hidden = false
  let state = states.get(panel)
  if (!state || state.identity !== identity(parts) || state.editor !== parts.editor) {
    state = {identity: identity(parts), editor: parts.editor, text: null, blocked: blocked(parts), plan: null, undo: null, headers: null, settings: null}; states.set(panel, state)
    field(panel, 'variable').value = ''; field(panel, 'value').value = ''
  }
  if (state.text !== parts.editor.value || state.blocked !== blocked(parts)) {
    invalidate(panel, state, 'Choose measurements and output names, then preview.'); state.text = parts.editor.value; state.blocked = blocked(parts)
  }
  try {
    const headers = parseTaskCsv(parts.editor.value, separator(parts)).headers
    if (JSON.stringify(headers) !== JSON.stringify(state.headers)) {
      const legend = document.createElement('legend'); legend.textContent = 'Measurement columns'; field(panel, 'measures').replaceChildren(legend)
      for (const name of headers) { const label = document.createElement('label'), input = document.createElement('input'); input.type = 'checkbox'; input.setAttribute('data-table-reshape-measure', ''); input.value = name; label.textContent = name + ' '; label.append(input); field(panel, 'measures').append(label) }
      state.headers = headers
    }
  } catch (error) { field(panel, 'measures').replaceChildren(); state.headers = null; invalidate(panel, state, String(error.message || error)) }
  const currentSettings = settings(panel)
  if (state.settings !== null && state.settings !== currentSettings) invalidate(panel, state, 'Reshape settings changed. Preview again.')
  state.settings = currentSettings
  for (const input of [...panel.querySelectorAll('[data-table-reshape-measure]'), field(panel, 'variable'), field(panel, 'value')]) input.disabled = blocked(parts)
  button(panel, 'review').disabled = blocked(parts) || !state.headers
  button(panel, 'apply').disabled = blocked(parts) || !state.plan
  button(panel, 'undo').disabled = blocked(parts) || !state.undo
}
export function changeTableReshape(parts) {
  const panel = parts?.surface.querySelector('[data-table-reshape]'), state = states.get(panel)
  if (state) { invalidate(panel, state, 'Reshape settings changed. Preview again.'); state.settings = settings(panel) }
}
export function actTableReshape(parts, action) {
  if (!parts || !supported(parts)) return
  syncTableReshape(parts)
  const panel = parts.surface.querySelector('[data-table-reshape]'), state = states.get(panel), kind = action.dataset.action.slice('source-table-reshape-'.length)
  if (blocked(parts)) return
  if (kind === 'cancel') { clear(panel, state, 'Preview cancelled. Draft unchanged.'); return }
  const args = () => [parts.editor.value, separator(parts), [...panel.querySelectorAll('[data-table-reshape-measure]')].filter(input => input.checked).map(input => input.value), field(panel, 'variable').value, field(panel, 'value').value]
  function replace(output, restoredSelection) {
    const before = parts.editor.value, selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
    try {
      parts.editor.setRangeText(output, 0, before.length, 'select')
      if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared table.')
      if (restoredSelection) parts.editor.setSelectionRange(...restoredSelection)
      state.text = output; parts.editor.dispatchEvent(new Event('input', {bubbles: true}))
      if (parts.editor.value !== output) throw new Error('Draft changed while applying; original draft restored.')
      parts.editor.focus()
    } catch (error) {
      parts.editor.value = before; parts.editor.setSelectionRange(...selection); state.text = before
      syncTableReshape(parts); throw error
    }
    return selection
  }
  try {
    if (kind === 'review') {
      state.plan = prepareTableReshape(...args()); field(panel, 'preview').textContent = JSON.stringify(state.plan.preview, null, 2)
      field(panel, 'status').textContent = `${state.plan.count} output records, ${state.plan.preview.headers.length} columns, ${state.plan.bytes} UTF-8 bytes. All records shown. Review before Apply.`; button(panel, 'apply').disabled = false
    } else if (kind === 'apply') {
      const output = applyTableReshape(state.plan, ...args()), before = parts.editor.value
      const selection = replace(output)
      state.undo = {before, after: output, selection}; clear(panel, state, 'Reshape applied to unsaved draft. Save explicitly to persist.'); button(panel, 'undo').disabled = false
    } else if (kind === 'undo') {
      if (!state.undo || parts.editor.value !== state.undo.after) throw new Error('Draft changed; scoped undo is unavailable.')
      replace(state.undo.before, state.undo.selection); state.undo = null; clear(panel, state, 'Original draft and selection restored.'); button(panel, 'undo').disabled = true
    }
  } catch (error) { invalidate(panel, state, String(error.message || error)) }
}
