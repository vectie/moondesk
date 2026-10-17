import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareJsonCopy, applyJsonCopy } from './source-json-copy.js'
import { parseJsonDocument, resolveJsonPointer } from './source-json-values.js'

const rawAt = (text, pointer) => { const node = resolveJsonPointer(parseJsonDocument(text), pointer); return text.slice(node.start, node.end) }

test('copies complete exact subtrees without number, escape, duplicate-key or whitespace normalization', () => {
  const raw = '{ "id":900719925474099312345,"n":-0,"n":1e+02,"s":"\\u0061","many":[' + '1,'.repeat(3000) + '2] }'
  const text = ' \r\n{"source":' + raw + ',"dest":[]}\t'
  const args = [text, '/source', '/dest', '', '0'], plan = prepareJsonCopy(...args)
  assert.equal(plan.output, ' \r\n{"source":' + raw + ',"dest":[' + raw + ']}\t')
  assert.equal(rawAt(plan.output, '/source'), raw)
  assert.equal(rawAt(plan.output, '/dest/0'), raw)
  assert.equal(applyJsonCopy(plan, ...args), plan.output)
  assert.ok(Object.isFrozen(plan))
})

test('same-array first, middle, last insertion uses original source before index shifts', () => {
  for (const [position, expected] of [['0','[2.00,1, 2.00,3]'], ['1','[1, 2.00,2.00,3]'], ['3','[1, 2.00,3,2.00]']]) {
    const plan = prepareJsonCopy('[1, 2.00,3]', '/1', '', '', position)
    assert.equal(plan.output, expected); assert.equal(rawAt(plan.output, plan.copiedPointer), '2.00')
  }
})

test('object copies support escaped and empty keys and preserve existing members', () => {
  const plan = prepareJsonCopy('{"a/b~":true,"dst":{}}', '/a~1b~0', '/dst', '', '0')
  assert.equal(plan.output, '{"a/b~":true,"dst":{"": true}}')
  assert.equal(plan.copiedPointer, '/dst/')
  const escaped = prepareJsonCopy('[null,{}]', '/0', '/1', 'x/y~', '0')
  assert.equal(escaped.copiedPointer, '/1/x~1y~0'); assert.equal(rawAt(escaped.output, escaped.copiedPointer), 'null')
})

test('root and ancestor copies into descendants insert finite original snapshots', () => {
  assert.equal(prepareJsonCopy('{"items":[]}', '', '/items', '', '0').output, '{"items":[{"items":[]}]}')
  assert.equal(prepareJsonCopy('{"a":{"children":[]}}', '/a', '/a/children', '', '0').output, '{"a":{"children":[{"children":[]}]}}')
})

test('invalid destinations, ambiguous sources, duplicate keys and malformed input never produce a plan', () => {
  for (const args of [
    ['{"a":1}', '/a', '', 'a', '0'], ['{"a":1}', '/a', '/a', '', '0'],
    ['[1]', '/1', '', '', '0'], ['[1]', '/0', '/bad', '', '0'],
    ['[1]', '/0', '', '', '2'], ['[1]', '/0', '', '', '01'],
    ['{"a":1,"\\u0061":2}', '/a', '', 'b', '0'], ['[1,]', '/0', '', '', '0'],
  ]) assert.throws(() => prepareJsonCopy(...args))
})

test('every changed review input requires another preview', () => {
  const args = ['[1,[]]', '/0', '/1', '', '0'], plan = prepareJsonCopy(...args)
  for (let index = 0; index < args.length; index++) {
    const changed = [...args]; changed[index] += ' '
    assert.throws(() => applyJsonCopy(plan, ...changed), /changed/)
  }
  assert.throws(() => applyJsonCopy(null, ...args), /changed/)
})
