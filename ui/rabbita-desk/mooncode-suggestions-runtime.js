import { conversationSuggestions, suggestionSignature } from './mooncode-suggestions-model.js'
import './styles/mooncode-suggestions.css'

const records = new Map()
let scheduled = false

function readRecord(key) {
  if (records.has(key)) return records.get(key)
  let record = { signature: '', items: [], dismissed: [], hidden: false }
  try { const saved = JSON.parse(localStorage.getItem(key)); if (saved && Array.isArray(saved.items) && Array.isArray(saved.dismissed)) record = saved } catch {}
  records.set(key, record)
  return record
}

function persist(key, record) {
  records.set(key, record)
  try { localStorage.setItem(key, JSON.stringify(record)) } catch {}
}

function currentInput(root) {
  const messages = [...root.querySelectorAll('.mooncode-message')]
  const assistant = messages.filter(message => message.dataset.role === 'assistant').at(-1)
  const user = messages.filter(message => message.dataset.role === 'user').at(-1)
  const latestCommand = [...root.querySelectorAll('.mooncode-tool-card')].filter(card => card.querySelector('.mooncode-tool-section.command pre')).at(-1)
  const failure = latestCommand?.dataset.state === 'failed' ? latestCommand : null
  return {
    answer: assistant?.querySelector('.mooncode-message-body')?.textContent?.trim().slice(-6000) || '',
    user: user?.querySelector('.mooncode-message-body')?.textContent?.trim().slice(0, 1600) || '',
    status: assistant?.dataset.status || '',
    failedCommand: failure?.querySelector('.mooncode-tool-section.command pre')?.textContent?.trim().slice(0, 2000) || '',
    selectedPath: root.querySelector('[data-runtime="mooncode-developer-tools-v1"]')?.dataset.sourcePath || '',
  }
}

function makeButton(text, action, title) {
  const button = document.createElement('button')
  button.type = 'button'
  button.textContent = text
  if (title) button.title = title
  button.addEventListener('click', action)
  return button
}

export function installMoonCodeSuggestions() {
  const root = document.querySelector('[data-testid="mooncode-center"]')
  const composer = root?.querySelector('.mooncode-composer')
  if (!composer) return
  const input = currentInput(root)
  // Streaming text should not reshuffle suggestions while an answer arrives.
  if (['running', 'streaming', 'pending'].includes(input.status)) {
    composer.querySelector('.mooncode-suggestions')?.remove()
    return
  }
  const key = `moondesk.suggestions.${root.dataset.workspaceId || 'general'}.${root.dataset.sessionId || 'new'}`
  const signature = suggestionSignature(input)
  let record = readRecord(key)
  if (record.signature !== signature) {
    record = { signature, items: conversationSuggestions(input), dismissed: [], hidden: record.hidden }
    persist(key, record)
  }
  const renderKey = `${key}:${signature}:${record.hidden}:${record.dismissed.join(',')}`
  const previous = composer.querySelector('.mooncode-suggestions')
  if (previous?.dataset.renderKey === renderKey) return
  previous?.remove()
  if (!record.items.length) return
  const shell = document.createElement('section')
  shell.className = 'mooncode-suggestions'
  shell.dataset.renderKey = renderKey
  shell.dataset.testid = 'mooncode-suggestions'
  shell.setAttribute('aria-label', 'Suggested next steps based on this conversation')
  const heading = document.createElement('div')
  heading.className = 'mooncode-suggestions-heading'
  const title = document.createElement('span')
  title.textContent = 'Suggested next steps'
  title.title = 'Contextual shortcuts from this conversation. Choosing one adds it to your draft; it never sends automatically.'
  const toggle = makeButton(record.hidden ? 'Show' : 'Hide', () => {
    record.hidden = !record.hidden
    persist(key, record)
    installMoonCodeSuggestions()
  })
  toggle.setAttribute('aria-expanded', String(!record.hidden))
  heading.append(title, toggle)
  shell.append(heading)
  if (!record.hidden) {
    const items = document.createElement('div')
    items.className = 'mooncode-suggestions-items'
    for (const suggestion of record.items.filter(item => !record.dismissed.includes(item.id))) {
      const group = document.createElement('div')
      group.className = 'mooncode-suggestion'
      const choose = makeButton(suggestion.label, () => {
        const field = root.querySelector('[data-testid="mooncode-input"]')
        if (!field) return
        field.value = `${field.value}${field.value.trim() ? '\n\n' : ''}${suggestion.text}`
        field.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertText', data: suggestion.text }))
        field.focus()
      }, suggestion.reason)
      const dismiss = makeButton('×', () => {
        record.dismissed.push(suggestion.id)
        persist(key, record)
        installMoonCodeSuggestions()
      })
      dismiss.className = 'mooncode-suggestion-dismiss'
      dismiss.setAttribute('aria-label', `Dismiss ${suggestion.label}`)
      group.append(choose, dismiss)
      items.append(group)
    }
    if (!items.children.length) items.append(makeButton('Show suggestions again', () => {
      record.dismissed = []
      persist(key, record)
      installMoonCodeSuggestions()
    }))
    shell.append(items)
  }
  const field = composer.querySelector('.composer-field')
  if (field) field.before(shell)
  else composer.prepend(shell)
}

if (typeof document !== 'undefined') {
  installMoonCodeSuggestions()
  new MutationObserver(() => {
    if (scheduled) return
    scheduled = true
    requestAnimationFrame(() => { scheduled = false; installMoonCodeSuggestions() })
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-session-id', 'data-status', 'data-workspace-id', 'data-source-path'] })
}
