function installMoonDeskShellStartup() {
  if (globalThis.__moondeskShellStartupInstalled) return
  globalThis.__moondeskShellStartupInstalled = true

  let commandPalette = null
  let commandPaletteReturnFocus = null

  const isVisibleControl = (element) => {
    if (!(element instanceof HTMLElement) || !element.isConnected) return false
    const rect = element.getBoundingClientRect()
    const style = getComputedStyle(element)
    return rect.width > 0 &&
      rect.height > 0 &&
      style.display !== 'none' &&
      style.visibility !== 'hidden' &&
      element.getAttribute('aria-hidden') !== 'true' &&
      !element.matches(':disabled')
  }

  const isEditableTarget = (element) =>
    element instanceof HTMLInputElement ||
    element instanceof HTMLTextAreaElement ||
    element instanceof HTMLSelectElement ||
    (element instanceof HTMLElement && element.isContentEditable)

  const rememberCommandPaletteTrigger = (fallback = null) => {
    const focused = document.activeElement
    const candidate = isVisibleControl(focused) ? focused : fallback
    if (isVisibleControl(candidate)) commandPaletteReturnFocus = candidate
  }

  const commandPaletteFocusables = (panel) =>
    [...panel.querySelectorAll(
      'a[href], button, input, textarea, select, [tabindex]:not([tabindex="-1"])'
    )].filter(isVisibleControl)

  const commandPaletteCommands = (panel) =>
    [...panel.querySelectorAll('.palette-command')].filter(isVisibleControl)

  const syncCommandPaletteFocus = () => {
    const next = document.querySelector('[data-testid="command-palette-panel"]')
    if (next === commandPalette) return

    const previous = commandPalette
    commandPalette = next instanceof HTMLElement ? next : null
    if (commandPalette) {
      if (!commandPaletteReturnFocus) rememberCommandPaletteTrigger()
      requestAnimationFrame(() => {
        const input = commandPalette?.querySelector(
          '[data-testid="command-palette-input"]'
        )
        if (isVisibleControl(input)) input.focus()
      })
      return
    }

    if (previous) {
      const restore = isVisibleControl(commandPaletteReturnFocus)
        ? commandPaletteReturnFocus
        : [...document.querySelectorAll(
            '[data-testid="command-palette-toggle"], [data-testid="primary-nav-summary"]'
          )].find(isVisibleControl)
      commandPaletteReturnFocus = null
      if (restore instanceof HTMLElement) requestAnimationFrame(() => restore.focus())
    }
  }

  new MutationObserver(syncCommandPaletteFocus).observe(document.documentElement, {
    childList: true,
    subtree: true,
  })

  const clickWhenReady = (testId, attempt = 0, clicked = false) => {
    const loaded = document.querySelector(
      '[data-testid="pack-product-card"], [data-testid="desk-workspace-row"]'
    )
    const empty = document.body.textContent?.includes('No domain packs are installed')
      || document.body.textContent?.includes('No MoonBooks in this workspace')
    if (loaded || (empty && attempt > 3)) return

    const button = document.querySelector(`[data-testid="${testId}"]`)
    let nextClicked = clicked
    if (!clicked && button && typeof button.click === 'function') {
      button.click()
      nextClicked = true
    }
    if (attempt < 30) {
      setTimeout(() => clickWhenReady(testId, attempt + 1, nextClicked), 300)
    }
  }

  document.addEventListener('click', (event) => {
    const trigger = event.target instanceof Element
      ? event.target.closest('[data-testid="command-palette-toggle"]')
      : null
    if (trigger) rememberCommandPaletteTrigger(trigger)

    const compactDestination = event.target instanceof Element
      ? event.target.closest('[data-testid^="compact-mode-"]')
      : null
    const compactNavigation = compactDestination?.closest(
      'details.primary-nav-compact'
    )
    if (
      compactDestination instanceof HTMLElement &&
      compactNavigation instanceof HTMLDetailsElement &&
      compactNavigation.open
    ) {
      compactNavigation.open = false
      requestAnimationFrame(() => {
        const summary = document.querySelector(
          '[data-testid="primary-nav-summary"]'
        )
        if (isVisibleControl(summary)) summary.focus()
      })
    }
  }, true)

  // Lepusa's WKWebView may not start Rabbita subscriptions until the first
  // interaction. Use the product's ordinary Refresh control so native users
  // arrive at the same loaded state as browser users without a mystery click.
  setTimeout(() => clickWhenReady('pack-home-refresh'), 150)

  document.addEventListener('keydown', (event) => {
    const palette = document.querySelector(
      '[data-testid="command-palette-panel"]'
    )
    if (palette instanceof HTMLElement && event.key === 'Tab') {
      const focusables = commandPaletteFocusables(palette)
      if (focusables.length === 0) {
        event.preventDefault()
        return
      }
      const first = focusables[0]
      const last = focusables[focusables.length - 1]
      const focused = document.activeElement
      if (!palette.contains(focused) ||
          (!event.shiftKey && focused === last) ||
          (event.shiftKey && focused === first)) {
        event.preventDefault()
        ;(event.shiftKey ? last : first).focus()
      }
      return
    }

    if (
      palette instanceof HTMLElement &&
      event.target instanceof HTMLElement &&
      event.target.dataset?.testid === 'command-palette-input'
    ) {
      const commands = commandPaletteCommands(palette)
      if (event.key === 'Enter' && commands.length > 0) {
        event.preventDefault()
        event.stopPropagation()
        commands[0].click()
        return
      }
      if ((event.key === 'ArrowDown' || event.key === 'ArrowUp') && commands.length > 0) {
        event.preventDefault()
        ;(event.key === 'ArrowDown' ? commands[0] : commands[commands.length - 1]).focus()
        return
      }
    }

    if (event.key === 'Escape') {
      if (palette instanceof HTMLElement) {
        const close = palette.querySelector(
          '[data-testid="command-palette-close"]'
        )
        if (!(close instanceof HTMLElement)) return
        event.preventDefault()
        event.stopPropagation()
        close.click()
        return
      }

      const focused = document.activeElement
      const disclosure = focused instanceof Element ? focused.closest('details[open]') : null
      const summary = disclosure?.querySelector(':scope > summary')
      if (!disclosure || !summary) return

      event.preventDefault()
      event.stopPropagation()
      disclosure.open = false
      summary.focus()
      return
    }

    if (!(event.metaKey || event.ctrlKey) || event.shiftKey) return
    if (isEditableTarget(event.target)) return
    const target = {
      '1': 'mode-desk',
      '2': 'mode-wiki',
      '3': 'mode-code',
      '4': 'mode-flow',
      '5': 'mode-packs',
      'k': 'command-palette-toggle',
    }[String(event.key || '').toLowerCase()]
    if (!target) return

    const button = document.querySelector(`[data-testid="${target}"]`)
    if (!button || typeof button.click !== 'function') return
    event.preventDefault()
    event.stopPropagation()
    if (target === 'command-palette-toggle') {
      rememberCommandPaletteTrigger(button)
    }
    button.click()
  }, true)
}

