import { setIconButton } from './ui-icons.js'

const mounted = new WeakMap()

function localDateTime(seconds, timezone = '') {
  const date = new Date(Number(seconds) * 1000)
  if (!Number.isFinite(date.getTime())) return ''
  if (timezone) {
    const parts = Object.fromEntries(new Intl.DateTimeFormat('en-CA', {
      timeZone: timezone, year: 'numeric', month: '2-digit', day: '2-digit', hour: '2-digit', minute: '2-digit', hourCycle: 'h23',
    }).formatToParts(date).map(part => [part.type, part.value]))
    return `${parts.year}-${parts.month}-${parts.day}T${parts.hour}:${parts.minute}`
  }
  const pad = value => String(value).padStart(2, '0')
  return `${date.getFullYear()}-${pad(date.getMonth() + 1)}-${pad(date.getDate())}T${pad(date.getHours())}:${pad(date.getMinutes())}`
}

function zonedInputSeconds(value, timezone) {
  if (!timezone) return new Date(value).getTime() / 1000
  const target = Date.parse(`${value}:00Z`) / 1000
  let candidate = target
  for (let index = 0; index < 4; index++) {
    const actual = Date.parse(`${localDateTime(candidate, timezone)}:00Z`) / 1000
    if (actual === target) return candidate
    candidate += target - actual
  }
  throw new Error('This local time is skipped by a daylight-saving change. Choose another time.')
}

function scheduleOccurrences(schedules, start, days = 7) {
  const end = new Date(start)
  end.setDate(end.getDate() + days)
  const startSeconds = Math.floor(start.getTime() / 1000)
  const endSeconds = Math.floor(end.getTime() / 1000)
  const events = []
  for (const schedule of schedules) {
    if (!schedule.enabled) continue
    let time = Number(schedule.next_due_at)
    const interval = Number(schedule.interval_seconds)
    if (!Number.isFinite(time) || !Number.isFinite(interval) || interval < 60) continue
    if (schedule.repeat !== false && ['daily', 'weekdays', 'weekly'].includes(schedule.recurrence)) {
      const timezone = schedule.timezone || 'UTC'
      const anchor = localDateTime(Number(schedule.calendar_anchor_at || time), timezone)
      const anchorWeekday = new Date(`${anchor.slice(0, 10)}T12:00:00Z`).getUTCDay()
      const firstDate = new Date(`${localDateTime(startSeconds, timezone).slice(0, 10)}T12:00:00Z`)
      for (let offset = 0; offset <= days + 1; offset++) {
        const date = new Date(firstDate)
        date.setUTCDate(date.getUTCDate() + offset)
        if (schedule.recurrence === 'weekdays' && [0, 6].includes(date.getUTCDay())) continue
        if (schedule.recurrence === 'weekly' && date.getUTCDay() !== anchorWeekday) continue
        let candidate
        try { candidate = zonedInputSeconds(`${date.toISOString().slice(0, 10)}T${anchor.slice(11)}`, timezone) } catch { continue }
        if (candidate >= Math.max(startSeconds, time) && candidate < endSeconds) events.push({ schedule, time: candidate })
      }
      continue
    }
    if (time < startSeconds && schedule.repeat !== false) time += Math.ceil((startSeconds - time) / interval) * interval
    for (let count = 0; time < endSeconds && count < days * 1440; count++, time += interval) {
      if (time >= startSeconds) events.push({ schedule, time })
      if (schedule.repeat === false) break
    }
  }
  return events.sort((a, b) => a.time - b.time)
}

