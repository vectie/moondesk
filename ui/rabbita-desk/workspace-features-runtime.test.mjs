import assert from 'node:assert/strict'
import test from 'node:test'

import {
  boundedText,
  changeCategory,
  chatProjectionFingerprint,
  historyChanges,
  learningProposalCounts,
  learningBookState,
  learningRequestMatches,
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

test('Book learning distinguishes persistence, per-item legacy migration, and failed saves', () => {
  assert.equal(learningBookState({ status: 'accepted' }).action, 'Save to book')
  assert.equal(learningBookState({ status: 'proposed' }).action, '')
  assert.equal(learningBookState({ status: 'rejected' }).action, '')
  const local = learningBookState({ status: 'accepted', book_learning: { status: 'unsupported' } })
  assert.equal(local.label, 'Desk only')
  assert.equal(local.action, '')
  assert.match(local.message, /not saved to a Book/)
  for (const status of ['pending', 'failed']) {
    const state = learningBookState({ status: 'accepted', book_learning: { status } })
    assert.equal(state.action, 'Retry book save')
    assert.match(state.message, /not yet saved/)
  }
  assert.match(learningBookState({ status: 'accepted', book_learning: { status: 'failed', error: 'learning_book_content_conflict' } }).message, /Nothing was overwritten/)
  const saved = learningBookState({ status: 'accepted', book_learning: { status: 'persisted' } })
  assert.equal(saved.action, '')
  assert.equal(saved.message, 'Saved to this book’s portable learning')
})

test('Learning read and save completions stay with the captured workspace and latest request', () => {
  const oldReadA = { workspaceId: 'A', generation: 1 }
  const readB = { workspaceId: 'B', generation: 2 }
  const latestReadA = { workspaceId: 'A', generation: 3 }
  assert.equal(learningRequestMatches(oldReadA, 'B', 2), false)
  assert.equal(learningRequestMatches(oldReadA, 'A', 3), false)
  assert.equal(learningRequestMatches(readB, 'A', 3), false)
  assert.equal(learningRequestMatches(latestReadA, 'A', 3), true)
  const saveA = { workspaceId: 'A', generation: 4 }
  assert.equal(learningRequestMatches(latestReadA, 'A', 4), false)
  assert.equal(learningRequestMatches(saveA, 'A', 4), true)
  assert.equal(learningRequestMatches(saveA, 'B', 5), false)
  assert.equal(learningRequestMatches(saveA, 'A', 6), false)
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
  assert.equal(html.includes('moondesk.review-package.v1'), true)
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

import { readFile } from 'node:fs/promises'

const sourcePath = new URL('./workspace-features-runtime.js', import.meta.url)
const source = await readFile(sourcePath, 'utf8')

test('continuation inspection anchors explicitly bypass client route interception', async () => {
  const view = await readFile(new URL('./main/work_continuation_outputs.mbt', import.meta.url), 'utf8')
  assert.match(view, /a\(\s*href=url,\s*target=Blank,\s*escape=true,/)
  assert.match(view, /rel\("noopener noreferrer"\)/)
  assert.equal(view.includes('on_click='), false)
})
// Expose the real private renderer only in this in-memory test module. Product
// exports remain unchanged; this exercises the real row-rendering branch.
const module = await import(`data:text/javascript;base64,${Buffer.from(`${source}
export function renderLearningForReview(records) {
  serverState = { workspace_id: 'suite-review' }
  featureState.learning_proposals = records
  featureState.learning_loaded_for = 'suite-review'
  featureState.learning_draft = null
  featureState.learning_status = ''
  return renderLearningTab()
}
`).toString('base64')}`)

class FakeElement {
  constructor(tag) { this.tagName = tag; this.children = []; this.textContent = '' }
  append(...children) { this.children.push(...children) }
  setAttribute() {}
  addEventListener() {}
}

function renderedText(record) {
  const prior = globalThis.document
  globalThis.document = { createElement: tag => new FakeElement(tag) }
  const text = node => [node.textContent, ...node.children.map(text)].join('\n')
  try { return text(module.renderLearningForReview([record])) } finally {
    if (prior === undefined) delete globalThis.document
    else globalThis.document = prior
  }
}

const path = 'memory/beliefs/desk-not-a-real-file.md'
const accepted = { id: 'lesson', kind: 'preference', detail: 'Keep guidance', status: 'accepted' }

test('unsupported SuiteRoot row explains the destination and never displays an unwritten Book path', () => {
  const output = renderedText({ ...accepted, book_learning: { status: 'unsupported', path, error: 'learning_requires_moonbook' } })
  assert.match(output, /Desk only/)
  assert.match(output, /Accepted for Desk guidance, but not saved to a Book/)
  assert.match(output, /Select a MoonBook workspace/)
  assert.equal(output.includes(path), false)
  assert.equal(output.includes('Retry book save'), false)
})

test('persisted row retains its actual Book path and success label', () => {
  const output = renderedText({ ...accepted, book_learning: { status: 'persisted', path } })
  assert.match(output, /Saved to book/)
  assert.equal(output.includes(path), true)
})

test('failed Book row preserves explicit retry and failure wording', () => {
  const output = renderedText({ ...accepted, book_learning: { status: 'failed', path, error: 'learning_book_write_failed' } })
  assert.match(output, /Retry book save/)
  assert.match(output, /not yet saved to the book/)
  assert.equal(output.includes(path), false)
})

test('historical Desk-only row retains per-item Save to book', () => {
  const output = renderedText(accepted)
  assert.match(output, /Desk only/)
  assert.match(output, /Save to book/)
  assert.match(output, /Save this lesson to the book to make it portable/)
})

// Exercise production signal -> emit -> DOM -> transport code in an isolated
// in-memory module. Nothing is exported for tests by the shipped runtime.
class RuntimeElement extends FakeElement {
  constructor(tag) {
    super(tag)
    this.dataset = {}
    this.style = {}
    this.attributes = {}
    this.listeners = new Map()
    this.classList = { contains: name => (this.className || '').split(' ').includes(name) }
  }
  setAttribute(key, value) { this.attributes[key] = value }
  addEventListener(name, callback) {
    this.listeners.set(name, [...(this.listeners.get(name) || []), callback])
  }
  replaceChildren(...children) { this.children = children }
  querySelector() { return null }
  querySelectorAll() { return [] }
  fire(name, detail = {}) {
    for (const callback of this.listeners.get(name) || []) {
      callback({ preventDefault() {}, stopPropagation() {}, ...detail })
    }
  }
}

let harnessNumber = 0
const settleLearning = async () => { for (let i = 0; i < 12; i += 1) await Promise.resolve() }
const allNodes = root => [root, ...root.children.flatMap(allNodes)]
const runtimeText = root => allNodes(root).map(node => node.textContent).join('\n')
const canonicalBinding = (suffix = 'A', generation = 1) => ({
  active: true, phase: 'ready', generation, binding_key: `canonical-${suffix}-${generation}`,
  workspace_id: `book-${suffix}`, book_root: `/books/${suffix}`, session_id: `session-${suffix}`,
  original_command_id: `command-${suffix}`, task_id: `task-${suffix}`, run_id: `run-${suffix}`,
  target_query: new URLSearchParams({ work_task: `task-${suffix}`, work_run: `run-${suffix}`,
    session: `session-${suffix}`, command: `command-${suffix}`, book_root: `/books/${suffix}`,
    return_to: '/project?task=one' }).toString(),
  output_hint: { command_id: '', path: '', evidence_id: '' },
})
const canonicalSource = {
  command_id: 'command-A', turn_id: 'turn-1', item_id: 'item-1', client_turn_id: 'client-1',
  content: 'The saved answer\nwith original formatting.', conversation_revision: 7, continuation_id: '',
}

async function capturedHarness(initial = canonicalBinding()) {
  const globals = ['document', 'HTMLElement', 'Element', 'location', 'fetch', 'addEventListener',
    'localStorage', '__moondeskWorkspaceFeatureSignal', '__moondeskPendingWorkspaceFeatureSignals',
    '__moondeskDownloadWorkPackage', '__moondeskCapturedFilesReady']
  const prior = new Map(globals.map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]))
  const root = new RuntimeElement('root')
  const documentEvents = new RuntimeElement('document')
  const windowEvents = new RuntimeElement('window')
  const requests = []
  const storageWrites = []
  const ambient = { workspace_id: 'ordinary-browse-workspace', selected_document: '', task_id: '', chat_count: 0 }
  const project = binding => { root.dataset.state = JSON.stringify({ ...ambient, captured_work: binding }) }
  const navigate = binding => {
    const query = new URLSearchParams(binding.target_query)
    for (const [key, field] of [['work_output_command', 'command_id'], ['work_output_path', 'path'], ['work_output_evidence', 'evidence_id']]) {
      if (binding.output_hint?.[field]) query.set(key, binding.output_hint[field])
    }
    globalThis.location = { search: `?${query}`, href: `https://desk.invalid/?${query}` }
  }
  project(initial)
  navigate(initial)
  Object.assign(globalThis, {
    HTMLElement: RuntimeElement, Element: RuntimeElement,
    document: {
      readyState: 'loading', documentElement: new RuntimeElement('html'),
      createElement: tag => new RuntimeElement(tag),
      querySelector: selector => selector === '[data-testid="workspace-feature-overlays"]' ? root : null,
      querySelectorAll: () => [],
      addEventListener: (...args) => documentEvents.addEventListener(...args),
    },
    addEventListener: (...args) => windowEvents.addEventListener(...args),
    localStorage: { getItem: () => null, setItem: (...args) => storageWrites.push(args) },
    fetch: (url, options = {}) => {
      if (!url.startsWith('/api/learning-proposals')) {
        return Promise.resolve({ ok: true, json: async () => ({ conversations: [] }) })
      }
      return new Promise((resolve, reject) => requests.push({
        url, options, body: options.body && JSON.parse(options.body),
        succeed: payload => resolve({ ok: true, json: async () => payload }),
        fail: () => reject(new Error('uncertain transport')),
      }))
    },
  })
  const imported = await import(`data:text/javascript;base64,${Buffer.from(`${source}
export const capturedRuntimeHarness${++harnessNumber} = true
export { emit as emitForTest, render as renderForTest, install as installForTest }
export const ordinaryForTest = featureState
export const capturedForTest = () => capturedLearning
`).toString('base64')}`)
  const signal = globalThis.__moondeskWorkspaceFeatureSignal
  imported.installForTest()
  await settleLearning()
  return {
    root, requests, storageWrites, project, navigate, ...imported,
    signal: (action, payload) => signal(action, JSON.stringify(payload)),
    teach: (binding = initial, answer = canonicalSource) => signal('teach-captured-work', JSON.stringify({ binding, source: answer })),
    review: (binding = initial) => signal('review-captured-learning', JSON.stringify({ binding })),
    find: (tag, text) => allNodes(root).find(node => node.tagName === tag && (text === undefined || node.textContent === text)),
    click(text) {
      const node = this.find('button', text)
      assert.ok(node, `button exists: ${text}`)
      assert.equal(Boolean(node.disabled), false, `button enabled: ${text}`)
      node.fire('click')
    },
    edit(text, kind = 'knowledge') {
      const detail = this.find('textarea')
      assert.ok(detail)
      detail.value = text
      detail.fire('input')
      const select = this.find('select')
      select.value = kind
      select.fire('change')
    },
    escape: () => documentEvents.fire('keydown', { key: 'Escape' }),
    popstate: () => windowEvents.fire('popstate'),
    close: () => { for (const [key, descriptor] of prior) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    } },
  }
}

async function emptyJournal(harness, index = 0, workspace = 'book-A') {
  harness.requests[index].succeed({ workspace_id: workspace, proposals: [] })
  await settleLearning()
}

test('captured Teach uses canonical destination and real learning-only form without touching ordinary draft', async () => {
  const h = await capturedHarness()
  try {
    const ordinaryDraft = { kind: 'preference', detail: 'ordinary draft', source: '' }
    h.ordinaryForTest.learning_draft = ordinaryDraft
    h.teach()
    assert.equal(h.requests[0].url, '/api/learning-proposals?workspace_id=book-A')
    assert.match(runtimeText(h.root), /Learning destination: book-A · \/books\/A/)
    assert.match(runtimeText(h.root), /full-page reload.*discards unsaved drafts/)
    assert.match(runtimeText(h.root), /Refresh exact work.*discards unsaved drafts/)
    assert.match(runtimeText(h.root), /starting a follow-up.*discards unsaved drafts/)
    assert.equal(allNodes(h.root).some(node => node.attributes.role === 'tablist'), false)
    assert.equal(runtimeText(h.root).includes('Document tools'), false)
    await emptyJournal(h)
    h.edit('Keep the exact guidance', 'procedure')
    h.find('form').fire('submit')
    assert.equal(h.requests[1].body.workspace_id, 'book-A')
    assert.equal(h.requests[1].body.action, 'propose')
    assert.equal(h.requests[1].body.kind, 'procedure')
    assert.equal(h.requests[1].body.detail, 'Keep the exact guidance')
    for (const value of ['book-A', '/books/A', 'session-A', 'command-A', 'turn-1', 'item-1', 'client-1']) {
      assert.ok(h.requests[1].body.source.includes(value))
    }
    assert.match(h.requests[1].body.source, /Conversation revision: 7/)
    assert.match(h.requests[1].body.source, /The saved answer\nwith original formatting\./)
    assert.equal(h.ordinaryForTest.learning_draft, ordinaryDraft)
    assert.deepEqual(h.storageWrites, [])
    assert.equal(allNodes(h.root).some(node => Object.values(node.attributes).some(value => String(value).includes('The saved answer'))), false)
  } finally { h.close() }
})

test('typed captured drafts survive renderer updates, Close, Escape, and source switches; Cancel clears only current source', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    await emptyJournal(h)
    h.edit('Typed before repaint', 'capability')
    h.renderForTest()
    assert.equal(h.find('textarea').value, 'Typed before repaint')
    assert.equal(h.find('select').value, 'capability')
    h.click('×')
    assert.equal(h.find('form'), undefined)
    h.teach()
    assert.equal(h.find('textarea').value, 'Typed before repaint')
    h.escape()
    assert.equal(h.find('form'), undefined)
    h.teach()
    assert.equal(h.find('textarea').value, 'Typed before repaint')
    h.teach(canonicalBinding(), { ...canonicalSource, item_id: 'item-2', content: 'Different saved answer' })
    assert.equal(h.find('textarea').value, '')
    h.edit('Second lesson')
    h.teach()
    assert.equal(h.find('textarea').value, 'Typed before repaint')
    h.click('Cancel')
    assert.equal(h.find('form'), undefined)
    h.teach()
    assert.equal(h.find('textarea').value, '')
    h.teach(canonicalBinding(), { ...canonicalSource, item_id: 'item-2', content: 'Different saved answer' })
    assert.equal(h.find('textarea').value, 'Second lesson')
    assert.equal(h.requests.length, 1)
  } finally { h.close() }
})

