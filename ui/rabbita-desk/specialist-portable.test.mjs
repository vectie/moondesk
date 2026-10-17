import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController, specialistBrief, specialistStorageKeyFor } from './specialist-builder.js'
import { portableByteLimit, portableContract, downloadCreator } from './specialist-portable.js'

const clone = value => JSON.parse(JSON.stringify(value))
const book = { workspace_id: 'source-workspace', book_id: 'same-book', version: '1.0.0', name: 'Source Book' }
const source = (id = 'source') => ({ contract: 'moondesk.specialist-preset.v1', id, revision: 4, name: `Creator ${id}`,
  purpose: 'Inspect selected evidence', example: 'Explain the monthly report', book: { ...book },
  capabilities: ['Citations'], knowledge_paths: ['wiki/method.md', 'raw/report.md'],
  task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Explain {{topic}} for {{audience}}' } })
const agent = (workspace = 'destination-workspace', patch = {}) => ({ ...book, workspace_id: workspace, name: 'Installed Book',
  contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: 'ready', capabilities: ['Citations'], ...patch })
const response = agents => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents }) })
const file = (content, name = 'chosen.creator.json') => {
  const bytes = typeof content === 'string' ? new TextEncoder().encode(content) : content
  return { name, size: bytes.byteLength, arrayBuffer: async () => bytes.buffer.slice(bytes.byteOffset, bytes.byteOffset + bytes.byteLength) }
}
const encoded = record => JSON.stringify({ contract: portableContract, creator: record })
function setup(records = [], overrides = {}) {
  const scope = overrides.scope || 'destination-library', key = specialistStorageKeyFor(scope)
  const values = new Map([[key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const reads = [], writes = [], dispatches = [], requests = []
  const storage = { getItem: key => { reads.push(key); return values.get(key) ?? null }, setItem: (key, value) => { writes.push(key); values.set(key, value) } }
  let serial = 0, agents = [agent()]
  const controller = createSpecialistController({ scope, storage, id: () => 'local-' + ++serial,
    fetch: async url => { requests.push(url); return response(agents) }, dispatch: (...args) => dispatches.push(args), ...overrides })
  return { c: controller, scope, key, values, reads, writes, storage, dispatches, requests, setAgents(value) { agents = value } }
}
async function review(h, record = source()) {
  await h.c.open(); assert.equal(await h.c.importCreatorFile(file(encoded(record))), true)
  assert.equal(h.c.chooseImportBook('destination-workspace'), true)
}
async function adopt(h, record = source()) { await review(h, record); assert.equal(await h.c.useImportedCreator(), true) }

// Adapters execute real JS controllers and file handlers, not live host/provider runs.
test('saved export is an allowlisted exact revision, excludes transient state and never reads another origin or library', async () => {
  const record = { ...source(), ignored_legacy_state: { token: 'never-export-this' } }
  const h = setup([record], { scope: 'original-library' }); await h.c.open(); h.c.reopen('source')
  h.c.editTaskInput('topic', 'private transient value'); h.c.revise(); h.c.edit('purpose', 'unsaved private purpose')
  const packet = h.c.exportSaved('source'), data = JSON.parse(packet.content)
  assert.equal(data.contract, portableContract); assert.deepEqual(data.creator, source())
  assert.equal(packet.filename, 'Creator-source-r4.creator.json')
  assert.doesNotMatch(packet.content, /never-export-this|private transient|unsaved private|original-library/)
  assert.ok(h.reads.every(key => key === h.key)); assert.deepEqual(h.writes, []); assert.deepEqual(h.dispatches, [])
  assert.equal(h.c.exportSaved('not-saved'), false)
  h.storage.setItem(h.key, '{}'); assert.equal(h.c.exportSaved('source'), false); assert.match(h.c.state.status, /changed/)
})

test('explicit import rebinds exact installed Book, creates fresh identity, then ordinary Create/Try/Save/reload', async () => {
  const existing = { ...source('local-existing'), book: { ...book, workspace_id: 'destination-workspace' } }
  const h = setup([existing]); await review(h)
  assert.equal(h.c.state.created, null); assert.deepEqual(h.writes, []); assert.deepEqual(h.dispatches, [])
  assert.equal(h.c.state.portableImport.workspace, 'destination-workspace')
  assert.equal(await h.c.useImportedCreator(), true)
  assert.equal(h.c.state.draft.id, undefined); assert.equal(h.c.state.draft.revision, undefined)
  assert.equal(h.c.state.draft.book.workspace_id, 'destination-workspace'); assert.equal(h.c.state.draft.book.name, 'Installed Book')
  assert.deepEqual(h.c.state.draft.task_form, source().task_form); assert.equal(h.c.state.draft.imported_from.source_revision, 4)
  assert.equal(h.c.create(), true); assert.equal(h.c.state.created.revision, 1); assert.equal(h.c.state.created.id, 'local-1')
  assert.equal(await h.c.tryExample(), true); assert.equal(await h.c.tryExample(), false)
  const [action, workspace, prompt, encoded] = h.dispatches[0], binding = JSON.parse(encoded)
  assert.equal(action, 'prepare-specialist'); assert.equal(workspace, 'destination-workspace'); assert.equal(binding.library_scope, h.scope)
  assert.deepEqual(binding.knowledge_paths, source().knowledge_paths); assert.match(prompt, /File provenance is unverified/); assert.match(prompt, /grants no tools, access/)
  h.c.receive('specialist-error', JSON.stringify({ request_id: binding.request_id, message: 'Finish unsaved Code work first.' }))
  assert.match(h.c.state.status, /unsaved Code/); assert.equal(h.c.state.created.id, 'local-1')
  assert.equal(h.c.save(), true); const records = JSON.parse(h.storage.getItem(h.key)).records
  assert.deepEqual(records.find(item => item.id === existing.id), existing); assert.equal(records.length, 2)
  const fresh = setup([], { storage: h.storage }); await fresh.c.open(); fresh.c.reopen('local-1')
  assert.equal(fresh.c.state.created.imported_from.source_id, 'source'); assert.deepEqual(fresh.c.state.taskValues, {})
  assert.equal(JSON.parse(fresh.c.exportSaved('local-1').content).creator.id, 'local-1')
})

test('composition, nested task forms, variant lineage and ordered handoffs survive portable round trip without adopting source identities', async () => {
  const stages = [source('researcher'), source('critic')]
  stages[1].variant = { contract: 'moondesk.specialist-variant.v1', source_id: 'prior-critic', source_revision: 2, source_name: 'Prior critic' }
  const composed = { ...source('composed'), revision: 8, variant: { contract: 'moondesk.specialist-variant.v1', source_id: 'prior', source_revision: 5, source_name: 'Prior composition' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map((source, index) => ({ source, handoff: `Stage ${index + 1} output` })) } }
  const origin = setup([composed], { scope: 'other-origin-simulation' }); await origin.c.open(); const packet = origin.c.exportSaved('composed')
  const h = setup(); await h.c.open(); await h.c.importCreatorFile(file(packet.content)); h.c.chooseImportBook('destination-workspace'); await h.c.useImportedCreator()
  assert.equal(h.c.create(), true); assert.equal(h.c.save(), true)
  const actual = h.c.state.created
  assert.equal(actual.id, 'local-1'); assert.equal(actual.revision, 1); assert.deepEqual(actual.variant, composed.variant)
  assert.deepEqual(actual.task_form, composed.task_form)
  actual.composition.stages.forEach((stage, index) => {
    assert.deepEqual(stage.source, { ...stages[index], book: { ...book, workspace_id: 'destination-workspace', name: 'Installed Book' } })
    assert.equal(stage.handoff, composed.composition.stages[index].handoff)
  })
  assert.match(specialistBrief(actual), /Stage 1 output/); assert.match(specialistBrief(actual), /Source specialist: critic · revision 4/)
  assert.equal(h.c.state.records.length, 1); assert.deepEqual(origin.c.state.records, [composed])
})

test('unknown authority/runtime fields, unsafe references, invalid forms and nested source mutations are rejected with unchanged work/storage', async () => {
  const cases = [
    data => { data.permissions = ['shell'] }, data => { data.contract = 'moondesk.specialist-library.v1' },
    data => { data.creator.permissions = ['shell'] }, data => { data.creator.book.authority = 'owner' },
    data => { data.creator.knowledge_paths = ['raw/../secrets'] }, data => { data.creator.task_form.template = '{{constructor}}' },
    data => { data.creator.task_form.taskValues = { topic: 'run' } }, data => { data.creator.imported_from = { contract: 'bad' } },
    data => { data.creator.composition = { contract: 'moondesk.specialist-composition.v1', stages: [source('a'), source('b')].map(source => ({ source, handoff: 'next' })) }; data.creator.composition.stages[0].source.tools = ['shell'] },
    data => { data.creator.composition = { contract: 'moondesk.specialist-composition.v1', stages: [source('a'), source('b')].map(source => ({ source, handoff: 'next' })) }; data.creator.composition.stages[0].source.task_form.template = '{{bad-key}}' },
  ]
  for (const mutate of cases) {
    const h = setup(); await h.c.open(); h.c.edit('purpose', 'Keep this draft')
    const before = h.storage.getItem(h.key), data = JSON.parse(encoded(source())); mutate(data)
    assert.equal(await h.c.importCreatorFile(file(JSON.stringify(data))), false)
    assert.equal(h.c.state.draft.purpose, 'Keep this draft'); assert.equal(h.c.state.portableImport, null)
    assert.equal(h.storage.getItem(h.key), before); assert.deepEqual(h.dispatches, [])
  }
})

test('Book matching requires explicit workspace selection and rechecks ID/version/status/capabilities at adoption and Try', async () => {
  const h = setup(); h.setAgents([agent(), agent('second-local-workspace')]); await h.c.open(); await h.c.importCreatorFile(file(encoded(source())))
  assert.equal(h.c.state.portableImport.workspace, ''); assert.equal(await h.c.useImportedCreator(), false)
  assert.equal(h.c.chooseImportBook('source-workspace'), false); assert.equal(h.c.chooseImportBook('second-local-workspace'), true)
  h.setAgents([agent(), agent('second-local-workspace', { version: '2.0.0' })])
  assert.equal(await h.c.useImportedCreator(), false); assert.equal(h.c.state.portableImport.workspace, '')
  assert.equal(h.c.state.draft.name, '')
  for (const patch of [{ book_id: 'imposter' }, { version: '2' }, { status: 'needs_attention' }, { capabilities: [] }]) {
    h.setAgents([agent('destination-workspace', patch)]); await h.c.importCreatorFile(file(encoded(source())))
    assert.equal(h.c.chooseImportBook('destination-workspace'), false); assert.equal(await h.c.useImportedCreator(), false)
  }
  h.setAgents([agent()]); await h.c.importCreatorFile(file(encoded(source()))); h.c.chooseImportBook('destination-workspace'); await h.c.useImportedCreator(); h.c.create()
  h.setAgents([agent('destination-workspace', { book_id: 'replacement' })]); assert.equal(await h.c.tryExample(), false); assert.deepEqual(h.dispatches, [])
})

test('invalid UTF-8, malformed JSON, excessive size and oversized briefs remain bounded and never overwrite', async () => {
  const h = setup(); await h.c.open(); h.c.edit('name', 'Keep')
  let read = false
  const cases = [file('{oops'), file(new Uint8Array([0xff])), { size: portableByteLimit + 1, arrayBuffer() { read = true } },
    { size: 1, arrayBuffer: async () => new Uint8Array(portableByteLimit + 1).buffer }]
  for (const input of cases) { assert.equal(await h.c.importCreatorFile(input), false); assert.equal(h.c.state.draft.name, 'Keep'); assert.equal(h.c.state.importLoading, false) }
  assert.equal(read, false)
  const large = source('large'); large.purpose = 'x'.repeat(8000); large.example = 'y'.repeat(8000)
  large.composition = { contract: 'moondesk.specialist-composition.v1', stages: ['a', 'b', 'c', 'd'].map(id => ({ source: { ...source(id), purpose: 'z'.repeat(8000), example: 't'.repeat(8000) }, handoff: 'pass it' })) }
  assert.equal(await h.c.importCreatorFile(file(encoded(large))), false); assert.match(h.c.state.status, /48,000/)
  assert.deepEqual(h.writes, []); assert.deepEqual(h.dispatches, [])
})

test('Cancel, Close, a newer file and navigation invalidate delayed import reads without replacing drafts', async () => {
  const h = setup(); await h.c.open(); h.c.edit('purpose', 'Keep draft')
  const oldDraft = clone(h.c.state.draft)
  for (const cancel of [() => h.c.cancelCreatorImport(), () => h.c.close(), () => h.c.newDraft()]) {
    let release
    const pending = h.c.importCreatorFile({ size: 5, arrayBuffer: () => new Promise(resolve => { release = resolve }) })
    cancel(); release(await file(encoded(source())).arrayBuffer()); assert.equal(await pending, false)
    assert.equal(h.c.state.portableImport, null); assert.equal(h.c.state.importLoading, false)
    if (!h.c.state.open) await h.c.open()
  }
  h.c.state.draft = clone(oldDraft)
  let release
  const older = h.c.importCreatorFile({ size: 1, arrayBuffer: () => new Promise(resolve => { release = resolve }) })
  await h.c.importCreatorFile(file(encoded(source('newer')))); release(await file(encoded(source('older'))).arrayBuffer()); await older
  assert.equal(h.c.state.portableImport.creator.id, 'newer'); assert.deepEqual(h.c.state.draft, oldDraft)
  h.c.cancelCreatorImport(); assert.deepEqual(h.c.state.draft, oldDraft)
})

test('adoption is single-flight and cannot overwrite Close, Cancel, navigation or newer edits during catalog refresh', async () => {
  for (const interrupt of ['close', 'cancel', 'new', 'edit']) {
    let delayed = false, release
    const h = setup([], { fetch: async () => delayed ? new Promise(resolve => { release = resolve }) : response([agent()]) })
    await review(h); h.c.edit('purpose', 'Existing draft'); delayed = true
    const pending = h.c.useImportedCreator(); assert.equal(await h.c.useImportedCreator(), false)
    if (interrupt === 'close') h.c.close()
    if (interrupt === 'cancel') h.c.cancelCreatorImport()
    if (interrupt === 'new') h.c.newDraft()
    if (interrupt === 'edit') h.c.edit('purpose', 'Newer edit')
    release(response([agent()])); assert.equal(await pending, false)
    assert.equal(h.c.state.created, null); assert.equal(h.c.state.importLoading, false)
    assert.equal(h.c.state.draft.imported_from, undefined)
    if (interrupt === 'edit') { assert.equal(h.c.state.draft.purpose, 'Newer edit'); assert.match(h.c.state.status, /draft changed/) }
    assert.deepEqual(h.writes, []); assert.deepEqual(h.dispatches, [])
  }
})

test('repeated file import makes independent drafts, identity collisions and storage failures never replace saved creators', async () => {
  const h = setup(); await adopt(h); h.c.create(); h.c.save(); const first = clone(h.c.state.created)
  await h.c.importCreatorFile(file(encoded(source()))); h.c.chooseImportBook('destination-workspace'); await h.c.useImportedCreator(); h.c.create(); h.c.save()
  assert.notEqual(h.c.state.created.id, first.id); assert.equal(h.c.state.created.revision, 1); assert.equal(h.c.state.records.length, 2)
  const collision = setup([first], { id: () => first.id }); await adopt(collision); assert.equal(collision.c.create(), false); assert.equal(collision.c.save(), false)
  assert.deepEqual(collision.c.state.records, [first])
  const denied = setup(); await adopt(denied); denied.c.create(); denied.storage.setItem = () => { throw new Error('Storage denied') }
  assert.equal(denied.c.save(), false); assert.match(denied.c.state.status, /Storage denied/); assert.ok(denied.c.state.created.imported_from)
})

test('local download produces only an application/json Blob and releases its object URL even on a blocked click', () => {
  const packet = { content: encoded(source()), filename: 'creator.json' }, blobs = [], urls = [], timers = [], clicks = []
  const link = { click() { clicks.push([this.href, this.download]) }, remove() { this.removed = true } }
  const options = { document: { body: { append(node) { assert.equal(node, link) } }, createElement(tag) { assert.equal(tag, 'a'); return link } },
    Blob: class { constructor(parts, options) { blobs.push({ parts, options }) } },
    URL: { createObjectURL() { return 'blob:local-only' }, revokeObjectURL(url) { urls.push(url) } }, later: fn => timers.push(fn) }
  downloadCreator(packet, options); assert.deepEqual(clicks, [['blob:local-only', 'creator.json']]); assert.equal(link.removed, true)
  assert.deepEqual(blobs[0].parts, [packet.content]); assert.match(blobs[0].options.type, /application\/json/); timers.shift()(); assert.deepEqual(urls, ['blob:local-only'])
  link.click = () => { throw new Error('Blocked download') }; assert.throws(() => downloadCreator(packet, options), /Blocked download/)
  timers.shift()(); assert.equal(urls.length, 2)
})

test('import never adopts the exported source ID even when it is unused in the destination', async () => {
  const h = setup([], { id: () => 'source' }); await adopt(h)
  assert.equal(h.c.create(), false); assert.match(h.c.state.status, /distinct identity/)
  assert.equal(h.c.state.created, null); assert.deepEqual(h.writes, [])
})

test('catalog interruption retains review for explicit retry; prepared work blocks importing and export failure is honest', async () => {
  let offline = false
  const h = setup([], { fetch: async () => { if (offline) throw new Error('Catalog disconnected'); return response([agent()]) } })
  await h.c.open(); h.c.edit('purpose', 'Keep original work'); offline = true
  assert.equal(await h.c.importCreatorFile(file(encoded(source()))), false)
  assert.match(h.c.state.status, /disconnected/); assert.equal(h.c.state.portableImport.creator.id, 'source')
  assert.equal(h.c.state.draft.purpose, 'Keep original work'); h.c.close(); offline = false; await h.c.open()
  h.c.chooseImportBook('destination-workspace'); assert.equal(await h.c.useImportedCreator(), true); h.c.create(); h.c.save()
  const created = clone(h.c.state.created)
  assert.equal(h.c.exportSaved(created.id, () => { throw new Error('Browser blocked the download') }), false)
  assert.match(h.c.state.status, /blocked the download/)
  await h.c.tryExample(); assert.equal(await h.c.importCreatorFile(file(encoded(source('different')))), false)
  assert.equal(h.c.exportSaved(created.id), false); assert.deepEqual(h.c.state.created, created)
})

test('other-window saves still block saving a portable creator and leave both versions recoverable', async () => {
  const h = setup(); await adopt(h); assert.equal(h.c.create(), true)
  const imported = clone(h.c.state.created), other = { ...source('other'), book: { ...book, workspace_id: 'destination-workspace' } }
  const external = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [other] })
  h.storage.setItem(h.key, external)
  assert.equal(h.c.save(), false); assert.match(h.c.state.status, /another window/)
  assert.equal(h.storage.getItem(h.key), external); assert.deepEqual(h.c.state.created, imported)
  h.c.close(); await h.c.open(); assert.equal(h.c.save(), true)
  assert.deepEqual(h.c.state.records.find(item => item.id === other.id), other)
})

test('a local variant of an imported creator records its immediate local source without relabeling it as foreign lineage', async () => {
  const h = setup(); await adopt(h); h.c.create(); h.c.save(); const imported = clone(h.c.state.created)
  assert.equal(h.c.forkSaved(imported.id), true); assert.equal(h.c.state.draft.imported_from, undefined)
  assert.equal(h.c.state.draft.variant.source_id, imported.id); assert.equal(h.c.create(), true); assert.equal(h.c.save(), true)
  assert.deepEqual(h.c.state.records.find(item => item.id === imported.id), imported)
})

test('initial catalog loading cannot race an import adoption or read a file before the builder is ready', async () => {
  let release, read = false
  const h = setup([], { fetch: () => new Promise(resolve => { release = resolve }) })
  const opening = h.c.open()
  assert.equal(await h.c.importCreatorFile({ size: 1, arrayBuffer() { read = true } }), false)
  assert.equal(read, false); assert.equal(h.c.state.portableImport, null)
  release(response([agent()])); await opening; assert.equal(h.c.state.loading, false)
})
