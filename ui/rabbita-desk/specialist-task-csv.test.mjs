import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { parseTaskCsv, inspectTaskCsv, taskCsvLimits } from './specialist-task-csv.js'
import { createSpecialistController, specialistStorageKeyFor, specialistBrief } from './specialist-builder.js'

const form = { contract: 'moondesk.specialist-task-form.v1', template: 'Compare {{topic}} for {{audience}}. Repeat {{topic}}.' }
const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', workspace_id: 'book-a', book_id: 'source-book', name: 'Source Book', version: '1.0.0', status: 'ready', capabilities: ['Evidence'] }
const book = { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version }
const preset = { contract: 'moondesk.specialist-preset.v1', id: 'analyst', revision: 4, name: 'Analyst', purpose: 'Compare evidence', example: 'Compare Q3', book, capabilities: ['Evidence'], knowledge_paths: ['raw/report.md'], task_form: form }
const copy = value => JSON.parse(JSON.stringify(value))
const csvFile = (source, name = 'tasks.csv') => ({ name, size: new TextEncoder().encode(source).length, arrayBuffer: async () => new TextEncoder().encode(source).buffer })
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no }); return { promise, resolve, reject } }
function harness(records = [preset], extra = {}) {
  const values = new Map([[specialistStorageKeyFor('csv-library'), JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  let agents = [agent], serial = 0
  const dispatches = [], requests = []
  const controller = createSpecialistController({ scope: 'csv-library', storage,
    fetch: async url => { requests.push(url); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents }) } },
    dispatch: (...args) => dispatches.push(args), id: () => `csv-${++serial}`, ...extra })
  return { controller, storage, dispatches, requests, setAgents(next) { agents = next } }
}
async function imported(h, source = 'Subject,Reader\n001.00,Founder\n2026-10-12,Analyst') {
  const c = h.controller
  await c.open(); c.reopen(preset.id)
  assert.equal(await c.importTaskCsv(csvFile(source)), true)
  c.mapTaskCsv('topic', 0); c.mapTaskCsv('audience', 1)
  assert.equal(c.inspectTaskCsv(), true); assert.equal(c.selectTaskCsvRow(0), true)
  return c
}

test('JSONL controller rejects failed imports atomically and ignores late reads after switching creator', async () => {
  const h = harness(), c = await imported(h), before = JSON.stringify(c.state.csv)
  assert.equal(await c.importTaskJsonl(csvFile('{"topic":12}', 'bad.jsonl')), false)
  assert.equal(JSON.stringify(c.state.csv), before); assert.equal(h.dispatches.length, 0)
  const wait = deferred(), source = '{"topic":"fresh","audience":"reader"}'
  const pending = c.importTaskJsonl({ name: 'late.jsonl', size: source.length, arrayBuffer: () => wait.promise })
  c.newDraft(); wait.resolve(new TextEncoder().encode(source).buffer)
  assert.equal(await pending, false); assert.equal(c.state.csv, null)
  c.reopen(preset.id)
  assert.equal(await c.importTaskJsonl({ name: 'invalid.jsonl', size: 1, arrayBuffer: async () => new Uint8Array([255]).buffer }), false)
  assert.match(c.state.status, /JSONL must be valid UTF-8/)
})

test('CSV parser preserves lexical strings, CRLF, BOM, multiline quoting, commas, escapes and literal formulas', () => {
  const csv = parseTaskCsv('\uFEFFID,Topic,Audience\r\n00123,"00.050, \"\"quoted\"\"\r\nline",  Founder  \r\n=1+2,$& {{other}},FALSE\r\n')
  assert.deepEqual(csv.headers, ['ID', 'Topic', 'Audience'])
  assert.deepEqual(csv.rows, [
    { number: 2, cells: ['00123', '00.050, "quoted"\r\nline', '  Founder  '] },
    { number: 3, cells: ['=1+2', '$& {{other}}', 'FALSE'] },
  ])
  const rows = inspectTaskCsv(form, csv, { topic: 1, audience: 2 })
  assert.equal(rows[0].task, 'Compare 00.050, "quoted"\r\nline for   Founder  . Repeat 00.050, "quoted"\r\nline.')
  assert.equal(rows[1].task, 'Compare $& {{other}} for FALSE. Repeat $& {{other}}.')
  assert.deepEqual(parseTaskCsv('h\rvalue\r').rows[0].cells, ['value'])
  assert.deepEqual(parseTaskCsv('a,b\n"",').rows[0].cells, ['', ''])
})

