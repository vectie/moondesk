import test from 'node:test'
import assert from 'node:assert/strict'
import {parseTaskCsv} from './specialist-task-csv.js'
import {prepareDerivedColumn,applyDerivedColumn} from './source-table-derive.js'
const args = ['id,value\n001, x:: y ::z\n002,a\n003,::\n',',','value','::','2','key',false]
test('literal split preserves all original values and leading zeroes, missing parts blank',()=>{
 const plan=prepareDerivedColumn(...args), table=parseTaskCsv(plan.output)
 assert.deepEqual(table.headers,['id','value','key']);assert.deepEqual(table.rows.map(r=>r.cells.at(-1)),[' y ','',''])
 assert.deepEqual(table.rows.map(r=>r.cells.slice(0,2)),parseTaskCsv(args[0]).rows.map(r=>r.cells))
 assert.equal(applyDerivedColumn(plan,...args),plan.output)
 const trim=[...args];trim[6]=true;assert.equal(parseTaskCsv(prepareDerivedColumn(...trim).output).rows[0].cells[2],'y')
})
test('TSV, quoted newlines/quotes, Unicode, CRLF and formula-looking text round-trip',()=>{
 const source='id\tvalue\r\n001\t"東京|a\nb"\r\n002\t"=SUM(1)|""x"""\r\n'
 const plan=prepareDerivedColumn(source,'\t','value','|','2','part',false),table=parseTaskCsv(plan.output,'\t')
 assert.deepEqual(table.rows.map(r=>r.cells.at(-1)),['a\nb','"x"']);assert.equal(table.rows[1].cells[1],'=SUM(1)|"x"')
})
test('literal metacharacters and empty leading/trailing parts are not regex/coerced',()=>{
 const p=prepareDerivedColumn('x\n.*abc.*\n',',','x','.*','1','part',false);assert.equal(parseTaskCsv(p.output).rows[0].cells[1],'')
})
test('invalid selections names widths and settings refuse',()=>{
 for(const [index,value] of [[2,'missing'],[3,''],[4,'0'],[4,'1.5'],[4,'-1'],[4,'1000000'],[5,'id'],[5,' id '],[5,''],[6,'yes']]){const a=[...args];a[index]=value;assert.throws(()=>prepareDerivedColumn(...a))}
 assert.throws(()=>prepareDerivedColumn('a,b\nx\n',',','a',':','1','c',false),/width/)
 assert.throws(()=>parseTaskCsv('a;b\nx;y',';'),/separator/)
 assert.throws(()=>prepareDerivedColumn('a,a\nx,y\n',',','a',':','1','c',false),/distinct/)
})
test('bounds and stale review are enforced using actual output reparse',()=>{
 const plan=prepareDerivedColumn(...args);const changed=[...args];changed[6]=true;assert.throws(()=>applyDerivedColumn(plan,...changed),/changed/)
 const headers=Array.from({length:32},(_,i)=>'c'+i);assert.throws(()=>prepareDerivedColumn(headers.join(',')+'\n'+headers.join(','),',','c0',':','1','extra',false),/31/)
 assert.throws(()=>prepareDerivedColumn('a\n'+'x\n'.repeat(101),',','a',':','1','b',false),/100/)
 assert.throws(()=>prepareDerivedColumn('a\n'+'x'.repeat(270000),',','a',':','1','b',false),/512 KiB/)
})
