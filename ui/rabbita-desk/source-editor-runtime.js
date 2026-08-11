const KEYWORDS = {
  MoonBit: [
    'async', 'break', 'catch', 'const', 'continue', 'derive', 'else', 'enum',
    'extern', 'fn', 'for', 'guard', 'if', 'impl', 'in', 'let', 'match', 'mut',
    'noraise', 'priv', 'pub', 'raise', 'return', 'struct', 'suberror', 'test',
    'trait', 'try', 'type', 'using', 'while', 'with', 'where',
  ],
  JavaScript: [
    'async', 'await', 'break', 'case', 'catch', 'class', 'const', 'continue',
    'default', 'delete', 'do', 'else', 'export', 'extends', 'false', 'finally',
    'for', 'from', 'function', 'if', 'import', 'in', 'instanceof', 'let', 'new',
    'null', 'of', 'return', 'static', 'super', 'switch', 'this', 'throw', 'true',
    'try', 'typeof', 'undefined', 'var', 'while', 'yield',
  ],
  TypeScript: [
    'abstract', 'any', 'as', 'async', 'await', 'boolean', 'class', 'const',
    'declare', 'else', 'enum', 'export', 'extends', 'false', 'for', 'from',
    'function', 'if', 'implements', 'import', 'in', 'interface', 'keyof', 'let',
    'never', 'new', 'null', 'number', 'of', 'private', 'protected', 'public',
    'readonly', 'return', 'static', 'string', 'super', 'this', 'true', 'type',
    'typeof', 'undefined', 'unknown', 'var', 'void', 'while',
  ],
  JSON: ['false', 'null', 'true'],
  Python: [
    'and', 'as', 'assert', 'async', 'await', 'break', 'class', 'continue', 'def',
    'del', 'elif', 'else', 'except', 'False', 'finally', 'for', 'from', 'global',
    'if', 'import', 'in', 'is', 'lambda', 'None', 'nonlocal', 'not', 'or', 'pass',
    'raise', 'return', 'True', 'try', 'while', 'with', 'yield',
  ],
}

const DEFINITION_WORDS = new Set([
  'class', 'const', 'def', 'enum', 'fn', 'function', 'interface', 'let', 'struct',
  'suberror', 'trait', 'type', 'var',
])

let installed = false
let completionState = null
const renderedHighlights = new WeakMap()

function editorParts(element) {
  const surface = element instanceof Element ? element.closest('.source-editor') : null
  if (!(surface instanceof HTMLElement)) return null
  const editor = surface.querySelector('[data-testid="source-editor-input"]')
  const highlight = surface.querySelector('[data-testid="source-highlight"] code')
  const completions = surface.querySelector('[data-testid="source-completions"]')
  const diagnostics = surface.querySelector('[data-testid="source-local-diagnostics"]')
  const language = surface.querySelector('[data-testid="source-language"]')?.textContent || 'Plain text'
  if (!(editor instanceof HTMLTextAreaElement) || !(highlight instanceof HTMLElement)) return null
  return { surface, editor, highlight, completions, diagnostics, language }
}

function escapeHtml(value) {
  return value.replaceAll('&', '&amp;').replaceAll('<', '&lt;').replaceAll('>', '&gt;')
}

function tokenClass(kind, value, keywords) {
  if (kind === 'word' && keywords.has(value)) return 'keyword'
  if (kind === 'word' && /^[A-Z]/.test(value)) return 'type'
  return kind
}

