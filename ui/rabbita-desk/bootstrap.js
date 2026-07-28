import '/styles.css'
import '/styles/product-shell.css'
import '/styles/mooncode-workflow.css'
import '/styles/mooncode.css'
import '/styles/moondesk-ux.css'

const app = document.getElementById('app')

if (app) {
  app.innerHTML = `
    <div class="boot-shell">
      <div class="boot-panel">
        <p class="eyebrow">MoonDesk</p>
        <h1>Loading workspace</h1>
        <p>Preparing the explorer, previews, inspector, and activity drawer.</p>
      </div>
    </div>
  `
}

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

  const clickWhenReady = (testId, attempt = 0) => {
    const button = document.querySelector(`[data-testid="${testId}"]`)
    if (button && typeof button.click === 'function') {
      button.click()
      const loaded = document.querySelector('[data-testid="pack-product-card"], [data-testid="desk-workspace-row"]')
      const empty = document.body.textContent?.includes('No domain packs are installed')
        || document.body.textContent?.includes('No MoonBooks in this workspace')
      if (loaded || (empty && attempt > 3)) return
    }
    if (attempt < 30) {
      setTimeout(() => clickWhenReady(testId, attempt + 1), 300)
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

// Do not await the long-lived Rabbita entrypoint. WKWebView defers timers owned
// by a module whose top-level await never settles, which would suppress native
// startup recovery and shell shortcuts until the first manual interaction.
void import('/main.js')

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

new MutationObserver(mooncodeScrollTranscriptToBottom).observe(app || document.body, {
  childList: true,
  subtree: true,
})
mooncodeScrollTranscriptToBottom()
