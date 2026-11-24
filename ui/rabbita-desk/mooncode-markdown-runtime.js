import { uiText } from './ui-locale.js'

let installed = false
const renderedSources = new WeakMap()
const previewTimers = new WeakMap()
const outlines = new WeakMap()

// Rabbita owns the light DOM. Rendering into a shadow root keeps Markdown
// enhancement from removing virtual-DOM children during the next chat update.
const markdownStyle = `
:host { display: block; white-space: normal; word-break: break-word; }
:host > :first-child { margin-top: 0; }
:host > :last-child { margin-bottom: 0; }
p, ul, ol, blockquote, table { margin: 0 0 12px; }
h1, h2, h3, h4, h5, h6 { margin: 16px 0 8px; line-height: 1.3; }
h1, h2, h3, h4, h5, h6 { scroll-margin-block-start: 64px; }
.document-sections { position: sticky; top: 0; z-index: 1; display: flex; align-items: center; gap: 8px; padding: 8px 0; margin-bottom: 12px; background: var(--bg-raised, #fff); color: var(--ink, #1f2937); font: var(--text-control, 13px)/1.4 var(--font-ui, system-ui); }
.document-sections select { min-width: 0; flex: 1; max-width: 100%; height: var(--control-height, 32px); border: 1px solid var(--line, #a7b1c2); border-radius: var(--radius-control, 6px); background: inherit; color: inherit; font: inherit; padding-inline: 8px; }
.document-sections select:focus-visible { outline: 2px solid var(--accent, #2563eb); outline-offset: 2px; }
@media (prefers-reduced-motion: reduce) { :host { scroll-behavior: auto; } }
h1 { font-size: 1.4em; } h2 { font-size: 1.25em; }
ul, ol { padding-left: 24px; } li + li { margin-top: 4px; }
blockquote { padding-left: 12px; border-left: 3px solid #a7b1c2; }
a { color: #2563eb; overflow-wrap: anywhere; }
a:focus-visible, button:focus-visible { outline: 2px solid #2563eb; outline-offset: 2px; }
img { max-width: 100%; height: auto; }
.mooncode-inline-code { font-family: ui-monospace, SFMono-Regular, monospace; font-size: .9em; }
.mooncode-code-block { max-width: 100%; overflow: auto; border-radius: 8px; background: #101827; color: #f8fafc; }
.mooncode-code-toolbar { display: flex; justify-content: space-between; padding: 6px 10px; }
.mooncode-copy-button { border: 0; border-radius: 4px; cursor: pointer; }
.mooncode-code-block pre { overflow: auto; margin: 0; padding: 10px; white-space: pre; }
table { border-collapse: collapse; display: block; overflow-x: auto; }
th, td { border: 1px solid #a7b1c2; padding: 4px 8px; }
`

// Resolve authored references against the document, never the server URL.
// The workspace file API remains responsible for realpath confinement.
export function bookReference(value, context) {
  if (!context?.workspace || !context?.path) return ''
  const href = String(value || '').trim()
  if (!href || /^[a-z][a-z0-9+.-]*:/i.test(href) || href.startsWith('/') || href.startsWith('#') || href.includes('\\')) return ''
  const [filename, fragment = ''] = href.split('#', 2)
  let decoded
  try { decoded = decodeURIComponent(filename) } catch { return '' }
  if (decoded.includes('?') || decoded.includes('\0') || decoded.includes('\\')) return ''
  const parts = context.path.split('/').slice(0, -1)
  for (const part of decoded.split('/')) {
    if (!part || part === '.') continue
    if (part === '..') { if (!parts.length) return ''; parts.pop() }
    else parts.push(part)
  }
  const path = parts.join('/')
  const query = new URLSearchParams({ workspace: context.workspace, path })
  if (/\.(?:png|jpe?g|gif|webp|svg)$/i.test(path)) return `/api/workspaces/${encodeURIComponent(context.workspace)}/raw?path=${encodeURIComponent(path)}`
  query.set('activity', /\.(?:pptd|page|json|ya?ml|txt)$/i.test(path) ? 'code' : 'wiki')
  return `/?${query}${fragment ? '#' + encodeURIComponent(fragment) : ''}`
}

