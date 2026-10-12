// Navigation is presentation state: no edits, storage, or semantic authority.
export function sourceOffset(text, line, column = 1) {
  if (!Number.isSafeInteger(line) || !Number.isSafeInteger(column) || line < 1 || column < 1) throw new Error('Use a positive line and column')
  const lines = text.split('\n')
  if (line > lines.length) throw new Error(`This file has ${lines.length} lines`)
  const content = lines[line - 1].replace(/\r$/, '')
  if (column > content.length + 1) throw new Error(`Line ${line} has ${content.length} UTF-16 columns`)
  let offset = lines.slice(0, line - 1).reduce((total, value) => total + value.length + 1, 0) + column - 1
  // Never place a caret between the two UTF-16 units of an astral character.
  if (offset > 0 && /[\uD800-\uDBFF]/.test(text[offset - 1]) && /[\uDC00-\uDFFF]/.test(text[offset] || '')) throw new Error('Column splits a Unicode character')
  return offset
}

export function parseSourceLocation(value, text) {
  const match = /^\s*([1-9]\d*)(?::([1-9]\d*))?\s*$/.exec(value)
  if (!match) throw new Error('Enter line or line:column, for example 12:3')
  const line = Number(match[1]), column = Number(match[2] || 1)
  return { line, column, offset: sourceOffset(text, line, column) }
}

export class SourceNavigation {
  constructor(limit = 50) { this.limit = limit; this.workspace = ''; this.back = []; this.forward = []; this.pending = null }
  context(workspace) {
    if (workspace !== this.workspace) { this.workspace = workspace; this.back = []; this.forward = []; this.pending = null }
  }
  begin(origin, target, direction = 'jump') {
    this.pending = { origin, target, direction }
    return this.pending
  }
  cancel() { this.pending = null }
  arrive(path) {
    const operation = this.pending
    if (!operation || path !== operation.target.path) return null
    this.pending = null
    const { origin, target, direction } = operation
    if (direction === 'back') { this.back.pop(); this.forward.push(origin) }
    else if (direction === 'forward') { this.forward.pop(); this.back.push(origin) }
    else { this.back.push(origin); this.forward = [] }
    this.back = this.back.slice(-this.limit); this.forward = this.forward.slice(-this.limit)
    return target
  }
}
