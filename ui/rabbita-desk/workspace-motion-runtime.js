// Presentation-only focus-guiding motion & embedded-host adaptation for MoonDesk.
// Never mutates application state or delays navigation.

let scheduled = false
let lastSurfaceKey = ''
let pinnedToBottom = true
let activeSessionId = ''
let lastTranscriptScrollHeight = 0
let lastTranscriptCount = 0
let prependAnchor = null
let userScrolledUp = false
let loadEarlierCooldownUntil = 0
let lastObservedTail = null
let tailResizeObserver = null
let previousScrollTop = 0
let lastUserScrollGestureAt = 0
const seenTranscriptKeys = new Map()
const observedTranscriptLists = new WeakSet()

function transcriptItemKey(el, index) {
  const itemId = el.dataset?.itemId || ''
  if (itemId) return itemId
  const role = el.dataset?.role || el.dataset?.testid || 'row'
  const turn = el.dataset?.clientTurnId || el.dataset?.commandId || ''
  return `${role}:${turn || index}`
}

function animateNewTranscriptItems(list, sessionId, skipAnimation = false) {
  if (prefersReducedMotion()) return
  const key = sessionId || '__default__'
  let seen = seenTranscriptKeys.get(key)
  const initialLoad = !seen
  if (!seen) {
    seen = new Set()
    seenTranscriptKeys.set(key, seen)
  }
  const children = list.children || []
  for (let i = 0; i < children.length; i++) {
    const el = children[i]
    if (el.dataset?.testid === 'mooncode-load-earlier') continue
    const id = transcriptItemKey(el, i)
    if (!seen.has(id)) {
      seen.add(id)
      // Animate ONLY newly appended tail messages; never flash initial history or prepended chunks.
      if (!initialLoad && !skipAnimation && i >= children.length - 2 && el.dataset) {
        el.dataset.mdNew = 'true'
        setTimeout(() => {
          if (el.dataset?.mdNew === 'true') delete el.dataset.mdNew
        }, 240)
      }
    }
  }
}

function scrollListToBottom(list) {
  if (!list) return
  list.scrollTop = list.scrollHeight
  previousScrollTop = list.scrollTop
  lastTranscriptScrollHeight = list.scrollHeight
}

function pinTranscriptBottomNowAndAfterPaint(list) {
  if (!list || !pinnedToBottom || prependAnchor) return
  scrollListToBottom(list)
  requestAnimationFrame(() => {
    if (pinnedToBottom && !prependAnchor && list.isConnected) {
      scrollListToBottom(list)
      // Catch asynchronous markdown/syntax/image expansion after first paint
      setTimeout(() => {
        if (pinnedToBottom && !prependAnchor && list.isConnected) {
          scrollListToBottom(list)
        }
      }, 90)
    }
  })
}

function observeTailElement(list) {
  if (typeof ResizeObserver === 'undefined') return
  const tail = list.lastElementChild
  if (!tail || tail === lastObservedTail) return
  if (tailResizeObserver) {
    try { tailResizeObserver.disconnect() } catch {}
  }
  lastObservedTail = tail
  tailResizeObserver = new ResizeObserver(() => {
    if (pinnedToBottom && !prependAnchor && list.isConnected) {
      scrollListToBottom(list)
    }
  })
  tailResizeObserver.observe(tail)
}

function triggerProgressiveLoadEarlier(list) {
  const now = Date.now()
  if (now < loadEarlierCooldownUntil) return
  const btn = list.querySelector('[data-testid="mooncode-load-earlier"]')
  if (!btn || btn.disabled) return
  loadEarlierCooldownUntil = now + 260
  prependAnchor = {
    scrollHeight: list.scrollHeight,
    scrollTop: list.scrollTop,
  }
  btn.click()
}

