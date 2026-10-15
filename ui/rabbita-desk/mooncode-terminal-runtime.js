import { Terminal } from '@xterm/xterm'
import { FitAddon } from '@xterm/addon-fit'
import { SearchAddon } from '@xterm/addon-search'
import { iconMarkup, setIconButton } from './ui-icons.js'
import '@xterm/xterm/css/xterm.css'
import './styles/mooncode-terminal.css'

const books = new Map()

async function request(workspaceId, id = '', payload, after) {
  const url = `/api/workspaces/${encodeURIComponent(workspaceId)}/terminals${id ? `/${encodeURIComponent(id)}` : ''}${after == null ? '' : `?after=${after}`}`
  const response = await fetch(url, payload === undefined ? {} : {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
  })
  const data = await response.json()
  if (!response.ok) {
    const error = new Error(data.error || data.message || `Terminal request failed (${response.status})`)
    error.status = response.status
    throw error
  }
  return data
}

function element(tag, className, text) {
  const node = document.createElement(tag)
  node.className = className
  if (text) node.textContent = text
  return node
}

function button(label, action) {
  const node = element('button', 'mooncode-terminal-button', label)
  node.type = 'button'
  node.title = label
  node.setAttribute('aria-label', label)
  node.addEventListener('click', action)
  return node
}

function report(book, error) {
  book.status.textContent = error instanceof Error ? error.message : String(error)
}

function active(book) { return book.sessions.get(book.selected) }

function fit(book, session) {
  if (!session || !session.host.isConnected || !session.host.getBoundingClientRect().width) return
  try {
    session.fit.fit()
    const size = `${session.term.cols}:${session.term.rows}`
    if (session.size !== size && session.status === -1) {
      session.size = size
      request(book.id, session.id, { action: 'resize', columns: session.term.cols, rows: session.term.rows }).catch(error => report(book, error))
    }
  } catch (error) { report(book, error) }
}

function select(book, id, focusTerminal = true) {
  book.selected = id
  sessionStorage.setItem(`moondesk.terminal.${book.id}`, id)
  for (const session of book.sessions.values()) {
    const selected = session.id === id
    session.host.hidden = !selected
    session.tab.setAttribute('aria-selected', String(selected))
    session.tab.tabIndex = selected ? 0 : -1
  }
  const session = active(book)
  book.empty.hidden = book.sessions.size > 0
  book.status.textContent = session
    ? `${session.title} · ${session.directory || 'Book root'} · ${session.status === -1 ? 'Running' : `Exited (${session.status})`}`
    : ''
  for (const control of book.sessionControls) control.disabled = !session
  book.actionsSummary.setAttribute('aria-disabled', String(!session))
  book.actionsSummary.tabIndex = session ? 0 : -1
  book.actions.open = false
  requestAnimationFrame(() => { fit(book, session); if (focusTerminal) session?.term.focus() })
}

function addSession(book, info) {
  if (book.sessions.has(info.id)) return book.sessions.get(info.id)
  const term = new Terminal({
    cursorBlink: true, scrollback: 10000, fontSize: 13,
    fontFamily: 'ui-monospace, SFMono-Regular, Menlo, Monaco, Consolas, monospace',
    theme: { background: '#131822', foreground: '#e3e8f0', cursor: '#c8dbff', selectionBackground: '#425576' },
    allowProposedApi: false, screenReaderMode: true,
  })
  const host = element('div', 'mooncode-terminal-screen')
  host.setAttribute('role', 'tabpanel')
  host.setAttribute('aria-label', info.title)
  host.dataset.terminalId = info.id
  host.id = `terminal-screen-${encodeURIComponent(book.id)}-${info.id}`
  const tab = button(info.title, () => select(book, info.id))
  tab.setAttribute('role', 'tab')
  tab.id = `terminal-tab-${encodeURIComponent(book.id)}-${info.id}`
  tab.setAttribute('aria-controls', host.id)
  host.setAttribute('aria-labelledby', tab.id)
  const fitAddon = new FitAddon()
  const search = new SearchAddon()
  term.loadAddon(fitAddon)
  term.loadAddon(search)
  book.screens.append(host)
  book.tabs.append(tab)
  term.open(host)
  const session = { ...info, term, host, tab, fit: fitAddon, search, offset: '0', size: '', queue: Promise.resolve(), polling: false }
  book.sessions.set(info.id, session)
  term.onData(data => {
    if (session.status !== -1) return
    session.queue = session.queue.then(() => request(book.id, info.id, { action: 'input', data })).catch(error => report(book, error))
  })
  term.attachCustomKeyEventHandler(event => {
    if ((event.metaKey || event.ctrlKey) && event.key.toLowerCase() === 'f' && event.type === 'keydown') {
      event.preventDefault(); book.search.focus(); return false
    }
    return true
  })
  return session
}

