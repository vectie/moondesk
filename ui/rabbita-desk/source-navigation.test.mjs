import test from 'node:test'
import assert from 'node:assert/strict'
import { SourceNavigation, parseSourceLocation } from './source-navigation.js'

test('line/column parser supports LF, CRLF, EOF and Unicode without split surrogates', () => {
  assert.deepEqual(parseSourceLocation(' 2:4 ', 'one\r\n猫😀x'), { line: 2, column: 4, offset: 8 })
})

test('invalid, overlong, out-of-range and split locations do not become navigation', () => {
  for (const value of ['0', '-1', '1:0', '1.5', '2:3', '3', '2:6', '9007199254740992', '1:2:3'])
    assert.throws(() => parseSourceLocation(value, 'one\r\n猫😀x'))
  assert.equal(parseSourceLocation('2:5', 'one\r\n猫😀x').offset, 9)
  assert.equal(parseSourceLocation('2', 'x\n').offset, 2)
})

test('history commits only completed navigation, branches, bounds, and isolates workspaces', () => {
  const n = new SourceNavigation(2); n.context('book')
  const a = { path: 'a', start: 1 }, b = { path: 'b', start: 2 }, c = { path: 'c', start: 3 }
  n.begin(a, b); assert.equal(n.arrive('loading'), null); assert.equal(n.back.length, 0)
  assert.deepEqual(n.arrive('b'), b); assert.deepEqual(n.back, [a])
  n.begin(b, a, 'back'); n.arrive('a'); assert.deepEqual(n.forward, [b]); assert.deepEqual(n.back, [])
  n.begin(a, b, 'forward'); n.arrive('b'); assert.deepEqual(n.back, [a]); assert.deepEqual(n.forward, [])
  n.begin(b, c); n.cancel(); assert.equal(n.arrive('c'), null); assert.deepEqual(n.back, [a])
  n.begin(b, c); n.arrive('c'); n.begin(c, a); n.arrive('a'); assert.deepEqual(n.back, [b, c])
  n.context('other'); assert.deepEqual(n.back, []); assert.deepEqual(n.forward, []); assert.equal(n.pending, null)
})
