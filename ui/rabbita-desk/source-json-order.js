import { parseJsonDocument, resolveJsonPointer, jsonPointerTokens } from './source-json-values.js'

// Compare decimal spellings without passing a JSON number through binary64,
// expanding exponents, or changing the original record tokens.
function decimal(raw) {
  const match = /^(-?)(\d+)(?:\.(\d+))?(?:[eE]([+-]?\d+))?$/.exec(raw)
  const exponent = match[4] || '0'
  if (exponent.replace(/^[+-]/, '').length > 256) throw new Error('Ordering supports number exponents up to 256 digits.')
  const digits = (match[2] + (match[3] || '')).replace(/^0+/, '')
  if (!digits) return { sign: 0, digits: '', magnitude: 0n }
  return { sign: match[1] ? -1 : 1, digits, magnitude: BigInt(exponent) - BigInt((match[3] || '').length) + BigInt(digits.length) }
}
function compareDecimal(a, b) {
  if (a.sign !== b.sign) return a.sign < b.sign ? -1 : 1
  if (!a.sign) return 0
  if (a.magnitude !== b.magnitude) return (a.magnitude < b.magnitude ? -1 : 1) * a.sign
  for (let i = 0; i < Math.max(a.digits.length, b.digits.length); i++) {
    const x = a.digits[i] || '0', y = b.digits[i] || '0'
    if (x !== y) return (x < y ? -1 : 1) * a.sign
  }
  return 0
}
function fieldAt(record, tokens) {
  let node = record
  for (const token of tokens) {
    if (!['object', 'array'].includes(node.type)) throw new Error('The field pointer continues through a scalar; null is not a missing field.')
    if (node.type === 'array' && !/^(?:0|[1-9]\d*)$/.test(token)) throw new Error('Field array positions require canonical zero-based integers.')
    const matches = node.children.filter(child => child.key === token)
    if (matches.length > 1) throw new Error('The field pointer is ambiguous because of duplicate keys.')
    if (!matches.length) return null
    node = matches[0].node
  }
  return node
}

export function prepareJsonOrder(text, pointer, field, type, direction, missing) {
  if (!['number', 'string', 'boolean'].includes(type)) throw new Error('Choose field type: number, string or boolean.')
  if (!['asc', 'desc'].includes(direction)) throw new Error('Choose order: asc or desc.')
  if (!['error', 'first', 'last'].includes(missing)) throw new Error('Choose missing-field policy: error, first or last. Null is not missing.')
  const tokens = jsonPointerTokens(field)
  if (!tokens.length) throw new Error('Choose a nonempty relative field pointer, such as /priority.')
  const root = parseJsonDocument(text), target = resolveJsonPointer(root, pointer)
  if (target.type !== 'array') throw new Error('Choose a JSON record array.')
  const records = target.children.map(({ node }, index) => {
    if (node.type !== 'object') throw new Error(`Item ${index} is not a record object.`)
    const value = fieldAt(node, tokens)
    if (!value && missing === 'error') throw new Error(`Item ${index} is missing the selected field.`)
    if (value && value.type !== type) throw new Error(`Item ${index} has ${value.type}; every present field must be ${type}. Null is not missing.`)
    const raw = value && text.slice(value.start, value.end)
    return { index, raw: text.slice(node.start, node.end), missing: !value,
      key: !value ? null : type === 'number' ? decimal(raw) : JSON.parse(raw) }
  })
  const ordered = [...records].sort((a, b) => {
    if (a.missing !== b.missing) return (a.missing ? -1 : 1) * (missing === 'first' ? 1 : -1)
    const result = a.missing ? 0 : type === 'number' ? compareDecimal(a.key, b.key) : a.key < b.key ? -1 : a.key > b.key ? 1 : 0
    return (direction === 'asc' ? result : -result) || a.index - b.index
  })
  let cursor = target.start, after = ''
  for (let i = 0; i < target.children.length; i++) {
    const node = target.children[i].node
    after += text.slice(cursor, node.start) + ordered[i].raw; cursor = node.end
  }
  after += text.slice(cursor, target.end)
  const output = text.slice(0, target.start) + after + text.slice(target.end)
  parseJsonDocument(output)
  return Object.freeze({ text, pointer, field, type, direction, missing, output,
    before: text.slice(target.start, target.end), after,
    originalIndexes: Object.freeze(ordered.map(item => item.index)), changed: output !== text })
}

export function applyJsonOrder(plan, text, pointer, field, type, direction, missing) {
  if (!plan || plan.text !== text || plan.pointer !== pointer || plan.field !== field || plan.type !== type || plan.direction !== direction || plan.missing !== missing) {
    throw new Error('Draft, array or ordering settings changed. Preview the ordering again.')
  }
  if (!plan.changed) throw new Error('The array is already in this order. No draft edit is needed.')
  return plan.output
}