function syncTranscriptScroll(doc = globalThis.document) {
  const center = doc?.querySelector?.('[data-testid="mooncode-center"]')
  const sessionId = center?.dataset?.sessionId || ''
  const list = doc?.querySelector?.('.code-workbench .mooncode-transcript-list')
  if (!list) return
  const sessionChanged = sessionId !== activeSessionId
  if (sessionChanged) {
    activeSessionId = sessionId
    pinnedToBottom = true
    userScrolledUp = false
    prependAnchor = null
    previousScrollTop = 0
    lastTranscriptScrollHeight = 0
    lastTranscriptCount = 0
  }
  if (!list.dataset.mdScrollBound) {
    list.dataset.mdScrollBound = 'true'
    const markGesture = () => { lastUserScrollGestureAt = Date.now() }
    list.addEventListener('wheel', markGesture, { passive: true })
    list.addEventListener('touchstart', markGesture, { passive: true })
    list.addEventListener('pointerdown', markGesture, { passive: true })
    list.addEventListener('scroll', () => {
      const currentTop = list.scrollTop
      const distance = list.scrollHeight - currentTop - list.clientHeight
      const nearBottom = distance <= 96
      const scrolledUp = currentTop < previousScrollTop - 4
      const recentUserGesture = Date.now() - lastUserScrollGestureAt < 600
      if (nearBottom) {
        pinnedToBottom = true
        userScrolledUp = false
      } else if (scrolledUp || recentUserGesture) {
        pinnedToBottom = false
        userScrolledUp = true
      }
      previousScrollTop = currentTop
      // Progressive load earlier history smoothly as the user scrolls near the top
      if (userScrolledUp && currentTop <= 140 && list.scrollHeight > list.clientHeight + 40) {
        triggerProgressiveLoadEarlier(list)
      }
    }, { passive: true })
  }
  if (typeof ResizeObserver !== 'undefined' && !observedTranscriptLists.has(list)) {
    observedTranscriptLists.add(list)
    new ResizeObserver(() => {
      if (pinnedToBottom && !prependAnchor) scrollListToBottom(list)
    }).observe(list)
  }
  const restoringPrepend = Boolean(prependAnchor)
  animateNewTranscriptItems(list, sessionId, restoringPrepend)
  observeTailElement(list)
  const count = list.children ? list.children.length : 0
  if (prependAnchor && list.scrollHeight !== prependAnchor.scrollHeight) {
    const delta = list.scrollHeight - prependAnchor.scrollHeight
    list.scrollTop = prependAnchor.scrollTop + delta
    lastTranscriptScrollHeight = list.scrollHeight
    lastTranscriptCount = count
    prependAnchor = null
    return
  }
  if (sessionChanged || count !== lastTranscriptCount || list.scrollHeight !== lastTranscriptScrollHeight) {
    lastTranscriptCount = count
    if (pinnedToBottom && !prependAnchor) {
      pinTranscriptBottomNowAndAfterPaint(list)
    } else {
      lastTranscriptScrollHeight = list.scrollHeight
    }
  }
}

function bindSmoothDisclosures(doc = globalThis.document) {
  if (prefersReducedMotion() || doc?.documentElement?.dataset?.mdDisclosureBound) return
  if (doc?.documentElement?.dataset) doc.documentElement.dataset.mdDisclosureBound = 'true'
  doc.addEventListener('click', (event) => {
    const summary = event.target?.closest?.(
      '.mooncode-thinking-card > summary, .mooncode-activity-disclosure > summary, .mooncode-evidence > summary'
    )
    if (!summary) return
    const details = summary.parentElement
    if (!details || details.tagName !== 'DETAILS' || typeof details.animate !== 'function') return
    event.preventDefault()
    if (details._mdAnim) {
      try { details._mdAnim.cancel() } catch {}
    }
    const startHeight = details.offsetHeight
    const isClosing = details.open
    if (isClosing) {
      const endHeight = summary.offsetHeight + 2
      details.style.overflow = 'hidden'
      const anim = details.animate(
        [{ height: `${startHeight}px` }, { height: `${endHeight}px` }],
        { duration: 170, easing: 'cubic-bezier(.22, 1, .36, 1)' }
      )
      details._mdAnim = anim
      anim.onfinish = () => {
        details.open = false
        details.style.overflow = ''
        details._mdAnim = null
      }
      anim.oncancel = () => {
        details.style.overflow = ''
        details._mdAnim = null
      }
    } else {
      details.open = true
      const endHeight = details.offsetHeight
      details.style.overflow = 'hidden'
      const anim = details.animate(
        [{ height: `${startHeight}px` }, { height: `${endHeight}px` }],
        { duration: 190, easing: 'cubic-bezier(.22, 1, .36, 1)' }
      )
      details._mdAnim = anim
      anim.onfinish = () => {
        details.style.overflow = ''
        details._mdAnim = null
        const list = details.closest('.mooncode-transcript-list')
        if (list && pinnedToBottom) scrollListToBottom(list)
      }
      anim.oncancel = () => {
        details.style.overflow = ''
        details._mdAnim = null
      }
    }
  })
}