function scheduleDraftPayload(draft, workspaceId, now = Date.now()) {
  const prompt = String(draft.prompt || '').trim()
  const model = String(draft.model || '').trim()
  const interval = Number(draft.minutes) * 60
  const when = zonedInputSeconds(draft.start, draft.timezone) * 1000
  if (!prompt || !model || !String(draft.title || '').trim()) throw new Error('Enter a name, task, and model.')
  if (!Number.isFinite(when) || when < now - 60_000) throw new Error('Choose a start time in the future.')
  if (!Number.isInteger(interval) || interval < 60 || interval > 2592000) throw new Error('Choose a repeat interval from 1 minute to 30 days.')
  return {
    action: draft.id ? 'update' : 'create',
    id: draft.id || `task-${globalThis.crypto?.randomUUID?.() || now.toString(36)}`,
    book_id: workspaceId, title: draft.title.trim(), prompt, model,
    interval_seconds: interval, next_due_at: Math.floor(when / 1000), repeat: draft.repeat !== 'once',
    recurrence: ['daily', 'weekdays', 'weekly'].includes(draft.repeat) ? draft.repeat : 'interval',
    timezone: draft.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
  }
}

function el(tag, className = '', text = '') {
  const node = document.createElement(tag)
  node.className = className
  node.textContent = text
  return node
}

function button(label, handler) {
  const node = el('button', 'secondary-button', label)
  node.type = 'button'
  node.addEventListener('click', handler)
  return node
}

function iconButton(label, icon, handler) {
  return setIconButton(button(label, handler), icon, label)
}