installMoonDeskShellStartup()

function workspaceEditorSplitBounds(body) {
  const rect = body.getBoundingClientRect()
  const splitter = body.querySelector('[data-action="resize-workspace-editors"]')
  const splitterWidth = splitter?.getBoundingClientRect().width || 9
  const minimum = Math.min(320, Math.max(220, (rect.width - splitterWidth) * 0.36))
  return {
    rect,
    minimum,
    maximum: Math.max(minimum, rect.width - splitterWidth - minimum),
  }
}

function setWorkspaceEditorSplit(body, sourceWidth) {
  const { rect, minimum, maximum } = workspaceEditorSplitBounds(body)
  const width = Math.min(maximum, Math.max(minimum, sourceWidth))
  body.style.setProperty('--workspace-editor-source-width', `${Math.round(width)}px`)
  const handle = body.querySelector('[data-action="resize-workspace-editors"]')
  if (handle instanceof HTMLElement && rect.width > 0) {
    handle.setAttribute('aria-valuemin', '25')
    handle.setAttribute('aria-valuemax', '75')
    handle.setAttribute('aria-valuenow', String(Math.round(width / rect.width * 100)))
  }
}

function syncWorkspaceEditorSplitter() {
  for (const body of document.querySelectorAll('.mooncode-workspace-editors-body')) {
    const handle = body.querySelector('[data-action="resize-workspace-editors"]')
    const source = body.querySelector('.source-editor')
    if (!(handle instanceof HTMLElement) || !(source instanceof HTMLElement)) continue
    const storedWidth = Number.parseFloat(
      body.style.getPropertyValue('--workspace-editor-source-width')
    )
    const width = Number.isFinite(storedWidth)
      ? storedWidth
      : source.getBoundingClientRect().width
    if (width > 0) setWorkspaceEditorSplit(body, width)
  }
}

