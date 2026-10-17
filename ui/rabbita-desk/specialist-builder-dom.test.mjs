import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { mountSpecialistBuilder, specialistStorageKeyFor } from './specialist-builder.js'

// Minimal DOM adapters invoke the real installed controls. They qualify event
// flow and recovery only, not browser layout or native/provider integration.
function browserAdapter() {
  const doc = { activeElement: null }
  class Element {
    constructor(tag) { this.tagName = tag; this.textContent = ''; this.className = ''; this.children = []; this.attrs = {}; this.dataset = {}; this.listeners = {}; this.value = ''; this.name = ''; this.disabled = false; this.checked = false; this.isConnected = true }
    setAttribute(name, value) { this.attrs[name] = value }
    append(...items) { for (const item of items) { item.parentElement = this; this.children.push(item) } }
    replaceChildren(...items) { this.children.forEach(item => { item.parentElement = null; item.isConnected = false }); this.children = []; this.append(...items) }
    remove() { this.parentElement.children = this.parentElement.children.filter(item => item !== this); this.isConnected = false }
    addEventListener(type, fn) { (this.listeners[type] ||= []).push(fn) }
    fire(type, extra = {}) { const event = { preventDefault() {}, ...extra }; for (const fn of this.listeners[type] || []) fn(event) }
    click() { if (!this.disabled) this.fire('click') }
    focus() { doc.activeElement = this }
    contains(node) { return node === this || this.children.some(child => child.contains(node)) }
    matches(selector) { if (selector.startsWith('[name=')) return this.name === selector.slice(7, -2); return this.tagName === selector }
    querySelectorAll(selector) { return this.children.flatMap(child => [...(selector.split(', ').some(part => child.matches(part)) ? [child] : []), ...child.querySelectorAll(selector)]) }
    querySelector(selector) { return this.querySelectorAll(selector)[0] || null }
  }
  const app = new Element('main'); app.inert = false
  Object.assign(doc, { body: new Element('body'), createElement: tag => new Element(tag), getElementById: id => id === 'app' ? app : null })
  doc.body.append(app)
  return { doc, app, Element }
}
const agent = { contract_id: 'moonsuite.agent-passport.v1', source_kind: 'moonbook', workspace_id: 'book-a', book_id: 'source-book', name: 'Source Book', version: '1.0.0', status: 'ready', capabilities: ['Evidence-backed answers'] }
const settle = async () => { for (let i = 0; i < 10; i++) await Promise.resolve() }
const visibleText = node => [node.textContent, ...node.children.map(visibleText)].join('\n')

async function rowEditFixture(options = {}, source = 'Subject,Reader\n,Founder\nOther,Reader\nextra,columns,must-stay') {
  const { doc, app } = browserAdapter(), dispatches = []
  const creator = { contract: 'moondesk.specialist-preset.v1', id: 'row-editor', revision: 3, name: 'Row editor', purpose: 'Review source material', example: 'Review an example',
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version }, capabilities: [], knowledge_paths: ['wiki/reference.md'],
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}} for {{audience}}' } }
  let raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [creator] })
  let serial = 0
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'row-edit-ui', storage: { getItem: () => raw, setItem: (_, value) => { raw = value } }, id: () => 'row-ui-' + ++serial,
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }), dispatch: (...args) => dispatches.push(args), ...options })
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const field = name => { const node = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(node, name); return node }
  const fill = (name, value) => { const node = field(name); node.value = value; node.fire('input'); return node }
  await mounted.controller.open(); button('Row editor · revision 3').click()
  const file = field('task-csv-file'); file.files = [{ name: 'tasks.csv', size: source.length, arrayBuffer: async () => new TextEncoder().encode(source).buffer }]; file.fire('change'); await settle()
  for (const [key, column] of [['topic', '0'], ['audience', '1']]) { const node = field('csv-map-' + key); node.value = column; node.fire('change') }
  button('Inspect CSV tasks').click()
  return { mounted, doc, app, dispatches, button, field, fill, get saved() { return JSON.parse(raw).records } }
}

test('mounted task exploration searches, orders, edits and checkpoints exact source rows before unsent preparation', async () => {
  const downloads = [], source = readFileSync(new URL('../../docs/samples/creator-exploration/tasks.csv', import.meta.url), 'utf8')
  const h = await rowEditFixture({ download: packet => downloads.push(packet) }, source), { mounted, button, field, fill, dispatches } = h
  const sourceRows = structuredClone(mounted.controller.state.csv.rows), saved = structuredClone(h.saved)
  const selectedButtons = () => mounted.panel.querySelectorAll('button').filter(node => /^Select CSV row/.test(node.textContent)).map(node => node.textContent)
  fill('task-exploration-query', 'FOUNDER'); field('task-exploration-field').value = 'audience'; field('task-exploration-sort').value = 'topic'
  button('Apply task exploration').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 4', 'Select CSV row 5', 'Select CSV row 2'])
  assert.match(visibleText(mounted.panel), /Showing 3 of 5 tasks · 4 ready · 1 need correction/)
  assert.equal(button('Select CSV row 4').disabled, true)
  button('Select CSV row 5').click(); assert.equal(mounted.controller.state.csv.selected, 3)
  assert.match(visibleText(mounted.panel), /Exact brief for CSV row 5/)
  button('Edit task inputs for CSV row 5').click(); fill('csv-row-input-topic', 'Adapted alpha')
  assert.equal(button('Apply task exploration').disabled, true)
  button('Apply row corrections').click()
  assert.equal(mounted.controller.state.csv.corrections[3].topic, 'Adapted alpha')
  assert.deepEqual(mounted.controller.state.csv.rows, sourceRows)
  button('Select CSV row 5').click(); assert.match(visibleText(mounted.panel), /Review Adapted alpha for Founder/)
  button('Save task checkpoint to file').click()
  assert.equal(downloads.length, 1)
  const checkpoint = JSON.parse(downloads[0].content)
  assert.equal(checkpoint.csv.source, source); assert.equal(checkpoint.corrections[3].topic, 'Adapted alpha')
  assert.equal(Object.hasOwn(checkpoint, 'exploration'), false)
  assert.equal(Object.hasOwn(checkpoint.csv, 'exploration'), false)
  button('Close').click(); await mounted.controller.open()
  assert.equal(field('task-exploration-query').value, 'FOUNDER')
  assert.deepEqual(selectedButtons(), ['Select CSV row 4', 'Select CSV row 5', 'Select CSV row 2'])
  button('Clear CSV tasks').click()
  const bytes = new TextEncoder().encode(downloads[0].content), input = field('task-checkpoint-file')
  input.files = [{ name: 'exploration.creator-tasks.json', size: bytes.length, arrayBuffer: async () => bytes.buffer }]; input.fire('change'); await settle()
  assert.equal(field('task-exploration-query').value, ''); assert.deepEqual(selectedButtons(), [])
  assert.match(visibleText(mounted.panel), /Inspect CSV tasks to populate this view/)
  button('Inspect CSV tasks').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 2', 'Select CSV row 3', 'Select CSV row 4', 'Select CSV row 5', 'Select CSV row 6'])
  field('task-exploration-status').value = 'corrected'; button('Apply task exploration').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 5']); button('Select CSV row 5').click()
  assert.equal(mounted.controller.selectTaskCsvRow(0), false)
  button('Prepare selected CSV task in chat').click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][0], 'prepare-specialist')
  assert.match(dispatches[0][2], /Representative task:\nReview Adapted alpha for Founder/)
  assert.deepEqual(h.saved, saved); assert.deepEqual(mounted.controller.state.csv.rows, sourceRows)
  mounted.controller.close()
})

test('mounted observation filters follow exact current tasks, keep historical evidence and never narrow exports', async () => {
  const h = await rowEditFixture({}, 'Subject,Reader\nZulu,Founder\nAlpha,Ops'), { mounted, button, field, fill, dispatches } = h
  const selectedButtons = () => mounted.panel.querySelectorAll('button').filter(node => /^Select CSV row/.test(node.textContent)).map(node => node.textContent)
  field('task-exploration-status').value = 'unobserved'; button('Apply task exploration').click()
  button('Select CSV row 2').click(); button('Record an observed response for selected task').click()
  assert.equal(button('Apply task exploration').disabled, true)
  assert.equal(mounted.controller.exploreTaskCsv({ query: '', field: '', sort: '', status: 'all', direction: 'asc' }), false)
  fill('task-result-output', 'Actual operator response'); button('Save operator observation').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 3']); assert.equal(mounted.controller.state.csv.selected, null)
  assert.equal(mounted.panel.querySelectorAll('button').some(node => node.textContent === 'Prepare selected CSV task in chat'), false)
  field('task-exploration-status').value = 'observed'; button('Apply task exploration').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 2'])
  button('Edit task inputs for CSV row 2').click(); fill('csv-row-input-topic', 'Changed Zulu'); button('Apply row corrections').click()
  assert.deepEqual(selectedButtons(), []); assert.match(visibleText(mounted.panel), /No tasks match this exploration/)
  field('task-exploration-status').value = 'historical'; button('Apply task exploration').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 2'])
  assert.match(visibleText(mounted.panel), /0 matching observation\(s\) · 1 historical observation\(s\)/)
  const originalObservation = structuredClone(mounted.controller.state.csv.observations[0])
  fill('task-exploration-query', 'no-matches'); button('Apply task exploration').click()
  const report = JSON.parse(mounted.controller.exportTaskResults('json').content)
  assert.equal(report.observations.length, 1); assert.equal(report.observations[0].row_index, 0)
  assert.equal(report.observations[0].matches_current_task, false); assert.equal(report.observations[0].output, 'Actual operator response')
  assert.deepEqual(mounted.controller.state.csv.observations[0], originalObservation)
  button('Reset task exploration').click(); button('Select CSV row 3').click()
  const fileText = new TextEncoder().encode('Additional context'), file = field('task-text-file')
  file.files = [{ name: 'context.txt', size: fileText.length, arrayBuffer: async () => fileText.buffer }]; file.fire('change'); await settle()
  assert.deepEqual(selectedButtons(), []); assert.match(visibleText(mounted.panel), /Inspect CSV tasks to populate/)
  button('Inspect CSV tasks').click(); field('task-exploration-status').value = 'unobserved'; button('Apply task exploration').click()
  assert.deepEqual(selectedButtons(), ['Select CSV row 2', 'Select CSV row 3'])
  assert.deepEqual(dispatches, []); mounted.controller.close()
})