test('captured saves are single-flight and an uncertain save only reconciles by explicit Reload', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    h.emitForTest('captured-learning-reload', 'canonical-A-1')
    assert.equal(h.requests.length, 1)
    await emptyJournal(h)
    h.edit('A lesson that may already be saved')
    const form = h.find('form')
    form.fire('submit')
    const submitted = h.requests[1].body
    form.fire('submit')
    h.emitForTest('captured-learning-reload', 'canonical-A-1')
    h.teach(canonicalBinding(), { ...canonicalSource, item_id: 'other', content: 'Other' })
    assert.equal(h.requests.length, 2)
    h.requests[1].fail()
    await settleLearning()
    assert.equal(h.find('textarea').value, submitted.detail)
    assert.match(runtimeText(h.root), /nothing is automatically resubmitted/)
    form.fire('submit')
    h.renderForTest()
    h.escape()
    h.teach()
    assert.equal(h.requests.length, 2)
    assert.equal(h.find('button', 'Save for review').disabled, true)
    h.click('Reload')
    assert.equal(h.requests.length, 3)
    h.requests[2].succeed({ workspace_id: 'book-A', proposals: [{ ...submitted, id: 'saved-on-server', status: 'proposed' }] })
    await settleLearning()
    assert.equal(h.find('form'), undefined)
    assert.match(runtimeText(h.root), /previously submitted proposal is saved/)
    assert.equal(h.requests.filter(request => request.options.method === 'POST').length, 1)
  } finally { h.close() }
})

