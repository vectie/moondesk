import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { createSpecialistController, specialistStorageKeyFor } from './specialist-builder.js'
import { taskBatchByteLimit, taskBatchContract } from './specialist-task-batch.js'

const copy = value => structuredClone(value)
const creator = { contract: 'moondesk.specialist-preset.v1', id: 'analyst', revision: 4, name: 'Analyst', purpose: 'Compare evidence', example: 'Compare Q3',
  book: { workspace_id: 'book-a', book_id: 'source-book', name: 'Source Book', version: '1.0.0' }, capabilities: ['Evidence'], knowledge_paths: ['raw/report.md'],
  task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Compare {{topic}} for {{audience}}.' } }
const agent = { ...creator.book, contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: 'ready' , capabilities: ['Evidence'] }
const file = (content, name = 'tasks.creator-tasks.json') => { const bytes = typeof content === 'string' ? new TextEncoder().encode(content) : content; return { name, size: bytes.byteLength, arrayBuffer: async () => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) } }
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no }); return { promise, resolve, reject } }
function setup(records = [creator], options = {}) {
  const key = specialistStorageKeyFor('batch-library'), values = new Map([[key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const writes = [], dispatches = [], requests = []
  const storage = options.storage || { getItem: key => values.get(key) ?? null, setItem: (key, value) => { writes.push(key); values.set(key, value) } }
  let serial = 0
  const c = createSpecialistController({ scope: 'batch-library', storage, id: () => 'batch-' + ++serial,
    fetch: async url => { requests.push(url); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) } },
    dispatch: (...args) => dispatches.push(args), ...options })
  return { c, storage, key, writes, dispatches, requests }
}
async function open(h, id = creator.id) { await h.c.open(); h.c.reopen(id); return h.c }
async function batch(h = setup(), source = '\uFEFFReader,Subject,Unused\r\nFounder,,private original column\r\nAnalyst,"001.00, quoted",=1+2\r\nwrong-width') {
  const c = await open(h)
  assert.equal(await c.importTaskCsv(file(source, 'original.csv')), true)
  c.mapTaskCsv('topic', 1); c.mapTaskCsv('audience', 0); c.inspectTaskCsv()
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', '<b>literal</b> $& {{audience}}'); assert.equal(c.applyTaskCsvRowEdit(), true)
  return h
}

test('checkpoint survives a fresh controller and restores exact cells, mapped corrections and a freshly reviewed one-row brief', async () => {
  const h = await batch(), c = h.c, original = copy(c.state.csv)
  c.editTaskInput('topic', 'manual-private'); c.editTaskInput('audience', 'manual-reader')
  c.selectTaskCsvRow(0); const expected = c.state.csv.inspected[0].brief
  const packet = c.exportTaskCheckpoint(), data = JSON.parse(packet.content)
  assert.equal(data.contract, taskBatchContract); assert.equal(packet.filename, 'Analyst-r4.creator-tasks.json')
  assert.equal(data.csv.source, original.source); assert.deepEqual(data.mapping, { topic: 1, audience: 0 })
  assert.deepEqual(data.corrections, original.corrections); assert.deepEqual(data.creator, creator)
  assert.doesNotMatch(packet.content, /manual-private|manual-reader|inspected|selected|pending|prepared|batch-library/)
  const fresh = setup([], { storage: h.storage }), resumed = await open(fresh)
  assert.equal(await resumed.importTaskCheckpoint(file(packet.content)), true)
  assert.deepEqual(resumed.state.csv.rows, original.rows); assert.deepEqual(resumed.state.csv.headers, original.headers)
  assert.deepEqual(resumed.state.csv.inspected, []); assert.equal(resumed.state.csv.selected, null)
  assert.equal(await resumed.prepareTaskCsvRow(), false); assert.equal(resumed.inspectTaskCsv(), true)
  assert.match(resumed.state.csv.inspected[2].errors.join(' '), /Expected 3 cells/)
  assert.equal(resumed.state.csv.inspected[0].originalValues.topic, '')
  resumed.selectTaskCsvRow(0); assert.equal(resumed.state.csv.inspected[0].brief, expected)
  assert.equal(await resumed.prepareTaskCsvRow(), true); assert.equal(fresh.dispatches.length, 1)
  assert.equal(fresh.dispatches[0][0], 'prepare-specialist'); assert.equal(fresh.dispatches[0][2], expected)
  resumed.receive('specialist-error', JSON.stringify({ request_id: JSON.parse(fresh.dispatches[0][3]).request_id, message: 'Finish unsent Code work first.' }))
  assert.match(resumed.state.status, /unsent Code/); assert.deepEqual(resumed.state.csv.corrections, original.corrections)
  assert.deepEqual(h.writes, []); assert.deepEqual(fresh.writes, []); assert.deepEqual(h.dispatches, [])
})

test('partial column mapping and original invalid values can be checkpointed without inventing readiness', async () => {
  const h = setup(), c = await open(h)
  await c.importTaskCsv(file('A,B\n,\n' + 'x'.repeat(4001) + ',reader', 'unfinished.csv')); c.mapTaskCsv('topic', 0)
  const packet = c.exportTaskCheckpoint(); c.clearTaskCsv()
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), true)
  assert.deepEqual(c.state.csv.mapping, { topic: 0 }); assert.equal(c.inspectTaskCsv(), false)
  c.mapTaskCsv('audience', 1); assert.equal(c.inspectTaskCsv(), true)
  assert.equal(c.state.csv.inspected.every(row => row.errors.length > 0), true)
  assert.equal(await c.prepareTaskCsvRow(), false); assert.deepEqual(h.dispatches, [])
})