test('malformed CSV, blank or duplicate headers, quote ambiguity and bounds fail explicitly', () => {
  for (const source of ['', '\n', 'Only a header', 'a,a\nx,y', ' a ,a\nx,y', 'a, \nx,y', 'x'.repeat(201) + '\ny', 'a\n"unfinished', 'a\nno"quote', 'a\n"yes" trailing', 'a\n\0']) assert.throws(() => parseTaskCsv(source))
  assert.throws(() => parseTaskCsv('a\n' + 'x'.repeat(taskCsvLimits.bytes)), /512 KiB/)
  assert.throws(() => parseTaskCsv('a\n' + 'é'.repeat(taskCsvLimits.bytes / 2)), /512 KiB/)
  assert.throws(() => parseTaskCsv(Array.from({ length: 33 }, (_, i) => 'h' + i).join(',') + '\nx'), /32 columns/)
  assert.throws(() => parseTaskCsv('a\n' + Array(101).fill('x').join('\n')), /100 task rows/)
  assert.equal(parseTaskCsv('a\n' + Array(100).fill('x').join('\n')).rows.length, 100)
})

test('mapping is explicit, supports reordered columns and reports per-row blank, width and length errors', () => {
  const csv = parseTaskCsv('Reader,Subject\nFounder,001\n,\nOnly one\nA,B,extra\nA,' + 'x'.repeat(4001))
  for (const mapping of [{}, { topic: 0 }, { topic: '1', audience: 0 }, { topic: 1, audience: -1 }, Object.create({ topic: 1, audience: 0 })]) assert.throws(() => inspectTaskCsv(form, csv, mapping), /Map/)
  const rows = inspectTaskCsv(form, csv, { topic: 1, audience: 0 })
  assert.equal(rows[0].task, 'Compare 001 for Founder. Repeat 001.')
  assert.equal(rows[1].errors.length, 2)
  assert.match(rows[2].errors.join(' '), /Expected 2 cells; found 1/)
  assert.match(rows[3].errors.join(' '), /Expected 2 cells; found 3/)
  assert.match(rows[4].errors.join(' '), /4,000/)
  assert.equal(rows.slice(1).every(row => row.task === ''), true)
  const repeated = { ...form, template: '{{topic}}{{topic}}{{topic}}' }
  assert.match(inspectTaskCsv(repeated, parseTaskCsv('Topic\n' + 'x'.repeat(3000)), { topic: 0 })[0].errors[0], /8,000/)
})

test('saved CSV creator prepares one exact selected row and returns for another without saved changes or sending', async () => {
  const h = harness(), c = await imported(h), raw = h.storage.getItem(specialistStorageKeyFor('csv-library'))
  assert.equal(h.dispatches.length, 0)
  assert.equal(c.state.csv.creator.revision, 4)
  for (const index of [0, 1]) {
    assert.equal(c.selectTaskCsvRow(index), true)
    const row = c.state.csv.inspected[index]
    assert.equal(await c.prepareTaskCsvRow(), true)
    assert.equal(await c.prepareTaskCsvRow(), false)
    const call = h.dispatches.at(-1), binding = JSON.parse(call[3])
    assert.equal(call[0], 'prepare-specialist'); assert.equal(call[1], agent.workspace_id)
    assert.equal(call[2], row.brief); assert.equal(call[2], specialistBrief(preset, row.task))
    assert.deepEqual(binding.knowledge_paths, ['raw/report.md']); assert.equal(binding.library_scope, 'csv-library')
    c.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
    assert.equal(c.state.open, false); assert.match(c.state.status, /Click Send/)
    await c.open()
  }
  assert.equal(h.dispatches.length, 2); assert.deepEqual(h.requests, Array(h.requests.length).fill('/api/desktop/agents'))
  assert.equal(h.storage.getItem(specialistStorageKeyFor('csv-library')), raw)
  assert.equal(c.state.created.revision, 4); assert.deepEqual(c.state.taskValues, {})
})

