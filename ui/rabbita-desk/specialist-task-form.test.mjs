import test from 'node:test'
import assert from 'node:assert/strict'
import { taskInputKeys, validTaskForm, fillTaskForm } from './specialist-task-form.js'
import { createSpecialistController, specialistStorageKeyFor } from './specialist-builder.js'
const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook',
  workspace_id: 'book-research', book_id: 'research-briefs', name: 'Research Book',
  version: '1.0.0', status: 'ready', capabilities: ['Evidence-backed answers', 'Reviewed procedures'] }
const catalog = agents => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents })
const storageFixture = () => { const values = new Map(); return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) } }
const searchResult = (workspace = agent.workspace_id, paths = ['wiki/method.md', 'raw/report.md']) => ({
  contract: 'pages-search.v1', ok: true, workspace_id: workspace,
  hits: paths.map(path => ({ workspace_id: workspace, path, title: path })),
})
function harness(overrides = {}) {
  const storage = overrides.storage || storageFixture(), calls = [], dispatches = []
  let serial = 0, agents = [agent]
  const request = async url => { calls.push(url); return { ok: true, json: async () => url.startsWith('/api/search?') ? searchResult() : catalog(agents) } }
  const controller = createSpecialistController({ scope: 'fixture-library', storage, fetch: request,
    id: () => 'fixture-' + ++serial, dispatch: (...args) => dispatches.push(args), ...overrides })
  return { controller, storage, calls, dispatches, setAgents(value) { agents = value } }
}
async function createExample(controller) {
  await controller.open(); controller.edit('name', 'Evidence brief specialist')
  controller.edit('purpose', 'Compare claims against source evidence.'); controller.edit('example', 'Summarize the Q3 report with uncertainties.')
  controller.chooseBook(agent.workspace_id); controller.toggleCapability('Evidence-backed answers', true)
  await controller.search('report'); controller.toggleKnowledge('raw/report.md', true)
  assert.equal(controller.create(), true)
}


