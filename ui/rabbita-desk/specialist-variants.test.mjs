import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController, specialistBrief, specialistStorageKeyFor } from './specialist-builder.js'

const scope = 'variant-library', key = specialistStorageKeyFor(scope)
const book = { workspace_id: 'research', book_id: 'research-book', name: 'Research Book', version: '1.0.0' }
const agent = { ...book, contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: 'ready', capabilities: ['Citations'] }
const catalog = { contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }
const source = (id = 'original') => ({ contract: 'moondesk.specialist-preset.v1', id, revision: 3,
  name: 'Evidence creator ' + id, purpose: 'Compare claims with citations', example: 'Summarize the October results', book: { ...book },
  capabilities: ['Citations'], knowledge_paths: ['wiki/method.md', 'raw/report.md'],
  task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Explain {{topic}} for {{audience}}' } })
const clone = value => JSON.parse(JSON.stringify(value))
function setup(records = [source()], overrides = {}) {
  const values = new Map([[key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }, dispatches = []
  let serial = 0
  const controller = createSpecialistController({ scope, storage,
    fetch: async () => ({ ok: true, json: async () => catalog }), id: () => 'variant-' + ++serial,
    dispatch: (...args) => dispatches.push(args), ...overrides })
  return { controller, storage, dispatches, saved: () => JSON.parse(storage.getItem(key)).records }
}

test('saved creator forks to a new named identity, preserves source snapshot and uses ordinary prepare/save/revise', async () => {
  const h = setup(), c = h.controller, original = source()
  await c.open(); c.reopen(original.id); c.editTaskInput('topic', 'Transient task'); c.editTaskInput('audience', 'Founders'); c.previewTask()
  assert.equal(c.forkSaved(original.id), true)
  assert.equal(c.state.created, null); assert.equal(c.state.editing, true); assert.deepEqual(c.state.taskValues, {}); assert.equal(c.state.taskPreview, '')
  assert.deepEqual(c.state.draft.task_form, original.task_form); assert.deepEqual(c.state.draft.knowledge_paths, original.knowledge_paths)
  assert.notEqual(c.state.draft.book, c.state.records[0].book)
  assert.deepEqual(c.state.draft.variant, { contract: 'moondesk.specialist-variant.v1', source_id: original.id, source_revision: 3, source_name: original.name })
  c.edit('name', 'Investor evidence creator'); c.edit('purpose', 'Compare financial claims with citations')
  assert.equal(c.create(), true); assert.equal(c.state.created.revision, 1); assert.notEqual(c.state.created.id, original.id)
  const variantId = c.state.created.id
  assert.equal(h.saved().length, 1); assert.equal(h.dispatches.length, 0)
  assert.equal(await c.tryExample(), true); assert.equal(await c.tryExample(), false)
  const [action, workspace, prompt, encoded] = h.dispatches[0]
  assert.equal(action, 'prepare-specialist'); assert.equal(workspace, book.workspace_id)
  assert.match(prompt, /Variant source: Evidence creator original \[original\] · saved revision 3/)
  assert.deepEqual(JSON.parse(encoded).knowledge_paths, original.knowledge_paths)
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(encoded).request_id })); await c.open()
  assert.equal(c.save(), true); assert.deepEqual(h.saved().find(row => row.id === original.id), original)
  c.revise(); c.editTaskTemplate('Analyze {{topic}}'); assert.equal(c.create(), true); assert.equal(c.save(), true)
  assert.equal(c.state.created.id, variantId); assert.equal(c.state.created.revision, 2)
  assert.deepEqual(h.saved().find(row => row.id === original.id), original)
  const fresh = setup([], { storage: h.storage }); await fresh.controller.open(); fresh.controller.reopen(variantId)
  assert.equal(fresh.controller.state.created.variant.source_revision, 3); assert.equal(fresh.controller.state.created.revision, 2)
  assert.match(specialistBrief(fresh.controller.state.created), /grants no tools, access/)
})

test('composed variant deeply copies all stages, task forms, handoffs and reference selections', async () => {
  const first = source('researcher'), second = source('critic')
  const composite = { ...source('composite'), revision: 5, composition: { contract: 'moondesk.specialist-composition.v1',
    stages: [{ source: first, handoff: 'Send evidence to critic' }, { source: second, handoff: 'Produce final review' }] } }
  const h = setup([first, second, composite]), c = h.controller
  await c.open(); assert.equal(c.forkSaved('composite'), true)
  assert.deepEqual(c.state.draft.composition, composite.composition)
  c.editHandoff(0, 'Produce investor evidence'); c.moveStage(1, -1)
  assert.equal(c.state.draft.composition.stages[1].source.task_form.template, first.task_form.template)
  assert.deepEqual(c.state.records.find(row => row.id === 'composite'), composite)
  assert.equal(c.create(), true); assert.equal(c.save(), true)
  assert.deepEqual(h.saved().find(row => row.id === 'composite'), composite)
  assert.equal(c.state.created.variant.source_revision, 5)
  assert.equal(c.state.created.composition.stages[0].source.id, 'critic')
})

test('fork uses the saved revision, retains it across source revisions and records direct lineage when copied again', async () => {
  const h = setup(), c = h.controller
  await c.open(); c.reopen('original'); c.revise(); c.edit('purpose', 'Not saved yet'); c.create()
  c.forkSaved('original'); assert.equal(c.state.draft.purpose, source().purpose); assert.equal(c.state.draft.variant.source_revision, 3)
  c.create(); c.save(); const variant = clone(c.state.created)
  c.reopen('original'); c.revise(); c.edit('purpose', 'New saved source'); c.create(); c.save()
  c.reopen(variant.id); assert.deepEqual(c.state.created, variant)
  assert.equal(c.forkSaved(variant.id), true); assert.equal(c.state.draft.variant.source_id, variant.id)
  assert.equal(c.state.draft.variant.source_revision, 1)
})

test('cross-window changes block saving without discarding the variant; reopening the library preserves source lineage', async () => {
  const h = setup(), c = h.controller; await c.open(); c.forkSaved('original'); c.create()
  const other = setup([], { storage: h.storage }); await other.controller.open(); other.controller.reopen('original')
  other.controller.revise(); other.controller.edit('purpose', 'Changed in other window'); other.controller.create(); other.controller.save()
  assert.equal(c.save(), false); assert.match(c.state.status, /another window/)
  const variant = clone(c.state.created); c.close(); await c.open(); assert.deepEqual(c.state.created, variant)
  assert.equal(c.save(), true); assert.equal(c.state.created.variant.source_revision, 3)
  assert.equal(h.saved().find(row => row.id === 'original').revision, 4)
})

test('failed source lookup, same name and colliding identity never replace an existing creator', async () => {
  const h = setup(), c = h.controller; await c.open(); c.edit('purpose', 'Unfinished work')
  assert.equal(c.forkSaved('missing'), false); assert.equal(c.state.draft.purpose, 'Unfinished work')
  c.forkSaved('original'); c.edit('name', source().name); assert.equal(c.create(), false); assert.match(c.state.status, /different name/)
  const collision = setup(undefined, { id: () => 'original' }); await collision.controller.open(); collision.controller.forkSaved('original')
  assert.equal(collision.controller.create(), false); assert.match(collision.controller.state.status, /distinct identity/)
  assert.deepEqual(collision.saved(), [source()]); assert.equal(collision.controller.save(), false)
})

test('preparing forbids forks; detached search cannot rewrite a copied same-Book draft', async () => {
  let release
  const h = setup(undefined, { fetch: async url => url.startsWith('/api/search?') ? new Promise(resolve => { release = resolve }) : { ok: true, json: async () => catalog } })
  const c = h.controller; await c.open(); c.chooseBook(book.workspace_id)
  const pending = c.search('query'); c.forkSaved('original')
  release({ ok: true, json: async () => ({ contract: 'pages-search.v1', ok: true, workspace_id: book.workspace_id, hits: [{ workspace_id: book.workspace_id, path: 'wiki/late.md' }] }) }); await pending
  assert.equal(c.state.searching, false); assert.deepEqual(c.state.hits, [])
  c.create(); const created = clone(c.state.created); await c.tryExample()
  assert.equal(c.forkSaved('original'), false); assert.deepEqual(c.state.created, created)
  c.receive('specialist-error', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id, message: 'Finish unsaved edits' }))
  assert.equal(c.forkSaved('original'), true)
})

test('invalid persisted lineage is rejected without changing storage; save failures retain an independent draft', async () => {
  for (const patch of [{ source_revision: 0 }, { source_revision: Number.MAX_SAFE_INTEGER + 1 }, { source_id: 'bad' }, { source_id: 'x'.repeat(129) }, { source_name: '' }, { source_name: 'x'.repeat(101) }, { contract: 'unknown' }, { unexpected: true }]) {
    const bad = { ...source('bad'), variant: { contract: 'moondesk.specialist-variant.v1', source_id: 'original', source_revision: 3, source_name: 'Original', ...patch } }
    const h = setup([bad]), before = h.storage.getItem(key); await h.controller.open()
    assert.ok(h.controller.state.storage_error); assert.deepEqual(h.controller.state.records, []); assert.equal(h.storage.getItem(key), before)
  }
  const h = setup(), c = h.controller; await c.open(); c.forkSaved('original'); c.create()
  const original = h.storage.getItem(key); h.storage.setItem = () => { throw Error('Quota exceeded') }
  assert.equal(c.save(), false); assert.match(c.state.status, /Quota exceeded/); assert.equal(h.storage.getItem(key), original)
  assert.equal(c.state.created.variant.source_id, 'original')
})