test('captured request callbacks and old DOM submits fail closed on generation, navigation, output, or exit changes', async () => {
  for (const change of ['generation', 'navigation', 'output', 'exit']) {
    const h = await capturedHarness()
    try {
      h.teach()
      await emptyJournal(h)
      h.edit('A bound lesson')
      const form = h.find('form')
      form.fire('submit')
      const saved = { ...h.requests[1].body, id: 'stale-save', status: 'proposed' }
      if (change === 'generation') h.project(canonicalBinding('A', 2))
      if (change === 'navigation') globalThis.location.search = globalThis.location.search.replace('work_run=run-A', 'work_run=newer-run')
      if (change === 'output') globalThis.location.search += '&work_output_command=other-command'
      if (change === 'exit') h.project({ active: false, phase: 'inactive', generation: 2 })
      h.requests[1].succeed(saved)
      await settleLearning()
      form.fire('submit')
      assert.equal(h.requests.length, 2, change)
      assert.equal(h.capturedForTest().learning_proposals.length, 0, change)
      h.renderForTest()
      assert.equal(h.capturedForTest(), null, change)
      assert.equal(h.find('form'), undefined, change)
    } finally { h.close() }
  }
})

test('stale reads cannot overwrite a new captured workspace and back/forward cannot restore an old draft', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    const next = canonicalBinding('B', 2)
    h.project(next)
    h.navigate(next)
    h.review(next)
    assert.equal(h.requests[1].url, '/api/learning-proposals?workspace_id=book-B')
    h.requests[0].succeed({ workspace_id: 'book-A', proposals: [{ workspace_id: 'book-A', id: 'late', status: 'proposed' }] })
    await emptyJournal(h, 1, 'book-B')
    assert.deepEqual(h.capturedForTest().learning_proposals, [])
    h.project(canonicalBinding())
    h.navigate(canonicalBinding())
    h.teach()
    await emptyJournal(h, 2)
    h.edit('Do not revive after departure')
    globalThis.location.search = ''
    h.popstate()
    assert.equal(h.capturedForTest(), null)
    h.navigate(canonicalBinding())
    h.popstate()
    h.teach()
    assert.equal(h.find('textarea').value, '')
  } finally { h.close() }
})

