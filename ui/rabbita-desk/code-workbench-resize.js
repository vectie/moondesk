import { createColumnResizeControl } from './column-resize-control.js'
const clamp = (value, min, max) => Math.max(min, Math.min(max, value))
const storageKey = 'moondesk.code-columns'

export function columnSizes(width, navigation = 240) {
  const navMax = Math.max(180, Math.min(420, width - 640))
  return { navigation: Math.round(clamp(navigation, 180, navMax)), navMax }
}
export function chatColumn(width, fraction = 0.49) {
  return Math.round(clamp(width * fraction, 360, Math.max(360, width - 360)))
}
export function createWorkbenchResizing(surface, onResize = () => {}) {
  const shell = surface.closest('.code-main'), workbench = surface.querySelector('.code-workbench')
  if (!shell || !workbench) return null
  const doc = surface.ownerDocument, win = doc.defaultView
  let saved
  try { saved = JSON.parse(win.localStorage.getItem(storageKey)) } catch { /* Optional preference. */ }
  let navigation = Number.isFinite(saved?.navigation) ? saved.navigation : 240
  let fraction = Number.isFinite(saved?.fraction) ? saved.fraction : 0.49
  const controls = []
  const set = (el, name, value) => { if (el.getAttribute(name) !== value) el.setAttribute(name, value) }
  const style = (el, name, value) => { if (el.style.getPropertyValue(name) !== value) el.style.setProperty(name, value) }
  function refresh() {
    if (!surface.isConnected) return
    style(shell, '--code-navigation-width', `${columnSizes(shell.clientWidth, navigation).navigation}px`)
    set(shell, 'data-resizable-columns', 'true')
    set(surface, 'data-column-layout', surface.clientWidth >= 800 ? 'split' : 'single')
    style(surface, '--code-chat-width', `${chatColumn(surface.clientWidth, fraction)}px`)
    controls.forEach(control => control.refresh())
    onResize()
  }
  const persist = () => {
    try { win.localStorage.setItem(storageKey, JSON.stringify({ navigation, fraction })) } catch { /* Optional preference. */ }
  }
  const chat = workbench.querySelector('.mooncode-chat-surface')
  if (chat) chat.id = 'code-chat-pane'
  controls.push(createColumnResizeControl(doc, {
    id: 'navigation', label: 'Resize conversation list', controls: 'code-chat-navigation',
    bounds: () => [180, columnSizes(shell.clientWidth).navMax],
    value: () => columnSizes(shell.clientWidth, navigation).navigation,
    change: value => { navigation = value; refresh() },
    reset: () => { navigation = 240; refresh() }, persist,
    rect: () => {
      const rect = shell.querySelector('.mooncode-rail')?.getBoundingClientRect()
      return shell.dataset.navigation === 'open' && win.innerWidth >= 1100 && rect?.height
        ? { x: rect.right, top: rect.top, height: rect.height } : null
    },
  }))
  controls.push(createColumnResizeControl(doc, {
    id: 'chat', label: 'Resize chat and work panels', controls: 'code-chat-pane code-workbench-panel',
    bounds: () => [360, Math.max(360, surface.clientWidth - 360)],
    value: () => chatColumn(surface.clientWidth, fraction),
    change: value => { fraction = value / surface.clientWidth; refresh() },
    reset: () => { fraction = 0.49; refresh() }, persist,
    rect: () => {
      const rect = chat?.getBoundingClientRect()
      return surface.dataset.workbenchFocus === 'split' && surface.clientWidth >= 800 && rect?.height
        ? { x: rect.right, top: rect.top, height: rect.height } : null
    },
  }))
  const observer = new win.ResizeObserver(refresh)
  observer.observe(shell)
  observer.observe(surface)
  refresh()
  return { refresh, dispose() {
    observer.disconnect()
    controls.forEach(control => control.dispose())
    shell.style.removeProperty('--code-navigation-width')
    shell.removeAttribute('data-resizable-columns')
    surface.style.removeProperty('--code-chat-width')
    surface.removeAttribute('data-column-layout')
  } }
}
