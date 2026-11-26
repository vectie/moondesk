import assert from 'node:assert/strict'
import test from 'node:test'
import { extractDocxOpsFromText, parseDocxSourceInfo } from './wiki-docx-ops.js'

test('parseDocxSourceInfo reads dataset attributes or falls back to sourceUrl', () => {
  assert.deepEqual(
    parseDocxSourceInfo({
      dataset: {
        workspaceId: 'book-alpha',
        documentPath: 'drafts/proposal.docx',
      },
    }),
    { workspaceId: 'book-alpha', path: 'drafts/proposal.docx' },
  )
  assert.deepEqual(
    parseDocxSourceInfo({
      dataset: {
        sourceUrl: '/api/workspaces/book-beta/office/export?path=notes%2Fintro.docx',
      },
    }),
    { workspaceId: 'book-beta', path: 'notes/intro.docx' },
  )
})

test('extractDocxOpsFromText parses fenced docx-ops JSON blocks', () => {
  const reply = [
    'Here is the proposed highlight and insertion:',
    '```docx-ops',
    JSON.stringify({
      ops: [
        { op: 'format_range', target: { paragraph_index: 2 }, range: { start: 0, end: 5 }, style: { highlight: 'yellow' } },
        { op: 'insert_after', target: { paragraph_index: 2 }, paragraphs: ['Follow-up paragraph'] },
      ],
    }),
    '```',
  ].join('\n')
  const ops = extractDocxOpsFromText(reply)
  assert.equal(ops?.length, 2)
  assert.equal(ops?.[0]?.op, 'format_range')
  assert.equal(ops?.[1]?.op, 'insert_after')
  assert.equal(extractDocxOpsFromText('Plain answer without ops'), null)
})
