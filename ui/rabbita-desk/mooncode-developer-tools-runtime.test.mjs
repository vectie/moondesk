import assert from 'node:assert/strict'
import test from 'node:test'

import {
  moonCodeCommandRequest,
  moonCodeToolStateOpens,
  normalizeDeveloperBrowserUrl,
} from './mooncode-developer-tools-runtime.js'
import {
  comparisonRequestIdentity,
  comparisonSessionProjection,
  loadComparison,
  moonCodeComparisonBranches,
  moonCodeComparisonRequest,
  saveComparison,
} from './mooncode-compare-evidence-runtime.js'
import {
  moonCodeBrowserEvidencePayload,
  moonCodeBrowserEvidenceRequestId,
} from './mooncode-browser-evidence-runtime.js'

test('developer browser accepts isolated HTTP previews and rejects active schemes', () => {
  assert.equal(
    normalizeDeveloperBrowserUrl('localhost:4173/demo'),
    'http://localhost:4173/demo',
  )
  assert.equal(
    normalizeDeveloperBrowserUrl('/api/workspaces/book/site', 'http://127.0.0.1:5188/'),
    'http://127.0.0.1:5188/api/workspaces/book/site',
  )
  assert.equal(normalizeDeveloperBrowserUrl('javascript:alert(1)'), null)
  assert.equal(normalizeDeveloperBrowserUrl('file:///tmp/private'), null)
  assert.equal(normalizeDeveloperBrowserUrl('about:blank'), 'about:blank')
})

test('terminal text is explicitly framed as a MoonCode command request', () => {
  assert.equal(moonCodeCommandRequest(''), '')
  assert.equal(
    moonCodeCommandRequest('moon test'),
    'Run this command and report the complete command evidence:\n\nmoon test',
  )
})

test('tool detail disclosure opens active and exceptional states only', () => {
  for (const state of ['running', 'queued', 'pending', 'failed', 'cancelled', 'rejected', 'reverted', 'stale']) {
    assert.equal(moonCodeToolStateOpens(state), true)
  }
  for (const state of ['passed', 'applied', 'done', 'recorded']) {
    assert.equal(moonCodeToolStateOpens(state), false)
  }
})

test('fork comparison preserves one baseline and requires explicit promotion', () => {
  assert.equal(moonCodeComparisonRequest('', 'A', 'B'), '')
  const prompt = moonCodeComparisonRequest('Improve startup', 'Reduce eager work', 'Cache discovery')
  assert.match(prompt, /same current workspace baseline/)
  assert.match(prompt, /MoonFort/)
  assert.match(prompt, /Approach A:[\s\S]*Reduce eager work/)
  assert.match(prompt, /Approach B:[\s\S]*Cache discovery/)
  assert.match(prompt, /do not promote either branch/)
})

test('fork comparison creates two distinct evidence-bound branch turns', () => {
  const branches = moonCodeComparisonBranches(
    'Improve startup',
    'Reduce eager work',
    'Cache discovery',
    {
      id: 'comparison-1',
      baseline_request_digest: `sha256:${'a'.repeat(64)}`,
    },
  )
  assert.equal(branches.length, 2)
  assert.deepEqual(branches.map(branch => branch.label), ['A', 'B'])
  assert.notEqual(branches[0].prompt, branches[1].prompt)
  for (const branch of branches) {
    assert.match(branch.prompt, /MoonFort fork child/)
    assert.match(branch.prompt, /do not promote/)
    assert.match(branch.prompt, /sandbox receipt/)
    assert.match(branch.prompt, /comparison-1/)
    assert.match(branch.prompt, /sha256:a{64}/)
  }
})

test('comparison identity binds workspace, context, and goal into one digest', async () => {
  const identity = await comparisonRequestIdentity({
    dataset: { workspaceId: 'book-one', contextPath: 'src/main.mbt' },
  }, 'Improve startup')
  assert.match(identity.id, /^comparison-/)
  assert.match(identity.baseline_request_digest, /^sha256:[a-f0-9]{64}$/)
})

test('comparison session projection keeps only typed status and evidence counts', () => {
  assert.deepEqual(comparisonSessionProjection({
    id: 'session-a',
    status: 'done',
    mooncode_summary: {
      event_count: 12,
      verified_test_count: 3,
      pending_diff_count: 1,
    },
    hidden: 'ignored',
  }), {
    id: 'session-a',
    status: 'done',
    event_count: 12,
    verified_test_count: 3,
    pending_diff_count: 1,
  })
})

test('comparison coordinator saves to and restores from the durable service', async () => {
  const originalFetch = globalThis.fetch
  const root = { dataset: { workspaceId: 'book-one', contextPath: 'src/main.mbt' } }
  const durable = {
    contract: 'moondesk.mooncode_comparison.v1',
    id: 'comparison-one',
    workspace_id: 'book-one',
    context_path: 'src/main.mbt',
    baseline_request_digest: `sha256:${'a'.repeat(64)}`,
    goal: 'Improve startup',
    sessions: [
      { label: 'A', id: 'session-a', status: 'running' },
      { label: 'B', id: 'session-b', status: 'queued' },
    ],
    selected_branch: '',
    revision: 1,
  }
  const calls = []
  globalThis.fetch = async (url, options = {}) => {
    calls.push({ url: String(url), method: options.method || 'GET' })
    return new Response(JSON.stringify(
      options.method === 'POST'
        ? durable
        : { contract: 'moondesk.mooncode_comparisons.v1', comparisons: [durable] },
    ), { status: 200, headers: { 'content-type': 'application/json' } })
  }
  try {
    const saved = await saveComparison(root, durable)
    assert.equal(saved.persistence, 'durable')
    assert.equal(saved.revision, 1)
    const loaded = await loadComparison(root)
    assert.equal(loaded.persistence, 'durable')
    assert.equal(loaded.id, 'comparison-one')
    assert.deepEqual(calls, [
      { url: '/api/mooncode/comparisons', method: 'POST' },
      { url: '/api/mooncode/comparisons?workspace_id=book-one', method: 'GET' },
    ])
  } finally {
    globalThis.fetch = originalFetch
  }
})

test('developer browser evidence is bound to a workspace source and request', () => {
  const root = {
    dataset: {
      evidenceRequestId: 'evidence-1',
      sourcePath: 'book/site/generated/index.html',
    },
  }
  assert.deepEqual(
    moonCodeBrowserEvidencePayload(
      root,
      { accessibility: 'main: Generated site', resources: ['/assets/site.css', 7] },
      'no console errors',
      'no runtime errors',
    ),
    {
      protocol: 'moondesk-preview-evidence-v1',
      request_id: 'evidence-1',
      source_path: 'book/site/generated/index.html',
      accessibility: 'main: Generated site',
      resources: ['/assets/site.css', '7'],
      console: 'no console errors',
      runtime: 'no runtime errors',
    },
  )
  assert.notEqual(moonCodeBrowserEvidenceRequestId(), moonCodeBrowserEvidenceRequestId())
})