test('saved composed snapshots and variant lineage stay pinned when sources and saved definition change', async () => {
  const one = { ...copy(preset), id: 'one', name: 'One', revision: 2 }, two = { ...copy(preset), id: 'two', name: 'Two', revision: 3 }
  const composed = { ...copy(preset), revision: 8, variant: { contract: 'moondesk.specialist-variant.v1', source_id: 'origin', source_name: 'Origin', source_revision: 6 },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: [{ source: one, handoff: 'Cite findings' }, { source: two, handoff: 'Review claims' }] } }
  const h = harness([composed, one, two]), c = await imported(h)
  c.close()
  const newer = copy(composed); newer.revision = 9; newer.purpose = 'New purpose'; newer.composition.stages.reverse()
  h.storage.setItem(specialistStorageKeyFor('csv-library'), JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [newer] }))
  await c.open(); assert.equal(await c.prepareTaskCsvRow(), true)
  assert.match(h.dispatches[0][2], /revision 8/); assert.match(h.dispatches[0][2], /Variant source: Origin/)
  assert.ok(h.dispatches[0][2].indexOf('Stage 1: One') < h.dispatches[0][2].indexOf('Stage 2: Two'))
  assert.equal(c.state.csv.creator.composition.stages[0].source.revision, 2)
})

test('incomplete mapping, invalid row and changed mapping cannot prepare a stale selected brief', async () => {
  const h = harness(), c = await imported(h, 'Subject,Reader\n001,Founder\n,')
  c.mapTaskCsv('audience', null)
  assert.equal(c.state.csv.selected, null); assert.equal(c.state.csv.inspected.length, 0)
  assert.equal(c.inspectTaskCsv(), false); assert.equal(await c.prepareTaskCsvRow(), false)
  c.mapTaskCsv('audience', 1); c.inspectTaskCsv()
  assert.equal(c.selectTaskCsvRow(1), false); assert.equal(await c.prepareTaskCsvRow(), false)
  c.selectTaskCsvRow(0); c.state.csv.inspected[0].brief = 'stale tampered preview'
  assert.equal(await c.prepareTaskCsvRow(), false); assert.equal(h.dispatches.length, 0)
})

test('imports require a saved exact task-form creator and preserve an existing batch after invalid input', async () => {
  const h = harness(), c = await imported(h), prior = copy(c.state.csv)
  for (const file of [csvFile('bad'), { size: 4, arrayBuffer: async () => new Uint8Array([97, 10, 192, 128]).buffer }, { size: taskCsvLimits.bytes + 1, arrayBuffer() { throw Error('must not read') } }, { size: 1, arrayBuffer: async () => { throw Error('Read failed') } }]) {
    assert.equal(await c.importTaskCsv(file), false); assert.deepEqual(c.state.csv, prior)
  }
  c.revise(); assert.equal(await c.importTaskCsv(csvFile('a\nx')), false)
  c.edit('purpose', 'Edited'); c.create()
  assert.equal(await c.importTaskCsv(csvFile('a\nx')), false); assert.match(c.state.status, /save this revision/)
  c.save(); assert.equal(await c.importTaskCsv(csvFile('a\nx')), true)
  const noForm = harness([{ ...preset, task_form: undefined }]); await noForm.controller.open(); noForm.controller.reopen(preset.id)
  assert.equal(await noForm.controller.importTaskCsv(csvFile('a\nx')), false)
})

test('latest file read owns the batch and stale failures cannot erase newer status or data', async () => {
  const h = harness(), c = await imported(h), slow = deferred()
  const pending = c.importTaskCsv({ name: 'older.csv', size: 10, arrayBuffer: () => slow.promise.then(value => new TextEncoder().encode(value).buffer) })
  assert.equal(await c.importTaskCsv(csvFile('Subject,Reader\nNew,Owner', 'new.csv')), true)
  const current = copy(c.state.csv), status = c.state.status
  slow.reject(Error('Old failure')); assert.equal(await pending, false)
  assert.deepEqual(c.state.csv, current); assert.equal(c.state.status, status); assert.equal(c.state.csvLoading, false)
})

