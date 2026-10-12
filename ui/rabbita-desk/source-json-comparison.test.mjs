import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { compareJsonDocuments, jsonComparisonReport } from './source-json-comparison.js'

const sample = name => readFileSync(new URL(`../../docs/samples/json-comparison/${name}.json`, import.meta.url), 'utf8')

test('sample comparison discovers exact nested differences independent of object order', () => {
  const before = sample('reference'), after = sample('current')
  const result = compareJsonDocuments(before, after)
  assert.deepEqual(result.counts, { added: 2, removed: 1, changed: 3, total: 6 })
  assert.deepEqual(result.changes.map(change => [change.kind, change.pointer]), [
    ['changed', '/account/plan'], ['removed', '/account/legacy'], ['changed', '/orders/1/amount'],
    ['added', '/orders/2'], ['changed', '/a~1b/~0flag'], ['added', '/enabled'],
  ])
  assert.equal(result.changes[2].before.json, '10'); assert.equal(result.changes[2].after.json, '12.5')
  assert.equal(result.changes[1].after, null); assert.equal(result.changes[5].before, null)
  assert.equal(result.changes[5].after.type, 'null'); assert.equal(result.changes[5].after.json, 'null')
  for (const change of result.changes) for (const [side, text] of [['before', before], ['after', after]]) {
    const value = change[side]
    if (value) assert.equal(text.slice(value.start, value.end), value.json)
  }
})

test('formatting, object order and decoded string escape spelling do not create differences', () => {
  const result = compareJsonDocuments('{"a": "\\u4e2D", "nested":{"x":1,"y":[]}}', ' { "nested": {"y":[],"x":1}, "\\u0061":"中" } ')
  assert.equal(result.counts.total, 0)
  assert.deepEqual(compareJsonDocuments('"\\ud83d\\ude80"', '"🚀"').changes, [])
  assert.deepEqual(compareJsonDocuments('"\\ud800"', '"\\uD800"').changes, [])
})

test('large numbers and exponent spelling remain exact without numeric coercion', () => {
  const result = compareJsonDocuments('[900719925474099312345,-0,1e0,1.00]', '[900719925474099312346,0,1E0,1]')
  assert.equal(result.counts.changed, 4)
  assert.equal(result.changes[0].before.json, '900719925474099312345')
  assert.equal(result.changes[0].after.json, '900719925474099312346')
  assert.deepEqual(result.changes.map(x => x.pointer), ['/0', '/1', '/2', '/3'])
})

test('type changes and added or removed containers are single complete subtree differences', () => {
  const result = compareJsonDocuments('{"x":false,"old":{"a":[1,2]},"same":null}', '{"x":{"v":true},"new":[3,4],"same":null}')
  assert.deepEqual(result.changes.map(x => [x.kind, x.pointer]), [['changed', '/x'], ['removed', '/old'], ['added', '/new']])
  assert.equal(result.changes[0].after.json, '{"v":true}')
  assert.equal(result.changes[1].before.json, '{"a":[1,2]}')
  assert.deepEqual(compareJsonDocuments('null', '[]').changes.map(x => x.pointer), [''])
})

test('arrays compare positions and never infer identity matching or moved records', () => {
  const result = compareJsonDocuments('[{"id":"a"},{"id":"b"}]', '[{"id":"b"}]')
  assert.deepEqual(result.changes.map(x => [x.kind, x.pointer]), [['changed', '/0/id'], ['removed', '/1']])
  assert.equal(result.changes[1].before.json, '{"id":"b"}')
})

test('exact member names, empty keys and prototype names remain ordinary pointer tokens', () => {
  const result = compareJsonDocuments('{"":1,"a/b":2,"~x":3,"__proto__":4,"constructor":5}', '{"":2,"a/b":3,"~x":4,"__proto__":5,"constructor":6}')
  assert.deepEqual(result.changes.map(x => x.pointer), ['/', '/a~1b', '/~0x', '/__proto__', '/constructor'])
  assert.deepEqual(compareJsonDocuments('{"Case":1}', '{"case":1}').changes.map(x => x.kind), ['removed', 'added'])
})

test('duplicate decoded keys on either input stop comparison instead of choosing an occurrence', () => {
  assert.throws(() => compareJsonDocuments('{"x":1,"\\u0078":1}', '{}'), /Reference JSON: duplicate object member.*\/x/)
  assert.throws(() => compareJsonDocuments('{}', '{"nested":{"a":1,"a":2}}'), /Current draft: duplicate object member.*\/nested\/a/)
  assert.throws(() => compareJsonDocuments('{"x":1,"x":1}', '{"x":1,"x":1}'), /duplicate/)
})

test('strict document bounds and failures identify the input without a partial result', () => {
  assert.throws(() => compareJsonDocuments('{"x":}', '{}'), /Reference JSON:.*offset/)
  assert.throws(() => compareJsonDocuments('{}', '{"x":true,}'), /Current draft:.*offset/)
  assert.throws(() => compareJsonDocuments('null', ' '.repeat(120001)), /Current draft:.*120,000/)
  assert.throws(() => compareJsonDocuments('['.repeat(65) + '0' + ']'.repeat(65), 'null'), /Reference JSON:.*64 nested/)
  assert.throws(() => compareJsonDocuments('"\ud800"', 'null'), /surrogate/)
  assert.throws(() => compareJsonDocuments('\ufeff{}', '{}'), /Reference JSON/)
  assert.throws(() => compareJsonDocuments('{}\n{}', '{}'), /content after/)
})

test('1,000 differences are complete and larger reports fail explicitly', () => {
  const before = JSON.stringify(Array(1000).fill(0)), after = JSON.stringify(Array(1000).fill(1))
  assert.equal(compareJsonDocuments(before, after).counts.total, 1000)
  assert.throws(() => compareJsonDocuments(JSON.stringify(Array(1001).fill(0)), JSON.stringify(Array(1001).fill(1))), /no partial report/)
  const key = 'long'.repeat(500)
  assert.throws(() => compareJsonDocuments(JSON.stringify({ [key]: Array(600).fill(0) }), JSON.stringify({ [key]: Array(600).fill(1) })), /paths and changed values exceed 1,000,000/)
})

test('downloaded JSON report reopens with complete changed tokens and clear source scope', () => {
  const before = '{"unchangedSecret":"not-in-report","large":900719925474099312345,"long":"old"}'
  const after = '{"unchangedSecret":"not-in-report","large":900719925474099312346,"long":"' + 'x'.repeat(4500) + '"}'
  const report = jsonComparisonReport(compareJsonDocuments(before, after), { workspaceId: 'book', sourcePath: 'config.json' })
  const reopened = JSON.parse(report)
  assert.equal(reopened.schema, 'moondesk.json-comparison.v1')
  assert.equal(reopened.changes[0].after.json, '900719925474099312346')
  assert.equal(reopened.changes[1].after.json.length, 4502)
  assert.equal(reopened.source.path, 'config.json'); assert.match(reopened.source.before, /Pasted reference/)
  assert.match(reopened.source.scope, /not a patch/); assert.doesNotMatch(report, /not-in-report/)
  assert.equal(JSON.parse(jsonComparisonReport(compareJsonDocuments('{}', '{}'), {})).counts.total, 0)
})
