import test from 'node:test'
import assert from 'node:assert/strict'
import { createSpecialistController } from './specialist-builder.js'
import { compositionContract, compositionSelections } from './specialist-composition.js'

const book = { workspace_id: 'research', book_id: 'research', version: '1', name: 'Research' }
const source = name => ({ contract: 'moondesk.specialist-preset.v1', id: name, revision: 2, name,
  purpose: `Do ${name}`, example: `Example ${name}`, book, capabilities: [], knowledge_paths: [`wiki/${name}.md`] })
const composition = { contract: compositionContract, stages: [
  { source: source('Researcher'), handoff: 'Cited findings for the writer' },
  { source: source('Writer'), handoff: 'A final concise brief' },
] }
const creator = { ...source('Composed'), composition, ...compositionSelections(composition) }
async function fixture() {
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [creator] }), sent = []
  let ready = true, serial = 0
  const c = createSpecialistController({ scope: 'journey', storage: { getItem: () => raw }, id: () => `request-${++serial}`,
    dispatch: (...args) => sent.push(args), fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true,
      agents: [{ ...book, contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', status: ready ? 'ready' : 'unavailable', capabilities: [] }] }) }) })
  await c.open(); c.reopen('Composed')
  return { c, sent, unavailable: () => { ready = false } }
}

test('two-stage task prepares exact snapshots and carries observed output through ordinary chat preparation', async () => {
  const { c, sent } = await fixture()
  c.editStageTask('Compare project Alpha for our readers')
  assert.equal(c.startStageJourney(), true)
  assert.equal(c.selectJourneyStage(1), false)
  assert.equal(c.previewJourneyStage(), true)
  assert.equal(await c.prepareJourneyStage(), true)
  assert.match(sent[0][2], /Compare project Alpha for our readers/)
  assert.match(sent[0][2], /Specialist: Researcher \(revision 2\)/)
  assert.doesNotMatch(sent[0][2], /Specialist: Composed|Ordered specialist stages/)
  assert.deepEqual(JSON.parse(sent[0][3]).knowledge_paths, ['wiki/Researcher.md'])
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(sent[0][3]).request_id }))
  assert.equal(c.state.open, false); assert.deepEqual(c.state.stageJourney.outputs, [])
  await c.open()
  assert.equal(c.recordStageOutput('Alpha has two cited strengths [source A].'), true)
  assert.equal(c.selectJourneyStage(1), true); assert.equal(c.previewJourneyStage(), true)
  assert.match(c.state.stageJourney.preview, /Alpha has two cited strengths \[source A\]/)
  assert.match(c.state.stageJourney.preview, /Original composed task:\nCompare project Alpha/)
  assert.equal(await c.prepareJourneyStage(), true)
  assert.deepEqual(JSON.parse(sent[1][3]).knowledge_paths, ['wiki/Writer.md'])
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(sent[1][3]).request_id }))
  await c.open(); c.recordStageOutput('Final Alpha brief')
  assert.deepEqual(c.state.stageJourney.outputs, ['Alpha has two cited strengths [source A].', 'Final Alpha brief'])
  c.selectJourneyStage(0); c.recordStageOutput('Corrected finding')
  assert.deepEqual(c.state.stageJourney.outputs, ['Corrected finding'])
  c.selectJourneyStage(1); c.previewJourneyStage()
  assert.match(c.state.stageJourney.preview, /Corrected finding/)
  assert.doesNotMatch(c.state.stageJourney.preview, /two cited strengths/)
})

test('task files survive stage preparation in the captured journey; Book availability still gates dispatch', async () => {
  const h = await fixture(), { c, sent } = h
  const bytes = new TextEncoder().encode('Fixture evidence')
  await c.addTaskFile({ name: 'evidence.txt', size: bytes.byteLength, arrayBuffer: async () => bytes.buffer })
  c.startStageJourney(); c.previewJourneyStage(); await c.prepareJourneyStage()
  c.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(sent[0][3]).request_id }))
  assert.equal(c.state.taskFiles.length, 0)
  await c.open(); assert.equal(c.recordStageOutput(''), false)
  c.recordStageOutput('Observed finding'); c.selectJourneyStage(1); c.previewJourneyStage()
  assert.match(c.state.stageJourney.preview, /Fixture evidence/)
  h.unavailable(); assert.equal(await c.prepareJourneyStage(), false); assert.equal(sent.length, 1)
  c.revise(); assert.equal(c.state.stageJourney, null)
})