test('save blocks pending edits and download failures without discarding corrections or claiming a disk write', async () => {
  const h = await batch(), c = h.c, before = copy(c.state.csv)
  c.beginTaskCsvRowEdit(0); c.editTaskCsvRowInput('topic', 'not applied')
  assert.equal(c.exportTaskCheckpoint(), false); assert.match(c.state.status, /Apply or cancel/)
  c.cancelTaskCsvRowEdit(); assert.deepEqual(c.state.csv.corrections, before.corrections)
  assert.equal(c.exportTaskCheckpoint(() => { throw Error('Download unavailable') }), false)
  assert.match(c.state.status, /Download unavailable/); assert.deepEqual(c.state.csv.corrections, before.corrections)
  const packets = []; assert.ok(c.exportTaskCheckpoint(packet => packets.push(packet)))
  assert.equal(packets.length, 1); assert.match(c.state.status, /download requested/)
  assert.doesNotMatch(c.state.status, /saved to disk/i)
})

test('task-only files and unrelated legacy state never leave through checkpoint export and cannot silently enter restore', async () => {
  const record = { ...copy(creator), ignored_legacy: { token: 'legacy-private-token' } }
  const h = await batch(setup([record])), c = h.c
  await c.addTaskFile(file('task-only-private-text', 'private.txt'))
  const packet = c.exportTaskCheckpoint()
  assert.doesNotMatch(packet.content, /legacy-private-token|task-only-private-text|private.txt/)
  const prior = copy(c.state.csv), files = copy(c.state.taskFiles)
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), false)
  assert.match(c.state.status, /Clear task-only files/); assert.deepEqual(c.state.csv, prior); assert.deepEqual(c.state.taskFiles, files)
  c.clearTaskFiles(); assert.equal(await c.importTaskCheckpoint(file(packet.content)), true)
  assert.deepEqual(c.state.taskFiles, []); assert.deepEqual(c.state.created, record)
})

