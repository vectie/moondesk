import { parseJsonDocument, resolveJsonPointer } from './source-json-values.js'

// Insert only new bytes; existing whitespace, keys and number tokens stay exact.
export function prepareJsonInsertion(text, pointer, key, position, valueInput) {
  const node = resolveJsonPointer(parseJsonDocument(text), pointer)
  if (!['object', 'array'].includes(node.type)) throw new Error('Select an object or array to insert into.')
  if (!/^(?:0|[1-9]\d*)$/.test(position) || Number(position) > node.children.length) {
    throw new Error(`Position must be an integer from 0 to ${node.children.length}, without leading zeroes.`)
  }
  if (node.type === 'object' && node.children.some(child => child.key === key)) {
    throw new Error('This object already has that decoded key. Choose a new key or replace the existing value.')
  }
  let value
  try { value = parseJsonDocument(valueInput) }
  catch (error) { throw new Error(`Insertion must be one strict JSON value: ${error.message}`) }
  const raw = valueInput.slice(value.start, value.end)
  const member = node.type === 'object' ? `${JSON.stringify(key)}: ${raw}` : raw
  const index = Number(position)
  const start = index < node.children.length ? node.children[index].memberStart
    : node.children.length ? node.children.at(-1).node.end : node.start + 1
  const insertion = index < node.children.length ? `${member},` : `${node.children.length ? ',' : ''}${member}`
  const output = text.slice(0, start) + insertion + text.slice(start)
  try { parseJsonDocument(output) }
  catch (error) { throw new Error(`Result cannot be explored: ${error.message}`) }
  return Object.freeze({ text, pointer, key, position, valueInput, start, insertion, output,
    before: text.slice(node.start, node.end), after: output.slice(node.start, node.end + insertion.length) })
}

export function applyJsonInsertion(plan, text, pointer, key, position, valueInput) {
  if (!plan || plan.text !== text || plan.pointer !== pointer || plan.key !== key ||
      plan.position !== position || plan.valueInput !== valueInput) {
    throw new Error('Draft, target or insertion changed. Preview the insertion again.')
  }
  return plan.output
}