function syncComposerAutoGrow(doc = globalThis.document) {
  const input = doc?.querySelector?.('.code-workbench .mooncode-input')
  if (!input) return
  const resize = () => {
    input.style.height = 'auto'
    const next = Math.max(40, Math.min(220, input.scrollHeight || 40))
    input.style.height = `${next}px`
  }
  if (!input.dataset.mdGrowBound) {
    input.dataset.mdGrowBound = 'true'
    input.addEventListener('input', resize)
    input.addEventListener('keydown', (e) => {
      if (e.key === 'Enter' && !e.shiftKey && !e.isComposing) {
        pinnedToBottom = true
      }
    })
    resize()
  } else if (input.value === '') {
    input.style.height = '40px'
  }
}

export function isEmbeddedInHost(win = globalThis.window) {
  try {
    return Boolean(win && win.self !== win.top)
  } catch {
    // Cross-origin frame access throws SecurityError -> definitely embedded.
    return true
  }
}

function prefersReducedMotion(win = globalThis.window) {
  try {
    return Boolean(win?.matchMedia?.('(prefers-reduced-motion: reduce)')?.matches)
  } catch {
    return false
  }
}

export function syncModeIndicator(doc = globalThis.document) {
  const toggle = doc?.querySelector?.('.title-bar .workspace-mode-toggle')
  if (!toggle) return false
  const active = toggle.querySelector('.mode-button.active')
  if (!active) return false
  let indicator = toggle.querySelector('.md-mode-indicator')
  if (!indicator) {
    indicator = doc.createElement('span')
    indicator.className = 'md-mode-indicator'
    indicator.setAttribute('aria-hidden', 'true')
    toggle.prepend(indicator)
  }
  const hostBox = toggle.getBoundingClientRect()
  const btnBox = active.getBoundingClientRect()
  if (btnBox.width <= 0) return false
  const x = btnBox.left - hostBox.left + (toggle.scrollLeft || 0)
  indicator.style.width = `${btnBox.width}px`
  indicator.style.transform = `translateX(${x}px)`
  indicator.style.opacity = '1'
  toggle.dataset.indicatorReady = 'true'
  return true
}

function pulseDestinationEntrance(doc = globalThis.document) {
  if (prefersReducedMotion()) return
  const surface = doc?.querySelector?.('.file-desk-main, .wiki-workspace, .mooncode-pane, .flow-workspace')
  if (!surface) return
  const key = surface.className
  if (key === lastSurfaceKey) return
  lastSurfaceKey = key
  surface.dataset.mdEntering = 'true'
  setTimeout(() => {
    if (surface.dataset.mdEntering === 'true') delete surface.dataset.mdEntering
  }, 260)
}

let wikiPinnedToBottom = true
let wikiPreviousScrollTop = 0
let wikiLastScrollHeight = 0
let wikiLastUserGestureAt = 0

