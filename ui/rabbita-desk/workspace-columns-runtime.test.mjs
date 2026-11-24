import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { installWorkspaceColumns } from './workspace-columns-runtime.js'

test('reusing the main DOM node across all destinations never leaks dividers, widths, or menus', async () => {
  const dom = new JSDOM('<div id="app"><main></main></div>', { url: 'http://localhost/' })
  const { window } = dom, doc = window.document, main = doc.querySelector('main')
  window.ResizeObserver = class { observe() {} disconnect() {} }
  window.requestAnimationFrame = () => 1
  window.cancelAnimationFrame = () => {}
  Object.defineProperty(window, 'innerWidth', { value: 1280, writable: true })
  Object.defineProperty(main, 'clientWidth', { value: 1280 })
  Object.defineProperty(main, 'clientHeight', { value: 760 })
  const manager = installWorkspaceColumns(doc)
  const change = (className, html) => {
    main.className = className
    main.innerHTML = html
    for (const el of main.querySelectorAll('*')) {
      Object.defineProperty(el, 'clientWidth', { value: 1040, configurable: true })
      Object.defineProperty(el, 'clientHeight', { value: 760, configurable: true })
      el.getBoundingClientRect = () => ({ top: 44, left: 240, right: 600, bottom: 720, height: 676, width: 360 })
    }
    manager.refresh()
    assert.equal(main.querySelectorAll('[role="separator"]').length, 0)
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, doc.querySelectorAll('.code-column-resize-menu').length)
  }
  try {
    change('code-main', '<aside class="mooncode-rail"></aside><section class="mooncode-center"><div class="code-workbench"><div class="mooncode-chat-surface"><textarea class="mooncode-input">Keep my draft</textarea></div><aside class="code-workbench-work"></aside></div></section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, 2)
    change('pack-home-main', '<section class="pack-home-hero">Packs</section><section class="pack-home-empty">No packs</section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, 0)
    assert.equal(main.style.getPropertyValue('--code-navigation-width'), '')
    assert.equal(main.hasAttribute('data-resizable-columns'), false)
    change('flow-main', '<section class="flow-composer">Canvas</section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, 0)
    change('desk-main file-desk-main', '<aside class="desk-sidebar"></aside><section class="desk-browser"></section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, 1)
    assert.equal(main.style.getPropertyValue('--workspace-rail'), '240px')
    window.innerWidth = 375
    manager.refresh()
    const row = doc.querySelector('[data-column-resize="desk"]')
    assert.equal(row.getAttribute('aria-orientation'), 'horizontal')
    assert.equal(row.getAttribute('aria-label'), 'Resize book list height')
    assert.equal(main.style.getPropertyValue('--desk-sidebar-height'), '220px')
    row.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowDown', cancelable: true }))
    assert.equal(main.style.getPropertyValue('--desk-sidebar-height'), '236px')
    window.innerWidth = 1280
    manager.refresh()
    assert.equal(row.getAttribute('aria-orientation'), 'vertical')
    assert.equal(main.style.getPropertyValue('--workspace-rail'), '240px')
    change('desk-main wiki-focus-main', '<section class="wiki-focus-workspace"><aside class="wiki-chat"></aside><section class="wiki-document-viewer"></section></section>')
    assert.equal(doc.querySelector('[data-column-resize="book"]').getAttribute('aria-label'), 'Resize document chat')
    assert.equal(main.style.getPropertyValue('--workspace-rail'), '')
    change('pack-home-main', '<aside class="pack-inspector"><h2>Pack details</h2></aside>')
    const handle = doc.querySelector('[data-column-resize="packs"]'), inspector = main.querySelector('aside')
    assert.equal(inspector.style.getPropertyValue('--pack-inspector-width'), '380px')
    handle.dispatchEvent(new window.KeyboardEvent('keydown', { key: 'ArrowLeft', bubbles: true, cancelable: true }))
    assert.equal(inspector.style.getPropertyValue('--pack-inspector-width'), '396px')
    change('flow-main', '<section class="flow-composer">Canvas again</section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer, .code-column-resize-menu').length, 0)
    change('desk-main file-desk-main', '<aside class="desk-sidebar"></aside><section class="desk-browser"></section>')
    assert.equal(doc.querySelectorAll('.workspace-column-resizer').length, 1)
    main.className = 'flow-main'
    main.innerHTML = '<section>Flow after a renderer update</section>'
    await Promise.resolve() // Cleanup does not wait for the deferred layout frame.
    assert.equal(doc.querySelectorAll('.workspace-column-resizer, .code-column-resize-menu').length, 0)
  } finally { manager.dispose(); dom.window.close() }
})
