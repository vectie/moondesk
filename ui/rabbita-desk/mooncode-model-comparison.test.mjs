import test from 'node:test'
import assert from 'node:assert/strict'
import { configureComparisonBranches, comparisonAnswerProjection } from './mooncode-compare-evidence-runtime.js'

test('model comparison sends the same read-only question to the chosen models', () => {
  const branches = configureComparisonBranches([{ label: 'A' }, { label: 'B' }], 'models', ['first', 'second'], 'Explain this design')
  assert.equal(branches[0].prompt, branches[1].prompt)
  assert.equal(branches[0].task_intent, 'read_only')
  assert.deepEqual(branches.map(branch => branch.model), ['first', 'second'])
  const approaches = configureComparisonBranches([{ label: 'A', prompt: 'Implement A' }], 'approaches', ['first'], 'Goal')
  assert.equal(approaches[0].prompt, 'Implement A')
  assert.equal(approaches[0].task_intent, undefined)
})

test('comparison displays canonical answer and only measured provider usage', () => {
  const actual = comparisonAnswerProjection({ context: { model: 'selected', conversation: [
    { assistant: { content: 'Earlier' }, usage: { measured: false, input_tokens: 100000 } },
    { assistant: { content: 'Actual answer' }, usage: { measured: true, input_tokens: 12, output_tokens: 8 } },
  ] } })
  assert.equal(actual.answer, 'Actual answer')
  assert.equal(actual.input_tokens, 12)
  assert.equal(actual.output_tokens, 8)
  assert.equal(actual.usage_measured, true)
  assert.equal(comparisonAnswerProjection({}).usage_measured, false)
})