function sourceEditorParts(element) {
  const surface = element instanceof Element
    ? element.closest('.source-editor')
    : null
  if (!(surface instanceof HTMLElement)) return null
  const editor = surface.querySelector('[data-testid="source-editor-input"]')
  const find = surface.querySelector('[data-testid="source-find"]')
  const result = surface.querySelector('[data-testid="source-find-result"]')
  const gutter = surface.querySelector('[data-testid="source-line-numbers"]')
  const cursor = surface.querySelector('[data-testid="source-cursor-position"]')
  if (!(editor instanceof HTMLTextAreaElement)) return null
  return { surface, editor, find, result, gutter, cursor }
}

function setTextContent(element, value) {
  if (element instanceof HTMLElement && element.textContent !== value) {
    element.textContent = value
  }
}

function sourceEditorMatches(parts) {
  if (!(parts?.find instanceof HTMLInputElement)) return []
  const query = parts.find.value
  if (!query) return []
  const haystack = parts.editor.value.toLocaleLowerCase()
  const needle = query.toLocaleLowerCase()
  const matches = []
  for (let offset = 0; offset <= haystack.length - needle.length;) {
    const start = haystack.indexOf(needle, offset)
    if (start < 0) break
    matches.push({ start, end: start + needle.length })
    offset = start + Math.max(needle.length, 1)
  }
  return matches
}

function syncSourceEditorChrome(element) {
  const parts = sourceEditorParts(element)
  if (!parts) return
  const { editor, gutter, cursor, result } = parts
  const lineCount = editor.value.split('\n').length
  setTextContent(
    gutter,
    Array.from({ length: lineCount }, (_, index) => String(index + 1)).join('\n')
  )
  if (gutter instanceof HTMLElement) gutter.scrollTop = editor.scrollTop

  const beforeCursor = editor.value.slice(0, editor.selectionStart)
  const line = beforeCursor.split('\n').length
  const lastBreak = beforeCursor.lastIndexOf('\n')
  const column = editor.selectionStart - lastBreak
  const selected = Math.max(0, editor.selectionEnd - editor.selectionStart)
  setTextContent(cursor, `Ln ${line}, Col ${column}${selected > 0 ? ` · ${selected} selected` : ''}`)

  const matches = sourceEditorMatches(parts)
  if (!(parts.find instanceof HTMLInputElement) || !parts.find.value) {
    setTextContent(result, 'No search')
    return
  }
  const active = matches.findIndex(match =>
    match.start === editor.selectionStart && match.end === editor.selectionEnd
  )
  setTextContent(result, matches.length === 0 ? '0 results' : `${active + 1 || 0}/${matches.length}`)
}

function selectSourceEditorMatch(element, direction) {
  const parts = sourceEditorParts(element)
  if (!parts) return
  const matches = sourceEditorMatches(parts)
  if (matches.length === 0) {
    syncSourceEditorChrome(parts.editor)
    return
  }
  const current = parts.editor.selectionStart
  let match
  if (direction < 0) {
    match = [...matches].reverse().find(candidate => candidate.start < current)
      || matches[matches.length - 1]
  } else {
    match = matches.find(candidate => candidate.start > current) || matches[0]
  }
  parts.editor.focus()
  parts.editor.setSelectionRange(match.start, match.end)
  syncSourceEditorChrome(parts.editor)
}

function indentSourceEditorSelection(editor, unindent) {
  const value = editor.value
  const start = editor.selectionStart
  const end = editor.selectionEnd
  if (!unindent && start === end) {
    editor.setRangeText('  ', start, end, 'end')
    editor.dispatchEvent(new Event('input', { bubbles: true }))
    syncSourceEditorChrome(editor)
    return
  }

  const lineStart = value.lastIndexOf('\n', Math.max(0, start - 1)) + 1
  const nextBreak = value.indexOf('\n', end)
  const lineEnd = nextBreak < 0 ? value.length : nextBreak
  const lines = value.slice(lineStart, lineEnd).split('\n')
  const transformed = lines.map(line => {
    if (!unindent) return `  ${line}`
    if (line.startsWith('  ')) return line.slice(2)
    if (line.startsWith('\t') || line.startsWith(' ')) return line.slice(1)
    return line
  }).join('\n')
  editor.setRangeText(transformed, lineStart, lineEnd, 'select')
  if (start === end) {
    const removed = value.slice(lineStart, start).length - transformed.slice(0, Math.max(0, start - lineStart)).length
    const caret = Math.max(lineStart, start - Math.max(0, removed))
    editor.setSelectionRange(caret, caret)
  }
  editor.dispatchEvent(new Event('input', { bubbles: true }))
  syncSourceEditorChrome(editor)
}