function syncWikiChatScroll(doc = globalThis.document) {
  const thread = doc?.querySelector?.('[data-testid="wiki-chat-thread"]')
  if (!thread) return
  if (!thread.dataset.mdWikiScrollBound) {
    thread.dataset.mdWikiScrollBound = 'true'
    const markGesture = () => { wikiLastUserGestureAt = Date.now() }
    thread.addEventListener('wheel', markGesture, { passive: true })
    thread.addEventListener('touchstart', markGesture, { passive: true })
    thread.addEventListener('pointerdown', markGesture, { passive: true })
    thread.addEventListener('scroll', () => {
      const currentTop = thread.scrollTop
      const distance = thread.scrollHeight - currentTop - thread.clientHeight
      const nearBottom = distance <= 84
      const scrolledUp = currentTop < wikiPreviousScrollTop - 4
      const recentGesture = Date.now() - wikiLastUserGestureAt < 600
      if (nearBottom) {
        wikiPinnedToBottom = true
      } else if (scrolledUp || recentGesture) {
        wikiPinnedToBottom = false
      }
      wikiPreviousScrollTop = currentTop
    }, { passive: true })
  }
  if (thread.scrollHeight !== wikiLastScrollHeight) {
    wikiLastScrollHeight = thread.scrollHeight
    if (wikiPinnedToBottom) {
      thread.scrollTop = thread.scrollHeight
      wikiPreviousScrollTop = thread.scrollTop
      requestAnimationFrame(() => {
        if (wikiPinnedToBottom && thread.isConnected) {
          thread.scrollTop = thread.scrollHeight
          wikiPreviousScrollTop = thread.scrollTop
        }
      })
    }
  }
}

function enhance() {
  scheduled = false
  if (typeof document === 'undefined') return
  if (isEmbeddedInHost()) {
    document.documentElement.dataset.embedded = 'moonproj'
  }
  syncModeIndicator(document)
  pulseDestinationEntrance(document)
  syncTranscriptScroll(document)
  syncWikiChatScroll(document)
  syncComposerAutoGrow(document)
  bindSmoothDisclosures(document)
}

function schedule() {
  if (scheduled) return
  scheduled = true
  requestAnimationFrame(enhance)
}

export function installWorkspaceMotion() {
  if (typeof document === 'undefined') return
  if (isEmbeddedInHost()) {
    document.documentElement.dataset.embedded = 'moonproj'
  }
  schedule()
  const root = document.getElementById('app') || document.body
  if (root && typeof MutationObserver !== 'undefined') {
    new MutationObserver(schedule).observe(root, {
      childList: true,
      subtree: true,
      characterData: true,
      attributes: true,
      attributeFilter: ['class', 'aria-pressed', 'aria-selected', 'data-session-id'],
    })
  }
  document.addEventListener('click', (event) => {
    const loadEarlier = event.target?.closest?.('[data-testid="mooncode-load-earlier"]')
    if (loadEarlier) {
      const list = loadEarlier.closest('.mooncode-transcript-list')
      if (list && !prependAnchor) {
        prependAnchor = {
          scrollHeight: list.scrollHeight,
          scrollTop: list.scrollTop,
        }
      }
      return
    }
    if (event.target?.closest?.('[data-testid="mooncode-send"]')) {
      pinnedToBottom = true
      userScrolledUp = false
      prependAnchor = null
    }
    if (event.target?.closest?.('.wiki-chat-composer button[type="submit"]')) {
      wikiPinnedToBottom = true
    }
    const moongateLink = event.target?.closest?.('[data-testid="moonclaw-open-moongate"]')
    if (moongateLink && moongateLink.href) {
      if (isEmbeddedInHost() && window.parent && window.parent !== window) {
        event.preventDefault()
        window.parent.postMessage({ type: 'moonsuite:open-url', url: moongateLink.href }, '*')
      }
      return
    }
    const anchor = event.target?.closest?.('a[href]')
    if (anchor && anchor.href && isEmbeddedInHost() && window.parent && window.parent !== window) {
      if (/^http:\/\/127\.0\.0\.1:4173\b/.test(anchor.href)) {
        event.preventDefault()
        window.parent.postMessage({ type: 'moonsuite:navigate', url: anchor.href }, '*')
      }
    }
  })
  window.addEventListener('resize', schedule)
}