test('Close, switching, revision and clearing cancel late imports while preserving intended recovery', async () => {
  for (const action of ['close', 'reopen', 'revise', 'newDraft', 'clearTaskCsv']) {
    const h = harness(), c = await imported(h), before = copy(c.state.csv), slow = deferred()
    const pending = c.importTaskCsv({ name: 'late.csv', size: 10, arrayBuffer: () => slow.promise.then(value => new TextEncoder().encode(value).buffer) })
    if (action === 'reopen') c.reopen(preset.id); else c[action]()
    slow.resolve('Subject,Reader\nLate,Owner'); assert.equal(await pending, false)
    assert.equal(c.state.csvLoading, false)
    if (action === 'close') { assert.deepEqual(c.state.csv, before); await c.open(); assert.deepEqual(c.state.csv, before) }
    else assert.equal(c.state.csv, null)
  }
})

test('Book drift and ordinary bridge unsent-work rejection keep selected rows recoverable for retry', async () => {
  const h = harness(), c = await imported(h), brief = c.state.csv.inspected[0].brief
  h.setAgents([{ ...agent, version: '2.0.0' }])
  assert.equal(await c.prepareTaskCsvRow(), false); assert.equal(h.dispatches.length, 0)
  assert.equal(c.state.csv.inspected[0].brief, brief)
  h.setAgents([agent]); assert.equal(await c.prepareTaskCsvRow(), true)
  const binding = JSON.parse(h.dispatches[0][3])
  c.receive('specialist-error', JSON.stringify({ request_id: 'unrelated', message: 'Wrong request' }))
  assert.equal(c.state.preparing, true)
  c.receive('specialist-error', JSON.stringify({ request_id: binding.request_id, message: 'Send or clear your current chat draft before preparing this example.' }))
  assert.match(c.state.status, /current chat draft/); assert.equal(c.state.csv.selected, 0)
  assert.equal(await c.prepareTaskCsvRow(), true)
})

test('preparation locks rows and imports, and Close cancels delayed catalog ownership', async () => {
  const deferredCatalog = deferred(); let catalogWait = false
  const h = harness([preset], { fetch: async () => catalogWait ? deferredCatalog.promise : ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  const c = await imported(h); catalogWait = true
  const pending = c.prepareTaskCsvRow()
  assert.equal(c.selectTaskCsvRow(1), false); assert.equal(c.mapTaskCsv('topic', 1), false)
  assert.equal(await c.importTaskCsv(csvFile('a\nx')), false); assert.equal(c.clearTaskCsv(), false)
  c.close(); deferredCatalog.resolve({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) })
  assert.equal(await pending, false); assert.equal(h.dispatches.length, 0); assert.equal(c.state.csv.selected, 0)
})

test('reload has no imported task data and manual invocation values remain independent', async () => {
  const h = harness(), c = await imported(h)
  c.editTaskInput('topic', 'Manual'); c.editTaskInput('audience', 'Reader'); c.previewTask()
  const preview = c.state.taskPreview
  c.mapTaskCsv('topic', 1); c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  assert.equal(c.state.taskPreview, preview); assert.equal(c.state.taskValues.topic, 'Manual')
  c.clearTaskCsv(); assert.equal(c.state.taskPreview, preview)
  const next = harness([preset], { storage: h.storage }); await next.controller.open(); next.controller.reopen(preset.id)
  assert.equal(next.controller.state.csv, null); assert.deepEqual(next.controller.state.taskValues, {})
})

test('production bridge retains all ordinary unsent-work guards and has no implicit Send', () => {
  const native = readFileSync(new URL('./main/specialist_builder.mbt', import.meta.url), 'utf8')
  for (const guard of ['model.request_prompt', 'model.mooncode_prompt', 'model.mooncode_images', 'model.mooncode_task_intent_submit_pending', 'markdown_navigation_needs_confirmation', 'office_editor_dirty', 'source_pane_dirty', 'model.git_review_note']) assert.ok(native.includes(guard), guard)
  assert.doesNotMatch(native, /SubmitWikiChat/)
})

test('row-level complete brief limits are visible even when each mapped input and filled task fits', async () => {
  const stages = Array.from({ length: 4 }, (_, index) => ({ ...copy(preset), id: `stage-${index}`, name: `Stage ${index}`, purpose: 'p'.repeat(4000), example: 'e'.repeat(7000) }))
  const large = { ...copy(preset), purpose: 'p'.repeat(1000), task_form: { ...form, template: '{{topic}}' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map(source => ({ source, handoff: 'Continue' })) } }
  const h = harness([large]), c = h.controller
  await c.open(); c.reopen(preset.id)
  assert.ok(specialistBrief(large).length < 48000)
  await c.importTaskCsv(csvFile('Topic\nShort\n' + 'x'.repeat(4000)))
  c.mapTaskCsv('topic', 0); c.inspectTaskCsv()
  assert.equal(c.state.csv.inspected[0].errors.length, 0)
  assert.match(c.state.csv.inspected[1].errors[0], /48,000/)
  assert.equal(c.selectTaskCsvRow(1), false); assert.equal(h.dispatches.length, 0)
})

test('missing Books, capability drift, catalog failures and oversized actual file bytes do not dispatch or erase rows', async () => {
  const h = harness(), c = await imported(h), previous = copy(c.state.csv)
  for (const agents of [[], [{ ...agent, status: 'unavailable' }], [{ ...agent, capabilities: [] }]]) {
    h.setAgents(agents); assert.equal(await c.prepareTaskCsvRow(), false); assert.equal(h.dispatches.length, 0)
    assert.deepEqual(c.state.csv, previous)
  }
  assert.equal(await c.importTaskCsv({ size: 1, arrayBuffer: async () => new ArrayBuffer(taskCsvLimits.bytes + 1) }), false)
  assert.deepEqual(c.state.csv, previous)
  let failCatalog = false
  const next = harness([preset], { fetch: async () => { if (failCatalog) throw Error('Catalog offline'); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) } } })
  await imported(next); failCatalog = true
  assert.equal(await next.controller.prepareTaskCsvRow(), false); assert.match(next.controller.state.status, /Catalog offline/)
  assert.equal(next.controller.state.csv.selected, 0)
})