function installWorkspaceEditorInteractions() {
  document.addEventListener('click', event => {
    const action = event.target instanceof Element
      ? event.target.closest('[data-action^="source-find-"]')
      : null
    if (!(action instanceof HTMLElement)) return
    if (action.dataset.action === 'source-find-previous') {
      selectSourceEditorMatch(action, -1)
    } else if (action.dataset.action === 'source-find-next') {
      selectSourceEditorMatch(action, 1)
    }
  }, true)

  document.addEventListener('input', event => {
    if (!(event.target instanceof Element)) return
    if (event.target.matches('[data-testid="source-editor-input"], [data-testid="source-find"]')) {
      syncSourceEditorChrome(event.target)
    }
  }, true)

  document.addEventListener('scroll', event => {
    if (event.target instanceof Element && event.target.matches('[data-testid="source-editor-input"]')) {
      syncSourceEditorChrome(event.target)
    }
  }, true)

  document.addEventListener('selectionchange', () => {
    const active = document.activeElement
    if (active instanceof HTMLTextAreaElement && active.matches('[data-testid="source-editor-input"]')) {
      syncSourceEditorChrome(active)
    }
  })

  document.addEventListener('pointerdown', event => {
    const handle = event.target instanceof Element
      ? event.target.closest('[data-action="resize-workspace-editors"]')
      : null
    const body = handle?.closest('.mooncode-workspace-editors-body')
    if (!(handle instanceof HTMLElement) || !(body instanceof HTMLElement)) return

    event.preventDefault()
    const bounds = workspaceEditorSplitBounds(body)
    const savedCursor = document.body.style.cursor
    const savedUserSelect = document.body.style.userSelect
    document.body.style.cursor = 'ew-resize'
    document.body.style.userSelect = 'none'
    handle.classList.add('is-dragging')

    const move = moveEvent => {
      setWorkspaceEditorSplit(body, moveEvent.clientX - bounds.rect.left)
    }
    const finish = () => {
      window.removeEventListener('pointermove', move)
      window.removeEventListener('pointerup', finish)
      window.removeEventListener('pointercancel', finish)
      document.body.style.cursor = savedCursor
      document.body.style.userSelect = savedUserSelect
      handle.classList.remove('is-dragging')
      handle.focus()
    }
    window.addEventListener('pointermove', move)
    window.addEventListener('pointerup', finish, { once: true })
    window.addEventListener('pointercancel', finish, { once: true })
  }, true)

  document.addEventListener('keydown', event => {
    const handle = event.target instanceof Element
      ? event.target.closest('[data-action="resize-workspace-editors"]')
      : null
    if (handle instanceof HTMLElement) {
      const body = handle.closest('.mooncode-workspace-editors-body')
      const source = body?.querySelector('.source-editor')
      if (!(body instanceof HTMLElement) || !(source instanceof HTMLElement)) return
      const current = source.getBoundingClientRect().width
      const direction = event.key === 'ArrowLeft' ? -1 : event.key === 'ArrowRight' ? 1 : 0
      if (direction !== 0) {
        event.preventDefault()
        setWorkspaceEditorSplit(body, current + direction * (event.shiftKey ? 64 : 24))
      }
      return
    }

    const target = event.target
    const parts = sourceEditorParts(target)
    if (!parts) return
    if (target instanceof HTMLInputElement && target.matches('[data-testid="source-find"]')) {
      if (event.key === 'Enter') {
        event.preventDefault()
        selectSourceEditorMatch(target, event.shiftKey ? -1 : 1)
      } else if (event.key === 'Escape') {
        event.preventDefault()
        parts.editor.focus()
      }
      return
    }

    const editor = target
    if (!(editor instanceof HTMLTextAreaElement) || !editor.matches('[data-testid="source-editor-input"]')) return
    if (event.key === 'Tab' && !editor.disabled) {
      event.preventDefault()
      indentSourceEditorSelection(editor, event.shiftKey)
      return
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f') {
      if (parts.find instanceof HTMLInputElement && !parts.find.disabled) {
        event.preventDefault()
        parts.find.focus()
        parts.find.select()
      }
      return
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'g') {
      event.preventDefault()
      selectSourceEditorMatch(editor, event.shiftKey ? -1 : 1)
      return
    }
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 's') {
      const save = editor.closest('.source-editor')?.querySelector('[data-testid="source-save"]')
      if (save instanceof HTMLButtonElement && !save.disabled) {
        event.preventDefault()
        save.click()
      }
    }
  }, true)
}

