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

await import('/main.js')

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
