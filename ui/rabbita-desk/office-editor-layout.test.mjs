import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'

test('long Office item lists scroll without pushing editing controls below the document', () => {
  const css = readFileSync(new URL('./styles/mooncode.css', import.meta.url), 'utf8')
  assert.match(css, /\.office-editor-nav \{[^}]*max-height: min\(28vh, 240px\);[^}]*overflow: auto;/)
})
