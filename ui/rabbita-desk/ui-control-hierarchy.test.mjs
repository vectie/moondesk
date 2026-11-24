import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
const read = file => readFileSync(new URL(file, import.meta.url), 'utf8')

test('selects and menus share the hierarchy tokens instead of surface-specific chevrons and heights', () => {
  const css = read('./styles/type-hierarchy.css')
  assert.match(css, /One native select style/)
  assert.match(css, /select:not\(\[multiple\]\)\s*\{[^}]*height: var\(--control-height\)/)
  assert.match(css, /select:not\(\[multiple\]\)\s*\{[^}]*chevron-down\.svg/)
  assert.match(css, /\.source-file-action-menu,[^}]*\.mooncode-composer-settings-body,[^}]*\.code-column-resize-menu\)\s*\{[^}]*border-radius: var\(--radius-popover\)/)
  assert.doesNotMatch(css, /\.coding-setup select \{ appearance:/)
})

test('responsive pane geometry has one owner and Flow uses its available height', () => {
  const old = read('./styles/code-workbench.css'), layout = read('./styles/workbench-layout.css')
  assert.doesNotMatch(old, /grid-template-columns: minmax\((260|220)px/)
  assert.doesNotMatch(old, /height: 50dvh/)
  assert.match(layout, /data-column-layout="single"/)
  assert.match(layout, /workspace-column-resizer\[hidden\]/)
  const destinations = read('./styles/destination-layout.css')
  assert.match(destinations, /\.flow-main \{[^}]*height: 100%/)
  assert.match(destinations, /flow-composer-infinite \{[^}]*flex: 1 0 320px; height: auto/)
})
