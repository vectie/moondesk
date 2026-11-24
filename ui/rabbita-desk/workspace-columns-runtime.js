import { createColumnResizeControl } from './column-resize-control.js'
import { createWorkbenchResizing } from './code-workbench-resize.js'
import { resizePrompt } from './code-workbench-runtime.js'

export const columnDestinations = [
  { id: 'desk', selector: '.file-desk-main', pane: '.desk-sidebar', variable: '--workspace-rail', rowVariable: '--desk-sidebar-height', rowInitial: 220, rowMin: 120, label: 'Resize book list', rowLabel: 'Resize book list height', initial: 240, min: 180, max: 420 },
  { id: 'book', selector: '.wiki-focus-workspace', pane: '.wiki-chat', variable: '--wiki-chat-width', rowVariable: '--wiki-chat-height', rowInitial: 0.42, rowMin: 220, label: 'Resize document chat', rowLabel: 'Resize document chat height', initial: 0.38, min: 280, max: 900, ratio: true },
  { id: 'desk-details', selector: '.desk-inspector[open] > .desk-details', variable: '--desk-details-width', label: 'Resize file details', initial: 300, min: 260, max: 640, right: true, layer: 26 },
  { id: 'packs', selector: '.pack-home-main > .pack-inspector', variable: '--pack-inspector-width', label: 'Resize pack details', initial: 380, min: 300, max: 760, right: true, layer: 161 },
]

export function createDestinationColumn(target, spec) {
  const doc = target.ownerDocument, win = doc.defaultView
  const pane = spec.pane ? target.querySelector(spec.pane) : target
  if (!pane) return null
  const key = `moondesk.columns.${spec.id}`
  let preferred = spec.initial, rowPreferred = spec.rowInitial
  try {
    const saved = JSON.parse(win.localStorage.getItem(key)), row = JSON.parse(win.localStorage.getItem(key + '.row'))
    if (Number.isFinite(saved)) preferred = saved
    if (Number.isFinite(row)) rowPreferred = row
  } catch { /* Optional preference. */ }
  const row = () => Boolean(spec.rowVariable && win.innerWidth <= 760)
  const total = () => row() ? target.clientHeight : spec.right ? win.innerWidth : target.clientWidth
  const bounds = () => row()
    ? [spec.rowMin, Math.max(spec.rowMin, total() - 240)]
    : [spec.min, Math.max(spec.min, Math.min(spec.max, total() - (spec.ratio ? 360 : 320)))]
  const value = () => {
    const [min, max] = bounds(), size = row() ? rowPreferred : preferred
    return Math.round(Math.max(min, Math.min(max, spec.ratio ? size * total() : size)))
  }
  let control
  function refresh() {
    if (!target.isConnected) return
    const pixels = `${value()}px`
    const variable = row() ? spec.rowVariable : spec.variable
    if (target.style.getPropertyValue(variable) !== pixels) target.style.setProperty(variable, pixels)
    if (target.dataset.resizablePane !== spec.id) target.dataset.resizablePane = spec.id
    control?.refresh()
  }
  control = createColumnResizeControl(doc, {
    id: spec.id, label: spec.label, controls: `workspace-pane-${spec.id}`, direction: spec.right ? -1 : 1, layer: spec.layer,
    orientation: () => row() ? 'horizontal' : 'vertical',
    rowLabel: spec.rowLabel,
    bounds, value,
    change: pixels => { if (row()) rowPreferred = spec.ratio ? pixels / total() : pixels; else preferred = spec.ratio ? pixels / total() : pixels; refresh() },
    reset: () => { if (row()) rowPreferred = spec.rowInitial; else preferred = spec.initial; refresh() },
    persist: () => { try { win.localStorage.setItem(key + (row() ? '.row' : ''), JSON.stringify(row() ? rowPreferred : preferred)) } catch { /* Optional preference. */ } },
    rect: () => {
      const rect = pane.getBoundingClientRect()
      if (row() && rect.width && rect.height) return { left: rect.left, y: rect.bottom, width: rect.width }
      return win.innerWidth > 760 && rect.width && rect.height
        ? { x: spec.right ? rect.left : rect.right, top: Math.max(0, rect.top), height: Math.min(win.innerHeight, rect.bottom) - Math.max(0, rect.top) } : null
    },
  })
  const previousId = pane.id
  pane.id = `workspace-pane-${spec.id}`
  const observer = new win.ResizeObserver(refresh)
  observer.observe(target)
  refresh()
  return { refresh, dispose() {
    observer.disconnect()
    control.dispose()
    target.style.removeProperty(spec.variable)
    if (spec.rowVariable) target.style.removeProperty(spec.rowVariable)
    target.removeAttribute('data-resizable-pane')
    if (previousId) pane.id = previousId; else pane.removeAttribute('id')
  } }
}

