import '/styles.css'
import '/styles/product-shell.css'
import '/styles/mooncode.css'

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

  const clickWhenReady = (testId, attempt = 0) => {
    const button = document.querySelector(`[data-testid="${testId}"]`)
    if (button && typeof button.click === 'function') {
      button.click()
      const loaded = document.querySelector('[data-testid="desk-workspace-row"]')
      const empty = document.body.textContent?.includes('No MoonBooks in this workspace')
      if (loaded || (empty && attempt > 3)) return
    }
    if (attempt < 30) {
      setTimeout(() => clickWhenReady(testId, attempt + 1), 300)
    }
  }

  // Lepusa's WKWebView may not start Rabbita subscriptions until the first
  // interaction. Use the product's ordinary Refresh control so native users
  // arrive at the same loaded state as browser users without a mystery click.
  setTimeout(() => clickWhenReady('desk-refresh-workspaces'), 150)

  document.addEventListener('keydown', (event) => {
    if (!(event.metaKey || event.ctrlKey) || event.shiftKey) return
    const target = {
      '1': 'mode-desk',
      '2': 'mode-wiki',
      '3': 'mode-code',
      '4': 'mode-flow',
      'k': 'command-palette-toggle',
    }[String(event.key || '').toLowerCase()]
    if (!target) return

    const button = document.querySelector(`[data-testid="${target}"]`)
    if (!button || typeof button.click !== 'function') return
    event.preventDefault()
    event.stopPropagation()
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
