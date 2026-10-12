import { parseJsonDocument } from './source-json-values.js'

export const JSON_COMPARISON_LIMIT = 1000
export const JSON_COMPARISON_RULES = Object.freeze({
  objects: 'Match decoded member names; ignore member order.',
  arrays: 'Compare zero-based positions; do not infer moves or record identities.',
  strings: 'Compare decoded values; ignore equivalent escape spelling.',
  numbers: 'Compare exact JSON tokens; do not round or infer numeric equivalence.',
})
const childPointer = (pointer, key) => `${pointer}/${key.replace(/~/g, '~0').replace(/\//g, '~1')}`

function checkedDocument(text, label) {
  let root
  try { root = parseJsonDocument(text) }
  catch (error) { throw new Error(`${label}: ${error.message}`) }
  const visit = (node, pointer) => {
    const seen = new Set()
    for (const child of node.children) {
      const next = childPointer(pointer, child.key)
      if (node.type === 'object' && seen.has(child.key)) {
        throw new Error(`${label}: duplicate object member at ${JSON.stringify(next)}. Rename or remove the duplicate before comparing.`)
      }
      seen.add(child.key); visit(child.node, next)
    }
  }
  visit(root, '')
  return root
}

// Compare ranges without converting JSON numbers into JavaScript numbers.
// Changes are disjoint subtrees, not an executable JSON Patch or merge plan.
export function compareJsonDocuments(beforeText, afterText) {
  const beforeRoot = checkedDocument(beforeText, 'Reference JSON')
  const afterRoot = checkedDocument(afterText, 'Current draft')
  const changes = []
  let reportUnits = 0
  const snapshot = (node, text) => node ? { type: node.type, json: text.slice(node.start, node.end), start: node.start, end: node.end } : null
  const add = (pointer, before, after) => {
    if (changes.length >= JSON_COMPARISON_LIMIT) throw new Error('Comparison exceeds 1,000 differences. Compare smaller JSON documents; no partial report was produced.')
    reportUnits += pointer.length + (before ? before.end - before.start : 0) + (after ? after.end - after.start : 0)
    if (reportUnits > 1_000_000) throw new Error('Comparison paths and changed values exceed 1,000,000 UTF-16 units. Compare smaller JSON documents; no partial report was produced.')
    changes.push({ kind: !before ? 'added' : !after ? 'removed' : 'changed', pointer,
      before: snapshot(before, beforeText), after: snapshot(after, afterText) })
  }
  const visit = (before, after, pointer) => {
    if (!before || !after || before.type !== after.type) { add(pointer, before, after); return }
    if (before.type === 'object') {
      const oldMembers = new Map(before.children.map(child => [child.key, child.node]))
      const newMembers = new Map(after.children.map(child => [child.key, child.node]))
      for (const [key, node] of oldMembers) visit(node, newMembers.get(key), childPointer(pointer, key))
      for (const [key, node] of newMembers) if (!oldMembers.has(key)) visit(null, node, childPointer(pointer, key))
    } else if (before.type === 'array') {
      for (let index = 0; index < Math.max(before.children.length, after.children.length); index += 1) {
        visit(before.children[index]?.node, after.children[index]?.node, childPointer(pointer, String(index)))
      }
    } else {
      const left = beforeText.slice(before.start, before.end), right = afterText.slice(after.start, after.end)
      const same = before.type === 'string' ? JSON.parse(left) === JSON.parse(right) : left === right
      if (!same) add(pointer, before, after)
    }
  }
  visit(beforeRoot, afterRoot, '')
  const counts = { added: 0, removed: 0, changed: 0, total: changes.length }
  for (const change of changes) counts[change.kind] += 1
  return { schema: 'moondesk.json-comparison.v1', rules: { ...JSON_COMPARISON_RULES }, counts, changes }
}

export function jsonComparisonReport(comparison, source) {
  return JSON.stringify({ ...comparison, source: { workspaceId: source.workspaceId || '', path: source.sourcePath || '',
    before: 'Pasted reference JSON', after: 'Current unsaved editor draft',
    offsets: 'Zero-based UTF-16 units in each input; not on-disk byte offsets',
    scope: 'Changed subtrees only. Read-only comparison, not a patch, merge, saved version or acceptance receipt.' } }, null, 2) + '\n'
}