const form = template => ({ contract: 'moondesk.specialist-task-form.v1', template })
async function creator(h) {
  await createExample(h.controller); h.controller.revise()
  h.controller.editTaskTemplate('Compare {{topic}} for {{audience}}. Check {{topic}} sources.')
  assert.equal(h.controller.create(), true); assert.equal(h.controller.save(), true)
}
function fill(c, topic = 'October retention', audience = 'Founders') {
  c.editTaskInput('topic', topic); c.editTaskInput('audience', audience)
}
test('template grammar requires bounded explicit inputs and treats values literally', () => {
  assert.deepEqual(taskInputKeys('{{topic}} and {{topic}} for {{audience}}'), ['topic', 'audience'])
  for (const invalid of ['', 'No inputs', '{{Mixed}}', '{{bad-name}}', '{{broken', '{{constructor}}', Array.from({ length: 9 }, (_, i) => `{{a${i}}}`).join(' ')]) assert.throws(() => taskInputKeys(invalid))
  assert.equal(validTaskForm({ template: '{{a}}' }), false)
  assert.equal(fillTaskForm(form('{{topic}} twice {{topic}}'), { topic: '$& {{other}} <script>' }), '$& {{other}} <script> twice $& {{other}} <script>')
  assert.throws(() => fillTaskForm(form('{{topic}}'), Object.create({ topic: 'inherited' })))
  for (const value of ['', ' ', '\0', 'x'.repeat(4001)]) assert.throws(() => fillTaskForm(form('{{topic}}'), { topic: value }))
  assert.throws(() => fillTaskForm(form('{{a}}{{a}}{{a}}'), { a: 'x'.repeat(3000) }), /8,000/)
})
test('saved creator reloads its form and stages distinct jobs without changing saved bytes or revision', async () => {
  const h = harness(); await creator(h)
  const saved = h.storage.getItem(specialistStorageKeyFor('fixture-library')), record = h.controller.state.created
  const next = harness({ storage: h.storage }); await next.controller.open(); next.controller.reopen(record.id)
  assert.deepEqual(next.controller.state.created.task_form, record.task_form)
  for (const topic of ['October retention', 'November revenue']) {
    fill(next.controller, topic); assert.equal(next.controller.previewTask(), true)
    const preview = next.controller.state.taskPreview
    assert.equal(await next.controller.prepareTask(), true)
    const call = next.dispatches.at(-1); assert.equal(call[2], preview)
    assert.ok(call[2].includes(`Compare ${topic} for Founders`))
    assert.equal(call[0], 'prepare-specialist'); assert.equal(call[1], agent.workspace_id)
    const binding = JSON.parse(call[3]); assert.deepEqual(binding.knowledge_paths, ['raw/report.md'])
    next.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id })); await next.controller.open()
  }
  assert.equal(next.controller.state.created.revision, record.revision)
  assert.equal(h.storage.getItem(specialistStorageKeyFor('fixture-library')), saved)
})
test('missing input and stale preview never dispatch; failed preparation preserves inputs and retry', async () => {
  const h = harness(); await creator(h)
  assert.equal(h.controller.previewTask(), false); assert.equal(await h.controller.prepareTask(), false)
  fill(h.controller); h.controller.previewTask(); h.controller.editTaskInput('topic', 'Changed')
  assert.equal(h.controller.state.taskPreview, ''); assert.equal(await h.controller.prepareTask(), false); assert.equal(h.dispatches.length, 0)
  h.controller.previewTask(); assert.equal(await h.controller.prepareTask(), true)
  h.controller.receive('specialist-error', JSON.stringify({ request_id: JSON.parse(h.dispatches[0][3]).request_id, message: 'Finish unsaved edits' }))
  assert.equal(h.controller.state.taskValues.topic, 'Changed'); assert.match(h.controller.state.status, /unsaved/)
  assert.equal(await h.controller.prepareTask(), true)
})
test('Book drift blocks a filled task, close cancels pending catalog and duplicate preparation is single-flight', async () => {
  const h = harness(); await creator(h); fill(h.controller); h.controller.previewTask()
  h.setAgents([{ ...agent, version: '2' }]); assert.equal(await h.controller.prepareTask(), false); assert.equal(h.dispatches.length, 0)
  let resolve
  const c = harness({ storage: h.storage, fetch: async () => ({ ok: true, json: async () => catalog([agent]) }) })
  await c.controller.open(); c.controller.reopen(h.controller.state.created.id); fill(c.controller); c.controller.previewTask()
  // Reuse production catalog callback with deferred response for the actual preparation.
  const d = harness({ storage: h.storage, fetch: () => new Promise(r => { resolve = r }) })
  const opening = d.controller.open(); resolve({ ok: true, json: async () => catalog([agent]) }); await opening
  d.controller.reopen(h.controller.state.created.id); fill(d.controller); d.controller.previewTask()
  const first = d.controller.prepareTask(); assert.equal(await d.controller.prepareTask(), false)
  assert.equal(d.controller.editTaskInput('topic', 'racing edit'), false)
  d.controller.close(); resolve({ ok: true, json: async () => catalog([agent]) }); assert.equal(await first, false)
  assert.equal(d.dispatches.length, 0); assert.equal(d.controller.state.taskValues.topic, 'October retention')
})
test('switching creators/revision clears invocation data; malformed persisted form fails closed', async () => {
  const h = harness(); await creator(h); fill(h.controller); h.controller.previewTask()
  h.controller.reopen(h.controller.state.created.id); assert.deepEqual(h.controller.state.taskValues, {}); assert.equal(h.controller.state.taskPreview, '')
  fill(h.controller); h.controller.revise(); assert.deepEqual(h.controller.state.taskValues, {})
  h.controller.editTaskTemplate('{{bad-key}}'); assert.equal(h.controller.create(), false)
  h.controller.editTaskTemplate(''); assert.equal(h.controller.create(), true); assert.equal(h.controller.state.created.task_form, undefined)
  const key = specialistStorageKeyFor('fixture-library'), data = JSON.parse(h.storage.getItem(key)); data.records[0].task_form.template = '{{bad-key}}'
  const raw = JSON.stringify(data); h.storage.setItem(key, raw)
  const next = harness({ storage: h.storage }); await next.controller.open()
  assert.match(next.controller.state.storage_error, /could not be read/); assert.equal(h.storage.getItem(key), raw)
})
