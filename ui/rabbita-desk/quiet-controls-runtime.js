// Presentation only: predictable dismissal and one unclipped tooltip layer.
const popupSelector = '[data-popup], details.desk-toolbar-disclosure, details.primary-nav-compact, details.toolbar-disclosure'
const iconSelector = '.moon-icon-button[aria-label], .mooncode-composer-icon-button[aria-label]'
const dismissing = new WeakSet()

export function tooltipPosition(anchor, size, viewport, gap = 8) {
  const left = Math.max(gap, Math.min(anchor.left + (anchor.width - size.width) / 2, viewport.width - size.width - gap))
  const below = anchor.bottom + gap
  const top = below + size.height <= viewport.height - gap
    ? below : Math.max(gap, anchor.top - size.height - gap)
  return { left, top }
}

export function dismissPopup(panel, { restoreFocus = false, document: doc = document } = {}) {
  if (dismissing.has(panel)) return
  const trigger = panel.dataset.popupTrigger
    ? doc.querySelector(panel.dataset.popupTrigger)
    : panel.querySelector(':scope > summary')
  if (panel.tagName === 'DETAILS') panel.open = false
  else {
    const close = panel.querySelector('[data-popup-dismiss]')
    if (close) {
      // Typed views unmount after dispatch. Pointerdown and focusin may both
      // arrive before that render; dispatch the toggle only once per panel.
      dismissing.add(panel)
      const previous = close.dataset.popupRestoreFocus
      close.dataset.popupRestoreFocus = String(restoreFocus)
      close.click()
      if (previous === undefined) delete close.dataset.popupRestoreFocus
      else close.dataset.popupRestoreFocus = previous
    }
  }
  if (restoreFocus) trigger?.focus()
}

