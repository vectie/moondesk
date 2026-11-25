import assert from 'node:assert/strict'
import fs from 'node:fs'
import test from 'node:test'
import { JSDOM } from 'jsdom'
import { isEmbeddedInHost, syncModeIndicator } from './workspace-motion-runtime.js'

test('embedded detection identifies standalone vs cross-origin iframe hosts safely', () => {
  const standalone = {}
  standalone.self = standalone
  standalone.top = standalone
  assert.equal(isEmbeddedInHost(standalone), false)

  const embedded = { self: {}, top: {} }
  assert.equal(isEmbeddedInHost(embedded), true)

  const crossOrigin = {
    get self() { return {} },
    get top() { throw new Error('SecurityError') },
  }
  assert.equal(isEmbeddedInHost(crossOrigin), true)
})

test('mode indicator aligns smoothly with the active mode button', () => {
  const dom = new JSDOM(`
    <header class="title-bar">
      <div class="workspace-mode-toggle">
        <button class="mode-button">Desk</button>
        <button class="mode-button active">Wiki</button>
        <button class="mode-button">Code</button>
      </div>
    </header>
  `)
  const toggle = dom.window.document.querySelector('.workspace-mode-toggle')
  const active = toggle.querySelector('.mode-button.active')
  toggle.getBoundingClientRect = () => ({ left: 100, width: 240 })
  active.getBoundingClientRect = () => ({ left: 176, width: 64 })

  assert.equal(syncModeIndicator(dom.window.document), true)
  const indicator = toggle.querySelector('.md-mode-indicator')
  assert.ok(indicator)
  assert.equal(indicator.style.width, '64px')
  assert.equal(indicator.style.transform, 'translateX(76px)')
  assert.equal(toggle.dataset.indicatorReady, 'true')
})

test('moondesk-motion.css enforces reduced-motion safety and avoids smooth scrolling on editors', () => {
  const css = fs.readFileSync(new URL('./styles/moondesk-motion.css', import.meta.url), 'utf8')
  assert.match(css, /prefers-reduced-motion:\s*reduce/)
  assert.match(css, /html\[data-embedded="moonproj"\]/)
  assert.doesNotMatch(css, /scroll-behavior:\s*smooth/)
})

test('moondesk-code-clean.css floats composer status without resizing and keeps solid layers', () => {
  const css = fs.readFileSync(new URL('./styles/moondesk-code-clean.css', import.meta.url), 'utf8')
  assert.match(css, /\.mooncode-composer \.mooncode-composer-status[\s\S]*position:\s*absolute/)
  assert.match(css, /\.code-workbench-heading[\s\S]*z-index:\s*20/)
  assert.match(css, /prefers-reduced-motion:\s*reduce/)
  assert.doesNotMatch(css, /scroll-behavior:\s*smooth/)
})