export function createComposerRow(target) {
  const doc = target.ownerDocument, win = doc.defaultView
  const input = target.querySelector('.mooncode-input'), composer = target.querySelector('.mooncode-composer')
  if (!input || !composer) return null
  const key = 'moondesk.code-composer-height'
  let preferred = null, control
  try { const saved = JSON.parse(win.localStorage.getItem(key)); if (Number.isFinite(saved)) preferred = saved } catch { /* Optional preference. */ }
  const bounds = () => [win.innerWidth <= 760 ? 44 : 40, Math.max(80, Math.min(300, Math.round(win.innerHeight * 0.4)))]
  const value = () => { const [min, max] = bounds(); return preferred === null ? input.getBoundingClientRect().height : Math.max(min, Math.min(max, preferred)) }
  function refresh() {
    if (preferred === null) { target.style.removeProperty('--code-composer-height'); target.removeAttribute('data-resizable-composer') }
    else {
      const [min, max] = bounds()
      target.style.setProperty('--code-composer-height', `${Math.max(min, Math.min(max, preferred))}`)
      target.dataset.resizableComposer = 'true'
    }
    resizePrompt(input)
    control?.refresh()
  }
  control = createColumnResizeControl(doc, {
    id: 'composer', label: 'Resize message input', controls: 'workspace-message-input', direction: -1,
    orientation: () => 'horizontal', bounds, value,
    change: pixels => { preferred = pixels; refresh() }, reset: () => { preferred = null; refresh() },
    persist: () => { try { win.localStorage.setItem(key, JSON.stringify(preferred)) } catch { /* Optional preference. */ } },
    rect: () => { const rect = composer.getBoundingClientRect(); return rect.width && rect.height ? { left: rect.left, y: rect.top, width: rect.width } : null },
  })
  const previousId = input.id
  input.id = 'workspace-message-input'
  const observer = new win.ResizeObserver(refresh)
  observer.observe(composer)
  refresh()
  return { refresh, dispose() {
    observer.disconnect(); control.dispose()
    target.style.removeProperty('--code-composer-height'); target.removeAttribute('data-resizable-composer')
    if (previousId) input.id = previousId; else input.removeAttribute('id')
  } }
}

// One lifecycle owner for all destinations. Renderer-reused nodes are checked
// through the current selector, not merely isConnected or their old identity.
export function installWorkspaceColumns(doc = document) {
  const win = doc.defaultView, mounted = new Map()
  const specs = [{ id: 'code', selector: '.code-main .mooncode-center' }, { id: 'composer', selector: '.code-main .mooncode-chat-surface:has(.mooncode-composer)' }, ...columnDestinations]
  let frame = null
  function refresh() {
    for (const spec of specs) {
      const target = doc.querySelector(spec.selector)
      let entry = mounted.get(spec.id)
      if (entry && entry.target !== target) { entry.controller.dispose(); mounted.delete(spec.id); entry = null }
      if (!target) continue
      if (!entry) {
        const controller = spec.id === 'code' ? createWorkbenchResizing(target, () => resizePrompt(target.querySelector('.mooncode-input')))
          : spec.id === 'composer' ? createComposerRow(target) : createDestinationColumn(target, spec)
        if (!controller) continue
        entry = { target, controller }
        mounted.set(spec.id, entry)
      }
      entry.controller.refresh()
    }
  }
  function schedule() {
    if (frame !== null) return
    frame = win.requestAnimationFrame(() => { frame = null; refresh() })
  }
  const observer = new win.MutationObserver(() => {
    // Teardown needs no layout reads: remove departed-page controls before
    // paint, while deferring new layout measurements to the next frame.
    for (const spec of specs) {
      const entry = mounted.get(spec.id)
      if (entry && (!entry.target.isConnected || !entry.target.matches(spec.selector))) {
        entry.controller.dispose()
        mounted.delete(spec.id)
      }
    }
    schedule()
  })
  observer.observe(doc.getElementById('app') || doc.body, { childList: true, subtree: true, attributes: true, attributeFilter: ['class', 'data-workbench-focus', 'data-navigation', 'open'] })
  win.addEventListener('resize', schedule)
  doc.addEventListener('scroll', schedule, true)
  refresh()
  return { refresh, dispose() {
    observer.disconnect()
    if (frame !== null) win.cancelAnimationFrame(frame)
    win.removeEventListener('resize', schedule)
    doc.removeEventListener('scroll', schedule, true)
    mounted.forEach(entry => entry.controller.dispose())
    mounted.clear()
  } }
}
