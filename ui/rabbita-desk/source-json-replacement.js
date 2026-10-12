import { parseJsonDocument, resolveJsonPointer } from './source-json-values.js'

// One exact source-range edit. Never round-trip JSON through JavaScript values.
export function prepareJsonReplacement(text, pointer, replacementInput) {
  const node = resolveJsonPointer(parseJsonDocument(text), pointer)
  let replacementNode
  try { replacementNode = parseJsonDocument(replacementInput) }
  catch (error) { throw new Error(`Replacement must be one strict JSON value: ${error.message}`) }
  const replacement = replacementInput.slice(replacementNode.start, replacementNode.end)
  const before = text.slice(node.start, node.end)
  const output = text.slice(0, node.start) + replacement + text.slice(node.end)
  // Combined depth, node and character limits matter even if each input fits.
  try { parseJsonDocument(output) }
  catch (error) { throw new Error(`Result cannot be explored: ${error.message}`) }
  return Object.freeze({ text, pointer, replacementInput, before, replacement, output,
    start: node.start, end: node.end, beforeType: node.type, afterType: replacementNode.type,
    changed: before !== replacement })
}

export function applyJsonReplacement(plan, text, pointer, replacementInput) {
  if (!plan || plan.text !== text || plan.pointer !== pointer || plan.replacementInput !== replacementInput) {
    throw new Error('Draft, displayed target or replacement changed. Preview the replacement again.')
  }
  return plan.output
}
