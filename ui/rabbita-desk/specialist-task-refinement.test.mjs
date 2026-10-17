import test from 'node:test'
import assert from 'node:assert/strict'
import { beginTaskRefinement, refinedTaskBrief } from './specialist-task-refinement.js'
import { specialistBrief } from './specialist-builder.js'
import { withTaskFiles } from './specialist-task-files.js'

const source = { contract: 'moondesk.specialist-preset.v1', id: 'original', revision: 4, name: 'Report writer', purpose: 'Explain the evidence', example: 'Explain the example',
  book: { workspace_id: 'book', book_id: 'book', version: '1', name: 'Book' }, capabilities: [], knowledge_paths: ['wiki/guide.md'],
  task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Explain {{topic}}' } }
const fileContent = '\ufeffExact 001.20\r\n海😀'
const files = [{ name: 'evidence.txt', content: fileContent, bytes: new TextEncoder().encode(fileContent).length }]
const observation = { row_index: 0, row_number: 2, original_cells: ['Exports'], inputs: { topic: 'Exports' }, task: 'Explain Exports',
  brief: withTaskFiles(specialistBrief(source, 'Explain Exports'), files), output: 'An unsupported claim', notes: 'Separate facts from inference' }

test('refinement copies the exact observed task, source and files into an independent ordinary variant', () => {
  const csv = { creator: structuredClone(source), observations: [structuredClone(observation)], observationFiles: [structuredClone(files)] }
  const { draft, context } = beginTaskRefinement(csv, 0, specialistBrief)
  assert.equal(draft.id, undefined); assert.equal(draft.variant.source_id, source.id)
  assert.deepEqual(draft.task_form, source.task_form)
  csv.creator.purpose = 'Later source'; csv.observations[0].task = 'Other task'; csv.observationFiles[0][0].content = 'Other file'
  assert.deepEqual(context.source, source); assert.deepEqual(context.observation, observation); assert.deepEqual(context.files, files)
  const creator = { ...draft, id: 'variant', contract: source.contract, revision: 1, purpose: source.purpose + '. Cite evidence and label unsupported inferences.' }
  creator.task_form.template = 'A future task for {{reader}}'
  const brief = refinedTaskBrief(context, creator, specialistBrief)
  assert.ok(brief.includes('Representative task:\nExplain Exports'))
  assert.ok(brief.includes(JSON.stringify(files[0].content))); assert.doesNotMatch(brief, /Other file|Other task|unsupported claim/)
  assert.equal(Object.hasOwn(creator, 'observation'), false)
})

test('historical file observations cannot silently retry using changed or missing snapshots', () => {
  const csv = { creator: source, observations: [observation] }
  assert.throws(() => beginTaskRefinement(csv, 0, specialistBrief), /snapshots are unavailable/)
  assert.throws(() => beginTaskRefinement({ ...csv, observationFiles: [[{ ...files[0], content: 'Changed' }]] }, 0, specialistBrief), /snapshots are unavailable/)
  const plain = { ...observation, brief: specialistBrief(source, observation.task) }
  assert.deepEqual(beginTaskRefinement({ creator: source, observations: [plain] }, 0, specialistBrief).context.files, [])
})

test('same-task retry requires an actual purpose correction, a separate identity and bounded complete brief', () => {
  const { draft, context } = beginTaskRefinement({ creator: source, observations: [observation], observationFiles: [files] }, 0, specialistBrief)
  assert.throws(() => refinedTaskBrief(context, { ...source, id: 'variant' }, specialistBrief), /concrete correction/)
  assert.throws(() => refinedTaskBrief(context, { ...source, purpose: 'Corrected' }, specialistBrief), /concrete correction/)
  assert.throws(() => refinedTaskBrief({ ...context, files: [] }, { ...draft, id: 'variant', purpose: 'Corrected' }, () => 'x'.repeat(48001)), /48,000/)
})
