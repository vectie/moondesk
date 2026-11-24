import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { chatColumn, columnSizes, createWorkbenchResizing } from './code-workbench-resize.js'

function fixture() {
  const dom = new JSDOM('<main class="code-main" data-navigation="open"><aside class="mooncode-rail" id="code-chat-navigation"></aside><section class="mooncode-center" data-workbench-focus="split"><div class="code-workbench"><div class="mooncode-chat-surface"><textarea>Keep this draft</textarea></div><aside class="code-workbench-work" id="code-workbench-panel"></aside></div></section></main>', { url: 'http://localhost/' })
  const { window } = dom, doc = window.document
  let width = 1280, frame = null, writes = 0, disconnected = false
  const shell = doc.querySelector('main'), surface = doc.querySelector('section')
  Object.defineProperty(window, 'innerWidth', { value: 1280 })
  Object.defineProperty(shell, 'clientWidth', { get: () => width })
  Object.defineProperty(surface, 'clientWidth', { get: () => width - (shell.dataset.navigation === 'open' ? parseFloat(shell.style.getPropertyValue('--code-navigation-width')) || 240 : 0) })
  doc.querySelector('.mooncode-rail').getBoundingClientRect = () => ({ top: 44, right: parseFloat(shell.style.getPropertyValue('--code-navigation-width')) || 240, height: 676 })
  doc.querySelector('.mooncode-chat-surface').getBoundingClientRect = () => ({ top: 85, right: 750, height: 635 })
  window.requestAnimationFrame = callback => { frame = callback; return 1 }
  window.cancelAnimationFrame = () => { frame = null }
  window.ResizeObserver = class { observe() {} disconnect() { disconnected = true } }
  window.HTMLElement.prototype.setPointerCapture = function () {}
  const controller = createWorkbenchResizing(surface, () => writes++)
  const handle = kind => doc.querySelector(`[data-column-resize="${kind}"]`)
  const pointer = (target, type, x) => {
    const event = new window.Event(type, { bubbles: true, cancelable: true })
    Object.assign(event, { pointerId: 1, button: 0, clientX: x })
    target.dispatchEvent(event)
  }
  const key = (target, value, shiftKey = false) => target.dispatchEvent(new window.KeyboardEvent('keydown', { key: value, shiftKey, bubbles: true, cancelable: true }))
  return { dom, doc, window, shell, surface, controller, handle, pointer, key,
    flush: () => { const callback = frame; frame = null; callback?.() },
    resize: value => { width = value; controller.refresh() },
    get writes() { return writes }, get disconnected() { return disconnected } }
}

test('column bounds leave both working panels readable and adapt to available space', () => {
  assert.deepEqual(columnSizes(1280), { navigation: 240, navMax: 420 })
  assert.equal(columnSizes(1100, 999).navigation, 420)
  assert.equal(columnSizes(700, 999).navigation, 180)
  for (const width of [800, 900, 1040, 1400]) {
    for (const fraction of [0.01, 0.49, 0.99]) {
      const chat = chatColumn(width, fraction)
      assert.ok(chat >= 360)
      assert.ok(width - chat >= 360)
    }
  }
})

test('dragging coalesces frames, persists only on release, and preserves the draft', () => {
  const h = fixture()
  try {
    const input = h.doc.querySelector('textarea'), navigation = h.handle('navigation')
    input.setSelectionRange(2, 6)
    h.pointer(navigation, 'pointerdown', 240)
    h.pointer(navigation, 'pointermove', 270)
    h.pointer(navigation, 'pointermove', 300)
    assert.equal(h.shell.style.getPropertyValue('--code-navigation-width'), '240px')
    h.flush()
    assert.equal(h.shell.style.getPropertyValue('--code-navigation-width'), '300px')
    assert.equal(h.window.localStorage.getItem('moondesk.code-columns'), null)
    h.pointer(navigation, 'pointerup', 300)
    assert.equal(JSON.parse(h.window.localStorage.getItem('moondesk.code-columns')).navigation, 300)
    navigation.click() // A release following a drag must not open a menu.
    assert.equal(h.doc.querySelector('details').open, false)
    assert.equal(input.value, 'Keep this draft')
    assert.equal(input.selectionStart, 2)
    assert.equal(input.selectionEnd, 6)
    assert.equal(h.doc.body.classList.contains('is-resizing-workspace'), false)
  } finally { h.controller.dispose(); h.dom.window.close() }
})

test('split resizing supports keyboard bounds, click-only alternatives, reset and reload', () => {
  const h = fixture()
  try {
    const chat = h.handle('chat'), initial = Number(chat.getAttribute('aria-valuenow'))
    h.key(chat, 'ArrowRight')
    assert.equal(Number(chat.getAttribute('aria-valuenow')), initial + 16)
    h.key(chat, 'Home')
    assert.equal(chat.getAttribute('aria-valuenow'), '360')
    h.key(chat, 'End')
    assert.equal(chat.getAttribute('aria-valuenow'), '680')
    h.pointer(chat, 'pointerdown', 680)
    h.pointer(chat, 'pointermove', 600)
    h.flush()
    h.pointer(chat, 'pointerup', 600)
    assert.equal(chat.getAttribute('aria-valuenow'), '600')
    const stored = JSON.parse(h.window.localStorage.getItem('moondesk.code-columns'))
    assert.equal(chatColumn(1040, stored.fraction), 600)
    chat.click() // Swallow the post-drag click.
    chat.click()
    const menu = h.doc.querySelectorAll('details')[1]
    assert.equal(menu.open, true)
    menu.querySelector('button').click()
    assert.equal(chat.getAttribute('aria-valuenow'), '568')
    assert.equal(menu.open, false)
    chat.click()
    menu.querySelectorAll('button')[2].click()
    assert.equal(chat.getAttribute('aria-valuenow'), String(chatColumn(1040)))
    h.controller.dispose()
    const reloaded = createWorkbenchResizing(h.surface)
    assert.equal(h.handle('chat').getAttribute('aria-valuenow'), String(chatColumn(1040)))
    reloaded.dispose()
  } finally { h.dom.window.close() }
})

test('narrow containers switch panes, reopening space restores split, and cancelled drags roll back', () => {
  const h = fixture()
  try {
    assert.equal(h.surface.dataset.columnLayout, 'split')
    h.resize(1000)
    assert.equal(h.surface.dataset.columnLayout, 'single')
    h.shell.dataset.navigation = 'closed'
    h.controller.refresh()
    assert.equal(h.surface.dataset.columnLayout, 'split')
    const chat = h.handle('chat'), initial = chat.getAttribute('aria-valuenow')
    h.pointer(chat, 'pointerdown', 500)
    h.pointer(chat, 'pointermove', 400)
    h.flush()
    assert.notEqual(chat.getAttribute('aria-valuenow'), initial)
    h.key(chat, 'Escape')
    assert.equal(chat.getAttribute('aria-valuenow'), initial)
    assert.equal(h.window.localStorage.getItem('moondesk.code-columns'), null)
    assert.equal(chat.parentNode, h.doc.body)
    assert.equal(h.shell.querySelectorAll('[role="separator"]').length, 0)
    h.controller.dispose()
    assert.equal(h.disconnected, true)
    assert.equal(h.doc.querySelectorAll('.workspace-column-resizer, .code-column-resize-menu').length, 0)
  } finally { h.dom.window.close() }
})
