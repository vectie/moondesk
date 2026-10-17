import { parseJsonDocument, resolveJsonPointer } from './source-json-values.js'

export function prepareJsonRemoval(text, pointer) {
  if (!pointer) throw new Error('Choose a member or array item; the document root cannot be removed.')
  const root = parseJsonDocument(text), node = resolveJsonPointer(root, pointer)
  const parentPointer = pointer.slice(0, pointer.lastIndexOf('/'))
  const parent = resolveJsonPointer(root, parentPointer)
  const index = parent.children.findIndex(child => child.node === node)
  const child = parent.children[index]
  // Include the following separator, or the preceding separator for the last child.
  // Every surviving value token remains byte-for-byte unchanged.
  const start = index === parent.children.length - 1 && index > 0 ? parent.children[index - 1].node.end : child.memberStart
  const end = index < parent.children.length - 1 ? parent.children[index + 1].memberStart : node.end
  const output = text.slice(0, start) + text.slice(end)
  parseJsonDocument(output)
  return Object.freeze({ text, pointer, parentPointer, start, end, output,
    before: text.slice(parent.start, parent.end), after: output.slice(parent.start, parent.end - (end - start)) })
}

export function applyJsonRemoval(plan, text, pointer) {
  if (!plan || plan.text !== text || plan.pointer !== pointer) throw new Error('Draft or target changed. Preview the removal again.')
  return plan.output
}
