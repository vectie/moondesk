const HTTP_PROTOCOLS = new Set(['http:', 'https:'])
const OPEN_TOOL_STATES = new Set(['running', 'queued', 'pending', 'failed', 'cancelled', 'rejected', 'reverted', 'stale'])
const REASONING_OPTIONS = [
  ['none', 'Auto'],
  ['minimal', 'Minimal'],
  ['low', 'Low'],
  ['medium', 'Medium'],
  ['high', 'High'],
  ['xhigh', 'Extra high'],
]
let developerToolsOpen = false
let selectedDeveloperTool = 'terminal'
const DEVELOPER_TOOLS_OPEN_KEY = 'moondesk.mooncode.developerToolsOpen'

export function normalizeDeveloperBrowserUrl(value, base = globalThis.location?.href || 'http://127.0.0.1/') {
  const raw = String(value || '').trim()
  if (!raw || raw === 'about:blank') return 'about:blank'

  let candidate = raw
  if (/^(localhost|127(?:\.\d{1,3}){3})(:\d+)?(?:\/|$)/i.test(raw)) {
    candidate = `http://${raw}`
  }

  let url
  try {
    url = new URL(candidate, base)
  } catch {
    return null
  }
  return HTTP_PROTOCOLS.has(url.protocol) ? url.toString() : null
}

export function moonCodeCommandRequest(command) {
  const value = String(command || '').trim()
  return value ? `Run this command and report the complete command evidence:\n\n${value}` : ''
}

export function moonCodeToolStateOpens(state) {
  return OPEN_TOOL_STATES.has(state)
}

function wrapToolSection(node, label, kind) {
  if (!(node instanceof HTMLElement) || node.closest('.mooncode-tool-section')) return null
  const section = document.createElement('section')
  section.className = `mooncode-tool-section ${kind}`
  section.setAttribute('aria-label', label)
  const title = document.createElement('h3')
  title.className = 'mooncode-tool-section-title'
  title.textContent = label
  const body = document.createElement('div')
  body.className = 'mooncode-tool-section-body'
  node.before(section)
  body.append(node)
  section.append(title, body)
  return section
}

function enhanceEvidenceCard(card) {
  if (!(card instanceof HTMLDetailsElement) || card.dataset.toolDetailsInstalled === 'true') return
  card.dataset.toolDetailsInstalled = 'true'
  card.classList.add('mooncode-tool-card')
  const state = card.dataset.state || 'recorded'
  card.dataset.state = state
  card.open = moonCodeToolStateOpens(state) && !card.classList.contains('summary-only')
  card.dataset.defaultOpen = String(card.open)
  const summary = card.querySelector(':scope > .mooncode-evidence-summary')
  if (summary) {
    const kind = summary.querySelector('.mooncode-evidence-kind')?.textContent?.trim() || 'Tool'
    const title = summary.querySelector('.mooncode-evidence-title')?.textContent?.trim() || 'Details'
    summary.setAttribute('aria-label', `${kind}: ${title}. Status ${state}`)
  }
  const sections = []
  const detail = card.querySelector(':scope > .mooncode-evidence-detail')
  if (detail) sections.push(wrapToolSection(detail, 'Arguments / context', 'arguments'))
  for (const block of card.querySelectorAll(':scope > .mooncode-evidence-text')) {
    const label = block.querySelector('.mooncode-evidence-toolbar span')?.textContent?.trim() || ''
    const kind = label.startsWith('Command') ? 'command' : 'output'
    sections.push(wrapToolSection(block, label || (kind === 'command' ? 'Command' : 'Output'), kind))
  }
  const diff = card.querySelector(':scope > .mooncode-diff-shell')
  if (diff) sections.push(wrapToolSection(diff, 'Diff', 'diff'))
  const receipt = card.querySelector(':scope > .mooncode-sandbox-receipt')
  if (receipt) sections.push(wrapToolSection(receipt, 'Approval / receipt', 'receipt'))
  const order = { arguments: 0, command: 1, output: 2, diff: 3, receipt: 4 }
  sections.filter(Boolean).sort((a, b) => order[a.classList[1]] - order[b.classList[1]])
    .forEach(section => card.append(section))
}