test('row corrections preserve original cells and literal mapped inputs, including two inputs mapped to one column', () => {
  const csv = parseTaskCsv('Text\n001.00'), original = copy(csv)
  const corrections = { 0: { topic: '$& {{audience}}\n<script>x</script>', audience: '=1+2' } }
  const row = inspectTaskCsv(form, csv, { topic: 0, audience: 0 }, corrections)[0]
  assert.deepEqual(csv, original); assert.deepEqual(row.originalValues, { topic: '001.00', audience: '001.00' })
  assert.deepEqual(row.corrected, ['topic', 'audience'])
  assert.equal(row.task, 'Compare $& {{audience}}\n<script>x</script> for =1+2. Repeat $& {{audience}}\n<script>x</script>.')
  assert.throws(() => inspectTaskCsv(form, csv, { topic: 0, audience: 0 }, { 0: { unrecognized: 'value' } }), /unknown task input/)
  assert.match(inspectTaskCsv(form, csv, { topic: 0, audience: 0 }, { 0: { topic: '\0' } })[0].errors.join(' '), /Enter topic/)
})

test('invalid imported row is corrected, explicitly selected and prepared exactly once without changing the CSV or saved creator', async () => {
  const h = harness(), c = await imported(h, 'Subject,Reader\nGood,Owner\n,Founder'), raw = h.storage.getItem(specialistStorageKeyFor('csv-library'))
  const originals = copy(c.state.csv.rows), creator = copy(c.state.created)
  assert.equal(c.selectTaskCsvRow(1), false)
  assert.equal(c.beginTaskCsvRowEdit(1), true); assert.equal(c.state.csv.selected, null)
  assert.equal(await c.prepareTaskCsvRow(), false)
  assert.equal(c.editTaskCsvRowInput('topic', 'Corrected 001.00'), true)
  assert.equal(c.applyTaskCsvRowEdit(), true); assert.equal(c.state.csv.selected, null)
  const row = c.state.csv.inspected[1]
  assert.deepEqual(row.errors, []); assert.deepEqual(row.corrected, ['topic']); assert.equal(row.originalValues.topic, '')
  assert.match(row.brief, /Compare Corrected 001.00 for Founder/)
  assert.equal(await c.prepareTaskCsvRow(), false)
  assert.equal(c.selectTaskCsvRow(1), true); assert.equal(await c.prepareTaskCsvRow(), true); assert.equal(await c.prepareTaskCsvRow(), false)
  assert.equal(h.dispatches.length, 1); assert.equal(h.dispatches[0][2], row.brief)
  assert.deepEqual(c.state.csv.rows, originals); assert.deepEqual(c.state.created, creator)
  assert.equal(h.storage.getItem(specialistStorageKeyFor('csv-library')), raw)
  assert.equal(c.editTaskCsvRowInput('topic', 'Racing change'), false); assert.equal(c.resetTaskCsvRow(1), false)
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id }))
  await c.open(); assert.equal(c.state.csv.inspected[1].values.topic, 'Corrected 001.00')
  assert.equal(c.save(), true); assert.equal(h.storage.getItem(specialistStorageKeyFor('csv-library')), raw)
  assert.doesNotMatch(c.exportSaved(preset.id).content, /Corrected 001\.00/)
})