test('mounted exploration applies Enter, rejects invalid options, clears hidden selection and ignores detached controls', async () => {
  const h = await rowEditFixture({}, 'Subject,Reader\n.*[a],Founder\n海😀,Research'), { mounted, button, field, fill, dispatches } = h
  button('Select CSV row 2').click()
  const detachedSelect = button('Select CSV row 2'), detachedApply = button('Apply task exploration')
  fill('task-exploration-query', '海😀').fire('keydown', { key: 'Enter' })
  assert.equal(mounted.controller.state.csv.selected, null)
  assert.equal(mounted.panel.querySelectorAll('button').some(node => node.textContent === 'Prepare selected CSV task in chat'), false)
  detachedSelect.click(); detachedApply.click()
  assert.equal(field('task-exploration-query').value, '海😀'); assert.equal(mounted.controller.state.csv.selected, null)
  const before = structuredClone(mounted.controller.state.csv.exploration)
  assert.equal(mounted.controller.exploreTaskCsv({ ...before, query: 'x'.repeat(201) }), false)
  assert.deepEqual(mounted.controller.state.csv.exploration, before)
  button('Reset task exploration').click(); assert.equal(field('task-exploration-query').value, '')
  fill('task-exploration-query', '.*[a]'); button('Apply task exploration').click()
  assert.equal(mounted.panel.querySelectorAll('button').filter(node => /^Select CSV row/.test(node.textContent)).length, 1)
  assert.ok(button('Select CSV row 2')); assert.deepEqual(dispatches, [])
  const file = field('task-jsonl-file'), bytes = new TextEncoder().encode('{"Subject":"Fresh","Reader":"Reader"}')
  file.files = [{ name: 'fresh.jsonl', size: bytes.length, arrayBuffer: async () => bytes.buffer }]; file.fire('change'); await settle()
  assert.equal(field('task-exploration-query').value, ''); assert.equal(mounted.controller.state.csv.rows.length, 1)
  mounted.controller.close()
})

test('mounted JSONL intake maps, edits, checkpoints, reopens and prepares an ordinary unsent creator task', async () => {
  const downloads = [], h = await rowEditFixture({ download: packet => downloads.push(packet) })
  const { mounted, button, field, fill, dispatches } = h
  const original = structuredClone(h.saved), input = field('task-jsonl-file')
  const source = '{"Subject":"","Reader":"Founder"}\n{"Reader":"Researcher","Subject":"001.20 海😀"}\n'
  const bytes = new TextEncoder().encode(source)
  input.files = [{ name: 'annotations.jsonl', size: bytes.length, arrayBuffer: async () => bytes.buffer }]; input.fire('change'); await settle()
  assert.match(visibleText(mounted.panel), /JSONL string records converted/)
  assert.equal(mounted.controller.state.csv.name, 'annotations.jsonl.csv')
  assert.deepEqual(dispatches, [])
  for (const [key, column] of [['topic', '0'], ['audience', '1']]) { const node = field('csv-map-' + key); node.value = column; node.fire('change') }
  button('Inspect CSV tasks').click(); button('Edit task inputs for CSV row 2').click()
  fill('csv-row-input-topic', 'Corrected annotation'); button('Apply row corrections').click()
  button('Save task checkpoint to file').click(); assert.equal(downloads.length, 1)
  button('Clear CSV tasks').click()
  const checkpoint = field('task-checkpoint-file'), packet = new TextEncoder().encode(downloads[0].content)
  checkpoint.files = [{ name: downloads[0].filename, size: packet.length, arrayBuffer: async () => packet.buffer }]; checkpoint.fire('change'); await settle()
  button('Inspect CSV tasks').click(); button('Select CSV row 2').click()
  assert.match(visibleText(mounted.panel), /Review Corrected annotation for Founder/)
  button('Prepare selected CSV task in chat').click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][0], 'prepare-specialist')
  assert.match(dispatches[0][2], /Review Corrected annotation for Founder/)
  assert.deepEqual(h.saved, original)
  mounted.controller.close()
})

test('mounted observation → correction → same-task retry keeps exact files, original evidence and ordinary Save/reopen', async () => {
  const downloads = [], h = await rowEditFixture({ download: packet => downloads.push(packet) }, 'Subject,Reader\nPilot expansion,Support lead\nNightly exports,Operations lead'), { mounted, button, field, fill, dispatches } = h
  const original = structuredClone(h.saved[0]), fileText = '\ufeffActual exports run nightly.\r\n001.20 海😀'
  const fileBytes = new TextEncoder().encode(fileText), taskFile = field('task-text-file')
  taskFile.files = [{ name: 'export-evidence.txt', size: fileBytes.length, arrayBuffer: async () => fileBytes.buffer }]; taskFile.fire('change'); await settle()
  button('Inspect CSV tasks').click(); button('Select CSV row 3').click(); button('Record an observed response for selected task').click()
  fill('task-result-output', 'Exports always finish at 02:00.'); fill('task-result-notes', 'The source gives no finish time.'); button('Save operator observation').click()
  const observation = structuredClone(mounted.controller.state.csv.observations[0])
  button('Clear task files').click(); button('Inspect CSV tasks').click(); button('Edit task inputs for CSV row 3').click()
  fill('csv-row-input-topic', 'Later task'); button('Apply row corrections').click()
  const batch = JSON.stringify(mounted.controller.state.csv), staleImprove = button('Improve creator from observation 1')
  staleImprove.click(); staleImprove.click()
  assert.equal(mounted.controller.state.refinement.number, 1)
  assert.match(visibleText(mounted.panel), /Row editor \[row-editor\] · captured revision 3/)
  assert.ok(visibleText(mounted.panel).includes(observation.task)); assert.ok(visibleText(mounted.panel).includes(observation.output))
  assert.ok(visibleText(mounted.panel).includes(fileText)); assert.equal(field('purpose').value, original.purpose)
  button('Download original observations JSON').click()
  assert.equal(downloads.length, 1); assert.equal(JSON.parse(downloads[0].content).observations[0].output, observation.output)
  assert.equal(mounted.controller.state.refinement.number, 1)
  assert.equal(button('New specialist').disabled, true); assert.equal(field('creator-import-file').disabled, true)
  button('Create specialist').click(); assert.match(visibleText(mounted.panel), /Write a concrete correction/)
  const correction = 'Review source material. Cite the supplied evidence; state that completion time is unknown when the source only says nightly.'
  fill('purpose', correction); fill('name', 'Evidence-bound reviewer'); fill('task-template', 'For future work, review {{subject}}')
  button('Create specialist').click()
  assert.equal(mounted.controller.state.created.purpose, correction); assert.deepEqual(h.saved, [original])
  const preview = mounted.controller.state.refinement.preview
  assert.ok(preview.includes('Representative task:\n' + observation.task)); assert.ok(preview.includes(JSON.stringify(fileText)))
  assert.doesNotMatch(preview, /Later task|Exports always finish at 02:00/); assert.deepEqual(dispatches, [])
  button('Prepare same captured task in chat').click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][0], 'prepare-specialist'); assert.equal(dispatches[0][2], preview)
  const firstRequest = JSON.parse(dispatches[0][3])
  mounted.controller.receive('specialist-error', JSON.stringify({ request_id: firstRequest.request_id, message: 'Finish the existing unsent Code draft first.' }))
  assert.match(visibleText(mounted.panel), /unsent Code draft/); assert.equal(mounted.controller.state.created.purpose, correction)
  assert.equal(mounted.controller.state.refinement.preview, preview); assert.equal(JSON.stringify(mounted.controller.state.csv), batch)
  button('Close').click(); await mounted.controller.open()
  assert.equal(mounted.controller.state.created.purpose, correction); assert.ok(visibleText(mounted.panel).includes(observation.output))
  button('Prepare same captured task in chat').click(); await settle(); assert.equal(dispatches.length, 2)
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(dispatches[1][3]).request_id }))
  assert.equal(mounted.panel, null); assert.match(mounted.controller.state.prepared, /Click Send/)
  assert.ok(dispatches.every(call => call[0] === 'prepare-specialist'))
  await mounted.controller.open(); button('Save specialist').click()
  assert.equal(h.saved.length, 2); assert.deepEqual(h.saved.find(record => record.id === original.id), original)
  const refined = structuredClone(h.saved.find(record => record.id !== original.id))
  assert.equal(refined.purpose, correction); assert.equal(refined.variant.source_id, original.id)
  assert.equal(Object.hasOwn(refined, 'refinement'), false); assert.equal(Object.hasOwn(refined, 'taskFiles'), false)
  button('Return to original observations').click()
  assert.deepEqual(mounted.controller.state.csv.observations[0], observation); assert.equal(JSON.stringify(mounted.controller.state.csv), batch)
  const exported = mounted.controller.exportTaskResults('json')
  assert.equal(Object.hasOwn(JSON.parse(exported.content).observations[0], 'task_files'), false)
  button('Evidence-bound reviewer · revision 1').click()
  assert.equal(mounted.controller.state.refinement, null); assert.equal(mounted.controller.state.created.purpose, correction)
  const portable = mounted.controller.exportSaved(refined.id)
  assert.equal(JSON.parse(portable.content).creator.purpose, correction)
  button('Revise').click(); assert.equal(field('purpose').value, correction)
  const { doc: freshDocument } = browserAdapter()
  const reloaded = mountSpecialistBuilder({ document: freshDocument, scope: 'row-edit-ui',
    storage: { getItem: () => JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: h.saved }) },
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await reloaded.controller.open()
  reloaded.panel.querySelectorAll('button').find(node => node.textContent === 'Evidence-bound reviewer · revision 1').click()
  assert.equal(reloaded.controller.state.created.purpose, correction); assert.equal(reloaded.controller.state.refinement, null)
  assert.ok(reloaded.panel.querySelector('[name="task-input-subject"]'))
  assert.ok(reloaded.panel.querySelectorAll('button').find(node => node.textContent === 'Try in chat'))
  if (process.env.MOONDESK_REFINEMENT_SAMPLE === '1') console.log('TASK_REFINEMENT_SAMPLE=' + JSON.stringify({ creator: JSON.parse(portable.content), original_observations: JSON.parse(exported.content), corrected_retry_brief: preview,
    task_file: { name: 'export-evidence.txt', content_utf8: fileText }, qualification: 'Mounted DOM adapter with simulated chat acknowledgements and a fresh controller save/reload; ordinary Send remains a separate native UI action. No provider execution or accepted learning.' }))
})

