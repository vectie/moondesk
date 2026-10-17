import test from 'node:test'
import assert from 'node:assert/strict'
import { readTaskFile, withTaskFiles, taskFileLimits } from './specialist-task-files.js'
import { createSpecialistController, specialistStorageKeyFor, specialistBrief } from './specialist-builder.js'
const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', workspace_id: 'book-a', book_id: 'book', name: 'Book', version: '1', status: 'ready', capabilities: [] }
const preset = { contract: 'moondesk.specialist-preset.v1', id: 'creator', revision: 3, name: 'Writer', purpose: 'Write from supplied evidence', example: 'Summarize this quarter', book: { workspace_id: 'book-a', book_id: 'book', name: 'Book', version: '1' }, capabilities: [], knowledge_paths: ['wiki/method.md'], task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Write about {{topic}}' } }
const file = (content = 'Revenue 001.20\r\nCosts 0.50', name = 'results.txt') => ({ name, size: new TextEncoder().encode(content).length, arrayBuffer: async () => new TextEncoder().encode(content).buffer })
const deferred = () => { let resolve, reject; const promise = new Promise((yes, no) => { resolve = yes; reject = no }); return { promise, resolve, reject } }
async function harness(extra = {}) {
  const values = new Map([[specialistStorageKeyFor('files-library'), JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [preset] })]])
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }, dispatches = [], requests = []
  let agents = [agent], serial = 0
  const c = createSpecialistController({ scope: 'files-library', storage, fetch: async url => { requests.push(url); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents }) } }, dispatch: (...args) => dispatches.push(args), id: () => `request-${++serial}`, ...extra })
  await c.open(); c.reopen('creator')
  return { c, storage, dispatches, requests, setAgents(next) { agents = next } }
}
const ack = (c, calls, action = 'specialist-prepared') => c.receive(action, JSON.stringify({ request_id: JSON.parse(calls.at(-1)[3]).request_id, message: 'Unsent chat needs attention' }))

test('task files preserve UTF-8 lexical text, BOM, CRLF and markup as data', async () => {
  const content = '\ufeff<script>alert(1)</script>\r\n001.20\n=SUM(A1)\t☾'
  const snapshot = await readTaskFile(file(content, 'Δ.txt'))
  assert.equal(snapshot.content, content)
  const brief = withTaskFiles('Creator brief', [snapshot])
  assert.deepEqual(JSON.parse(brief.slice(brief.indexOf('[\n'))), [{ filename: 'Δ.txt', content_utf8: content }])
  assert.match(brief, /untrusted task data/)
})

test('binary, oversized declared/actual data, unreadable and unsafe filename imports fail closed', async () => {
  for (const input of [null, file(''), file(' \n'), file('binary\0'), file('beep\x07'), file('ok', '../a.txt'), file('ok', 'bad\n.txt'), file('ok', 'a'.repeat(201)), { ...file(), size: -1 }, { ...file(), size: 1.5 }, { ...file(), size: taskFileLimits.bytes + 1 }, { ...file(), arrayBuffer: async () => new Uint8Array([0xc0, 0x80]).buffer }, { ...file(), arrayBuffer: async () => new ArrayBuffer(taskFileLimits.bytes + 1) }]) await assert.rejects(readTaskFile(input))
  await assert.rejects(readTaskFile({ ...file(), arrayBuffer: async () => { throw Error('Local read failed') } }), /Local read failed/)
  assert.throws(() => withTaskFiles('brief', Array.from({ length: 5 }, (_, i) => ({ name: '' + i, content: 'a' }))), /four/)
  assert.throws(() => withTaskFiles('brief', [{ name: 'a', content: 'a' }, { name: 'a', content: 'b' }]), /distinct/)
  assert.throws(() => withTaskFiles('brief', [{ name: 'a', content: 'x'.repeat(65537) }]), /64 KiB/)
  assert.throws(() => withTaskFiles('x'.repeat(47900), [{ name: 'a', content: 'a' }]), /48,000/)
})

test('creator→temporary file→exact prepared brief keeps saved creator/export/Book references unchanged and clears after acknowledgement', async () => {
  const { c, storage, dispatches, requests } = await harness(), raw = storage.getItem(specialistStorageKeyFor('files-library'))
  assert.equal(await c.addTaskFile(file()), true)
  const preview = c.taskBrief(c.state.created)
  assert.match(preview, /results.txt/); assert.match(preview, /001.20/)
  assert.equal(c.save(), true)
  assert.equal(storage.getItem(specialistStorageKeyFor('files-library')), raw)
  assert.doesNotMatch(JSON.stringify(c.exportSaved('creator')), /001.20|results.txt/)
  assert.equal(await c.tryExample(), true); assert.equal(await c.tryExample(), false)
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][2], preview)
  assert.deepEqual(JSON.parse(dispatches[0][3]).knowledge_paths, ['wiki/method.md'])
  assert.equal(await c.addTaskFile(file('another')), false); assert.equal(c.clearTaskFiles(), false)
  ack(c, dispatches)
  assert.deepEqual(c.state.taskFiles, []); assert.equal(c.state.open, false)
  await c.open(); assert.equal(c.taskBrief(c.state.created), specialistBrief(preset))
  assert.equal(await c.tryExample(), true); assert.doesNotMatch(dispatches[1][2], /results.txt/)
  assert.deepEqual(requests, Array(requests.length).fill('/api/desktop/agents'))
})

