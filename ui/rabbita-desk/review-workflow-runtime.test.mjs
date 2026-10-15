import test from 'node:test'
import assert from 'node:assert/strict'
import { reviewDiffSections, reviewDiffPairs, reviewFindingPrompt, reviewJsonChanges, reviewChangedTokens, reviewAgentPrompt } from './review-workflow-runtime.js'
import { linkSubmittedFindings, reconcileReviewFinding } from './review-findings.js'

test('historical review preserves renamed file and exact old/new lines', () => {
  const files = reviewDiffSections('diff --git a/old.mbt b/new.mbt\n--- a/old.mbt\n+++ b/new.mbt\n@@ -9,3 +12,4 @@\n same\n-old\n+new\n+extra\n end\n')
  assert.equal(files[0].title, 'new.mbt')
  assert.deepEqual(files[0].hunks[0].rows.map(r => [r.kind, r.old, r.next]), [
    ['context', 9, 12], ['removed', 10, ''], ['added', '', 13], ['added', '', 14], ['context', 11, 15],
  ])
  const pairs = reviewDiffPairs(files[0].hunks[0].rows)
  assert.equal(pairs[1][0].text, 'old'); assert.equal(pairs[1][1].text, 'new')
  assert.equal(pairs[2][0], null); assert.equal(pairs[2][1].text, 'extra')
  assert.equal(pairs[3][0].old, 11); assert.equal(pairs[3][1].next, 15)
})

test('binary and deletion commits preserve file boundaries without invented hunks', () => {
  const files = reviewDiffSections('diff --git a/logo.png b/logo.png\nBinary files differ\ndiff --git a/deleted b/deleted\n--- a/deleted\n+++ /dev/null\n@@ -1 +0,0 @@\n-gone\n')
  assert.equal(files.length, 2); assert.equal(files[0].hunks.length, 0)
  assert.match(files[0].metadata.join(''), /Binary files differ/)
  assert.equal(files[1].hunks[0].rows[0].old, 1)
})

test('finding follow-up carries original source and discussion context', () => {
  const prompt = reviewFindingPrompt({ path: 'src/main.mbt', line: 17, body: 'Handle empty input', url: 'https://github.com/org/repo/pull/1#discussion_r1', revision: 'abc' })
  assert.match(prompt, /src\/main.mbt:17/); assert.match(prompt, /reviewed revision abc/)
  assert.match(prompt, /Handle empty input/); assert.match(prompt, /#discussion_r1/)
  assert.match(prompt, /Inspect the current code/)
})

test('JSON structural review ignores formatting and key order but reports value paths', () => {
  assert.deepEqual(reviewJsonChanges('{"a":1,"b":2}', '{ "b": 2, "a": 1 }'), [])
  assert.deepEqual(reviewJsonChanges('{"a/b":{"old":true}}', '{"a/b":{"new":null}}').map(c => [c.path, c.kind]), [['/a~1b/new', 'added'], ['/a~1b/old', 'removed']])
  assert.equal(reviewJsonChanges('', '{"created":true}')[0].kind, 'added')
  assert.throws(() => reviewJsonChanges('not json', '{}'))
})

test('token changes preserve identifiers and punctuation around replacement', () => {
  assert.deepEqual(reviewChangedTokens('return old_value(x)', 'return next_value(x)'), [['return ', 'old_value', '(x)'], ['return ', 'next_value', '(x)']])
  assert.deepEqual(reviewChangedTokens('same', 'same'), [['same', '', ''], ['same', '', '']])
})

test('agent review preserves selected scope and asks for actionable findings without edits', () => {
  assert.match(reviewAgentPrompt('working'), /staged and unstaged/)
  assert.match(reviewAgentPrompt('branch', 'origin/main'), /compared with origin\/main/)
  assert.match(reviewAgentPrompt('commit', 'abc123'), /commit abc123/)
  assert.match(reviewAgentPrompt('custom', 'Only parser changes'), /Only parser changes/)
  assert.match(reviewAgentPrompt('working'), /Do not modify files/)
})

test('findings link only matching accepted contexts and canonical command evidence', () => {
  const findings = [{ id: 'one', workspaceId: 'book', status: 'draft' }, { id: 'two', workspaceId: 'other', status: 'draft' }]
  const linked = linkSubmittedFindings(findings, { workspaceId: 'book', sessionId: 'chat', clientTurnId: 'client', contexts: [{ text: '[Review finding one]\nfix' }, { text: '[Review finding two]' }] })
  assert.equal(linked[0].sessionId, 'chat'); assert.equal(linked[1].status, 'draft')
  assert.equal(reconcileReviewFinding(linked[0], []).commandId, undefined)
  const current = reconcileReviewFinding(linked[0], [{ command_id: 'real-turn', status: 'completed', user: { content: '[Review finding one]\nfix' }, assistant: { content: 'Changed the parser' } }])
  assert.equal(current.commandId, 'real-turn'); assert.equal(current.taskStatus, 'completed')
  assert.equal(current.status, 'submitted', 'completed work does not automatically verify a finding')
})