test('mounted correction survives Revise and Escape, while explicit discard returns the original observation', async () => {
  const { mounted, button, fill, field, dispatches } = await rowEditFixture()
  button('Select CSV row 3').click(); button('Record an observed response for selected task').click()
  fill('task-result-output', '<img src=x onerror=alert(1)> literal response'); button('Save operator observation').click()
  button('Improve creator from observation 1').click(); assert.equal(mounted.panel.querySelector('img'), null)
  fill('purpose', 'Review source material and quote only measured values.'); button('Create specialist').click(); button('Revise').click()
  const correction = field('purpose').value
  mounted.panel.fire('keydown', { key: 'Escape' }); await mounted.controller.open()
  assert.equal(field('purpose').value, correction); assert.equal(mounted.controller.state.csv.observations.length, 1)
  const oldCreate = button('Create revised specialist')
  button('Discard unsaved correction and return to observations').click(); oldCreate.click()
  assert.equal(mounted.controller.state.created.id, 'row-editor'); assert.equal(mounted.controller.state.created.revision, 3)
  assert.equal(mounted.controller.state.csv.observations.length, 1); assert.deepEqual(dispatches, [])
})

test('visible creator output controls record exact selected-task observations and export without sending', async () => {
  const packets = [], { mounted, button, fill, dispatches } = await rowEditFixture({ download: packet => packets.push(packet) })
  button('Select CSV row 3').click()
  button('Record an observed response for selected task').click()
  fill('task-result-output', '<script>literal result</script>\r\n=SUM(1,2)')
  fill('task-result-notes', 'Check source before accepting')
  const oldSave = button('Save operator observation'); oldSave.click(); oldSave.click()
  assert.equal(mounted.controller.state.csv.observations.length, 1)
  assert.equal(mounted.panel.querySelector('script'), null)
  assert.match(visibleText(mounted.panel), /Matches current task inputs/)
  const oldExport = button('Download exact task-results JSON'); oldExport.click(); oldExport.click()
  assert.equal(packets.length, 1)
  const result = JSON.parse(packets[0].content)
  assert.equal(result.observations[0].output, '<script>literal result</script>\r\n=SUM(1,2)')
  assert.equal(result.observations[0].inputs.topic, 'Other')
  assert.match(visibleText(mounted.panel), /download requested/)
  assert.deepEqual(dispatches, [])
})

test('visible input changes preserve historical observations and stale result controls cannot attach to a new task', async () => {
  const { mounted, button, fill } = await rowEditFixture()
  button('Select CSV row 3').click(); button('Record an observed response for selected task').click()
  fill('task-result-output', 'Earlier observed output'); button('Save operator observation').click()
  button('Edit task inputs for CSV row 3').click(); fill('csv-row-input-topic', 'New task'); button('Apply row corrections').click()
  assert.match(visibleText(mounted.panel), /Historical: task inputs or brief changed/)
  assert.equal(mounted.controller.state.csv.observations[0].inputs.topic, 'Other')
  button('Select CSV row 3').click(); button('Record an observed response for selected task').click()
  fill('task-result-output', 'Unsaved response'); const stale = button('Save operator observation')
  assert.equal(button('Download exact task-results JSON').disabled, true)
  button('Cancel unfinished observation').click(); stale.click()
  assert.equal(mounted.controller.state.csv.observations.length, 1)
})

test('visible failed result downloads leave recorded responses available for retry', async () => {
  const { mounted, button, fill } = await rowEditFixture({ download: () => { throw new Error('Download blocked by fixture') } })
  button('Select CSV row 3').click(); button('Record an observed response for selected task').click()
  fill('task-result-output', 'Preserve this response'); button('Save operator observation').click()
  button('Download task-results Markdown').click()
  assert.match(visibleText(mounted.panel), /Download blocked by fixture/)
  assert.equal(mounted.controller.state.csv.observations[0].output, 'Preserve this response')
})

test('visible checkpoint controls save corrected data, restore it and require fresh inspect/select before guarded preparation', async () => {
  const packets = [], h = await rowEditFixture({ download: packet => packets.push(packet) })
  const { mounted, button, field, fill, dispatches } = h
  button('Edit task inputs for CSV row 2').click(); fill('csv-row-input-topic', '<script>literal checkpoint</script>')
  assert.equal(button('Save task checkpoint to file').disabled, true)
  button('Apply row corrections').click(); button('Select CSV row 2').click()
  const exact = mounted.controller.state.csv.inspected[0].brief
  const oldExport = button('Save task checkpoint to file'); oldExport.click(); oldExport.click()
  assert.equal(packets.length, 1); assert.match(visibleText(mounted.panel), /download requested/)
  assert.match(visibleText(mounted.panel), /review private information before sharing/)
  button('Clear CSV tasks').click()
  const restore = field('task-checkpoint-file')
  restore.files = [{ name: packets[0].filename, size: new TextEncoder().encode(packets[0].content).byteLength, arrayBuffer: async () => new TextEncoder().encode(packets[0].content).buffer }]
  restore.fire('change'); await settle()
  assert.match(visibleText(mounted.panel), /Restored 3 task rows with 1 corrected row/)
  assert.equal(mounted.controller.state.csv.selected, null); assert.equal(mounted.controller.state.csv.inspected.length, 0)
  assert.equal(mounted.panel.querySelectorAll('button').some(item => item.textContent === 'Prepare selected CSV task in chat'), false)
  button('Inspect CSV tasks').click(); assert.equal(button('Select CSV row 4').disabled, true)
  assert.equal(mounted.panel.querySelector('script'), null)
  button('Select CSV row 2').click(); assert.equal(mounted.controller.state.csv.inspected[0].brief, exact)
  button('Prepare selected CSV task in chat').click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][2], exact)
})

test('detached checkpoint controls cannot restore into a revised creator and invalid restore preserves pending row edits', async () => {
  const h = await rowEditFixture(), { mounted, button, field, fill, dispatches } = h
  button('Edit task inputs for CSV row 2').click(); fill('csv-row-input-topic', 'Pending correction')
  const restore = field('task-checkpoint-file'); restore.files = [{ size: 4, arrayBuffer: async () => new TextEncoder().encode('bad!').buffer }]
  restore.fire('change'); await settle()
  assert.match(visibleText(mounted.panel), /not valid JSON/)
  assert.equal(field('csv-row-input-topic').value, 'Pending correction')
  button('Cancel row edit').click(); const staleRestore = field('task-checkpoint-file')
  let reads = 0; staleRestore.files = [{ size: 4, arrayBuffer: async () => { reads++; return new TextEncoder().encode('bad!').buffer } }]
  button('Revise').click(); staleRestore.fire('change'); await settle()
  assert.equal(reads, 0); assert.equal(mounted.controller.state.csv, null); assert.deepEqual(dispatches, [])
})

