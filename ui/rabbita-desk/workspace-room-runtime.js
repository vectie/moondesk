const rooms = new Map()
let activeRoom = null
let refreshTimer = 0
const profileKey = 'moondesk.room-profile.v1'

function roomMessages(messages, parent = '') {
  return messages.filter(message => (message.reply_to || '') === parent)
}

function reactionCounts(message) {
  return (message.reactions || []).reduce((counts, item) => {
    counts[item.reaction] = (counts[item.reaction] || 0) + 1
    return counts
  }, {})
}

function el(tag, className = '', text = '') {
  const node = document.createElement(tag)
  node.className = className; node.textContent = text
  return node
}

function button(label, callback) {
  const node = el('button', 'secondary-button', label)
  node.type = 'button'; node.addEventListener('click', callback)
  return node
}

function readProfile() {
  try {
    const stored = JSON.parse(localStorage.getItem(profileKey) || '{}')
    if (stored.id) return stored
  } catch {}
  return { id: `person-${globalThis.crypto?.randomUUID?.() || Date.now()}`, name: '' }
}

function renderWorkspaceRoom(state, options = {}) {
  const workspaceId = state.workspace_id || ''
  let room = rooms.get(workspaceId)
  if (!room) {
    room = { channel: 'general', payload: { channels: [], messages: [], presence: [] }, drafts: new Map(), profile: readProfile(), loading: false, sending: false, error: '', reply: '', typingAt: 0, attach: false }
    rooms.set(workspaceId, room)
  }
  const root = el('div', 'document-tool-content workspace-room')
  root.dataset.testid = 'workspace-room'
  activeRoom = { root, room }
  const context = () => `${workspaceId}:${room.channel}`
  const load = async () => {
    if (!workspaceId || room.loading) return
    const requested = context()
    room.loading = true
    try {
      const response = await fetch(`/api/document-room?workspace_id=${encodeURIComponent(workspaceId)}&channel=${encodeURIComponent(room.channel)}`)
      if (!response.ok) throw new Error('Room could not be loaded. Try Refresh.')
      const payload = await response.json()
      if (requested !== context()) return
      const changed = JSON.stringify(room.payload) !== JSON.stringify(payload)
      room.payload = payload
      room.error = ''
      if (changed) draw()
    } catch (error) { room.error = error.message; draw() }
    finally { room.loading = false }
  }
  const send = async (action, fields = {}, quiet = false) => {
    if (!room.profile.name.trim()) { room.error = 'Enter your name to join the room.'; draw(); return false }
    const requested = context()
    if (!quiet && room.sending) return false
    if (!quiet) { room.sending = true; room.error = ''; draw() }
    try {
      const response = await fetch('/api/document-room', {
        method: 'POST', headers: { 'content-type': 'application/json' }, body: JSON.stringify({
          workspace_id: workspaceId, channel: room.channel, actor_id: room.profile.id,
          author: room.profile.name.trim(), action, ...fields,
        }),
      })
      const payload = await response.json()
      if (!response.ok) throw new Error(payload.message || 'Your message could not be sent. Your draft is kept.')
      if (requested === context()) room.payload = payload
      return true
    } catch (error) { if (!quiet) room.error = error.message; return false }
    finally { if (!quiet) { room.sending = false; draw() } }
  }
  const draw = () => {
    // Keep the caret stable while messages arrive. Drafts survive other redraws.
    if (root.contains(document.activeElement) && document.activeElement?.matches('textarea')) return
    root.replaceChildren()
    const intro = el('div', 'document-tool-intro with-action')
    const copy = el('div')
    copy.append(el('h3', '', 'Book room'), el('p', '', 'Discuss work with people connected to this MoonDesk workspace. Messages and replies stay with the book.'))
    intro.append(copy, button('Refresh', load))
    root.append(intro)
    const identity = el('label', 'workspace-room-profile')
    identity.append(el('span', '', 'Your display name'))
    const name = el('input'); name.value = room.profile.name; name.placeholder = 'Your name'
    name.addEventListener('change', () => {
      room.profile.name = name.value
      try { localStorage.setItem(profileKey, JSON.stringify(room.profile)) } catch {}
      void send('presence', { typing: false }, true)
    })
    identity.append(name); root.append(identity)
    const channelRow = el('div', 'workspace-room-channels')
    const channels = room.payload.channels.length ? room.payload.channels : [{ id: 'general', title: 'General' }]
    for (const channel of channels) {
      const tab = button(channel.title, () => {
        room.channel = channel.id; room.reply = ''; room.payload = { ...room.payload, messages: [], presence: [] }; draw(); void load()
      })
      tab.setAttribute('aria-pressed', String(room.channel === channel.id)); channelRow.append(tab)
    }
    const channelForm = el('form', 'workspace-room-new-channel')
    const channelName = el('input'); channelName.placeholder = 'New channel'; channelName.setAttribute('aria-label', 'New channel name'); channelName.required = true
    const create = el('button', 'secondary-button', 'Create channel'); create.type = 'submit'
    channelForm.append(channelName, create)
    channelForm.addEventListener('submit', event => { event.preventDefault(); void send('create-channel', { title: channelName.value }) })
    root.append(channelRow, channelForm)
    const others = room.payload.presence.filter(person => person.actor_id !== room.profile.id)
    const presence = el('p', 'status-line', others.length ? others.map(person => `${person.author}${person.typing ? ' is typing…' : ' is here'}`).join(' · ') : 'You are the first person here.')
    presence.setAttribute('aria-live', 'polite'); root.append(presence)
    const messages = el('div', 'workspace-room-messages')
    messages.setAttribute('role', 'log'); messages.setAttribute('aria-label', 'Room messages')
    const renderMessage = (message, reply = false) => {
      const row = el('article', `workspace-room-message${reply ? ' reply' : ''}`)
      row.append(el('strong', '', message.author), el('p', '', message.text))
      const date = new Date(/^\d+$/.test(String(message.created_at)) ? Number(message.created_at) : message.created_at)
      if (Number.isFinite(date.getTime())) row.append(el('small', '', date.toLocaleString()))
      if (message.document_path) row.append(button(`Open ${message.document_path}`, () => options.openFile?.(message.document_path)))
      const counts = reactionCounts(message)
      const actions = el('div', 'workspace-room-message-actions')
      for (const [id, label] of [['agree', 'Agree'], ['thanks', 'Thanks'], ['question', 'Question']]) {
        const reaction = button(`${label}${counts[id] ? ` ${counts[id]}` : ''}`, () => send('react', { message_id: message.id, reaction: id }))
        reaction.setAttribute('aria-pressed', String((message.reactions || []).some(item => item.actor_id === room.profile.id && item.reaction === id)))
        actions.append(reaction)
      }
      if (!reply) actions.append(button('Reply', () => { room.reply = message.id; draw(); root.querySelector('textarea')?.focus() }))
      actions.append(button('Add to task', () => globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'discussion', label: `${message.author} in ${channels.find(item => item.id === room.channel)?.title || 'Book room'}`, text: message.text, path: message.document_path || '', workspaceId } }))))
      row.append(actions)
      return row
    }
    for (const message of roomMessages(room.payload.messages)) {
      messages.append(renderMessage(message))
      for (const reply of roomMessages(room.payload.messages, message.id)) messages.append(renderMessage(reply, true))
    }
    if (!room.payload.messages.length) messages.append(el('p', 'document-tool-empty', 'Start with a question, a decision, or an update for your collaborators.'))
    root.append(messages)
    const composer = el('form', 'workspace-room-composer')
    if (room.reply) {
      const parent = room.payload.messages.find(item => item.id === room.reply)
      composer.append(el('p', '', `Replying to ${parent?.author || 'discussion'}: ${(parent?.text || '').slice(0, 100)}`), button('Cancel reply', () => { room.reply = ''; draw() }))
    }
    const draftKey = `${room.channel}:${room.reply}`
    const draft = room.drafts.get(draftKey) || { text: '', client_id: `message-${globalThis.crypto?.randomUUID?.() || Date.now()}` }
    room.drafts.set(draftKey, draft)
    const text = el('textarea'); text.required = true; text.value = draft.text; text.setAttribute('aria-label', room.reply ? 'Write a reply' : 'Write a message'); text.placeholder = room.reply ? 'Write a reply…' : 'Share an update or ask a question…'
    text.addEventListener('input', () => {
      draft.text = text.value
      if (Date.now() - room.typingAt > 5000) { room.typingAt = Date.now(); void send('presence', { typing: Boolean(text.value.trim()) }, true) }
    })
    text.addEventListener('blur', () => setTimeout(draw, 100))
    composer.append(text)
    if (state.selected_document) {
      const attach = el('label')
      const checkbox = el('input'); checkbox.type = 'checkbox'; checkbox.checked = room.attach
      checkbox.addEventListener('change', () => { room.attach = checkbox.checked })
      attach.append(checkbox, document.createTextNode(` Attach ${state.selected_document}`)); composer.append(attach)
    }
    const submit = el('button', 'primary-button', room.sending ? 'Sending…' : 'Send message'); submit.type = 'submit'; submit.disabled = room.sending || !workspaceId
    composer.append(submit)
    composer.addEventListener('submit', async event => {
      event.preventDefault()
      const text = draft.text.trim()
      if (!text) return
      const replyTo = room.reply
      const saved = await send('message', { text, client_id: draft.client_id, reply_to: replyTo, document_path: room.attach ? state.selected_document || '' : '' })
      if (saved && room.drafts.get(draftKey)?.text.trim() === text) { room.drafts.delete(draftKey); if (room.reply === replyTo) room.reply = ''; draw() }
    })
    root.append(composer)
    const error = el('p', 'status-line', room.error); error.setAttribute('role', 'status'); root.append(error)
  }
  draw()
  void load()
  clearInterval(refreshTimer)
  refreshTimer = setInterval(() => {
    if (!root.isConnected || activeRoom?.root !== root || document.visibilityState === 'hidden') return
    void load()
    if (room.profile.name.trim()) void send('presence', { typing: Date.now() - room.typingAt < 8000 }, true)
  }, 5000)
  return root
}

export { renderWorkspaceRoom, roomMessages, reactionCounts }
