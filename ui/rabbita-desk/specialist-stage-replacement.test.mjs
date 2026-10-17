import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController, specialistBrief, specialistStorageKeyFor } from './specialist-builder.js'
import { compositionContract, compositionSelections } from './specialist-composition.js'

const scope = 'stage-replacement-library', key = specialistStorageKeyFor(scope)
const book = { workspace_id: 'research', book_id: 'research-book', version: '1', name: 'Research Book' }
const passport = { ...book, contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: 'ready', capabilities: ['Find', 'Review', 'Write'] }
const source = (id, changes = {}) => ({ contract: 'moondesk.specialist-preset.v1', id, revision: 1, name: id,
  purpose: `Perform ${id} work`, example: `Example for ${id}`, book, knowledge_paths: [`wiki/${id}.md`, 'raw/shared.md'], capabilities: ['Find'], ...changes })
const old = () => source('Researcher')
const updated = () => source('Researcher', { name: 'Evidence analyst', revision: 2, purpose: 'Distinguish conflicting evidence.', example: 'Compare the new report.',
  capabilities: ['Review'], knowledge_paths: ['wiki/method-v2.md', 'raw/shared.md'], task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Compare {{report}}' } })
const critic = () => source('Critic', { capabilities: ['Review'] })
const writer = () => source('Writer', { capabilities: ['Write'] })
const composition = () => {
  const stages = { contract: compositionContract, stages: [
    { source: old(), handoff: 'Give cited findings to the critic.' },
    { source: critic(), handoff: 'Deliver the final checked report.' },
  ] }
  return source('Composed', { name: 'Report creator', composition: stages, ...compositionSelections(stages) })
}
function harness(records = [composition(), updated(), critic(), writer()], options = {}) {
  const values = new Map([[key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })]])
  const storage = options.storage || { getItem: k => values.get(k) ?? null, setItem: (k, value) => values.set(k, value) }
  const dispatches = []; let serial = 0
  const controller = createSpecialistController({ scope, storage, id: () => `local-${++serial}`, dispatch: (...args) => dispatches.push(args),
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [structuredClone(passport)] }) }), ...options })
  return { controller, storage, dispatches }
}
async function edit(h) { await h.controller.open(); h.controller.reopen('Composed'); h.controller.revise(); return h.controller }
const bytes = content => new TextEncoder().encode(content).buffer
const file = content => ({ name: 'task-only.txt', size: bytes(content).byteLength, arrayBuffer: async () => bytes(content) })

test('refresh a renamed/revised source in place, then save/reload and prepare the exact revised output brief', async () => {
  const h = harness(), c = await edit(h), before = h.storage.getItem(key), originalDraft = structuredClone(c.state.draft)
  assert.equal(c.previewStageReplacement(0, 'Researcher'), true)
  assert.deepEqual(c.state.draft, originalDraft); assert.equal(h.storage.getItem(key), before)
  assert.equal(c.state.stageReplacement.candidate.composition.stages[0].source.name, 'Evidence analyst')
  assert.equal(c.applyStageReplacement(), true)
  assert.deepEqual(c.state.draft.composition.stages.map(stage => stage.handoff), originalDraft.composition.stages.map(stage => stage.handoff))
  assert.deepEqual(c.state.draft.composition.stages.map(stage => stage.source.id), ['Researcher', 'Critic'])
  assert.deepEqual(c.state.draft.knowledge_paths, ['wiki/method-v2.md', 'raw/shared.md', 'wiki/Critic.md'])
  assert.deepEqual(c.state.draft.capabilities, ['Review'])
  assert.deepEqual(c.state.draft.composition.stages[0].source.task_form, updated().task_form)
  assert.deepEqual(c.state.created, composition()); assert.equal(h.storage.getItem(key), before); assert.equal(h.dispatches.length, 0)
  assert.equal(c.create(), true); assert.equal(c.state.created.id, 'Composed'); assert.equal(c.state.created.revision, 2)
  assert.equal(c.save(), true)
  const records = JSON.parse(h.storage.getItem(key)).records
  assert.deepEqual(records.find(record => record.id === 'Researcher'), updated())
  assert.deepEqual(records.find(record => record.id === 'Critic'), critic())
  const restarted = harness([], { storage: h.storage }); await restarted.controller.open(); restarted.controller.reopen('Composed')
  assert.equal(await restarted.controller.tryExample(), true)
  const prompt = restarted.dispatches[0][2], binding = JSON.parse(restarted.dispatches[0][3])
  assert.equal(prompt, specialistBrief(c.state.created)); assert.match(prompt, /Stage 1: Evidence analyst/)
  assert.match(prompt, /Researcher · revision 2/); assert.match(prompt, /Give cited findings to the critic/)
  assert.doesNotMatch(prompt, /Perform Researcher work|@wiki\/Researcher.md/)
  assert.deepEqual(binding.knowledge_paths, c.state.created.knowledge_paths)
})

