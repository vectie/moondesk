import assert from 'node:assert/strict'
import test from 'node:test'
import { resultTimestamp, resultBundles, filterResultBundles } from './workspace-results-runtime.js'
import { localDateTime, zonedInputSeconds, scheduleOccurrences, scheduleDraftPayload } from './mooncode-calendar-runtime.js'
import { roomMessages, reactionCounts } from './workspace-room-runtime.js'
import { formatMarkdownSelection } from './document-editing-runtime.js'
import { standaloneArtifactHtml } from './workspace-artifact-export.js'
import { calendarEventIcs, bookCalendarOccurrences } from './book-calendar-runtime.js'
import { cellCoordinates, sheetProjection, sheetCsv } from './document-table-runtime.js'

test('result inbox joins scheduled outcomes to output files without duplicate runs', () => {
  const bundles = resultBundles({ work: [
    { type: 'run', run_id: 'r1', title: 'Create report', status: 'done' },
    { type: 'artifact', run_id: 'r1', title: 'Report', path: 'reports/result.md' },
  ] }, [{ id: 'c1', chat: [{ role: 'background_result', content: JSON.stringify({
    id: 'b1', run_id: 'r1', summary: 'Report ready', path: 'reports/result.md', warning: true,
  }) }] }])
  assert.equal(bundles.length, 1)
  assert.equal(bundles[0].artifacts.length, 1)
  assert.equal(bundles[0].conversation_id, 'c1')
  assert.equal(filterResultBundles(bundles, 'attention', 'result.md').length, 1)
  const receipts = { [bundles[0].id]: bundles[0].revision }
  assert.equal(filterResultBundles(bundles, 'unread', '', receipts).length, 0)
  assert.equal(filterResultBundles([{ ...bundles[0], revision: 'new result' }], 'unread', '', receipts).length, 1)
  const scheduled = resultBundles({}, [], [], [{ id: 'nightly', title: 'Nightly review', session_id: 'code-nightly', last_command_id: 'run-1', last_finished_at: 1793350800, last_status: 'failed', prompt: 'Review code' }])
  assert.equal(scheduled[0].conversation_kind, 'code')
  assert.equal(scheduled[0].attention, true)
})

test('result timestamps accept server millisecond strings, schedule seconds and ISO dates', () => {
  assert.equal(resultTimestamp('1791865577432'), 1791865577432)
  assert.equal(resultTimestamp('1791865577'), 1791865577000)
  assert.equal(resultTimestamp('2026-10-13T00:00:00Z'), Date.parse('2026-10-13T00:00:00Z'))
})

test('calendar shows hourly events across the week and omits paused and past one-off work', () => {
  const start = new Date('2026-10-13T00:00:00Z')
  const seconds = start.getTime() / 1000
  const events = scheduleOccurrences([
    { id: 'hourly', enabled: true, interval_seconds: 3600, next_due_at: seconds },
    { id: 'once', enabled: true, repeat: false, interval_seconds: 60, next_due_at: seconds + 30 },
    { id: 'old', enabled: true, repeat: false, interval_seconds: 60, next_due_at: seconds - 30 },
    { id: 'paused', enabled: false, interval_seconds: 60, next_due_at: seconds },
  ], start, 2)
  assert.equal(events.filter(item => item.schedule.id === 'hourly').length, 48)
  assert.equal(events.filter(item => item.schedule.id === 'once').length, 1)
  assert.equal(events.filter(item => ['old', 'paused'].includes(item.schedule.id)).length, 0)
})

test('calendar form carries local start, one-off intent and editable title to the owner API', () => {
  const now = Date.now()
  const start = localDateTime(now / 1000 + 3600)
  const payload = scheduleDraftPayload({ id: 'task-one', title: 'Review', prompt: 'Check changes', model: 'provider/model', minutes: 60, repeat: 'once', start }, 'book-a', now)
  assert.equal(payload.action, 'update')
  assert.equal(payload.repeat, false)
  assert.equal(payload.next_due_at, new Date(start).getTime() / 1000)
  assert.throws(() => scheduleDraftPayload({ ...payload, start: 'invalid' }, 'book-a', now), /start time/)
})