installWorkspaceEditorInteractions()

let sourceEditorRuntimeLoading = false

function loadSourceEditorRuntime() {
  if (sourceEditorRuntimeLoading || !document.querySelector('[data-testid="source-editor-input"]')) return
  sourceEditorRuntimeLoading = true
  void import('./source-editor-runtime.js').then(module => {
    module.installSourceEditorRuntime()
  }).catch(error => {
    sourceEditorRuntimeLoading = false
    console.error('Source editor assistance failed to load', error)
  })
}

new MutationObserver(loadSourceEditorRuntime).observe(
  document.getElementById('app') || document.body,
  {
  childList: true,
  subtree: true,
  },
)
loadSourceEditorRuntime()

let mooncodeMarkdownRuntimeLoading = false

function loadMoonCodeMarkdownRuntime() {
  if (mooncodeMarkdownRuntimeLoading || !document.querySelector('[data-testid="mooncode-markdown-source"]')) return
  mooncodeMarkdownRuntimeLoading = true
  void import('./mooncode-markdown-runtime.js').then(module => {
    module.installMoonCodeMarkdownRuntime()
  }).catch(error => {
    mooncodeMarkdownRuntimeLoading = false
    console.error('MoonCode Markdown route runtime failed to load', error)
  })
}

new MutationObserver(loadMoonCodeMarkdownRuntime).observe(
  document.getElementById('app') || document.body,
  { childList: true, subtree: true },
)
loadMoonCodeMarkdownRuntime()

let mooncodeTranscript = null
let mooncodeTranscriptKey = ''
let mooncodeStickToBottom = true
let mooncodeScrollFrame = 0

function mooncodeScrollDistance(list) {
  return list.scrollHeight - list.scrollTop - list.clientHeight
}

function mooncodeScrollTranscriptToBottom() {
  cancelAnimationFrame(mooncodeScrollFrame)
  mooncodeScrollFrame = requestAnimationFrame(() => {
    const list = document.querySelector('.mooncode-transcript-list')
    if (!list) return

    if (list !== mooncodeTranscript) {
      mooncodeTranscript = list
      mooncodeTranscriptKey = ''
      mooncodeStickToBottom = true
      list.addEventListener('scroll', () => {
        mooncodeStickToBottom = mooncodeScrollDistance(list) < 96
      }, { passive: true })
    }

    const messages = list.querySelectorAll('.mooncode-message')
    const last = messages[messages.length - 1]
    const key = `${messages.length}:${last?.textContent || ''}`
    if (key === mooncodeTranscriptKey) return

    const firstRender = mooncodeTranscriptKey === ''
    mooncodeTranscriptKey = key
    if (firstRender || mooncodeStickToBottom) {
      list.scrollTop = list.scrollHeight
      mooncodeStickToBottom = true
    }
  })
}

const app = document.getElementById('app')
new MutationObserver(mooncodeScrollTranscriptToBottom).observe(app || document.body, {
  childList: true,
  subtree: true,
})
mooncodeScrollTranscriptToBottom()
new MutationObserver(syncWorkspaceEditorSplitter).observe(app || document.body, {
  childList: true,
  subtree: true,
})
window.addEventListener('resize', syncWorkspaceEditorSplitter, { passive: true })
syncWorkspaceEditorSplitter()
new MutationObserver(() => {
  for (const editor of document.querySelectorAll('[data-testid="source-editor-input"]')) {
    syncSourceEditorChrome(editor)
  }
}).observe(app || document.body, {
  childList: true,
  subtree: true,
})
for (const editor of document.querySelectorAll('[data-testid="source-editor-input"]')) {
  syncSourceEditorChrome(editor)
}
