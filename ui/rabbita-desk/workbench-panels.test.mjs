import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'
import { JSDOM } from 'jsdom'
import { iconMarkup, setIconButton } from './ui-icons.js'

const read = file => readFileSync(new URL(file, import.meta.url), 'utf8')
const tick = () => new Promise(resolve => setTimeout(resolve, 0))
function runtime(file, exports, markup = '<main></main>', setup = () => {}) {
  const dom = new JSDOM(markup, { url: 'http://localhost/', runScripts: 'outside-only' })
  const { window } = dom
  Object.assign(window, { iconMarkup, setIconButton, requestAnimationFrame: () => {}, ResizeObserver: class { observe() {} } })
  setup(window)
  let source = read(file).replace(/^import .*$/gm, '').replace(/^export /gm, '')
  source = source.slice(0, source.lastIndexOf("if (typeof document !== 'undefined')"))
  window.eval(read('./ui-locale.js').replace(/^export /gm, '') + '\n' + source + `\nwindow.api = {${exports}}`)
  return { dom, window, api: window.api }
}

test('preview actions follow the opened page rather than an unsubmitted address', () => {
  const markup = `<main data-initial-url="about:blank"><section data-developer-tool-panel="browser">
    <button data-developer-browser-action="back"></button><button data-developer-browser-action="forward"></button><button data-developer-browser-action="reload"></button>
    <form data-developer-browser-address-form><input data-testid="mooncode-developer-browser-address"><button type="submit">Go</button></form>
    <button data-developer-browser-action="open-external"></button><button data-pick-code-element></button>
    <iframe data-testid="mooncode-developer-browser-frame" src="about:blank"></iframe><p data-testid="mooncode-developer-browser-status"></p></section></main>`
  const h = runtime('./mooncode-developer-tools-runtime.js', 'installBrowser', markup)
  try {
    const root = h.window.document.querySelector('main'), control = name => root.querySelector(`[data-developer-browser-action="${name}"]`)
    h.api.installBrowser(root)
    const address = root.querySelector('input'), go = root.querySelector('form button'), picker = root.querySelector('[data-pick-code-element]')
    for (const button of [go, picker, control('reload'), control('open-external')]) assert.equal(button.disabled, true)
    address.value = '/preview/report.html'; address.dispatchEvent(new h.window.Event('input'))
    assert.equal(go.disabled, false); assert.equal(control('open-external').disabled, true)
    root.querySelector('form').dispatchEvent(new h.window.Event('submit', { bubbles: true, cancelable: true }))
    assert.equal(control('reload').disabled, false); assert.equal(picker.disabled, false)
    let opened; h.window.open = url => { opened = url }
    address.value = 'https://example.com/unsubmitted'; address.dispatchEvent(new h.window.Event('input'))
    control('open-external').click(); assert.equal(opened, 'http://localhost/preview/report.html')
    root.querySelector('form').dispatchEvent(new h.window.Event('submit', { bubbles: true, cancelable: true }))
    assert.equal(picker.disabled, true)
    control('back').click(); assert.equal(picker.disabled, false)
    control('back').click(); assert.equal(control('reload').disabled, true)
    assert.equal(root.querySelector('section').dataset.hasPage, 'false')
  } finally { h.dom.window.close() }
})

test('workbench tabs activate directly and never expose selection actions without a selection', () => {
  const dom = new JSDOM(`<main data-workbench-view="compare" data-workbench-focus="split"><div class="code-workbench-tabs"><button data-workbench-view="source">Files</button><button data-workbench-view="terminal">Terminal</button></div><button data-workbench-action="selection"></button><div class="code-workbench-work"></div></main>`, { url: 'http://localhost/', runScripts: 'outside-only', pretendToBeVisual: true })
  try {
    dom.window.eval(read('./code-workbench-runtime.js').replace(/^export /gm, '') + '\nwindow.syncTabs = syncPanelTabs')
    const surface = dom.window.document.querySelector('main')
    surface.querySelector('button').disabled = true
    dom.window.syncTabs(surface)
    const source = surface.querySelector('[data-workbench-view="source"]')
    source.click()
    assert.equal(surface.dataset.workbenchView, 'source')
    assert.equal(source.getAttribute('aria-pressed'), 'true')
    assert.equal(source.getAttribute('role'), 'button')
    assert.equal(source.disabled, false)
    assert.equal(surface.querySelector('[data-workbench-action="selection"]').disabled, true)
  } finally { dom.window.close() }
})

test('terminal loading, failure and recovery stay distinct, and selection/search require actual inputs', async () => {
  const requests = []
  const h = runtime('./mooncode-terminal-runtime.js', 'createBook, addSession, select, syncControls', '<main></main>', window => {
    class FakeTerminal {
      constructor() { this.selection = ''; this.cols = 80; this.rows = 24 }
      loadAddon() {}
      open(host) { host.append(window.document.createElement('textarea')) }
      onData() {}
      onSelectionChange(callback) { this.selected = callback }
      attachCustomKeyEventHandler() {}
      getSelection() { return this.selection }
      write(_data, done) { done?.() }
      focus() {}
    }
    Object.assign(window, { Terminal: FakeTerminal, FitAddon: class {}, SearchAddon: class {}, setInterval: () => 1 })
    window.fetch = () => new Promise(resolve => requests.push(resolve))
  })
  try {
    const book = h.api.createBook('test-book'); h.window.document.querySelector('main').append(book.shell)
    assert.equal(book.empty.hidden, true); assert.equal(book.refresh.disabled, true)
    requests[0]({ ok: false, status: 503, json: async () => ({ error: 'Disconnected' }) }); await tick()
    assert.equal(book.empty.hidden, true); assert.equal(book.status.textContent, 'Disconnected')
    book.refresh.click(); requests[1]({ ok: true, json: async () => ({ sessions: [] }) }); await tick()
    assert.equal(book.empty.hidden, false); assert.equal(book.status.textContent, '')
    const session = h.api.addSession(book, { id: 'one', title: 'My run', directory: '', status: -1 })
    h.api.select(book, 'one', false)
    assert.equal(book.send.disabled, true); assert.equal(book.previous.disabled, true)
    session.term.selection = 'read-only output'; session.term.selected()
    assert.equal(book.send.disabled, false)
    book.search.value = 'output'; book.search.dispatchEvent(new h.window.Event('input'))
    assert.equal(book.previous.disabled, false)
    session.status = 0; h.api.syncControls(book); assert.equal(book.interrupt.disabled, true)
  } finally { h.dom.window.close() }
})