function safeLink(value, context) {
  const href = String(value || '').trim()
  const reference = bookReference(href, context)
  if (reference) return reference
  if (context?.workspace && !/^[a-z][a-z0-9+.-]*:/i.test(href) && !href.startsWith('/') && !href.startsWith('#')) return ''
  if (href.startsWith('/') || href.startsWith('#') || href.startsWith('./') || href.startsWith('../')) return href
  try {
    const url = new URL(href)
    return ['http:', 'https:', 'mailto:'].includes(url.protocol) ? href : ''
  } catch {
    return ''
  }
}

function localBookRoute(href, context) {
  if (!href.startsWith('/?') || !context?.workspace) return false
  const query = new URL(href, 'http://book.local').searchParams
  return query.get('workspace') === context.workspace && ['wiki', 'code'].includes(query.get('activity')) && !!query.get('path')
}

function appendInline(parent, source, context) {
  let text = String(source || '')
  const token = /(`[^`\n]+`|\*\*[^*\n]+\*\*|~~[^~\n]+~~|!?\[[^\]\n]*\]\([^\s)]+\)|https?:\/\/[^\s<]+)/
  while (text) {
    const match = token.exec(text)
    if (!match) {
      parent.append(document.createTextNode(text))
      break
    }
    if (match.index > 0) parent.append(document.createTextNode(text.slice(0, match.index)))
    const value = match[0]
    if (value.startsWith('`')) {
      const code = document.createElement('code')
      code.className = 'mooncode-inline-code'
      code.textContent = value.slice(1, -1)
      parent.append(code)
    } else if (value.startsWith('**')) {
      const strong = document.createElement('strong')
      appendInline(strong, value.slice(2, -2), context)
      parent.append(strong)
    } else if (value.startsWith('~~')) {
      const deleted = document.createElement('del')
      appendInline(deleted, value.slice(2, -2), context)
      parent.append(deleted)
    } else if (value.startsWith('![')) {
      const parts = /^!\[([^\]]*)\]\(([^)]+)\)$/.exec(value)
      const href = bookReference(parts?.[2], context)
      if (href.startsWith('/api/workspaces/')) {
        const image = document.createElement('img')
        image.src = href
        image.alt = parts[1]
        image.loading = 'lazy'
        parent.append(image)
      } else parent.append(document.createTextNode(parts?.[1] || value))
    } else if (value.startsWith('[')) {
      const parts = /^\[([^\]]*)\]\(([^)]+)\)$/.exec(value)
      const href = safeLink(parts?.[2], context)
      if (href) {
        const link = document.createElement('a')
        link.href = href
        link.target = href.startsWith('#') || bookReference(parts?.[2], context) || localBookRoute(href, context) ? '_self' : '_blank'
        link.rel = 'noopener noreferrer'
        appendInline(link, parts[1], context)
        parent.append(link)
      } else {
        parent.append(document.createTextNode(parts?.[1] || value))
      }
    } else {
      const link = document.createElement('a')
      link.href = value
      link.target = '_blank'
      link.rel = 'noopener noreferrer'
      link.textContent = value
      parent.append(link)
    }
    text = text.slice(match.index + value.length)
  }
}

function copyText(value, button) {
  const copied = () => {
    button.textContent = 'Copied'
    button.setAttribute('aria-label', 'Copied code')
    setTimeout(() => {
      if (!button.isConnected) return
      button.textContent = 'Copy'
      button.setAttribute('aria-label', 'Copy code')
    }, 1600)
  }
  if (navigator.clipboard?.writeText) {
    void navigator.clipboard.writeText(value).then(copied).catch(() => {})
    return
  }
  const field = document.createElement('textarea')
  field.value = value
  field.style.position = 'fixed'
  field.style.opacity = '0'
  document.body.append(field)
  field.select()
  if (document.execCommand('copy')) copied()
  field.remove()
}

