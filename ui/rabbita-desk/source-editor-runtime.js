import { syncMarkdownLinks, changeMarkdownLinks, actMarkdownLinks } from './source-markdown-links-ui.js'
import { syncJsonExplorer, actJsonExplorer, changeJsonReplacement } from './source-json-explorer.js'
import { syncJsonComparison, changeJsonComparison, actJsonComparison } from './source-json-comparison-ui.js'
import { codeOutline } from './source-code-outline.js'
import { parseSourceLocation, SourceNavigation } from './source-navigation.js'

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
const MAX_HIGHLIGHT_CHARACTERS = 120_000

let installed = false
let completionState = null
let completionListSequence = 0
const navigation = new SourceNavigation()
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
  const large = parts.editor.value.length > MAX_HIGHLIGHT_CHARACTERS
  const signature = large
    ? `${parts.language}\u0000large`
    : `${parts.language}\u0000${parts.editor.value}`
  const changed = renderedHighlights.get(parts.highlight) !== signature
  if (changed) {
    if (large) parts.highlight.replaceChildren()
    else parts.highlight.innerHTML = highlightedHtml(parts.editor.value, parts.language)
    renderedHighlights.set(parts.highlight, signature)
  }
  parts.highlight.parentElement.scrollTop = parts.editor.scrollTop
  parts.highlight.parentElement.scrollLeft = parts.editor.scrollLeft
  parts.surface.classList.toggle('is-highlight-ready', !large)
  if (changed && parts.diagnostics instanceof HTMLElement) {
    const problem = large ? '' : structuralDiagnostic(parts.editor.value, parts.language)
    const message = large
      ? 'Local highlighting and diagnostics paused for this large file'
      : problem
      ? `Local diagnostics: ${problem}`
      : 'Local diagnostics: no structural issues'
    if (parts.diagnostics.textContent !== message) parts.diagnostics.textContent = message
    parts.diagnostics.classList.toggle('has-problem', Boolean(problem))
  }
  syncNavigation(parts)
  syncCodeOutline(parts)
  syncJsonExplorer(parts)
  syncJsonComparison(parts)
  syncMarkdownLinks(parts)
  applyPendingReveal(parts)
}

const outlineCache = new WeakMap()

function syncCodeOutline(parts) {
  let panel = parts.surface.querySelector('[data-code-outline]')
  if (!panel) {
    panel = document.createElement('div'); panel.setAttribute('data-code-outline', '')
    panel.setAttribute('aria-label', 'Local code declaration outline')
    const filter = document.createElement('input'); filter.setAttribute('data-code-outline-filter', '')
    filter.placeholder = 'Filter declarations'; filter.setAttribute('aria-label', 'Filter local code declarations')
    const status = document.createElement('p'); status.setAttribute('data-code-outline-status', ''); status.setAttribute('role', 'status')
    const list = document.createElement('div'); list.setAttribute('data-code-outline-list', '')
    panel.append(filter, status, list); parts.surface.append(panel)
  }
  const filter = panel.querySelector('[data-code-outline-filter]')
  const context = semanticContext(parts)
  const identity = `${context.workspaceId}\0${context.path}`
  const previous = outlineCache.get(panel)
  if (previous && previous.identity !== identity) filter.value = ''
  const signature = `${identity}\0${parts.language}\0${parts.editor.disabled}\0${filter.value}\0${parts.editor.value}`
  if (previous?.signature === signature) return
  const outline = codeOutline(parts.editor.value, parts.language)
  const entries = outline.entries.filter(entry => entry.name.toLowerCase().includes(filter.value.toLowerCase()))
  panel.hidden = !outline.supported
  filter.disabled = parts.editor.disabled || Boolean(outline.unavailable)
  panel.querySelector('[data-code-outline-status]').textContent = outline.unavailable ||
    `Local declaration hints · ${entries.length} matching; showing ${Math.min(entries.length, 100)}. Not compiler symbols.`
  panel.querySelector('[data-code-outline-list]').replaceChildren(...entries.slice(0, 100).map(entry => {
    const button = document.createElement('button'); button.type = 'button'; button.className = 'secondary-button'
    button.dataset.action = 'source-code-outline-select'; button.dataset.codeOutlineStart = String(entry.start)
    button.textContent = `${entry.kind} ${entry.name} · L${entry.line}`; button.disabled = parts.editor.disabled
    return button
  }))
  outlineCache.set(panel, { identity, signature, text: parts.editor.value, entries })
}

