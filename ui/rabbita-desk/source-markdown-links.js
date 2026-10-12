// A bounded source scanner, not a Markdown renderer or URL resolver.
export const MARKDOWN_LINK_LIMITS = Object.freeze({ characters: 120_000, links: 1000, depth: 32 })
const plans = new WeakSet()
const punctuation = /[!"#$%&'()*+,\-./:;<=>?@[\\\]^_`{|}~]/
const escapedLength = (text, index) => text[index] === '\\' && punctuation.test(text[index + 1] || '') ? 2 : 1

// Parse a destination token, retaining angle brackets and backslash spelling.
function destination(text, start) {
  let index = start, depth = 0
  if (text[index] === '<') {
    index += 1
    while (index < text.length) {
      if (escapedLength(text, index) === 2) { index += 2; continue }
      if (text[index] === '>') return { start, end: index + 1 }
      if (text[index] === '<' || /[\r\n\u0000-\u001f\u007f]/.test(text[index])) return null
      index += 1
    }
    return null
  }
  while (index < text.length) {
    if (escapedLength(text, index) === 2) { index += 2; continue }
    const char = text[index]
    if (/[\s<>\u0000-\u001f\u007f]/u.test(char)) break
    if (char === '(') { depth += 1; if (depth > MARKDOWN_LINK_LIMITS.depth) return null }
    if (char === ')') { if (!depth) break; depth -= 1 }
    index += 1
  }
  return depth ? null : { start, end: index }
}

function inlineLink(text, start, mask) {
  const image = text[start] === '!'
  const bracket = start + (image ? 1 : 0)
  if (text[bracket] !== '[') return null
  let index = bracket + 1, depth = 1
  while (index < text.length && depth) {
    if (mask?.[index] || text[index] === '\n' || text[index] === '\r') return null
    if (escapedLength(text, index) === 2) { index += 2; continue }
    if (text[index] === '[') { depth += 1; if (depth > MARKDOWN_LINK_LIMITS.depth) return null }
    if (text[index] === ']') depth -= 1
    index += 1
  }
  if (depth || text[index] !== '(') return null
  const label = text.slice(bracket + 1, index - 1)
  // Nested link/image labels need a real Markdown tree. Leave them untouched.
  if (/\]\(/.test(label)) return null
  index += 1
  while (text[index] === ' ' || text[index] === '\t') index += 1
  const token = destination(text, index)
  if (!token) return null
  index = token.end
  const spaced = text[index] === ' ' || text[index] === '\t'
  while (text[index] === ' ' || text[index] === '\t') index += 1
  if (spaced && ['"', "'", '('].includes(text[index])) {
    const close = text[index] === '(' ? ')' : text[index]
    index += 1
    while (index < text.length && text[index] !== close) {
      if (text[index] === '\n' || text[index] === '\r') return null
      index += escapedLength(text, index)
    }
    if (text[index] !== close) return null
    index += 1
    while (text[index] === ' ' || text[index] === '\t') index += 1
  }
  if (text[index] !== ')') return null
  for (let pos = bracket; pos <= index; pos += 1) if (mask?.[pos]) return null
  return { kind: image ? 'image' : 'link', label, start, end: index + 1,
    destinationStart: token.start, destinationEnd: token.end, destination: text.slice(token.start, token.end) }
}

function excludedSource(text) {
  const mask = new Uint8Array(text.length)
  let offset = 0, fence = null, frontMatter = false, html = false, reference = false
  const lines = text.split('\n')
  for (let number = 0; number < lines.length; number += 1) {
    const raw = lines[number], line = raw.replace(/\r$/, '')
    const end = Math.min(text.length, offset + raw.length + 1)
    let excluded = false
    if (!line.trim()) reference = false
    if (!fence && !html && /^ {0,3}\[(?:\\.|[^\]\\])+\]:/.test(line)) reference = true
    if (number === 0 && /^(---|\+\+\+)$/.test(line)) frontMatter = line
    if (frontMatter) {
      excluded = true
      if (number > 0 && (line === frontMatter || (frontMatter === '---' && line === '...'))) frontMatter = false
    } else {
      // Container fences are skipped conservatively as well as top-level fences.
      const content = line.replace(/^(?: {0,3}> ?)* {0,3}(?:(?:[-+*]|\d+[.)])\s+)?/, '')
      const marker = /^(`{3,}|~{3,})(.*)$/.exec(content)
      if (fence) {
        excluded = true
        if (marker && marker[1][0] === fence[0] && marker[1].length >= fence.length && !marker[2].trim()) fence = null
      } else if (marker && (marker[1][0] !== '`' || !marker[2].includes('`'))) {
        fence = marker[1]; excluded = true
      } else {
        if (!line.trim()) html = false
        // Raw HTML and its following block are outside this scanner's scope.
        if (/<(?:!--|\?|!\[CDATA\[|\/?[A-Za-z][A-Za-z0-9-]*(?:\s|>|\/>))/.test(line.replace(/\]\([ \t]*<[^<>\r\n]*>/g, '](__destination__'))) html = true
        excluded = html || /^(?: {4}|\t| {0,3}>)/.test(line)
      }
    }
    if (excluded || reference) mask.fill(1, offset, end)
    offset = end
  }
  let ticks = 0
  for (let index = 0; index < text.length;) {
    if (mask[index]) { index += 1; continue }
    if (!ticks && escapedLength(text, index) === 2) { index += 2; continue }
    if (text[index] === '`') {
      let end = index + 1
      while (text[end] === '`' && !mask[end]) end += 1
      const count = end - index
      mask.fill(1, index, end)
      if (!ticks) ticks = count
      else if (ticks === count) ticks = 0
      index = end
    } else { if (ticks) mask[index] = 1; index += 1 }
  }
  return mask
}