test('replace a deleted source with a different creator without losing its handoff or position', async () => {
  const h = harness([composition(), critic(), writer()]), c = await edit(h), original = structuredClone(c.state.draft)
  assert.equal(c.previewStageReplacement(0, 'Researcher'), false); assert.match(c.state.status, /saved single-stage/)
  assert.deepEqual(c.state.draft, original)
  assert.equal(c.previewStageReplacement(0, 'Writer'), true); assert.equal(c.applyStageReplacement(), true)
  assert.deepEqual(c.state.draft.composition.stages.map(stage => stage.source.id), ['Writer', 'Critic'])
  assert.equal(c.state.draft.composition.stages[0].handoff, original.composition.stages[0].handoff)
  assert.equal(c.create(), true); assert.match(specialistBrief(c.state.created), /Stage 1: Writer/)
})

test('cancel, repeated compare/apply, and close keep mutation explicitly bounded to the pending draft', async () => {
  const h = harness(), c = await edit(h), before = structuredClone(c.state.draft)
  c.previewStageReplacement(0, 'Researcher'); assert.equal(c.cancelStageReplacement(), true)
  assert.equal(c.applyStageReplacement(), false); assert.deepEqual(c.state.draft, before)
  c.previewStageReplacement(0, 'Researcher'); c.previewStageReplacement(0, 'Writer')
  assert.equal(c.applyStageReplacement(), true); assert.equal(c.applyStageReplacement(), false)
  assert.equal(c.state.draft.composition.stages[0].source.id, 'Writer')
  assert.equal(c.previewStageReplacement(0, 'Writer'), false); assert.match(c.state.status, /already uses/)
  c.previewStageReplacement(0, 'Researcher'); const edited = structuredClone(c.state.draft); c.close(); await c.open()
  assert.equal(c.state.stageReplacement, null); assert.equal(c.applyStageReplacement(), false); assert.deepEqual(c.state.draft, edited)
  assert.equal(JSON.parse(h.storage.getItem(key)).records[0].revision, 1)
})

test('renaming, changing a handoff or form after comparison rejects stale apply and retains edits', async () => {
  for (const mutate of [c => c.edit('name', 'Another creator name'), c => c.editHandoff(0, 'New required output'), c => c.editTaskTemplate('Create {{report}}')]) {
    const c = await edit(harness()); c.previewStageReplacement(0, 'Researcher'); mutate(c)
    const edited = structuredClone(c.state.draft)
    assert.equal(c.applyStageReplacement(), false); assert.match(c.state.status, /draft changed/); assert.deepEqual(c.state.draft, edited)
    assert.equal(c.state.stageReplacement, null); assert.equal(c.previewStageReplacement(0, 'Researcher'), true); assert.equal(c.applyStageReplacement(), true)
    assert.equal(c.state.draft.name, edited.name); assert.equal(c.state.draft.composition.stages[0].handoff, edited.composition.stages[0].handoff)
  }
})

test('reordering, removing, adding stages and creator navigation invalidate pending comparisons', async () => {
  for (const mutate of [c => c.moveStage(0, 1), c => c.removeStage(0), c => c.addStage('Writer'), c => c.newDraft(), c => c.reopen('Researcher'), c => c.forkSaved('Researcher')]) {
    const c = await edit(harness()); c.previewStageReplacement(0, 'Researcher'); mutate(c)
    const edited = structuredClone(c.state.draft)
    assert.equal(c.state.stageReplacement, null); assert.equal(c.applyStageReplacement(), false); assert.deepEqual(c.state.draft, edited)
  }
})

test('new or deleted saved source in another window blocks preview/apply without losing local work', async () => {
  for (const change of [records => { records.find(item => item.id === 'Researcher').revision = 3 }, records => records.splice(records.findIndex(item => item.id === 'Researcher'), 1)]) {
    const h = harness(), c = await edit(h), before = structuredClone(c.state.draft)
    c.previewStageReplacement(0, 'Researcher')
    const store = JSON.parse(h.storage.getItem(key)); change(store.records); const raw = JSON.stringify(store); h.storage.setItem(key, raw)
    assert.equal(c.applyStageReplacement(), false); assert.match(c.state.status, /Saved specialists changed/)
    assert.deepEqual(c.state.draft, before); assert.equal(h.storage.getItem(key), raw)
    assert.equal(c.previewStageReplacement(0, 'Researcher'), false)
    c.close(); await c.open(); assert.deepEqual(c.state.draft, before)
    const exists = store.records.some(item => item.id === 'Researcher')
    assert.equal(c.previewStageReplacement(0, 'Researcher'), exists)
    if (exists) assert.equal(c.state.stageReplacement.candidate.composition.stages[0].source.revision, 3)
  }
})

