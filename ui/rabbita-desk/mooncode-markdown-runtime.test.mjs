import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { bookReference, installMoonCodeMarkdownRuntime } from './mooncode-markdown-runtime.js'

test('Book references preserve workspace, directory and ordinary source formats', () => {
  const context = { workspace: 'book-research', path: 'wiki/02-presentation/index.md' }
  for (const [source, expected, activity] of [
    ['speaker-notes.md', 'wiki/02-presentation/speaker-notes.md', 'wiki'],
    ['../01-proposal/proposal.md', 'wiki/01-proposal/proposal.md', 'wiki'],
    ['slides/pages/01.page', 'wiki/02-presentation/slides/pages/01.page', 'code'],
  ]) {
    const url = new URL(bookReference(source, context), 'http://localhost:4281')
    assert.equal(url.searchParams.get('workspace'), 'book-research')
    assert.equal(url.searchParams.get('path'), expected)
    assert.equal(url.searchParams.get('activity'), activity)
  }
  assert.equal(bookReference('../../../escape.md', context), '')
  assert.equal(bookReference('%2e%2e/%2e%2e/%2e%2e/escape.md', context), '')
  assert.equal(bookReference('javascript:alert(1)', context), '')
  assert.equal(bookReference('//example.com/x', context), '')
  assert.equal(bookReference('x.md', {}), '')
})

test('installed renderer makes Book links clickable and coalesces live previews', async () => {
  const dom = new JSDOM('<div id="app"><div data-testid="mooncode-markdown-source" data-book-workspace="book-research" data-book-path="wiki/index.md"></div></div>', { url: 'http://localhost:4281' })
  const previous = new Map()
  for (const name of ['document', 'HTMLElement', 'Element', 'MutationObserver']) {
    previous.set(name, Object.getOwnPropertyDescriptor(globalThis, name))
    Object.defineProperty(globalThis, name, { configurable: true, value: dom.window[name] })
  }
  try {
    const source = document.querySelector('[data-testid]')
    source.textContent = '[阶段](02-presentation/index.md)\n\n![图](figures/theory.png)\n\n![外部](https://example.com/tracker.png)\n\n[危险](javascript:alert(1))'
    installMoonCodeMarkdownRuntime()
    const link = source.shadowRoot.querySelector('a')
    assert.equal(link.target, '_self')
    assert.equal(new URL(link.href).searchParams.get('path'), 'wiki/02-presentation/index.md')
    assert.equal(source.shadowRoot.querySelectorAll('img').length, 1)
    assert.match(source.shadowRoot.querySelector('img').src, /\/api\/workspaces\/book-research\/raw\?path=wiki%2Ffigures%2Ftheory.png/)
    assert.equal(source.shadowRoot.querySelectorAll('a').length, 1)
    const live = document.createElement('section')
    live.className = 'markdown-live-preview'
    const draft = document.createElement('div')
    draft.dataset.testid = 'mooncode-markdown-source'
    live.append(draft)
    document.getElementById('app').append(live)
    for (let i = 0; i < 20; i++) draft.textContent = `# Draft ${i}`
    await new Promise(resolve => setTimeout(resolve, 30))
    assert.equal(draft.shadowRoot, null)
    await new Promise(resolve => setTimeout(resolve, 180))
    assert.equal(draft.shadowRoot.querySelector('h1').textContent, 'Draft 19')
  } finally {
    dom.window.close()
    for (const [name, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
})
