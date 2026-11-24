import { uiText } from './ui-locale.js'
const clamp = (value, min, max) => Math.max(min, Math.min(max, value))

// Outside Rabbita's reconciled tree: main/section nodes are reused between pages.
export function createColumnResizeControl(doc, config) {
  const win = doc.defaultView, handle = doc.createElement('div')
  handle.className = 'workspace-column-resizer'
  handle.style.zIndex = String(config.layer || 20)
  handle.id = `workspace-resize-${config.id}`
  handle.dataset.columnResize = config.id
  handle.tabIndex = 0
  handle.setAttribute('role', 'separator')
  handle.setAttribute('aria-label', uiText(config.label))
  handle.setAttribute('aria-controls', config.controls)
  handle.title = uiText('Drag to resize; click for options')
  const menu = doc.createElement('details')
  menu.className = 'code-column-resize-menu'
  menu.dataset.popup = 'true'
  menu.dataset.popupTrigger = `#${handle.id}`
  menu.setAttribute('aria-label', uiText(config.label))
  const summary = doc.createElement('summary')
  summary.hidden = true
  menu.append(summary)
  let drag = null, frame = null, nextX = null, ignoreClick = false
  const horizontal = () => config.orientation?.() === 'horizontal'
  const direction = () => typeof config.direction === 'function' ? config.direction() : config.direction || 1
  const coordinate = event => (drag ? drag.horizontal : horizontal()) ? event.clientY : event.clientX
  const apply = pixels => { const [min, max] = config.bounds(); config.change(clamp(pixels, min, max)) }
  const buttons = []
  for (const [name, amount] of [['Narrower', -32], ['Wider', 32], ['Reset width', 0]]) {
    const button = doc.createElement('button')
    button.type = 'button'
    button.textContent = uiText(name)
    button.addEventListener('click', () => {
      if (amount) apply(config.value() + amount)
      else config.reset()
      config.persist()
      menu.open = false
      refresh()
      handle.focus({ preventScroll: true })
    })
    menu.append(button)
    buttons.push(button)
  }
  doc.body.append(handle, menu)
  function refresh() {
    const rect = config.rect()
    handle.hidden = !rect
    if (!rect) { menu.open = false; return }
    const row = horizontal()
    const label = uiText(row && config.rowLabel ? config.rowLabel : config.label)
    if (handle.getAttribute('aria-label') !== label) handle.setAttribute('aria-label', label)
    if (menu.getAttribute('aria-label') !== label) menu.setAttribute('aria-label', label)
    handle.classList.toggle('workspace-row-resizer', row)
    handle.setAttribute('aria-orientation', row ? 'horizontal' : 'vertical')
    const labels = row ? ['Shorter', 'Taller', 'Reset height'] : ['Narrower', 'Wider', 'Reset width']
    buttons.forEach((button, index) => { const text = uiText(labels[index]); if (button.textContent !== text) button.textContent = text })
    const geometry = row
      ? { left: `${rect.left}px`, top: `${rect.y - 6}px`, width: `${rect.width}px`, height: '12px' }
      : { left: `${rect.x - 6}px`, top: `${rect.top}px`, width: '12px', height: `${rect.height}px` }
    for (const [key, value] of Object.entries(geometry)) {
      if (handle.style[key] !== value) handle.style[key] = value
    }
    const [min, max] = config.bounds()
    for (const [key, value] of Object.entries({ 'aria-valuemin': min, 'aria-valuemax': max, 'aria-valuenow': Math.round(config.value()) })) {
      if (handle.getAttribute(key) !== String(value)) handle.setAttribute(key, value)
    }
  }
  function finish(cancel = false) {
    if (!drag) return
    if (frame !== null) win.cancelAnimationFrame(frame)
    frame = null
    const previous = drag
    if (cancel) apply(previous.width)
    else if (nextX !== null) apply(previous.width + (nextX - previous.x) * previous.direction)
    nextX = null
    drag = null
    ignoreClick = previous.moved
    doc.body.classList.remove('is-resizing-workspace')
    doc.body.classList.remove('is-resizing-workspace-row')
    handle.classList.remove('is-dragging')
    if (handle.hasPointerCapture?.(previous.id)) handle.releasePointerCapture(previous.id)
    if (!cancel) config.persist()
    refresh()
  }
  const openMenu = event => {
    const rect = handle.getBoundingClientRect()
    menu.style.left = `${clamp(rect.right + 6, 8, win.innerWidth - 156)}px`
    menu.style.top = `${clamp(event?.clientY || rect.top + 80, 8, win.innerHeight - 140)}px`
    menu.open = true
    menu.querySelector('button').focus({ preventScroll: true })
  }
  handle.addEventListener('pointerdown', event => {
    if (event.button !== 0) return
    event.preventDefault()
    menu.open = false
    handle.focus({ preventScroll: true })
    drag = { id: event.pointerId, x: coordinate(event), horizontal: horizontal(), direction: direction(), width: config.value(), moved: false }
    ignoreClick = false
    handle.setPointerCapture(event.pointerId)
    doc.body.classList.add('is-resizing-workspace')
    doc.body.classList.toggle('is-resizing-workspace-row', drag.horizontal)
    handle.classList.add('is-dragging')
  })
  handle.addEventListener('pointermove', event => {
    if (!drag || event.pointerId !== drag.id) return
    if (Math.abs(coordinate(event) - drag.x) > 3) drag.moved = true
    if (!drag.moved) return
    nextX = coordinate(event)
    if (frame !== null) return
    frame = win.requestAnimationFrame(() => {
      frame = null
      if (drag && nextX !== null) apply(drag.width + (nextX - drag.x) * drag.direction)
      refresh()
    })
  })
  handle.addEventListener('pointerup', () => finish())
  handle.addEventListener('pointercancel', () => finish(true))
  handle.addEventListener('lostpointercapture', () => finish())
  handle.addEventListener('click', event => {
    if (ignoreClick) { ignoreClick = false; return }
    openMenu(event)
  })
  handle.addEventListener('keydown', event => {
    if (event.key === 'Escape' && drag) { event.preventDefault(); finish(true); return }
    if (event.key === 'Enter' || event.key === ' ') { event.preventDefault(); openMenu(); return }
    const [min, max] = config.bounds(), step = (event.shiftKey ? 64 : 16) * direction()
    const pixels = event.key === (horizontal() ? 'ArrowUp' : 'ArrowLeft') ? config.value() - step
      : event.key === (horizontal() ? 'ArrowDown' : 'ArrowRight') ? config.value() + step
      : event.key === 'Home' ? min : event.key === 'End' ? max : null
    if (pixels === null) return
    event.preventDefault()
    apply(pixels)
    config.persist()
    refresh()
  })
  refresh()
  return { refresh, dispose() { finish(true); handle.remove(); menu.remove() } }
}