function mountCalendar(host) {
  const workspaceId = host.dataset.workspaceId
  const state = { workspaceId, schedules: [], loading: false, busy: false, error: '', notice: '', draft: null, offset: 0, remove: '' }
  mounted.set(host, state)
  const mutate = async payload => {
    if (state.busy) return
    state.busy = true
    state.error = ''
    draw()
    try {
      const response = await fetch('/api/mooncode/schedules', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify(payload),
      })
      const result = await response.json()
      if (!response.ok || !Array.isArray(result.schedules)) throw new Error(result.message || result.error || 'This schedule could not be saved.')
      state.schedules = result.schedules.filter(item => item.book_id === workspaceId)
      state.draft = null
      state.remove = ''
      state.notice = payload.action === 'run-now' ? 'Queued to run. The conversation will show the result.' : payload.action === 'delete' ? 'Schedule removed. Its conversation remains available.' : 'Schedule saved.'
    } catch (error) { state.error = error.message }
    state.busy = false
    draw()
  }
  const load = async () => {
    if (state.loading) return
    state.loading = true
    state.error = ''
    draw()
    try {
      const response = await fetch('/api/mooncode/schedules')
      const result = await response.json()
      if (!response.ok || !Array.isArray(result.schedules)) throw new Error(result.message || 'Scheduled work is unavailable. Start MoonTown and refresh.')
      state.schedules = result.schedules.filter(item => item.book_id === workspaceId)
    } catch (error) { state.error = error.message }
    state.loading = false
    draw()
  }
  const edit = schedule => {
    state.draft = schedule ? {
      id: schedule.id, title: schedule.title || schedule.id, prompt: schedule.prompt, model: schedule.model,
      minutes: schedule.interval_seconds / 60, repeat: schedule.repeat === false ? 'once' : schedule.recurrence || 'interval',
      timezone: schedule.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC',
      start: localDateTime(Math.max(Number(schedule.next_due_at), Math.floor(Date.now() / 1000) + 300), schedule.timezone || ''),
    } : { title: '', prompt: '', model: host.dataset.model || '', minutes: 1440, repeat: 'daily', timezone: Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC', start: localDateTime(Date.now() / 1000 + 3600) }
    draw()
    host.querySelector('input')?.focus()
  }
  const draw = () => {
    if (!host.isConnected) return
    host.replaceChildren()
    host.classList.add('mooncode-calendar')
    const header = el('div', 'mooncode-calendar-toolbar')
    header.append(button('New scheduled task', () => edit(null)), iconButton('Refresh', 'refresh', load))
    host.append(header)
    const status = el('p', 'status-line', state.error || (state.loading ? 'Loading…' : state.notice))
    status.setAttribute('role', state.error ? 'alert' : 'status')
    if (status.textContent) host.append(status)
    const start = new Date()
    start.setHours(0, 0, 0, 0)
    start.setDate(start.getDate() + state.offset * 7)
    const navigation = el('div', 'mooncode-calendar-toolbar')
    navigation.append(iconButton('Previous week', 'chevron-left', () => { state.offset--; draw() }), button('Today', () => { state.offset = 0; draw() }), iconButton('Next week', 'chevron-right', () => { state.offset++; draw() }), el('span', 'mooncode-calendar-month', start.toLocaleDateString(undefined, { year: 'numeric', month: 'long' })))
    host.append(navigation)
    const week = el('div', 'mooncode-calendar-week')
    const events = scheduleOccurrences(state.schedules, start)
    for (let day = 0; day < 7; day++) {
      const date = new Date(start)
      date.setDate(date.getDate() + day)
      const column = el('section', 'mooncode-calendar-day')
      column.append(el('span', 'mooncode-calendar-weekday', date.toLocaleDateString(undefined, { weekday: 'short' })), el('h4', '', String(date.getDate())))
      const daily = events.filter(event => new Date(event.time * 1000).toDateString() === date.toDateString())
      for (const event of daily.slice(0, 4)) {
        const label = `${new Date(event.time * 1000).toLocaleTimeString(undefined, { hour: '2-digit', minute: '2-digit' })} · ${event.schedule.title || event.schedule.id}`
        column.append(button(label, () => edit(event.schedule)))
      }
      if (daily.length > 4) column.append(el('small', '', `+${daily.length - 4} more runs`))
      week.append(column)
    }
    host.append(week)
    if (!events.length) host.append(el('p', 'mooncode-calendar-empty', 'No runs this week'))
    const timing = el('details', 'mooncode-calendar-timing')
    timing.append(el('summary', '', 'Schedule timing'), el('p', '', 'Times use your local timezone. Daily and weekly tasks keep their saved local time, including daylight-saving changes. Custom intervals start after the previous run finishes.'))
    host.append(timing)
    if (state.draft) {
      const draft = state.draft
      const form = el('form', 'mooncode-calendar-form')
      form.append(el('h4', '', draft.id ? 'Edit scheduled task' : 'New scheduled task'))
      for (const [key, label, type] of [['title', 'Task name', 'text'], ['prompt', 'What should happen?', 'textarea'], ['model', 'Model', 'text'], ['start', 'Start at', 'datetime-local']]) {
        const field = el('label')
        field.append(el('span', '', label))
        const input = el(type === 'textarea' ? 'textarea' : 'input')
        if (type !== 'textarea') input.type = type
        input.required = true
        input.value = draft[key] || ''
        input.addEventListener('input', () => { draft[key] = input.value })
        field.append(input)
        form.append(field)
      }
      const cadence = el('label')
      cadence.append(el('span', '', 'Repeat'))
      const select = el('select')
      for (const [value, label] of [['once', 'Once'], ['daily', 'Every day'], ['weekdays', 'Weekdays'], ['weekly', 'Every week'], ['60', 'Every hour'], ['interval', 'Custom interval']]) {
        const option = el('option', '', label)
        option.value = value
        select.append(option)
      }
      select.value = ['once', 'daily', 'weekdays', 'weekly'].includes(draft.repeat) ? draft.repeat : String(draft.minutes) === '60' ? '60' : 'interval'
      select.addEventListener('change', () => {
        draft.repeat = ['once', 'daily', 'weekdays', 'weekly'].includes(select.value) ? select.value : 'interval'
        if (select.value === '60') draft.minutes = 60
        draw()
      })
      cadence.append(select)
      form.append(cadence)
      form.append(el('p', 'mooncode-schedule-form-help', `Time zone: ${draft.timezone}. Weekly tasks repeat on the start date’s weekday.`))
      if (select.value === 'interval') {
        const label = el('label')
        label.append(el('span', '', 'Repeat every (minutes)'))
        const minutes = el('input')
        minutes.type = 'number'; minutes.min = '1'; minutes.max = '43200'; minutes.value = draft.minutes
        minutes.addEventListener('input', () => { draft.minutes = minutes.value })
        label.append(minutes); form.append(label)
      }
      const save = el('button', 'primary-button', state.busy ? 'Saving…' : 'Save task')
      save.type = 'submit'; save.disabled = state.busy
      form.append(save, button('Cancel', () => { state.draft = null; draw() }))
      form.addEventListener('submit', event => {
        event.preventDefault()
        try { void mutate(scheduleDraftPayload(draft, workspaceId)) } catch (error) { state.error = error.message; draw() }
      })
      host.append(form)
    }
    for (const schedule of state.schedules) {
      const row = el('article', 'mooncode-calendar-task')
      const prompt = el('details', 'mooncode-calendar-prompt')
      prompt.append(el('summary', '', schedule.title || schedule.id), el('p', '', schedule.prompt))
      row.append(prompt)
      const last = Number(schedule.last_finished_at) > 0 ? ` · Last result: ${schedule.last_status} · ${new Date(Number(schedule.last_finished_at) * 1000).toLocaleString()}` : ''
      row.append(el('small', '', `${schedule.enabled ? 'Active' : 'Paused'}${last}`))
      const actions = el('div', 'mooncode-calendar-toolbar')
      const pending = Boolean(schedule.pending_command_id)
      for (const [label, icon, handler] of [
        ['Edit', 'edit', () => edit(schedule)], ['Run now', 'play', () => mutate({ action: 'run-now', id: schedule.id })],
        [schedule.enabled ? 'Pause' : 'Resume', schedule.enabled ? 'paused' : 'running', () => mutate({ action: schedule.enabled ? 'pause' : 'resume', id: schedule.id })],
        ['Remove', 'trash', () => { state.remove = schedule.id; draw() }],
      ]) {
        const control = iconButton(label, icon, handler)
        control.disabled = state.busy || (pending && ['Edit', 'Run now', 'Remove'].includes(label))
        actions.append(control)
      }
      const nativeRow = [...host.parentElement.querySelectorAll('[data-schedule-id]')].find(item => item.dataset.scheduleId === schedule.id)
      const nativeOpen = nativeRow?.querySelector('button')
      if (schedule.last_status !== 'never-run') actions.append(iconButton('Open conversation', 'chat', () => {
        if (nativeOpen && !nativeOpen.disabled) nativeOpen.click()
        else {
          const url = new URL(globalThis.location.href)
          for (const name of [...url.searchParams.keys()]) if (name.startsWith('work_') || ['command', 'book_root', 'return_to', 'path'].includes(name)) url.searchParams.delete(name)
          url.searchParams.set('activity', 'code'); url.searchParams.set('workspace', workspaceId); url.searchParams.set('session', schedule.session_id)
          globalThis.location.assign(url)
        }
      }))
      row.append(actions)
      if (state.remove === schedule.id) {
        row.append(el('p', '', 'Remove future runs? Your conversation and previous results remain available.'), button('Remove schedule', () => mutate({ action: 'delete', id: schedule.id })), button('Keep schedule', () => { state.remove = ''; draw() }))
      }
      host.append(row)
    }
    // The MoonBit controls remain as a fallback before this enhancement loads.
    host.parentElement.classList.add('calendar-ready')
  }
  void load()
}

function enhanceCalendars() {
  for (const host of document.querySelectorAll('[data-testid="mooncode-calendar-host"]')) {
    if (!mounted.has(host) || mounted.get(host).workspaceId !== host.dataset.workspaceId) mountCalendar(host)
  }
}

if (typeof document !== 'undefined') {
  const observer = new MutationObserver(records => {
    if (records.some(record => record.type === 'attributes' || [...record.addedNodes].some(node => node.nodeType === 1 && (node.matches?.('[data-testid="mooncode-calendar-host"]') || node.querySelector?.('[data-testid="mooncode-calendar-host"]'))))) enhanceCalendars()
  })
  observer.observe(document.documentElement, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-workspace-id'] })
  enhanceCalendars()
}

export { localDateTime, zonedInputSeconds, scheduleOccurrences, scheduleDraftPayload, enhanceCalendars }
