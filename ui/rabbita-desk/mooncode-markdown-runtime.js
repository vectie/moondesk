let installed = false

function safeLink(value) {
  const href = String(value || '').trim()
  if (href.startsWith('/') || href.startsWith('#') || href.startsWith('./') || href.startsWith('../')) return href
  try {
    const url = new URL(href)
    return ['http:', 'https:', 'mailto:'].includes(url.protocol) ? href : ''
  } catch {
    return ''
  }
}

function appendInline(parent, source) {
  let text = String(source || '')
  const token = /(`[^`\n]+`|\*\*[^*\n]+\*\*|~~[^~\n]+~~|\[[^\]\n]+\]\([^\s)]+\)|https?:\/\/[^\s<]+)/
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
      appendInline(strong, value.slice(2, -2))
      parent.append(strong)
    } else if (value.startsWith('~~')) {
      const deleted = document.createElement('del')
      appendInline(deleted, value.slice(2, -2))
      parent.append(deleted)
    } else if (value.startsWith('[')) {
      const parts = /^\[([^\]]+)\]\(([^)]+)\)$/.exec(value)
      const href = safeLink(parts?.[2])
      if (href) {
        const link = document.createElement('a')
        link.href = href
        link.target = '_blank'
        link.rel = 'noopener noreferrer'
        appendInline(link, parts[1])
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

function tableRow(line, cellTag) {
  const row = document.createElement('tr')
  for (const value of line.trim().replace(/^\||\|$/g, '').split('|')) {
    const cell = document.createElement(cellTag)
    appendInline(cell, value.trim())
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

function renderBlocks(source) {
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
      appendInline(element, heading[2])
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
      head.append(tableRow(line, 'th'))
      index += 2
      while (index < lines.length && lines[index].includes('|') && lines[index].trim()) {
        body.append(tableRow(lines[index], 'td'))
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
      quote.append(renderBlocks(quoted.join('\n')))
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
          appendInline(row, item[2].slice(task[0].length))
        } else {
          appendInline(row, item[2])
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
    appendInline(element, paragraph.join(' '))
    fragment.append(element)
  }
  return fragment
}

function renderSource(source) {
  if (!(source instanceof HTMLElement) || source.dataset.markdownRendered === 'true') return
  source.dataset.markdownRendered = 'true'
  const parent = source.parentElement
  if (!parent) return
  const fragment = renderBlocks(source.textContent || '')
  parent.replaceChildren(fragment)
  parent.dataset.markdownEnhanced = 'true'
}

function renderPending(root = document) {
  if (root instanceof Element && root.matches('[data-testid="mooncode-markdown-source"]')) renderSource(root)
  for (const source of root.querySelectorAll?.('[data-testid="mooncode-markdown-source"]') || []) renderSource(source)
}

export function installMoonCodeMarkdownRuntime() {
  if (installed) return
  installed = true
  renderPending()
  new MutationObserver(records => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (node instanceof Element) renderPending(node)
      }
    }
  }).observe(document.getElementById('app') || document.body, { childList: true, subtree: true })
}
