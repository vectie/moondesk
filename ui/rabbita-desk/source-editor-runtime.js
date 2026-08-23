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
let pendingReveal = null
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
  applyPendingReveal(parts)
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

function semanticContext(parts) {
  const workspaceId = parts.surface.dataset.workspaceId || ''
  const path = parts.surface.dataset.sourcePath || ''
  const dirty = parts.surface.dataset.sourceDirty === 'true' ||
    parts.surface.dataset.sourceRuntimeDirty === 'true'
  return {
    workspaceId,
    path,
    dirty,
    available: parts.language === 'MoonBit' && workspaceId !== '' && path.endsWith('.mbt') && !dirty,
  }
}

function sourcePosition(editor) {
  const before = editor.value.slice(0, editor.selectionStart)
  const lines = before.split('\n')
  return { line: lines.length, column: lines[lines.length - 1].length + 1 }
}

function semanticResults(parts) {
  return parts.surface.querySelector('[data-testid="source-semantic-results"]')
}

function setSemanticMessage(parts, message, problem = false) {
  const results = semanticResults(parts)
  if (!(results instanceof HTMLElement)) return
  results.replaceChildren()
  const text = document.createElement('p')
  text.className = problem ? 'source-semantic-message has-problem' : 'source-semantic-message'
  text.textContent = message
  results.append(text)
}

function setSemanticBusy(parts, busy) {
  parts.surface.classList.toggle('is-semantic-loading', busy)
  const available = semanticContext(parts).available
  for (const button of parts.surface.querySelectorAll('[data-action="source-compiler-check"], [data-action="source-go-definition"], [data-action="source-find-references"]')) {
    if (button instanceof HTMLButtonElement) {
      button.disabled = busy || !available
    }
  }
}