test('edit and reset invalidate the selected brief; cancelled edits retain only previously applied corrections', async () => {
  const h = harness(), c = await imported(h)
  assert.equal(c.beginTaskCsvRowEdit(0), true)
  c.editTaskCsvRowInput('topic', 'First correction'); c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(0)
  const corrected = c.state.csv.inspected[0].brief
  assert.equal(c.beginTaskCsvRowEdit(0), true); c.editTaskCsvRowInput('topic', 'Unapplied change')
  assert.equal(c.state.csv.selected, null); assert.equal(await c.prepareTaskCsvRow(), false)
  assert.equal(c.selectTaskCsvRow(1), false); assert.equal(c.inspectTaskCsv(), false)
  assert.equal(c.cancelTaskCsvRowEdit(), true); assert.equal(c.state.csv.inspected[0].brief, corrected)
  assert.equal(c.state.csv.selected, null); c.selectTaskCsvRow(0)
  assert.equal(c.resetTaskCsvRow(0), true); assert.equal(c.state.csv.inspected.length, 0)
  assert.equal(await c.prepareTaskCsvRow(), false); c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  assert.equal(c.state.csv.inspected[0].values.topic, '001.00')
  assert.notEqual(c.state.csv.inspected[0].brief, corrected)
  assert.equal(await c.prepareTaskCsvRow(), true); assert.equal(h.dispatches.length, 1)
  assert.doesNotMatch(h.dispatches[0][2], /correction|Unapplied/)
})

test('invalid corrections keep editor and original data; row-width errors cannot silently discard or guess cells', async () => {
  const h = harness(), c = await imported(h, 'Subject,Reader\nGood,Owner\n,Founder\nExtra,Reader,secret\nMissing')
  assert.equal(c.beginTaskCsvRowEdit(2), false); assert.match(c.state.status, /different number of cells/)
  assert.equal(c.beginTaskCsvRowEdit(3), false); assert.equal(c.beginTaskCsvRowEdit(1), true)
  for (const value of [' ', '\0']) {
    c.editTaskCsvRowInput('topic', value); assert.equal(c.applyTaskCsvRowEdit(), false)
    assert.equal(c.state.csv.editor.values.topic, value); assert.deepEqual(c.state.csv.corrections, {})
    assert.equal(c.state.csv.rows[1].cells[0], ''); assert.equal(await c.prepareTaskCsvRow(), false)
  }
  assert.equal(c.editTaskCsvRowInput('topic', 'x'.repeat(4001)), false)
  assert.equal(c.editTaskCsvRowInput('constructor', 'bad'), false)
  c.editTaskCsvRowInput('topic', 'Recovered'); assert.equal(c.applyTaskCsvRowEdit(), true)
  c.resetTaskCsvRow(1); c.inspectTaskCsv(); assert.match(c.state.csv.inspected[1].errors.join(' '), /Enter topic/)
  assert.deepEqual(c.state.csv.rows[2].cells, ['Extra', 'Reader', 'secret'])
})