export function markdownLinks(text) {
  if (typeof text !== 'string' || text.length > MARKDOWN_LINK_LIMITS.characters) throw new Error('Markdown link inspection requires at most 120,000 UTF-16 units.')
  const mask = excludedSource(text), links = []
  let line = 1, lineStart = 0
  for (let index = 0; index < text.length;) {
    if (text[index] === '\n') { line += 1; lineStart = index + 1 }
    if (mask[index]) { index += 1; continue }
    if (escapedLength(text, index) === 2) { index += 2; continue }
    const link = (text[index] === '[' || (text[index] === '!' && text[index + 1] === '[')) ? inlineLink(text, index, mask) : null
    if (link) {
      links.push(Object.freeze({ ...link, line, column: link.destinationStart - lineStart + 1 }))
      if (links.length > MARKDOWN_LINK_LIMITS.links) throw new Error('Markdown link inspection is limited to 1,000 supported links; no partial replacement is available.')
      index = link.end
    } else index += 1
  }
  return Object.freeze(links)
}

export function prepareMarkdownLinkReplacement(text, destinationStart, replacement, scope = 'one') {
  if (!['one', 'matching'].includes(scope)) throw new Error('Choose one occurrence or all exact matching destinations.')
  if (typeof replacement !== 'string' || replacement.length > MARKDOWN_LINK_LIMITS.characters) throw new Error('Replacement destination is too large.')
  const parsed = inlineLink(`[link](${replacement})`, 0)
  if (!parsed || parsed.destination !== replacement || parsed.end !== replacement.length + 8) {
    throw new Error('Enter one Markdown destination token: docs/guide.md or <docs/user guide.md>. Escape parentheses or balance them. Do not include a title.')
  }
  const links = markdownLinks(text), selected = links.find(link => link.destinationStart === destinationStart)
  if (!selected) throw new Error('The selected link is no longer available. Inspect the current draft again.')
  const matches = links.filter(link => scope === 'one' ? link === selected : link.destination === selected.destination)
  let output = text
  for (const match of [...matches].reverse()) output = output.slice(0, match.destinationStart) + replacement + output.slice(match.destinationEnd)
  if (output.length > MARKDOWN_LINK_LIMITS.characters) throw new Error('Result exceeds the 120,000 UTF-16-unit inspection limit.')
  // Ensure a replacement cannot change the recognized link structure or hide later links.
  const updated = markdownLinks(output)
  let delta = 0
  const sameStructure = updated.length === links.length && links.every((link, index) => {
    const changed = matches.includes(link), current = updated[index]
    const same = current.destinationStart === link.destinationStart + delta && current.kind === link.kind &&
      current.label === link.label && current.destination === (changed ? replacement : link.destination)
    if (changed) delta += replacement.length - link.destination.length
    return same
  })
  if (!sameStructure) throw new Error('Destination would change Markdown inspection structure. Use a different destination token; use <> for an empty destination with a title.')
  const plan = Object.freeze({ text, destinationStart, replacement, scope, before: selected.destination,
    matches: Object.freeze(matches), output, changed: selected.destination !== replacement })
  plans.add(plan)
  return plan
}

export function applyMarkdownLinkReplacement(plan, text, destinationStart, replacement, scope) {
  if (!plan || !plans.has(plan) || plan.text !== text || plan.destinationStart !== destinationStart || plan.replacement !== replacement || plan.scope !== scope) {
    throw new Error('Draft, selected link, replacement or scope changed. Preview the link replacement again.')
  }
  return plan.output
}
