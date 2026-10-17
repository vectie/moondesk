import test from 'node:test'
import assert from 'node:assert/strict'
import { defaultTaskExploration, validateTaskExploration, exploreTaskRows } from './specialist-task-explorer.js'
import { parseTaskCsv, inspectTaskCsv } from './specialist-task-csv.js'
import { captureTaskObservation } from './specialist-task-results.js'

const form = { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}} for {{audience}}' }
function fixture(source = 'Subject,Reader,Private\nZulu,Founder,unmapped-secret\nAlpha,Ops,no\n,Founder,no\nalpha,Founder,no\nSea 海😀,Research,no') {
  const csv = { ...parseTaskCsv(source), creator: { task_form: form }, mapping: { topic: 0, audience: 1 }, corrections: {}, inspected: [] }
  csv.inspected = inspectTaskCsv(form, csv, csv.mapping).map(row => ({ ...row, brief: row.errors.length ? '' : 'Exact brief: ' + row.task }))
  return csv
}
const view = (csv, patch = {}) => exploreTaskRows(csv, { ...defaultTaskExploration, ...patch })
const indices = result => result.entries.map(entry => entry.index)

test('literal search uses only chosen current mapped inputs, retaining exact source identity', () => {
  const csv = fixture()
  assert.deepEqual(indices(view(csv, { query: 'FOUNDER', field: 'audience' })), [0, 2, 3])
  assert.deepEqual(indices(view(csv, { query: 'founder', field: 'topic' })), [])
  assert.deepEqual(indices(view(csv, { query: 'unmapped-secret' })), [])
  assert.deepEqual(indices(view(csv, { query: 'Exact brief' })), [])
  assert.deepEqual(indices(view(csv, { query: '海😀' })), [4])
  assert.deepEqual(indices(view(fixture('Subject,Reader\n.*[a],R\ntext,R'), { query: '.*[a]' })), [0])
  assert.deepEqual(indices(view(fixture('Subject,Reader\n"line one\nline two",R'), { query: 'one\nline' })), [0])
  assert.deepEqual(indices(view(csv, { query: ' Alpha ' })), []) // Search spaces remain literal.
})

test('field ordering is stable, lexical and independent from source rows or corrections', () => {
  const csv = fixture(), before = JSON.stringify(csv)
  assert.deepEqual(indices(view(csv, { sort: 'topic' })), [2, 1, 3, 4, 0])
  assert.deepEqual(indices(view(csv, { sort: 'topic', direction: 'desc' })), [0, 4, 1, 3, 2])
  assert.deepEqual(indices(view(csv, { direction: 'desc' })), [4, 3, 2, 1, 0])
  assert.deepEqual(indices(view(fixture('Subject,Reader\n2,R\n10,R\n001,R'), { sort: 'topic' })), [2, 1, 0])
  assert.equal(JSON.stringify(csv), before)
  for (const entry of view(csv, { sort: 'topic' }).entries) assert.equal(entry.row, csv.inspected[entry.index])
})

test('whole-batch counts and status intersections distinguish matching from historical observations', () => {
  const csv = fixture()
  csv.observations = [captureTaskObservation(csv, 0, csv.inspected[0], 'An actual response', ''), captureTaskObservation(csv, 0, csv.inspected[0], 'Second response', '')]
  csv.observations.push(captureTaskObservation(csv, 1, csv.inspected[1], 'Old alpha response', ''))
  csv.inspected[1] = { ...csv.inspected[1], values: { ...csv.inspected[1].values, topic: 'Changed' }, corrected: ['topic'], task: 'Changed task', brief: 'Changed brief' }
  assert.deepEqual(indices(view(csv, { status: 'observed' })), [0])
  assert.deepEqual(indices(view(csv, { status: 'unobserved' })), [1, 3, 4])
  assert.deepEqual(indices(view(csv, { status: 'historical' })), [1])
  assert.deepEqual(indices(view(csv, { status: 'needs-correction' })), [2])
  assert.deepEqual(indices(view(csv, { status: 'corrected', query: 'changed' })), [1])
  assert.deepEqual(indices(view(csv, { status: 'ready', query: 'founder' })), [0, 3])
  const result = view(csv, { query: 'nothing-matches' })
  assert.deepEqual(result.counts, { all: 5, ready: 4, 'needs-correction': 1, corrected: 1, observed: 1, unobserved: 3, historical: 1 })
  assert.equal(result.entries.length, 0); assert.equal(result.total, 5)
  csv.observations.push(captureTaskObservation(csv, 1, csv.inspected[1], 'New response', ''))
  assert.deepEqual(indices(view(csv, { status: 'historical' })), [])
  assert.equal(view(csv).entries[1].historical, 1); assert.equal(view(csv).entries[1].matching, 1)
})

test('duplicate inputs never borrow another source row observation; changed complete brief loses its match', () => {
  const csv = fixture('Subject,Reader\nDuplicate,Reader\nDuplicate,Reader')
  csv.observations = [captureTaskObservation(csv, 1, csv.inspected[1], 'Observed only row 3', '')]
  assert.deepEqual(indices(view(csv, { status: 'observed' })), [1])
  assert.deepEqual(indices(view(csv, { status: 'unobserved' })), [0])
  csv.inspected[1].brief += '\nNew file text'
  assert.deepEqual(indices(view(csv, { status: 'observed' })), [])
  assert.deepEqual(indices(view(csv, { status: 'historical' })), [1])
})

test('uninspected or partly invalidated batches never expose stale rows or observation match counts', () => {
  const csv = fixture(); csv.observations = [captureTaskObservation(csv, 0, csv.inspected[0], 'Response', '')]
  csv.inspected.pop()
  assert.equal(view(csv).inspected, false); assert.deepEqual(view(csv).entries, []); assert.equal(view(csv).counts.observed, 0)
  csv.inspected = []
  assert.equal(view(csv, { status: 'unobserved' }).entries.length, 0); assert.equal(view(csv).total, 5)
})

test('exploration validates options and copies them without mutating defaults', () => {
  const options = { ...defaultTaskExploration, query: 'x'.repeat(200) }, result = validateTaskExploration(form, options)
  assert.notEqual(result, options); assert.deepEqual(result, options)
  const invalid = [null, [], {}, { ...options, query: 'x'.repeat(201) }, { ...options, query: '\0' }, { ...options, query: 1 },
    { ...options, field: 'unknown' }, { ...options, sort: 'original_cells' }, { ...options, status: 'complete' }, { ...options, direction: 'random' }, { ...options, extra: true }]
  for (const value of invalid) assert.throws(() => validateTaskExploration(form, value), /supported task fields/)
  assert.equal(defaultTaskExploration.query, '')
})

test('100-row supported limit stays stable with ties, duplicate inputs, Unicode and corrections', () => {
  const csv = fixture('Subject,Reader\n' + Array.from({ length: 100 }, (_, i) => `${i % 2 ? '海😀' : 'same'},reader`).join('\n'))
  const result = view(csv, { sort: 'topic', direction: 'desc' })
  assert.equal(result.entries.length, 100); assert.equal(new Set(indices(result)).size, 100)
  assert.deepEqual(indices(result).slice(0, 50), Array.from({ length: 50 }, (_, i) => i * 2 + 1))
  assert.deepEqual(csv.rows.map(row => row.number), Array.from({ length: 100 }, (_, i) => i + 2))
})
