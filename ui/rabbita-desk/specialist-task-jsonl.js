import { parseTaskCsv, taskCsvLimits } from './specialist-task-csv.js'

// Decode only flat string records. In particular, duplicate keys, coercion and
// flattening must not silently erase distinctions in imported task inputs.
function stringRecord(line, number) {
  let offset = 0
  const fields = new Map()
  const bad = () => { throw new Error(`JSONL line ${number} needs one nonempty object with distinct string keys and string values.`) }
  const space = () => { while (offset < line.length && /[ \t\r]/.test(line[offset])) offset++ }
  const take = char => { space(); if (line[offset++] !== char) bad() }
  const token = () => {
    space()
    const pattern = /"(?:[^"\\\u0000-\u001f]|\\(?:["\\/bfnrt]|u[0-9a-fA-F]{4}))*"/y
    pattern.lastIndex = offset
    const match = pattern.exec(line)
    if (!match) bad()
    offset = pattern.lastIndex
    return JSON.parse(match[0])
  }
  take('{')
  while (true) {
    const key = token(); take(':'); const value = token()
    if (fields.has(key)) bad()
    fields.set(key, value)
    if (fields.size > taskCsvLimits.columns) throw new Error('JSONL supports at most 32 fields.')
    space()
    if (line[offset] === '}') { offset++; break }
    take(',')
  }
  space(); if (offset !== line.length) bad()
  return fields
}

export function parseTaskJsonl(source) {
  if (typeof source !== 'string' || source.length > taskCsvLimits.bytes || new TextEncoder().encode(source).length > taskCsvLimits.bytes) throw new Error('Choose UTF-8 JSONL no larger than 512 KiB.')
  if (source.includes('\0')) throw new Error('JSONL cannot contain NUL characters.')
  const lines = source.replace(/^\uFEFF/, '').split('\n')
  if (lines.at(-1) === '') lines.pop()
  if (!lines.length || lines.length > taskCsvLimits.rows) throw new Error('JSONL needs 1 to 100 task records, one per line.')
  const records = lines.map((line, index) => stringRecord(line, index + 1))
  const headers = [...records[0].keys()]
  for (const [index, record] of records.entries()) {
    if (record.size !== headers.length || headers.some(key => !record.has(key))) throw new Error(`JSONL line ${index + 1} has different fields. Every record must name the same fields; use explicit empty strings for blank inputs.`)
  }
  const quote = value => '"' + value.replaceAll('"', '""') + '"'
  // A lossless table of decoded strings integrates with ordinary task editing
  // and checkpoints. Original JSON spelling/whitespace is not an archive.
  const csvSource = [headers, ...records.map(record => headers.map(key => record.get(key)))].map(row => row.map(quote).join(',')).join('\n') + '\n'
  const table = parseTaskCsv(csvSource)
  return { ...table, source: csvSource }
}