async function poll(book) {
  if (!book.shell.isConnected || document.hidden) return
  for (const session of book.sessions.values()) {
    if (session.polling || session.ended) continue
    session.polling = true
    try {
      const data = await request(book.id, session.id, undefined, session.offset)
      if (BigInt(data.start) > BigInt(session.offset)) session.term.write('\r\n[Older terminal output is no longer retained]\r\n')
      if (data.output) {
        const bytes = Uint8Array.from(atob(data.output), character => character.charCodeAt(0))
        await new Promise(resolve => session.term.write(bytes, resolve))
      }
      session.offset = String(data.next)
      session.status = data.status
      if (data.status !== -1 && !data.output) {
        session.ended = true
        session.term.write(`\r\n[Shell exited with code ${data.status}]\r\n`)
        if (book.selected === session.id) report(book, `Shell exited (${data.status}). Open a new terminal to continue.`)
      }
    } catch (error) {
      if (error.status === 404) {
        session.ended = true
        session.status = 0
        session.term.write('\r\n[This terminal session has ended. Open a new terminal to continue.]\r\n')
      }
      report(book, error)
    }
    finally { session.polling = false }
  }
}

async function refresh(book) {
  try {
    const data = await request(book.id)
    for (const info of data.sessions) addSession(book, info)
    const preferred = sessionStorage.getItem(`moondesk.terminal.${book.id}`)
    select(book, book.sessions.has(preferred) ? preferred : book.sessions.keys().next().value || '')
    await poll(book)
  } catch (error) { report(book, error) }
}

