import assert from 'node:assert/strict'
import test from 'node:test'

import {
  boundedText,
  changeCategory,
  chatProjectionFingerprint,
  historyChanges,
  mergeFollowupQueues,
  modeLabel,
  officeReviewChanges,
  typedLocationLabel,
  shouldAutoSendFollowup,
} from './workspace-features-runtime.js'

test('chat projection fingerprint is constant-size and changes with streamed tails', () => {
  const first = chatProjectionFingerprint({
    task_id: 'task-1',
    chat_count: 240,
    chat_revision: '100',
    chat_tail_role: 'assistant-stream',
    chat_tail_bytes: 1024 * 1024,
  })
  const next = chatProjectionFingerprint({
    task_id: 'task-1',
    chat_count: 240,
    chat_revision: '101',
    chat_tail_role: 'assistant-stream',
    chat_tail_bytes: 1024 * 1024 + 64,
  })
  assert.equal(first.length < 64, true)
  assert.notEqual(first, next)
})

test('Find and Add exposes distinct user-facing providers', () => {
  assert.deepEqual(
    ['files', 'semantic', 'structure', 'code', 'issues', 'work'].map(modeLabel),
    ['Exact', 'Meaning', 'Structure', 'Code', 'Issues', 'Work'],
  )
})

test('Typed document locations have stable human labels', () => {
  assert.equal(
    typedLocationLabel({ sheet: 'Revenue', cell_range: 'B12:D12' }),
    'Revenue · B12:D12',
  )
  assert.equal(typedLocationLabel({ slide: 4 }), 'slide 4')
  assert.equal(typedLocationLabel({ page: 2, section: 'Risks' }), 'page 2 · Risks')
})

test('Office review categorizes content, formula, formatting, and layout', () => {
  assert.equal(changeCategory({ text: 'A' }, { text: 'B' }), 'content')
  assert.equal(changeCategory({ formula: '=A1' }, { formula: '=A2' }), 'formula')
  assert.equal(changeCategory({ text: 'A', bold: false }, { text: 'A', bold: true }), 'formatting')
  assert.equal(changeCategory({ text: 'A', x: 1 }, { text: 'A', x: 2 }), 'layout')
  assert.deepEqual(
    officeReviewChanges({
      kind: 'pptx',
      before: { text: 'A', x: 1, y: 2, width: 3, height: 4 },
      after: { text: 'B', x: 2, y: 2, width: 4, height: 4 },
    }),
    ['Text changed', 'Position changed', 'Size changed'],
  )
})

test('History compare filters semantic change categories', () => {
  const left = { items: [
    { reference: 'A1', text: '1', formula: '=1' },
    { reference: 'A2', text: 'Draft', bold: false },
  ] }
  const right = { items: [
    { reference: 'A1', text: '2', formula: '=2' },
    { reference: 'A2', text: 'Draft', bold: true },
  ] }
  assert.equal(historyChanges(left, right, 'all').length, 2)
  assert.equal(historyChanges(left, right, 'formula').length, 1)
  assert.equal(historyChanges(left, right, 'formatting').length, 1)
  assert.equal(historyChanges(left, right, 'content').length, 0)
})

test('Persisted visible text is bounded before it enters local UI archives', () => {
  assert.equal(boundedText('  hello   world  '), 'hello world')
  assert.equal(boundedText('abcdef', 5), 'abcd…')
})

test('Concurrent follow-up drafts merge by stable turn identity', () => {
  assert.deepEqual(
    mergeFollowupQueues(
      [
        { id: 'remote', text: 'remote turn', state: 'draft' },
        { id: 'shared', text: 'older text', state: 'draft' },
      ],
      [
        { id: 'shared', text: 'edited locally', state: 'draft' },
        { id: 'local', text: 'local turn', state: 'draft' },
      ],
    ).map(item => [item.id, item.text]),
    [
      ['remote', 'remote turn'],
      ['shared', 'edited locally'],
      ['local', 'local turn'],
    ],
  )
})

test('follow-ups advance only after a real busy-to-idle transition', () => {
  assert.equal(shouldAutoSendFollowup(null, false, false), false)
  assert.equal(shouldAutoSendFollowup(false, false, false), false)
  assert.equal(shouldAutoSendFollowup(true, true, false), false)
  assert.equal(shouldAutoSendFollowup(true, false, false), true)
  assert.equal(shouldAutoSendFollowup(true, false, true), false)
})
