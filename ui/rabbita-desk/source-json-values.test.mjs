import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { parseJsonDocument, resolveJsonPointer, jsonChildPointers, JSON_VALUE_LIMITS } from './source-json-values.js'

const fixture = readFileSync(new URL('../../docs/samples/json-values/orders.json', import.meta.url), 'utf8')
const rawAt = (text, pointer) => {
  const node = resolveJsonPointer(parseJsonDocument(text), pointer)
  return text.slice(node.start, node.end)
}

test('nested value extraction keeps exact number, whitespace and escape spelling', () => {
  assert.equal(rawAt(fixture, '/orders/0/id'), '900719925474099312345')
  assert.equal(rawAt(fixture, '/orders/0/amount'), '-0.00E+09')
  assert.equal(rawAt(fixture, '/orders/0/details/note'), '"\\u4e2D"')
  assert.equal(rawAt(fixture, '/orders/1/amount'), '12.50')
  assert.equal(rawAt(fixture, '/orders/0'), readFileSync(new URL('../../docs/samples/json-values/first-order-value.json', import.meta.url), 'utf8'))
  assert.equal(rawAt(fixture, '/orders/0/details'), '{ "paid": false, "note": "\\u4e2D" }')
  assert.equal(rawAt(fixture, ''), fixture.trim())
  assert.equal(rawAt(' 1e999 \r\n', ''), '1e999')
  assert.equal(rawAt(String.raw`"\ud800"`, ''), String.raw`"\ud800"`)
  assert.throws(() => parseJsonDocument('"' + String.fromCharCode(0xd800) + '"'), /Unpaired Unicode/)
  assert.throws(() => parseJsonDocument('"' + String.fromCharCode(0xdc00) + '"'), /Unpaired Unicode/)
})

test('pointer navigation handles exact empty, escaped, Unicode and prototype-like keys', () => {
  assert.equal(rawAt(fixture, '/a~1b/~0label'), '"🚀"')
  assert.equal(rawAt(fixture, '//0'), 'true')
  assert.equal(rawAt(fixture, '//1'), 'null')
  const text = '{"__proto__":{"constructor":7},"~1":"exact","%2F":1,"東京":[],"01":false}'
  assert.equal(rawAt(text, '/__proto__/constructor'), '7')
  assert.equal(rawAt(text, '/~01'), '"exact"')
  assert.equal(rawAt(text, '/%2F'), '1')
  assert.equal(rawAt(text, '/東京'), '[]')
  assert.equal(rawAt(text, '/01'), 'false')
  const root = parseJsonDocument(fixture)
  assert.deepEqual(jsonChildPointers(root, '').map(child => child.pointer), ['/batch', '/orders', '/a~1b', '/', '/review'])
})

test('duplicate keys remain exportable as a container but ambiguous descendants cannot be chosen', () => {
  const root = parseJsonDocument(fixture)
  assert.equal(rawAt(fixture, '/review'), '{ "tag": "first", "tag": "second" }')
  assert.throws(() => resolveJsonPointer(root, '/review/tag'), /ambiguous/)
  assert.ok(jsonChildPointers(resolveJsonPointer(root, '/review'), '/review').every(child => child.ambiguous))
  assert.throws(() => rawAt('{"a":1,"\\u0061":2}', '/a'), /ambiguous/)
})

test('missing values and malformed pointers explain a recoverable navigation failure', () => {
  const root = parseJsonDocument(fixture)
  assert.throws(() => resolveJsonPointer(root, '/orders/2'), /does not exist/)
  assert.throws(() => resolveJsonPointer(root, '/orders/01'), /without leading zeroes/)
  assert.throws(() => resolveJsonPointer(root, '/orders/-'), /not a value/)
  assert.throws(() => resolveJsonPointer(root, '/batch/x'), /scalar/)
  assert.throws(() => resolveJsonPointer(root, '#/orders'), /URI fragments/)
  assert.throws(() => resolveJsonPointer(root, '/a~2b'), /~0/)
})

test('incomplete edit blocks exploration until the entire draft is valid strict JSON', () => {
  for (const text of ['{"orders":[1,]}', '{"a":1,}', '{"a":}', '[01]', '[1.]', '{a:1}', 'true false', '"\\x00"', '"a\nb"', '\ufeff{}', '// comment\n{}', '']) {
    assert.throws(() => parseJsonDocument(text), /offset/)
  }
  const text = '{"orders":[1,2]}'
  assert.equal(rawAt(text, '/orders/1'), '2')
  for (const text of ['{}', '[]', '"quote: \\" slash: \\\\"', '-0', 'true', 'false', 'null']) {
    assert.doesNotThrow(() => parseJsonDocument(text))
  }
})

test('bounded explorer reports oversized documents and values rather than truncating output', () => {
  assert.throws(() => parseJsonDocument(' '.repeat(JSON_VALUE_LIMITS.characters + 1)), /120,000/)
  const deepest = '['.repeat(64) + '0' + ']'.repeat(64)
  assert.equal(rawAt(deepest, ''), deepest)
  assert.throws(() => parseJsonDocument(`[${deepest}]`), /64 nested/)
  assert.doesNotThrow(() => parseJsonDocument('[' + Array(9999).fill('0').join(',') + ']'))
  assert.throws(() => parseJsonDocument('[' + Array(10000).fill('0').join(',') + ']'), /10,000/)
})
