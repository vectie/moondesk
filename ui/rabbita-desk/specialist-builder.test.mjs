import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController, specialistBrief, specialistStorageKeyFor } from './specialist-builder.js'

const specialistStorageKey = specialistStorageKeyFor('fixture-library')

// Fixture adapters exercise production controller code. No model/provider result
// or native host execution is simulated as a qualified result.
export const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook',
  workspace_id: 'book-research', book_id: 'research-briefs', name: 'Research Book',
  version: '1.0.0', status: 'ready', capabilities: ['Evidence-backed answers', 'Reviewed procedures'] }
export const catalog = agents => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents })
export const storageFixture = () => { const values = new Map(); return { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) } }
export const searchResult = (workspace = agent.workspace_id, paths = ['wiki/method.md', 'raw/report.md']) => ({
  contract: 'pages-search.v1', ok: true, workspace_id: workspace,
  hits: paths.map(path => ({ workspace_id: workspace, path, title: path })),
})
export function harness(overrides = {}) {
  const storage = overrides.storage || storageFixture(), calls = [], dispatches = []
  let serial = 0, agents = [agent]
  const request = async url => { calls.push(url); return { ok: true, json: async () => url.startsWith('/api/search?') ? searchResult() : catalog(agents) } }
  const controller = createSpecialistController({ scope: 'fixture-library', storage, fetch: request,
    id: () => 'fixture-' + ++serial, dispatch: (...args) => dispatches.push(args), ...overrides })
  return { controller, storage, calls, dispatches, setAgents(value) { agents = value } }
}
export async function createExample(controller) {
  await controller.open(); controller.edit('name', 'Evidence brief specialist')
  controller.edit('purpose', 'Compare claims against source evidence.'); controller.edit('example', 'Summarize the Q3 report with uncertainties.')
  controller.chooseBook(agent.workspace_id); controller.toggleCapability('Evidence-backed answers', true)
  await controller.search('report'); controller.toggleKnowledge('raw/report.md', true)
  assert.equal(controller.create(), true)
}

test('purpose → exact Book knowledge → create → prepare → revise → save → reopen keeps a usable brief', async () => {
  const h = harness(); await createExample(h.controller)
  const first = h.controller.state.created
  assert.equal(first.revision, 1); assert.deepEqual(first.knowledge_paths, ['raw/report.md'])
  assert.match(specialistBrief(first), /@raw\/report.md/)
  assert.equal(await h.controller.tryExample(), true)
  assert.equal(h.dispatches.length, 1)
  const [action, workspace, prompt, encoded] = h.dispatches[0]
  assert.equal(action, 'prepare-specialist'); assert.equal(workspace, agent.workspace_id)
  assert.equal(prompt, specialistBrief(first)); const binding = JSON.parse(encoded)
  assert.deepEqual(binding.knowledge_paths, ['raw/report.md']); assert.equal(binding.book_id, agent.book_id)
  assert.equal(h.controller.state.preparing, true)
  h.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
  assert.equal(h.controller.state.open, false); assert.match(h.controller.state.prepared, /No trial result/)
  await h.controller.open(); h.controller.revise(); h.controller.edit('purpose', 'Flag contradictory claims and preserve citations.')
  assert.equal(h.controller.create(), true); assert.equal(h.controller.state.created.revision, 2)
  assert.equal(h.controller.state.prepared, ''); assert.equal(h.controller.save(), true)
  const fresh = harness({ storage: h.storage }); await fresh.controller.open()
  assert.equal(fresh.controller.state.records.length, 1); fresh.controller.reopen(first.id)
  assert.equal(fresh.controller.state.created.revision, 2)
  assert.match(specialistBrief(fresh.controller.state.created), /Flag contradictory/)
  assert.equal(await fresh.controller.tryExample(), true)
  assert.equal(fresh.dispatches[0][1], agent.workspace_id)
  assert.match(fresh.dispatches[0][2], /revision 2/)
})

test('search uses existing scoped contract and rejects cross-Book, unsafe and unrequested references', async () => {
  let result = searchResult(agent.workspace_id, ['wiki/method.md', '../outside.md', 'raw/../secret', 'tools/shell.json', 'wiki/a\\b', 'wiki/a\nline', 'wiki/method.md'])
  const h = harness({ fetch: async url => ({ ok: true, json: async () => url.startsWith('/api/search?') ? result : catalog([agent]) }) })
  await h.controller.open(); h.controller.chooseBook(agent.workspace_id); await h.controller.search('method')
  assert.deepEqual(h.controller.state.hits.map(item => item.path), ['wiki/method.md'])
  h.controller.toggleKnowledge('wiki/not-returned.md', true); assert.deepEqual(h.controller.state.draft.knowledge_paths, [])
  h.controller.toggleKnowledge('wiki/method.md', true)
  result = searchResult('other-book'); await h.controller.search('anything')
  assert.deepEqual(h.controller.state.hits, []); assert.match(h.controller.state.status, /mismatched/)
  assert.deepEqual(h.controller.state.draft.knowledge_paths, ['wiki/method.md'])
})

