import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { codeOutline } from './source-code-outline.js'

test('MoonBit declarations retain exact UTF-16 coordinates in CRLF drafts', () => {
 const text = '// 🌙\r\n///|\r\npub fn Cat::jump() {}\r\nstruct Cat {}\r\nlet value = 1'
 const { entries } = codeOutline(text, 'MoonBit')
 assert.deepEqual(entries.map(x => [x.name, x.line, x.column]), [['Cat::jump', 3, 8], ['Cat', 4, 8], ['value', 5, 5]])
 for (const entry of entries) assert.equal(text.slice(entry.start, entry.end), entry.name)
})
test('JS and TS declarations omit multiline comments, strings and template literals', () => {
 const text = '/*\nfunction fake() {}\n*/\nconst text = `\nclass Hidden {}\n`;\nexport async function real() {}\nexport interface Shape {}\nexport type Alias = Shape'
 assert.deepEqual(codeOutline(text, 'TypeScript').entries.map(x => x.name), ['text', 'real', 'Shape', 'Alias'])
 assert.equal(codeOutline('function* generate() {}', 'JavaScript').entries.length, 0) // outside bounded syntax
})
test('Python async and nested definitions skip multiline docstrings', () => {
 const text = '"""\ndef hidden():\n"""\nclass Public:\n  async def run(self):\n    pass\n# class Hidden:\n'
 assert.deepEqual(codeOutline(text, 'Python').entries.map(x => [x.name, x.line]), [['Public', 4], ['run', 5]])
})
test('unterminated Python multiline data never creates later declarations', () => {
 assert.deepEqual(codeOutline('"""unterminated\ndef hidden(): pass', 'Python').entries, [])
})
test('unsupported and oversized documents are explicit', () => {
 assert.equal(codeOutline('# Heading', 'Markdown').supported, false)
 assert.match(codeOutline('x'.repeat(120001), 'MoonBit').unavailable, /120,000/)
 assert.deepEqual(codeOutline('', 'MoonBit').entries, [])
})

test('JS regex quotes, escapes, classes and flags do not consume later code', () => {
 const text = 'const quote = /"/;\nfunction real() {}\nconst pattern = /["\x27`/]+\\/x/giu;\nclass After {}\nfunction choose() { return /`/ }\nfunction final() {}'
 const entries = codeOutline(text, 'JavaScript').entries
 assert.deepEqual(entries.map(x => x.name), ['quote', 'real', 'pattern', 'After', 'choose', 'final'])
 for (const entry of entries) assert.equal(text.slice(entry.start, entry.end), entry.name)
})

test('division, division assignment and regex expressions coexist in TS', () => {
 const text = 'const ratio = total / count;\nlet other = 2 / 4 / 8;\nother /= 2;\nconst pick = ratio ? /"/ : /`/;\nfunction tail() {}'
 assert.deepEqual(codeOutline(text, 'TypeScript').entries.map(x => x.name), ['ratio', 'other', 'pick', 'tail'])
})

test('unfinished JS regex or ordinary string recovers at the next line', () => {
 assert.deepEqual(codeOutline('const pattern = /["\nfunction following() {}', 'JavaScript').entries.map(x => x.name), ['pattern', 'following'])
 assert.deepEqual(codeOutline('const text = "unfinished\nfunction following() {}', 'JavaScript').entries.map(x => x.name), ['text', 'following'])
})

test('production source runtime outline reaches downstream navigation and installation', () => {
 const text = readFileSync(new URL('./source-editor-runtime.js', import.meta.url), 'utf8')
 const entries = codeOutline(text, 'JavaScript').entries
 for (const name of ['syncCodeOutline', 'selectCodeOutline', 'revealSourceLocation', 'installSourceEditorRuntime']) {
   const entry = entries.find(entry => entry.name === name)
   assert.ok(entry, name)
   assert.equal(text.slice(entry.start, entry.end), name)
 }
})
