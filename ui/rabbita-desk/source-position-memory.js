export function boundedEditorPosition(position, text) {
  const bound = value => {
    let offset = Math.max(0, Math.min(text.length, Number(value) || 0))
    if (/[\uD800-\uDBFF]/.test(text[offset - 1] || '') && /[\uDC00-\uDFFF]/.test(text[offset] || '')) offset--
    return offset
  }
  return { start: bound(position.start), end: bound(position.end), direction: position.direction || 'none', scrollTop: Math.max(0, Number(position.scrollTop) || 0), scrollLeft: Math.max(0, Number(position.scrollLeft) || 0) }
}

export class SourcePositionMemory {
  constructor(storage = globalThis.localStorage) { this.storage = storage; this.positions = new Map() }
  key(workspace, path) { return `moondesk.source.position:${JSON.stringify([workspace, path])}` }
  save(workspace, path, position) {
    if (!workspace || !path) return
    const key = this.key(workspace, path)
    const value = { start: position.start, end: position.end, direction: position.direction, scrollTop: position.scrollTop, scrollLeft: position.scrollLeft }
    this.positions.set(key, value)
    try { this.storage?.setItem(key, JSON.stringify(value)) } catch { /* In-memory positions remain available. */ }
  }
  read(workspace, path, text) {
    const key = this.key(workspace, path)
    let saved = this.positions.get(key)
    if (!saved) try { saved = JSON.parse(this.storage?.getItem(key) || 'null') } catch { /* Missing or old position. */ }
    return saved && typeof saved === 'object' ? boundedEditorPosition(saved, text) : null
  }
}
