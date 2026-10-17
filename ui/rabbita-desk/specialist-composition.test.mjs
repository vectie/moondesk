import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController, specialistBrief, specialistStorageKeyFor } from './specialist-builder.js'
import { compositionContract, compositionSelections, validComposition } from './specialist-composition.js'

const scope = 'composition-library', key = specialistStorageKeyFor(scope)
const book = { workspace_id: 'research', book_id: 'research-book', version: '1.2.0', name: 'Research Book' }
const passport = { ...book, contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: 'ready', capabilities: ['Find evidence', 'Review claims', 'Write'] }
const source = (id, changes = {}) => ({ contract: 'moondesk.specialist-preset.v1', id, revision: 1, name: id,
  purpose: `Perform ${id} work`, example: `Example for ${id}`, book, knowledge_paths: [`wiki/${id}.md`, 'raw/shared.md'], capabilities: ['Find evidence'], ...changes })
const originals = () => [source('Researcher'), source('Critic', { capabilities: ['Review claims'] }), source('Writer', { capabilities: ['Write'] })]
function harness(records = originals(), options = {}) {
  const values = new Map([[key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const storage = options.storage || { getItem: k => values.get(k) ?? null, setItem: (k, value) => values.set(k, value) }
  const calls = [], dispatches = []; let serial = 0, agents = [passport]
  const controller = createSpecialistController({ scope, storage,
    fetch: async url => { calls.push(url); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents }) } },
    id: () => `composition-${++serial}`, dispatch: (...args) => dispatches.push(args), ...options })
  return { controller, storage, calls, dispatches, setAgents(next) { agents = next } }
}
async function compose(h) {
  const c = h.controller; await c.open(); assert.equal(c.newComposition(), true)
  c.edit('name', 'Evidence brief creator'); c.edit('purpose', 'Create a reviewed evidence brief.'); c.edit('example', 'Evaluate the October report.')
  assert.equal(c.addStage('Researcher'), true); assert.equal(c.addStage('Critic'), true)
  c.editHandoff(0, 'Hand off cited findings and unresolved questions.'); c.editHandoff(1, 'Return the reviewed brief with contradictory claims identified.')
}

test('saved specialist revisions compose into a new usable ordered brief, then prepare through the existing chat bridge', async () => {
  const h = harness(); await compose(h); const c = h.controller
  assert.equal(c.create(), true); const record = c.state.created
  assert.equal(record.revision, 1); assert.equal(record.composition.contract, compositionContract)
  assert.deepEqual(record.knowledge_paths, ['wiki/Researcher.md', 'raw/shared.md', 'wiki/Critic.md'])
  assert.deepEqual(record.capabilities, ['Find evidence', 'Review claims'])
  const brief = specialistBrief(record)
  assert.ok(brief.indexOf('Stage 1: Researcher') < brief.indexOf('Stage 2: Critic'))
  assert.match(brief, /October report/); assert.match(brief, /Source representative example \(context only\)/)
  assert.match(brief, /Hand off cited findings/); assert.match(brief, /do not create separate agents/)
  assert.equal(h.dispatches.length, 0); assert.equal(await c.tryExample(), true)
  assert.equal(h.dispatches[0][0], 'prepare-specialist'); assert.equal(h.dispatches[0][1], book.workspace_id); assert.equal(h.dispatches[0][2], brief)
  const binding = JSON.parse(h.dispatches[0][3]); assert.equal(binding.book_id, book.book_id); assert.equal(binding.version, book.version)
  assert.deepEqual(binding.knowledge_paths, record.knowledge_paths); assert.equal(binding.library_scope, scope)
  c.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
  assert.equal(c.state.open, false); assert.match(c.state.prepared, /No trial result/)
  assert.deepEqual(h.calls, ['/api/desktop/agents', '/api/desktop/agents'])
})

test('stage reorder and removal update the actual brief and exact union without changing source specialists', async () => {
  const h = harness(), saved = h.storage.getItem(key); await compose(h); const c = h.controller
  assert.equal(c.addStage('Writer'), true); c.editHandoff(2, 'Deliver final copy.')
  assert.equal(c.moveStage(2, -1), true); assert.equal(c.moveStage(0, -1), false)
  assert.equal(c.moveStage(0, 5), false); assert.equal(c.removeStage(-1), false)
  assert.equal(c.removeStage(2), true); assert.equal(c.create(), true)
  const brief = specialistBrief(c.state.created)
  assert.match(brief, /Stage 1: Researcher/); assert.match(brief, /Stage 2: Writer/); assert.doesNotMatch(brief, /Stage 3|wiki\/Critic/)
  assert.deepEqual(c.state.created.capabilities, ['Find evidence', 'Write']); assert.equal(h.storage.getItem(key), saved)
})

