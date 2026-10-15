import assert from 'node:assert/strict'
import test from 'node:test'
import { conversationSuggestions, suggestionSignature } from './mooncode-suggestions-model.js'

test('an empty conversation does not invent next work', () => {
  assert.deepEqual(conversationSuggestions({}), [])
})

test('failed commands and interrupted requests retain exact task context', () => {
  const items = conversationSuggestions({ failedCommand: 'moon test source', status: 'interrupted', user: 'Fix the composer', answer: 'Stopped' })
  assert.equal(items[0].id, 'failed-command')
  assert.match(items[0].text, /moon test source/)
  assert.equal(items[1].id, 'resume')
  assert.match(items[1].text, /Fix the composer/)
})

test('the latest question is offered as an editable answer scaffold', () => {
  const items = conversationSuggestions({ answer: 'Should the sidebar stay open on small screens?' })
  assert.equal(items[0].id, 'answer-question')
  assert.match(items[0].text, /Should the sidebar stay open on small screens\?/)
})

test('suggestions follow actual implementation and file context', () => {
  const items = conversationSuggestions({ answer: 'Updated the editor. Next step is selection feedback.', selectedPath: 'src/editor.mbt' })
  assert.deepEqual(items.map(item => item.id), ['explain-file', 'review-changes', 'next-step'])
  assert.match(items[0].text, /src\/editor.mbt/)
  assert.notEqual(suggestionSignature({ answer: 'A' }), suggestionSignature({ answer: 'B' }))
})