test('captured signals reject stale or tampered bindings and invalid sources before requests', async () => {
  const h = await capturedHarness()
  try {
    for (const changed of [
      { workspace_id: 'other' }, { generation: 9 }, { binding_key: 'old' },
      { book_root: '/other' }, { session_id: 'other' }, { original_command_id: 'other' },
      { output_hint: { command_id: 'other' } },
    ]) h.teach({ ...canonicalBinding(), ...changed })
    for (const changed of [{ turn_id: '' }, { command_id: '' }, { content: '   ' }, { content: null }]) {
      h.teach(canonicalBinding(), { ...canonicalSource, ...changed })
    }
    h.signal('teach-captured-work', { binding: canonicalBinding(), source: null })
    assert.equal(h.requests.length, 0)
    assert.equal(h.find('form'), undefined)
  } finally { h.close() }
})

test('captured provenance keeps full identity and visibly truncates only the answer excerpt', async () => {
  const h = await capturedHarness()
  try {
    h.teach(canonicalBinding(), { ...canonicalSource, item_id: '', command_id: 'follow-up-9', continuation_id: 'continuation-9', content: '🌙'.repeat(9000) })
    await emptyJournal(h)
    h.edit('Long answer lesson')
    h.find('form').fire('submit')
    const provenance = h.requests[1].body.source
    assert.ok(provenance.length <= 8000)
    assert.match(provenance, /Source command: "follow-up-9"/)
    assert.match(provenance, /Continuation: "continuation-9"/)
    assert.match(provenance, /Answer excerpt truncated; source identity retained/)
    assert.equal(/[\uD800-\uDBFF]\n\[Answer excerpt/.test(provenance), false)
    assert.equal(h.requests[1].body.workspace_id, 'book-A')
  } finally { h.close() }
})

test('persisted captured proposals reopen with existing book states and decisions use captured workspace', async () => {
  const h = await capturedHarness()
  try {
    h.review()
    h.requests[0].succeed({ workspace_id: 'book-A', proposals: [
      { ...accepted, workspace_id: 'book-A', id: 'persisted', book_learning: { status: 'persisted', path: 'memory/saved.md' } },
      { ...accepted, workspace_id: 'book-A', id: 'unsupported', book_learning: { status: 'unsupported', path: 'must-not-show.md' } },
      { ...accepted, workspace_id: 'book-A', id: 'failed', book_learning: { status: 'failed' } },
      { ...accepted, workspace_id: 'book-A', id: 'legacy' },
      { ...accepted, workspace_id: 'book-A', id: 'pending', status: 'proposed' },
    ] })
    await settleLearning()
    const text = runtimeText(h.root)
    for (const label of ['Saved to book', 'Desk only', 'Book save incomplete', 'Retry book save', 'Save to book', 'Accept learning']) assert.ok(text.includes(label), label)
    assert.equal(text.includes('must-not-show.md'), false)
    assert.equal(h.find('form'), undefined)
    h.click('Accept learning')
    assert.deepEqual(h.requests[1].body, { action: 'accept', id: 'pending', workspace_id: 'book-A' })
    h.requests[1].succeed({ ...accepted, workspace_id: 'book-A', id: 'pending', book_learning: { status: 'persisted', path: 'memory/new.md' } })
    await settleLearning()
    h.click('×')
    h.review()
    assert.match(runtimeText(h.root), /memory\/new.md/)
    h.click('Retry book save')
    assert.deepEqual(h.requests[2].body, { action: 'persist', id: 'failed', workspace_id: 'book-A' })
  } finally { h.close() }
})

test('fresh runtime intentionally drops ephemeral drafts while Review reloads saved proposals', async () => {
  let h = await capturedHarness()
  try {
    h.teach()
    await emptyJournal(h)
    h.edit('Unsaved before full page reload')
    assert.deepEqual(h.storageWrites, [])
  } finally { h.close() }
  h = await capturedHarness()
  try {
    h.review()
    assert.equal(h.find('form'), undefined)
    assert.equal(h.requests.length, 1)
    h.requests[0].succeed({ workspace_id: 'book-A', proposals: [{ ...accepted, workspace_id: 'book-A', book_learning: { status: 'persisted', path: 'memory/durable.md' } }] })
    await settleLearning()
    assert.match(runtimeText(h.root), /Saved to book/)
    assert.match(runtimeText(h.root), /memory\/durable.md/)
    assert.equal(runtimeText(h.root).includes('Unsaved before full page reload'), false)
  } finally { h.close() }
})

test('portable next-step guidance appears only after an accepted lesson is saved in the captured Book', async () => {
  for (const [status, persistence, shown] of [
    ['proposed', 'persisted', false], ['rejected', 'persisted', false],
    ['accepted', 'unsupported', false], ['accepted', 'failed', false],
    ['accepted', undefined, false], ['accepted', 'persisted', true],
  ]) {
    const h = await capturedHarness()
    try {
      h.review()
      h.requests[0].succeed({ workspace_id: 'book-A', proposals: [{
        ...accepted, workspace_id: 'book-A', status,
        book_learning: persistence ? { status: persistence, path: 'memory/saved.md' } : undefined,
      }] })
      await settleLearning()
      const copy = runtimeText(h.root)
      assert.equal(copy.includes('Optional next step:'), shown)
      if (shown) {
        assert.match(copy, /close Learning Review, then choose Exit inspection/)
        assert.match(copy, /Keep this same Book selected \(book-A · \/books\/A\)/)
        assert.match(copy, /Publish → Experienced Book package/)
        assert.match(copy, /Nothing is packaged or transferred to Town automatically/)
        assert.equal(allNodes(h.root).some(node => ['button', 'a', 'form'].includes(node.tagName) && /Publish|package|Town/.test(node.textContent)), false)
        h.click('×')
        assert.equal(h.requests.length, 1)
        assert.equal(h.find('aside'), undefined)
      }
      assert.equal(h.requests.length, 1)
      assert.deepEqual(h.storageWrites, [])
    } finally { h.close() }
  }
})

test('an uncertain save stays locked through failed Reload and retries only after an explicit reconciled submit', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    await emptyJournal(h)
    h.edit('Retain this after uncertain save', 'preference')
    h.find('form').fire('submit')
    h.requests[1].fail()
    await settleLearning()
    h.click('Reload')
    h.requests[2].fail()
    await settleLearning()
    assert.match(runtimeText(h.root), /Save is still unconfirmed/)
    assert.equal(h.find('button', 'Save for review').disabled, true)
    h.find('form').fire('submit')
    assert.equal(h.requests.length, 3)
    h.click('Reload')
    await emptyJournal(h, 3)
    assert.equal(h.find('textarea').value, 'Retain this after uncertain save')
    assert.equal(h.find('select').value, 'preference')
    assert.equal(h.find('button', 'Save for review').disabled, false)
    assert.equal(h.requests.length, 4)
    h.find('form').fire('submit')
    assert.equal(h.requests.length, 5)
    assert.deepEqual(h.requests[4].body, h.requests[1].body)
  } finally { h.close() }
})