function codeBlock(language, content) {
  const wrapper = document.createElement('div')
  wrapper.className = 'mooncode-code-block'
  wrapper.dataset.testid = 'mooncode-code-block'
  const toolbar = document.createElement('div')
  toolbar.className = 'mooncode-code-toolbar'
  const label = document.createElement('span')
  label.textContent = language || 'Code'
  const copy = document.createElement('button')
  copy.type = 'button'
  copy.className = 'mooncode-copy-button'
  copy.dataset.testid = 'mooncode-copy-code'
  copy.setAttribute('aria-label', 'Copy code')
  copy.textContent = 'Copy'
  copy.addEventListener('click', () => copyText(content, copy))
  toolbar.append(label, copy)
  const pre = document.createElement('pre')
  const code = document.createElement('code')
  if (language) code.className = `language-${language}`
  code.textContent = content
  pre.append(code)
  wrapper.append(toolbar, pre)
  return wrapper
}

function isTableDivider(line) {
  const cells = line.trim().replace(/^\||\|$/g, '').split('|')
  return cells.length > 0 && cells.every(cell => /^\s*:?-{3,}:?\s*$/.test(cell))
}

function tableRow(line, cellTag, context) {
  const row = document.createElement('tr')
  for (const value of line.trim().replace(/^\||\|$/g, '').split('|')) {
    const cell = document.createElement(cellTag)
    appendInline(cell, value.trim(), context)
    row.append(cell)
  }
  return row
}

function startsBlock(lines, index) {
  const line = lines[index] || ''
  return line.trim() === '' ||
    /^\s*(```|~~~)/.test(line) ||
    /^#{1,6}\s+/.test(line) ||
    /^\s*>\s?/.test(line) ||
    /^\s*(?:[-+*]|\d+[.)])\s+/.test(line) ||
    /^\s*(?:---+|___+|\*\*\*+)\s*$/.test(line) ||
    (index + 1 < lines.length && line.includes('|') && isTableDivider(lines[index + 1]))
}

function renderBlocks(source, context) {
  const fragment = document.createDocumentFragment()
  const lines = String(source || '').replace(/\r\n?/g, '\n').split('\n')
  let index = 0
  while (index < lines.length) {
    const line = lines[index]
    if (line.trim() === '') {
      index += 1
      continue
    }
    const fence = /^\s*(```|~~~)\s*([^\s]*)\s*$/.exec(line)
    if (fence) {
      const content = []
      index += 1
      while (index < lines.length && !new RegExp(`^\\s*${fence[1]}`).test(lines[index])) {
        content.push(lines[index])
        index += 1
      }
      if (index < lines.length) index += 1
      fragment.append(codeBlock(fence[2], content.join('\n')))
      continue
    }
    const heading = /^(#{1,6})\s+(.+)$/.exec(line)
    if (heading) {
      const element = document.createElement(`h${heading[1].length}`)
      element.dataset.sourceLine = String(index)
      appendInline(element, heading[2], context)
      fragment.append(element)
      index += 1
      continue
    }
    if (/^\s*(?:---+|___+|\*\*\*+)\s*$/.test(line)) {
      fragment.append(document.createElement('hr'))
      index += 1
      continue
    }
    if (index + 1 < lines.length && line.includes('|') && isTableDivider(lines[index + 1])) {
      const table = document.createElement('table')
      const head = document.createElement('thead')
      const body = document.createElement('tbody')
      head.append(tableRow(line, 'th', context))
      index += 2
      while (index < lines.length && lines[index].includes('|') && lines[index].trim()) {
        body.append(tableRow(lines[index], 'td', context))
        index += 1
      }
      table.append(head, body)
      fragment.append(table)
      continue
    }
    if (/^\s*>\s?/.test(line)) {
      const quoted = []
      while (index < lines.length && /^\s*>\s?/.test(lines[index])) {
        quoted.push(lines[index].replace(/^\s*>\s?/, ''))
        index += 1
      }
      const quote = document.createElement('blockquote')
      quote.append(renderBlocks(quoted.join('\n'), context))
      fragment.append(quote)
      continue
    }
    const list = /^\s*((?:[-+*])|(?:\d+[.)]))\s+(.+)$/.exec(line)
    if (list) {
      const ordered = /^\d/.test(list[1])
      const element = document.createElement(ordered ? 'ol' : 'ul')
      while (index < lines.length) {
        const item = /^\s*((?:[-+*])|(?:\d+[.)]))\s+(.+)$/.exec(lines[index])
        if (!item || /^\d/.test(item[1]) !== ordered) break
        const row = document.createElement('li')
        const task = /^\[([ xX-])\]\s+/.exec(item[2])
        if (task) {
          const marker = document.createElement('span')
          marker.className = 'mooncode-task-marker'
          marker.textContent = task[1].toLowerCase() === 'x' ? '[x] ' : task[1] === '-' ? '[-] ' : '[ ] '
          row.append(marker)
          appendInline(row, item[2].slice(task[0].length), context)
        } else {
          appendInline(row, item[2], context)
        }
        element.append(row)
        index += 1
      }
      fragment.append(element)
      continue
    }
    const paragraph = [line.trim()]
    index += 1
    while (index < lines.length && !startsBlock(lines, index)) {
      paragraph.push(lines[index].trim())
      index += 1
    }
    const element = document.createElement('p')
    appendInline(element, paragraph.join(' '), context)
    fragment.append(element)
  }
  return fragment
}

