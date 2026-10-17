import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareJsonRemoval, applyJsonRemoval } from './source-json-removal.js'
test('first middle last and only children keep surviving tokens exact', () => {
  for (const [text, pointers, expected] of [
    [' [1e+02, -0, 9007199254740993123] \n', ['/0','/1','/2'], [' [-0, 9007199254740993123] \n',' [1e+02, 9007199254740993123] \n',' [1e+02, -0] \n']],
    ['{ "a": 1, "b": 2, "c": 3 }', ['/a','/b','/c'], ['{ "b": 2, "c": 3 }','{ "a": 1, "c": 3 }','{ "a": 1, "b": 2 }']],
    ['{ "a/b~": [ 1 ] }', ['/a~1b~0/0','/a~1b~0'], ['{ "a/b~": [  ] }','{  }']],
    ['{"":true}', ['/'], ['{}']],
  ]) for (let i=0;i<pointers.length;i++) {
    const plan=prepareJsonRemoval(text,pointers[i]); assert.equal(plan.output,expected[i]); assert.equal(applyJsonRemoval(plan,text,pointers[i]),expected[i]);
    assert.equal(plan.output,text.slice(0,plan.start)+text.slice(plan.end));
  }
})
test('root, missing, ambiguous and stale targets cannot apply', () => {
  for (const [text,pointer] of [['[]',''],['[0]','/2'],['{"a":1,"a":2}','/a'],['[0]','/00']]) assert.throws(()=>prepareJsonRemoval(text,pointer));
  const plan=prepareJsonRemoval('[1,2]','/0');
  assert.throws(()=>applyJsonRemoval(plan,'[2,1]','/0'),/changed/);
  assert.throws(()=>applyJsonRemoval(plan,'[1,2]','/1'),/changed/);
})
