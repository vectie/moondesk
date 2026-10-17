import test from 'node:test'
import assert from 'node:assert/strict'
import { prepareTableReshape, applyTableReshape } from './source-table-reshape.js'
import { parseTaskCsv } from './specialist-task-csv.js'

test('wide to long keeps identifiers and uses row-major, source-column order', () => {
  const text = 'account,Jan,Feb\n001,10,20\n002,30,40\n'
  const plan = prepareTableReshape(text, ',', ['Feb', 'Jan'], 'month', 'amount')
  assert.equal(plan.text, text)
  assert.deepEqual(plan.preview.headers, ['account', 'month', 'amount'])
  assert.deepEqual(plan.preview.rows.map(row => row.cells), [['001', 'Jan', '10'], ['001', 'Feb', '20'], ['002', 'Jan', '30'], ['002', 'Feb', '40']])
  assert.deepEqual(plan.preview.rows.map(row => row.sourceRecord), [2, 2, 3, 3])
  assert.equal(applyTableReshape(plan, text, ',', ['Feb', 'Jan'], 'month', 'amount'), plan.output)
})
test('CSV round-trip preserves quoted multiline, quotes, commas, blanks, zeros and formula text', () => {
  const text = 'id,Jan,Feb\r\n"00,1","line1\r\nline2",""\r\n001,"=1+1","say ""hi"""\r\n001,,+42\r\n'
  const plan = prepareTableReshape(text, ',', ['Jan', 'Feb'], 'measurement', 'literal')
  assert.deepEqual(parseTaskCsv(plan.output).rows.map(row => row.cells), [['00,1', 'Jan', 'line1\r\nline2'], ['00,1', 'Feb', ''], ['001', 'Jan', '=1+1'], ['001', 'Feb', 'say "hi"'], ['001', 'Jan', ''], ['001', 'Feb', '+42']])
  assert.equal(plan.bytes, new TextEncoder().encode(plan.output).length)
})
test('TSV preserves Unicode and quoted tabs and supports selecting every column', () => {
  const plan = prepareTableReshape('\uFEFF猫\t月\n"一\t二"\t😀\n\t001\n', '\t', ['月', '猫'], '項目', '値')
  assert.deepEqual(plan.preview.headers, ['項目', '値'])
  assert.deepEqual(parseTaskCsv(plan.output, '\t').rows.map(row => row.cells), [['猫', '一\t二'], ['月', '😀'], ['猫', ''], ['月', '001']])
})
test('measure names match exactly and reject missing, repeated and empty selections', () => {
  const text = 'id, Jan ,jan\na,1,2\n'
  assert.deepEqual(prepareTableReshape(text, ',', [' Jan '], 'month', 'amount').preview.headers, ['id', 'jan', 'month', 'amount'])
  for (const names of [[], ['Jan'], ['JAN'], [' Jan ', ' Jan '], ['missing'], null, [0]]) assert.throws(() => prepareTableReshape(text, ',', names, 'month', 'amount'), /exact, distinct/)
})
test('output names are explicit, bounded and collision checked against retained headers', () => {
  const prepare = (variable, value) => prepareTableReshape('id,Jan\na,1\n', ',', ['Jan'], variable, value)
  for (const names of [['', 'value'], ['x', ' '], [null, 'x'], ['x'.repeat(201), 'x'], ['a\0', 'x']]) assert.throws(() => prepare(...names), /nonblank/)
  for (const names of [['id', 'x'], [' id ', 'x'], ['x', 'x'], ['x', ' x ']]) assert.throws(() => prepare(...names), /distinct/)
  assert.deepEqual(prepare('Jan', 'value').preview.headers, ['id', 'Jan', 'value'])
})
test('rejects malformed, ragged, duplicate, empty, excessive and NUL input without mutation', () => {
  for (const text of ['id,Jan\n"oops', 'id,Jan\na\n', 'id,Jan\na,1,2\n', 'id,id\na,1\n', 'id,Jan\n', 'id,Jan\na,\0\n', 'id,Jan\n' + 'a,1\n'.repeat(101), 'id,Jan\na,' + 'x'.repeat(524288)]) assert.throws(() => prepareTableReshape(text, ',', ['Jan'], 'm', 'v'))
  assert.throws(() => prepareTableReshape('id,Jan\na,1\n', ';', ['Jan'], 'm', 'v'), /separator/)
})
test('preflights expansion at exact 100-record and 32-column boundaries', () => {
  assert.equal(prepareTableReshape('id,a,b\n' + 'x,1,2\n'.repeat(50), ',', ['a', 'b'], 'm', 'v').count, 100)
  assert.throws(() => prepareTableReshape('id,a,b\n' + 'x,1,2\n'.repeat(51), ',', ['a', 'b'], 'm', 'v'), /102 records/)
  const headers = Array.from({length: 32}, (_, index) => 'c' + index)
  const text = headers.join(',') + '\n' + headers.map(() => 'x').join(',') + '\n'
  assert.throws(() => prepareTableReshape(text, ',', ['c31'], 'm', 'v'), /32 output columns/)
  assert.equal(prepareTableReshape(text, ',', ['c30', 'c31'], 'm', 'v').preview.headers.length, 32)
})
test('preflights UTF-8 expansion and quoting before building the expanded output', () => {
  const text = 'id,a,b\n' + '界'.repeat(90000) + ',1,2\n'
  assert.ok(new TextEncoder().encode(text).length < 524288)
  assert.throws(() => prepareTableReshape(text, ',', ['a', 'b'], 'm', 'v'), /output would exceed 512 KiB/)
  const quoteHeavy = 'id,a\n"' + '""'.repeat(262130) + '",1\n'
  assert.ok(new TextEncoder().encode(quoteHeavy).length < 524288)
  assert.throws(() => prepareTableReshape(quoteHeavy, ',', ['a'], 'measurement', 'value'), /output would exceed 512 KiB/)
})
test('accepts exact 512 KiB output and rejects the next byte', () => {
  const framing = '"id","m","v"\n"","a","1"\n'
  const identifier = 'x'.repeat(524288 - new TextEncoder().encode(framing).length)
  const text = 'id,a\n' + identifier + ',1\n'
  assert.equal(prepareTableReshape(text, ',', ['a'], 'm', 'v').bytes, 524288)
  assert.throws(() => prepareTableReshape('id,a\n' + identifier + 'x,1\n', ',', ['a'], 'm', 'v'), /output would exceed 512 KiB/)
})
test('Apply rejects stale input, names, selection, delimiter and tampered preview', () => {
  const args = ['id,a,b\nx,1,2\n', ',', ['a', 'b'], 'm', 'v']
  const plan = prepareTableReshape(...args)
  assert.throws(() => applyTableReshape(null, ...args), /Preview/)
  for (const next of [[args[0] + 'y,3,4\n', ...args.slice(1)], [args[0], ',', ['a'], 'm', 'v'], [args[0], ',', ['b', 'a'], 'm', 'v'], [args[0], ',', ['a', 'b'], 'month', 'v'], [args[0], '\t', ['a', 'b'], 'm', 'v']]) assert.throws(() => applyTableReshape(plan, ...next))
  const tampered = structuredClone(plan); tampered.output = 'unreviewed'
  assert.throws(() => applyTableReshape(tampered, ...args), /changed/)
})