test('visible row repair applies reviewed inputs, refreshes the exact brief, prepares once and restores original errors on reset', async () => {
  const h = await rowEditFixture(), { mounted, dispatches, button, field, fill } = h
  assert.equal(button('Select CSV row 2').disabled, true)
  assert.equal(button('Edit task inputs for CSV row 4').disabled, true)
  button('Edit task inputs for CSV row 2').click()
  assert.match(visibleText(mounted.panel), /imported from column 1 \(Subject\)/)
  button('Apply row corrections').click(); assert.match(visibleText(mounted.panel), /Enter topic/)
  fill('csv-row-input-topic', '<img src=x> $& {{audience}}')
  assert.equal(field('csv-row-input-topic').maxLength, 4000)
  const oldApply = button('Apply row corrections'); oldApply.click(); oldApply.click()
  assert.equal(mounted.controller.state.csv.editor, null)
  assert.match(visibleText(mounted.panel), /Corrected task ready to select/)
  assert.equal(field('csv-map-topic').disabled, true)
  assert.equal(mounted.panel.querySelector('img'), null)
  button('Select CSV row 2').click()
  const exact = mounted.panel.querySelectorAll('pre').find(node => node.className === 'specialist-csv-preview').textContent
  assert.match(exact, /Review <img src=x> \$& \{\{audience\}\} for Founder/)
  const oldPrepare = button('Prepare selected CSV task in chat')
  button('Edit task inputs for CSV row 2').click(); oldPrepare.click(); await settle()
  assert.equal(dispatches.length, 0)
  assert.equal(button('Select CSV row 3').disabled, true)
  fill('csv-row-input-topic', 'Unapplied'); button('Cancel row edit').click()
  assert.equal(mounted.controller.state.csv.inspected[0].brief, exact)
  button('Select CSV row 2').click(); const prepare = button('Prepare selected CSV task in chat'); prepare.click(); prepare.click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][2], exact)
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: JSON.parse(dispatches[0][3]).request_id }))
  await mounted.controller.open(); button('Reset CSV row 2 corrections').click()
  assert.equal(mounted.controller.state.csv.selected, null); assert.equal(mounted.controller.state.csv.inspected.length, 0)
  button('Inspect CSV tasks').click(); assert.equal(button('Select CSV row 2').disabled, true)
  assert.equal(mounted.controller.state.csv.rows[0].cells[0], '')
  assert.match(visibleText(mounted.panel), /CSV row 2 · Needs correction/)
})

test('row edit Escape recovery and detached controls cannot alter a newer row, reset or creator', async () => {
  const { mounted, app, button, field, fill, dispatches } = await rowEditFixture()
  button('Edit task inputs for CSV row 2').click(); const oldInput = fill('csv-row-input-topic', 'Retained pending')
  const oldApply = button('Apply row corrections'), oldCancel = button('Cancel row edit')
  mounted.panel.fire('keydown', { key: 'Escape' }); assert.equal(app.inert, false)
  oldApply.click(); oldInput.value = 'Late mutation'; oldInput.fire('input')
  await mounted.controller.open(); assert.equal(field('csv-row-input-topic').value, 'Retained pending')
  button('Apply row corrections').click(); button('Edit task inputs for CSV row 3').click()
  oldCancel.click(); oldApply.click(); oldInput.fire('input')
  assert.equal(mounted.controller.state.csv.editor.index, 1); assert.equal(field('csv-row-input-topic').value, 'Other')
  button('Cancel row edit').click(); const reset = button('Reset all row corrections'); reset.click()
  const map = field('csv-map-topic'); assert.equal(map.disabled, false); map.value = '1'; map.fire('change')
  reset.click(); assert.equal(mounted.controller.state.csv.mapping.topic, 1)
  button('Inspect CSV tasks').click(); button('Edit task inputs for CSV row 2').click()
  const obsolete = field('csv-row-input-topic'), apply = button('Apply row corrections')
  button('New specialist').click(); obsolete.value = 'Detached'; obsolete.fire('input'); apply.click()
  assert.equal(mounted.controller.state.csv, null); assert.equal(mounted.controller.state.draft.name, '')
  assert.equal(dispatches.length, 0)
})

test('visible builder controls complete define, choose, create, try, revise, save and reopen flow', async () => {
  const { doc, app, Element } = browserAdapter(), values = new Map(), dispatches = []
  const trigger = new Element('button'); app.append(trigger); trigger.focus()
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  let serial = 0
  const request = async url => ({ ok: true, json: async () => url.startsWith('/api/search?') ? {
    contract: 'pages-search.v1', ok: true, workspace_id: 'book-a', hits: [
      { workspace_id: 'book-a', path: 'wiki/decision-method.md', title: 'Decision method' },
      { workspace_id: 'book-a', path: 'raw/quarter.md', title: 'Quarter source' },
    ],
  } : { contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] } })
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'library-a', storage, fetch: request, id: () => `preset-${++serial}`, dispatch: (...args) => dispatches.push(args) })
  const click = label => { const item = mounted.panel.querySelectorAll('button').find(node => node.textContent === label); assert.ok(item, `visible control: ${label}`); item.click() }
  const fill = (name, value) => { const item = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(item, `visible field: ${name}`); item.value = value; item.fire('input') }
  const choose = label => { const node = mounted.panel.querySelectorAll('label').find(node => visibleText(node).includes(label)); assert.ok(node, `visible choice: ${label}`); const input = node.querySelector('input'); input.checked = true; input.fire('change') }
  await mounted.controller.open()
  assert.equal(app.inert, true); assert.equal(mounted.panel.attrs['aria-modal'], 'true')
  fill('name', 'Research specialist'); fill('purpose', 'Compare claims and preserve citations.'); fill('example', 'Summarize this quarter with uncertainties.')
  const book = mounted.panel.querySelector('select'); book.value = 'book-a'; book.fire('change')
  choose('Evidence-backed answers'); fill('knowledge-query', 'quarter'); mounted.panel.querySelector('form').fire('submit'); await settle()
  choose('raw/quarter.md'); click('Create specialist')
  assert.match(visibleText(mounted.panel), /Research specialist · revision 1/)
  assert.match(visibleText(mounted.panel), /@raw\/quarter.md/)
  assert.equal(dispatches.length, 0); click('Try in chat'); click('Preparing…'); await settle()
  assert.equal(dispatches.length, 1); const binding = JSON.parse(dispatches[0][3])
  assert.deepEqual(binding.knowledge_paths, ['raw/quarter.md']); assert.equal(binding.library_scope, 'library-a')
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
  assert.equal(mounted.panel, null); assert.equal(app.inert, false); assert.equal(doc.activeElement, trigger)
  await mounted.controller.open(); click('Revise'); fill('purpose', 'Flag contradictions and cite source evidence.'); click('Create revised specialist')
  click('Save specialist'); assert.match(visibleText(mounted.panel), /Saved in this browser/)
  const saved = JSON.parse(storage.getItem(specialistStorageKeyFor('library-a'))).records[0]
  assert.equal(saved.revision, 2); click('Close')
  const restarted = mountSpecialistBuilder({ document: doc, scope: 'library-a', storage, fetch: request })
  await restarted.controller.open()
  const reopen = restarted.panel.querySelectorAll('button').find(node => node.textContent === 'Research specialist · revision 2'); assert.ok(reopen); reopen.click()
  assert.match(visibleText(restarted.panel), /Flag contradictions/)
  assert.match(visibleText(restarted.panel), /Preparation alone is not a completed trial/)
  assert.ok(restarted.panel.querySelectorAll('button').some(node => node.textContent === 'Try in chat'))
  restarted.panel.fire('keydown', { key: 'Escape' }); assert.equal(restarted.panel, null); assert.equal(app.inert, false)
})

test('builder escapes user text by textContent, traps keyboard focus, and retains fields after close', async () => {
  const { doc, app } = browserAdapter()
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'library-a', storage: { getItem: () => null }, fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open()
  const input = mounted.panel.querySelector('[name="purpose"]'); input.value = '<img src=x onerror=alert(1)>'; input.fire('input')
  const buttons = mounted.panel.querySelectorAll('button'), last = buttons.at(-1); last.focus()
  let prevented = false; mounted.panel.fire('keydown', { key: 'Tab', preventDefault() { prevented = true } })
  assert.equal(prevented, true); assert.equal(doc.activeElement, buttons[0])
  mounted.panel.fire('keydown', { key: 'Escape' }); await mounted.controller.open()
  assert.equal(mounted.panel.querySelector('[name="purpose"]').value, '<img src=x onerror=alert(1)>')
  assert.equal(app.inert, true); mounted.controller.close()
})

