import { taskInputKeys, taskInputErrors, fillTaskForm } from './specialist-task-form.js'

// A local CSV is data for explicitly selected invocations, never executable code.
export const taskCsvLimits = Object.freeze({ bytes: 512 * 1024, rows: 100, columns: 32 })
export function parseTaskCsv(source, separator = ',') {
  if (separator !== ',' && separator !== '\t') throw new Error('Use a comma or tab table separator.')
  if (typeof source !== 'string' || source.length > taskCsvLimits.bytes || new TextEncoder().encode(source).length > taskCsvLimits.bytes) throw new Error('Choose a UTF-8 CSV no larger than 512 KiB.')
  if (source.includes('\0')) throw new Error('CSV cannot contain NUL characters.')
  source = source.replace(/^\uFEFF/, '')
  const records = []
  let row = [], value = '', mode = 'start'
  const cell = () => {
    row.push(value); value = ''; mode = 'start'
    if (row.length > taskCsvLimits.columns) throw new Error('CSV supports at most 32 columns.')
  }
  const record = () => {
    cell(); records.push(row); row = []
    if (records.length > taskCsvLimits.rows + 1) throw new Error('CSV supports at most 100 task rows plus a header.')
  }
  for (let i = 0; i < source.length; i++) {
    const char = source[i]
    if (mode === 'quoted') {
      if (char === '"') {
        if (source[i + 1] === '"') { value += '"'; i++ } else mode = 'closed'
      } else value += char
    } else if (char === separator) cell()
    else if (char === '\r' || char === '\n') {
      record(); if (char === '\r' && source[i + 1] === '\n') i++
    } else if (char === '"' && mode === 'start') mode = 'quoted'
    else {
      if (mode === 'closed' || char === '"') throw new Error(`Malformed CSV quoting in record ${records.length + 1}.`)
      value += char; mode = 'plain'
    }
  }
  if (mode === 'quoted') throw new Error('CSV has an unclosed quoted cell.')
  if (mode !== 'start' || row.length || value) record()
  if (records.length < 2) throw new Error('CSV needs a header and at least one task row.')
  const headers = records.shift()
  if (headers.some(header => !header.trim() || header.length > 200) || new Set(headers.map(header => header.trim())).size !== headers.length) throw new Error('CSV headers must be nonblank, distinct names of at most 200 characters.')
  return { headers, rows: records.map((cells, index) => ({ number: index + 2, cells })) }
}

export function inspectTaskCsv(form, csv, mapping, corrections = {}) {
  const keys = taskInputKeys(form.template)
  for (const key of keys) {
    if (!Object.hasOwn(mapping, key) || !Number.isInteger(mapping[key]) || mapping[key] < 0 || mapping[key] >= csv.headers.length) throw new Error(`Map ${key} to a CSV column before inspecting rows.`)
  }
  return csv.rows.map((row, index) => {
    const originalValues = Object.fromEntries(keys.map(key => [key, row.cells[mapping[key]]]))
    const correction = Object.hasOwn(corrections, index) ? corrections[index] : null
    if (correction && (typeof correction !== 'object' || Array.isArray(correction) || Object.keys(correction).some(key => !keys.includes(key)))) throw new Error('Row corrections contain an unknown task input. Reset the corrections and retry.')
    const values = Object.fromEntries(keys.map(key => [key, correction && Object.hasOwn(correction, key) ? correction[key] : originalValues[key]]))
    const corrected = keys.filter(key => values[key] !== originalValues[key])
    const errors = row.cells.length === csv.headers.length ? [] : [`Expected ${csv.headers.length} cells; found ${row.cells.length}.`]
    errors.push(...taskInputErrors(form, values))
    let task = ''
    if (!errors.length) { try { task = fillTaskForm(form, values) } catch (error) { errors.push(error.message) } }
    return { number: row.number, originalValues, values, corrected, errors, task }
  })
}