test('composition save/reload and revision retain pinned source snapshots despite later upstream edits', async () => {
  const h = harness(); await compose(h); const c = h.controller; c.create(); assert.equal(c.save(), true)
  const composedId = c.state.created.id, saved = JSON.parse(h.storage.getItem(key))
  const original = saved.records.find(item => item.id === 'Researcher'); original.revision = 9; original.purpose = 'New upstream purpose'
  h.storage.setItem(key, JSON.stringify(saved))
  const restarted = harness([], { storage: h.storage }); await restarted.controller.open(); restarted.controller.reopen(composedId)
  assert.equal(restarted.controller.state.created.composition.stages[0].source.revision, 1)
  assert.match(specialistBrief(restarted.controller.state.created), /Perform Researcher work/)
  assert.doesNotMatch(specialistBrief(restarted.controller.state.created), /New upstream purpose/)
  restarted.controller.revise(); restarted.controller.moveStage(1, -1); assert.equal(restarted.controller.create(), true)
  assert.equal(restarted.controller.state.created.id, composedId); assert.equal(restarted.controller.state.created.revision, 2)
  assert.equal(restarted.controller.save(), true)
  assert.equal(JSON.parse(h.storage.getItem(key)).records.find(item => item.id === 'Researcher').revision, 9)
})

test('compatible exact Book identity is required; mismatch never drops existing stages', async () => {
  for (const changes of [{ workspace_id: 'other-workspace' }, { book_id: 'other-book' }, { version: '2.0.0' }]) {
    const otherBook = { ...book, ...changes }, h = harness([...originals(), source('Other', { book: otherBook })]); await compose(h)
    h.controller.state.agents = [passport, { ...passport, ...otherBook }]
    const before = JSON.stringify(h.controller.state.draft)
    assert.equal(h.controller.addStage('Other'), false); assert.match(h.controller.state.status, /same exact|changed/)
    assert.equal(JSON.stringify(h.controller.state.draft), before)
  }
})

test('create requires complete output handoffs and 2–4 stages, rejects duplicate and nested sources', async () => {
  const h = harness(); await compose(h); const c = h.controller
  assert.equal(c.addStage('Researcher'), false); assert.match(c.state.status, /already/)
  c.editHandoff(1, ' '); assert.equal(c.create(), false)
  c.editHandoff(1, 'x'.repeat(2001)); assert.equal(c.create(), false)
  c.editHandoff(1, 'Return a reviewed brief.'); assert.equal(c.create(), true); assert.equal(c.save(), true)
  const savedId = c.state.created.id; c.newComposition(); assert.equal(c.addStage(savedId), false); assert.match(c.state.status, /single-stage/)
  assert.equal(c.create(), false); c.addStage('Researcher'); c.editHandoff(0, 'Final'); assert.equal(c.create(), false)
  c.state.records.push(source('Fourth'), source('Fifth')); c.addStage('Critic'); c.addStage('Writer'); c.addStage('Fourth')
  assert.equal(c.addStage('Fifth'), false); assert.equal(c.state.draft.composition.stages.length, 4)
})

test('combined reference overflow is rejected atomically and shared paths count only once', async () => {
  const many = Array.from({ length: 20 }, (_, index) => `wiki/file-${index}.md`)
  const h = harness([source('Researcher', { knowledge_paths: many }), source('Critic', { knowledge_paths: ['wiki/new.md'] }), source('Writer', { knowledge_paths: ['wiki/file-0.md'] })])
  const c = h.controller; await c.open(); c.newComposition(); assert.equal(c.addStage('Researcher'), true)
  assert.equal(c.addStage('Critic'), false); assert.match(c.state.status, /exceed 20/); assert.equal(c.state.draft.composition.stages.length, 1)
  assert.equal(c.addStage('Writer'), true); assert.equal(c.state.draft.knowledge_paths.length, 20)
})

test('composition snapshots cannot silently lose inherited knowledge or switch Book', async () => {
  const h = harness(); await compose(h); const c = h.controller, before = JSON.stringify(c.state.draft)
  c.chooseBook('other'); c.toggleKnowledge('raw/shared.md', false); c.toggleCapability('Find evidence', false)
  assert.equal(await c.search('unrelated'), false); assert.equal(JSON.stringify(c.state.draft), before)
  c.removeStage(1); c.removeStage(0); assert.equal(c.state.draft.book, null); assert.deepEqual(c.state.draft.knowledge_paths, [])
})

