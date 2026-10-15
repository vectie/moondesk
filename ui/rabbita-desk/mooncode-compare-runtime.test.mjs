import test from 'node:test'
import assert from 'node:assert/strict'
import { startComparisonBranches, comparisonNeedsRefresh } from './mooncode-compare-runtime.js'

test('partial comparison start preserves accepted conversation and retry identity', async () => {
  const progress = [], calls = []
  const branches = [{ label: 'A', model: 'first', client_turn_id: 'stable-a' }, { label: 'B', model: 'second', client_turn_id: 'stable-b' }]
  const create = async branch => { calls.push(branch.client_turn_id); if (branch.label === 'B') throw new Error('Provider unavailable'); return { ...branch, id: 'accepted-a', status: 'running' } }
  const result = await startComparisonBranches(branches, create, async state => progress.push(state))
  assert.equal(result.sessions[0].id, 'accepted-a')
  assert.equal(result.failed_branches[0].client_turn_id, 'stable-b')
  assert.equal(result.failed_branches[0].model, 'second')
  assert.ok(progress.some(state => state.sessions.some(session => session.id === 'accepted-a')))
  await startComparisonBranches(result.failed_branches, async branch => { calls.push(branch.client_turn_id); return { ...branch, id: 'accepted-b' } })
  assert.deepEqual(calls, ['stable-a', 'stable-b', 'stable-b'])
})

test('comparison refresh waits for canonical turn completion rather than an idle empty session', () => {
  assert.equal(comparisonNeedsRefresh([{ status: 'idle', answer: '' }]), true)
  assert.equal(comparisonNeedsRefresh([{ status: 'idle', turn_status: 'running', answer: 'partial' }]), true)
  assert.equal(comparisonNeedsRefresh([{ status: 'idle', turn_status: 'completed', answer: 'done' }]), false)
  assert.equal(comparisonNeedsRefresh([{ status: 'failed' }]), false)
})
