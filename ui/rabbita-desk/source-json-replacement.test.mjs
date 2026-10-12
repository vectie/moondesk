import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { prepareJsonReplacement, applyJsonReplacement } from './source-json-replacement.js'

const fixture = readFileSync(new URL('../../docs/samples/json-values/orders.json', import.meta.url), 'utf8')
const replace = (text, pointer, value) => applyJsonReplacement(prepareJsonReplacement(text, pointer, value), text, pointer, value)

test('correct one nested value while preserving all other source tokens and whitespace', () => {
  const plan = prepareJsonReplacement(fixture, '/orders/0/details/paid', ' \n true\t ')
  assert.equal(plan.before, 'false'); assert.equal(plan.replacement, 'true')
  assert.equal(plan.beforeType, 'boolean'); assert.equal(plan.afterType, 'boolean')
  assert.equal(plan.output, fixture.replace('"paid": false', '"paid": true'))
  assert.equal(plan.output, readFileSync(new URL('../../docs/samples/json-values/orders-paid-draft.json', import.meta.url), 'utf8'))
  assert.equal(applyJsonReplacement(plan, fixture, plan.pointer, ' \n true\t '), plan.output)
  assert.ok(plan.output.includes('900719925474099312345'))
  assert.ok(plan.output.includes('-0.00E+09')); assert.ok(plan.output.includes('"\\u4e2D"'))
})

test('replace a subtree with a different JSON type without number coercion', () => {
  const replacement = '{ "id": 900719925474099399999, "amount": -0.00e+99, "label": "\\u4e2D", "tag": 1, "tag": 2 }'
  const output = replace(fixture, '/orders/1/amount', replacement)
  assert.equal(output, fixture.replace('12.50', replacement))
  assert.equal(replace('[null,false,0,"old",{},[]]', '/3', '[]'), '[null,false,0,[],{},[]]')
})

test('root replacement retains outer source whitespace including its final newline', () => {
  assert.equal(replace(' \r\n {"a":1} \t\r\n', '', ' \t[1, 2]\n'), ' \r\n [1, 2] \t\r\n')
  for (const value of ['null', 'false', '""', '{}', '[]', '-0']) assert.equal(replace(' 0\n', '', value), ` ${value}\n`)
})

test('exact escaped and empty keys, prototype-like names and Unicode remain addressable', () => {
  const input = '{"":{"a/b":{"~key":false}},"__proto__":7,"🚀":"old"}'
  assert.equal(replace(input, '//a~1b/~0key', 'true'), input.replace('false', 'true'))
  assert.equal(replace(input, '/__proto__', '900719925474099312345'), input.replace(':7', ':900719925474099312345'))
  assert.equal(replace(input, '/🚀', '"東京"'), input.replace('"old"', '"東京"'))
})

test('ambiguous/missing targets cannot be replaced; their unambiguous container can', () => {
  const input = '{"item":{"a":1,"\\u0061":2},"next":1}'
  assert.throws(() => replace(input, '/item/a', '0'), /ambiguous/)
  assert.throws(() => replace(input, '/missing', '0'), /does not exist/)
  assert.throws(() => replace('[1,2]', '/01', '0'), /without leading zeroes/)
  assert.equal(replace(input, '/item', '{"a":3}'), '{"item":{"a":3},"next":1}')
})

test('review binds the full draft, displayed pointer and exact replacement input', () => {
  const input = '{"a":1,"b":2}', replacement = '3'
  const plan = prepareJsonReplacement(input, '/a', replacement)
  assert.throws(() => applyJsonReplacement(plan, '{"a":1,"b":9}', '/a', replacement), /changed/)
  assert.throws(() => applyJsonReplacement(plan, input, '/b', replacement), /changed/)
  assert.throws(() => applyJsonReplacement(plan, input, '/a', ' 3'), /changed/)
  assert.throws(() => applyJsonReplacement(null, input, '/a', replacement), /changed/)
  assert.equal(applyJsonReplacement(plan, input, '/a', replacement), '{"a":3,"b":2}')
  assert.equal(prepareJsonReplacement(input, '/a', ' 1\n').changed, false)
})

test('invalid replacements and invalid source documents fail before output', () => {
  for (const value of ['', ' ', 'true false', '{"a":}', '[1,]', '"\\x00"', '/* comment */ 1', '\ufeff{}']) {
    assert.throws(() => replace('{"a":1}', '/a', value), /Replacement must be one strict JSON value/)
  }
  assert.throws(() => replace('{"a":}', '/a', '1'), /offset/)
  assert.throws(() => replace('{"a":1}', '/a', '"' + String.fromCharCode(0xd800) + '"'), /Unpaired/)
  assert.equal(replace('{"a":1}', '/a', '"\\ud800"'), '{"a":"\\ud800"}')
})

test('combined result respects explorer size, nested-container and node limits', () => {
  const largeSource = '{"a":1,"b":"' + 'x'.repeat(119_980) + '"}'
  assert.throws(() => replace(largeSource, '/a', '"' + 'y'.repeat(100) + '"'), /Result cannot be explored.*120,000/)
  const nested = '['.repeat(64) + '0' + ']'.repeat(64)
  assert.throws(() => replace('[0]', '/0', nested), /Result cannot be explored.*64 nested/)
  const many = '[' + Array(9998).fill('0').join(',') + ']'
  assert.throws(() => replace(many, '/0', '[1,2]'), /Result cannot be explored.*10,000/)
})