test('reachable Pack Home → lazy builder → exact Book preparation → existing Send contract is wired', () => {
  const source = name => readFileSync(new URL(name, import.meta.url), 'utf8')
  assert.match(source('main/pack_home_views.mbt'), /workspace_feature_msg\("open-specialist"\)/)
  assert.match(source('main/workspace_features_actions.mbt'), /"prepare-specialist" =>\s*prepare_specialist_example/)
  assert.match(source('workspace-features-runtime.js'), /import\('\.\/specialist-builder.js'\)/)
  assert.match(source('specialist-builder.js'), /from '\.\/specialist-composition.js'/)
  assert.match(source('specialist-composition.js'), /export function compositionInstructions/)
  assert.match(source('vite.config.js'), /plugins: \[rabbita\(\)/)
  assert.match(source('main/specialist_builder.mbt'), /wiki_chat_file_paths: binding.knowledge_paths/)
  assert.doesNotMatch(source('main/specialist_builder.mbt'), /SubmitWikiChat/)
  assert.match(source('main/commands_wiki_chat.mbt'), /"file_paths": Json::array\(paths.map/)
  assert.match(source('bootstrap.js'), /specialist-builder.css/)
})

test('visible composition controls select saved revisions, reorder handoffs, create, save, reload and prepare the actual composed brief', async () => {
  const { doc, app } = browserAdapter(), values = new Map(), dispatches = []
  const records = ['Researcher', 'Critic', 'Writer'].map((name, index) => ({
    contract: 'moondesk.specialist-preset.v1', id: name.toLowerCase(), revision: index + 1,
    name, purpose: `${name} purpose`, example: `${name} source example`, book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version },
    capabilities: ['Evidence-backed answers'], knowledge_paths: [`wiki/${name}.md`, 'raw/shared.md'],
  }))
  records.push({ ...records[0], id: 'other-book', name: 'Other Book specialist', book: { ...records[0].book, workspace_id: 'elsewhere' } })
  values.set(specialistStorageKeyFor('library-a'), JSON.stringify({ contract: 'moondesk.specialist-library.v1', records }))
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  const request = async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) })
  const options = { document: doc, scope: 'library-a', storage, fetch: request, id: () => 'composed', dispatch: (...args) => dispatches.push(args) }
  let mounted = mountSpecialistBuilder(options)
  const click = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, `visible button ${label}`); node.click() }
  const fill = (name, value) => { const node = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(node, `visible input ${name}`); node.value = value; node.fire('input') }
  const add = value => { const node = mounted.panel.querySelector('[name="stage-source"]'); node.value = value; click('Add stage') }
  await mounted.controller.open(); click('Compose specialists')
  fill('name', 'Reviewed report creator'); fill('purpose', 'Create a clear sourced report'); fill('example', 'Explain the October results')
  add('researcher'); fill('handoff-0', 'Pass cited findings to the critic')
  const unavailable = mounted.panel.querySelector('[name="stage-source"]').children.find(node => node.value === 'other-book')
  assert.equal(unavailable.disabled, true)
  add('critic'); fill('handoff-1', 'Flag contradictions for the writer'); add('writer'); fill('handoff-2', 'Produce the final reviewed report')
  assert.equal(mounted.panel.querySelector('[name="handoff-0"]').value, 'Pass cited findings to the critic')
  click('Move stage 3 up'); assert.equal(mounted.panel.querySelector('[name="handoff-1"]').value, 'Produce the final reviewed report')
  click('Move stage 2 down'); click('Remove stage 3'); add('writer'); fill('handoff-2', 'Produce the final reviewed report')
  click('Close'); assert.equal(app.inert, false); await mounted.controller.open()
  assert.equal(mounted.panel.querySelector('[name="handoff-2"]').value, 'Produce the final reviewed report')
  click('Create specialist'); assert.match(visibleText(mounted.panel), /Researcher r1 → Critic r2 → Writer r3/)
  assert.match(visibleText(mounted.panel), /Stage 3: Writer/); assert.match(visibleText(mounted.panel), /Produce the final reviewed report/)
  click('Save specialist'); assert.match(visibleText(mounted.panel), /Saved in this browser/); click('Close')
  mounted = mountSpecialistBuilder(options); await mounted.controller.open(); click('Reviewed report creator · revision 1')
  assert.match(visibleText(mounted.panel), /Researcher r1 → Critic r2 → Writer r3/)
  click('Try in chat'); await settle(); assert.equal(dispatches.length, 1)
  assert.match(dispatches[0][2], /Stage 1: Researcher/); assert.match(dispatches[0][2], /Stage 2: Critic/); assert.match(dispatches[0][2], /Stage 3: Writer/)
  const binding = JSON.parse(dispatches[0][3]); assert.deepEqual(binding.knowledge_paths, ['wiki/Researcher.md', 'raw/shared.md', 'wiki/Critic.md', 'wiki/Writer.md'])
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id })); assert.equal(mounted.panel, null); assert.equal(app.inert, false)
})

test('empty composition explains its prerequisites and Escape retains the unfinished work', async () => {
  const { doc } = browserAdapter()
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'library-a', storage: { getItem: () => null }, fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open(); mounted.panel.querySelectorAll('button').find(node => node.textContent === 'Compose specialists').click()
  assert.match(visibleText(mounted.panel), /Create and save two single-stage specialists first/)
  const input = mounted.panel.querySelector('[name="purpose"]'); input.value = '<img src=x onerror=alert(1)>'; input.fire('input')
  mounted.panel.fire('keydown', { key: 'Escape' }); await mounted.controller.open()
  assert.equal(mounted.panel.querySelector('[name="purpose"]').value, '<img src=x onerror=alert(1)>')
  assert.ok(mounted.controller.state.draft.composition); assert.equal(mounted.panel.querySelector('img'), null)
})

test('detached composition controls cannot overwrite a reordered handoff or a newer draft', async () => {
  const { doc } = browserAdapter()
  const records = ['One', 'Two'].map(name => ({ contract: 'moondesk.specialist-preset.v1', id: name, revision: 1, name, purpose: name, example: name,
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }, capabilities: [], knowledge_paths: [] }))
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records })
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'library-a', storage: { getItem: () => raw }, fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open(); mounted.controller.newComposition(); mounted.controller.addStage('One'); mounted.controller.addStage('Two')
  mounted.controller.editHandoff(0, 'One handoff'); mounted.controller.editHandoff(1, 'Two handoff')
  const detachedInput = mounted.panel.querySelector('[name="handoff-0"]')
  const detachedButton = mounted.panel.querySelectorAll('button').find(node => node.textContent === 'Remove stage 1')
  mounted.controller.moveStage(1, -1); detachedInput.value = 'Wrong handoff'; detachedInput.fire('input'); detachedButton.click()
  assert.deepEqual(mounted.controller.state.draft.composition.stages.map(stage => stage.handoff), ['Two handoff', 'One handoff'])
  const oldName = mounted.panel.querySelector('[name="name"]')
  mounted.controller.newDraft(); oldName.value = 'Old composition'; oldName.fire('input')
  assert.equal(mounted.controller.state.draft.name, ''); assert.equal(mounted.controller.state.draft.composition, undefined)
})


test('visible reusable task form creates, fills, invalidates preview, prepares, recovers and reloads without saving input values', async () => {
  const { doc } = browserAdapter(), values = new Map(), dispatches = []
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  const options = { document: doc, scope: 'task-form-library', storage,
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }),
    id: () => 'task-form-creator', dispatch: (...args) => dispatches.push(args) }
  let mounted = mountSpecialistBuilder(options)
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const fill = (name, value) => { const input = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(input, name); input.value = value; input.fire('input'); return input }
  await mounted.controller.open()
  fill('name', 'Reusable analyst'); fill('purpose', 'Explain evidence'); fill('example', 'Explain Q3')
  const book = mounted.panel.querySelector('[name="book"]'); book.value = agent.workspace_id; book.fire('change')
  fill('task-template', 'Explain {{topic}} for {{audience}}')
  button('Create specialist').click(); button('Save specialist').click()
  const original = values.get(specialistStorageKeyFor('task-form-library'))
  fill('task-input-topic', 'September'); fill('task-input-audience', 'founders'); button('Preview filled task').click()
  assert.ok(mounted.panel.querySelectorAll('pre').some(node => node.textContent.includes('Explain September for founders')))
  const detached = button('Prepare filled task in chat')
  fill('task-input-topic', 'October')
  assert.equal(mounted.panel.querySelectorAll('pre').some(node => node.textContent.includes('Explain September for founders')), false)
  button('Prepare filled task in chat').click(); await new Promise(resolve => setImmediate(resolve)); assert.equal(dispatches.length, 0)
  button('Preview filled task').click(); detached.click(); assert.equal(dispatches.length, 0)
  button('Close').click(); await mounted.controller.open()
  assert.equal(mounted.panel.querySelector('[name="task-input-topic"]').value, 'October')
  button('Prepare filled task in chat').click(); await new Promise(resolve => setImmediate(resolve))
  assert.equal(dispatches.length, 1); assert.match(dispatches[0][2], /Explain October for founders/)
  const binding = JSON.parse(dispatches[0][3]); mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
  assert.equal(mounted.panel, null); assert.equal(values.get(specialistStorageKeyFor('task-form-library')), original)
  mounted = mountSpecialistBuilder(options); await mounted.controller.open(); button('Reusable analyst · revision 1').click()
  assert.equal(mounted.panel.querySelector('[name="task-input-topic"]').value, '')
  button('Revise').click(); assert.equal(mounted.panel.querySelector('[name="task-template"]').value, 'Explain {{topic}} for {{audience}}')
})

