import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareJsonMove, applyJsonMove } from './source-json-move.js'

test('reordering creator steps uses post-removal positions and keeps exact value lexemes', () => {
  const raw = ' {"steps":[{"id":9007199254740993123,"n":1e+02},{"id":-0},{"id":"\\u0061"}],"keep": 12.50} \r\n'
  const plan = prepareJsonMove(raw, '/steps/0', '/steps', '', '2')
  assert.equal(plan.output, ' {"steps":[{"id":-0},{"id":"\\u0061"},{"id":9007199254740993123,"n":1e+02}],"keep": 12.50} \r\n')
  assert.equal(plan.movedPointer, '/steps/2')
  assert.equal(applyJsonMove(plan, raw, '/steps/0', '/steps', '', '2'), plan.output)
  assert.equal(prepareJsonMove(plan.output, '/steps/2', '/steps', '', '0').output, raw)
})
test('cross-container move remaps a later sibling destination without selecting another node', () => {
  const plan = prepareJsonMove('[1e+02,{"tasks":[-0]}]', '/0', '/1/tasks', '', '1')
  assert.equal(plan.output, '[{"tasks":[-0,1e+02]}]')
  assert.equal(plan.targetPointer, '/0/tasks'); assert.equal(plan.movedPointer, '/0/tasks/1')
})
test('moves into ancestors, earlier containers, empty objects and escaped keys preserve values', () => {
  assert.equal(prepareJsonMove('{"nest":{"a":1},"keep":2}', '/nest/a', '', 'a/b~', '1').output, '{"nest":{},"a/b~": 1,"keep":2}')
  assert.equal(prepareJsonMove('{"target":[],"a/b~":{"":true}}', '/a~1b~0/', '/target', '', '0').output, '{"target":[true],"a/b~":{}}')
  const emptyKey = prepareJsonMove('{"source":[-0],"target":{}}', '/source/0', '/target', '', '0')
  assert.equal(emptyKey.output, '{"source":[],"target":{"": -0}}'); assert.equal(emptyKey.movedPointer, '/target/')
  assert.equal(prepareJsonMove('{"one":{"__proto__":1},"two":{}}', '/one/__proto__', '/two', '__proto__', '0').output, '{"one":{},"two":{"__proto__": 1}}')
})
test('invalid destinations, collisions, duplicate keys and out-of-range positions fail without edits', () => {
  for (const args of [
    ['[0]', '', '', '', '0'], ['[0]', '/0', '/0', '', '0'], ['{"a":{"b":[]}}', '/a', '/a/b', '', '0'],
    ['{"a":1,"b":2}', '/a', '/b', '', '0'], ['{"a":1,"b":2}', '/a', '', 'b', '0'],
    ['{"a":1,"a":2}', '/a', '', 'new', '0'], ['[0,1]', '/0', '', '', '2'], ['[0,1]', '/0', '', '', '01'],
    ['[0]', '/00', '', '', '0'], ['[0]', '/0', '/missing', '', '0'], ['[0,1]', '/0', '', '', '0'],
  ]) assert.throws(() => prepareJsonMove(...args), JSON.stringify(args))
})
test('every changed preview binding is checked again before applying', () => {
  const args = ['[0,1]', '/0', '', '', '1'], plan = prepareJsonMove(...args)
  for (let index = 0; index < args.length; index++) {
    const changed = [...args]; changed[index] += ' '
    assert.throws(() => applyJsonMove(plan, ...changed), /changed/)
  }
  assert.throws(() => applyJsonMove(null, ...args), /changed/)
})
