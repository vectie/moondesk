import test from 'node:test'
import assert from 'node:assert/strict'
import { workPanelItems, taskDraft, codingTaskPresets, mergeTaskThreads, taskPosition, taskArtifacts, taskResultPackage } from './work-journey-runtime.js'
import { taskSchedulePayload, linkedScheduleResults } from './task-schedule-runtime.js'

test('task start and recent conversations have focused destinations', () => {
  assert.deepEqual(workPanelItems('tasks'), [['tasks', 'Start a task']])
  assert.deepEqual(workPanelItems('threads'), [['threads', 'Recent tasks']])
  assert.deepEqual(workPanelItems('results').map(([id]) => id), ['results', 'artifacts', 'schedules'])
  assert.equal(workPanelItems('review').some(([id]) => id === 'tasks'), false)
})

test('server conversation refresh retains local draft, sources and open output', () => {
  const position = taskPosition({ work_title: 'Weekly report', request_prompt: 'Revise conclusion', selected_document: 'outputs/report.md', task_files: ['sources/revenue.csv'], task_context: [{ kind: 'quote', value: 'Sales' }], current_directory: 'outputs' })
  const merged = mergeTaskThreads([{ id: 'report', updated_at: 3, chat: [{ role: 'assistant', content: 'New answer' }] }], [{ id: 'report', position, updated_at: 2, chat: [] }, { id: 'draft-a', draft: true, updated_at: 4 }])
  assert.equal(merged[0].id, 'draft-a')
  assert.equal(merged[1].chat[0].content, 'New answer')
  assert.deepEqual(merged[1].position, position)
})

test('output export includes its own conversation and sources, excluding another active task', () => {
  const thread = { id: 'report', position: { files: ['sources/report.csv'] }, chat: [{ role: 'artifact_ref', content: JSON.stringify({ path: 'outputs/report.md', label: 'Report' }) }, { role: 'artifact_ref', content: '{bad' }] }
  const artifacts = taskArtifacts(thread)
  assert.deepEqual(artifacts, [{ path: 'outputs/report.md', title: 'Report' }])
  const output = taskResultPackage({ workspace: 'Research', selected_document: 'other.md', chat: [{ role: 'user', content: 'Other task' }] }, { title: 'Report', artifacts }, thread)
  assert.equal(output.selected_document, 'outputs/report.md')
  assert.deepEqual(output.chat, thread.chat)
  assert.equal(output.sources[0].path, 'sources/report.csv')
})

test('a scheduled report carries the original book, sources and outputs and returns to its conversation', () => {
  const origin = { workspaceId: 'book-a', thread: { id: 'chat-a', position: { files: ['sources/report.csv'] } }, bundle: { title: 'Report', artifacts: [{ path: 'outputs/report.md' }] } }
  const payload = taskSchedulePayload({ id: 'schedule-a', title: 'Weekly report', prompt: 'Update report', model: 'provider/model', minutes: 10080, start: '2026-10-20T09:00', timezone: 'Asia/Shanghai', repeat: 'weekly' }, origin, Date.parse('2026-10-14T00:00Z'))
  assert.equal(payload.action, 'create')
  assert.equal(payload.id, 'schedule-a')
  assert.equal(payload.book_id, 'book-a')
  assert.match(payload.prompt, /sources\/report.csv/)
  assert.match(payload.prompt, /outputs\/report.md/)
  const binding = { 'schedule-a': { workspaceId: 'book-a', conversationId: 'chat-a', title: 'Report', outputPaths: ['outputs/report.md'] } }
  const schedules = [{ id: 'schedule-a', book_id: 'book-a', session_id: 'run-chat', last_command_id: 'run-a', last_finished_at: 1793350800, last_status: 'done' }]
  const results = linkedScheduleResults(schedules, binding, 'book-a', 'chat-a')
  assert.equal(results[0].conversation_id, 'chat-a')
  assert.equal(results[0].path, 'outputs/report.md')
  assert.equal(linkedScheduleResults(schedules, binding, 'book-b').length, 0)
  assert.equal(linkedScheduleResults(schedules, binding, 'book-a', 'chat-b').length, 0)
})

test('a coding preset stages a named editable task', () => {
  const preset = codingTaskPresets.find(item => item.id === 'fix-bug')
  const draft = taskDraft(preset.prompt + 'The menu is clipped', 'code', preset.title)
  assert.equal(draft.kind, 'code')
  assert.equal(draft.title, 'Fix a bug')
  assert.match(draft.prompt, /The menu is clipped$/)
  assert.deepEqual(taskDraft('  Weekly report\nUse my sources ', 'document'), { prompt: 'Weekly report\nUse my sources', kind: 'document', title: 'Weekly report' })
})
