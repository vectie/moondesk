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

test('production UI keeps the shell and Rabbita app in lazy chunks', () => {
  const initial = assetNamed('index-')
  const shell = assetNamed('shell-runtime-')
  const app = assetNamed('_rabbita_main-entry-')
  const initialSource = readFileSync(path.join(assetsRoot, initial), 'utf8')
  const html = readFileSync(path.join(distRoot, 'index.html'), 'utf8')

  assert.match(html, new RegExp(`/assets/${initial.replace(/[.*+?^${}()|[\]\\]/g, '\\$&')}`))
  assert.doesNotMatch(html, /_rabbita_main-entry/)
  assert.match(initialSource, /shell-runtime-/)
  assert.match(initialSource, /_rabbita_main-entry-/)
  assert.ok(statSize(initial) < 16 * 1024, 'initial entry should remain a small shell')
  assert.ok(statSize(shell) < 32 * 1024, 'shell runtime should remain lightweight')
  assert.ok(statSize(app) > 1 * 1024 * 1024, 'Rabbita app should remain lazy')
})

test('production UI keeps explicit transfer-size budgets', () => {
  const initial = assetNamed('index-')
  const shell = assetNamed('shell-runtime-')
  const app = assetNamed('_rabbita_main-entry-')
  const gzipSize = name => gzipSync(readFileSync(path.join(assetsRoot, name))).byteLength

  assert.ok(gzipSize(initial) < 4 * 1024, 'initial shell transfer should stay below 4 KiB')
  assert.ok(gzipSize(shell) < 8 * 1024, 'interaction shell transfer should stay below 8 KiB')
  assert.ok(statSize(app) < 3 * 1024 * 1024, 'compiled Rabbita app should stay below 3 MiB')
  assert.ok(gzipSize(app) < 380 * 1024, 'compiled Rabbita app transfer should stay below 380 KiB')
})

function statSize(name) {
  return statSync(path.join(assetsRoot, name)).size
}
