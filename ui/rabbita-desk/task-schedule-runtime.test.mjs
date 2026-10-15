import test from 'node:test'
import assert from 'node:assert/strict'
import { renderTaskSchedule, taskScheduleEditDraft, taskSchedulePayload } from './task-schedule-runtime.js'
import { localDateTime } from './mooncode-calendar-runtime.js'

class Field {
  constructor(tag, className = '', text = '') { this.tagName = tag; this.className = className; this.textContent = text; this.children = []; this.value = '' }
  append(...children) { this.children.push(...children) }
  replaceChildren(...children) { this.children = children }
  setAttribute(name, value) { this[name] = value }
}
const el = (...args) => new Field(...args)
const nodes = root => [root, ...root.children.flatMap(nodes)]

test('editing a one-time schedule preserves its instant and does not duplicate task context', () => {
  const when = Date.now() / 1000 + 86400
  const draft = taskScheduleEditDraft({ id: 'one', title: 'Report', prompt: 'Write report\n\nSources in this MoonBook:\ninbox/source.csv\n\nUpdate these outputs and keep their paths:\ninbox/report.md', model: 'provider/model', next_due_at: when, interval_seconds: 86400, repeat: false }, {})
  assert.equal(draft.start, localDateTime(when, draft.timezone))
  assert.equal(draft.prompt, 'Write report')
  const payload = taskSchedulePayload(draft, { workspaceId: 'book-a', bundle: { artifacts: [{ path: 'inbox/report.md' }] }, thread: { position: { files: ['inbox/source.csv'] } } })
  assert.equal(payload.action, 'update')
  assert.equal(payload.repeat, false)
  assert.equal((payload.prompt.match(/Sources in this MoonBook:/g) || []).length, 1)
})

test('schedule form saves a real request and retains its origin through refresh and retry', async () => {
  const savedFetch = globalThis.fetch; const savedStorage = globalThis.localStorage
  const values = new Map(); const requests = []; let unavailable = true
  globalThis.localStorage = { getItem: key => values.get(key), setItem: (key, value) => values.set(key, value) }
  globalThis.fetch = async (url, options) => {
    requests.push({ url, body: JSON.parse(options.body) })
    return unavailable ? { ok: false, status: 503, json: async () => ({ message: 'Owner unavailable' }) } : { ok: true, json: async () => ({ schedules: [{ id: requests.at(-1).body.id }] }) }
  }
  try {
    const origin = { workspaceId: 'book-report', model: 'provider/model', models: ['provider/model'],
      bundle: { title: 'Weekly report', artifacts: [{ path: 'inbox/report.md' }] },
      thread: { id: 'report-chat', position: { files: ['inbox/revenue.csv'] }, chat: [{ role: 'user', content: 'Write the weekly report' }] } }
    let root = renderTaskSchedule(origin, { el, onClose() {} })
    const form = nodes(root).find(node => node.tagName === 'form')
    await form.onsubmit({ preventDefault() {} })
    assert.equal(origin.saved, undefined)
    assert.match(nodes(root).map(node => node.textContent).join(' '), /Your draft is kept/)
    const firstId = requests[0].body.id
    unavailable = false
    root = renderTaskSchedule(origin, { el, onClose() {} })
    await nodes(root).find(node => node.tagName === 'form').onsubmit({ preventDefault() {} })
    assert.equal(requests[1].body.id, firstId)
    assert.equal(requests[1].body.book_id, 'book-report')
    assert.match(requests[1].body.prompt, /inbox\/revenue.csv/)
    assert.match(requests[1].body.prompt, /inbox\/report.md/)
    const binding = JSON.parse(values.get('moondesk.task-schedules.v1'))[firstId]
    assert.equal(binding.conversationId, 'report-chat')
    assert.equal(origin.saved, firstId)
    assert.equal(nodes(renderTaskSchedule(origin, { el, onClose() {} })).some(node => node.tagName === 'form'), false)
  } finally { globalThis.fetch = savedFetch; globalThis.localStorage = savedStorage }
})

test('real MoonDesk proxy and MoonTown owner retain, update and finish schedule intent', { skip: !process.env.MOONDESK_JOURNEY_API }, async () => {
  const base = process.env.MOONDESK_JOURNEY_API
  const id = `journey-check-${Date.now()}`
  const post = async payload => {
    const response = await fetch(`${base}/api/mooncode/schedules`, { method: 'POST', headers: { 'content-type': 'application/json', origin: base }, body: JSON.stringify(payload) })
    const result = await response.json(); assert.equal(response.ok, true, JSON.stringify(result)); return result
  }
  try {
    const created = await post({ action: 'create', id, book_id: 'book-journey-check', title: 'Weekly report check', prompt: 'Refresh inbox/report.md using inbox/revenue.csv', model: 'moongate/deepseek-v4.1-flash', interval_seconds: 604800, next_due_at: Math.floor(Date.now() / 1000) + 86400, repeat: false, recurrence: 'weekly', timezone: 'Asia/Shanghai' })
    assert.equal(created.schedules.find(schedule => schedule.id === id).book_id, 'book-journey-check')
    const loaded = await (await fetch(`${base}/api/mooncode/schedules`)).json()
    assert.equal(loaded.schedules.find(schedule => schedule.id === id).title, 'Weekly report check')
    const paused = await post({ action: 'pause', id }); assert.equal(paused.schedules.find(schedule => schedule.id === id).enabled, false)
    const resumed = await post({ action: 'resume', id }); assert.equal(resumed.schedules.find(schedule => schedule.id === id).enabled, true)
    const queued = await post({ action: 'run-now', id }); assert.ok(Number(queued.schedules.find(schedule => schedule.id === id).next_due_at) <= Date.now() / 1000)
  } finally { await post({ action: 'delete', id }) }
})
