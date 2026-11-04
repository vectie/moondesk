import test from 'node:test'
import assert from 'node:assert/strict'
import { startComparisonBranches, comparisonNeedsRefresh } from './mooncode-compare-runtime.js'
import { readFileSync } from 'node:fs'
import { JSDOM } from 'jsdom'

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

test('comparison requires a meaningful goal without losing its local draft', async () => {
  const dom = new JSDOM('<main data-workspace-id="compare-input"><section data-developer-tool-panel="compare"></section></main>', { url: 'http://localhost', runScripts: 'outside-only' })
  try {
    let requests = 0
    dom.window.fetch = () => { requests++; throw new Error('Unexpected request') }
    dom.window.evidence = { loadComparison: async () => null }
    const source = readFileSync(new URL('./mooncode-compare-runtime.js', import.meta.url), 'utf8').replace(/^export /gm, '').replaceAll("await import('./mooncode-compare-evidence-runtime.js')", 'window.evidence')
    dom.window.eval(source + '\nwindow.installComparison = installMoonCodeCompare')
    const root = dom.window.document.querySelector('main'); dom.window.installComparison(root)
    const goal = root.querySelector('[data-developer-compare-goal]'), submit = root.querySelector('button[type="submit"]')
    const input = value => { goal.value = value; goal.dispatchEvent(new dom.window.Event('input', { bubbles: true })) }
    assert.equal(submit.disabled, true)
    input('  '); assert.equal(submit.disabled, true)
    input('Compare two approaches'); assert.equal(submit.disabled, false)
    assert.equal(JSON.parse(dom.window.localStorage.getItem('moondesk.compare.draft:compare-input')).goal, 'Compare two approaches')
    input(''); root.querySelector('form').dispatchEvent(new dom.window.Event('submit', { cancelable: true }))
    await Promise.resolve()
    assert.equal(requests, 0)
  } finally { dom.window.close() }
})
