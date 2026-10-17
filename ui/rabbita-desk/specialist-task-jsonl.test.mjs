import test from 'node:test'
import assert from 'node:assert/strict'
import { parseTaskJsonl } from './specialist-task-jsonl.js'
import { inspectTaskCsv } from './specialist-task-csv.js'

test('JSON Lines imports literal fields, reordered keys and escaped multiline strings into an editable table', () => {
  const table = parseTaskJsonl('\ufeff{"topic":"001.20 海😀\\nquote \\"","audience":"=1+2"}\r\n{"audience":"  reader  ","topic":"$& {{other}}"}\r\n')
  assert.deepEqual(table.headers, ['topic', 'audience'])
  assert.deepEqual(table.rows.map(row => row.cells), [['001.20 海😀\nquote "', '=1+2'], ['$& {{other}}', '  reader  ']])
  const form = { contract: 'moondesk.specialist-task-form.v1', template: '{{topic}} for {{audience}}' }
  assert.throws(() => inspectTaskCsv(form, table, {}), /Map/)
  assert.equal(inspectTaskCsv(form, table, { topic: 0, audience: 1 })[1].task, '$& {{other}} for   reader  ')
})

test('JSONL refuses type coercion, duplicate decoded keys, malformed records and schema differences', () => {
  for (const value of ['', '{}', '[]', '{"x":1}', '{"x":true}', '{"x":null}', '{"x":[]}', '{"x":{}}', '{"x":"a","x":"b"}', '{"x":"a","\\u0078":"b"}', '{"x":"a",}', '{"x":"a"} garbage', '{"x":"a"}\n\n', '{"x":"a"}\n{"y":"b"}', '{"x":"a"}\n{"x":"b","y":"c"}', '{" ":"a"}', '{"x":"\\u0000"}']) assert.throws(() => parseTaskJsonl(value), value)
})

test('JSONL enforces bounded records, fields, byte size and decoded header uniqueness', () => {
  assert.equal(parseTaskJsonl(Array(100).fill('{"x":"a"}').join('\n')).rows.length, 100)
  assert.throws(() => parseTaskJsonl(Array(101).fill('{"x":"a"}').join('\n')), /100/)
  assert.throws(() => parseTaskJsonl(JSON.stringify(Object.fromEntries(Array.from({ length: 33 }, (_, i) => ['k' + i, 'v'])))), /32/)
  assert.throws(() => parseTaskJsonl('{"x":"' + 'é'.repeat(262144) + '"}'), /512/)
  assert.throws(() => parseTaskJsonl('{"x":"a"," x ":"b"}'), /distinct/)
  const table = parseTaskJsonl('{"__proto__":"literal","constructor":"also literal"}')
  assert.deepEqual(table.rows[0].cells, ['literal', 'also literal'])
})