// Heading identities belong to this rendered document, not to another parser
// or persisted outline. Duplicate titles remain individually navigable.
function headingIDs(headings) {
  const used = new Set()
  for (const heading of headings) {
    const stem = heading.textContent.trim().toLowerCase().replace(/\s+/g, '-').replace(/[^\p{L}\p{N}_-]/gu, '') || 'section'
    let id = stem, suffix = 1
    while (used.has(id)) id = `${stem}-${++suffix}`
    used.add(id); heading.id = id; heading.tabIndex = -1
  }
}

export function markdownLineOffset(text, line) {
  let offset = 0
  for (let index = 0; index < line; index++) {
    const next = text.indexOf('\n', offset)
    if (next < 0) return text.length
    offset = next + 1
  }
  return offset
}

function revealEditorHeading(editor, line) {
  const start = markdownLineOffset(editor.value, line)
  const end = editor.value.indexOf('\n', start)
  editor.focus({ preventScroll: true })
  editor.setSelectionRange(start, end < 0 ? editor.value.length : end)
  // Textarea caret APIs don't consistently reveal a wrapped line in WebKit.
  // Measure only on navigation, never on each keystroke or scroll event.
  const mirror = document.createElement('div'), marker = document.createElement('span')
  const computed = editor.ownerDocument.defaultView.getComputedStyle(editor)
  for (const property of ['font', 'lineHeight', 'letterSpacing', 'padding', 'boxSizing', 'tabSize']) mirror.style[property] = computed[property]
  mirror.style.cssText += `;position:fixed;visibility:hidden;pointer-events:none;white-space:pre-wrap;overflow-wrap:break-word;width:${editor.clientWidth}px;`
  mirror.append(document.createTextNode(editor.value.slice(0, start)), marker)
  marker.textContent = '\u200b'
  document.body.append(mirror)
  editor.scrollTop = Math.max(0, marker.offsetTop - mirror.offsetTop - editor.clientHeight / 3)
  mirror.remove()
}

function navigateHeading(source, state, heading) {
  state.select.value = heading.id
  const editor = source.closest('.markdown-edit-surface')?.querySelector('textarea.markdown-editor')
  if (editor) revealEditorHeading(editor, Number(heading.dataset.sourceLine))
  const reduced = source.ownerDocument.defaultView.matchMedia?.('(prefers-reduced-motion: reduce)').matches
  // Animating through a whole dissertation triggers lazy images along the
  // route and shifts the destination. Long chapter jumps must land directly.
  const distance = Math.abs(heading.getBoundingClientRect().top)
  const viewport = source.ownerDocument.defaultView.innerHeight || 800
  heading.scrollIntoView?.({ block: 'start', behavior: reduced || distance > viewport * 2 ? 'auto' : 'smooth' })
  if (!editor) heading.focus({ preventScroll: true })
}

