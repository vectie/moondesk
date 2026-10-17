import { prepareJsonRemoval, applyJsonRemoval } from './source-json-removal.js'
const plans = new WeakMap()
const field = panel => panel.querySelector('[data-json-remove-preview]')
const applyButton = panel => panel.querySelector('[data-action="source-json-remove-apply"]')
export function createJsonRemovalPanel(panel, button) {
  panel.append(button('remove-review', 'Preview removal of displayed member or item'), button('remove-apply', 'Remove from draft'), button('remove-cancel', 'Cancel removal'))
  const preview = document.createElement('pre'); preview.setAttribute('data-json-remove-preview', '')
  preview.setAttribute('aria-label', 'JSON removal preview'); preview.setAttribute('role', 'status'); preview.style.whiteSpace = 'pre-wrap'; panel.append(preview)
  applyButton(panel).disabled = true
}
export function resetJsonRemoval(panel) { plans.delete(panel); field(panel).textContent = ''; applyButton(panel).disabled = true }
export function syncJsonRemoval(parts, panel, state) {
  const saved = plans.get(panel)
  if (saved && (saved.identity !== state.identity || saved.plan.text !== state.text || saved.plan.pointer !== state.pointer || parts.editor.disabled)) resetJsonRemoval(panel)
  panel.querySelector('[data-action="source-json-remove-review"]').disabled = parts.editor.disabled || !state.node || !state.pointer
  applyButton(panel).disabled = parts.editor.disabled || !plans.has(panel)
}
export function actJsonRemoval(parts, panel, state, kind) {
  try {
    if (kind === 'cancel') { resetJsonRemoval(panel); return }
    if (kind === 'review') {
      const plan = prepareJsonRemoval(parts.editor.value, state.pointer)
      plans.set(panel, { identity: state.identity, plan })
      field(panel).textContent = `Remove ${state.pointer} from the unsaved draft. Array positions after it shift down.\nBefore:\n${plan.before.slice(0, 4000)}\nAfter:\n${plan.after.slice(0, 4000)}` + (plan.before.length > 4000 ? '\nPreview shortened to 4,000 units; apply removes the complete member/item.' : '')
      applyButton(panel).disabled = false
    } else if (kind === 'apply') {
      const saved = plans.get(panel)
      if (!saved || saved.identity !== state.identity) throw new Error('Preview the removal first.')
      const plan = saved.plan, output = applyJsonRemoval(plan, parts.editor.value, state.pointer)
      const selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try {
        parts.editor.setRangeText('', plan.start, plan.end, 'select')
        if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared removal.')
      } catch (error) { parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection); throw error }
      resetJsonRemoval(panel)
      state.pointer = plan.parentPointer
      panel.querySelector('[data-json-pointer]').value = state.pointer
      parts.editor.dispatchEvent(new Event('input', { bubbles: true })); parts.editor.focus()
      panel.querySelector('[data-json-status]').textContent = 'Removed from the unsaved draft. Use Undo or Save when ready.'
    }
  } catch (error) { resetJsonRemoval(panel); field(panel).textContent = error.message }
}
