import { parseTaskCsv } from './specialist-task-csv.js'

export function prepareDerivedColumn(text, separator, sourceHeader, delimiter, part, name, trim) {
  const table = parseTaskCsv(text, separator)
  if (!table.headers.includes(sourceHeader)) throw new Error('Choose an exact existing source column name.')
  if (typeof delimiter !== 'string' || !delimiter || delimiter.length > 200) throw new Error('Use a nonempty literal delimiter up to 200 characters.')
  if (!/^[1-9]\d{0,5}$/.test(String(part))) throw new Error('Part must be a positive one-based integer up to 999999.')
  if (typeof trim !== 'boolean') throw new Error('Trim must be an explicit checkbox choice.')
  if (typeof name !== 'string' || !name.trim() || name.length > 200 || table.headers.some(h => h.trim() === name.trim())) throw new Error('Use a new nonblank column name up to 200 characters.')
  if (table.headers.length >= 32) throw new Error('At most 31 input columns can receive a derived column (32 total).')
  const index = table.headers.indexOf(sourceHeader), cells = []
  for (const row of table.rows) {
    if (row.cells.length !== table.headers.length) throw new Error(`Record ${row.number} has a different width from its header.`)
    const selected = row.cells[index].split(delimiter)[Number(part)-1] ?? ''
    cells.push(trim ? selected.trim() : selected)
  }
  const quote = value => '"' + value.replaceAll('"','""') + '"'
  const rows = [table.headers.concat(name), ...table.rows.map((row,i) => row.cells.concat(cells[i]))]
  // textarea.value uses LF; producing CRLF would fail the editor retention check.
  const output = rows.map(row => row.map(quote).join(separator)).join('\n') + '\n'
  const reparsed = parseTaskCsv(output, separator)
  if (JSON.stringify(reparsed.headers) !== JSON.stringify(rows[0]) || JSON.stringify(reparsed.rows.map(r=>r.cells)) !== JSON.stringify(rows.slice(1))) throw new Error('Prepared output did not round-trip through the table parser.')
  return {text, output, separator, sourceHeader, delimiter, part:String(part), name, trim, count:cells.length,
    preview:table.rows.slice(0,10).map((row,i)=>({record:i+1, original:row.cells[index], derived:cells[i]}))}
}
export function applyDerivedColumn(plan, ...args) {
  if (!plan) throw new Error('Preview the derived column first.')
  const current = prepareDerivedColumn(...args)
  if (JSON.stringify(current) !== JSON.stringify(plan)) throw new Error('Draft or column settings changed. Preview again.')
  return current.output
}