test('visible saved-creator variant copies composition and form, edits independently, tries, saves and reloads with exact lineage', async () => {
  const { doc, app } = browserAdapter(), values = new Map(), dispatches = []
  const stages = ['Researcher', 'Critic'].map((name, i) => ({ contract: 'moondesk.specialist-preset.v1', id: name, revision: i + 2,
    name, purpose: `${name} purpose`, example: `${name} example`, book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name },
    capabilities: ['Evidence-backed answers'], knowledge_paths: ['raw/quarter.md'] }))
  const original = { ...stages[0], id: 'composed-source', name: 'Reviewed creator', revision: 5,
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}}' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map(source => ({ source, handoff: `${source.name} handoff` })) } }
  const key = specialistStorageKeyFor('variant-ui')
  values.set(key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [...stages, original] }))
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  let serial = 0
  const options = { document: doc, scope: 'variant-ui', storage,
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }),
    id: () => 'variant-ui-' + ++serial, dispatch: (...args) => dispatches.push(args) }
  let mounted = mountSpecialistBuilder(options)
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const click = label => button(label).click()
  const fill = (name, value) => { const input = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(input, name); input.value = value; input.fire('input') }
  await mounted.controller.open(); click('Reviewed creator · revision 5')
  fill('task-input-topic', 'Transient source job'); click('Preview filled task')
  click('Create variant of Reviewed creator')
  assert.equal(mounted.controller.state.created, null); assert.deepEqual(mounted.controller.state.taskValues, {})
  assert.match(visibleText(mounted.panel), /Variant of Reviewed creator · saved revision 5/)
  assert.match(visibleText(mounted.panel), /Knowledge files remain live/)
  assert.equal(mounted.panel.querySelector('[name="task-template"]').value, 'Review {{topic}}')
  assert.equal(mounted.panel.querySelector('[name="handoff-0"]').value, 'Researcher handoff')
  fill('name', 'Investor report creator'); fill('purpose', 'Prepare an investor report'); fill('handoff-0', 'Pass investor evidence')
  click('Move stage 2 up'); click('Close'); assert.equal(app.inert, false); await mounted.controller.open()
  assert.equal(mounted.panel.querySelector('[name="handoff-1"]').value, 'Pass investor evidence')
  click('Create specialist'); assert.match(visibleText(mounted.panel), /Investor report creator · revision 1/)
  assert.match(visibleText(mounted.panel), /Critic r3 → Researcher r2/)
  assert.equal(dispatches.length, 0); assert.equal(JSON.parse(values.get(key)).records.length, 3)
  click('Try in chat'); assert.equal(button('Create variant of Reviewed creator').disabled, true); await settle()
  assert.equal(dispatches.length, 1); assert.match(dispatches[0][2], /Variant source: Reviewed creator \[composed-source\] · saved revision 5/)
  const binding = JSON.parse(dispatches[0][3]); assert.deepEqual(binding.knowledge_paths, ['raw/quarter.md'])
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id })); assert.equal(mounted.panel, null)
  await mounted.controller.open(); click('Save specialist')
  const savedVariant = mounted.controller.state.created, records = JSON.parse(values.get(key)).records
  assert.notEqual(savedVariant.id, original.id); assert.deepEqual(records.find(row => row.id === original.id), original)
  click('Reviewed creator · revision 5'); click('Revise'); fill('purpose', 'Source revision six'); click('Create revised specialist'); click('Save specialist')
  click('Investor report creator · revision 1'); assert.match(visibleText(mounted.panel), /saved source is now revision 6/)
  assert.equal(mounted.controller.state.created.variant.source_revision, 5)
  click('Close'); mounted = mountSpecialistBuilder(options); await mounted.controller.open(); click('Investor report creator · revision 1')
  assert.equal(mounted.panel.querySelector('[name="task-input-topic"]').value, '')
  fill('task-input-topic', 'Q4'); click('Preview filled task'); click('Prepare filled task in chat'); await settle()
  assert.equal(dispatches.length, 2); assert.match(dispatches[1][2], /Review Q4/)
  assert.equal(JSON.parse(values.get(key)).records.length, 4)
})

test('detached variant controls cannot fork over a newer draft and failed naming retains copied inputs', async () => {
  const { doc } = browserAdapter()
  const record = { contract: 'moondesk.specialist-preset.v1', id: 'source', revision: 1, name: '<Source>', purpose: 'Source purpose', example: 'Source example',
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }, capabilities: [], knowledge_paths: [] }
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [record] })
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'variant-ui', storage: { getItem: () => raw }, id: () => 'new-variant',
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open()
  const get = label => mounted.panel.querySelectorAll('button').find(node => node.textContent === label)
  const detached = get('Create variant of <Source>'); get('New specialist').click(); detached.click()
  assert.equal(mounted.controller.state.draft.name, '')
  get('Create variant of <Source>').click()
  const name = mounted.panel.querySelector('[name="name"]'); name.value = '<Source>'; name.fire('input'); get('Create specialist').click()
  assert.match(visibleText(mounted.panel), /different name/); assert.equal(mounted.controller.state.editing, true)
  assert.equal(mounted.panel.querySelector('[name="purpose"]').value, 'Source purpose')
  assert.equal(mounted.panel.querySelector('script'), null)
  mounted.panel.fire('keydown', { key: 'Escape' }); await mounted.controller.open()
  assert.equal(mounted.controller.state.draft.variant.source_id, 'source')
})

test('old source Book, reference, capability and search controls cannot mutate the newly forked variant', async () => {
  const { doc } = browserAdapter(), calls = []
  const record = { contract: 'moondesk.specialist-preset.v1', id: 'source', revision: 1, name: 'Source', purpose: 'Source purpose', example: 'Source example',
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name },
    capabilities: ['Evidence-backed answers'], knowledge_paths: ['raw/quarter.md'] }
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [record] })
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'variant-ui', storage: { getItem: () => raw },
    fetch: async url => { calls.push(url); return { ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) } } })
  await mounted.controller.open(); mounted.controller.reopen('source'); mounted.controller.revise()
  const oldBook = mounted.panel.querySelector('[name="book"]'), oldForm = mounted.panel.querySelector('form')
  const oldChoices = mounted.panel.querySelectorAll('input').filter(node => node.type === 'checkbox')
  const oldQuery = mounted.panel.querySelector('[name="knowledge-query"]'); oldQuery.value = 'old query'
  mounted.panel.querySelectorAll('button').find(node => node.textContent === 'Create variant of Source').click()
  const draft = JSON.stringify(mounted.controller.state.draft), status = mounted.controller.state.status
  for (const choice of oldChoices) { choice.checked = false; choice.fire('change') }
  oldBook.value = ''; oldBook.fire('change'); oldForm.fire('submit'); await settle()
  assert.equal(JSON.stringify(mounted.controller.state.draft), draft)
  assert.equal(mounted.controller.state.status, status); assert.equal(calls.length, 1)
})

test('mounted CSV workflow maps local spreadsheet columns, inspects errors, prepares exact composed row, and returns for another', async () => {
  const { doc, app } = browserAdapter(), values = new Map(), dispatches = []
  const stages = ['Researcher', 'Critic'].map((name, index) => ({ contract: 'moondesk.specialist-preset.v1', id: name, revision: index + 2, name,
    purpose: name + ' purpose', example: name + ' example', book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version },
    capabilities: ['Evidence-backed answers'], knowledge_paths: ['raw/quarter.md'] }))
  const creator = { ...stages[0], id: 'csv-creator', name: 'CSV review creator', revision: 5,
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}} for {{audience}}' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map(source => ({ source, handoff: source.name + ' handoff' })) } }
  const key = specialistStorageKeyFor('csv-ui'), raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [creator, ...stages] })
  values.set(key, raw)
  let serial = 0
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'csv-ui', storage: { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) },
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }),
    id: () => `csv-ui-${++serial}`, dispatch: (...args) => dispatches.push(args) })
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const map = (key, column) => { const node = mounted.panel.querySelector(`[name="csv-map-${key}"]`); assert.ok(node, key); node.value = column; node.fire('change') }
  await mounted.controller.open(); button('CSV review creator · revision 5').click()
  const input = mounted.panel.querySelector('[name="task-csv-file"]')
  assert.equal(input.type, 'file'); assert.equal(input.accept, '.csv,text/csv')
  const source = 'Reader,Subject\nFounder,"001.50, quoted"\n,\nAnalyst,<img src=x onerror=alert(1)>'
  input.files = [{ name: '<script>tasks.csv', size: source.length, arrayBuffer: async () => new TextEncoder().encode(source).buffer }]; input.fire('change'); await settle()
  assert.match(visibleText(mounted.panel), /3 task rows/)
  button('Inspect CSV tasks').click(); assert.match(visibleText(mounted.panel), /Map topic/)
  map('topic', '1'); map('audience', '0'); button('Inspect CSV tasks').click()
  assert.match(visibleText(mounted.panel), /2 of 3 rows ready/)
  assert.match(visibleText(mounted.panel), /CSV row 3 · Needs correction/)
  assert.equal(button('Select CSV row 3').disabled, true)
  assert.equal(mounted.panel.querySelector('img'), null); assert.equal(mounted.panel.querySelector('script'), null)
  button('Select CSV row 2').click()
  assert.match(visibleText(mounted.panel), /Exact brief for CSV row 2/)
  const exact = mounted.panel.querySelectorAll('pre').find(node => node.className === 'specialist-csv-preview').textContent
  assert.match(exact, /Review 001.50, quoted for Founder/); assert.match(exact, /Stage 2: Critic/)
  button('Prepare selected CSV task in chat').click(); await settle(); assert.equal(dispatches.length, 1); assert.equal(dispatches[0][2], exact)
  assert.equal(button('Select CSV row 4').disabled, true)
  let binding = JSON.parse(dispatches[0][3])
  mounted.controller.receive('specialist-error', JSON.stringify({ request_id: binding.request_id, message: 'Send or clear your current chat draft first.' }))
  assert.match(visibleText(mounted.panel), /current chat draft/)
  assert.equal(mounted.panel.querySelectorAll('pre').find(node => node.className === 'specialist-csv-preview').textContent, exact)
  button('Prepare selected CSV task in chat').click(); await settle(); binding = JSON.parse(dispatches[1][3])
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: binding.request_id }))
  assert.equal(mounted.panel, null); assert.equal(app.inert, false)
  await mounted.controller.open(); button('Select CSV row 4').click(); button('Prepare selected CSV task in chat').click(); await settle()
  assert.equal(dispatches.length, 3); assert.match(dispatches[2][2], /Review <img src=x onerror=alert\(1\)> for Analyst/)
  assert.equal(values.get(key), raw)
})

