import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'

test('chat uses one readable column without reply cards or a second composer-sized scroll spacer', () => {
  const css = readFileSync(new URL('./styles/workbench-layout.css', import.meta.url), 'utf8')
  const transcript = css.match(/\.code-workbench \.mooncode-transcript-list \{([^}]+)\}/)?.[1] || ''
  assert.match(transcript, /width: 100%; max-width: none;/)
  assert.match(transcript, /var\(--mooncode-chat-column\)/)
  assert.match(transcript, /scroll-padding-bottom: 28px/)
  const reply = css.match(/\.code-workbench \.mooncode-message\.assistant \{([^}]+)\}/)?.[1] || ''
  assert.match(reply, /width: 100%; max-width: none/)
  assert.match(reply, /border: 0/)
  assert.match(reply, /box-shadow: none/)
  assert.match(css, /\.code-workbench \.mooncode-composer \{[^}]*var\(--mooncode-chat-column\)/)
})

test('the composer does not automatically mount suggested prompts over the draft', () => {
  const bootstrap = readFileSync(new URL('./bootstrap.js', import.meta.url), 'utf8')
  assert.doesNotMatch(bootstrap, /import\(['"]\.\/mooncode-suggestions-runtime\.js['"]\)/)
  assert.match(bootstrap, /import\(['"]\.\/mooncode-task-controls-runtime\.js['"]\)/)
  assert.match(bootstrap, /import\(['"]\.\/mooncode-media-tools-runtime\.js['"]\)/)
})