test('closing during a captured save preserves its binding and successful completion without reopening the panel', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    await emptyJournal(h)
    h.edit('Saved after Close')
    h.find('form').fire('submit')
    assert.equal(h.find('button', 'Cancel').disabled, true)
    h.click('×')
    h.requests[1].succeed({ ...h.requests[1].body, id: 'saved-after-close', status: 'proposed' })
    await settleLearning()
    assert.equal(h.find('form'), undefined)
    assert.equal(h.capturedForTest().open, false)
    h.review()
    assert.equal(h.find('form'), undefined)
    assert.match(runtimeText(h.root), /Saved after Close/)
    assert.equal(h.requests.length, 2)
  } finally { h.close() }
})

test('captured journal responses cannot cross destinations and malformed save acknowledgments remain uncertain', async () => {
  const h = await capturedHarness()
  try {
    h.teach()
    h.requests[0].succeed({ workspace_id: 'wrong-book', proposals: [{ ...accepted, workspace_id: 'wrong-book' }] })
    await settleLearning()
    assert.deepEqual(h.capturedForTest().learning_proposals, [])
    assert.match(runtimeText(h.root), /could not be loaded/)
    h.click('Reload')
    await emptyJournal(h, 1)
    h.edit('Keep unconfirmed detail')
    h.find('form').fire('submit')
    h.requests[2].succeed({ ...accepted, workspace_id: 'wrong-book' })
    await settleLearning()
    assert.equal(h.find('textarea').value, 'Keep unconfirmed detail')
    assert.match(runtimeText(h.root), /Save could not be confirmed/)
    assert.equal(h.capturedForTest().save_uncertain, true)
    assert.deepEqual(h.capturedForTest().learning_proposals, [])
  } finally { h.close() }
})