test('detached CSV mapping, row, prepare and file controls cannot affect newer render or creator', async () => {
  const { doc } = browserAdapter(), dispatches = []
  const saved = { contract: 'moondesk.specialist-preset.v1', id: 'csv-source', revision: 1, name: 'CSV source', purpose: 'Review', example: 'Review example',
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }, capabilities: [], knowledge_paths: [],
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}}' } }
  const raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [saved] })
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'csv-stale', storage: { getItem: () => raw },
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }), dispatch: (...args) => dispatches.push(args) })
  const button = label => mounted.panel.querySelectorAll('button').find(node => node.textContent === label)
  await mounted.controller.open(); button('CSV source · revision 1').click()
  let file = mounted.panel.querySelector('[name="task-csv-file"]')
  file.files = [{ name: 'tasks.csv', size: 7, arrayBuffer: async () => new TextEncoder().encode('a,b\nX,Y').buffer }]; file.fire('change'); await settle()
  const oldMap = mounted.panel.querySelector('[name="csv-map-topic"]')
  oldMap.value = '0'; oldMap.fire('change'); button('Inspect CSV tasks').click()
  const oldRow = button('Select CSV row 2'); oldRow.click()
  const oldPrepare = button('Prepare selected CSV task in chat')
  const map = mounted.panel.querySelector('[name="csv-map-topic"]'); map.value = '1'; map.fire('change')
  oldMap.value = '0'; oldMap.fire('change'); oldRow.click(); oldPrepare.click(); await settle()
  assert.equal(mounted.controller.state.csv.mapping.topic, 1); assert.equal(mounted.controller.state.csv.selected, null); assert.equal(dispatches.length, 0)
  file = mounted.panel.querySelector('[name="task-csv-file"]')
  button('New specialist').click(); file.fire('change'); await settle()
  assert.equal(mounted.controller.state.csv, null); assert.equal(mounted.controller.state.draft.name, '')
})

test('mounted Escape cancels a late file read and reopening retains the earlier batch', async () => {
  const { doc, app } = browserAdapter()
  const saved = { contract: 'moondesk.specialist-preset.v1', id: 'csv-source', revision: 1, name: 'CSV source', purpose: 'Review', example: 'Review example',
    book: { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }, capabilities: [], knowledge_paths: [],
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}}' } }
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'csv-close', storage: { getItem: () => JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [saved] }) },
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open(); mounted.panel.querySelectorAll('button').find(node => node.textContent === 'CSV source · revision 1').click()
  let input = mounted.panel.querySelector('[name="task-csv-file"]')
  input.files = [{ name: 'first.csv', size: 3, arrayBuffer: async () => new TextEncoder().encode('a\nX').buffer }]; input.fire('change'); await settle()
  let resolve
  input = mounted.panel.querySelector('[name="task-csv-file"]')
  input.files = [{ name: 'later.csv', size: 3, arrayBuffer: () => new Promise(yes => { resolve = text => yes(new TextEncoder().encode(text).buffer) }) }]; input.fire('change')
  mounted.panel.fire('keydown', { key: 'Escape' }); assert.equal(app.inert, false)
  resolve('a\nY'); await settle(); assert.equal(mounted.controller.state.csv.name, 'first.csv')
  await mounted.controller.open(); assert.match(visibleText(mounted.panel), /first.csv/)
  mounted.panel.querySelectorAll('button').find(node => node.textContent === 'Clear CSV tasks').click()
  assert.equal(mounted.controller.state.csv, null)
})

test('visible creator export/import reviews a portable composition, binds installed identity and uses ordinary Create/Try/Save', async () => {
  const { doc, app } = browserAdapter(), values = new Map(), downloads = [], dispatches = []
  const stages = ['Analyst', 'Reviewer'].map(name => ({ contract: 'moondesk.specialist-preset.v1', id: name, revision: 3,
    name, purpose: `${name} evidence`, example: `${name} example`, book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version },
    capabilities: [...agent.capabilities], knowledge_paths: ['raw/quarter.md'] }))
  const creator = { ...stages[0], id: 'portable-original', name: 'Portable reviewer', revision: 7,
    task_form: { contract: 'moondesk.specialist-task-form.v1', template: 'Review {{topic}}' },
    composition: { contract: 'moondesk.specialist-composition.v1', stages: stages.map(source => ({ source, handoff: `${source.name} output` })) } }
  const key = specialistStorageKeyFor('portable-origin'), targetKey = specialistStorageKeyFor('portable-destination')
  values.set(key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [creator] }))
  const storage = { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }
  const localAgent = { ...agent, workspace_id: 'new-installation', name: 'Local installed Book' }
  let serial = 0, mounted = mountSpecialistBuilder({ document: doc, scope: 'portable-origin', storage,
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }), download: packet => downloads.push(packet) })
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const fill = (name, value) => { const node = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(node, name); node.value = value; node.fire('input') }
  await mounted.controller.open(); button('Export Portable reviewer').click()
  assert.equal(downloads.length, 1); assert.equal(JSON.parse(downloads[0].content).creator.revision, 7)
  assert.match(visibleText(mounted.panel), /Local download requested/); button('Close').click()
  const options = { document: doc, scope: 'portable-destination', storage, id: () => 'imported-ui-' + ++serial,
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [localAgent] }) }), dispatch: (...args) => dispatches.push(args) }
  mounted = mountSpecialistBuilder(options); await mounted.controller.open(); fill('purpose', 'Keep unfinished work')
  const chooseFile = () => {
    const input = mounted.panel.querySelector('[name="creator-import-file"]'); assert.equal(input.type, 'file')
    const bytes = new TextEncoder().encode(downloads[0].content)
    input.files = [{ name: downloads[0].filename, size: bytes.length, arrayBuffer: async () => bytes.buffer }]; input.fire('change')
  }
  chooseFile(); await settle(); assert.equal(button('Use imported definition').disabled, true)
  assert.match(visibleText(mounted.panel), /source revision 7/); assert.match(visibleText(mounted.panel), /original workspace is not adopted/)
  assert.equal(values.has(targetKey), false); assert.equal(dispatches.length, 0)
  button('Cancel creator import').click(); assert.equal(mounted.panel.querySelector('[name="purpose"]').value, 'Keep unfinished work')
  chooseFile(); await settle()
  const choice = mounted.panel.querySelector('[name="creator-import-book"]'); choice.value = 'new-installation'; choice.fire('change')
  const detached = button('Use imported definition'); detached.click(); detached.click(); await settle()
  assert.equal(mounted.panel.querySelector('[name="purpose"]').value, creator.purpose)
  assert.equal(mounted.panel.querySelector('[name="task-template"]').value, 'Review {{topic}}')
  assert.equal(mounted.panel.querySelector('[name="handoff-0"]').value, 'Analyst output')
  assert.equal(mounted.controller.state.draft.book.workspace_id, 'new-installation'); assert.equal(mounted.controller.state.created, null)
  assert.equal(values.has(targetKey), false); button('Create specialist').click()
  assert.match(visibleText(mounted.panel), /Portable reviewer · revision 1/); button('Try in chat').click(); await settle()
  assert.equal(dispatches.length, 1); assert.equal(dispatches[0][1], 'new-installation'); assert.match(dispatches[0][2], /Analyst output/)
  const binding = JSON.parse(dispatches[0][3]); assert.equal(binding.library_scope, 'portable-destination')
  mounted.controller.receive('specialist-error', JSON.stringify({ request_id: binding.request_id, message: 'Finish the existing Code draft first.' }))
  assert.match(visibleText(mounted.panel), /existing Code draft/); button('Save specialist').click()
  assert.equal(JSON.parse(values.get(targetKey)).records.length, 1); assert.deepEqual(JSON.parse(values.get(key)).records, [creator])
  button('Close').click(); assert.equal(app.inert, false)
  mounted = mountSpecialistBuilder(options); await mounted.controller.open(); button('Portable reviewer · revision 1').click()
  assert.match(visibleText(mounted.panel), /Imported from Portable reviewer · original revision 7/)
  assert.equal(mounted.panel.querySelector('[name="task-input-topic"]').value, '')
  mounted.panel.fire('keydown', { key: 'Escape' }); assert.equal(mounted.panel, null); assert.equal(app.inert, false)
})

test('visible import Cancel and Escape invalidate pending reads and stale import controls', async () => {
  const { doc, app } = browserAdapter()
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'portable-cancel', storage: { getItem: () => null },
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) })
  await mounted.controller.open()
  const purpose = mounted.panel.querySelector('[name="purpose"]'); purpose.value = 'Keep this'; purpose.fire('input')
  for (const close of [false, true]) {
    let release
    const input = mounted.panel.querySelector('[name="creator-import-file"]')
    input.files = [{ size: 1, arrayBuffer: () => new Promise(resolve => { release = resolve }) }]; input.fire('change')
    const staleCancel = mounted.panel.querySelectorAll('button').find(item => item.textContent === 'Cancel creator import')
    if (close) mounted.panel.fire('keydown', { key: 'Escape' }); else staleCancel.click()
    release(new TextEncoder().encode('{}').buffer); await settle()
    if (close) { assert.equal(mounted.panel, null); assert.equal(app.inert, false); await mounted.controller.open() }
    staleCancel.click()
    assert.equal(mounted.controller.state.portableImport, null); assert.equal(mounted.controller.state.importLoading, false)
    assert.equal(mounted.panel.querySelector('[name="purpose"]').value, 'Keep this')
  }
})