test('book room groups replies under their discussion and counts human reactions', () => {
  const messages = [{ id: 'one', text: 'Question' }, { id: 'two', text: 'Answer', reply_to: 'one' }]
  assert.deepEqual(roomMessages(messages).map(item => item.id), ['one'])
  assert.deepEqual(roomMessages(messages, 'one').map(item => item.id), ['two'])
  assert.deepEqual(reactionCounts({ reactions: [{ actor_id: 'a', reaction: 'agree' }, { actor_id: 'b', reaction: 'agree' }] }), { agree: 2 })
})

test('calendar recurrence keeps local morning through daylight-saving changes and skips weekends', () => {
  const timezone = 'America/New_York'
  const friday = zonedInputSeconds('2026-10-30T09:00', timezone)
  const events = scheduleOccurrences([{ enabled: true, repeat: true, recurrence: 'weekdays', timezone, interval_seconds: 86400, next_due_at: friday }], new Date('2026-10-30T00:00:00Z'), 5)
  assert.deepEqual(events.map(event => localDateTime(event.time, timezone)), ['2026-10-30T09:00', '2026-11-02T09:00', '2026-11-03T09:00'])
  assert.equal(events[1].time - events[0].time, 3 * 86400 + 3600)
})

test('note formatting preserves surrounding text and targets whole selected lines for lists', () => {
  assert.deepEqual(formatMarkdownSelection('Hello world!', 6, 11, 'bold'), { text: 'Hello **world**!', start: 8, end: 13 })
  assert.equal(formatMarkdownSelection('First\nSecond\nThird', 0, 12, 'list').text, '- First\n- Second\nThird')
})

test('standalone artifacts export editable values and escape embedded script-like user content', () => {
  const html = standaloneArtifactHtml({ title: '<Report>', purpose: 'Keep notes', items: [{ label: '</script><script>alert(1)</script>', value: '42', done: true }] })
  assert.match(html, /&lt;Report&gt;/)
  assert.match(html, /Download updated copy/)
  assert.ok(!html.includes('</script><script>alert(1)</script>'))
  assert.match(html, /"value":"42"/)
})

test('calendar export keeps recurrence local time, reminder and document context', () => {
  const event = { id: 'review', title: 'Review, discuss', starts_at: 1793350800, ends_at: 1793354400, timezone: 'Asia/Shanghai', recurrence: 'weekdays', remind_minutes: 15, document_path: 'reports/review.md' }
  const ics = calendarEventIcs(event)
  assert.match(ics, /RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR/)
  assert.match(ics, /DTSTART;TZID=Asia\/Shanghai:/)
  assert.match(ics, /TRIGGER:-PT15M/)
  assert.ok(ics.includes('SUMMARY:Review\\, discuss'))
  assert.match(ics, /reports\/review.md/)
  assert.ok(bookCalendarOccurrences([event], new Date('2026-10-30T00:00:00Z'), 7).length > 0)
})

test('spreadsheet preview keeps sheet and cell identities and exports quoted values or formulas', () => {
  assert.deepEqual(cellCoordinates('Sheet1!$AA$20'), { column: 27, row: 20, letters: 'AA' })
  const projection = sheetProjection([{ section: 'One', reference: 'B2', text: 'hello,"world"' }, { section: 'One', reference: 'A2', text: '3', formula: '=1+2' }, { section: 'Two', reference: 'A1', text: 'other' }], 'One')
  assert.deepEqual(projection.columns, [1, 2])
  assert.equal(sheetCsv(projection), '"3","hello,""world"""')
  assert.equal(sheetCsv(projection, true), '"=1+2","hello,""world"""')
})