test('changing Book clears references and preferences; late search cannot mix Book identities', async () => {
  let resolveSearch
  const second = { ...agent, workspace_id: 'book-two', book_id: 'second' }
  const h = harness({ fetch: async url => url.startsWith('/api/search?') ? new Promise(resolve => { resolveSearch = resolve }) : { ok: true, json: async () => catalog([agent, second]) } })
  await h.controller.open(); h.controller.chooseBook(agent.workspace_id); h.controller.toggleCapability(agent.capabilities[0], true)
  const pending = h.controller.search('report'); h.controller.chooseBook(second.workspace_id)
  resolveSearch({ ok: true, json: async () => searchResult() }); await pending
  assert.equal(h.controller.state.draft.book.workspace_id, second.workspace_id)
  assert.deepEqual(h.controller.state.draft.knowledge_paths, []); assert.deepEqual(h.controller.state.draft.capabilities, [])
  assert.deepEqual(h.controller.state.hits, []); assert.equal(h.controller.state.searching, false)
})

test('create validates required work and never starts or grants a runtime', async () => {
  const h = harness(); await h.controller.open(); assert.equal(h.controller.create(), false)
  assert.match(h.controller.state.status, /Enter a name/); assert.equal(h.dispatches.length, 0)
  h.controller.chooseBook(agent.workspace_id); h.controller.toggleCapability('Execute shell', true)
  assert.deepEqual(h.controller.state.draft.capabilities, [])
  await createExample(h.controller); assert.equal(h.dispatches.length, 0)
  assert.match(specialistBrief(h.controller.state.created), /grants no tools/)
})

test('prepare refresh rejects removed, unavailable, changed-version and removed-capability Books', async () => {
  for (const agents of [[], [{ ...agent, status: 'needs_attention' }], [{ ...agent, version: '2.0.0' }], [{ ...agent, book_id: 'replacement' }], [{ ...agent, capabilities: [] }]]) {
    const h = harness(); await createExample(h.controller); h.setAgents(agents)
    assert.equal(await h.controller.tryExample(), false); assert.equal(h.dispatches.length, 0)
    assert.equal(h.controller.state.preparing, false); assert.ok(h.controller.state.created)
    assert.match(h.controller.state.status, /unavailable|changed|no longer/)
  }
})

test('repeated Try stays single-flight and acknowledges only its exact request', async () => {
  const h = harness(); await createExample(h.controller)
  const first = h.controller.tryExample(); assert.equal(await h.controller.tryExample(), false); await first
  assert.equal(h.dispatches.length, 1)
  h.controller.receive('specialist-prepared', '{"request_id":"unrelated"}')
  assert.equal(h.controller.state.preparing, true); assert.equal(h.controller.state.open, true)
  const binding = JSON.parse(h.dispatches[0][3])
  h.controller.receive('specialist-error', JSON.stringify({ request_id: binding.request_id, message: 'Save the current edit first.' }))
  assert.equal(h.controller.state.preparing, false); assert.equal(h.controller.state.open, true)
  assert.match(h.controller.state.status, /Save the current edit/)
  assert.equal(h.controller.state.created.revision, 1)
})

test('closing during catalog verification cancels preparation before dispatch', async () => {
  const h = harness(); await createExample(h.controller)
  let release
  const delayed = createSpecialistController({ scope: 'fixture-library', storage: h.storage, id: () => 'delayed', dispatch: () => assert.fail('cancelled trial dispatched'),
    fetch: async () => new Promise(resolve => { release = resolve }) })
  const open = delayed.open(); delayed.close(); release({ ok: true, json: async () => catalog([agent]) }); await open
  assert.equal(delayed.state.open, false)
  let serial = 0
  const second = harness({ fetch: async url => {
    if (++serial > 2) return new Promise(resolve => { release = resolve })
    return { ok: true, json: async () => url.startsWith('/api/search?') ? searchResult() : catalog([agent]) }
  } })
  await createExample(second.controller); const trying = second.controller.tryExample(); second.controller.close()
  release({ ok: true, json: async () => catalog([agent]) }); await trying
  assert.equal(second.dispatches.length, 0); assert.equal(second.controller.state.preparing, false)
})

