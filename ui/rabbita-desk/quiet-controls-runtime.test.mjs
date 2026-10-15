import assert from 'node:assert/strict'
import test from 'node:test'
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
