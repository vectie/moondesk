import { localDateTime, zonedInputSeconds, scheduleOccurrences } from './mooncode-calendar-runtime.js'
import { iconMarkup } from './ui-icons.js'
import { uiText, uiLocale, userContent } from './ui-locale.js'

const calendars = new Map()
const reminded = new Set()

function calendarEventIcs(event) {
  const escape = value => String(value || '').replace(/\\/g, '\\\\').replace(/\r?\n/g, '\\n').replace(/;/g, '\\;').replace(/,/g, '\\,')
  const stamp = seconds => new Date(Number(seconds) * 1000).toISOString().replace(/[-:]/g, '').replace(/\.\d{3}Z$/, 'Z')
  const localStamp = seconds => localDateTime(seconds, event.timezone || 'UTC').replace(/[-:]/g, '') + '00'
  const recurrence = event.recurrence || 'once'
  const recurring = recurrence !== 'once'
  const start = recurring ? `DTSTART;TZID=${event.timezone || 'UTC'}:${localStamp(event.starts_at)}` : `DTSTART:${stamp(event.starts_at)}`
  const end = recurring ? `DTEND;TZID=${event.timezone || 'UTC'}:${localStamp(event.ends_at)}` : `DTEND:${stamp(event.ends_at)}`
  const rule = recurrence === 'weekly' ? 'RRULE:FREQ=WEEKLY' : recurrence === 'weekdays' ? 'RRULE:FREQ=WEEKLY;BYDAY=MO,TU,WE,TH,FR' : recurrence === 'daily' ? 'RRULE:FREQ=DAILY' : ''
  return ['BEGIN:VCALENDAR', 'VERSION:2.0', 'PRODID:-//MoonDesk//Book Calendar//EN', 'BEGIN:VEVENT', `UID:${escape(event.id)}@moondesk`, `DTSTAMP:${stamp(Date.now() / 1000)}`, start, end, `SUMMARY:${escape(event.title)}`, `DESCRIPTION:${escape([event.description, event.document_path].filter(Boolean).join('\n'))}`, ...(rule ? [rule] : []), ...(Number(event.remind_minutes) >= 0 ? ['BEGIN:VALARM', `TRIGGER:-PT${Number(event.remind_minutes)}M`, 'ACTION:DISPLAY', `DESCRIPTION:${escape(event.title)}`, 'END:VALARM'] : []), 'END:VEVENT', 'END:VCALENDAR', ''].join('\r\n')
}

function downloadCalendarEvent(event) {
  const url = URL.createObjectURL(new Blob([calendarEventIcs(event)], { type: 'text/calendar;charset=utf-8' }))
  const link = document.createElement('a'); link.href = url; link.download = `${event.id || 'event'}.ics`
  document.body.append(link); link.click(); setTimeout(() => { link.remove(); URL.revokeObjectURL(url) }, 1000)
}

function bookCalendarOccurrences(events, now = new Date(), days = 14) {
  const start = new Date(now); start.setHours(0, 0, 0, 0)
  return scheduleOccurrences(events.map(event => ({ ...event, enabled: true, next_due_at: event.starts_at, interval_seconds: 86400, repeat: event.recurrence !== 'once' })), start, days)
}

function el(tag, className = '', text = '') { const node = document.createElement(tag); node.className = className; node.textContent = text; return node }
function button(label, callback) { const node = el('button', 'secondary-button', label); node.type = 'button'; node.addEventListener('click', callback); return node }