test('row corrections stay separate from other rows and manual forms; mapping requires an explicit correction reset', async () => {
  const h = harness(), c = await imported(h)
  c.editTaskInput('topic', 'Manual'); c.editTaskInput('audience', 'Reader'); c.previewTask(); const manual = c.state.taskPreview
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Edited row'); c.applyTaskCsvRowEdit()
  const rows = copy(c.state.csv.inspected)
  assert.equal(c.mapTaskCsv('topic', 1), false); assert.equal(c.state.csv.mapping.topic, 0)
  assert.deepEqual(c.state.csv.inspected, rows); assert.match(c.state.status, /reset row corrections/)
  c.selectTaskCsvRow(1); assert.doesNotMatch(c.state.csv.inspected[1].brief, /Edited row/)
  c.selectTaskCsvRow(0); assert.match(c.state.csv.inspected[0].brief, /Edited row/)
  assert.equal(c.state.taskPreview, manual)
  c.resetTaskCsvCorrections(); assert.equal(c.state.csv.selected, null); assert.equal(c.state.csv.inspected.length, 0)
  assert.equal(c.mapTaskCsv('topic', 1), true); c.inspectTaskCsv()
  assert.equal(c.state.csv.inspected[0].values.topic, 'Founder'); assert.deepEqual(c.state.csv.inspected[0].corrected, [])
  assert.equal(c.state.taskPreview, manual)
})

test('Close preserves pending edits and applied corrections, while explicit replacement, revision and reload clear them', async () => {
  const h = harness(), c = await imported(h)
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Applied'); c.applyTaskCsvRowEdit()
  c.beginTaskCsvRowEdit(1); c.editTaskCsvRowInput('topic', 'Pending')
  c.close(); assert.equal(c.editTaskCsvRowInput('topic', 'Closed'), false); assert.equal(c.applyTaskCsvRowEdit(), false)
  await c.open(); assert.equal(c.state.csv.editor.values.topic, 'Pending'); assert.equal(c.state.csv.corrections[0].topic, 'Applied')
  assert.equal(await c.importTaskCsv(csvFile('invalid')), false)
  assert.equal(c.state.csv.editor.values.topic, 'Pending')
  c.cancelTaskCsvRowEdit(); c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', '001.00'); c.applyTaskCsvRowEdit()
  assert.deepEqual(c.state.csv.corrections, {}); assert.deepEqual(c.state.csv.inspected[0].corrected, [])
  for (const action of ['reopen', 'revise', 'newDraft', 'clearTaskCsv', 'importTaskCsv']) {
    const next = harness(), d = await imported(next)
    d.beginTaskCsvRowEdit(0); d.editTaskCsvRowInput('topic', 'Unsaved')
    if (action === 'reopen') d.reopen(preset.id)
    else if (action === 'importTaskCsv') { await d.importTaskCsv(csvFile('Subject,Reader\nFresh,Owner')); assert.deepEqual(d.state.csv.corrections, {}); assert.equal(d.state.csv.editor, null); continue }
    else d[action]()
    assert.equal(d.state.csv, null)
  }
  const reload = harness([preset], { storage: h.storage }); await reload.controller.open(); reload.controller.reopen(preset.id)
  assert.equal(reload.controller.state.csv, null)
})

test('task-only files and composition snapshots survive corrections; edits cannot leak to exported creator definitions', async () => {
  const composed = { ...copy(preset), composition: { contract: 'moondesk.specialist-composition.v1', stages: [
    { source: { ...copy(preset), id: 'first', name: 'First' }, handoff: 'Cited findings' },
    { source: { ...copy(preset), id: 'second', name: 'Second' }, handoff: 'Final review' },
  ] } }
  const h = harness([composed]), c = await imported(h), stages = copy(c.state.created.composition)
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Corrected task')
  assert.equal(await c.addTaskFile(csvFile('Private task snapshot', 'notes.txt')), true)
  assert.equal(c.state.csv.inspected.length, 0); assert.equal(c.state.csv.editor.values.topic, 'Corrected task')
  c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(0)
  assert.match(c.state.csv.inspected[0].brief, /Private task snapshot/); assert.match(c.state.csv.inspected[0].brief, /Stage 1: First/)
  assert.deepEqual(c.state.created.composition, stages)
  const packet = JSON.stringify(c.exportSaved(preset.id))
  assert.doesNotMatch(packet, /Private task snapshot|Corrected task/)
  await c.prepareTaskCsvRow(); c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id }))
  await c.open(); assert.equal(c.state.taskFiles.length, 0); assert.equal(c.state.csv.inspected.length, 0)
  assert.equal(c.state.csv.corrections[0].topic, 'Corrected task')
  c.inspectTaskCsv(); assert.doesNotMatch(c.state.csv.inspected[0].brief, /Private task snapshot/)
})

