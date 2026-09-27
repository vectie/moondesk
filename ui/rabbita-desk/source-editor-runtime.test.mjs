import test from 'node:test'
import assert from 'node:assert/strict'
import { semanticLocations } from './source-editor-runtime.js'

test('MoonBit navigation accepts only distinct, confined typed locations', () => {
  assert.deepEqual(semanticLocations({ locations: [
    { path: 'pkg/main.mbt', line: 3, column: 5 },
    null,
    { path: 'pkg/main.mbt', line: 3, column: 5 },
    { path: '../outside.mbt', line: 1, column: 1 },
    { path: '/outside.mbt', line: 1, column: 1 },
    { path: 'pkg/main.mbt', line: 0, column: 1 },
  ] }), [{ path: 'pkg/main.mbt', line: 3, column: 5 }])
  assert.deepEqual(semanticLocations({ locations: null }), [])
  assert.deepEqual(semanticLocations(null), [])
})
