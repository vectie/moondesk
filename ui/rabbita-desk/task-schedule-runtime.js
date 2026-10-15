import { localDateTime, scheduleDraftPayload } from './mooncode-calendar-runtime.js'
import { taskSources } from './work-journey-runtime.js'

const bindingKey = 'moondesk.task-schedules.v1'
const scheduleViews = new Map()
export function taskScheduleBindings() {
  try { return JSON.parse(localStorage.getItem(bindingKey) || '{}') } catch { return {} }
}

export function taskSchedulePayload(draft, origin, now = Date.now()) {
  const sources = taskSources(origin.thread).map(source => source.path)
  const outputs = origin.bundle.artifacts.map(file => file.path)
  const prompt = [draft.prompt, sources.length ? `Sources in this MoonBook:\n${sources.join('\n')}` : '',
    outputs.length ? `Update these outputs and keep their paths:\n${outputs.join('\n')}` : '',
    'Summarize what changed when you finish.'].filter(Boolean).join('\n\n')
  return { ...scheduleDraftPayload({ ...draft, id: draft.editing ? draft.id : '', prompt }, origin.workspaceId, now), id: draft.id }
}

export function taskScheduleEditDraft(schedule, binding, now = Date.now()) {
  const timezone = schedule.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
  const originalPrompt = String(schedule.prompt || '').split('\n\nSources in this MoonBook:')[0].split('\n\nUpdate these outputs and keep their paths:')[0].replace(/\n\nSummarize what changed when you finish\.$/, '')
  return { id: schedule.id, editing: true, title: schedule.title || binding.title, prompt: binding.prompt || originalPrompt, model: schedule.model, minutes: Number(schedule.interval_seconds) / 60, repeat: schedule.repeat === false ? 'once' : schedule.recurrence || 'weekly', timezone, start: localDateTime(Math.max(Number(schedule.next_due_at), now / 1000 + 300), timezone) }
}

export function taskScheduleSummary(workspaceId, conversationId) {
  const view = scheduleViews.get(workspaceId)
  if (!view?.loaded) return null
  const bindings = taskScheduleBindings()
  return view.schedules.filter(schedule => bindings[schedule.id]?.conversationId === conversationId).length
}
export function rememberTaskSchedules(workspaceId, schedules) {
  scheduleViews.set(workspaceId, { schedules, loaded: true, busy: false, error: '' })
}

