import assert from 'node:assert/strict'
import test from 'node:test'
import { renderWithDOM } from './test-dom-harness.mjs'

test('DOM projection preserves real node semantics and restores the host realm', () => {
  const originalDocument = Object.getOwnPropertyDescriptor(globalThis, 'document')
  const originalFetch = globalThis.fetch
  const markup = renderWithDOM(id => {
    const root = document.getElementById(id)
    const input = document.createElement('input')
    input.value = 'live value'
    input.checked = true
    root.append(input)
    assert.equal(input.value, 'live value')
    assert.equal(input.checked, true)
    const label = document.createElement('p')
    label.textContent = 'A < B & C'
    root.append(label)
    root.append(document.createElementNS('http://www.w3.org/2000/svg', 'svg'))
  })
  assert.match(markup, /A &lt; B &amp; C/)
  assert.match(markup, /value="live value"/)
  assert.match(markup, / checked/)
  assert.match(markup, /<svg/)
  assert.deepEqual(Object.getOwnPropertyDescriptor(globalThis, 'document'), originalDocument)
  assert.equal(globalThis.fetch, originalFetch)
})

test('DOM projection restores globals after failure and denies network calls', () => {
  const previous = Object.getOwnPropertyDescriptor(globalThis, 'window')
  const originalFetch = globalThis.fetch
  assert.throws(() => renderWithDOM(() => fetch('http://localhost.test/forbidden')), /must not make network requests/)
  assert.deepEqual(Object.getOwnPropertyDescriptor(globalThis, 'window'), previous)
  assert.equal(globalThis.fetch, originalFetch)
})

test('closing the projection cancels pending frames and timers', async () => {
  let effects = 0
  renderWithDOM(() => {
    window.requestAnimationFrame(() => { effects++ })
    window.setTimeout(() => { effects++ }, 0)
  })
  await new Promise(resolve => setTimeout(resolve, 30))
  assert.equal(effects, 0)
})

test('Rabbita normalization omits only identified scaffolding and retains authored empty elements and comments', () => {
  const markup = renderWithDOM(id => {
    const root = document.getElementById(id)
    root.innerHTML = '<div></div>'
    root.append(document.createComment('start'))
    root.insertAdjacentHTML('beforeend', '<div></div><!--start--><details open></details>')
    root.append(document.createComment('end'))
  }, true)
  assert.equal(markup, '<div></div><!--start--><details open></details>')
})

test('Rabbita normalization fails visibly when its bootstrap contract changes', () => {
  assert.throws(() => renderWithDOM(id => {
    document.getElementById(id).append(document.createElement('p'))
  }, true), /Unsupported Rabbita mount bootstrap/)
})

test('canonical notation never rewrites authored text that resembles attributes', () => {
  const text = 'literal open="" href="it\'s" < & >'
  const markup = renderWithDOM(id => {
    const p = document.createElement('p')
    p.textContent = text
    p.setAttribute('data-label', "it's")
    document.getElementById(id).append(p)
  })
  assert.equal(markup, '<p data-label="it&#39;s">literal open="" href="it\'s" &lt; &amp; &gt;</p>')
})

test('authored template content and inactive scripts remain intact without execution', () => {
  const markup = renderWithDOM(id => {
    document.getElementById(id).innerHTML = '<template><b>keep &amp; preserve</b></template><script>globalThis.__deskProjectionScriptExecuted = true</script>'
  })
  assert.equal(markup, '<template><b>keep &amp; preserve</b></template><script>globalThis.__deskProjectionScriptExecuted = true</script>')
  assert.equal(globalThis.__deskProjectionScriptExecuted, undefined)
})

test('live textarea values replace multi-node defaults without losing text', () => {
  const markup = renderWithDOM(id => {
    const textarea = document.createElement('textarea')
    textarea.append(document.createTextNode('old '), document.createTextNode('default'))
    textarea.value = 'live < & > value'
    document.getElementById(id).append(textarea)
  })
  assert.equal(markup, '<textarea>live &lt; &amp; &gt; value</textarea>')
})
