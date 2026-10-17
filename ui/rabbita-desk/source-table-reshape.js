import { parseTaskCsv, taskCsvLimits } from './specialist-task-csv.js'

// Current draft only. All cell values remain literal text; no type inference.
export function prepareTableReshape(text, separator, measures, variableName, valueName) {
  const table = parseTaskCsv(text, separator)
  if (!Array.isArray(measures) || !measures.length || new Set(measures).size !== measures.length || measures.some(name => !table.headers.includes(name))) throw new Error('Select one or more exact, distinct measurement headers.')
  const selected = table.headers.map((name, index) => ({name, index})).filter(item => measures.includes(item.name))
  const identifiers = table.headers.map((name, index) => ({name, index})).filter(item => !measures.includes(item.name))
  for (const row of table.rows) {
    if (row.cells.length !== table.headers.length) throw new Error(`Record ${row.number} has a different width from its header.`)
  }
  const headers = [...identifiers.map(item => item.name), variableName, valueName]
  if ([variableName, valueName].some(name => typeof name !== 'string' || !name.trim() || name.length > 200 || name.includes('\0'))) throw new Error('Enter nonblank variable and value names of at most 200 characters without NUL.')
  if (new Set(headers.map(name => name.trim())).size !== headers.length) throw new Error('Variable and value names must be distinct from each other and retained identifier headers, including surrounding-space collisions.')
  const count = table.rows.length * selected.length
  if (count > taskCsvLimits.rows) throw new Error(`Reshape would produce ${count} records; at most 100 output records are supported. Select fewer measurements.`)
  if (headers.length > taskCsvLimits.columns) throw new Error('Reshape supports at most 32 output columns, including variable and value.')

  // Preflight encoded size before allocating expanded records or serialized output.
  const encoder = new TextEncoder()
  const cellBytes = value => encoder.encode(value).length + 2 + (value.match(/"/g)?.length || 0)
  const framingBytes = headers.length // one-byte separators plus final LF
  let bytes = headers.reduce((total, value) => total + cellBytes(value), framingBytes)
  for (const row of table.rows) {
    const repeatedBytes = identifiers.reduce((total, item) => total + cellBytes(row.cells[item.index]), framingBytes)
    for (const item of selected) bytes += repeatedBytes + cellBytes(item.name) + cellBytes(row.cells[item.index])
  }
  if (bytes > taskCsvLimits.bytes) throw new Error('Reshaped output would exceed 512 KiB. Use fewer measurements or a smaller draft.')
  const rows = []
  for (const row of table.rows) {
    for (const item of selected) rows.push({sourceRecord: row.number, measurement: item.name, cells: [...identifiers.map(identifier => row.cells[identifier.index]), item.name, row.cells[item.index]]})
  }
  const quote = value => '"' + value.replaceAll('"', '""') + '"'
  const output = [headers, ...rows.map(row => row.cells)].map(row => row.map(quote).join(separator)).join('\n') + '\n'
  const parsed = parseTaskCsv(output, separator)
  if (encoder.encode(output).length !== bytes || JSON.stringify(parsed.headers) !== JSON.stringify(headers) || JSON.stringify(parsed.rows.map(row => row.cells)) !== JSON.stringify(rows.map(row => row.cells))) throw new Error('Prepared reshape did not round-trip through the table parser.')
  return {text, separator, measures: [...measures], variableName, valueName, output, count, bytes, preview: {headers, rows}}
}

export function applyTableReshape(plan, ...args) {
  if (!plan) throw new Error('Preview the reshape first.')
  const current = prepareTableReshape(...args)
  if (JSON.stringify(plan) !== JSON.stringify(current)) throw new Error('Draft or reshape settings changed. Preview again.')
  return current.output
}