function renderBookCalendar(state, options = {}) {
  const workspaceId = state.workspace_id || ''
  let calendar = calendars.get(workspaceId)
  if (!calendar) { calendar = { events: [], loaded: false, loading: false, busy: false, error: '', draft: null }; calendars.set(workspaceId, calendar) }
  const root = el('div', 'document-tool-content book-calendar')
  const load = async () => {
    if (calendar.loading || !workspaceId) return
    calendar.loading = true; draw()
    try {
      const response = await fetch(`/api/document-calendar?workspace_id=${encodeURIComponent(workspaceId)}`)
      if (!response.ok) throw new Error('Calendar could not be loaded. Try Refresh.')
      calendar.events = (await response.json()).events || []; calendar.loaded = true; calendar.error = ''
    } catch (error) { calendar.error = error.message }
    calendar.loading = false; draw()
  }
  const save = async payload => {
    if (calendar.busy) return
    calendar.busy = true; calendar.error = ''; draw()
    try {
      const response = await fetch('/api/document-calendar', { method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({ ...payload, workspace_id: workspaceId }) })
      const data = await response.json()
      if (!response.ok) throw new Error(data.message || 'Event could not be saved. Your draft is kept.')
      calendar.events = data.events || []; calendar.draft = null
    } catch (error) { calendar.error = error.message }
    calendar.busy = false; draw()
  }
  const edit = event => {
    const timezone = event?.timezone || Intl.DateTimeFormat().resolvedOptions().timeZone || 'UTC'
    calendar.draft = event ? { ...event, start: localDateTime(event.starts_at, timezone), end: localDateTime(event.ends_at, timezone) } : {
      title: '', description: '', timezone, start: localDateTime(Date.now() / 1000 + 3600), end: localDateTime(Date.now() / 1000 + 5400), recurrence: 'once', remind_minutes: 15, document_path: state.selected_document || '',
    }
    draw()
  }
  const draw = () => {
    root.replaceChildren()
    const intro = el('div', 'document-tool-intro secondary-tools')
    const refresh = button('', load); refresh.className = 'moon-icon-button'; refresh.setAttribute('aria-label', 'Refresh'); refresh.title = 'Refresh'; refresh.innerHTML = iconMarkup('refresh')
    if (!calendar.draft) intro.append(button('New event', () => edit(null)))
    intro.append(refresh); root.append(intro)
    const reminders = el('details', 'book-calendar-reminders')
    reminders.append(el('summary', '', 'Reminder behavior'), el('p', 'mooncode-schedule-form-help', 'MoonDesk shows reminders while this book calendar is open. Export an event to your calendar app for reminders when MoonDesk is closed.'))
    if (typeof Notification !== 'undefined' && Notification.permission !== 'granted') reminders.append(button('Enable desktop reminders', async () => { await Notification.requestPermission(); draw() }))
    const status = el('p', 'status-line', calendar.error || (calendar.loading ? 'Loading calendar…' : '')); status.setAttribute('role', 'status'); root.append(status)
    if (calendar.draft && !calendar.draft.deleting) {
      const draft = calendar.draft
      const form = el('form', 'mooncode-calendar-form')
      const canSave = () => Boolean(draft.title.trim() && draft.start && draft.end && draft.end > draft.start && !calendar.busy)
      const syncSave = () => { submit.disabled = !canSave() }
      for (const [key, label, type] of [['title', 'Event title', 'text'], ['description', 'Notes', 'text'], ['start', 'Starts', 'datetime-local'], ['end', 'Ends', 'datetime-local'], ['document_path', 'Related file', 'text']]) {
        const field = el('label'); field.append(el('span', '', label))
        const input = el('input'); input.type = type; input.value = draft[key] || ''; input.required = ['title', 'start', 'end'].includes(key); input.addEventListener('input', () => { draft[key] = input.value; syncSave() }); field.append(input); form.append(field)
      }
      for (const [key, label, choices] of [['recurrence', 'Repeat', [['once', 'Once'], ['daily', 'Daily'], ['weekdays', 'Weekdays'], ['weekly', 'Weekly']]], ['remind_minutes', 'Remind me', [['-1', 'No reminder'], ['0', 'At start'], ['5', '5 minutes before'], ['15', '15 minutes before'], ['60', '1 hour before']]]]) {
        const field = el('label'); field.append(el('span', '', label)); const select = el('select')
        for (const [value, title] of choices) { const option = el('option', '', title); option.value = value; select.append(option) }
        select.value = String(draft[key]); select.addEventListener('change', () => { draft[key] = select.value }); field.append(select); form.append(field)
      }
      form.append(el('p', 'mooncode-schedule-form-help', `Time zone: ${draft.timezone}`))
      const submit = el('button', 'primary-button', calendar.busy ? 'Saving…' : 'Save event'); submit.type = 'submit'; syncSave()
      const actions = el('div', 'mooncode-calendar-form-actions'); actions.append(button('Cancel', () => { calendar.draft = null; draw() }), submit); form.append(actions)
      form.addEventListener('submit', event => { event.preventDefault(); if (!canSave()) return; try { void save({ ...draft, starts_at: zonedInputSeconds(draft.start, draft.timezone), ends_at: zonedInputSeconds(draft.end, draft.timezone), remind_minutes: Number(draft.remind_minutes) }) } catch (error) { calendar.error = error.message; draw() } })
      root.append(form)
    }
    const occurrences = bookCalendarOccurrences(calendar.events)
    if (occurrences.length) root.append(el('h4', '', 'Next two weeks'))
    if (!occurrences.length && calendar.loaded && !calendar.error && !calendar.draft) root.append(el('p', 'document-tool-empty', 'No upcoming events.'))
    root.append(reminders)
    for (const { schedule: event, time } of occurrences) {
      const row = el('article', 'result-bundle')
      row.append(userContent(el('strong', '', event.title)), el('p', '', new Date(time * 1000).toLocaleString(uiLocale())), userContent(el('p', '', event.description || '')))
      const actions = el('div', 'result-bundle-actions'); actions.append(button('Edit event', () => edit(event)), button('Export to calendar', () => downloadCalendarEvent(event)))
      if (event.document_path) actions.append(button('Open related work', () => options.openFile?.(event.document_path)))
      actions.append(button('Remove event', () => { calendar.draft = { ...event, start: localDateTime(event.starts_at, event.timezone), end: localDateTime(event.ends_at, event.timezone), deleting: true }; draw() }))
      row.append(actions); root.append(row)
    }
    if (calendar.draft?.deleting) {
      const prompt = el('div', 'result-bundle'); prompt.append(el('p', '', `Remove “${calendar.draft.title}” and its future occurrences?`), button('Remove', () => save({ action: 'delete', id: calendar.draft.id })), button('Keep event', () => { calendar.draft = null; draw() })); root.append(prompt)
    }
    const past = calendar.events.filter(event => event.recurrence === 'once' && Number(event.ends_at) < Date.now() / 1000)
    if (past.length) {
      const history = el('details'); history.append(el('summary', '', `${past.length} past events`))
      for (const event of past) history.append(userContent(button(event.title, () => edit(event))))
      root.append(history)
    }
  }
  draw(); if (!calendar.loaded && !calendar.loading) void load()
  const timer = setInterval(() => {
    if (!root.isConnected) { clearInterval(timer); return }
    const now = Date.now() / 1000
    for (const { schedule: event, time } of bookCalendarOccurrences(calendar.events)) {
      if (Number(event.remind_minutes) < 0) continue
      const due = time - Number(event.remind_minutes) * 60
      const key = `${workspaceId}:${event.id}:${time}`
      if (due <= now && now < time + 60 && !reminded.has(key)) {
        reminded.add(key)
        const notice = userContent(el('p', 'result-bundle', `${uiText('Reminder')}: ${event.title} · ${new Date(time * 1000).toLocaleTimeString(uiLocale())}`)); notice.setAttribute('role', 'alert'); root.prepend(notice)
        if (typeof Notification !== 'undefined' && Notification.permission === 'granted') new Notification(event.title, { body: event.description || uiText('Your book calendar event is starting soon.'), tag: key })
      }
    }
  }, 15000)
  timer?.unref?.()
  return root
}

export { calendarEventIcs, downloadCalendarEvent, bookCalendarOccurrences, renderBookCalendar }
