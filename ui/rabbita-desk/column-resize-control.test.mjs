import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { createColumnResizeControl } from './column-resize-control.js'

test('horizontal dividers drag vertically, use up/down keys, and expose height reset', () => {
  const dom = new JSDOM('<main></main>', { url: 'http://localhost/' })
  const { window } = dom, doc = window.document
  let height = 120, frame, saves = 0
  window.requestAnimationFrame = callback => { frame = callback; return 1 }
  window.cancelAnimationFrame = () => { frame = null }
  window.HTMLElement.prototype.setPointerCapture = () => {}
  const control = createColumnResizeControl(doc, {
    id: 'rows', label: 'Resize rows', controls: 'test-pane', orientation: () => 'horizontal',
    bounds: () => [60, 300], value: () => height, change: value => { height = value }, reset: () => { height = 120 }, persist: () => saves++,
    rect: () => ({ left: 0, y: height, width: 500 }),
  })
  try {
    const handle = doc.querySelector('[role="separator"]')
    assert.equal(handle.getAttribute('aria-orientation'), 'horizontal')
    const pointer = (type, y) => {
      const event = new window.Event(type, { bubbles: true, cancelable: true })
      Object.assign(event, { clientX: 250, clientY: y, pointerId: 1, button: 0 })
      handle.dispatchEvent(event)
    }
    pointer('pointerdown', 120); pointer('pointermove', 180); frame(); pointer('pointerup', 180)
    assert.equal(height, 180)
    assert.equal(saves, 1)
    handle.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowUp', cancelable: true }))
    assert.equal(height, 164)
    handle.click(); handle.click() // First post-drag click is consumed.
    const buttons = doc.querySelectorAll('button')
    assert.equal(buttons[1].textContent, 'Taller')
    buttons[1].click()
    assert.equal(height, 196)
    buttons[2].click()
    assert.equal(height, 120)
    assert.equal(handle.style.width, '500px')
    assert.equal(doc.body.classList.contains('is-resizing-workspace-row'), false)
  } finally { control.dispose(); dom.window.close() }
})