function createBook(workspaceId) {
  const shell = element('section', 'mooncode-interactive-terminal')
  shell.dataset.testid = 'mooncode-interactive-terminal'
  shell.setAttribute('aria-label', 'Interactive terminals')
  const tabs = element('div', 'mooncode-terminal-tabs')
  tabs.setAttribute('role', 'tablist')
  tabs.setAttribute('aria-label', 'Terminals in this Book')
  const toolbar = element('div', 'mooncode-terminal-toolbar')
  const screens = element('div', 'mooncode-terminal-screens')
  const status = element('p', 'mooncode-terminal-status', 'Loading terminals…')
  status.setAttribute('role', 'status')
  const empty = element('div', 'mooncode-terminal-empty', 'Open a terminal to run commands in this book.')
  const search = element('input', 'mooncode-terminal-search')
  search.type = 'search'
  search.placeholder = 'Find in terminal'
  search.setAttribute('aria-label', 'Find in terminal output')
  search.title = 'Find in terminal output (⌘/Ctrl+F)'
  const directory = element('input', 'mooncode-terminal-directory')
  directory.placeholder = 'Book root'
  directory.setAttribute('aria-label', 'Folder for new terminal, relative to this Book')
  directory.title = 'Folder for new terminal, relative to this book'
  const actions = element('details', 'mooncode-terminal-actions')
  const actionsSummary = element('summary', 'mooncode-terminal-button')
  setIconButton(actionsSummary, 'more', 'Terminal actions')
  actions.append(actionsSummary)
  actionsSummary.addEventListener('click', event => {
    if (!active(book)) event.preventDefault()
  })
  actions.addEventListener('keydown', event => {
    if (event.key === 'Escape') { actions.open = false; actionsSummary.focus() }
  })
  const book = { id: workspaceId, shell, tabs, screens, status, empty, search, sessions: new Map(), selected: '' }
  const newTerminal = button('New terminal', async () => {
    newTerminal.disabled = true
    report(book, 'Starting shell…')
    try {
      const info = await request(book.id, '', { directory: directory.value.trim(), columns: 100, rows: 30 })
      addSession(book, info)
      select(book, info.id)
      poll(book)
    } catch (error) { report(book, error) }
    finally { newTerminal.disabled = false }
  })
  newTerminal.innerHTML = `${iconMarkup('terminal')}<span>New</span>`
  const interrupt = button('Interrupt', () => {
    const session = active(book)
    if (session) request(book.id, session.id, { action: 'interrupt' }).catch(error => report(book, error))
  })
  setIconButton(interrupt, 'stop', 'Interrupt command (Ctrl+C)')
  const rename = button('Rename', () => {
    const session = active(book)
    if (!session) return
    actions.open = false
    const input = element('input', 'mooncode-terminal-rename')
    input.value = session.title
    input.setAttribute('aria-label', 'Terminal name')
    session.tab.replaceWith(input)
    input.focus(); input.select()
    let finished = false
    const finish = async save => {
      if (finished) return
      finished = true
      const title = input.value.trim()
      if (save && title) {
        try {
          await request(book.id, session.id, { action: 'rename', title })
          session.title = title; session.tab.textContent = title; session.tab.title = title; session.tab.setAttribute('aria-label', title); session.host.setAttribute('aria-label', title)
        } catch (error) { report(book, error) }
      }
      input.replaceWith(session.tab)
      select(book, session.id)
    }
    input.addEventListener('keydown', event => {
      if (event.key === 'Enter' || event.key === 'Escape') { event.preventDefault(); finish(event.key === 'Enter') }
    })
    input.addEventListener('blur', () => finish(true))
  })
  const close = button('Close terminal', async () => {
    const session = active(book)
    if (!session) return
    actions.open = false
    try {
      await request(book.id, session.id, { action: 'close' })
    } catch (error) {
      if (error.status !== 404) { report(book, error); return }
    }
    session.ended = true
    session.term.dispose(); session.host.remove(); session.tab.remove()
    book.sessions.delete(session.id)
    select(book, book.sessions.keys().next().value || '')
  })
  close.title = 'End this shell and its foreground command'
  const send = button('Ask about selection', () => {
    const session = active(book)
    const text = session?.term.getSelection()
    if (!text) { report(book, 'Select terminal output to attach it to your conversation.'); return }
    window.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: {
      kind: 'terminal', label: session.title, text, path: session.directory, workspaceId: book.id, action: 'ask',
    } }))
    report(book, 'Selected output added to the conversation.')
  })
  setIconButton(send, 'selection', 'Ask about selected output')
  function find(previous = false) {
    const session = active(book)
    if (!session || !search.value) return
    const found = previous ? session.search.findPrevious(search.value) : session.search.findNext(search.value)
    report(book, found ? `Found “${search.value}”` : `No match for “${search.value}”`)
  }
  search.addEventListener('keydown', event => {
    if (event.key === 'Enter') { event.preventDefault(); find(event.shiftKey) }
    if (event.key === 'Escape') active(book)?.term.focus()
  })
  tabs.addEventListener('keydown', event => {
    if (!['ArrowLeft', 'ArrowRight', 'Home', 'End'].includes(event.key)) return
    event.preventDefault()
    const ids = [...book.sessions.keys()]
    const index = ids.indexOf(book.selected)
    select(book, ids[event.key === 'Home' ? 0 : event.key === 'End' ? ids.length - 1 : (index + (event.key === 'ArrowRight' ? 1 : -1) + ids.length) % ids.length], false)
    active(book)?.tab.focus()
  })
  const previous = button('Previous match', () => find(true))
  previous.textContent = '↑'
  const next = button('Next match', () => find())
  next.textContent = '↓'
  const searchControls = element('div', 'mooncode-terminal-search-controls')
  searchControls.setAttribute('role', 'search')
  searchControls.setAttribute('aria-label', 'Search terminal output')
  searchControls.innerHTML = iconMarkup('search')
  searchControls.append(search, previous, next)
  const actionMenu = element('div', 'mooncode-terminal-action-menu')
  actionMenu.append(rename, close)
  actions.append(actionMenu)
  book.sessionControls = [interrupt, rename, close, send, search, previous, next]
  book.actions = actions
  book.actionsSummary = actionsSummary
  for (const control of book.sessionControls) control.disabled = true
  actionsSummary.setAttribute('aria-disabled', 'true')
  actionsSummary.tabIndex = -1
  toolbar.append(directory, newTerminal, interrupt, send, actions, searchControls)
  screens.append(empty)
  shell.append(tabs, toolbar, screens, status)
  new ResizeObserver(() => fit(book, active(book))).observe(screens)
  books.set(workspaceId, book)
  refresh(book)
  return book
}

export function installMoonCodeTerminal(root) {
  const panel = root.querySelector('[data-developer-tool-panel="terminal"]')
  if (!panel) return
  const workspaceId = root.dataset.workspaceId || ''
  const existing = panel.querySelector('.mooncode-interactive-terminal')
  if (existing?.dataset.workspaceId === workspaceId) return
  existing?.remove()
  if (!workspaceId) return
  let details = panel.querySelector('.mooncode-terminal-agent-evidence')
  if (!details) {
    details = element('details', 'mooncode-terminal-agent-evidence')
    const summary = element('summary', '', 'Agent command history')
    const previous = [...panel.childNodes]
    details.append(summary, ...previous)
    panel.append(details)
  }
  const book = books.get(workspaceId) || createBook(workspaceId)
  book.shell.dataset.workspaceId = workspaceId
  panel.prepend(book.shell)
  requestAnimationFrame(() => fit(book, active(book)))
}

setInterval(() => { for (const book of books.values()) poll(book) }, 200)
if (typeof document !== 'undefined') {
  new MutationObserver(() => {
    for (const root of document.querySelectorAll('[data-runtime="mooncode-developer-tools-v1"]')) installMoonCodeTerminal(root)
  }).observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-workspace-id'] })
}