function selectCodeOutline(parts, action) {
  if (!parts || parts.editor.disabled) return
  const panel = parts.surface.querySelector('[data-code-outline]')
  const snapshot = outlineCache.get(panel)
  const context = semanticContext(parts)
  if (!snapshot || snapshot.text !== parts.editor.value || snapshot.identity !== `${context.workspaceId}\0${context.path}`) {
    syncCodeOutline(parts); return
  }
  const entry = snapshot.entries.find(entry => entry.start === Number(action.dataset.codeOutlineStart))
  if (entry) revealSourceLocation(parts, { path: context.path, ...entry })
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
  if (completionState?.parts.editor instanceof HTMLTextAreaElement) {
    const editor = completionState.parts.editor
    editor.removeAttribute('aria-controls')
    editor.removeAttribute('aria-activedescendant')
    editor.setAttribute('aria-expanded', 'false')
  }
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
  if (!parts.completions.id) parts.completions.id = `source-completions-${++completionListSequence}`
  parts.completions.replaceChildren(...words.map((word, index) => {
    const button = document.createElement('button')
    button.type = 'button'
    button.role = 'option'
    button.textContent = word
    button.dataset.completionIndex = String(index)
    button.id = `${parts.completions.id}-option-${index}`
    button.tabIndex = -1
    button.setAttribute('aria-selected', index === 0 ? 'true' : 'false')
    button.className = index === 0 ? 'is-selected' : ''
    return button
  }))
  parts.completions.classList.add('is-open')
  parts.editor.setAttribute('aria-autocomplete', 'list')
  parts.editor.setAttribute('aria-controls', parts.completions.id)
  parts.editor.setAttribute('aria-expanded', 'true')
  parts.editor.setAttribute('aria-activedescendant', `${parts.completions.id}-option-0`)
}

