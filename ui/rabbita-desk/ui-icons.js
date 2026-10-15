// A single glyph vocabulary shared by typed views and runtime controls.
// Names are fixed, never interpolated from messages or provider responses.
export const ICON_NAMES = Object.freeze([
  'files', 'changes', 'browser', 'terminal', 'compare', 'search',
  'selection', 'chat', 'split', 'settings', 'calendar', 'attach',
  'mic', 'mic-off', 'send', 'stop', 'more', 'fork',
  'queued', 'running', 'waiting', 'complete', 'failed', 'paused',
  'home', 'folder', 'book', 'code', 'workflow', 'package',
  'plus', 'close', 'check', 'edit', 'copy', 'trash',
  'refresh', 'undo', 'redo', 'save', 'upload', 'download',
  'external-link', 'link', 'pin', 'unpin', 'filter', 'history',
  'panel-left', 'panel-right', 'panel-bottom', 'expand', 'collapse',
  'chevron-left', 'chevron-right', 'chevron-up', 'chevron-down',
  'eye', 'eye-off', 'review', 'play', 'volume', 'volume-off',
  'image', 'camera', 'plug', 'unplug', 'help', 'info',
  'branch', 'commit', 'offline',
])

export function iconMarkup(name) {
  if (!ICON_NAMES.includes(name)) throw new Error(`Unknown UI icon: ${name}`)
  return `<span class="moon-icon" data-icon="${name}" aria-hidden="true"></span>`
}

export function setIconButton(button, name, label, { pressed } = {}) {
  const markup = iconMarkup(name)
  if (button.dataset.controlIcon !== name) {
    button.innerHTML = markup
    button.dataset.controlIcon = name
  }
  button.classList.add('moon-icon-button')
  button.setAttribute('aria-label', label)
  button.title = label
  button.dataset.tooltip = label
  if (pressed !== undefined) button.setAttribute('aria-pressed', String(pressed))
  return button
}

// Unknown states keep their text; only actual runtime state chooses a glyph.
export function statusIconName(status) {
  switch (String(status || '').toLowerCase()) {
    case 'queued': case 'pending': return 'queued'
    case 'running': case 'working': case 'in_progress': return 'running'
    case 'waiting': case 'needs_input': case 'awaiting_user': return 'waiting'
    case 'completed': case 'complete': case 'succeeded': case 'done': return 'complete'
    case 'failed': case 'error': return 'failed'
    case 'paused': case 'stopped': case 'cancelled': case 'canceled': return 'paused'
    default: return null
  }
}