test('corrected tasks retain Book checks, recover from bridge rejection and reject late mutation of reviewed corrections', async () => {
  const h = harness(), c = await imported(h)
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Reviewed'); c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(0)
  c.state.csv.corrections[0].topic = 'Not reviewed'
  assert.equal(await c.prepareTaskCsvRow(), false); assert.equal(h.dispatches.length, 0)
  c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  h.setAgents([{ ...agent, version: '2.0.0' }]); assert.equal(await c.prepareTaskCsvRow(), false)
  assert.equal(c.state.csv.corrections[0].topic, 'Not reviewed'); assert.equal(h.dispatches.length, 0)
  h.setAgents([agent]); await c.prepareTaskCsvRow()
  c.receive('specialist-error', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id, message: 'Unsent draft exists.' }))
  assert.equal(c.state.csv.selected, 0); assert.match(c.state.status, /Unsent draft/)
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'Revised after rejection'); c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(0)
  await c.prepareTaskCsvRow(); assert.match(h.dispatches[1][2], /Revised after rejection/)
})

test('corrected row validation still enforces filled task and complete brief limits', async () => {
  const repeated = { ...copy(preset), task_form: { ...form, template: '{{topic}}{{topic}}{{topic}}' } }
  const h = harness([repeated]), c = h.controller
  await c.open(); c.reopen(preset.id); await c.importTaskCsv(csvFile('Subject\nShort')); c.mapTaskCsv('topic', 0); c.inspectTaskCsv()
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'x'.repeat(3000))
  assert.equal(c.applyTaskCsvRowEdit(), false); assert.match(c.state.status, /8,000/)
  assert.deepEqual(c.state.csv.corrections, {}); assert.equal(c.state.csv.editor.values.topic.length, 3000)
  c.editTaskCsvRowInput('topic', 'Fixed'); assert.equal(c.applyTaskCsvRowEdit(), true)
  const stages = Array.from({ length: 4 }, (_, index) => ({ ...copy(preset), id: `stage-${index}`, name: `Stage ${index}`, purpose: 'p'.repeat(4000), example: 'e'.repeat(7000) }))
  const large = { ...copy(preset), purpose: 'p'.repeat(1000), task_form: { ...form, template: '{{topic}}' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map(source => ({ source, handoff: 'Continue' })) } }
  const full = harness([large]), d = full.controller
  await d.open(); d.reopen(preset.id); await d.importTaskCsv(csvFile('Subject\nShort')); d.mapTaskCsv('topic', 0); d.inspectTaskCsv()
  d.beginTaskCsvRowEdit(0); d.editTaskCsvRowInput('topic', 'x'.repeat(4000))
  assert.equal(d.applyTaskCsvRowEdit(), false); assert.match(d.state.status, /48,000/)
  assert.deepEqual(d.state.csv.corrections, {}); assert.equal(d.state.csv.inspected[0].values.topic, 'Short')
  assert.equal(full.dispatches.length, 0); d.editTaskCsvRowInput('topic', 'Recovered'); assert.equal(d.applyTaskCsvRowEdit(), true)
})

test('overlong imported field can be shortened, while pending catalog preparation locks row correction actions', async () => {
  const wait = deferred(); let waiting = false
  const h = harness([preset], { fetch: async () => waiting ? wait.promise : ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  const c = await imported(h, 'Subject,Reader\nGood,Owner\n' + 'x'.repeat(4001) + ',Founder')
  c.beginTaskCsvRowEdit(1); assert.equal(c.state.csv.editor.values.topic.length, 4001)
  c.editTaskCsvRowInput('topic', 'Shortened'); c.applyTaskCsvRowEdit(); c.selectTaskCsvRow(1)
  waiting = true; const pending = c.prepareTaskCsvRow()
  assert.equal(c.beginTaskCsvRowEdit(0), false); assert.equal(c.resetTaskCsvRow(1), false); assert.equal(c.resetTaskCsvCorrections(), false)
  c.close(); wait.resolve({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) })
  assert.equal(await pending, false); assert.equal(h.dispatches.length, 0)
  waiting = false; await c.open(); assert.equal(c.state.csv.corrections[1].topic, 'Shortened')
  assert.equal(await c.prepareTaskCsvRow(), true); assert.match(h.dispatches[0][2], /Compare Shortened for Founder/)
})