function moveCompletion(direction) {
  if (!completionState) return false
  completionState.selected = (completionState.selected + direction + completionState.words.length) % completionState.words.length
  for (const [index, button] of [...completionState.parts.completions.children].entries()) {
    button.classList.toggle('is-selected', index === completionState.selected)
    button.setAttribute('aria-selected', index === completionState.selected ? 'true' : 'false')
  }
  completionState.parts.editor.setAttribute(
    'aria-activedescendant',
    `${completionState.parts.completions.id}-option-${completionState.selected}`,
  )
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
      revealSourceLocation(parts, { path: semanticContext(parts).path, start, end: start + word.length,
        line: lineIndex + 1, column: 1 })
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
    if (!parts.surface.isConnected || !semanticContext(parts).available ||
      semanticContext(parts).workspaceId !== context.workspaceId ||
      semanticContext(parts).path !== context.path) return null
    if (!payload || typeof payload !== 'object') throw new Error('Compiler response is unreadable')
    if (!response.ok) throw new Error(payload.error?.message || payload.error || payload.message || `Compiler request failed (${response.status})`)
    if (payload.ok === false && action !== 'diagnostics') {
      throw new Error(String(payload.output || 'MoonBit navigation could not resolve this symbol').slice(0, 1000))
    }
    return payload
  } catch (error) {
    if (parts.surface.isConnected && semanticContext(parts).workspaceId === context.workspaceId &&
      semanticContext(parts).path === context.path) {
      setSemanticMessage(parts, String(error.message || error), true)
    }
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

export function semanticLocations(payload) {
  if (!Array.isArray(payload?.locations)) return []
  const seen = new Set()
  return payload.locations.filter(location => {
    if (!location || typeof location !== 'object') return false
    const path = String(location.path || '')
    const line = Number(location.line)
    const column = Number(location.column)
    if (!path || path.startsWith('/') || path.includes('\0') ||
      path.split('/').includes('..') ||
      !Number.isSafeInteger(line) || line < 1 ||
      !Number.isSafeInteger(column) || column < 1) return false
    const key = `${path}:${line}:${column}`
    if (seen.has(key)) return false
    seen.add(key)
    return true
  })
}

function navigationSnapshot(parts) {
  return { path: semanticContext(parts).path, start: parts.editor.selectionStart,
    end: parts.editor.selectionEnd, direction: parts.editor.selectionDirection,
    scrollTop: parts.editor.scrollTop, scrollLeft: parts.editor.scrollLeft,
    text: parts.editor.value }
}

function navigationMessage(parts, message) {
  const status = parts.surface.querySelector('[data-source-navigation-status]')
  if (status && status.textContent !== message) status.textContent = message
}

function syncNavigation(parts) {
  navigation.context(semanticContext(parts).workspaceId)
  let toolbar = parts.surface.querySelector('[data-source-navigation]')
  if (!toolbar) {
    toolbar = document.createElement('div')
    toolbar.className = 'source-editor-toolbar'
    toolbar.setAttribute('data-source-navigation', '')
    toolbar.setAttribute('aria-label', 'Source location navigation')
    for (const [action, label] of [['back', 'Back to location'], ['forward', 'Forward to location'], ['cancel', 'Cancel navigation']]) {
      const button = document.createElement('button')
      button.type = 'button'; button.className = 'secondary-button'
      button.dataset.action = `source-navigation-${action}`; button.textContent = label
      toolbar.append(button)
    }
    const input = document.createElement('input')
    input.dataset.sourceLocation = ''; input.placeholder = 'Line:column'
    input.setAttribute('aria-label', 'Go to source line and UTF-16 column')
    toolbar.append(input)
    const go = document.createElement('button')
    go.type = 'button'; go.className = 'secondary-button'
    go.dataset.action = 'source-navigation-go'; go.textContent = 'Go to location'
    toolbar.append(go)
    const status = document.createElement('span')
    status.setAttribute('data-source-navigation-status', '')
    status.setAttribute('role', 'status'); toolbar.append(status)
    parts.surface.append(toolbar)
  }
  for (const direction of ['back', 'forward']) {
    toolbar.querySelector(`[data-action="source-navigation-${direction}"]`).disabled =
      parts.editor.disabled || Boolean(navigation.pending) || navigation[direction].length === 0
  }
  toolbar.querySelector('[data-action="source-navigation-cancel"]').disabled = !navigation.pending
  toolbar.querySelector('[data-action="source-navigation-go"]').disabled = parts.editor.disabled
}

function navigateAction(parts, action) {
  if (!parts) return
  if (action === 'cancel') { navigation.cancel(); navigationMessage(parts, 'Navigation canceled'); syncNavigation(parts); return }
  if (parts.editor.disabled) return
  if (action === 'go') {
    try {
      const location = parseSourceLocation(parts.surface.querySelector('[data-source-location]').value, parts.editor.value)
      revealSourceLocation(parts, { path: semanticContext(parts).path, ...location })
    } catch (error) { navigationMessage(parts, error.message) }
  } else {
    const target = navigation[action]?.at(-1)
    if (target && !navigation.pending) revealSourceLocation(parts, target, action)
  }
}

function revealSourceLocation(parts, location, direction = 'jump') {
  if (!location?.path || parts.editor.disabled) return
  const context = semanticContext(parts)
  navigation.context(context.workspaceId)
  navigation.begin(navigationSnapshot(parts), location, direction)
  if (context.path !== location.path) {
    const pathInput = parts.surface.querySelector('[data-testid="source-path"]')
    const open = parts.surface.querySelector('[data-testid="source-open"]')
    if (pathInput instanceof HTMLInputElement && open instanceof HTMLButtonElement && !open.disabled) {
      pathInput.value = location.path
      pathInput.dispatchEvent(new Event('input', { bubbles: true }))
      open.click()
      navigationMessage(parts, `Opening ${location.path}…`)
    } else navigation.cancel()
    syncNavigation(parts)
    return
  }
  applyPendingReveal(parts)
}

function applyPendingReveal(parts) {
  const pending = navigation.pending
  if (!pending) return
  const context = semanticContext(parts)
  if (context.path !== pending.target.path && context.path !== pending.origin.path) {
    navigation.cancel(); syncNavigation(parts); return
  }
  if (context.path !== pending.target.path || parts.editor.disabled) return
  const location = navigation.arrive(context.path)
  const lines = parts.editor.value.split('\n')
  const lineIndex = Math.max(0, Math.min(lines.length - 1, (location.line || 1) - 1))
  const base = lines.slice(0, lineIndex).reduce((sum, line) => sum + line.length + 1, 0)
  const clamp = value => {
    let offset = Math.max(0, Math.min(parts.editor.value.length, value))
    if (/[\uD800-\uDBFF]/.test(parts.editor.value[offset - 1] || '') && /[\uDC00-\uDFFF]/.test(parts.editor.value[offset] || '')) offset -= 1
    return offset
  }
  const start = clamp(location.start ?? location.offset ?? (base + Math.min(lines[lineIndex].length, (location.column || 1) - 1)))
  const end = clamp(location.end ?? start)
  parts.editor.focus(); parts.editor.setSelectionRange(start, end, location.direction || 'none')
  const lineHeight = Number.parseFloat(getComputedStyle(parts.editor).lineHeight) || 20
  parts.editor.scrollTop = location.scrollTop ?? Math.max(0, lineIndex * lineHeight - lineHeight * 3)
  parts.editor.scrollLeft = location.scrollLeft ?? 0
  navigationMessage(parts, location.text !== undefined && location.text !== parts.editor.value
    ? 'Returned to location; text changed, selection is bounded to current content'
    : `Location: ${context.path}`)
  syncEditor(parts.editor)
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
  const location = semanticLocations(payload)[0]
  if (!location) {
    setSemanticMessage(parts, 'MoonBit definition is unavailable inside this MoonBook.', true)
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
  const locations = semanticLocations(payload)
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
    if (event.target instanceof HTMLInputElement && event.target.matches('[data-markdown-links-replacement]')) {
      changeMarkdownLinks(editorParts(event.target))
    }
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-json-compare-reference]')) {
      changeJsonComparison(editorParts(event.target))
    }
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-json-replacement]')) {
      changeJsonReplacement(editorParts(event.target))
    }
    if (event.target instanceof HTMLInputElement && event.target.matches('[data-code-outline-filter]')) {
      const parts = editorParts(event.target); if (parts) syncCodeOutline(parts)
    }
    if (event.target instanceof HTMLTextAreaElement && event.target.matches('[data-testid="source-editor-input"]')) {
      navigation.cancel()
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
    if (completionState && event.target !== completionState.parts.editor) closeCompletions()
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
    if (action.dataset.action.startsWith('source-markdown-links-')) actMarkdownLinks(editorParts(action), action, revealSourceLocation)
    else if (action.dataset.action.startsWith('source-json-compare-')) actJsonComparison(editorParts(action), action, revealSourceLocation)
    else if (action.dataset.action.startsWith('source-json-')) actJsonExplorer(editorParts(action), action, revealSourceLocation)
    else if (action.dataset.action === 'source-code-outline-select') selectCodeOutline(editorParts(action), action)
    else if (action.dataset.action.startsWith('source-navigation-')) navigateAction(editorParts(action), action.dataset.action.slice('source-navigation-'.length))
    else if (action.dataset.action === 'source-compiler-check') void runCompilerDiagnostics(action)
    else if (action.dataset.action === 'source-go-definition') void runDefinitionLookup(action)
    else if (action.dataset.action === 'source-find-references') void runReferencesLookup(action)
  }, true)
  document.addEventListener('keydown', event => {
    const editor = event.target
    if (editor instanceof HTMLInputElement && editor.matches('[data-json-pointer]') && event.key === 'Enter' && !event.isComposing) {
      event.preventDefault()
      const parts = editorParts(editor)
      const action = parts?.surface.querySelector('[data-action="source-json-go"]')
      if (action) actJsonExplorer(parts, action, revealSourceLocation)
      return
    }
    if (editor instanceof HTMLInputElement && editor.matches('[data-source-location]') && event.key === 'Enter') {
      event.preventDefault(); navigateAction(editorParts(editor), 'go'); return
    }
    if (!(editor instanceof HTMLTextAreaElement) || !editor.matches('[data-testid="source-editor-input"]')) return
    if (event.isComposing) return
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'g' && !event.altKey && !event.shiftKey) {
      event.preventDefault()
      editorParts(editor)?.surface.querySelector('[data-source-location]')?.focus()
    } else if ((event.metaKey || event.ctrlKey) && event.code === 'Space') {
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
    } else if (completionState && event.key === 'Tab') {
      closeCompletions()
    }
  }, true)
  let editorSyncPending = false
  const scheduleEditorSync = () => {
    if (editorSyncPending) return
    editorSyncPending = true
    requestAnimationFrame(() => {
      editorSyncPending = false
      for (const editor of document.querySelectorAll('[data-testid="source-editor-input"]')) syncEditor(editor)
    })
  }
  new MutationObserver(records => {
    for (const record of records) {
      if (record.type === 'attributes' && record.target instanceof HTMLElement &&
        record.target.matches('[data-testid="source-editor"]') &&
        record.target.dataset.sourceDirty === 'false') {
        record.target.dataset.sourceRuntimeDirty = 'false'
      }
    }
    scheduleEditorSync()
  }).observe(document.getElementById('app') || document.body, {
    childList: true,
    subtree: true,
    attributes: true,
    attributeFilter: ['data-source-dirty'],
  })
  scheduleEditorSync()
}