test('every creator identity, template and composition snapshot must match instead of being adopted from a checkpoint', async () => {
  const stage = id => ({ ...copy(creator), id, name: id })
  const record = { ...copy(creator), composition: { contract: 'moondesk.specialist-composition.v1', stages: [{ source: stage('one'), handoff: 'Cite evidence' }, { source: stage('two'), handoff: 'Review claims' }] } }
  const h = await batch(setup([record])), c = h.c, packet = c.exportTaskCheckpoint(), before = copy(c.state.csv)
  for (const mutate of [r => r.id = 'other', r => r.revision++, r => r.book.version = '2.0.0', r => r.task_form.template += ' revised', r => r.composition.stages[0].source.purpose = 'Changed source', r => r.composition.stages.reverse(), r => r.composition.stages[0].handoff = 'New handoff']) {
    const data = JSON.parse(packet.content); mutate(data.creator)
    assert.equal(await c.importTaskCheckpoint(file(JSON.stringify(data))), false)
    assert.match(c.state.status, /exact saved creator|invalid creator definition/); assert.deepEqual(c.state.csv, before)
  }
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), true)
  assert.deepEqual(c.state.csv.creator.composition, record.composition)
  assert.deepEqual(c.state.records, [record]); assert.deepEqual(h.writes, [])
})

test('unknown fields, authority hints, malformed mappings and out-of-range or invalid corrections are rejected atomically', async () => {
  const h = await batch(), c = h.c, packet = c.exportTaskCheckpoint(), before = copy(c.state.csv)
  const mutations = [d => d.contract = 'other', d => d.prepared = true, d => d.creator.authority = 'grant', d => d.csv.filename = 'extra', d => d.csv.source = 'bad',
    d => d.mapping.unknown = 0, d => d.mapping.topic = '1', d => d.mapping.topic = 3, d => delete d.mapping.topic,
    d => d.corrections['99'] = d.corrections['0'], d => d.corrections['00'] = d.corrections['0'], d => d.corrections['2'] = d.corrections['0'],
    d => d.corrections['0'].unknown = 'bad', d => d.corrections['0'].topic = '', d => d.corrections['0'].topic = 'x'.repeat(4001),
    d => d.corrections['0'].topic = '\0', d => d.corrections['0'] = [], d => d.corrections['0'] = { topic: 'value' },
    d => d.corrections = JSON.parse('{"__proto__":{"topic":"evil","audience":"reader"}}')]
  for (const mutate of mutations) {
    const data = JSON.parse(packet.content); mutate(data)
    assert.equal(await c.importTaskCheckpoint(file(JSON.stringify(data))), false)
    assert.deepEqual(c.state.csv, before)
  }
  assert.deepEqual(h.writes, []); assert.deepEqual(h.dispatches, [])
})

test('strict UTF-8, real read size, JSON and file failures retain existing work and report the error', async () => {
  const h = await batch(), c = h.c, before = copy(c.state.csv)
  for (const input of [file(new Uint8Array([0xc0, 0x80])), file('{bad'), { size: taskBatchByteLimit + 1, arrayBuffer() { throw Error('must not read') } },
    { size: 0, arrayBuffer: async () => new Uint8Array(taskBatchByteLimit + 1).buffer }, { size: 1, arrayBuffer: async () => { throw Error('read failed') } }]) {
    assert.equal(await c.importTaskCheckpoint(input), false); assert.deepEqual(c.state.csv, before); assert.equal(c.state.csvLoading, false)
  }
})

test('cross-window creator changes before or during read block restoration without overwriting the working batch', async () => {
  const h = await batch(), c = h.c, packet = c.exportTaskCheckpoint(), before = copy(c.state.csv), raw = h.storage.getItem(h.key)
  h.storage.setItem(h.key, raw + ' ')
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), false); assert.match(c.state.status, /changed/)
  h.storage.setItem(h.key, raw)
  const slow = deferred(), pending = c.importTaskCheckpoint({ size: 1, arrayBuffer: () => slow.promise })
  h.storage.setItem(h.key, raw + ' '); slow.resolve(new TextEncoder().encode(packet.content).buffer)
  assert.equal(await pending, false); assert.match(c.state.status, /changed/); assert.deepEqual(c.state.csv, before)
})