function highlightedHtml(value, language) {
  const keywords = new Set(KEYWORDS[language] || [])
  let output = ''
  let index = 0
  while (index < value.length) {
    const rest = value.slice(index)
    const comment = rest.match(language === 'Python' || language === 'Shell'
      ? /^#[^\n]*/
      : /^(?:\/\/|#\|)[^\n]*/)
    const blockComment = rest.match(/^\/\*[\s\S]*?\*\//)
    const string = rest.match(/^(?:"(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|`(?:\\.|[^`\\])*`)/)
    const number = rest.match(/^\b(?:0x[\da-f]+|\d+(?:\.\d+)?)\b/i)
    const word = rest.match(/^[A-Za-z_$][\w$]*/)
    const token = comment || blockComment || string || number || word
    if (!token) {
      output += escapeHtml(value[index])
      index += 1
      continue
    }
    const kind = comment || blockComment ? 'comment'
      : string ? 'string'
      : number ? 'number'
      : 'word'
    const css = tokenClass(kind, token[0], keywords)
    output += css === 'word'
      ? escapeHtml(token[0])
      : `<span class="source-token-${css}">${escapeHtml(token[0])}</span>`
    index += token[0].length
  }
  return output + (value.endsWith('\n') ? ' ' : '')
}

function structuralDiagnostic(value, language) {
  if (language === 'JSON' && value.trim()) {
    try {
      JSON.parse(value)
    } catch (error) {
      return `JSON · ${String(error.message || error)}`
    }
  }
  const pairs = { ')': '(', ']': '[', '}': '{' }
  const stack = []
  let quote = ''
  let escaped = false
  let line = 1
  let column = 0
  for (let index = 0; index < value.length; index += 1) {
    const char = value[index]
    column += 1
    if (char === '\n') {
      line += 1
      column = 0
    }
    if (quote) {
      if (escaped) escaped = false
      else if (char === '\\') escaped = true
      else if (char === quote) quote = ''
      continue
    }
    if (char === '"' || char === "'" || char === '`') {
      quote = char
      continue
    }
    if (char === '/' && value[index + 1] === '/') {
      const end = value.indexOf('\n', index)
      if (end < 0) break
      index = end - 1
      continue
    }
    if (char === '(' || char === '[' || char === '{') stack.push({ char, line, column })
    else if (pairs[char]) {
      const open = stack.pop()
      if (!open || open.char !== pairs[char]) return `Line ${line}, col ${column} · unmatched ${char}`
    }
  }
  if (quote) return `Line ${line}, col ${column} · unterminated string`
  const open = stack.pop()
  return open ? `Line ${open.line}, col ${open.column} · unmatched ${open.char}` : ''
}

function syncEditor(element) {
  const parts = editorParts(element)
  if (!parts) return
  const signature = `${parts.language}\u0000${parts.editor.value}`
  if (renderedHighlights.get(parts.highlight) !== signature) {
    parts.highlight.innerHTML = highlightedHtml(parts.editor.value, parts.language)
    renderedHighlights.set(parts.highlight, signature)
  }
  parts.highlight.parentElement.scrollTop = parts.editor.scrollTop
  parts.highlight.parentElement.scrollLeft = parts.editor.scrollLeft
  parts.surface.classList.add('is-highlight-ready')
  const problem = structuralDiagnostic(parts.editor.value, parts.language)
  if (parts.diagnostics instanceof HTMLElement) {
    parts.diagnostics.textContent = problem
      ? `Local diagnostics: ${problem}`
      : 'Local diagnostics: no structural issues'
    parts.diagnostics.classList.toggle('has-problem', Boolean(problem))
  }
}

function wordRange(editor) {
  const before = editor.value.slice(0, editor.selectionStart)
  const after = editor.value.slice(editor.selectionStart)
  const prefix = before.match(/[A-Za-z_$][\w$]*$/)?.[0] || ''
  const suffix = after.match(/^[\w$]*/)?.[0] || ''
  return { start: editor.selectionStart - prefix.length, end: editor.selectionStart + suffix.length, word: prefix + suffix, prefix }
}

function completionCandidates(parts) {
  const range = wordRange(parts.editor)
  const identifiers = parts.editor.value.match(/[A-Za-z_$][\w$]*/g) || []
  const words = [...new Set([...(KEYWORDS[parts.language] || []), ...identifiers])]
    .filter(word => word !== range.word && word.startsWith(range.prefix))
    .sort((left, right) => left.length - right.length || left.localeCompare(right))
    .slice(0, 8)
  return { range, words }
}

function closeCompletions() {
  if (completionState?.parts.completions instanceof HTMLElement) {
    completionState.parts.completions.replaceChildren()
    completionState.parts.completions.classList.remove('is-open')
  }
  completionState = null
}

function acceptCompletion(index) {
  const state = completionState
  const word = state?.words[index]
  if (!state || !word) return
  state.parts.editor.setRangeText(word, state.range.start, state.range.end, 'end')
  state.parts.editor.dispatchEvent(new Event('input', { bubbles: true }))
  state.parts.editor.focus()
  closeCompletions()
}

function showCompletions(element) {
  const parts = editorParts(element)
  if (!parts || !(parts.completions instanceof HTMLElement)) return
  const { range, words } = completionCandidates(parts)
  closeCompletions()
  if (words.length === 0) {
    if (parts.diagnostics instanceof HTMLElement) parts.diagnostics.textContent = 'Local completion: no matches'
    return
  }
  completionState = { parts, range, words, selected: 0 }
  parts.completions.replaceChildren(...words.map((word, index) => {
    const button = document.createElement('button')
    button.type = 'button'
    button.role = 'option'
    button.textContent = word
    button.dataset.completionIndex = String(index)
    button.className = index === 0 ? 'is-selected' : ''
    return button
  }))
  parts.completions.classList.add('is-open')
}

function moveCompletion(direction) {
  if (!completionState) return false
  completionState.selected = (completionState.selected + direction + completionState.words.length) % completionState.words.length
  for (const [index, button] of [...completionState.parts.completions.children].entries()) {
    button.classList.toggle('is-selected', index === completionState.selected)
  }
  return true
}

function revealLocalDefinition(element) {
  const parts = editorParts(element)
  if (!parts) return false
  const { word } = wordRange(parts.editor)
  if (!word) return false
  const lines = parts.editor.value.split('\n')
  const escaped = word.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')
  const pattern = new RegExp(`\\b(?:${[...DEFINITION_WORDS].join('|')})\\s+${escaped}\\b`)
  let offset = 0
  for (let lineIndex = 0; lineIndex < lines.length; lineIndex += 1) {
    const line = lines[lineIndex]
    const match = pattern.exec(line)
    if (match) {
      const start = offset + match.index + match[0].lastIndexOf(word)
      parts.editor.focus()
      parts.editor.setSelectionRange(start, start + word.length)
      const lineHeight = Number.parseFloat(getComputedStyle(parts.editor).lineHeight) || 20
      parts.editor.scrollTop = Math.max(0, lineIndex * lineHeight - lineHeight * 3)
      syncEditor(parts.editor)
      if (parts.diagnostics instanceof HTMLElement) parts.diagnostics.textContent = `Local definition: ${word}`
      return true
    }
    offset += line.length + 1
  }
  if (parts.diagnostics instanceof HTMLElement) parts.diagnostics.textContent = `Local definition not found for ${word}`
  return false
}

export function installSourceEditorRuntime() {
  if (installed) return
  installed = true
  document.addEventListener('input', event => {
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-testid="source-editor-input"]')) {
      syncEditor(event.target)
      closeCompletions()
    }
  }, true)
  document.addEventListener('scroll', event => {
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-testid="source-editor-input"]')) syncEditor(event.target)
  }, true)
  document.addEventListener('click', event => {
    const completion = event.target instanceof Element ? event.target.closest('[data-completion-index]') : null
    if (completion instanceof HTMLElement) acceptCompletion(Number(completion.dataset.completionIndex))
  }, true)
  document.addEventListener('keydown', event => {
    const editor = event.target
    if (!(editor instanceof HTMLTextAreaElement) || !editor.matches('[data-testid="source-editor-input"]')) return
    if ((event.metaKey || event.ctrlKey) && event.code === 'Space') {
      event.preventDefault()
      showCompletions(editor)
    } else if (event.key === 'F12') {
      event.preventDefault()
      revealLocalDefinition(editor)
    } else if (completionState && event.key === 'ArrowDown') {
      event.preventDefault()
      moveCompletion(1)
    } else if (completionState && event.key === 'ArrowUp') {
      event.preventDefault()
      moveCompletion(-1)
    } else if (completionState && event.key === 'Enter') {
      event.preventDefault()
      acceptCompletion(completionState.selected)
    } else if (completionState && event.key === 'Escape') {
      event.preventDefault()
      closeCompletions()
    }
  }, true)
  new MutationObserver(records => {
    for (const record of records) {
      for (const node of record.addedNodes) {
        if (!(node instanceof Element)) continue
        if (node.matches('[data-testid="source-editor-input"]')) syncEditor(node)
        for (const editor of node.querySelectorAll('[data-testid="source-editor-input"]')) syncEditor(editor)
      }
    }
  }).observe(document.getElementById('app') || document.body, { childList: true, subtree: true })
  for (const editor of document.querySelectorAll('[data-testid="source-editor-input"]')) syncEditor(editor)
}
