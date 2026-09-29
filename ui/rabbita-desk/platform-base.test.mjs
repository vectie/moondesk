import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import test from 'node:test'
import vm from 'node:vm'

const source = readFileSync(new URL('./public/platform-base.js', import.meta.url), 'utf8')

function load(scriptPath) {
  const location = new URL('https://example.test/moondesk/?activity=code')
  class Element {
    attributes = new Map()
    setAttribute(name, value) { this.attributes.set(name, value) }
    getAttribute(name) { return this.attributes.get(name) ?? null }
    querySelectorAll() { return [] }
  }
  const context = {
    URL,
    Request,
    location,
    Element,
    MutationObserver: class { observe() {} },
    document: {
      currentScript: { src: `https://example.test${scriptPath}` },
      documentElement: new Element(),
    },
    fetch: input => input,
    WebSocket: class { constructor(url) { this.url = url } },
    EventSource: class { constructor(url) { this.url = url } },
  }
  context.globalThis = context
  vm.runInNewContext(source, context)
  return context
}

test('platform build keeps MoonDesk API and socket traffic below /moondesk', () => {
  const app = load('/moondesk/platform-base.js')
  assert.equal(app.fetch('/api/mooncode/chat'), 'https://example.test/moondesk/api/mooncode/chat')
  assert.equal(app.fetch('/moondesk/api/mooncode/chat'), '/moondesk/api/mooncode/chat')
  assert.equal(new app.WebSocket('wss://example.test/ws').url, 'wss://example.test/moondesk/ws')
  assert.equal(new app.EventSource('/api/events').url, 'https://example.test/moondesk/api/events')
  assert.equal(app.fetch('/user/v1/models'), '/user/v1/models')
  assert.equal(app.fetch('/moontown/api/agent/chat'), '/moontown/api/agent/chat')
  assert.equal(app.fetch('https://other.test/api'), 'https://other.test/api')
  const link = new app.Element()
  link.setAttribute('href', '/api/mooncode/sessions/one/export')
  assert.equal(link.getAttribute('href'), 'https://example.test/moondesk/api/mooncode/sessions/one/export')
})

test('standalone build leaves root-mounted requests unchanged', () => {
  const app = load('/platform-base.js')
  assert.equal(app.fetch('/api/mooncode/chat'), '/api/mooncode/chat')
  assert.equal(new app.WebSocket('wss://example.test/ws').url, 'wss://example.test/ws')
})