test('latest checkpoint or CSV read wins and stale failures cannot replace new data or status', async () => {
  const h = await batch(), c = h.c, packet = c.exportTaskCheckpoint(), slow = deferred()
  const pending = c.importTaskCheckpoint({ size: 1, arrayBuffer: () => slow.promise })
  assert.equal(await c.importTaskCsv(file('A,B\nNew,Data', 'new.csv')), true)
  const before = copy(c.state.csv), status = c.state.status
  slow.reject(Error('old failure')); assert.equal(await pending, false)
  assert.deepEqual(c.state.csv, before); assert.equal(c.state.status, status)
  const slowCsv = deferred(), csvPending = c.importTaskCsv({ size: 1, arrayBuffer: () => slowCsv.promise })
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), true)
  slowCsv.resolve(new TextEncoder().encode('A\nlate').buffer); assert.equal(await csvPending, false)
  assert.equal(c.state.csv.name, 'original.csv')
})

test('Close, Clear, creator revision and switching cancel pending restores', async () => {
  for (const action of ['close', 'clearTaskCsv', 'revise', 'reopen', 'newDraft']) {
    const h = await batch(), c = h.c, packet = c.exportTaskCheckpoint(), slow = deferred()
    const pending = c.importTaskCheckpoint({ size: 1, arrayBuffer: () => slow.promise })
    if (action === 'reopen') c.reopen(creator.id); else c[action]()
    const before = copy(c.state.csv), status = c.state.status
    slow.resolve(new TextEncoder().encode(packet.content).buffer); assert.equal(await pending, false)
    assert.deepEqual(c.state.csv, before); assert.equal(c.state.status, status); assert.equal(c.state.csvLoading, false)
  }
})

test('task-file reads appearing during restore keep both existing batch and newly selected file', async () => {
  const h = await batch(), c = h.c, packet = c.exportTaskCheckpoint(), before = copy(c.state.csv), slow = deferred()
  const pending = c.importTaskCheckpoint({ size: 1, arrayBuffer: () => slow.promise })
  await c.addTaskFile(file('selected while restoring', 'new.txt'))
  slow.resolve(new TextEncoder().encode(packet.content).buffer)
  assert.equal(await pending, false); assert.match(c.state.status, /Task-only files changed/)
  assert.deepEqual(c.state.csv.rows, before.rows); assert.deepEqual(c.state.csv.corrections, before.corrections)
  assert.equal(c.state.taskFiles[0].content, 'selected while restoring')
})

test('resumed tasks retain Book/version gates and single-flight preparation without reporting run completion', async () => {
  const h = await batch(), packet = h.c.exportTaskCheckpoint()
  const fresh = setup([creator], { fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [{ ...agent, version: '2.0.0' }] }) }) }), c = await open(fresh)
  assert.equal(await c.importTaskCheckpoint(file(packet.content)), true); c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  assert.equal(await c.prepareTaskCsvRow(), false); assert.match(c.state.status, /version changed/); assert.deepEqual(fresh.dispatches, [])
  const good = setup(), ready = await open(good); await ready.importTaskCheckpoint(file(packet.content)); ready.inspectTaskCsv(); ready.selectTaskCsvRow(0)
  assert.equal(await ready.prepareTaskCsvRow(), true); assert.equal(await ready.prepareTaskCsvRow(), false)
  assert.equal(ready.exportTaskCheckpoint(), false); assert.equal(await ready.importTaskCheckpoint(file(packet.content)), false)
  assert.equal(good.dispatches.length, 1)
  ready.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(good.dispatches[0][3]).request_id }))
  assert.match(ready.state.status, /Click Send/); assert.equal(ready.state.open, false)
})

test('portable sample exercises real CSV mapping, correction, checkpoint and reinspection', async () => {
  const sample = readFileSync(new URL('../../docs/samples/creator-task-checkpoint/tasks.csv', import.meta.url), 'utf8')
  const h = await batch(setup(), sample), packet = h.c.exportTaskCheckpoint()
  h.c.clearTaskCsv(); assert.equal(await h.c.importTaskCheckpoint(file(packet.content)), true)
  assert.equal(h.c.inspectTaskCsv(), true); assert.equal(h.c.state.csv.inspected[0].errors.length, 0)
  assert.equal(h.c.state.csv.inspected[0].originalValues.topic, '')
})
