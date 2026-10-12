import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { markdownLinks, prepareMarkdownLinkReplacement, applyMarkdownLinkReplacement, MARKDOWN_LINK_LIMITS } from './source-markdown-links.js'

const sample = name => readFileSync(new URL(`../../docs/samples/markdown-links/${name}.md`, import.meta.url), 'utf8')

test('sample retargets both real guide links while preserving labels, titles, code and reference syntax', () => {
  const before = sample('guide-before'), links = markdownLinks(before)
  assert.deepEqual(links.map(link => link.destination), ['docs/old-guide.md', 'docs/faq.md', 'docs/old-guide.md', 'images/diagram(v1).svg'])
  const plan = prepareMarkdownLinkReplacement(before, links[0].destinationStart, 'docs/new-guide.md', 'matching')
  assert.equal(plan.output, sample('guide-after')); assert.equal(plan.matches.length, 2)
  assert.equal(applyMarkdownLinkReplacement(plan, before, links[0].destinationStart, 'docs/new-guide.md', 'matching'), plan.output)
  for (const link of links) assert.equal(before.slice(link.destinationStart, link.destinationEnd), link.destination)
})

test('destinations retain balanced and escaped parentheses, angle forms, titles, brackets and Unicode locations', () => {
  const text = '😀 [v2 [guide]](docs/a(b(c)).md "A title")\r\n![図](docs/a\\(old\\).svg) [Space](<docs/user guide.md> \'Open\')'
  const links = markdownLinks(text)
  assert.deepEqual(links.map(link => link.destination), ['docs/a(b(c)).md', 'docs/a\\(old\\).svg', '<docs/user guide.md>'])
  assert.equal(links[0].label, 'v2 [guide]'); assert.equal(links[0].line, 1); assert.equal(links[0].column, 17)
  assert.equal(links[1].kind, 'image'); assert.equal(links[1].line, 2)
  const plan = prepareMarkdownLinkReplacement(text, links[2].destinationStart, '<new guide.md>')
  assert.equal(plan.output, text.replace('<docs/user guide.md>', '<new guide.md>'))
  assert.ok(plan.output.includes('\r\n'))
})

test('one vs exact matching includes images but never equivalent escaped spellings', () => {
  const text = '[a](docs/a(b).md) ![b](docs/a(b).md) [c](docs/a\\(b\\).md) [d](<docs/a(b).md>)'
  const links = markdownLinks(text)
  const one = prepareMarkdownLinkReplacement(text, links[1].destinationStart, 'other', 'one')
  assert.equal(one.output, '[a](docs/a(b).md) ![b](other) [c](docs/a\\(b\\).md) [d](<docs/a(b).md>)')
  assert.equal(prepareMarkdownLinkReplacement(text, links[1].destinationStart, 'other', 'matching').matches.length, 2)
})

test('code blocks, spans, indented code, quotes, front matter and raw HTML are excluded conservatively', () => {
  const text = ['---', 'title: "[front](a)"', '---', '[visible](yes)', '`[code](no)`', '``span ` [code](no)``',
    '~~~md', '[fenced](no)', '~~~', '- ```md', '  [container fence](no)', '  ```', '    [indented](no)', '> [quoted](no)',
    '<div>', '[html](no)', '</div>', '', '[after](yes)', '\\[escaped](no)'].join('\n')
  assert.deepEqual(markdownLinks(text).map(link => link.label), ['visible', 'after'])
})

test('multiline spans and unterminated exclusions do not expose code-looking links', () => {
  assert.deepEqual(markdownLinks('`code\n[x](no)\n`\n[y](yes)').map(link => link.label), ['y'])
  assert.equal(markdownLinks('[x](yes)\n```\n[y](no)').length, 1)
  assert.equal(markdownLinks('`unterminated\n[x](no)').length, 0)
})

test('reference, multiline, malformed and unsupported inline syntax is omitted', () => {
  const text = '[ref][id]\n[id]: dest\n\n<https://example.com>\n[a](not balanced( )\n[b](url\n"title")\n[c](url "bad)\n[d](ok)'
  assert.deepEqual(markdownLinks(text).map(link => link.label), ['d'])
  assert.deepEqual(markdownLinks('[ref][id]\n[id]: dest\n\n[a](not balanced( )\n[b](url\n"title")\n[c](url "bad)\n[d](ok)').map(link => link.label), ['d'])
})

test('empty and angle destinations can be authored without changing labels or title text', () => {
  assert.equal(prepareMarkdownLinkReplacement('[label](old)', 8, '').output, '[label]()')
  assert.throws(() => prepareMarkdownLinkReplacement('[label](old \"title\")', 8, ''), /inspection structure/)
  for (const destination of ['<>', 'docs/a(b).md', 'docs/a\\(b\\).md', '<new path>', '#part', '?q=a&b=2']) {
    const plan = prepareMarkdownLinkReplacement('[label](old "title")', 8, destination)
    assert.equal(plan.output, `[label](${destination} "title")`)
  }
})

test('invalid replacement is rejected before any source edit', () => {
  for (const value of ['two words', '(unclosed', 'bad)', '<bad', '<a>b', 'target "title"', 'x\ny', 'x\u0000y', 'x\\']) {
    assert.throws(() => prepareMarkdownLinkReplacement('[x](old)', 4, value), /destination token/)
  }
  assert.throws(() => prepareMarkdownLinkReplacement('[x](old)\n[y](keep)', 4, '`'), /inspection structure/)
})

test('prepared edits are immutable and bound to source, selected occurrence, input and scope', () => {
  const text = '[x](old)', plan = prepareMarkdownLinkReplacement(text, 4, 'new', 'one')
  for (const args of [[text+' ',4,'new','one'], [text,5,'new','one'], [text,4,'other','one'], [text,4,'new','matching']]) {
    assert.throws(() => applyMarkdownLinkReplacement(plan, ...args), /changed/)
  }
  assert.throws(() => applyMarkdownLinkReplacement({...plan}, text,4,'new','one'), /changed/)
  assert.ok(Object.isFrozen(plan)); assert.ok(Object.isFrozen(plan.matches)); assert.ok(Object.isFrozen(plan.matches[0]))
  assert.equal(prepareMarkdownLinkReplacement(text, 4, 'old').changed, false)
})

test('explicit size, result, occurrence and nesting limits fail instead of returning partial edits', () => {
  assert.throws(() => markdownLinks('x'.repeat(MARKDOWN_LINK_LIMITS.characters+1)), /120,000/)
  assert.throws(() => markdownLinks('[a](x) '.repeat(1001)), /1,000/)
  assert.equal(markdownLinks('[a](x) '.repeat(1000)).length, 1000)
  assert.equal(markdownLinks('[a](' + '('.repeat(33) + 'x' + ')'.repeat(33) + ')').length, 0)
  assert.throws(() => prepareMarkdownLinkReplacement('[a](x) [b](x)', 4, 'y'.repeat(60_000), 'matching'), /Result exceeds/)
  assert.throws(() => prepareMarkdownLinkReplacement('[a](x)', 99, 'y'), /no longer available/)
})


test('reference definition titles and their continuations stay outside a real-link migration', () => {
  const text = '[ref]: docs/guide.md "[example](old.md)"\n\n[continued]:\n  docs/guide.md\n  "[title example](old.md)"\n\n[real](old.md)'
  const links = markdownLinks(text)
  assert.deepEqual(links.map(link => link.label), ['real'])
  assert.equal(prepareMarkdownLinkReplacement(text, links[0].destinationStart, 'new.md', 'matching').output,
    text.replace('[real](old.md)', '[real](new.md)'))
})
