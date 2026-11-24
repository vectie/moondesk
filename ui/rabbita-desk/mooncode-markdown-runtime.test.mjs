import test from 'node:test'
import assert from 'node:assert/strict'
import { JSDOM } from 'jsdom'
import { readFileSync } from 'node:fs'
import { bookReference, markdownLineOffset, installMoonCodeMarkdownRuntime } from './mooncode-markdown-runtime.js'

test('heading navigation offsets keep the original CRLF and complete large draft', () => {
  const text = '# First\r\n' + 'unchanged '.repeat(43000) + '\r\n## 证据\r\nend'
  assert.equal(markdownLineOffset(text, 2), text.indexOf('## 证据'))
  assert.equal(markdownLineOffset(text, 0), 0)
  assert.equal(markdownLineOffset(text, 99), text.length)
  const styles = readFileSync(new URL('./styles/type-hierarchy.css', import.meta.url), 'utf8')
  assert.match(styles, /\.wiki-document-viewer \.markdown-editor \{[^}]*height: 100%;[^}]*min-height: 0;/)
  assert.match(styles, /\.wiki-document-viewer \.markdown-live-preview \{[^}]*overflow: auto;/)
})

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
    source.className = 'book-markdown-source'
    source.textContent = '# 论文\n\n[证据](#证据)\n\n## 证据\n\n```md\n## Not a section\n```\n\n## 证据\n\n> ## Quoted heading'
    await new Promise(resolve => setTimeout(resolve, 10))
    const root = source.shadowRoot
    const sections = root.querySelector('select[aria-label="Jump to section"]')
    assert.equal(sections.options.length, 3)
    assert.deepEqual([...sections.options].map(option => option.value), ['论文', '证据', '证据-2'])
    const linkEvent = new dom.window.MouseEvent('click', { bubbles: true, cancelable: true })
    root.querySelector('a').dispatchEvent(linkEvent)
    assert.equal(linkEvent.defaultPrevented, true)
    assert.equal(root.activeElement.id, '证据')
    assert.equal(sections.value, '证据')
    source.textContent = '[Edit Word](/?activity=code&workspace=book-research&path=wiki/proposal.docx)'
    await new Promise(resolve => setTimeout(resolve, 10))
    assert.equal(source.shadowRoot.querySelector('a').target, '_self')
    const edit = document.createElement('section')
    edit.className = 'markdown-edit-surface'
    const editor = document.createElement('textarea'); editor.className = 'markdown-editor'
    const draftText = '# First\r\n' + 'Complete draft '.repeat(31000) + '\r\n## Last\nTail'
    editor.value = draftText
    edit.append(editor)
    document.getElementById('app').append(edit)
    const live = document.createElement('section')
    live.className = 'markdown-live-preview'
    const draft = document.createElement('div')
    draft.dataset.testid = 'mooncode-markdown-source'
    live.append(draft)
    edit.append(live)
    draft.className = 'book-markdown-source'
    for (let i = 0; i < 20; i++) draft.textContent = `# Draft ${i}`
    await new Promise(resolve => setTimeout(resolve, 30))
    assert.equal(draft.shadowRoot, null)
    await new Promise(resolve => setTimeout(resolve, 180))
    assert.equal(draft.shadowRoot.querySelector('h1').textContent, 'Draft 19')
    draft.textContent = editor.value
    await new Promise(resolve => setTimeout(resolve, 180))
    const jump = draft.shadowRoot.querySelector('select')
    const normalized = editor.value
    jump.value = 'last'
    jump.dispatchEvent(new dom.window.Event('change', { bubbles: true }))
    assert.equal(editor.selectionStart, normalized.indexOf('## Last'))
    assert.equal(editor.value, normalized)
    assert.equal(editor.value.length, normalized.length)
    assert.equal(document.activeElement, editor)
    draft.textContent = '# Only heading'
    await new Promise(resolve => setTimeout(resolve, 180))
    assert.equal(draft.shadowRoot.querySelector('nav'), null)
  } finally {
    dom.window.close()
    for (const [name, descriptor] of previous) {
      if (descriptor) Object.defineProperty(globalThis, name, descriptor)
      else delete globalThis[name]
    }
  }
})