export function renderTaskSchedules(origin, { el, onEdit, onOpenRun, onChanged }) {
  const { workspaceId, conversationId } = origin
  let view = scheduleViews.get(workspaceId)
  if (!view) { view = { schedules: [], loaded: false, busy: false, error: '' }; scheduleViews.set(workspaceId, view) }
  const root = el('div', 'document-tool-content task-schedules')
  const load = async () => {
    if (view.busy) return
    view.busy = true; view.error = ''; draw()
    try {
      const response = await fetch('/api/mooncode/schedules'); const data = await response.json()
      if (!response.ok || !Array.isArray(data.schedules)) throw new Error('Start MoonTown to manage scheduled work.')
      view.schedules = data.schedules; view.loaded = true
    } catch (error) { view.error = error.message }
    view.busy = false; draw(); onChanged?.()
  }
  const mutate = async (schedule, action) => {
    if (view.busy) return
    view.busy = true; view.error = ''; draw()
    try {
      const response = await fetch('/api/mooncode/schedules', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ action, id: schedule.id }) })
      const data = await response.json()
      if (!response.ok || !Array.isArray(data.schedules)) throw new Error(data.message || 'This schedule could not be changed. Try again.')
      view.schedules = data.schedules
      if (action === 'delete') { const bindings = taskScheduleBindings(); delete bindings[schedule.id]; localStorage.setItem(bindingKey, JSON.stringify(bindings)) }
    } catch (error) { view.error = error.message }
    view.busy = false; draw(); onChanged?.()
  }
  const draw = () => {
    root.replaceChildren()
    const refresh = el('button', 'secondary-button', 'Refresh'); refresh.type = 'button'; refresh.onclick = load; refresh.disabled = view.busy
    root.append(refresh)
    const status = el('p', 'status-line', view.error || (view.busy ? 'Updating schedules…' : '')); status.setAttribute('role', 'status'); root.append(status)
    const bindings = taskScheduleBindings()
    const schedules = view.schedules.filter(schedule => schedule.book_id === workspaceId && bindings[schedule.id] && (!conversationId || bindings[schedule.id].conversationId === conversationId))
    if (view.loaded && !schedules.length) root.append(el('p', 'document-tool-empty', 'No schedules for this task. Use the calendar beside an output to create one.'))
    for (const schedule of schedules) {
      const row = el('article', 'task-schedule-row')
      row.append(el('strong', '', schedule.title || bindings[schedule.id].title), el('small', '', `${schedule.enabled ? 'Active' : 'Paused'} · ${new Date(Number(schedule.next_due_at) * 1000).toLocaleString()}`))
      const actions = el('div', 'task-schedule-actions')
      for (const [icon, label, callback] of [
        ['edit', 'Edit schedule', () => onEdit(schedule, bindings[schedule.id])],
        [schedule.enabled ? 'paused' : 'play', schedule.enabled ? 'Pause schedule' : 'Resume schedule', () => mutate(schedule, schedule.enabled ? 'pause' : 'resume')],
        ['refresh', 'Run now', () => mutate(schedule, 'run-now')],
        ['trash', 'Remove schedule', () => mutate(schedule, 'delete')],
      ]) {
        const button = el('button', 'moon-icon-button'); button.type = 'button'; button.title = label; button.setAttribute('aria-label', label); button.disabled = view.busy
        const glyph = el('span', 'moon-icon'); glyph.dataset.icon = icon; glyph.setAttribute('aria-hidden', 'true'); button.append(glyph); button.onclick = callback; actions.append(button)
      }
      if (schedule.last_command_id && onOpenRun) { const run = el('button', 'secondary-button', 'Open last run'); run.type = 'button'; run.onclick = () => onOpenRun(schedule.session_id); actions.append(run) }
      row.append(actions); root.append(row)
    }
  }
  draw(); if (!view.loaded && !view.busy && !view.error) void load()
  return root
}

export function linkedScheduleResults(schedules, bindings, workspaceId, conversationId = '') {
  return schedules.flatMap(schedule => {
    const binding = bindings[schedule.id]
    if (!binding || binding.workspaceId !== workspaceId || schedule.book_id !== workspaceId ||
      (conversationId && binding.conversationId !== conversationId) || !Number(schedule.last_finished_at)) return []
    return [{
      contract: 'moondesk.document_automation_result.v1', kind: 'background_result',
      id: `scheduled-${schedule.id}-${schedule.last_command_id}-${schedule.last_finished_at}`,
      goal_id: schedule.id, run_id: schedule.last_command_id,
      conversation_id: binding.conversationId, code_session_id: schedule.session_id,
      conversation_kind: binding.kind || '',
      decision: schedule.last_status, summary: `${binding.title} · ${schedule.last_status}`,
      path: binding.outputPaths?.[0] || '', document_path: binding.outputPaths?.[0] || '',
      output_paths: binding.outputPaths || [], warning: schedule.last_status === 'failed',
      created_at: new Date(Number(schedule.last_finished_at) * 1000).toISOString(),
    }]
  })
}

