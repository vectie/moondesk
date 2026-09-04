import assert from 'node:assert/strict'
import test from 'node:test'

import {
  boundedText,
  changeCategory,
  chatProjectionFingerprint,
  historyChanges,
  learningProposalCounts,
  learningProposalTransition,
  mergeFollowupQueues,
  modeLabel,
  officeReviewChanges,
  reviewPackageFromState,
  reviewPackageHtml,
  reviewRoomProjection,
  typedLocationLabel,
  shouldAutoSendFollowup,
  shouldRestoreDocumentThread,
  sourceSubscriptionCounts,
  sourceSubscriptionTransition,
  taskRecipeMissingFields,
} from './workspace-features-runtime.js'

test('Learning Review transitions are immutable and preserve decision counts', () => {
  const current = [
    { id: 'one', status: 'proposed', detail: 'First' },
    { id: 'two', status: 'accepted', detail: 'Second' },
  ]
  const next = learningProposalTransition(current, {
    id: 'one', status: 'accepted', detail: 'First',
  })
  assert.deepEqual(next.map(item => item.id), ['one', 'two'])
  assert.deepEqual(learningProposalCounts(next), {
    proposed: 0, accepted: 2, rejected: 0,
  })
  assert.equal(current[0].status, 'proposed')
})

test('Task recipe validation reports only missing required decisions', () => {
  const recipe = { fields: [
    { key: 'audience', required: true },
    { key: 'tone', required: false },
    { key: 'period', required: true },
  ] }
  assert.deepEqual(
    taskRecipeMissingFields(recipe, { audience: 'Board', tone: '' }),
    ['period'],
  )
  assert.deepEqual(
    taskRecipeMissingFields(recipe, { audience: 'Board', period: 'Q3' }),
    [],
  )
})

test('Source subscription transitions are immutable and preserve setup state', () => {
  const pending = { id: 'source-one', status: 'needs_setup', title: 'Reports' }
  const current = [pending, { id: 'source-two', status: 'active', title: 'Feed' }]
  const next = sourceSubscriptionTransition(current, {
    ...pending,
    status: 'active',
    standing_goal_id: 'goal-one',
  })
  assert.deepEqual(next.map(item => item.id), ['source-one', 'source-two'])
  assert.deepEqual(sourceSubscriptionCounts(next), { active: 2, needs_setup: 0 })
  assert.equal(current[0].status, 'needs_setup')
})

test('Review room projection pins decisions first and deduplicates participants', () => {
  const records = [
    { id: 'open', kind: 'thread', author: 'You', assigned_to: 'Alex', pinned: false },
    { id: 'reply', kind: 'reply', author: 'Agent', assigned_to: '' },
    { id: 'pinned', kind: 'thread', author: 'Alex', assigned_to: 'Agent', pinned: true },
  ]
  const room = reviewRoomProjection(records, ['You'])
  assert.deepEqual(room.threads.map(item => item.id), ['pinned', 'open'])
  assert.deepEqual(room.participants, ['You', 'Alex', 'Agent'])
  assert.deepEqual(records.map(item => item.id), ['open', 'reply', 'pinned'])
})

test('Review packages are bounded, grouped, and HTML escaped', () => {
  const packageData = reviewPackageFromState(
    {
      workspace: 'Board <Book>',
      selected_document: 'documents/brief.docx',
      chat: [
        { role: 'tool', content: 'hidden' },
        { role: 'user', content: 'Check <script>alert(1)</script>' },
      ],
    },
    [
      { id: 'decision', kind: 'thread', detail: 'Approve', pinned: true },
      { id: 'reply', kind: 'reply', thread_id: 'decision', author: 'Alex', detail: 'Agreed' },
    ],
    [{ label: 'Forecast', type: 'workspace', value: 'data/forecast.xlsx' }],
    '2026-09-04T15:00:00Z',
  )
  assert.equal(packageData.contract, 'moondesk.review-package.v1')
  assert.equal(packageData.conversation.length, 1)
  assert.equal(packageData.discussions[0].replies[0].author, 'Alex')
  const html = reviewPackageHtml(packageData)
  assert.equal(html.includes('<script>alert(1)</script>'), false)
  assert.equal(html.includes('&lt;script&gt;alert(1)&lt;/script&gt;'), true)
  assert.equal(html.includes('Pinned decisions'), true)
})

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

test('explicit new conversations cannot be auto-restored over by document history', () => {
  assert.equal(shouldRestoreDocumentThread('', 0, false), true)
  assert.equal(shouldRestoreDocumentThread('', 0, true), false)
  assert.equal(shouldRestoreDocumentThread('task-one', 0, false), false)
  assert.equal(shouldRestoreDocumentThread('', 2, false), false)
})
