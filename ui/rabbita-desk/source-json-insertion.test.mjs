import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareJsonInsertion, applyJsonInsertion } from './source-json-insertion.js'

test('insertion first, middle and last preserves every existing byte and exact new tokens', () => {
  for (const [text, key, expected] of [
    [' [1e+02, 9007199254740993123] \n', '', [' [-0,1e+02, 9007199254740993123] \n', ' [1e+02, -0,9007199254740993123] \n', ' [1e+02, 9007199254740993123,-0] \n']],
    ['{"a":1e+02, "b":9007199254740993123}', 'c', ['{"c": -0,"a":1e+02, "b":9007199254740993123}', '{"a":1e+02, "c": -0,"b":9007199254740993123}', '{"a":1e+02, "b":9007199254740993123,"c": -0}']],
  ]) {
    for (let i = 0; i < 3; i++) {
      const plan = prepareJsonInsertion(text, '', key, String(i), ' -0 ')
      assert.equal(plan.output, expected[i])
      assert.equal(plan.output.slice(0, plan.start) + plan.output.slice(plan.start + plan.insertion.length), text)
      assert.equal(applyJsonInsertion(plan, text, '', key, String(i), ' -0 '), expected[i])
    }
  }
})

test('empty containers, escaped keys and duplicate keys have explicit behavior', () => {
  assert.equal(prepareJsonInsertion('{ "a/b~": [ ] }', '/a~1b~0', '', '0', '1.00').output, '{ "a/b~": [1.00 ] }')
  assert.equal(prepareJsonInsertion('{}', '', '"/\\~', '0', 'true').output, '{"\\\"/\\\\~": true}')
  assert.equal(prepareJsonInsertion('{ }', '', '', '0', 'null').output, '{"": null }')
  assert.throws(() => prepareJsonInsertion('{"\\u0061":1}', '', 'a', '1', '2'), /decoded key/)
  assert.throws(() => prepareJsonInsertion('{"a":{},"a":{}}', '/a', 'b', '0', '2'), /ambiguous/)
  assert.equal(prepareJsonInsertion('{"a":1,"a":2}', '', 'b', '2', '3').output, '{"a":1,"a":2,"b": 3}')
})

test('invalid inputs and stale plans cannot mutate the draft', () => {
  for (const position of ['-1', '01', '2', '1.5', '', 'Infinity']) assert.throws(() => prepareJsonInsertion('[1]', '', '', position, '2'), /Position/)
  assert.throws(() => prepareJsonInsertion('0', '', '', '0', '2'), /object or array/)
  assert.throws(() => prepareJsonInsertion('[]', '', '', '0', '2,'), /strict JSON/)
  const plan = prepareJsonInsertion('[]', '', '', '0', '2')
  assert.throws(() => applyJsonInsertion(plan, '[1]', '', '', '0', '2'), /changed/)
  assert.throws(() => applyJsonInsertion(plan, '[]', '', '', '0', '3'), /changed/)
  assert.throws(() => applyJsonInsertion(plan, '[]', '', 'x', '0', '2'), /changed/)
  assert.throws(() => prepareJsonInsertion('[]', '', '', '0', '"' + 'x'.repeat(119998) + '"'), /Result cannot/)
})
