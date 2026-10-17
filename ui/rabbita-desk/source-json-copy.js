import { parseJsonDocument, resolveJsonPointer } from './source-json-values.js'
import { prepareJsonInsertion } from './source-json-insertion.js'

// Snapshot the original value before insertion, including when copying an
// ancestor into its descendant. No decoding/re-encoding of the value occurs.
export function prepareJsonCopy(text, pointer, destination, key, position) {
  const root = parseJsonDocument(text), source = resolveJsonPointer(root, pointer)
  const target = resolveJsonPointer(root, destination)
  const raw = text.slice(source.start, source.end)
  const insertion = prepareJsonInsertion(text, destination, key, position, raw)
  const copiedPointer = destination + '/' + (target.type === 'array' ? position : key.replaceAll('~', '~0').replaceAll('/', '~1'))
  const copied = resolveJsonPointer(parseJsonDocument(insertion.output), copiedPointer)
  if (insertion.output.slice(copied.start, copied.end) !== raw) throw new Error('Copied value did not retain its exact text.')
  return Object.freeze({ text, pointer, destination, key, position, copiedPointer, output: insertion.output,
    raw, before: insertion.before, after: insertion.after })
}

export function applyJsonCopy(plan, text, pointer, destination, key, position) {
  if (!plan || plan.text !== text || plan.pointer !== pointer || plan.destination !== destination || plan.key !== key || plan.position !== position) {
    throw new Error('Draft, source or destination changed. Preview the copy again.')
  }
  return plan.output
}
