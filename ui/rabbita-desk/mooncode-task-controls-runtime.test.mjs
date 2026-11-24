import assert from 'node:assert/strict'
import test from 'node:test'
import { JSDOM } from 'jsdom'
import { installMoonCodeTaskControls } from './mooncode-task-controls-runtime.js'

test('a new question reveals its answer controls once without stealing the composer draft', async () => {
  const dom = new JSDOM('<textarea id="composer"></textarea><details class="code-task-inspector"><summary>Task, queue and agents</summary><div data-mooncode-task-controls data-session-id="task"></div></details>', { url: 'http://localhost/', pretendToBeVisual: true })
  const state = { queue: [], questions: [], workers: [], plan: '', recap: '', context: { book_root: '/book', conversation: [] } }
  const requests = []
  let refresh
  let scrolls = 0
  dom.window.HTMLElement.prototype.scrollIntoView = () => { scrolls += 1 }
  const replacements = {
    window: dom.window, document: dom.window.document, MutationObserver: dom.window.MutationObserver,
    CustomEvent: dom.window.CustomEvent, setInterval: callback => { refresh = callback; return 0 },
    fetch: async (_url, request) => {
      const body = JSON.parse(request.body)
      requests.push(body)
      if (body.action === 'answer_question') state.questions = []
      return { ok: true, json: async () => structuredClone(state) }
    },
  }
  const previous = new Map(Object.keys(replacements).map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]))
  let dispose
  try {
    for (const [key, value] of Object.entries(replacements)) Object.defineProperty(globalThis, key, { configurable: true, writable: true, value })
    dispose = installMoonCodeTaskControls()
    await new Promise(resolve => setTimeout(resolve, 0))
    const inspector = dom.window.document.querySelector('details')
    const composer = dom.window.document.querySelector('#composer')
    composer.value = 'write me a python version print hello world'
    composer.focus()
    assert.equal(inspector.open, false)
    state.questions = [{ question_id: 'command:question', question: 'What should I write?', options: [] }]
    refresh()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(inspector.open, true)
    assert.equal(scrolls, 1)
    assert.equal(dom.window.document.activeElement, composer)
    assert.equal(composer.value, 'write me a python version print hello world')
    inspector.open = false
    refresh()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(inspector.open, false)
    assert.equal(scrolls, 1)
    inspector.open = true
    const answer = inspector.querySelector('.mooncode-task-question textarea')
    answer.value = composer.value
    ;[...inspector.querySelectorAll('button')].find(button => button.textContent === 'Send answer').click()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.deepEqual(requests.at(-1), { action: 'answer_question', question_id: 'command:question', answer: composer.value })
    assert.equal(inspector.querySelector('.mooncode-task-question'), null)
  } finally {
    dispose?.()
    dom.window.close()
    for (const [key, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    }
  }
})

test('single-agent task controls edit the working plan without a separate goal form', async () => {
  const dom = new JSDOM('<div data-mooncode-task-controls data-session-id="task"></div>', { url: 'http://localhost/' })
  const state = { queue: [], questions: [], workers: [], plan: 'Inspect, repair, verify', recap: '', context: { book_root: '/book', conversation: [] } }
  const requests = []
  const replacements = {
    window: dom.window, document: dom.window.document, MutationObserver: dom.window.MutationObserver,
    CustomEvent: dom.window.CustomEvent, setInterval: () => 0,
    fetch: async (_url, request) => {
      const body = JSON.parse(request.body)
      requests.push(body)
      if (body.action === 'set_plan') state.plan = body.plan
      return { ok: true, json: async () => structuredClone(state) }
    },
  }
  const previous = new Map(Object.keys(replacements).map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)]))
  let dispose
  try {
    for (const [key, value] of Object.entries(replacements)) Object.defineProperty(globalThis, key, { configurable: true, writable: true, value })
    dispose = installMoonCodeTaskControls()
    await new Promise(resolve => setTimeout(resolve, 0))
    const root = dom.window.document.querySelector('[data-mooncode-task-controls]')
    assert.match(root.textContent, /Working plan/)
    assert.doesNotMatch(root.textContent, /Set goal|Done when|No delegated agents yet|Agent team/)
    const label = [...root.querySelectorAll('label')].find(label => label.firstChild?.textContent === 'Working plan')
    label.querySelector('textarea').value = 'Deliver the verified repair'
    ;[...root.querySelectorAll('button')].find(button => button.textContent === 'Save plan').click()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.deepEqual(requests.at(-1), { action: 'set_plan', plan: 'Deliver the verified repair' })
    assert.equal(state.plan, 'Deliver the verified repair')
  } finally {
    dispose?.()
    dom.window.close()
    for (const [key, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    }
  }
})
