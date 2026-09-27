import { strict as assert } from 'node:assert'
import { readFileSync, readdirSync, statSync } from 'node:fs'
import { test } from 'node:test'
import { fileURLToPath } from 'node:url'
import path from 'node:path'
import { gzipSync } from 'node:zlib'

const distRoot = fileURLToPath(new URL('./dist/', import.meta.url))
const assetsRoot = path.join(distRoot, 'assets')

function assetNamed(prefix) {
  const match = readdirSync(assetsRoot)
    .filter(name => name.startsWith(prefix) && name.endsWith('.js'))
  assert.equal(match.length, 1, `expected one ${prefix} asset, found ${match.length}`)
  return match[0]
}

test('production UI keeps route runtimes and the Rabbita app in lazy chunks', () => {
  const initial = assetNamed('index-')
  const shell = assetNamed('shell-runtime-')
  const editor = assetNamed('source-editor-runtime-')
  const markdown = assetNamed('mooncode-markdown-runtime-')
  const devtools = assetNamed('mooncode-developer-tools-runtime-')
  const compare = assetNamed('mooncode-compare-runtime-')
  const app = assetNamed('_rabbita_main-entry-')
  const initialSource = readFileSync(path.join(assetsRoot, initial), 'utf8')
  const shellSource = readFileSync(path.join(assetsRoot, shell), 'utf8')
  const html = readFileSync(path.join(distRoot, 'index.html'), 'utf8')

  assert.match(html, new RegExp(`/assets/${initial.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`))
  assert.doesNotMatch(html, /_rabbita_main-entry/)
  assert.match(initialSource, /shell-runtime-/)
  assert.match(initialSource, /_rabbita_main-entry-/)
  assert.match(shellSource, /source-editor-runtime-/)
  assert.match(shellSource, /mooncode-markdown-runtime-/)
  assert.doesNotMatch(initialSource, /source-editor-runtime-/)
  assert.doesNotMatch(initialSource, /mooncode-markdown-runtime-/)
  for (const asset of [initial, shell, editor, markdown, devtools, compare, app]) {
    assert.ok(statSize(asset) > 0, `${asset} should not be empty`)
  }
})

test('production UI reports non-blocking bundle sizes', t => {
  const initial = assetNamed('index-')
  const shell = assetNamed('shell-runtime-')
  const editor = assetNamed('source-editor-runtime-')
  const markdown = assetNamed('mooncode-markdown-runtime-')
  const devtools = assetNamed('mooncode-developer-tools-runtime-')
  const compare = assetNamed('mooncode-compare-runtime-')
  const app = assetNamed('_rabbita_main-entry-')
  const gzipSize = name => gzipSync(readFileSync(path.join(assetsRoot, name))).byteLength

  for (const asset of [initial, shell, editor, markdown, devtools, compare, app]) {
    t.diagnostic(`${asset}: ${statSize(asset)} raw bytes, ${gzipSize(asset)} gzip bytes`)
  }
})

function statSize(name) {
  return statSync(path.join(assetsRoot, name)).size
}
test('production minification preserves JSON boolean contracts', async () => {
  const { minify } = await import('terser')
  const { default: config } = await import('./vite.config.js')
  const result = await minify('globalThis.__moondeskBooleanProbe = JSON.stringify({ ok: true, running: false, files: [] });', config.build.terserOptions)
  const vm = await import('node:vm')
  const context = {}
  vm.runInNewContext(result.code, context)
  assert.deepEqual(JSON.parse(context.__moondeskBooleanProbe), { ok: true, running: false, files: [] })
})