function enhanceApprovalCard(card) {
  if (!(card instanceof HTMLElement) || card instanceof HTMLDetailsElement) return
  const state = card.dataset.state || 'recorded'
  const details = document.createElement('details')
  for (const attribute of card.attributes) details.setAttribute(attribute.name, attribute.value)
  details.classList.add('mooncode-tool-card')
  details.open = moonCodeToolStateOpens(state)
  details.dataset.defaultOpen = String(details.open)
  details.dataset.toolDetailsInstalled = 'true'
  const titleText = card.querySelector('.mooncode-approval-copy > strong')?.textContent?.trim() || 'Approval'
  const summary = document.createElement('summary')
  summary.className = 'mooncode-evidence-summary mooncode-approval-summary'
  summary.setAttribute('aria-label', `Approval: ${titleText}. Status ${state}`)
  for (const [className, text] of [
    ['mooncode-evidence-kind approval', 'Approval'],
    ['mooncode-evidence-title', titleText],
    [`mooncode-evidence-state ${state}`, state],
  ]) {
    const span = document.createElement('span')
    span.className = className
    span.textContent = text
    summary.append(span)
  }
  details.append(summary, ...card.childNodes)
  card.replaceWith(details)
  const technical = details.querySelector('.mooncode-approval-detail')
  if (technical) {
    technical.classList.add('mooncode-tool-section', 'receipt')
    technical.setAttribute('aria-label', 'Approval / receipt · Technical details')
    const technicalSummary = technical.querySelector('summary')
    if (technicalSummary) technicalSummary.textContent = 'Approval / receipt'
    const argumentsBlock = technical.querySelector('pre')
    if (argumentsBlock) wrapToolSection(argumentsBlock, 'Arguments', 'arguments')
  }
}

function enhanceToolTranscript(scope = document) {
  for (const card of scope.querySelectorAll('[data-testid="mooncode-evidence"]')) enhanceEvidenceCard(card)
  for (const card of scope.querySelectorAll('[data-testid="mooncode-approval"]')) enhanceApprovalCard(card)
}

function dispatchControlValue(root, kind, value) {
  const sync = root.querySelector(`[data-mooncode-control-sync="${kind}"]`)
  if (!(sync instanceof HTMLInputElement)) return
  sync.value = value
  sync.dispatchEvent(new InputEvent('input', {
    bubbles: true,
    composed: true,
    inputType: 'insertText',
    data: value,
  }))
}

function composerControl(title, kind, options, selected, disabled = false) {
  const label = document.createElement('label')
  label.className = `mooncode-composer-control mooncode-${kind}-control`
  const caption = document.createElement('span')
  caption.className = 'mooncode-composer-control-label'
  caption.textContent = title
  const select = document.createElement('select')
  select.className = 'mooncode-composer-select'
  select.dataset.testid = `mooncode-${kind}-select`
  select.setAttribute('aria-label', `MoonCode ${kind === 'model' ? 'model' : 'reasoning effort'}`)
  select.disabled = disabled
  for (const [value, text] of options) {
    const option = document.createElement('option')
    option.value = value
    option.textContent = text
    option.selected = value === selected
    select.append(option)
  }
  select.addEventListener('change', () => dispatchControlValue(label.parentElement, kind, select.value))
  label.append(caption, select)
  return label
}

function installComposerControls(root) {
  if (!(root instanceof HTMLElement) || root.dataset.controlsInstalled === 'true') return
  root.dataset.controlsInstalled = 'true'
  const models = String(root.dataset.models || '').split('\n').filter(Boolean)
  const modelOptions = models.length ? models.map(value => [value, value]) : [['', 'No models available']]
  root.prepend(
    composerControl('Model', 'model', modelOptions, root.dataset.selectedModel || '', models.length === 0),
    composerControl('Reasoning', 'reasoning', REASONING_OPTIONS, root.dataset.reasoning || 'none'),
  )
}

function ensureDeveloperToolsShell(root) {
  return root.querySelector('.mooncode-developer-tools-body') instanceof HTMLElement
}

function setStatus(root, message) {
  const status = root.querySelector('[data-testid="mooncode-developer-browser-status"]')
  if (status) status.textContent = message
}

