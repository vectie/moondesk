import { exportCreator } from './specialist-portable.js'

// Operator observations, never provider receipts or completion state.
export const taskResultLimits = Object.freeze({ output: 16384, notes: 8192, count: 100, bytes: 4 * 1024 * 1024 })
const clone = value => JSON.parse(JSON.stringify(value))
const bytes = text => new TextEncoder().encode(text).length
const exactText = value => typeof value === 'string' && new TextDecoder().decode(new TextEncoder().encode(value)) === value && !value.includes('\0')
const checkSize = value => { if (bytes(JSON.stringify(value, null, 2)) > taskResultLimits.bytes - 65536) throw new Error('Task observations approach the 4 MiB archive limit. Export this batch before starting another; nothing was truncated.') }

export function captureTaskObservation(csv, index, row, output, notes) {
  if (!Number.isInteger(index) || !csv?.rows[index] || !row || row.errors.length || !row.brief) throw new Error('Inspect and select a valid current task before recording its response.')
  if (!exactText(output) || !output.trim() || output.length > taskResultLimits.output || !exactText(notes) || notes.length > taskResultLimits.notes) throw new Error('Enter a response of 1–16,384 characters and notes up to 8,192, using well-formed Unicode without NUL.')
  return { row_index: index, row_number: csv.rows[index].number, original_cells: clone(csv.rows[index].cells), inputs: clone(row.values), task: row.task, brief: row.brief, output, notes }
}

export function sameObservedTask(observation, csv, row) {
  const original = csv?.rows[observation.row_index]
  return !!original && !!row && !row.errors.length && observation.row_number === original.number &&
    JSON.stringify(observation.original_cells) === JSON.stringify(original.cells) &&
    JSON.stringify(observation.inputs) === JSON.stringify(row.values) && observation.task === row.task && observation.brief === row.brief
}

export function appendTaskObservation(csv, observation) {
  const observations = [...(csv.observations || []), clone(observation)]
  if (observations.length > taskResultLimits.count) throw new Error('Keep at most 100 observations in one task batch. Export this batch before starting another.')
  checkSize({ creator: csv.creator, source_headers: csv.headers, source_name: csv.name, observations })
  return observations
}

function literalBlock(text) {
  let width = 3, run = 0
  for (const char of text) { if (char === '`') { run++; width = Math.max(width, run + 1) } else run = 0 }
  const fence = '`'.repeat(width)
  return `${fence}text\n${text}\n${fence}\n`
}

export function exportTaskResults(csv, rows, format, validPreset) {
  if (!csv?.observations?.length) throw new Error('Record an operator-observed response first.')
  if (csv.resultEditor) throw new Error('Save or cancel the unfinished observation before exporting results.')
  if (!['json', 'csv', 'markdown'].includes(format)) throw new Error('Choose JSON, spreadsheet-safe CSV or Markdown.')
  const definition = JSON.parse(exportCreator(csv.creator, validPreset).content).creator
  const data = { contract: 'moondesk.creator-task-results.v1', provenance: 'operator-entered; no execution or completion verified',
    creator: definition, source_name: csv.name, source_headers: clone(csv.headers),
    observations: csv.observations.map((item, index) => ({ observation_number: index + 1, ...clone(item),
      matches_current_task: sameObservedTask(item, csv, rows[item.row_index]),
      current_input_errors: [...(rows[item.row_index]?.errors || ['Current row unavailable'])] })) }
  let content, extension
  if (format === 'json') { content = JSON.stringify(data, null, 2) + '\n'; extension = 'json' }
  else if (format === 'csv') {
    // Every untrusted cell is a JSON value before RFC-style CSV escaping. In
    // particular strings begin with a literal quote, so =/+/-/@ never execute
    // as spreadsheet formulas. JSON.parse restores exact strings and CRLF.
    const cell = value => '"' + JSON.stringify(value).replaceAll('"', '""') + '"'
    content = 'observation_number,row_number,matches_current_task,inputs_json,task_json,response_json,notes_json,current_input_errors_json\r\n' +
      data.observations.map(item => [item.observation_number, item.row_number, item.matches_current_task, item.inputs, item.task, item.output, item.notes, item.current_input_errors].map(cell).join(',')).join('\r\n') + '\r\n'
    extension = 'csv'
  } else {
    const parts = ['# Creator task observations\n',
      'These are operator-entered responses, not provider receipts, accepted knowledge or verified completion. Match status compares captured inputs and complete briefs with this currently open batch. File references remain live. A changed task keeps its earlier observation with a mismatch label.\n',
      '## Creator and input columns\n' + literalBlock(JSON.stringify({ creator: definition, source_name: csv.name, source_headers: csv.headers }, null, 2))]
    for (const item of data.observations) parts.push(`## Observation ${item.observation_number} · CSV row ${item.row_number}\n`,
      item.matches_current_task ? 'Captured inputs and brief match the current task.\n' : 'Historical observation: inputs or complete brief do not match the current task.\n',
      '### Original cells and captured task inputs\n' + literalBlock(JSON.stringify({ original_cells: item.original_cells, inputs: item.inputs }, null, 2)),
      '### Exact captured brief\n' + literalBlock(item.brief), '### Operator-entered response\n' + literalBlock(item.output),
      '### Operator notes\n' + literalBlock(item.notes), '### Current input errors\n' + literalBlock(JSON.stringify(item.current_input_errors)))
    content = parts.join('\n'); extension = 'md'
  }
  if (!exactText(content)) throw new Error('This report contains unsupported Unicode or NUL in captured task text. Export exact JSON instead; no text was replaced.')
  if (bytes(content) > taskResultLimits.bytes) throw new Error('This results export exceeds 4 MiB. Choose another format or export fewer observations in a new batch; the current observations are kept.')
  return { filename: `creator-task-results.${extension}`, content, mime: format === 'csv' ? 'text/csv;charset=utf-8' : format === 'markdown' ? 'text/markdown;charset=utf-8' : 'application/json;charset=utf-8' }
}