function installDocumentOutline(source, root) {
  const headings = [...root.querySelectorAll('h1,h2,h3,h4,h5,h6')].filter(heading => !heading.closest('blockquote'))
  headingIDs(headings)
  const previous = outlines.get(source)
  if (previous?.onClick) root.removeEventListener('click', previous.onClick)
  outlines.delete(source)
  // Conversations share the renderer, but do not need a document toolbar.
  if (!source.classList.contains('book-markdown-source') || headings.length < 2) return
  const nav = document.createElement('nav'), label = document.createElement('label'), select = document.createElement('select')
  nav.className = 'document-sections'; nav.setAttribute('aria-label', uiText('Document sections'))
  label.textContent = uiText('Sections'); select.setAttribute('aria-label', uiText('Jump to section'))
  for (const heading of headings) {
    const option = document.createElement('option')
    option.value = heading.id
    option.textContent = '\u2002'.repeat(Number(heading.tagName[1]) - 1) + heading.textContent
    select.append(option)
  }
  label.append(select); nav.append(label)
  // One native select remains reachable while reading or editing a long file.
  label.style.cssText = 'display:flex;align-items:center;gap:8px;width:100%;min-width:0'
  const state = { headings, nav, select }
  if (headings.some(heading => heading.id === previous?.select.value)) select.value = previous.select.value
  select.addEventListener('change', () => {
    const heading = headings.find(item => item.id === select.value)
    if (heading) navigateHeading(source, state, heading)
  })
  root.prepend(nav); outlines.set(source, state)
  state.onClick = event => {
    const anchor = event.target.closest?.('a[href^="#"]')
    if (!anchor) return
    let id
    try { id = decodeURIComponent(anchor.getAttribute('href').slice(1)) } catch { return }
    const heading = headings.find(item => item.id === id)
    if (heading) { event.preventDefault(); navigateHeading(source, state, heading) }
  }
  root.addEventListener('click', state.onClick)
}

function syncActiveSection(source) {
  const state = outlines.get(source)
  if (!state || !source.getClientRects().length) return
  const top = state.nav.getBoundingClientRect().bottom + 12
  let low = 0, high = state.headings.length
  while (low < high) {
    const middle = (low + high) >>> 1
    if (state.headings[middle].getBoundingClientRect().top <= top) low = middle + 1
    else high = middle
  }
  state.select.value = state.headings[Math.max(0, low - 1)].id
}

function renderSource(source, immediate = false) {
  if (!(source instanceof HTMLElement)) return
  // A long dissertation must not rebuild its full preview on every keystroke.
  // Only the live editor preview waits for a brief typing pause; file views
  // and streamed answers keep their existing immediate behavior.
  if (!immediate && source.closest('.markdown-live-preview')) {
    clearTimeout(previewTimers.get(source))
    previewTimers.set(source, setTimeout(() => {
      previewTimers.delete(source)
      if (source.isConnected) renderSource(source, true)
    }, 150))
    return
  }
  const content = source.textContent || ''
  const context = { workspace: source.dataset.bookWorkspace, path: source.dataset.bookPath }
  const identity = JSON.stringify([content, context])
  if (renderedSources.get(source) === identity) return
  const root = source.shadowRoot || source.attachShadow({ mode: 'open' })
  const style = document.createElement('style')
  style.textContent = markdownStyle
  root.replaceChildren(style, renderBlocks(content, context))
  installDocumentOutline(source, root)
  renderedSources.set(source, identity)
}

function renderPending(root = document) {
  if (root instanceof Element && root.matches('[data-testid="mooncode-markdown-source"]')) renderSource(root)
  for (const source of root.querySelectorAll?.('[data-testid="mooncode-markdown-source"]') || []) renderSource(source)
}

export function installMoonCodeMarkdownRuntime() {
  if (installed) return
  installed = true
  renderPending()
  let scrollFrame = false
  document.addEventListener('scroll', event => {
    if (event.target?.matches?.('textarea') || scrollFrame) return
    scrollFrame = true
    const schedule = globalThis.requestAnimationFrame || (callback => setTimeout(callback, 16))
    schedule(() => {
      scrollFrame = false
      for (const source of document.querySelectorAll('.book-markdown-source')) syncActiveSection(source)
    })
  }, { capture: true, passive: true })
  new MutationObserver(records => {
    for (const record of records) {
      const target = record.target instanceof Element ? record.target : record.target.parentElement
      const source = target?.closest?.('[data-testid="mooncode-markdown-source"]')
      if (source) renderSource(source)
      for (const node of record.addedNodes) {
        if (node instanceof Element) renderPending(node)
      }
    }
  }).observe(document.getElementById('app') || document.body, {
    childList: true,
    characterData: true,
    attributes: true,
    attributeFilter: ['data-book-workspace', 'data-book-path'],
    subtree: true,
  })
}