function installTabs(root) {
  const select = selected => {
    selectedDeveloperTool = selected
    for (const candidate of root.querySelectorAll('[data-developer-tool-tab]')) {
      const active = candidate.dataset.developerToolTab === selected
      candidate.classList.toggle('active', active)
      candidate.setAttribute('aria-selected', String(active))
    }
    for (const panel of root.querySelectorAll('[data-developer-tool-panel]')) {
      panel.classList.toggle('active', panel.dataset.developerToolPanel === selected)
    }
    if (selected === 'compare') loadCompare(root)
  }
  select(selectedDeveloperTool)
  if (root.dataset.developerTabsInstalled === 'true') return
  root.dataset.developerTabsInstalled = 'true'
  root.addEventListener('click', (event) => {
    const tab = event.target instanceof Element
      ? event.target.closest('[data-developer-tool-tab]')
      : null
    if (!(tab instanceof HTMLButtonElement)) return
    select(tab.dataset.developerToolTab)
  })
}

function installTerminal(root) {
  const form = root.querySelector('[data-developer-terminal-form]')
  const input = root.querySelector('[data-testid="mooncode-developer-terminal-input"]')
  const status = root.querySelector('[data-testid="mooncode-developer-terminal-status"]')
  if (!(form instanceof HTMLFormElement) || !(input instanceof HTMLInputElement)) return

  form.addEventListener('submit', (event) => {
    event.preventDefault()
    const prompt = moonCodeCommandRequest(input.value)
    if (!prompt) return
    const composer = document.querySelector('[data-testid="mooncode-input"]')
    if (!(composer instanceof HTMLTextAreaElement)) {
      if (status) status.textContent = 'MoonCode composer is unavailable'
      return
    }
    if (composer.value.trim()) {
      if (status) status.textContent = 'MoonCode already has a draft; finish or clear it before sending this command'
      composer.focus()
      return
    }

    composer.value = prompt
    composer.dispatchEvent(new InputEvent('input', {
      bubbles: true,
      composed: true,
      inputType: 'insertText',
      data: prompt,
    }))
    input.value = ''
    if (status) status.textContent = 'Command request prepared for MoonCode'

    requestAnimationFrame(() => {
      const send = document.querySelector('[data-testid="mooncode-send"]')
      if (!(send instanceof HTMLButtonElement) || send.disabled) {
        if (status) status.textContent = 'Command request is in the MoonCode composer; review and send it there'
        composer.focus()
        return
      }
      send.click()
      if (status) status.textContent = 'Command request sent through MoonCode'
    })
  })
}

async function loadCompare(root) {
  if (root.dataset.compareInstalled === 'true' || root.dataset.compareLoading === 'true') return
  root.dataset.compareLoading = 'true'
  try {
    const { installMoonCodeCompare } = await import('./mooncode-compare-runtime.js')
    installMoonCodeCompare(root)
    root.dataset.compareInstalled = 'true'
  } finally {
    delete root.dataset.compareLoading
  }
}

function installCompareFromActions(scope = document) {
  for (const action of scope.querySelectorAll('[data-mooncode-compare-from]')) {
    if (!(action instanceof HTMLButtonElement) || action.dataset.compareActionInstalled === 'true') continue
    action.dataset.compareActionInstalled = 'true'
    action.addEventListener('click', async () => {
      const root = document.querySelector('[data-runtime="mooncode-developer-tools-v1"]')
      if (!(root instanceof HTMLDetailsElement)) return
      developerToolsOpen = true
      globalThis.sessionStorage?.setItem(DEVELOPER_TOOLS_OPEN_KEY, 'true')
      await loadCompare(root)
      const { openMoonCodeCompareFrom } = await import('./mooncode-compare-runtime.js')
      openMoonCodeCompareFrom(root, action)
    })
  }
}

