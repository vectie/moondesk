import { prepareJsonReplacement, applyJsonReplacement } from './source-json-replacement.js'

const edits = new WeakMap()
const find = (panel, name) => panel.querySelector(`[data-json-${name}]`)
const button = (panel, name) => panel.querySelector(`[data-action="source-json-replace-${name}"]`)
const PREVIEW_SIZE = 4000

export function createJsonReplacementPanel(panel, makeButton) {
  const section = document.createElement('div'); section.setAttribute('data-json-replacement-section', ''); section.hidden = true
  const help = document.createElement('p')
  help.textContent = 'Replace the displayed value with one JSON value. Preview first, then apply to the unsaved draft. Use the source editor Undo/Redo and Save controls.'
  const replacement = document.createElement('textarea'); replacement.setAttribute('data-json-replacement', '')
  replacement.setAttribute('aria-label', 'Replacement JSON value'); replacement.spellcheck = false; replacement.rows = 5
  const status = document.createElement('p'); status.setAttribute('data-json-replacement-status', ''); status.setAttribute('role', 'status')
  const before = document.createElement('pre'); before.setAttribute('data-json-replacement-before', ''); before.setAttribute('aria-label', 'Before replacement')
  const after = document.createElement('pre'); after.setAttribute('data-json-replacement-after', ''); after.setAttribute('aria-label', 'After replacement')
  for (const preview of [before, after]) { preview.style.maxHeight = '12rem'; preview.style.overflow = 'auto'; preview.style.whiteSpace = 'pre-wrap' }
  section.append(help, replacement, makeButton('replace-review', 'Preview replacement'),
    makeButton('replace-apply', 'Apply replacement to draft'), makeButton('replace-cancel', 'Cancel replacement'), status, before, after)
  panel.append(section)
}

export function resetJsonReplacement(panel) {
  edits.delete(panel)
  find(panel, 'replacement').value = ''
  find(panel, 'replacement-section').hidden = true
}

function clearReview(panel, edit, message) {
  edit.plan = null
  find(panel, 'replacement-before').textContent = ''; find(panel, 'replacement-after').textContent = ''
  button(panel, 'apply').disabled = true
  find(panel, 'replacement-status').textContent = message
}

export function syncJsonReplacement(parts, panel, state) {
  let edit = edits.get(panel)
  if (edit && (edit.identity !== state.identity || edit.pointer !== state.pointer)) {
    edits.delete(panel); edit = null
    find(panel, 'replacement').value = ''
  }
  find(panel, 'replacement-section').hidden = !edit
  if (edit && (edit.text !== state.text || edit.disabled !== parts.editor.disabled)) {
    clearReview(panel, edit, 'Draft or editor availability changed. Preview the replacement again.')
    edit.text = state.text; edit.disabled = parts.editor.disabled
  }
  const unavailable = parts.editor.disabled || !state.node
  find(panel, 'replacement').disabled = unavailable
  button(panel, 'review').disabled = unavailable
  button(panel, 'apply').disabled = unavailable || !edit?.plan?.changed
  button(panel, 'cancel').disabled = parts.editor.disabled
}

export function changeJsonReplacement(parts) {
  if (!parts) return
  const panel = parts.surface.querySelector('[data-json-explorer]')
  const edit = edits.get(panel)
  if (edit) clearReview(panel, edit, 'Replacement changed. Preview it before applying.')
}

export function actJsonReplacement(parts, panel, state, kind) {
  let edit = edits.get(panel)
  if (kind === 'open' && state.node) {
    edit = { identity: state.identity, pointer: state.pointer, text: state.text, disabled: false, plan: null }
    edits.set(panel, edit)
    find(panel, 'replacement').value = state.text.slice(state.node.start, state.node.end)
    clearReview(panel, edit, `Editing ${state.pointer || '(root)'}. Enter a replacement, then preview it.`)
    syncJsonReplacement(parts, panel, state); find(panel, 'replacement').focus()
    return
  }
  if (!edit || edit.identity !== state.identity || edit.pointer !== state.pointer) return
  if (kind === 'cancel') {
    edits.delete(panel); find(panel, 'replacement').value = ''
    clearReview(panel, edit, ''); find(panel, 'replacement-section').hidden = true
    return
  }
  if (!state.node) return
  try {
    const replacementInput = find(panel, 'replacement').value
    if (kind === 'review') {
      const plan = prepareJsonReplacement(parts.editor.value, state.pointer, replacementInput)
      edit.plan = plan
      find(panel, 'replacement-before').textContent = `Before (${plan.beforeType}):\n${plan.before.slice(0, PREVIEW_SIZE)}`
      find(panel, 'replacement-after').textContent = `After (${plan.afterType}):\n${plan.replacement.slice(0, PREVIEW_SIZE)}`
      const shortened = Math.max(plan.before.length, plan.replacement.length) > PREVIEW_SIZE
      find(panel, 'replacement-status').textContent = plan.changed
        ? `Preview for ${state.pointer || '(root)'}: ${plan.before.length} → ${plan.replacement.length} UTF-16 units. Surrounding text is unchanged.` +
          (shortened ? ' Preview shortened at 4,000 units per value; apply uses the full replacement. Inspect the editor and replacement field for complete values.' : '')
        : 'No change: replacement tokens already match the displayed value.'
      button(panel, 'apply').disabled = !plan.changed
    } else if (kind === 'apply') {
      const plan = edit.plan
      const output = applyJsonReplacement(plan, parts.editor.value, state.pointer, replacementInput)
      if (!plan.changed) return
      // Match the established completion path: one input event enters the
      // existing EditDraft reducer and its history; no separate file write.
      edits.delete(panel); find(panel, 'replacement').value = ''
      clearReview(panel, edit, ''); find(panel, 'replacement-section').hidden = true
      const selection = [parts.editor.selectionStart, parts.editor.selectionEnd, parts.editor.selectionDirection]
      try {
        parts.editor.setRangeText(plan.replacement, plan.start, plan.end, 'select')
        if (parts.editor.value !== output) throw new Error('Editor did not retain the prepared replacement.')
      } catch (error) {
        parts.editor.value = plan.text; parts.editor.setSelectionRange(...selection)
        edits.set(panel, edit); find(panel, 'replacement').value = replacementInput
        find(panel, 'replacement-section').hidden = false
        throw error
      }
      parts.editor.dispatchEvent(new Event('input', { bubbles: true }))
      parts.editor.focus()
      find(panel, 'status').textContent = `Replaced ${state.pointer || '(root)'} in the unsaved draft. Use Undo to restore it or Save when ready.`
    }
  } catch (error) {
    clearReview(panel, edit, error.message)
  }
}
