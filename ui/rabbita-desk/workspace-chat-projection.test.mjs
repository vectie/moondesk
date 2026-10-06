import assert from 'node:assert/strict'
import test from 'node:test'

import {
  chatProjectionFingerprint,
  projectChatFromDom,
} from './workspace-features-runtime.js'

class ChatElement {
  constructor(content, role = 'assistant-stream', fragment = false) {
    this.children = []
    this.content = content
    this.reads = 0
    this.dataset = fragment ? { kind: role, payload: content } : { chatRole: role }
    this.classList = {
      contains: name => name === (fragment ? 'wiki-chat-fragment' : 'wiki-chat-message'),
    }
  }

  querySelector(selector) {
    assert.equal(selector, ':scope > p')
    this.reads += 1
    return { textContent: this.content }
  }
}

function withChat(children, run) {
  const previousElement = globalThis.HTMLElement
  const previousDocument = globalThis.document
  const thread = new ChatElement('')
  thread.children = children
  globalThis.HTMLElement = ChatElement
  globalThis.document = {
    querySelector: selector => {
      assert.equal(selector, '[data-testid="wiki-chat-thread"]')
      return thread
    },
  }
  try { run(thread) } finally {
    globalThis.HTMLElement = previousElement
    globalThis.document = previousDocument
  }
}

function stateFor(children, revision = '1') {
  return {
    task_id: 'projection-regression',
    chat_count: children.length,
    chat_revision: revision,
    chat_tail_role: children.at(-1)?.dataset.chatRole || '',
    chat_tail_bytes: children.at(-1)?.content.length || 0,
  }
}

test('chat nonblank filtering matches trim for every leading UTF-16 code unit', () => {
  withChat([], thread => {
    // Include unpaired surrogates, control characters, all ECMAScript whitespace,
    // and both ASCII fast-path boundaries. Projection must retain exact content.
    for (let start = 0; start < 0x10000; start += 128) {
      const contents = Array.from({ length: 128 }, (_, offset) =>
        `${String.fromCharCode(start + offset)} \t\n`)
      thread.children = contents.map(content => new ChatElement(content))
      const result = projectChatFromDom(stateFor(thread.children))
      assert.deepEqual(result, contents.filter(content => content.trim()).map(content => ({
        role: 'assistant-stream', content,
      })))
    }
  })
})

test('chat projection preserves Unicode, HTML-like text, and long whitespace exactly', () => {
  const whitespace = '\t\n\v\f\r \u00a0\u1680\u2000\u2001\u2002\u2003\u2004\u2005\u2006\u2007\u2008\u2009\u200a\u2028\u2029\u202f\u205f\u3000\ufeff'
  const longWhitespace = whitespace.repeat(4096)
  const contents = [
    '', whitespace, longWhitespace,
    '!', '~', '\x7f', '\0', '\u0085', '\u180e', '\u200b',
    '😀', '\ud800', '\udfff', 'e\u0301', '中文',
    '<script>alert("&")</script>\n\'😀',
    `${longWhitespace}x${longWhitespace}`,
    `x${longWhitespace}`, `${longWhitespace}😀`,
    'x'.repeat(1024 * 1024) + '\n\t😀<>&',
  ]
  const nodes = contents.map(content => new ChatElement(content))
  withChat(nodes, () => {
    assert.deepEqual(projectChatFromDom(stateFor(nodes)), contents
      .filter(content => content.trim())
      .map(content => ({ role: 'assistant-stream', content })))
  })
})

test('streamed tail updates preserve every character and prior entries without rereading them', () => {
  const nodes = Array.from({ length: 240 }, (_, index) =>
    new ChatElement(`message ${index}`, index % 2 ? 'assistant' : 'user'))
  nodes.at(-1).dataset.chatRole = 'assistant-stream'
  withChat(nodes, () => {
    let state = stateFor(nodes)
    let chat = projectChatFromDom(state)
    let fingerprint = chatProjectionFingerprint(state)
    const head = chat.slice(0, -1)
    const payloads = ['x', '😀', ' \t中文', '\u200b', '\ud800', '<&"\'>']
    for (let index = 0; index < 24; index += 1) {
      const content = payloads[index % payloads.length].repeat(131072) + `\n${index}  `
      const previous = chat
      const previousTail = chat.at(-1)
      nodes.at(-1).content = content
      state = stateFor(nodes, String(index + 2))
      chat = projectChatFromDom(state, chat, fingerprint)
      fingerprint = chatProjectionFingerprint(state)
      assert.equal(chat.length, 240)
      assert.equal(chat.at(-1).content, content)
      assert.equal(chat.at(-1).role, 'assistant-stream')
      assert.equal(previous.at(-1), previousTail)
      for (let headIndex = 0; headIndex < 239; headIndex += 1) {
        assert.equal(chat[headIndex], head[headIndex])
        assert.equal(nodes[headIndex].reads, 1)
      }
    }
    assert.equal(nodes.at(-1).reads, 25)
  })
})

test('unchanged fingerprints and blank streamed tails retain the previous projection', () => {
  const tail = new ChatElement('original')
  withChat([tail], () => {
    const initialState = stateFor([tail])
    const chat = projectChatFromDom(initialState)
    const fingerprint = chatProjectionFingerprint(initialState)
    tail.content = 'not yet published'
    assert.equal(projectChatFromDom(initialState, chat, fingerprint), chat)
    assert.equal(tail.reads, 1)
    for (const blank of ['', ' \t\n', '\ufeff\u3000']) {
      tail.content = blank
      assert.equal(projectChatFromDom(stateFor([tail], '2'), chat, fingerprint), chat)
    }
    tail.content = 'completion  \n'
    tail.dataset.chatRole = 'assistant'
    assert.deepEqual(projectChatFromDom(stateFor([tail], '3'), chat, fingerprint), [
      { role: 'assistant', content: 'completion  \n' },
    ])
  })
})

test('typed fragments keep their existing raw payload and role rules', () => {
  const nodes = [
    new ChatElement('  ', 'source_ref', true),
    new ChatElement('{"path":"x<&😀"}', ' artifact_ref ', true),
    new ChatElement('', 'source_ref', true),
    new ChatElement('payload', '  ', true),
    new ChatElement('  ', 'assistant'),
    new ChatElement(' keep\n ', ' assistant '),
  ]
  withChat(nodes, () => {
    assert.deepEqual(projectChatFromDom(stateFor(nodes)), [
      { role: 'source_ref', content: '  ' },
      { role: 'artifact_ref', content: '{"path":"x<&😀"}' },
      { role: 'assistant', content: ' keep\n ' },
    ])
  })
})
