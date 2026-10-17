import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController } from './specialist-builder.js'
import { appendTaskObservation } from './specialist-task-results.js'
import { parseTaskCsv } from './specialist-task-csv.js'
import { downloadCreator } from './specialist-portable.js'

const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', workspace_id: 'book-a', book_id: 'source-book', name: 'Source Book', version: '1.0.0', status: 'ready', capabilities: ['Evidence'] }
const preset = { contract: 'moondesk.specialist-preset.v1', id: 'research-writer', revision: 2, name: 'Research writer', purpose: 'Explain retained sources to a chosen reader', example: 'Explain the operating guide to a founder',
  book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version }, capabilities: [], knowledge_paths: ['wiki/reference.md'],
  task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Explain {{topic}} for {{audience}}. Cite the available source and name missing evidence.' } }
const file = (source, name = 'tasks.csv') => ({ name, size: new TextEncoder().encode(source).length, arrayBuffer: async () => new TextEncoder().encode(source).buffer })
async function harness(source = 'Topic,Audience\nNightly exports,Founder\nPilot expansion,Support lead') {
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [preset] }), dispatches = []
  const c = createSpecialistController({ scope: 'results', storage: { getItem: () => raw }, dispatch: (...args) => dispatches.push(args),
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await c.open(); c.reopen(preset.id); assert.equal(await c.importTaskCsv(file(source)), true)
  c.mapTaskCsv('topic', 0); c.mapTaskCsv('audience', 1); c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  return { c, raw, dispatches }
}
function record(c, output = 'Source: operating guide. Exports run nightly; the exact completion time is not stated.', notes = 'Ask the owner for a measured completion window.') {
  assert.equal(c.beginTaskObservation(c.state.csv.selected), true)
  assert.equal(c.editTaskObservation('output', output), true); assert.equal(c.editTaskObservation('notes', notes), true)
  assert.equal(c.saveTaskObservation(), true)
}

test('real creator controller collects selected row responses and exports exact downstream records without dispatch', async () => {
  const { c, raw, dispatches } = await harness(); record(c)
  c.selectTaskCsvRow(1); record(c, 'Measure support demand before increasing the pilot size.', 'Capacity evidence is still missing.')
  const packet = c.exportTaskResults('json'), data = JSON.parse(packet.content)
  assert.equal(data.contract, 'moondesk.creator-task-results.v1'); assert.equal(data.observations.length, 2)
  assert.deepEqual(data.creator, preset); assert.deepEqual(data.observations[0].inputs, { topic: 'Nightly exports', audience: 'Founder' })
  assert.equal(data.observations[1].row_number, 3); assert.equal(data.observations.every(item => item.matches_current_task), true)
  assert.deepEqual(dispatches, []); assert.equal(JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: c.state.records }), raw)
  assert.match(data.provenance, /operator-entered/); assert.equal(Object.hasOwn(data, 'completed'), false)
})

test('multiple observations preserve earlier responses and input edits flag historical bindings', async () => {
  const { c } = await harness(); record(c, 'First response'); record(c, 'Response after feedback')
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Changed source'); c.applyTaskCsvRowEdit()
  assert.deepEqual(c.taskObservationStatuses(), [false, false])
  let data = JSON.parse(c.exportTaskResults('json').content)
  assert.deepEqual(data.observations.map(item => item.output), ['First response', 'Response after feedback'])
  assert.equal(data.observations[0].inputs.topic, 'Nightly exports')
  c.selectTaskCsvRow(0); record(c, 'New task response')
  assert.deepEqual(c.taskObservationStatuses(), [false, false, true])
  c.resetTaskCsvRow(0); c.inspectTaskCsv()
  assert.deepEqual(c.taskObservationStatuses(), [true, true, false])
})

test('task changes during editing retain unsaved response and refuse to misbind it', async () => {
  const { c } = await harness(); c.beginTaskObservation(0); c.editTaskObservation('output', 'Pending result')
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Different'); c.applyTaskCsvRowEdit()
  assert.equal(c.saveTaskObservation(), false); assert.match(c.state.status, /task changed/)
  assert.equal(c.state.csv.resultEditor.output, 'Pending result'); assert.equal(c.state.csv.observations, undefined)
  assert.equal(c.exportTaskResults('json'), false)
  c.cancelTaskObservation(); c.selectTaskCsvRow(0); record(c)
})

test('selected task-file bytes enter captured brief explicitly and changes retain historical responses', async () => {
  const { c } = await harness(); await c.addTaskFile(file('Private selected evidence', 'evidence.txt')); c.inspectTaskCsv(); c.selectTaskCsvRow(0); record(c)
  const result = JSON.parse(c.exportTaskResults('json').content)
  assert.match(result.observations[0].brief, /Private selected evidence/)
  c.removeTaskFile(0); assert.deepEqual(c.taskObservationStatuses(), [false])
  assert.match(c.exportTaskResults('markdown').content, /Historical observation/)
})