async function semanticRequest(parts, action) {
  const context = semanticContext(parts)
  if (!context.available) {
    setSemanticMessage(parts, 'Save the MoonBit file before running compiler semantics.', true)
    return null
  }
  const range = wordRange(parts.editor)
  const position = sourcePosition(parts.editor)
  const body = {
    action,
    path: context.path,
    line: position.line,
    column: position.column,
  }
  if (action !== 'diagnostics') body.symbol = range.word
  setSemanticBusy(parts, true)
  setSemanticMessage(parts, action === 'diagnostics' ? 'Running moon check…' : `Running moon ide for ${range.word || 'selection'}…`)
  try {
    const response = await fetch(`/api/workspaces/${encodeURIComponent(context.workspaceId)}/source/semantics`, {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(body),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok) throw new Error(payload.error || payload.message || `Compiler request failed (${response.status})`)
    return payload
  } catch (error) {
    setSemanticMessage(parts, String(error.message || error), true)
    return null
  } finally {
    setSemanticBusy(parts, false)
  }
}

function diagnosticLocation(diagnostic) {
  const match = String(diagnostic.loc || '').match(/^(\d+):(\d+)/)
  return {
    path: String(diagnostic.relative_path || diagnostic.path || ''),
    line: Number(match?.[1] || 1),
    column: Number(match?.[2] || 1),
  }
}

function locationButton(location, label) {
  const button = document.createElement('button')
  button.type = 'button'
  button.className = 'source-semantic-result'
  button.dataset.semanticPath = location.path
  button.dataset.semanticLine = String(location.line)
  button.dataset.semanticColumn = String(location.column)
  button.textContent = label
  return button
}

function renderCompilerDiagnostics(parts, payload) {
  const results = semanticResults(parts)
  if (!(results instanceof HTMLElement)) return
  const diagnostics = Array.isArray(payload.diagnostics) ? payload.diagnostics : []
  results.replaceChildren()
  const summary = document.createElement('p')
  const errors = diagnostics.filter(item => item.level === 'error').length
  const warnings = diagnostics.filter(item => item.level === 'warning').length
  summary.className = errors > 0 ? 'source-semantic-message has-problem' : 'source-semantic-message'
  summary.textContent = diagnostics.length === 0
    ? 'MoonBit compiler: workspace check passed'
    : `MoonBit compiler: ${errors} errors · ${warnings} warnings`
  results.append(summary)
  for (const diagnostic of diagnostics.slice(0, 50)) {
    const location = diagnosticLocation(diagnostic)
    results.append(locationButton(
      location,
      `${diagnostic.level || 'diagnostic'} · ${location.path}:${diagnostic.loc || location.line} · ${diagnostic.message || ''}`,
    ))
  }
}

function workspaceSemanticPath(path, modulePrefix) {
  const value = String(path || '').replace(/^\.\//, '')
  const prefix = String(modulePrefix || '')
  return prefix && !value.startsWith(prefix) ? prefix + value : value
}

function definitionLocation(output, modulePrefix = '') {
  const path = output.match(/^Definition found at file (.+)$/m)?.[1]?.trim()
  const line = Number(output.match(/^\s*(\d+) \|/m)?.[1] || 1)
  if (!path) return null
  return { path: workspaceSemanticPath(path, modulePrefix), line, column: 1 }
}

function referenceLocations(output, modulePrefix = '') {
  const locations = []
  const seen = new Set()
  const pattern = /^(.+?):(\d+):(\d+)-\d+:\d+:$/gm
  for (const match of output.matchAll(pattern)) {
    const path = workspaceSemanticPath(match[1], modulePrefix)
    const key = `${path}:${match[2]}:${match[3]}`
    if (seen.has(key)) continue
    seen.add(key)
    locations.push({ path, line: Number(match[2]), column: Number(match[3]) })
  }
  return locations
}

function revealSourceLocation(parts, location) {
  if (!location?.path) return
  const context = semanticContext(parts)
  if (context.path !== location.path) {
    pendingReveal = location
    const pathInput = parts.surface.querySelector('[data-testid="source-path"]')
    const open = parts.surface.querySelector('[data-testid="source-open"]')
    if (pathInput instanceof HTMLInputElement && open instanceof HTMLButtonElement) {
      pathInput.value = location.path
      pathInput.dispatchEvent(new Event('input', { bubbles: true }))
      open.click()
    }
    return
  }
  const lines = parts.editor.value.split('\n')
  const lineIndex = Math.max(0, Math.min(lines.length - 1, location.line - 1))
  let offset = 0
  for (let index = 0; index < lineIndex; index += 1) offset += lines[index].length + 1
  const columnOffset = Math.max(0, Math.min(lines[lineIndex].length, location.column - 1))
  const start = offset + columnOffset
  parts.editor.focus()
  parts.editor.setSelectionRange(start, start)
  const lineHeight = Number.parseFloat(getComputedStyle(parts.editor).lineHeight) || 20
  parts.editor.scrollTop = Math.max(0, lineIndex * lineHeight - lineHeight * 3)
  pendingReveal = null
  syncEditor(parts.editor)
}

function applyPendingReveal(parts) {
  if (!pendingReveal) return
  if (semanticContext(parts).path === pendingReveal.path) revealSourceLocation(parts, pendingReveal)
}

async function runCompilerDiagnostics(element) {
  const parts = editorParts(element)
  if (!parts) return
  const payload = await semanticRequest(parts, 'diagnostics')
  if (payload) renderCompilerDiagnostics(parts, payload)
}

async function runDefinitionLookup(element) {
  const parts = editorParts(element)
  if (!parts) return
  const payload = await semanticRequest(parts, 'definition')
  if (!payload) return
  const location = definitionLocation(String(payload.output || ''), payload.module_prefix)
  if (!location) {
    setSemanticMessage(parts, `MoonBit definition not found for ${payload.symbol || 'selection'}`, true)
    return
  }
  setSemanticMessage(parts, `MoonBit definition: ${location.path}:${location.line}`)
  revealSourceLocation(parts, location)
}

async function runReferencesLookup(element) {
  const parts = editorParts(element)
  if (!parts) return
  const payload = await semanticRequest(parts, 'references')
  if (!payload) return
  const results = semanticResults(parts)
  if (!(results instanceof HTMLElement)) return
  const locations = referenceLocations(String(payload.output || ''), payload.module_prefix)
  results.replaceChildren()
  const summary = document.createElement('p')
  summary.className = 'source-semantic-message'
  summary.textContent = `MoonBit references: ${locations.length}`
  results.append(summary)
  for (const location of locations.slice(0, 50)) {
    results.append(locationButton(location, `${location.path}:${location.line}:${location.column}`))
  }
}

export function installSourceEditorRuntime() {
  if (installed) return
  installed = true
  document.addEventListener('input', event => {
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-testid="source-editor-input"]')) {
      const parts = editorParts(event.target)
      if (parts) parts.surface.dataset.sourceRuntimeDirty = 'true'
      syncEditor(event.target)
      closeCompletions()
    }
  }, true)
  document.addEventListener('scroll', event => {
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-testid="source-editor-input"]')) syncEditor(event.target)
  }, true)
  document.addEventListener('click', event => {
    const completion = event.target instanceof Element ? event.target.closest('[data-completion-index]') : null
    if (completion instanceof HTMLElement) {
      acceptCompletion(Number(completion.dataset.completionIndex))
      return
    }
    const location = event.target instanceof Element ? event.target.closest('[data-semantic-path]') : null
    if (location instanceof HTMLElement) {
      const parts = editorParts(location)
      if (parts) revealSourceLocation(parts, {
        path: location.dataset.semanticPath || '',
        line: Number(location.dataset.semanticLine || 1),
        column: Number(location.dataset.semanticColumn || 1),
      })
      return
    }
    const action = event.target instanceof Element ? event.target.closest('[data-action]') : null
    if (!(action instanceof HTMLElement)) return
    if (action.dataset.action === 'source-compiler-check') void runCompilerDiagnostics(action)
    else if (action.dataset.action === 'source-go-definition') void runDefinitionLookup(action)
    else if (action.dataset.action === 'source-find-references') void runReferencesLookup(action)
  }, true)
  document.addEventListener('keydown', event => {
    const editor = event.target
    if (!(editor instanceof HTMLTextAreaElement) || !editor.matches('[data-testid="source-editor-input"]')) return
    if ((event.metaKey || event.ctrlKey) && event.code === 'Space') {
      event.preventDefault()
      showCompletions(editor)
    } else if (event.key === 'F12' && event.shiftKey) {
      event.preventDefault()
      if (semanticContext(editorParts(editor)).available) void runReferencesLookup(editor)
    } else if (event.key === 'F12') {
      event.preventDefault()
      if (semanticContext(editorParts(editor)).available) void runDefinitionLookup(editor)
      else revealLocalDefinition(editor)
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
