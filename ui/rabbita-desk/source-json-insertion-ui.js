import { prepareJsonInsertion, applyJsonInsertion } from './source-json-insertion.js'

const edits = new WeakMap()
const field = (panel, name) => panel.querySelector(`[data-json-insert-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-json-insert-${name}"]`)

export function createJsonInsertionPanel(panel, makeButton) {
  const section = document.createElement('div'); section.setAttribute('data-json-insert-section', ''); section.hidden = true
  const help = document.createElement('p')
  help.textContent = 'Insert one member or item into the displayed container. Position is zero-based; the child count appends. Object keys are plain text, including empty keys; existing decoded keys are rejected. Preview, then apply to the unsaved draft and use Undo/Redo or Save.'
  section.append(help)
  for (const [name, tag, label] of [['key', 'input', 'New object key (plain text)'], ['position', 'input', 'Insertion position (zero-based)'], ['value', 'textarea', 'Inserted JSON value']]) {
    const item = document.createElement(tag); item.setAttribute(`data-json-insert-${name}`, ''); item.setAttribute('aria-label', label)
    item.placeholder = label; item.spellcheck = false; section.append(item)
  }
  section.append(makeButton('insert-review', 'Preview insertion'), makeButton('insert-apply', 'Apply insertion to draft'), makeButton('insert-cancel', 'Cancel insertion'))
  for (const name of ['status', 'before', 'after']) {
    const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-json-insert-${name}`, '')
    if (name === 'status') item.setAttribute('role', 'status')
    else { item.setAttribute('aria-label', `${name} insertion`); item.style.maxHeight = '12rem'; item.style.overflow = 'auto'; item.style.whiteSpace = 'pre-wrap' }
    section.append(item)
  }
  panel.append(section)
}

export function resetJsonInsertion(panel) {
  edits.delete(panel); field(panel, 'section').hidden = true
  for (const name of ['key', 'position', 'value']) field(panel, name).value = ''
}

function clear(panel, edit, message) {
  edit.plan = null; button(panel, 'apply').disabled = true
  field(panel, 'status').textContent = message
  field(panel, 'before').textContent = ''; field(panel, 'after').textContent = ''
}

export function syncJsonInsertion(parts, panel, state) {
  let edit = edits.get(panel)
  if (edit && (edit.identity !== state.identity || edit.pointer !== state.pointer)) { resetJsonInsertion(panel); edit = null }
  if (edit && (edit.text !== state.text || edit.disabled !== parts.editor.disabled)) {
    clear(panel, edit, 'Draft or editor availability changed. Preview the insertion again.')
    edit.text = state.text; edit.disabled = parts.editor.disabled
  }
  const unavailable = parts.editor.disabled || !['object', 'array'].includes(state.node?.type)
  field(panel, 'section').hidden = !edit
  for (const name of ['key', 'position', 'value']) field(panel, name).disabled = unavailable || (name === 'key' && state.node?.type !== 'object')
  button(panel, 'review').disabled = unavailable
  button(panel, 'apply').disabled = unavailable || !edit?.plan
}

export function changeJsonInsertion(parts) {
  if (!parts) return
  const panel = parts.surface.querySelector('[data-json-explorer]'), edit = edits.get(panel)
  if (edit) clear(panel, edit, 'Insertion changed. Preview it before applying.')
}

export function actJsonInsertion(parts, panel, state, kind) {
  let edit = edits.get(panel)
  if (kind === 'open' && ['object', 'array'].includes(state.node?.type)) {
    edit = { identity: state.identity, pointer: state.pointer, text: state.text, disabled: parts.editor.disabled, plan: null }
    edits.set(panel, edit)
    field(panel, 'key').value = ''; field(panel, 'position').value = String(state.node.children.length); field(panel, 'value').value = ''
    clear(panel, edit, `Insert into ${state.pointer || '(root)'} (${state.node.type}); positions 0–${state.node.children.length}.`)
    syncJsonInsertion(parts, panel, state); field(panel, state.node.type === 'object' ? 'key' : 'value').focus(); return
  }
  if (!edit || edit.identity !== state.identity || edit.pointer !== state.pointer) return
  if (kind === 'cancel') { resetJsonInsertion(panel); return }
  try {
    const args = [parts.editor.value, state.pointer, field(panel, 'key').value, field(panel, 'position').value, field(panel, 'value').value]
    if (kind === 'review') {
      edit.plan = prepareJsonInsertion(...args)
      field(panel, 'before').textContent = `Before:\n${edit.plan.before.slice(0, 4000)}`
      field(panel, 'after').textContent = `After:\n${edit.plan.after.slice(0, 4000)}`
      field(panel, 'status').textContent = `Preview for ${state.pointer || '(root)'}, position ${args[3]}. Existing bytes remain unchanged.` +
        (edit.plan.after.length > 4000 ? ' Preview shortened at 4,000 units; apply uses the complete value.' : '')
      button(panel, 'apply').disabled = false
    } else if (kind === 'apply') {
      const plan = edit.plan, output = applyJsonInsertion(plan, ...args)
      const selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try {
        parts.editor.setRangeText(plan.insertion, plan.start, plan.start, 'select')
        if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared insertion.')
      } catch (error) { parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error }
      resetJsonInsertion(panel)
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      panel.querySelector('[data-json-status]').textContent = `Inserted at ${state.pointer || '(root)'}, position ${plan.position} in the unsaved draft. Use Undo or Save when ready.`
    }
  } catch (error) { clear(panel, edit, error.message) }
}