test('same-workspace proposal acknowledgments must match submitted kind, detail, source, and proposed status', async () => {
  for (const mismatch of [
    { source: 'Source from another saved answer' },
    { detail: 'Another proposal in the same workspace' },
    { kind: 'procedure' },
    { status: 'accepted', book_learning: { status: 'persisted' } },
    { id: '   ' },
  ]) {
    const h = await capturedHarness()
    try {
      h.teach()
      await emptyJournal(h)
      h.edit('Keep this exact proposal')
      h.find('form').fire('submit')
      h.requests[1].succeed({ ...h.requests[1].body, id: 'proposal-reply', status: 'proposed', ...mismatch })
      await settleLearning()
      assert.equal(h.capturedForTest().save_uncertain, true)
      assert.equal(h.capturedForTest().save_inflight, false)
      assert.equal(h.find('textarea').value, 'Keep this exact proposal')
      assert.deepEqual(h.capturedForTest().learning_proposals, [])
      assert.match(runtimeText(h.root), /Save could not be confirmed/)
      assert.equal(runtimeText(h.root).includes('Saved to this book’s portable learning'), false)
      h.find('form').fire('submit')
      assert.equal(h.requests.length, 2)
    } finally { h.close() }
  }
})

test('same-workspace decision acknowledgments require the requested record and resulting status', async () => {
  for (const action of ['accept', 'reject', 'persist']) {
    for (const mismatch of ['id', 'status']) {
      const h = await capturedHarness()
      try {
        h.review()
        const existing = { ...accepted, workspace_id: 'book-A', id: 'requested-lesson',
          status: action === 'persist' ? 'accepted' : 'proposed' }
        h.requests[0].succeed({ workspace_id: 'book-A', proposals: [existing] })
        await settleLearning()
        h.click({ accept: 'Accept learning', reject: 'Dismiss', persist: 'Save to book' }[action])
        assert.deepEqual(h.requests[1].body, { action, id: 'requested-lesson', workspace_id: 'book-A' })
        const expectedStatus = action === 'reject' ? 'rejected' : 'accepted'
        h.requests[1].succeed({ ...existing,
          id: mismatch === 'id' ? 'another-lesson' : 'requested-lesson',
          status: mismatch === 'status' ? (action === 'reject' ? 'accepted' : 'proposed') : expectedStatus,
          book_learning: { status: 'persisted' },
        })
        await settleLearning()
        assert.equal(h.capturedForTest().save_uncertain, true, `${action}/${mismatch}`)
        assert.deepEqual(h.capturedForTest().learning_proposals, [existing], `${action}/${mismatch}`)
        assert.match(runtimeText(h.root), /Save could not be confirmed/)
        assert.equal(runtimeText(h.root).includes('Saved to book'), false)
        h.emitForTest(`captured-learning-${action}`, 'canonical-A-1', 'requested-lesson')
        assert.equal(h.requests.length, 2)
      } finally { h.close() }
    }
  }
})

test('a matching proposal acknowledgment accepts the backend-normalized source and clears only the submitted draft', async () => {
  const h = await capturedHarness()
  try {
    h.teach(canonicalBinding(), { ...canonicalSource, content: 'Saved answer with trailing whitespace\n\n' })
    await emptyJournal(h)
    h.edit('Exact successful proposal')
    h.find('form').fire('submit')
    const submitted = h.requests[1].body
    h.requests[1].succeed({ ...submitted, source: submitted.source.trim(), id: 'confirmed-lesson', status: 'proposed' })
    await settleLearning()
    assert.equal(h.capturedForTest().save_uncertain, false)
    assert.equal(h.find('form'), undefined)
    assert.equal(h.capturedForTest().learning_proposals[0].id, 'confirmed-lesson')
    assert.match(runtimeText(h.root), /Waiting for your review/)
  } finally { h.close() }
})