export function renderTaskSchedule(origin, { el, onClose, onSaved }) {
  const zone = Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
  const draft = origin.draft ||= {
    id: `task-${crypto.randomUUID()}`, title: origin.bundle.title,
    prompt: origin.thread?.chat?.find(entry => entry.role === 'user')?.content || origin.bundle.summary || `Refresh ${origin.bundle.title}`,
    model: origin.model || '', repeat: 'weekly', minutes: 10080,
    timezone: zone, start: localDateTime(Date.now() / 1000 + 86400, zone),
  }
  const root = el('div', 'document-tool-content task-schedule')
  if (origin.saved) {
    root.append(el('h3', '', 'Task scheduled'), el('p', 'status-line', 'New results will appear in this task.'))
    const done = el('button', 'primary-button', 'Done'); done.type = 'button'; done.onclick = onClose; root.append(done)
    return root
  }
  const form = el('form', 'task-start-form')
  const back = el('button', 'secondary-button', origin.returnTab === 'schedules' ? '← Schedules' : '← Results'); back.type = 'button'; back.onclick = onClose
  root.append(back, el('h3', '', draft.editing ? 'Edit schedule' : 'Schedule this task'), el('p', 'status-line', origin.bundle.title))
  for (const [key, label, type] of [['title', 'Name', 'text'], ['prompt', 'Task', 'textarea'], ['start', 'First run', 'datetime-local']]) {
    const field = el('label', '', label)
    const input = el(type === 'textarea' ? 'textarea' : 'input')
    if (type !== 'textarea') input.type = type
    else input.rows = 3
    input.value = draft[key]; input.required = true
    input.oninput = () => { draft[key] = input.value }
    field.append(input); form.append(field)
  }
  const repeat = el('label', '', 'Repeat'); const select = el('select')
  for (const [value, label] of [['daily', 'Daily'], ['weekdays', 'Weekdays'], ['weekly', 'Weekly'], ['once', 'Once']]) {
    const option = el('option', '', label); option.value = value; select.append(option)
  }
  select.value = draft.repeat; select.onchange = () => { draft.repeat = select.value; draft.minutes = select.value === 'weekly' ? 10080 : 1440 }
  repeat.append(select); form.append(repeat)
  const model = el('label', '', 'Model'); const models = el('input'); models.type = 'text'; models.required = true
  models.setAttribute('list', 'task-schedule-models'); models.placeholder = 'provider/model'
  const choices = el('datalist'); choices.id = 'task-schedule-models'
  const populateModels = () => {
    choices.replaceChildren()
    for (const value of [...new Set([draft.model, ...(origin.models || [])])].filter(Boolean)) {
      const option = el('option', '', value); option.value = value; choices.append(option)
    }
    models.value = draft.model
  }
  populateModels(); models.oninput = () => { draft.model = models.value }; model.append(models, choices); form.append(model)
  if (!origin.modelsLoaded && !(origin.models || []).length) {
    origin.modelsLoaded = true
    fetch('/api/moonclaw/models').then(response => response.ok ? response.json() : {}).then(payload => {
      origin.models = (payload.models || []).map(model => model.name).filter(Boolean)
      if (!draft.model) draft.model = payload.default_model || origin.models[0] || ''
      populateModels()
    }).catch(() => { origin.modelsLoaded = false })
  }
  form.append(el('small', '', `${draft.timezone} · Results return to this task`))
  const status = el('p', 'status-line'); status.setAttribute('role', 'status')
  const submit = el('button', 'primary-button', draft.editing ? 'Save schedule' : 'Create schedule'); submit.type = 'submit'
  form.append(status, submit); root.append(form)
  form.onsubmit = async event => {
    event.preventDefault(); submit.disabled = true; status.textContent = 'Saving schedule…'
    try {
      const payload = taskSchedulePayload(draft, origin)
      const response = await fetch('/api/mooncode/schedules', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload) })
      const result = await response.json()
      if (!response.ok || !Array.isArray(result.schedules)) throw new Error(response.status === 503 ? 'Start MoonTown to schedule this task. Your draft is kept.' : result.message || 'This schedule could not be saved. Try again.')
      const bindings = taskScheduleBindings()
      bindings[payload.id] = { workspaceId: origin.workspaceId, conversationId: origin.thread?.id || '', kind: origin.bundle.conversation_kind || '', title: origin.bundle.title, prompt: draft.prompt, outputPaths: origin.bundle.artifacts.map(file => file.path) }
      localStorage.setItem(bindingKey, JSON.stringify(bindings))
      scheduleViews.set(origin.workspaceId, { schedules: result.schedules, loaded: true, busy: false, error: '' })
      origin.saved = payload.id
      status.textContent = 'Scheduled. New results will appear in this task.'; submit.textContent = 'Scheduled'
      onSaved?.()
    } catch (error) { status.textContent = error.message; submit.disabled = false }
  }
  return root
}
