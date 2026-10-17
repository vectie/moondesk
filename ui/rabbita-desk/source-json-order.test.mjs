import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareJsonOrder as preview, applyJsonOrder as apply } from './source-json-order.js'

const order = (text, direction = 'asc', missing = 'error', type = 'number', field = '/n', pointer = '') => preview(text, pointer, field, type, direction, missing)
test('orders creator record array without changing a single raw record, separator or surrounding byte', () => {
  const text = ' {"steps":[ {"n":9007199254740993,"id":"\\u0061"},\n { "n":9007199254740992,"x":1e+02 },\t{"n":-0}],"keep":12.50}\r\n'
  const args = [text, '/steps', '/n', 'number', 'asc', 'error'], plan = preview(...args)
  assert.equal(plan.output, ' {"steps":[ {"n":-0},\n { "n":9007199254740992,"x":1e+02 },\t{"n":9007199254740993,"id":"\\u0061"}],"keep":12.50}\r\n')
  assert.deepEqual(plan.originalIndexes, [2,1,0]); assert.equal(apply(plan, ...args), plan.output)
  assert.deepEqual(preview(...args), plan)
})
test('exact decimal ordering supports huge exponents, tiny negatives and stable equivalent spellings', () => {
  const raw = '[{"n":1e99999},{"n":-1e99999},{"n":1.00},{"n":10e-1},{"n":-0},{"n":0e999},{"n":-0.0001},{"n":1e-99999},{"n":-1e-99999}]'
  assert.deepEqual(order(raw).originalIndexes, [1,6,8,4,5,7,2,3,0])
  assert.deepEqual(order(raw, 'desc').originalIndexes, [0,2,3,7,4,5,8,6,1])
  assert.deepEqual(order('[{"n":-12},{"n":-1.20e1},{"n":-12.01},{"n":12.0001},{"n":12}]').originalIndexes, [2,0,1,4,3])
  assert.throws(() => order('[{"n":1e' + '9'.repeat(257) + '}]'), /256 digits/)
})
test('missing placement stays explicit and independent of direction; null and scalar traversal refuse', () => {
  const raw = '[{"n":1},{"x":1},{"n":2},{"x":2}]'
  assert.throws(() => order(raw), /missing/)
  assert.deepEqual(order(raw, 'desc', 'first').originalIndexes, [1,3,2,0])
  assert.deepEqual(order(raw, 'desc', 'last').originalIndexes, [2,0,1,3])
  assert.throws(() => order('[{"n":null}]', 'asc', 'last'), /null/)
  assert.throws(() => order('[{"n":1}]', 'asc', 'last', 'number', '/n/x'), /scalar/)
})
test('decoded strings, booleans and slash/tilde pointers follow declared exact semantics', () => {
  assert.deepEqual(order('[{"n":"b"},{"n":"\\u0061"},{"n":"a"},{"n":"A"}]', 'asc', 'error', 'string').originalIndexes, [3,1,2,0])
  assert.deepEqual(order('[{"n":true},{"n":false},{"n":true}]', 'asc', 'error', 'boolean').originalIndexes, [1,0,2])
  assert.deepEqual(order('[{"a/b~":[{"":2}]},{"a/b~":[{"":1}]}]', 'asc', 'error', 'number', '/a~1b~0/0/').originalIndexes, [1,0])
})
test('empty, singleton and sorted arrays preview without applying a spurious edit', () => {
  for (const raw of ['[]', '[{"n":1}]', '[{"n":1},{"n":2}]']) {
    const plan = order(raw); assert.equal(plan.changed, false); assert.equal(plan.output, raw)
    assert.throws(() => apply(plan, raw, '', '/n', 'number', 'asc', 'error'), /already/)
  }
})
test('invalid fields, arrays, mixed types, duplicate ambiguity, bounds and all stale bindings refuse', () => {
  for (const raw of ['[1,2]', '[{"n":1},{"n":"2"}]', '[{"n":1,"n":2}]', '[{"n":1e}]', '{"n":1}', '[{"n":01}]']) assert.throws(() => order(raw))
  assert.throws(() => order('[{"n":1}]', 'ascending'), /asc/)
  assert.throws(() => order('[{"n":1}]', 'asc', 'ignore'), /policy/)
  assert.throws(() => order('[{"n":1}]', 'asc', 'error', 'date'), /type/)
  assert.throws(() => order('[{"n":1}]', 'asc', 'error', 'number', ''), /nonempty/)
  assert.throws(() => order('[{"n":1}]', 'asc', 'error', 'number', '/~x'), /~0/)
  assert.throws(() => order(' '.repeat(120001) + '[]'), /120,000/)
  assert.throws(() => order('[{"n":' + '['.repeat(65) + '0' + ']'.repeat(65) + '}]'), /64/)
  assert.throws(() => order('[' + Array(5001).fill('{"n":1}').join(',') + ']'), /10,000/)
  const args = ['[{"n":2},{"n":1}]', '', '/n', 'number', 'asc', 'error'], plan = preview(...args)
  for (let i = 0; i < args.length; i++) { const changed = [...args]; changed[i] += ' '; assert.throws(() => apply(plan, ...changed), /changed/) }
  assert.throws(() => apply(null, ...args), /changed/)
})