export function installQuietControls(doc = document, win = window) {
  if (doc.documentElement.dataset.quietControls === 'ready') return
  doc.documentElement.dataset.quietControls = 'ready'
  const tooltip = doc.createElement('div')
  tooltip.className = 'moon-control-tooltip'
  tooltip.id = 'moon-control-tooltip'
  tooltip.setAttribute('role', 'tooltip')
  tooltip.hidden = true
  doc.body.append(tooltip)
  let owner = null
  let pending = null
  let previousTitle = null

  function hideTooltip() {
    win.clearTimeout(pending)
    pending = null
    if (owner) {
      const described = (owner.getAttribute('aria-describedby') || '').split(/\s+/).filter(id => id && id !== tooltip.id)
      if (described.length) owner.setAttribute('aria-describedby', described.join(' '))
      else owner.removeAttribute('aria-describedby')
      if (previousTitle !== null && !owner.hasAttribute('title')) owner.setAttribute('title', previousTitle)
    }
    owner = null
    previousTitle = null
    tooltip.hidden = true
  }

  function showTooltip(control, immediate = false) {
    if (owner === control && !tooltip.hidden) return
    hideTooltip()
    owner = control
    const show = () => {
      if (owner !== control || !control.isConnected || !control.getClientRects().length) return hideTooltip()
      tooltip.textContent = control.getAttribute('aria-label') || control.title
      if (!tooltip.textContent) return hideTooltip()
      previousTitle = control.getAttribute('title')
      control.removeAttribute('title')
      tooltip.hidden = false
      const position = tooltipPosition(control.getBoundingClientRect(), tooltip.getBoundingClientRect(), { width: win.innerWidth, height: win.innerHeight })
      tooltip.style.left = `${position.left}px`
      tooltip.style.top = `${position.top}px`
      const described = (control.getAttribute('aria-describedby') || '').split(/\s+/).filter(Boolean)
      if (!described.includes(tooltip.id)) described.push(tooltip.id)
      control.setAttribute('aria-describedby', described.join(' '))
    }
    if (immediate) show()
    else pending = win.setTimeout(show, 400)
  }

  function popups() {
    return [...doc.querySelectorAll(popupSelector)].filter(panel =>
      !dismissing.has(panel) && panel.getClientRects().length && (panel.tagName !== 'DETAILS' || panel.open))
  }
  function triggerFor(panel) {
    return panel.dataset.popupTrigger ? doc.querySelector(panel.dataset.popupTrigger) : panel.querySelector(':scope > summary')
  }
  function onPointerOver(event) {
    if (event.pointerType === 'touch') return
    const control = event.target.closest?.(iconSelector)
    if (control) showTooltip(control)
  }
  function onPointerOut(event) {
    if (owner && !owner.contains(event.relatedTarget)) hideTooltip()
  }
  function onFocusIn(event) {
    for (const panel of popups().filter(item => item.tagName !== 'DETAILS')) {
      if (!panel.contains(event.target) && !triggerFor(panel)?.contains(event.target)) dismissPopup(panel, { document: doc })
    }
    const control = event.target.closest?.(iconSelector)
    if (control) showTooltip(control, true)
    else hideTooltip()
  }
  function onPointerDown(event) {
    hideTooltip()
    for (const panel of popups().reverse()) {
      if (!panel.contains(event.target) && !triggerFor(panel)?.contains(event.target)) dismissPopup(panel, { document: doc })
    }
  }
  function onKeyDown(event) {
    if (event.key !== 'Escape' || event.defaultPrevented) return
    if (doc.querySelector('[data-testid="command-palette-panel"]')) return
    // A native disclosure nested inside a panel gets the first Escape.
    const candidates = popups()
    const disclosure = event.target.closest?.('details[open]')
    const nested = disclosure && candidates.some(item => item === disclosure || item.contains(disclosure)) ? disclosure : null
    const panel = nested || candidates.findLast(item => item.contains(event.target)) || candidates.at(-1)
    if (panel) {
      hideTooltip()
      dismissPopup(panel, { restoreFocus: true, document: doc })
      event.preventDefault()
      event.stopImmediatePropagation()
    } else if (!tooltip.hidden) {
      hideTooltip()
      event.preventDefault()
      event.stopImmediatePropagation()
    }
  }
  function onToggle(event) {
    const panel = event.target
    if (!panel.matches?.(popupSelector) || !panel.open) return
    for (const other of popups()) {
      if (other !== panel && !other.contains(panel) && !panel.contains(other)) dismissPopup(other, { document: doc })
    }
  }
  doc.addEventListener('pointerover', onPointerOver)
  doc.addEventListener('pointerout', onPointerOut)
  doc.addEventListener('focusin', onFocusIn)
  doc.addEventListener('focusout', hideTooltip)
  doc.addEventListener('pointerdown', onPointerDown)
  doc.addEventListener('click', event => {
    const close = event.target.closest?.('[data-popup-dismiss]')
    const panel = close?.closest('[data-popup]')
    const trigger = panel && triggerFor(panel)
    if (trigger && close.dataset.popupRestoreFocus !== 'false') win.requestAnimationFrame(() => trigger.isConnected && trigger.focus())
  }, true)
  doc.addEventListener('toggle', onToggle, true)
  const seen = new WeakSet()
  const observer = new MutationObserver(() => {
    for (const panel of popups().filter(item => item.tagName !== 'DETAILS')) {
      if (seen.has(panel)) continue
      seen.add(panel)
      for (const other of popups()) {
        if (other !== panel && !other.contains(panel) && !panel.contains(other)) dismissPopup(other, { document: doc })
      }
      panel.querySelector('[data-popup-dismiss]')?.focus()
    }
    if (owner && !owner.isConnected) hideTooltip()
  })
  observer.observe(doc.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-popup'] })
  // Window capture owns presentation Escape before shell/document handlers.
  win.addEventListener('keydown', onKeyDown, true)
  win.addEventListener('resize', hideTooltip)
  win.addEventListener('scroll', hideTooltip, true)
}

if (typeof document !== 'undefined' && typeof window !== 'undefined') installQuietControls()