test('invalid mappings and incomplete rows remain errors and never gain observed-success labels', async () => {
  const { c } = await harness('Topic,Audience\nNightly exports,Founder\nMissing\n,Reader')
  assert.equal(c.beginTaskObservation(1), false); assert.equal(c.beginTaskObservation(2), false)
  record(c); c.mapTaskCsv('topic', null)
  const data = JSON.parse(c.exportTaskResults('json').content)
  assert.equal(data.observations[0].matches_current_task, false); assert.match(data.observations[0].current_input_errors.join(' '), /Map topic/)
  assert.equal(data.observations[0].output.startsWith('Source:'), true)
})

test('spreadsheet-safe CSV encodes formula-looking, multiline and Unicode strings losslessly', async () => {
  const { c } = await harness(); const output = '=HYPERLINK("https://example.invalid")\r\n +CMD 海😀', notes = '\t@SUM(1,2)\n"quoted"'
  record(c, output, notes)
  const csv = parseTaskCsv(c.exportTaskResults('csv').content)
  assert.equal(csv.rows.length, 1)
  assert.equal(csv.rows[0].cells[5][0], '"'); assert.equal(JSON.parse(csv.rows[0].cells[5]), output)
  assert.equal(JSON.parse(csv.rows[0].cells[6]), notes)
  assert.deepEqual(JSON.parse(csv.rows[0].cells[3]), { topic: 'Nightly exports', audience: 'Founder' })
})

test('Markdown uses literal fences and preserves exact observed markup without evaluating it', async () => {
  const { c } = await harness(); const output = '<script>unsafe()</script>\r\n```````\n# fake heading'
  record(c, output); const packet = c.exportTaskResults('markdown')
  assert.match(packet.content, /````````text/); assert.ok(packet.content.includes(output)); assert.match(packet.content, /not provider receipts/)
})

test('blank, invalid Unicode, NUL, oversize and excess observations preserve current work', async () => {
  const { c } = await harness(); c.beginTaskObservation(0)
  for (const output of ['', ' ', '\ud800', 'bad\0text']) {
    c.editTaskObservation('output', output); assert.equal(c.saveTaskObservation(), false); assert.equal(c.state.csv.observations, undefined)
  }
  c.editTaskObservation('output', 'Kept'); assert.equal(c.editTaskObservation('output', 'x'.repeat(16385)), false); assert.equal(c.state.csv.resultEditor.output, 'Kept')
  assert.equal(c.saveTaskObservation(), true)
  const one = c.state.csv.observations[0]
  assert.throws(() => appendTaskObservation({ ...c.state.csv, observations: Array(100).fill(one) }, one), /100 observations/)
  assert.throws(() => appendTaskObservation({ ...c.state.csv, observations: Array(99).fill({ ...one, brief: 'x'.repeat(48000) }) }, one), /4 MiB/)
})

test('checkpoint remains input-only and failed downloads preserve exact observations', async () => {
  const { c } = await harness(); record(c)
  const before = JSON.stringify(c.state.csv.observations)
  assert.equal(c.exportTaskResults('json', () => { throw new Error('Download denied') }), false)
  assert.match(c.state.status, /Download denied/); assert.equal(JSON.stringify(c.state.csv.observations), before)
  const checkpoint = JSON.parse(c.exportTaskCheckpoint().content)
  assert.equal(Object.hasOwn(checkpoint, 'observations'), false)
  assert.equal(c.exportTaskResults('unknown'), false)
  c.close(); assert.equal(c.saveTaskObservation(), false); assert.equal(c.exportTaskResults('json'), false)
  await c.open(); assert.equal(JSON.stringify(c.state.csv.observations), before)
})

test('sample journey exports practical two-row creator outputs through production entry', async () => {
  const { c } = await harness(); record(c)
  c.selectTaskCsvRow(1); record(c, 'Measure support demand and staffing before expanding to twelve teams.', 'Review the observed capacity before proposing a creator revision.')
  if (process.env.MOONDESK_RESULTS_SAMPLE === '1') console.log('TASK_RESULTS_SAMPLE=' + JSON.stringify({ json: JSON.parse(c.exportTaskResults('json').content), csv: c.exportTaskResults('csv').content, markdown: c.exportTaskResults('markdown').content }))
})

test('production result downloads preserve actual Blob text, correct MIME and cleanup across formats', async () => {
  const { c } = await harness(); record(c)
  for (const format of ['json', 'csv', 'markdown']) {
    const packet = c.exportTaskResults(format)
    let blob, clicked = false, removed = false, revoked = false
    const link = { click() { clicked = true }, remove() { removed = true } }
    downloadCreator(packet, { document: { body: { append(node) { assert.equal(node, link) } }, createElement: () => link },
      URL: { createObjectURL(value) { blob = value; return 'blob:fixture' }, revokeObjectURL(url) { assert.equal(url, 'blob:fixture'); revoked = true } }, Blob, later: fn => fn() })
    assert.equal(await blob.text(), packet.content); assert.equal(blob.type, packet.mime); assert.equal(link.download, packet.filename)
    assert.ok(clicked && removed && revoked)
  }
})

test('legacy malformed task Unicode cannot silently change in Markdown while exact JSON preserves it', async () => {
  const { c } = await harness(); c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'old\ud800task'); c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(0); record(c)
  assert.equal(JSON.parse(c.exportTaskResults('json').content).observations[0].inputs.topic, 'old\ud800task')
  assert.equal(c.exportTaskResults('markdown'), false); assert.match(c.state.status, /unsupported Unicode/)
})