test('files invalidate exact filled-task previews and selected CSV rows; each task must be reviewed again', async () => {
  const { c, dispatches } = await harness()
  c.editTaskInput('topic', 'Q4'); c.previewTask(); const prior = c.state.taskPreview
  await c.addTaskFile(file()); assert.equal(c.state.taskPreview, '')
  assert.equal(await c.prepareTask(), false); assert.equal(c.previewTask(), true)
  assert.notEqual(c.state.taskPreview, prior); assert.equal(await c.prepareTask(), true)
  ack(c, dispatches, 'specialist-rejected'); assert.equal(c.state.taskFiles.length, 1)
  c.removeTaskFile(0); assert.equal(c.state.taskPreview, '')
  await c.importTaskCsv(file('Topic\nFirst\nSecond', 'tasks.csv')); c.mapTaskCsv('topic', 0); c.inspectTaskCsv(); c.selectTaskCsvRow(0)
  await c.addTaskFile(file()); assert.equal(c.state.csv.inspected.length, 0); assert.equal(c.state.csv.selected, null)
  assert.equal(await c.prepareTaskCsvRow(), false)
  c.inspectTaskCsv(); c.selectTaskCsvRow(0); const exact = c.state.csv.inspected[0].brief
  assert.equal(await c.prepareTaskCsvRow(), true); assert.equal(dispatches.at(-1)[2], exact)
  ack(c, dispatches); await c.open(); c.inspectTaskCsv(); c.selectTaskCsvRow(1)
  assert.equal(await c.prepareTaskCsvRow(), true); assert.doesNotMatch(dispatches.at(-1)[2], /results.txt/)
})

test('latest file wins; invalid replacement keeps prior files; reads cannot cross Close, Cancel, revision or creator navigation', async () => {
  for (const action of ['close', 'clearTaskFiles', 'revise', 'newDraft', 'reopen']) {
    const { c, dispatches } = await harness(); await c.addTaskFile(file())
    const slow = deferred(), pending = c.addTaskFile({ ...file('late', 'late.txt'), arrayBuffer: () => slow.promise })
    assert.equal(await c.tryExample(), false); assert.equal(dispatches.length, 0)
    if (action === 'reopen') c.reopen('creator'); else c[action]()
    slow.resolve(new TextEncoder().encode('late').buffer); assert.equal(await pending, false)
    assert.equal(c.state.taskFileLoading, false)
    assert.equal(c.state.taskFiles.length, action === 'close' ? 1 : 0)
    if (action === 'close') { await c.open(); assert.equal(c.state.taskFiles[0].name, 'results.txt') }
  }
  const { c } = await harness(); const slow = deferred()
  const older = c.addTaskFile({ ...file('old', 'old.txt'), arrayBuffer: () => slow.promise })
  await c.addTaskFile(file('new', 'new.txt')); const status = c.state.status
  slow.reject(Error('Stale read failed')); assert.equal(await older, false); assert.equal(c.state.status, status)
  assert.deepEqual(c.state.taskFiles.map(item => item.name), ['new.txt'])
  assert.equal(await c.addTaskFile(file('different', 'new.txt')), false)
  assert.equal(c.state.taskFiles[0].content, 'new')
})

test('Book drift, ordinary rejection and failed local reads preserve temporary files for explicit retry', async () => {
  const h = await harness(), { c, dispatches } = h
  await c.addTaskFile(file()); h.setAgents([{ ...agent, version: '2' }])
  assert.equal(await c.tryExample(), false); assert.equal(dispatches.length, 0); assert.equal(c.state.taskFiles.length, 1)
  h.setAgents([agent]); await c.tryExample(); ack(c, dispatches, 'specialist-rejected')
  assert.equal(c.state.open, true); assert.equal(c.state.taskFiles.length, 1)
  assert.equal(await c.addTaskFile({ ...file('a', 'failed.txt'), arrayBuffer: async () => { throw Error('Read failed') } }), false)
  assert.equal(c.state.taskFiles.length, 1)
  await c.tryExample(); ack(c, dispatches); assert.equal(c.state.taskFiles.length, 0)
})
