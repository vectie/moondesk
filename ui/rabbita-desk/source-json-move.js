import { parseJsonDocument, resolveJsonPointer, jsonPointerTokens } from './source-json-values.js'
import { prepareJsonRemoval } from './source-json-removal.js'
import { prepareJsonInsertion } from './source-json-insertion.js'

const pointerOf = tokens => tokens.map(key => '/' + key.replaceAll('~', '~0').replaceAll('/', '~1')).join('')

// Both locations refer to the original draft. Position is in the destination
// after removal, making same-array reorder unambiguous (0 means first).
export function prepareJsonMove(text, pointer, destination, key, position) {
  if (!pointer) throw new Error('Choose a member or item; the document root cannot be moved.')
  const root = parseJsonDocument(text), source = resolveJsonPointer(root, pointer)
  const target = resolveJsonPointer(root, destination)
  if (!['object', 'array'].includes(target.type)) throw new Error('Destination must be an object or array.')
  if (destination === pointer || destination.startsWith(pointer + '/')) throw new Error('A value cannot move into itself or its descendant.')
  const from = jsonPointerTokens(pointer), into = jsonPointerTokens(destination)
  const parentTokens = from.slice(0, -1), parent = resolveJsonPointer(root, pointerOf(parentTokens))
  // Deleting an earlier array sibling shifts paths to later destinations.
  if (parent.type === 'array' && into.length > parentTokens.length &&
      parentTokens.every((part, index) => part === into[index]) && Number(into[parentTokens.length]) > Number(from.at(-1))) {
    into[parentTokens.length] = String(Number(into[parentTokens.length]) - 1)
  }
  const targetPointer = pointerOf(into), removal = prepareJsonRemoval(text, pointer)
  const insertion = prepareJsonInsertion(removal.output, targetPointer, key, position, text.slice(source.start, source.end))
  if (insertion.output === text) throw new Error('No change. Choose a different position or destination.')
  const movedPointer = targetPointer + '/' + (target.type === 'array' ? position : key.replaceAll('~', '~0').replaceAll('/', '~1'))
  const outputRoot = parseJsonDocument(insertion.output), moved = resolveJsonPointer(outputRoot, movedPointer)
  if (insertion.output.slice(moved.start, moved.end) !== text.slice(source.start, source.end)) throw new Error('Moved value did not retain its exact text.')
  return Object.freeze({ text, pointer, destination, key, position, targetPointer, movedPointer, output: insertion.output,
    sourceBefore: removal.before, sourceAfter: removal.after, destinationBefore: insertion.before, destinationAfter: insertion.after })
}

export function applyJsonMove(plan, text, pointer, destination, key, position) {
  if (!plan || plan.text !== text || plan.pointer !== pointer || plan.destination !== destination || plan.key !== key || plan.position !== position) {
    throw new Error('Draft, source or destination changed. Preview the move again.')
  }
  return plan.output
}