test('a failed catalog refresh preserves the creator without a fabricated run', async () => {
  let online = true
  const h = harness({ fetch: async url => { if (!online) throw new Error('Disconnected'); return { ok: true, json: async () => url.startsWith('/api/search?') ? searchResult() : catalog([agent]) } } })
  await createExample(h.controller); online = false; assert.equal(await h.controller.tryExample(), false)
  assert.equal(h.dispatches.length, 0); assert.match(h.controller.state.status, /Disconnected/)
  assert.ok(h.controller.state.created); assert.equal(h.controller.state.prepared, '')
})

test('storage failure and corrupt saved data cannot report success or overwrite prior bytes', async () => {
  const broken = storageFixture(); const old = '{broken-json'; broken.setItem(specialistStorageKey, old)
  const h = harness({ storage: broken }); await createExample(h.controller)
  assert.equal(h.controller.save(), false); assert.equal(broken.getItem(specialistStorageKey), old)
  const denied = harness({ storage: { getItem: () => null, setItem: () => { throw new Error('Quota exceeded') } } })
  await createExample(denied.controller); assert.equal(denied.controller.save(), false)
  assert.match(denied.controller.state.status, /Quota exceeded/); assert.equal(denied.controller.state.records.length, 0)
})

test('other-window save conflicts preserve both the saved record and the unsaved revision', async () => {
  const h = harness(); await createExample(h.controller); h.controller.save()
  const other = harness({ storage: h.storage }); await other.controller.open(); other.controller.reopen(h.controller.state.created.id)
  other.controller.revise(); other.controller.edit('purpose', 'Other window revision'); other.controller.create(); assert.equal(other.controller.save(), true)
  h.controller.revise(); h.controller.edit('purpose', 'Unsaved current-window revision'); h.controller.create()
  assert.equal(h.controller.save(), false); assert.match(h.controller.state.status, /another window/)
  h.controller.close(); await h.controller.open()
  assert.equal(h.controller.save(), false); assert.match(h.controller.state.status, /newer revision/)
  assert.equal(h.controller.state.created.purpose, 'Unsaved current-window revision')
  assert.equal(JSON.parse(h.storage.getItem(specialistStorageKey)).records[0].purpose, 'Other window revision')
})

test('close and reopen retain unsaved fields; explicit save survives a new controller', async () => {
  const h = harness(); await h.controller.open(); h.controller.edit('purpose', 'Unfinished specialist'); h.controller.close()
  await h.controller.open(); assert.equal(h.controller.state.draft.purpose, 'Unfinished specialist')
  assert.equal(h.storage.getItem(specialistStorageKey), null)
})

test('catalog contract errors are actionable and cannot turn into a ready empty library', async () => {
  const h = harness({ fetch: async () => ({ ok: true, json: async () => ({ agents: [agent] }) }) })
  await h.controller.open(); assert.match(h.controller.state.status, /could not be verified/)
  assert.deepEqual(h.controller.state.agents, [])
})


test('saved specialists are scoped to the exact Desk library even when Book IDs repeat', async () => {
  const h = harness(); await createExample(h.controller); assert.equal(h.controller.save(), true)
  const other = harness({ storage: h.storage, scope: 'another-library' }); await other.controller.open()
  assert.deepEqual(other.controller.state.records, [])
  await createExample(other.controller); other.controller.edit('purpose', 'This must not touch the original library')
  assert.equal(other.controller.save(), true)
  assert.ok(h.storage.getItem(specialistStorageKeyFor('another-library')))
  assert.equal(JSON.parse(h.storage.getItem(specialistStorageKey)).records[0].purpose, 'Compare claims against source evidence.')
})

test('missing library scope blocks creation instead of inventing a storage or Book identity', async () => {
  const h = harness({ scope: undefined }); await h.controller.open()
  h.controller.edit('name', 'Specialist'); h.controller.edit('purpose', 'Read sources'); h.controller.edit('example', 'Summarize')
  h.controller.chooseBook(agent.workspace_id)
  assert.equal(h.controller.create(), false); assert.match(h.controller.state.status, /library scope/)
  assert.equal(h.dispatches.length, 0)
})

test('missing live dispatch reports a recoverable blocker instead of hanging or claiming a trial', async () => {
  const h = harness({ dispatch: undefined }); await createExample(h.controller)
  assert.equal(await h.controller.tryExample(), false)
  assert.equal(h.controller.state.preparing, false); assert.match(h.controller.state.status, /chat bridge is unavailable/)
})
