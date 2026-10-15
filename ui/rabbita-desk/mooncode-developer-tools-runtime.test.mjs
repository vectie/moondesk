import assert from 'node:assert/strict'
import test from 'node:test'

import {
  moonCodeCommandRequest,
  moonCodeToolStateOpens,
  normalizeDeveloperBrowserUrl,
  composerSettingsSummary,
  installComposerControls,
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

test('composer settings retain nested select controls and update the typed sync inputs', () => {
  class Node {
    constructor(tag) { this.tag = tag; this.children = []; this.dataset = {}; this.listeners = {}; this.attributes = {}; this.value = ''; this.open = false }
    append(...nodes) { for (const node of nodes) { node.parentElement = this; this.children.push(node) } }
    prepend(...nodes) { for (const node of nodes) node.parentElement = this; this.children.unshift(...nodes) }
    replaceChildren(...nodes) { this.children = []; this.append(...nodes) }
    setAttribute(name, value) { this.attributes[name] = value }
    getAttribute(name) { return this.attributes[name] }
    addEventListener(name, callback) { this.listeners[name] = callback }
    dispatchEvent(event) { this.listeners[event.type]?.(event) }
    get options() { return this.children }
    closest() { return this.dataset.runtime ? this : this.parentElement?.closest() }
    querySelector(selector) {
      const testid = selector.match(/data-testid="([^"]+)"/)?.[1]
      const sync = selector.match(/data-mooncode-control-sync="([^"]+)"/)?.[1]
      for (const node of this.children) {
        if (testid && node.dataset.testid === testid || sync && node.dataset.mooncodeControlSync === sync || selector.includes('> summary') && node.tag === 'summary') return node
        const child = node.querySelector(selector)
        if (child) return child
      }
      return null
    }
  }
  class Select extends Node {}
  class Input extends Node {}
  const previous = Object.fromEntries(['document', 'HTMLElement', 'HTMLSelectElement', 'HTMLInputElement', 'InputEvent'].map(key => [key, globalThis[key]]))
  try {
    Object.assign(globalThis, { HTMLElement: Node, HTMLSelectElement: Select, HTMLInputElement: Input, InputEvent: class { constructor(type, options) { this.type = type; Object.assign(this, options) } }, document: { createElement: tag => tag === 'select' ? new Select(tag) : new Node(tag) } })
    const root = new Node('div')
    root.dataset = { runtime: 'mooncode-composer-controls-v1', models: 'moongate/test-model', selectedModel: 'moongate/test-model', reasoning: 'high', taskIntent: 'read_only' }
    const updates = []
    for (const kind of ['model', 'reasoning', 'task-intent']) {
      const input = new Input('input')
      input.dataset.mooncodeControlSync = kind
      input.addEventListener('input', () => { updates.push([kind, input.value]); root.dataset[kind === 'task-intent' ? 'taskIntent' : kind === 'model' ? 'selectedModel' : kind] = input.value })
      root.append(input)
    }
    installComposerControls(root)
    const settings = root.children.find(node => node.tag === 'details')
    const reasoning = root.querySelector('[data-testid="mooncode-reasoning-select"]')
    reasoning.value = 'medium'; reasoning.dispatchEvent({ type: 'change' })
    assert.deepEqual(updates, [['reasoning', 'medium']])
    settings.open = true; settings.open = false
    installComposerControls(root)
    assert.equal(root.querySelector('[data-testid="mooncode-reasoning-select"]'), reasoning)
    assert.equal(reasoning.value, 'medium')
    assert.equal(root.querySelector('[data-testid="mooncode-task-intent-select"]').value, 'read_only')
    assert.equal(settings.children[0].dataset.custom, 'true')
    root.dataset.reasoning = 'none'; root.dataset.taskIntent = 'auto'
    installComposerControls(root)
    assert.equal(settings.children[0].dataset.custom, 'false')
    assert.equal(composerSettingsSummary('high', 'read_only').label, 'Response settings. Reasoning: High. Task purpose: Review only')
  } finally {
    for (const [key, value] of Object.entries(previous)) { if (value === undefined) delete globalThis[key]; else globalThis[key] = value }
  }
})

test('composer settings translates both the summary and its current option values', () => {
  const i18n = { message(key, params) {
    if (key === 'code.response_settings_summary') return `回复设置。推理强度：${params.reasoning}。任务目的：${params.task}`
    return { 'code.reasoning_high': '高', 'code.task_read_only': '提问 / 审阅' }[key]
  } }
  const summary = composerSettingsSummary('high', 'read_only', i18n)
  assert.equal(summary.label, '回复设置。推理强度：高。任务目的：提问 / 审阅')
  assert.deepEqual(summary.params, { reasoning: '高', task: '提问 / 审阅' })
})

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