test('invalid source identity, incompatible Book, duplicate or nested creator never mutate composition', async () => {
  const h = harness(), c = await edit(h), before = structuredClone(c.state.draft)
  for (const [index, sourceId] of [[-1, 'Writer'], [1.5, 'Writer'], [5, 'Writer'], [0, 'missing'], [0, 'Critic'], [0, 'Composed']]) {
    assert.equal(c.previewStageReplacement(index, sourceId), false); assert.deepEqual(c.state.draft, before)
  }
  for (const changes of [{ workspace_id: 'other' }, { book_id: 'other' }, { version: '2' }]) {
    const other = source('Other', { book: { ...book, ...changes } }), separate = harness([composition(), other, critic()]), editor = await edit(separate)
    assert.equal(editor.previewStageReplacement(0, 'Other'), false); assert.match(editor.state.status, /same exact/)
    assert.equal(editor.state.draft.composition.stages[0].source.revision, 1)
  }
})

test('unavailable Book and removed capability reject the replacement before draft mutation', async () => {
  for (const agents of [[], [{ ...passport, status: 'unavailable' }], [{ ...passport, version: '2' }], [{ ...passport, capabilities: ['Find'] }]]) {
    const c = await edit(harness()), before = structuredClone(c.state.draft); c.state.agents = agents
    assert.equal(c.previewStageReplacement(0, 'Researcher'), false); assert.deepEqual(c.state.draft, before)
  }
})

test('combined reference/capability bounds apply to replacement atomically', async () => {
  for (const changes of [{ knowledge_paths: Array.from({ length: 20 }, (_, i) => `wiki/new-${i}.md`) }, { capabilities: Array.from({ length: 16 }, (_, i) => `cap-${i}`) }]) {
    const replacement = source('Large', changes), c = await edit(harness([composition(), replacement, critic()]))
    c.state.agents[0].capabilities = [...passport.capabilities, ...replacement.capabilities]
    const before = structuredClone(c.state.draft)
    assert.equal(c.previewStageReplacement(0, 'Large'), false); assert.match(c.state.status, /exceed 20 knowledge files or 16 capabilities/)
    assert.deepEqual(c.state.draft, before)
  }
})

test('replacement participates in the existing complete-brief bound and failed save recovery', async () => {
  const long = 'x'.repeat(8000), large = source('Large', { purpose: long, example: long })
  const h = harness([composition(), large, critic(), writer()]), c = await edit(h)
  c.edit('purpose', long); c.edit('example', long); c.addStage('Writer'); c.editHandoff(2, 'Final')
  c.state.draft.composition.stages[1].source.purpose = long; c.state.draft.composition.stages[1].source.example = long
  assert.equal(c.previewStageReplacement(0, 'Large'), true); assert.equal(c.applyStageReplacement(), true)
  const before = h.storage.getItem(key); assert.equal(c.create(), false); assert.match(c.state.status, /48,000-character/)
  assert.equal(h.storage.getItem(key), before); assert.equal(h.dispatches.length, 0)
  const normal = harness(), editor = await edit(normal); editor.previewStageReplacement(0, 'Researcher'); editor.applyStageReplacement(); editor.create()
  normal.storage.setItem = () => { throw new Error('quota exceeded') }
  assert.equal(editor.save(), false); assert.match(editor.state.status, /quota exceeded/)
  assert.equal(editor.state.created.composition.stages[0].source.revision, 2)
})

test('R626 task files cannot leak into stage snapshots, revised/exported creators or late replacement callbacks', async () => {
  const h = harness(), c = h.controller; await c.open(); c.reopen('Composed')
  assert.equal(await c.addTaskFile(file('old task private input')), true)
  let finish
  const pending = c.addTaskFile({ name: 'late.txt', size: 4, arrayBuffer: () => new Promise(resolve => { finish = resolve }) })
  c.revise(); assert.deepEqual(c.state.taskFiles, []); c.previewStageReplacement(0, 'Researcher'); c.applyStageReplacement(); c.create()
  finish(bytes('late')); assert.equal(await pending, false); assert.deepEqual(c.state.taskFiles, [])
  assert.equal(await c.addTaskFile(file('new task-only input')), true); assert.equal(c.save(), true)
  assert.doesNotMatch(JSON.stringify(c.exportSaved('Composed')), /old task private input|new task-only input|late.txt/)
  assert.equal(await c.tryExample(), true)
  assert.match(h.dispatches[0][2], /new task-only input/); assert.match(h.dispatches[0][2], /Stage 1: Evidence analyst/)
  assert.doesNotMatch(h.dispatches[0][2], /old task private input|late.txt/)
  assert.equal(c.previewStageReplacement(0, 'Writer'), false); assert.equal(c.applyStageReplacement(), false)
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id }))
  assert.deepEqual(c.state.taskFiles, []); assert.doesNotMatch(JSON.stringify(c.state.created), /task-only input|private input|late.txt/)
})
