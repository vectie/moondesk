import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'
import { JSDOM } from 'jsdom'
import { tooltipPosition, dismissPopup } from './quiet-controls-runtime.js'

test('tooltips stay inside narrow viewports and flip above a bottom control', () => {
  const viewport = { width: 375, height: 740 }
  const size = { width: 240, height: 40 }
  assert.deepEqual(tooltipPosition({ left: 0, top: 5, bottom: 49, width: 44 }, size, viewport), { left: 8, top: 57 })
  assert.deepEqual(tooltipPosition({ left: 330, top: 690, bottom: 734, width: 44 }, size, viewport), { left: 127, top: 642 })
})

test('Escape can return to a disclosure trigger while an outside dismissal leaves focus alone', () => {
  let focused = 0
  const summary = { focus() { focused++ } }
  const panel = { tagName: 'DETAILS', open: true, dataset: {}, querySelector: () => summary }
  dismissPopup(panel, { document: {}, restoreFocus: true })
  assert.equal(panel.open, false)
  assert.equal(focused, 1)
  panel.open = true
  dismissPopup(panel, { document: {} })
  assert.equal(panel.open, false)
  assert.equal(focused, 1)
})

test('typed drawers dismiss through their existing close action', () => {
  let closed = 0
  let focused = 0
  const trigger = { focus() { focused++ } }
  const close = { dataset: {}, click() { closed++; assert.equal(this.dataset.popupRestoreFocus, 'true') } }
  const panel = { tagName: 'SECTION', dataset: { popupTrigger: '.trigger' }, querySelector: () => close }
  dismissPopup(panel, { document: { querySelector: () => trigger }, restoreFocus: true })
  assert.equal(closed, 1)
  assert.equal(focused, 1)
  assert.equal(close.dataset.popupRestoreFocus, undefined)
})

test('outside dismissal tells typed close handlers to keep focus at the clicked destination', () => {
  let toggles = 0
  const close = { dataset: {}, click() { toggles++; assert.equal(this.dataset.popupRestoreFocus, 'false') } }
  const panel = { tagName: 'SECTION', dataset: {}, querySelector: () => close }
  dismissPopup(panel, { document: {} })
  dismissPopup(panel, { document: {} })
  assert.equal(toggles, 1)
  assert.equal(close.dataset.popupRestoreFocus, undefined)
})

test('switching controls for the same drawer does not dismiss it before activation', async () => {
  const dom = new JSDOM(`<button id="first" aria-controls="inspector">First</button><button id="second" aria-controls="inspector">Second</button><button id="outside">Outside</button>
    <aside id="inspector" data-popup="inspector" data-popup-focus-dismiss="false" data-popup-trigger="#first"><button data-popup-dismiss>Close</button><h2>First</h2></aside>`, { runScripts: 'outside-only', pretendToBeVisual: true })
  try {
    const { window } = dom
    const doc = window.document
    window.HTMLElement.prototype.getClientRects = () => [{ width: 100, height: 40 }]
    let dismissed = 0
    doc.querySelector('[data-popup-dismiss]').onclick = () => { dismissed++; doc.querySelector('aside').remove() }
    doc.getElementById('second').onclick = () => { doc.querySelector('h2').textContent = 'Second' }
    window.eval(readFileSync(new URL('./quiet-controls-runtime.js', import.meta.url), 'utf8').replaceAll('export ', ''))
    const second = doc.getElementById('second')
    second.dispatchEvent(new window.Event('pointerdown', { bubbles: true }))
    second.focus()
    second.click()
    await new Promise(resolve => setTimeout(resolve, 0))
    assert.equal(dismissed, 0)
    assert.equal(doc.querySelector('h2').textContent, 'Second')
    // A reconciled view may briefly restore focus to its main container.
    // An attached inspector stays open until an explicit outside click/Escape.
    doc.getElementById('outside').focus()
    assert.equal(dismissed, 0)
    doc.getElementById('outside').dispatchEvent(new window.Event('pointerdown', { bubbles: true }))
    assert.equal(dismissed, 1)
  } finally { dom.window.close() }
})
