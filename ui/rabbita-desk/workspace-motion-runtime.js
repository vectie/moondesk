// Presentation-only focus-guiding motion & embedded-host adaptation for MoonDesk.
// Never mutates application state or delays navigation.

let scheduled = false
let lastSurfaceKey = ''

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

function enhance() {
  scheduled = false
  if (typeof document === 'undefined') return
  if (isEmbeddedInHost()) {
    document.documentElement.dataset.embedded = 'moonproj'
  }
  syncModeIndicator(document)
  pulseDestinationEntrance(document)
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
      attributes: true,
      attributeFilter: ['class', 'aria-pressed', 'aria-selected'],
    })
  }
  document.addEventListener('click', (event) => {
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
