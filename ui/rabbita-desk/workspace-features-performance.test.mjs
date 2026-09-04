import assert from 'node:assert/strict'
import test from 'node:test'
import { performance } from 'node:perf_hooks'

import {
  chatProjectionFingerprint,
  conversationPersistenceFingerprint,
  projectChatFromDom,
  typedSourceEntries,
} from './workspace-features-runtime.js'

class FakeElement {
  constructor(role, content, fragment = false) {
    this.children = []
    this.dataset = fragment
      ? { kind: role, payload: content }
      : { chatRole: role }
    this.content = content
    this.classList = {
      contains: value => value === (fragment ? 'wiki-chat-fragment' : 'wiki-chat-message'),
    }
  }

  querySelector(selector) {
    return selector === ':scope > p' ? { textContent: this.content } : null
  }
}

function withFakeChatDom(children, body) {
  const priorElement = globalThis.HTMLElement
  const priorDocument = globalThis.document
  const thread = new FakeElement('', '')
  thread.children = children
  globalThis.HTMLElement = FakeElement
  globalThis.document = {
    querySelector: selector => selector === '[data-testid="wiki-chat-thread"]' ? thread : null,
  }
  try { return body(thread) } finally {
    globalThis.HTMLElement = priorElement
    globalThis.document = priorDocument
  }
}

test('1 MiB streamed answer fingerprint remains suffix-bounded', () => {
  const response = 'x'.repeat(1024 * 1024)
  const chat = Array.from({ length: 239 }, (_, index) => ({
    role: index % 2 ? 'assistant' : 'user',
    content: `message ${index}`,
  }))
  chat.push({ role: 'assistant-stream', content: response })
  const started = performance.now()
  let fingerprint = ''
  for (let index = 0; index < 1000; index += 1) {
    fingerprint = conversationPersistenceFingerprint('task', 'documents/large.docx', 'working', chat)
  }
  const elapsed = performance.now() - started
  assert.match(fingerprint, /1048576/)
  assert.ok(elapsed < 250, `suffix fingerprint took ${elapsed.toFixed(1)} ms`)
})

test('hundreds of typed locations are parsed without transcript inference', () => {
  const chat = Array.from({ length: 600 }, (_, index) => ({
    role: index % 2 ? 'source_ref' : 'artifact_ref',
    content: JSON.stringify(index % 2 ? {
      workspace_path: 'documents/forecast.xlsx',
      sheet: `Sheet ${index % 8}`,
      cell_range: `A${index}:D${index}`,
      label: `Citation ${index}`,
    } : {
      path: `outputs/artifact-${index}.xlsx`,
      mime_type: 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
    }),
  }))
  const started = performance.now()
  const sources = typedSourceEntries(chat)
  const elapsed = performance.now() - started
  assert.equal(sources.length, 600)
  assert.equal(sources[1].location.sheet, 'Sheet 1')
  assert.ok(elapsed < 250, `typed source parsing took ${elapsed.toFixed(1)} ms`)
})

test('240-message projection updates only the streamed tail', () => {
  const nodes = Array.from({ length: 240 }, (_, index) =>
    new FakeElement(index % 2 ? 'assistant' : 'user', `message ${index}`))
  withFakeChatDom(nodes, () => {
    let state = {
      task_id: 'task-long',
      chat_count: 240,
      chat_revision: '0',
      chat_tail_role: 'assistant-stream',
      chat_tail_bytes: nodes.at(-1).content.length,
    }
    nodes.at(-1).dataset.chatRole = 'assistant-stream'
    let chat = projectChatFromDom(state, [], '')
    let fingerprint = chatProjectionFingerprint(state)
    assert.equal(chat.length, 240)
    const large = 'x'.repeat(1024 * 1024)
    nodes.at(-1).content = large
    state = { ...state, chat_tail_bytes: large.length }
    const started = performance.now()
    for (let index = 0; index < 1000; index += 1) {
      nodes.at(-1).content = `${large}${index}`
      state = {
        ...state,
        chat_revision: String(index + 1),
        chat_tail_bytes: large.length + String(index).length,
      }
      const nextFingerprint = chatProjectionFingerprint(state)
      chat = projectChatFromDom(state, chat, fingerprint)
      fingerprint = nextFingerprint
    }
    const elapsed = performance.now() - started
    assert.equal(chat.at(-1).content.endsWith('999'), true)
    assert.ok(elapsed < 250, `tail projection took ${elapsed.toFixed(1)} ms`)
  })
})

test('rapid conversation replacement remains bounded at the visible transcript policy', () => {
  const nodes = Array.from({ length: 240 }, (_, index) =>
    new FakeElement(index % 2 ? 'assistant' : 'user', `file-a message ${index}`))
  withFakeChatDom(nodes, thread => {
    let chat = []
    let fingerprint = ''
    const started = performance.now()
    for (let switchIndex = 0; switchIndex < 80; switchIndex += 1) {
      thread.children = nodes.map((node, index) =>
        new FakeElement(index % 2 ? 'assistant' : 'user', `file-${switchIndex} message ${index}`))
      const state = {
        task_id: `task-${switchIndex}`,
        chat_count: 240,
        chat_revision: String(switchIndex),
        chat_tail_role: 'assistant',
        chat_tail_bytes: thread.children.at(-1).content.length,
      }
      chat = projectChatFromDom(state, chat, fingerprint)
      fingerprint = chatProjectionFingerprint(state)
    }
    const elapsed = performance.now() - started
    assert.equal(chat.at(-1).content, 'file-79 message 239')
    assert.ok(elapsed < 250, `rapid replacement took ${elapsed.toFixed(1)} ms`)
  })
})
