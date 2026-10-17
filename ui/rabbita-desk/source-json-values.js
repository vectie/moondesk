// Source ranges, rather than parsed JavaScript values, preserve JSON number and
// string spelling. JSON.parse is used only to decode individual string tokens.
export const JSON_VALUE_LIMITS = Object.freeze({ characters: 120_000, nodes: 10_000, depth: 64 })

export function parseJsonDocument(text) {
  if (text.length > JSON_VALUE_LIMITS.characters) throw new Error('JSON explorer unavailable above 120,000 UTF-16 units.')
  // Blob encodes UTF-8, which would replace literal unpaired UTF-16 surrogates.
  // Escaped JSON spellings such as \\ud800 remain ordinary ASCII and stay exact.
  for (let index = 0; index < text.length; index += 1) {
    const unit = text.charCodeAt(index)
    if (unit >= 0xd800 && unit <= 0xdbff) {
      const next = text.charCodeAt(index + 1)
      if (!(next >= 0xdc00 && next <= 0xdfff)) throw new Error(`Unpaired Unicode surrogate at UTF-16 offset ${index}. Use a JSON Unicode escape.`)
      index += 1
    } else if (unit >= 0xdc00 && unit <= 0xdfff) throw new Error(`Unpaired Unicode surrogate at UTF-16 offset ${index}. Use a JSON Unicode escape.`)
  }
  let offset = 0
  let nodes = 0
  const fail = message => { throw new Error(`${message} at UTF-16 offset ${offset}.`) }
  const whitespace = () => { while (offset < text.length && /[ \t\r\n]/.test(text[offset])) offset += 1 }
  const string = () => {
    const start = offset++
    while (offset < text.length) {
      const char = text[offset++]
      if (char === '"') {
        try { return JSON.parse(text.slice(start, offset)) } catch { fail('Invalid JSON string') }
      }
      if (char === '\\') offset += 1
      else if (char.charCodeAt(0) < 32) fail('Unescaped control character')
    }
    fail('Unterminated JSON string')
  }
  const value = depth => {
    whitespace()
    if (++nodes > JSON_VALUE_LIMITS.nodes) fail('JSON explorer exceeds 10,000 values')
    const start = offset
    const char = text[offset]
    let type
    const children = []
    if (char === '{' || char === '[') {
      if (depth >= JSON_VALUE_LIMITS.depth) fail('JSON explorer exceeds 64 nested containers')
      type = char === '{' ? 'object' : 'array'
      const close = char === '{' ? '}' : ']'
      offset += 1; whitespace()
      if (text[offset] !== close) {
        while (true) {
          const memberStart = offset
          let key = String(children.length)
          if (type === 'object') {
            if (text[offset] !== '"') fail('Expected an object key')
            key = string(); whitespace()
            if (text[offset++] !== ':') fail('Expected a colon')
          }
          children.push({ key, memberStart, node: value(depth + 1) })
          whitespace()
          if (text[offset] !== ',') break
          offset += 1; whitespace()
        }
      }
      if (text[offset++] !== close) fail(`Expected ${close}`)
    } else if (char === '"') { type = 'string'; string() }
    else {
      const token = /^(?:true|false|null|-?(?:0|[1-9]\d*)(?:\.\d+)?(?:[eE][+-]?\d+)?)/.exec(text.slice(offset))?.[0]
      if (!token) fail('Expected a JSON value')
      type = token === 'null' ? 'null' : token === 'true' || token === 'false' ? 'boolean' : 'number'
      offset += token.length
    }
    return { type, start, end: offset, children }
  }
  const root = value(0)
  whitespace()
  if (offset !== text.length) fail('Unexpected content after JSON value')
  return root
}

export function jsonPointerTokens(pointer) {
  if (pointer === '') return []
  if (!pointer.startsWith('/')) throw new Error('A JSON Pointer is empty for the root, or starts with /. URI fragments are not supported.')
  return pointer.slice(1).split('/').map(token => {
    if (/~(?:[^01]|$)/.test(token)) throw new Error('Use ~0 for a tilde and ~1 for a slash in JSON Pointer keys.')
    return token.replace(/~1/g, '/').replace(/~0/g, '~')
  })
}

export function resolveJsonPointer(root, pointer) {
  let node = root
  for (const token of jsonPointerTokens(pointer)) {
    if (node.type !== 'object' && node.type !== 'array') throw new Error('This JSON Pointer continues through a scalar value.')
    if (node.type === 'array' && !/^(?:0|[1-9]\d*)$/.test(token)) throw new Error('Array positions use zero-based integers without leading zeroes; - is not a value.')
    const matches = node.children.filter(child => child.key === token)
    if (!matches.length) throw new Error('JSON Pointer does not exist in the current draft. Choose Parent or Root to recover.')
    if (matches.length > 1) throw new Error('JSON Pointer is ambiguous because this object has duplicate keys. Inspect or export its parent.')
    node = matches[0].node
  }
  return node
}

export function jsonChildPointers(node, pointer) {
  const counts = new Map()
  for (const child of node.children) counts.set(child.key, (counts.get(child.key) || 0) + 1)
  return node.children.map(child => ({ ...child,
    pointer: `${pointer}/${child.key.replace(/~/g, '~0').replace(/\//g, '~1')}`,
    ambiguous: counts.get(child.key) > 1,
  }))
}