test('saved composition tampering fails closed and leaves local bytes unchanged', async () => {
  const h = harness(); await compose(h); h.controller.create(); h.controller.save()
  const base = JSON.parse(h.storage.getItem(key))
  for (const corrupt of [
    item => { item.composition.contract = 'wrong' },
    item => { item.composition.stages[0].source.book.version = 'other' },
    item => { item.composition.stages[0].source.contract = 'wrong' },
    item => { item.composition.stages[0].source.composition = {} },
    item => { item.composition.stages[0].source.id = item.id },
    item => { item.composition.stages[0].source.knowledge_paths = ['../outside'] },
    item => { item.composition.stages[0].handoff = '' },
    item => { item.knowledge_paths = [] },
    item => { item.capabilities = [] },
  ]) {
    const data = structuredClone(base); corrupt(data.records[0]); const raw = JSON.stringify(data); h.storage.setItem(key, raw)
    const restarted = harness([], { storage: h.storage }); await restarted.controller.open()
    assert.match(restarted.controller.state.storage_error, /could not be read/); assert.deepEqual(restarted.controller.state.records, [])
    assert.equal(h.storage.getItem(key), raw)
  }
})

test('a large composed prompt is blocked before create or chat dispatch', async () => {
  const long = 'x'.repeat(8000), h = harness(originals().map(item => ({ ...item, purpose: long, example: long })))
  await compose(h); const c = h.controller; c.addStage('Writer'); c.editHandoff(2, 'Final output')
  assert.equal(c.create(), false); assert.match(c.state.status, /48,000-character/); assert.equal(h.dispatches.length, 0)
})

test('composition remains recoverable across close, repeated preparation and rejected native staging', async () => {
  const h = harness(); await compose(h); const c = h.controller, draft = structuredClone(c.state.draft)
  c.close(); await c.open(); assert.deepEqual(c.state.draft, draft); c.create()
  assert.equal(await c.tryExample(), true); assert.equal(await c.tryExample(), false); assert.equal(c.newComposition(), false)
  assert.equal(c.newDraft(), false); assert.equal(h.dispatches.length, 1)
  const requestId = JSON.parse(h.dispatches[0][3]).request_id
  c.receive('specialist-error', JSON.stringify({ request_id: requestId, message: 'Finish your current Code draft.' }))
  assert.equal(c.state.open, true); assert.match(c.state.status, /Code draft/); assert.equal(c.state.created.composition.stages.length, 2)
})

test('fresh Book catalog rejects stale composite use and preserves the local definition', async () => {
  for (const next of [[], [{ ...passport, version: '2' }], [{ ...passport, status: 'needs_attention' }], [{ ...passport, capabilities: ['Find evidence'] }]]) {
    const h = harness(); await compose(h); h.controller.create(); const definition = structuredClone(h.controller.state.created); h.setAgents(next)
    assert.equal(await h.controller.tryExample(), false); assert.equal(h.dispatches.length, 0); assert.deepEqual(h.controller.state.created, definition)
  }
})

test('conflicting and failed composition saves never overwrite saved source revisions or report success', async () => {
  const h = harness(); await compose(h); const c = h.controller; c.create()
  const changed = JSON.parse(h.storage.getItem(key)); changed.records[0].revision = 2; const raw = JSON.stringify(changed); h.storage.setItem(key, raw)
  assert.equal(c.save(), false); assert.match(c.state.status, /another window/); assert.equal(h.storage.getItem(key), raw)
  c.close(); await c.open(); const before = h.storage.getItem(key); h.storage.setItem = () => { throw new Error('quota exceeded') }
  assert.equal(c.save(), false); assert.match(c.state.status, /quota/); assert.equal(h.storage.getItem(key), before); assert.ok(c.state.created.composition)
})

test('validated composition helper rejects self inclusion and derives order-sensitive stable unions', () => {
  const composition = { contract: compositionContract, stages: originals().slice(0, 2).map(item => ({ source: item, handoff: 'Cited handoff' })) }
  const record = { id: 'combined', book, ...compositionSelections(composition) }
  assert.equal(validComposition(composition, record), true)
  assert.equal(validComposition(composition, { ...record, id: 'Researcher' }), false)
  composition.stages.reverse(); assert.equal(validComposition(composition, record), false)
})

test('composed creator fills a new task while preserving every captured stage and its handoff', async () => {
  const h = harness(); await compose(h); const c = h.controller
  c.editTaskTemplate('Evaluate {{period}} for {{audience}}'); assert.equal(c.create(), true)
  const snapshot = JSON.stringify(c.state.created)
  c.editTaskInput('period', 'November'); c.editTaskInput('audience', 'operators'); assert.equal(c.previewTask(), true)
  assert.equal(await c.prepareTask(), true)
  const prompt = h.dispatches[0][2]
  assert.match(prompt, /Evaluate November for operators/); assert.match(prompt, /Stage 1: Researcher/)
  assert.match(prompt, /Stage 2: Critic/); assert.match(prompt, /Hand off cited findings/)
  assert.equal(JSON.stringify(c.state.created), snapshot)
})
