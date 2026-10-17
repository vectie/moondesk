import test from 'node:test'
import assert from 'node:assert/strict'
import {prepareDuplicateKeys as prepare, applyDuplicateKeys as apply} from './source-table-deduplicate.js'
import {parseTaskCsv} from './specialist-task-csv.js'
test('first/last preserve original order, exact keys and full conflicting records', () => {
  const text = 'id,name\n001,old\n1,one\n001,new\n 001,space\nA,upper\na,lower\n'
  const first = prepare(text, ',', ['id'], 'first'), last = prepare(text, ',', ['id'], 'last')
  assert.deepEqual(first.preview.removed.map(r => r.number), [4])
  assert.deepEqual(last.preview.retained.map(r => r.number), [3,4,5,6,7])
  assert.deepEqual(last.preview.duplicates[0], {key:['001'], records:[{number:2,cells:['001','old']},{number:4,cells:['001','new']}], keep:4})
  assert.equal(apply(last,text,',',['id'],'last'),last.output)
  assert.deepEqual(parseTaskCsv(last.output).rows.map(r=>r.cells[0]),['1','001',' 001','A','a'])
  assert.equal(new Set(parseTaskCsv(last.output).rows.map(r=>r.cells[0])).size,5)
})
test('composite tuple keys, quoted multiline CSV and TSV keep exact values', () => {
  const text = 'a\tb\tv\n"a|b"\tc\t"old\nvalue"\na\t"b|c"\tdistinct\n"a|b"\tc\t"new ""quoted"""\n'
  const plan=prepare(text,'\t',['a','b'],'last')
  assert.deepEqual(plan.preview.removed[0],{number:2,cells:['a|b','c','old\nvalue']})
  assert.deepEqual(parseTaskCsv(plan.output,'\t').rows.map(r=>r.cells),[['a','b|c','distinct'],['a|b','c','new "quoted"']])
  assert.equal(plan.output.includes('\r'),false)
})
test('blank tuple components are visible unresolved and always retained',()=>{
  const p=prepare('id,v\n,x\n ,y\n,z\na,1\na,2\n',',',['id'],'first')
  assert.deepEqual(p.preview.unresolvedBlankKeys.map(r=>r.number),[2,3,4])
  assert.equal(p.preview.retained.length,4);assert.equal(p.preview.removed.length,1)
})
test('invalid selection, malformed widths, limits and stale settings reject',()=>{
  const text='id,v\na,1\na,2\n', p=prepare(text,',',['id'],'first')
  for(const keys of [[],['missing'],['id','id']]) assert.throws(()=>prepare(text,',',keys,'first'))
  assert.throws(()=>prepare(text,',',['id'],'auto'))
  assert.throws(()=>prepare('id,v\na\n',',',['id'],'first'),/width/)
  assert.throws(()=>prepare('id\n'+'a\n'.repeat(101),',',['id'],'first'),/100/)
  assert.throws(()=>apply(p,text,',',['id'],'last'),/changed/)
  assert.throws(()=>apply(p,text+'b,3\n',',',['id'],'first'),/changed/)
})
