import { parseTaskCsv } from './specialist-task-csv.js'

// Exact text tuples: never trim, coerce, or join keys with an ambiguous separator.
export function prepareDuplicateKeys(text, separator, headers, policy) {
  const table = parseTaskCsv(text, separator)
  if (!Array.isArray(headers) || !headers.length || new Set(headers).size !== headers.length || headers.some(h => !table.headers.includes(h))) throw new Error('Select one or more exact, distinct key headers.')
  if (!['first', 'last'].includes(policy)) throw new Error('Choose keep first or keep last explicitly.')
  const indices = headers.map(h => table.headers.indexOf(h)), groups = new Map(), blank = []
  for (const row of table.rows) {
    if (row.cells.length !== table.headers.length) throw new Error(`Record ${row.number} has a different width from its header.`)
    const key = indices.map(i => row.cells[i])
    if (key.some(value => !value.trim())) { blank.push(row); continue }
    const encoded = JSON.stringify(key)
    if (!groups.has(encoded)) groups.set(encoded, {key, records: []})
    groups.get(encoded).records.push(row)
  }
  const duplicates = [...groups.values()].filter(g => g.records.length > 1), removed = new Set()
  for (const group of duplicates) {
    group.keep = group.records[policy === 'first' ? 0 : group.records.length - 1].number
    for (const row of group.records) if (row.number !== group.keep) removed.add(row.number)
  }
  const retained = table.rows.filter(row => !removed.has(row.number))
  const quote = value => '"' + value.replaceAll('"', '""') + '"'
  // HTML textarea API values normalize newlines to LF, including quoted cells.
  const output = [table.headers, ...retained.map(r => r.cells)].map(row => row.map(quote).join(separator)).join('\n') + '\n'
  const parsed = parseTaskCsv(output, separator)
  if (JSON.stringify(parsed.rows.map(r => r.cells)) !== JSON.stringify(retained.map(r => r.cells))) throw new Error('Prepared table failed round-trip.')
  return {text, separator, headers, policy, output, preview: {headers: table.headers, duplicates, unresolvedBlankKeys: blank, retained, removed: table.rows.filter(r => removed.has(r.number))}}
}
export function applyDuplicateKeys(plan, ...args) {
  if (!plan) throw new Error('Preview duplicate keys first.')
  const current = prepareDuplicateKeys(...args)
  if (JSON.stringify(plan) !== JSON.stringify(current)) throw new Error('Draft or key settings changed. Preview again.')
  return current.output
}