test('visible task-only files reach exact normal-chat brief, cancel late reads, recover after Close and never enter saved creator', async () => {
  const { doc } = browserAdapter(), dispatches = [], values = new Map()
  const record = { contract: 'moondesk.specialist-preset.v1', id: 'writer', revision: 1, name: 'Writer', purpose: 'Explain supplied evidence', example: 'Explain Q4', book: { workspace_id: agent.workspace_id, book_id: agent.book_id, name: agent.name, version: agent.version }, capabilities: [], knowledge_paths: [] }
  const key = specialistStorageKeyFor('file-controls'), raw = JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [record] }); values.set(key, raw)
  const mounted = mountSpecialistBuilder({ document: doc, scope: 'file-controls', storage: { getItem: key => values.get(key) ?? null, setItem: (key, value) => values.set(key, value) }, fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }), id: () => 'request-file', dispatch: (...args) => dispatches.push(args) })
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const pick = input => { const node = mounted.panel.querySelector('[name="task-text-file"]'); node.files = [input]; node.fire('change') }
  const file = content => ({ name: 'quarter.md', size: new TextEncoder().encode(content).length, arrayBuffer: async () => new TextEncoder().encode(content).buffer })
  await mounted.controller.open(); button('Writer · revision 1').click()
  pick(file('<img src=x onerror=alert(1)>\nExact 001.20')); await settle()
  assert.match(visibleText(mounted.panel), /Exact 001.20/); assert.equal(mounted.panel.querySelector('img'), null)
  button('Close').click(); await mounted.controller.open(); assert.match(visibleText(mounted.panel), /quarter.md/)
  const detachedRemove = button('Remove task file quarter.md'); button('Clear task files').click()
  pick(file('New snapshot')); await settle(); detachedRemove.click(); assert.equal(mounted.controller.state.taskFiles.length, 1)
  button('Save specialist').click(); assert.equal(values.get(key), raw)
  let resolve
  pick({ ...file('late'), name: 'late.txt', arrayBuffer: () => new Promise(yes => { resolve = yes }) })
  assert.equal(button('Try in chat').disabled, true)
  button('Clear task files').click(); resolve(new TextEncoder().encode('late').buffer); await settle()
  assert.equal(mounted.controller.state.taskFiles.length, 0)
  pick(file('Approved snapshot')); await settle()
  const preview = mounted.controller.taskBrief(mounted.controller.state.created)
  button('Try in chat').click(); await settle(); assert.equal(dispatches.length, 1); assert.equal(dispatches[0][2], preview)
  assert.match(dispatches[0][2], /Approved snapshot/)
  mounted.controller.receive('specialist-prepared', JSON.stringify({ request_id: 'request-file' }))
  await mounted.controller.open(); assert.equal(mounted.controller.state.taskFiles.length, 0)
  assert.doesNotMatch(visibleText(mounted.panel), /Approved snapshot/)
  mounted.panel.fire('keydown', { key: 'Escape' }); assert.equal(mounted.panel, null)
})

function stageReplacementDomHarness() {
  const { doc, app } = browserAdapter(), values = new Map(), dispatches = []
  const book = { workspace_id: agent.workspace_id, book_id: agent.book_id, version: agent.version, name: agent.name }
  const source = (id, changes = {}) => ({ contract: 'moondesk.specialist-preset.v1', id, revision: 1, name: id,
    purpose: `${id} purpose`, example: `${id} example`, book, capabilities: ['Evidence-backed answers'], knowledge_paths: ['raw/shared.md'], ...changes })
  const researcher = source('Researcher'), critic = source('Critic'), writer = source('Writer')
  const updated = source('Researcher', { name: 'New researcher', revision: 3, purpose: '<img src=x onerror=alert(1)> Research with counterevidence.', knowledge_paths: ['wiki/new-method.md'] })
  const composed = source('Composed', { name: 'Report creator', composition: { contract: 'moondesk.specialist-composition.v1', stages: [
    { source: researcher, handoff: 'Pass cited findings to the critic.' }, { source: critic, handoff: 'Produce the final report.' },
  ] } })
  const key = specialistStorageKeyFor('stage-replacement-ui')
  values.set(key, JSON.stringify({ contract: 'moondesk.specialist-library.v1', records: [composed, updated, critic, writer, source('Incompatible', { book: { ...book, version: 'other' } })] }))
  const storage = { getItem: k => values.get(k) ?? null, setItem: (k, value) => values.set(k, value) }
  const options = { document: doc, scope: 'stage-replacement-ui', storage, id: () => 'unused-new-id', dispatch: (...args) => dispatches.push(args),
    fetch: async () => ({ ok: true, json: async () => ({ contract_id: 'moonsuite.agent-catalog.v1', ok: true, agents: [agent] }) }) }
  let mounted = mountSpecialistBuilder(options)
  const button = label => { const node = mounted.panel.querySelectorAll('button').find(item => item.textContent === label); assert.ok(node, label); return node }
  const click = label => button(label).click()
  const input = (name, value) => { const node = mounted.panel.querySelector(`[name="${name}"]`); assert.ok(node, name); node.value = value; node.fire('input'); return node }
  const choose = (index, id) => { const select = mounted.panel.querySelector(`[name="stage-replacement-${index}"]`); assert.ok(select); select.value = id; click(`Review replacement for stage ${index + 1}`) }
  return { get mounted() { return mounted }, doc, app, values, key, dispatches, button, click, input, choose,
    async reload() { mounted.controller.close(); mounted = mountSpecialistBuilder(options); await mounted.controller.open() } }
}

test('visible stage comparison replaces the selected saved revision without dropping output handoff, then saves and prepares it', async () => {
  const h = stageReplacementDomHarness(); await h.mounted.controller.open(); h.click('Report creator · revision 1'); h.click('Revise')
  const saved = h.values.get(h.key)
  assert.match(visibleText(h.mounted.panel), /This library also has New researcher · revision 3/)
  const select = h.mounted.panel.querySelector('[name="stage-replacement-0"]')
  assert.equal(select.children.find(item => item.value === 'Critic').disabled, true)
  assert.equal(select.children.find(item => item.value === 'Incompatible').disabled, true)
  h.choose(0, 'Researcher')
  assert.match(visibleText(h.mounted.panel), /Current stage snapshot/); assert.match(visibleText(h.mounted.panel), /Proposed saved snapshot/)
  assert.match(visibleText(h.mounted.panel), /Researcher \[Researcher\] · revision 1/)
  assert.match(visibleText(h.mounted.panel), /New researcher \[Researcher\] · revision 3/)
  assert.match(visibleText(h.mounted.panel), /Research with counterevidence/); assert.match(visibleText(h.mounted.panel), /wiki\/new-method.md/)
  assert.equal(h.mounted.panel.querySelector('img'), null); assert.equal(h.values.get(h.key), saved); assert.equal(h.dispatches.length, 0)
  const cancelled = h.button('Apply stage replacement'); h.click('Cancel stage replacement'); cancelled.click()
  assert.equal(h.mounted.controller.state.draft.composition.stages[0].source.revision, 1)
  h.choose(0, 'Researcher'); const apply = h.button('Apply stage replacement'); apply.click(); apply.click()
  assert.equal(h.mounted.controller.state.draft.composition.stages[0].source.revision, 3)
  assert.equal(h.mounted.panel.querySelector('[name="handoff-0"]').value, 'Pass cited findings to the critic.')
  assert.equal(h.mounted.panel.querySelector('[name="handoff-1"]').value, 'Produce the final report.')
  assert.equal(h.values.get(h.key), saved); assert.equal(h.mounted.controller.state.created.revision, 1)
  h.click('Create revised specialist'); assert.match(visibleText(h.mounted.panel), /New researcher r3 → Critic r1/)
  h.click('Save specialist'); await h.reload(); h.click('Report creator · revision 2')
  h.click('Try in chat'); await settle(); assert.equal(h.dispatches.length, 1)
  assert.match(h.dispatches[0][2], /Stage 1: New researcher/); assert.match(h.dispatches[0][2], /Stage 2: Critic/)
  assert.match(h.dispatches[0][2], /Pass cited findings to the critic/)
  assert.deepEqual(JSON.parse(h.dispatches[0][3]).knowledge_paths, ['wiki/new-method.md', 'raw/shared.md'])
})

test('visible stage comparison handles changed handoff, detached controls, reorder and Escape without overwriting work', async () => {
  const h = stageReplacementDomHarness(); await h.mounted.controller.open(); h.click('Report creator · revision 1'); h.click('Revise')
  h.choose(0, 'Researcher'); h.input('handoff-0', 'Deliver a changed intermediate output.')
  h.click('Apply stage replacement'); assert.match(visibleText(h.mounted.panel), /draft changed after the comparison/)
  assert.equal(h.mounted.panel.querySelector('[name="handoff-0"]').value, 'Deliver a changed intermediate output.')
  h.choose(0, 'Researcher'); const oldApply = h.button('Apply stage replacement'), oldReview = h.button('Review replacement for stage 1')
  h.click('Move stage 1 down'); oldApply.click(); oldReview.click()
  assert.deepEqual(h.mounted.controller.state.draft.composition.stages.map(stage => stage.source.name), ['Critic', 'Researcher'])
  assert.equal(h.mounted.controller.state.stageReplacement, null)
  h.choose(1, 'Researcher'); const escaped = h.button('Apply stage replacement')
  h.mounted.panel.fire('keydown', { key: 'Escape' }); assert.equal(h.app.inert, false); escaped.click()
  await h.mounted.controller.open(); assert.equal(h.mounted.controller.state.stageReplacement, null)
  assert.equal(h.mounted.panel.querySelector('[name="handoff-1"]').value, 'Deliver a changed intermediate output.')
  h.choose(1, 'Researcher'); h.click('Apply stage replacement')
  assert.deepEqual(h.mounted.controller.state.draft.composition.stages.map(stage => stage.source.name), ['Critic', 'New researcher'])
  assert.equal(h.mounted.panel.querySelector('[name="handoff-1"]').value, 'Deliver a changed intermediate output.')
})
