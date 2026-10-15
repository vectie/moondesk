const editors = new WeakSet()
const formatGlyphs = {
  heading: 'H', bold: 'B', italic: 'I',
  link: '<path d="M10 13a5 5 0 0 0 7 0l3-3a5 5 0 0 0-7-7l-2 2M14 11a5 5 0 0 0-7 0l-3 3a5 5 0 0 0 7 7l2-2"/>',
  list: '<path d="M9 6h12M9 12h12M9 18h12"/><circle cx="4" cy="6" r="1"/><circle cx="4" cy="12" r="1"/><circle cx="4" cy="18" r="1"/>',
  ordered: '1.', checklist: '<path d="m3 6 2 2 3-4M11 6h10M3 12h4v4H3zM11 14h10M11 20h10"/>',
  quote: '<path d="M4 5h6v7H4zM4 12c0 4 2 6 6 6M14 5h6v7h-6zM14 12c0 4 2 6 6 6"/>',
  code: '<path d="m8 5-7 7 7 7M16 5l7 7-7 7"/>',
  table: '<rect x="3" y="3" width="18" height="18" rx="2"/><path d="M3 9h18M3 15h18M10 3v18"/>',
}

function formatMarkdownSelection(text, start, end, command) {
  const selected = text.slice(start, end)
  const wrappers = { bold: ['**', '**', 'bold text'], italic: ['_', '_', 'italic text'], code: ['`', '`', 'code'], link: ['[', '](https://example.com)', 'link text'] }
  if (wrappers[command]) {
    const [before, after, fallback] = wrappers[command]
    const value = selected || fallback
    return { text: text.slice(0, start) + before + value + after + text.slice(end), start: start + before.length, end: start + before.length + value.length }
  }
  if (command === 'table') {
    const value = '\n| Column | Value |\n| --- | --- |\n| Item | Detail |\n'
    return { text: text.slice(0, start) + value + text.slice(end), start: start + 3, end: start + 9 }
  }
  const lineStart = text.lastIndexOf('\n', start - 1) + 1
  const ending = text.indexOf('\n', end)
  const lineEnd = ending < 0 ? text.length : ending
  const prefix = ({ heading: '## ', list: '- ', ordered: '1. ', quote: '> ', checklist: '- [ ] ' })[command]
  if (!prefix) return { text, start, end }
  const block = text.slice(lineStart, lineEnd).split('\n').map(line => `${prefix}${line}`).join('\n')
  return { text: text.slice(0, lineStart) + block + text.slice(lineEnd), start: lineStart, end: lineStart + block.length }
}

function enhanceDocumentEditors() {
  for (const textarea of document.querySelectorAll('textarea.markdown-editor')) {
    if (editors.has(textarea)) continue
    editors.add(textarea)
    const surface = textarea.closest('.markdown-edit-surface')
    if (!surface) continue
    const toolbar = document.createElement('div')
    toolbar.className = 'document-format-toolbar'
    toolbar.setAttribute('role', 'toolbar')
    toolbar.setAttribute('aria-label', 'Format note')
    const apply = command => {
      const change = formatMarkdownSelection(textarea.value, textarea.selectionStart, textarea.selectionEnd, command)
      textarea.value = change.text
      textarea.dispatchEvent(new Event('input', { bubbles: true }))
      textarea.focus()
      textarea.setSelectionRange(change.start, change.end)
    }
    for (const [id, label] of [['heading', 'Heading'], ['bold', 'Bold'], ['italic', 'Italic'], ['link', 'Link'], ['list', 'List'], ['ordered', 'Numbered'], ['checklist', 'Checklist'], ['quote', 'Quote'], ['code', 'Code'], ['table', 'Table']]) {
      const button = document.createElement('button')
      button.type = 'button'; button.className = 'secondary-button'; button.dataset.format = id
      button.title = label; button.setAttribute('aria-label', label)
      const glyph = formatGlyphs[id]
      button.innerHTML = glyph.startsWith('<') ? `<svg viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true">${glyph}</svg>` : `<span aria-hidden="true">${glyph}</span>`
      button.addEventListener('pointerdown', event => event.preventDefault())
      button.addEventListener('click', () => apply(id)); toolbar.append(button)
    }
    const ai = document.createElement('select')
    ai.setAttribute('aria-label', 'Rewrite selected text with AI')
    for (const [value, label] of [['', 'Rewrite selection…'], ['clearer', 'Make clearer'], ['shorter', 'Make shorter'], ['formal', 'Make more formal'], ['explain', 'Explain selection']]) {
      const option = document.createElement('option'); option.value = value; option.textContent = label; ai.append(option)
    }
    const selection = { start: 0, end: 0 }
    textarea.addEventListener('select', () => { selection.start = textarea.selectionStart; selection.end = textarea.selectionEnd })
    ai.addEventListener('change', () => {
      if (!ai.value) return
      const selected = textarea.value.slice(selection.start, selection.end)
      if (!selected.trim()) { textarea.focus(); ai.value = ''; return }
      const path = surface.querySelector('.quiet-path')?.textContent || 'current document'
      const instruction = ai.value === 'explain' ? 'Explain this selection.' : `Rewrite only this selected passage to make it ${ai.value}. Preserve factual meaning and surrounding content. Show the proposed replacement before applying it.`
      globalThis.__moondeskWorkspaceFeaturesDispatch?.('ask-selection', `${instruction}\n\nDocument: ${path}\nSelected passage:\n${selected}`, 'draft', '', '')
      ai.value = ''
    })
    toolbar.append(ai)
    surface.querySelector('.site-toolbar')?.after(toolbar)
    textarea.addEventListener('keydown', event => {
      if (!(event.metaKey || event.ctrlKey) || event.altKey) return
      if (event.key.toLowerCase() === 's') {
        const save = textarea.closest('.wiki-document-viewer')?.querySelector('[data-markdown-action="save"]')
        if (save) { event.preventDefault(); save.click() }
        return
      }
      const command = ({ b: 'bold', i: 'italic', k: 'link' })[event.key.toLowerCase()]
      if (command) { event.preventDefault(); apply(command) }
    })
  }
}

if (typeof document !== 'undefined') {
  const observer = new MutationObserver(records => {
    if (records.some(record => [...record.addedNodes].some(node => node.nodeType === 1 && (node.matches?.('textarea.markdown-editor') || node.querySelector?.('textarea.markdown-editor'))))) enhanceDocumentEditors()
  })
  observer.observe(document.documentElement, { childList: true, subtree: true })
  enhanceDocumentEditors()
}

export { formatMarkdownSelection, enhanceDocumentEditors }
