import { prepareJsonOrder, applyJsonOrder } from './source-json-order.js'

const edits = new WeakMap()
const names = ['field', 'type', 'direction', 'missing']
const field = (panel, name) => panel.querySelector(`[data-json-order-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-json-order-${name}"]`)

export function createJsonOrderPanel(panel, makeButton) {
  panel.append(makeButton('order-open', 'Order displayed record array'))
  const section = document.createElement('div'); section.setAttribute('data-json-order-section', ''); section.hidden = true
  const help = document.createElement('p')
  help.textContent = 'Choose a relative field pointer, type (number, string or boolean), direction (asc or desc), and missing-field policy (error, first or last). Null and wrong types refuse. Numbers compare exactly; strings use case-sensitive UTF-16 ordering. Ties retain their original order. Preview, then apply to the unsaved draft.'
  section.append(help)
  for (const [name, label] of [['field', 'Relative field JSON Pointer, e.g. /priority'], ['type', 'Field type: number, string or boolean'], ['direction', 'Order: asc or desc'], ['missing', 'Missing field: error, first or last']]) {
    const item = document.createElement('input'); item.setAttribute(`data-json-order-${name}`, ''); item.setAttribute('aria-label', label); item.placeholder = label; section.append(item)
  }
  section.append(makeButton('order-review', 'Preview ordering'), makeButton('order-apply', 'Order in draft'), makeButton('order-cancel', 'Cancel ordering'))
  for (const name of ['status', 'preview']) {
    const item = document.createElement(name === 'status' ? 'p' : 'pre'); item.setAttribute(`data-json-order-${name}`, '')
    if (name === 'status') item.setAttribute('role', 'status')
    else { item.style.maxHeight = '20rem'; item.style.overflow = 'auto'; item.style.whiteSpace = 'pre-wrap' }
    section.append(item)
  }
  panel.append(section)
}
export function resetJsonOrder(panel) {
  edits.delete(panel); field(panel, 'section').hidden = true; button(panel, 'apply').disabled = true
  for (const name of names) field(panel, name).value = ''
}
function clear(panel, edit, message) {
  edit.plan = null; button(panel, 'apply').disabled = true; field(panel, 'status').textContent = message; field(panel, 'preview').textContent = ''
}
export function syncJsonOrder(parts, panel, state) {
  let edit = edits.get(panel)
  if (edit && (edit.identity !== state.identity || edit.pointer !== state.pointer)) { resetJsonOrder(panel); edit = null }
  if (edit && (edit.text !== state.text || edit.disabled !== parts.editor.disabled)) {
    clear(panel, edit, 'Draft or editor availability changed. Preview again.'); edit.text = state.text; edit.disabled = parts.editor.disabled
  }
  const unavailable = parts.editor.disabled || state.node?.type !== 'array'
  button(panel, 'open').disabled = unavailable; field(panel, 'section').hidden = !edit
  for (const name of names) field(panel, name).disabled = unavailable
  button(panel, 'review').disabled = unavailable; button(panel, 'apply').disabled = unavailable || !edit?.plan?.changed
}
export function changeJsonOrder(parts) {
  const panel = parts?.surface.querySelector('[data-json-explorer]'), edit = edits.get(panel)
  if (edit) clear(panel, edit, 'Ordering settings changed. Preview again before applying.')
}
export function actJsonOrder(parts, panel, state, kind) {
  let edit = edits.get(panel)
  if (kind === 'open' && state.node?.type === 'array') {
    edit = { identity: state.identity, pointer: state.pointer, text: state.text, disabled: parts.editor.disabled, plan: null }; edits.set(panel, edit)
    clear(panel, edit, 'Choose all four settings explicitly. The draft is unchanged.'); syncJsonOrder(parts, panel, state); field(panel, 'field').focus(); return
  }
  if (!edit || edit.identity !== state.identity || edit.pointer !== state.pointer) return
  if (kind === 'cancel') { resetJsonOrder(panel); return }
  try {
    const args = [parts.editor.value, state.pointer, ...names.map(name => field(panel, name).value)]
    if (kind === 'review') {
      const plan = prepareJsonOrder(...args); edit.plan = plan
      field(panel, 'preview').textContent = `Before:\n${plan.before.slice(0, 4000)}\nAfter:\n${plan.after.slice(0, 4000)}`
      field(panel, 'status').textContent = `${plan.changed ? 'Ready to order' : 'Already in this order; no edit needed'}. Original zero-based item indexes in output order: ${plan.originalIndexes.slice(0, 100).join(', ') || '(empty)'}.` +
        (plan.originalIndexes.length > 100 ? ' Index list shortened at 100 items.' : '') +
        (Math.max(plan.before.length, plan.after.length) > 4000 ? ' Before/after shortened at 4,000 units; apply uses the complete draft.' : '')
      button(panel, 'apply').disabled = !plan.changed
    } else if (kind === 'apply') {
      const plan = edit.plan, output = applyJsonOrder(plan, ...args), selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try { parts.editor.setRangeText(output, 0, parts.editor.value.length, 'select'); if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared ordering.') }
      catch (error) { parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error }
      resetJsonOrder(panel); state.page = 0
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      panel.querySelector('[data-json-status]').textContent = `Ordered ${state.pointer || '(root)'} in the unsaved draft. Inspect the result and use the existing Save controls when ready.`
    }
  } catch (error) { clear(panel, edit, error.message) }
}
