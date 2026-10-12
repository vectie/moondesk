// A lexical navigation aid over the current draft, never compiler symbol truth.
export function codeOutline(text, language) {
  if (!['MoonBit', 'JavaScript', 'TypeScript', 'Python'].includes(language)) return { supported: false, entries: [] }
  if (text.length > 120000) return { supported: true, entries: [], unavailable: 'Code outline unavailable above 120,000 UTF-16 characters' }
  // Mask comments and quoted text without changing offsets or line endings.
  const chars = text.split(''); let quote = '', block = false, lineComment = false, lastToken = ''
  const javascript = language === 'JavaScript' || language === 'TypeScript'
  const expressionStart = new Set(['', '=', '(', '[', '{', ',', ':', ';', '!', '?', '&', '|', '+', '-', '*', '%', '^', '~', '<', '>', 'return', 'throw', 'case', 'delete', 'void', 'typeof', 'instanceof', 'in', 'of', 'yield', 'await'])
  const blank = i => { if (chars[i] !== '\n' && chars[i] !== '\r') chars[i] = ' ' }
  for (let i = 0; i < text.length; i++) {
    const c = text[i], next = text[i + 1]
    if (lineComment) { if (c === '\n') lineComment = false; else blank(i); continue }
    if (block) { blank(i); if (c === '*' && next === '/') { blank(++i); block = false } continue }
    if (quote) {
      blank(i)
      if (c === '\\') { if (i + 1 < text.length) blank(++i); continue }
      if (text.startsWith(quote, i)) { for (let j = 1; j < quote.length; j++) blank(i + j); i += quote.length - 1; quote = ''; lastToken = 'literal' }
      // Unescaped newlines cannot belong to ordinary JS strings. Recover a
      // draft error locally instead of hiding every subsequent declaration.
      if (javascript && c === '\n' && quote !== '`') { quote = ''; lastToken = '' }
      continue
    }
    if (language === 'Python' && c === '#' || language !== 'Python' && c === '/' && next === '/') { lineComment = true; blank(i); continue }
    if (language !== 'Python' && c === '/' && next === '*') { block = true; blank(i); blank(++i); continue }
    if (javascript && c === '/' && expressionStart.has(lastToken)) {
      // Regex literals are single-line; escaped slashes and character classes
      // must not terminate them. Never interpret their quotes as string starts.
      let end = i + 1, characterClass = false
      for (; end < text.length && text[end] !== '\n' && text[end] !== '\r'; end++) {
        if (text[end] === '\\') {
          if (text[end + 1] !== '\n' && text[end + 1] !== '\r') end++
          continue
        }
        if (text[end] === '[') characterClass = true
        else if (text[end] === ']') characterClass = false
        else if (text[end] === '/' && !characterClass) {
          end++
          while (/[A-Za-z]/.test(text[end] || '')) end++
          break
        }
      }
      end = Math.min(end, text.length)
      for (let j = i; j < end; j++) blank(j)
      i = end - 1; lastToken = 'literal'; continue
    }
    if (c === '"' || c === "'" || c === '`') {
      quote = language === 'Python' && text.startsWith(c.repeat(3), i) ? c.repeat(3) : c
      for (let j = 0; j < quote.length; j++) blank(i + j)
      i += quote.length - 1
      continue
    }
    if (/\s/.test(c)) continue
    if (/[A-Za-z_$0-9]/.test(c)) {
      const start = i
      while (/[\w$]/.test(text[i + 1] || '')) i++
      lastToken = text.slice(start, i + 1)
    } else if ((c === '+' || c === '-') && next === c) {
      lastToken = c + c; i++
    } else lastToken = c
  }
  const identifier = '[A-Za-z_$][\\w$]*'
  const pattern = language === 'Python'
    ? new RegExp(`^\\s*(?:async\\s+)?(def|class)\\s+(${identifier})`)
    : language === 'MoonBit'
      ? new RegExp(`^\\s*(?:(?:pub(?:\\([^)]*\\))?|priv|async)\\s+)*(fn|struct|enum|trait|type|suberror|let|const)\\s+(${identifier}(?:::(?:${identifier}))?)`)
      : new RegExp(`^\\s*(?:(?:export|default|declare|abstract|async)\\s+)*(function|class|interface|enum|type|const|let|var)\\s+(\\*?\\s*${identifier})`)
  const entries = []; let offset = 0
  for (const [index, line] of chars.join('').split('\n').entries()) {
    const match = pattern.exec(line)
    if (match) {
      const name = match[2].replace(/^\*?\s*/, '')
      const start = offset + match[0].lastIndexOf(name)
      entries.push({ name, kind: match[1], line: index + 1, column: start - offset + 1, start, end: start + name.length })
    }
    offset += line.length + 1
  }
  return { supported: true, entries }
}