function installBrowser(root) {
  const panel = root.querySelector('[data-developer-tool-panel="browser"]')
  const frame = root.querySelector('[data-testid="mooncode-developer-browser-frame"]')
  const address = root.querySelector('[data-testid="mooncode-developer-browser-address"]')
  const form = root.querySelector('[data-developer-browser-address-form]')
  if (!(panel instanceof HTMLElement) ||
      !(frame instanceof HTMLIFrameElement) ||
      !(address instanceof HTMLInputElement) ||
      !(form instanceof HTMLFormElement)) return

  const initial = normalizeDeveloperBrowserUrl(root.dataset.initialUrl) || 'about:blank'
  const history = [initial]
  let cursor = 0

  const updateButtons = () => {
    const back = root.querySelector('[data-developer-browser-action="back"]')
    const forward = root.querySelector('[data-developer-browser-action="forward"]')
    if (back instanceof HTMLButtonElement) back.disabled = cursor === 0
    if (forward instanceof HTMLButtonElement) forward.disabled = cursor >= history.length - 1
  }

  const load = (target, { record = true } = {}) => {
    const normalized = normalizeDeveloperBrowserUrl(target)
    if (!normalized) {
      setStatus(root, 'Only HTTP and HTTPS preview addresses are supported')
      address.setAttribute('aria-invalid', 'true')
      return false
    }
    address.removeAttribute('aria-invalid')
    if (record && normalized !== history[cursor]) {
      history.splice(cursor + 1)
      history.push(normalized)
      cursor = history.length - 1
    }
    address.value = normalized
    frame.src = normalized
    setStatus(root, normalized === 'about:blank' ? 'Enter a preview address' : 'Loading isolated preview')
    updateButtons()
    return true
  }

  form.addEventListener('submit', (event) => {
    event.preventDefault()
    load(address.value)
  })

  root.addEventListener('click', (event) => {
    const action = event.target instanceof Element
      ? event.target.closest('[data-developer-browser-action]')
      : null
    if (!(action instanceof HTMLButtonElement)) return
    switch (action.dataset.developerBrowserAction) {
      case 'back':
        if (cursor > 0) {
          cursor -= 1
          load(history[cursor], { record: false })
        }
        break
      case 'forward':
        if (cursor < history.length - 1) {
          cursor += 1
          load(history[cursor], { record: false })
        }
        break
      case 'reload':
        frame.src = history[cursor]
        setStatus(root, 'Reloading isolated preview')
        break
      case 'open-external': {
        const target = normalizeDeveloperBrowserUrl(address.value)
        if (!target || target === 'about:blank') {
          setStatus(root, 'Enter a valid HTTP or HTTPS address first')
          break
        }
        globalThis.open?.(target, '_blank', 'noopener,noreferrer')
        setStatus(root, 'Opened current address externally')
        break
      }
    }
  })

  frame.addEventListener('load', () => {
    setStatus(root, frame.src === 'about:blank' ? 'Enter a preview address' : 'Ready · isolated preview')
  })
  updateButtons()
}

function installRoot(root) {
  if (!(root instanceof HTMLElement)) return
  if (['terminal', 'browser', 'compare'].includes(root.dataset.preferredTool)) {
    selectedDeveloperTool = root.dataset.preferredTool
  }
  const shellReady = ensureDeveloperToolsShell(root)
  if (!shellReady || root.dataset.developerToolsInstalled === 'true') return
  root.dataset.developerToolsInstalled = 'true'
  delete root.dataset.compareInstalled
  delete root.dataset.compareLoading
  import('./mooncode-terminal-evidence-runtime.js').then(({ projectCommandEvidence }) => {
    projectCommandEvidence(root)
  })
  installTabs(root)
  installTerminal(root)
  installBrowser(root)
  import('./mooncode-browser-evidence-runtime.js').then(({ installMoonCodeBrowserEvidence }) => {
    installMoonCodeBrowserEvidence(root)
  })
  developerToolsOpen = developerToolsOpen || root.open || globalThis.sessionStorage?.getItem(DEVELOPER_TOOLS_OPEN_KEY) === 'true'
  root.open = developerToolsOpen
  if (root.dataset.developerToggleInstalled !== 'true') {
    root.dataset.developerToggleInstalled = 'true'
    root.addEventListener('toggle', () => {
      developerToolsOpen = root.open
      globalThis.sessionStorage?.setItem(DEVELOPER_TOOLS_OPEN_KEY, String(root.open))
    })
  }
}

export function installMoonCodeDeveloperTools(scope = document) {
  enhanceToolTranscript(scope)
  installCompareFromActions(scope)
  for (const root of scope.querySelectorAll('[data-runtime="mooncode-composer-controls-v1"]')) {
    installComposerControls(root)
  }
  for (const root of scope.querySelectorAll('[data-runtime="mooncode-developer-tools-v1"]')) {
    installRoot(root)
  }
}

if (typeof document !== 'undefined') {
  installMoonCodeDeveloperTools()
  new MutationObserver(() => installMoonCodeDeveloperTools()).observe(document.documentElement, {
    childList: true,
    subtree: true,
  })
}
