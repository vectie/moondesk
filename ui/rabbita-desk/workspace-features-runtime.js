const rootSelector = '[data-testid="workspace-feature-overlays"]'
let serverState = {}
let lastThreadPersistenceFingerprint = ''
let lastHistoryPersistenceFingerprint = ''
const restoredDocumentKeys = new Set()
const serverThreadsByWorkspace = new Map()
const serverThreadLoads = new Set()
const pendingConversationWrites = new Map()
let pendingConversationWriteTimer = 0
const chatEnhancementSignatures = new WeakMap()
let livingArtifactRuntime = null
let livingArtifactRuntimePromise = null
let disposeLivingArtifactBridge = null
const featureState = {
  search_open: false,
  purpose: 'open',
  mode: 'files',
  query: '',
  synthesis_open: false,
  synthesis_title: 'New synthesis',
  synthesis_status: '',
  synthesis: [],
  export_status: '',
  toolbox_open: false,
  toolbox_tab: 'review',
  active_anchor: null,
  selection_toolbar: null,
  thread_status: '',
  queued_followups: [],
  followup_identity: '',
  followup_loaded_for: '',
  followup_revision: 0,
  followup_save_timer: 0,
  followup_save_inflight: false,
  followup_save_dirty: false,
  last_task_busy: null,
  suppress_followup_auto_once: false,
  background_results_identity: '',
  background_results_timer: 0,
  background_result_ids: new Set(),
  preferences: [],
  preferences_loaded_for: '',
  preferences_status: '',
  preference_draft: null,
  learning_proposals: [],
  learning_loaded_for: '',
  learning_status: '',
  learning_draft: null,
  task_recipes: [],
  task_recipes_loaded: false,
  task_recipe_selected: '',
  task_recipe_status: '',
  source_subscriptions: [],
  source_subscriptions_loaded_for: '',
  source_subscription_status: '',
  source_subscription_draft: null,
  living_artifacts: [],
  living_artifacts_loaded_for: '',
  living_artifact_status: '',
  living_artifact_draft: null,
  review_threads: [],
  review_counts: { open: 0, unread: 0, required: 0, pinned: 0 },
  review_participants: [],
  review_threads_loaded_for: '',
  review_thread_status: '',
  dismissed_fragments: new Set(),
  pending_source_location: null,
  history_status: '',
  compare_left: '',
  compare_right: '',
  compare_filter: 'all',
  reviewed_markers: new Set(),
}

const storageKeys = {
  threads: 'moondesk.document-threads.v1',
  history: 'moondesk.document-history.v1',
  packs: 'moondesk.check-packs.v1',
  reviewed: 'moondesk.reviewed-markers.v1',
  followups: 'moondesk.queued-followups.v1',
  reviewViewer: 'moondesk.review-viewer.v1',
}

const checkPacks = [
  {
    id: 'document-quality',
    title: 'Document quality',
    description: 'Check clarity, contradictions, missing context, and unsupported claims.',
    reads: 'The selected document and explicitly attached sources',
    warns: 'Only when a material issue needs your decision',
    prompt: 'Check this document for clarity, contradictions, missing context, and unsupported claims. Suggest focused improvements and interrupt me only for material warnings.',
  },
  {
    id: 'spreadsheet-consistency',
    title: 'Spreadsheet consistency',
    description: 'Check formulas, outliers, inconsistent labels, and incomplete ranges.',
    reads: 'The selected spreadsheet and its formulas',
    warns: 'Broken formulas, material outliers, or ambiguous assumptions',
    prompt: 'Check this spreadsheet for formula consistency, outliers, inconsistent labels, and incomplete ranges. Preserve valid formulas and report only actionable warnings.',
  },
  {
    id: 'citation-audit',
    title: 'Citation audit',
    description: 'Trace important claims to workspace or web evidence.',
    reads: 'The selected document, attached workspace sources, and approved web search',
    warns: 'Important claims without adequate support',
    prompt: 'Audit the important claims in this document. Trace each material claim to workspace or web evidence, distinguish fact from inference, and return a concise citation report.',
  },
  {
    id: 'presentation-polish',
    title: 'Presentation polish',
    description: 'Check narrative flow, slide density, repetition, and executive readability.',
    reads: 'The selected presentation and its visible slide content',
    warns: 'Only structural problems that weaken the presentation',
    prompt: 'Review this presentation for narrative flow, slide density, repetition, and executive readability. Propose a concise improvement plan and only surface material warnings.',
  },
]

const ReviewPackageMaxConversationEntries = 80
const ReviewPackageEntryMaxChars = 48_000

function isLivingArtifactPath(path) {
  return /^book\/site\/generated\/living\/[^/]+\/index\.html$/.test(String(path || ''))
}

function ensureLivingArtifactRuntime() {
  if (livingArtifactRuntimePromise) return livingArtifactRuntimePromise
  livingArtifactRuntimePromise = import('./living-artifacts-runtime.js')
    .then(module => {
      livingArtifactRuntime = module
      disposeLivingArtifactBridge?.()
      disposeLivingArtifactBridge = module.installLivingArtifactBridge({
        getState: () => ({
          workspaceId: String(serverState.workspace_id || ''),
          selectedPath: String(serverState.selected_document || ''),
        }),
        onSaved: artifact => {
          featureState.living_artifacts = module.livingArtifactTransition(
            featureState.living_artifacts,
            artifact,
          )
          featureState.living_artifact_status = 'Saved in this MoonBook'
          render()
        },
        onError: () => {
          featureState.living_artifact_status = 'This artifact could not be synchronized'
          render()
        },
      })
      render()
      return module
    })
    .catch(error => {
      livingArtifactRuntimePromise = null
      featureState.living_artifact_status = 'Living artifacts could not be loaded'
      console.error(error)
      render()
      throw error
    })
  return livingArtifactRuntimePromise
}

function readStored(key, fallback) {
  try {
    const value = JSON.parse(globalThis.localStorage?.getItem(key) || 'null')
    return value ?? fallback
  } catch {
    return fallback
  }
}

function writeStored(key, value) {
  try {
    globalThis.localStorage?.setItem(key, JSON.stringify(value))
  } catch {
    // Persistence is an enhancement. The live document workflow remains usable.
  }
}

function reviewViewerId() {
  const existing = String(readStored(storageKeys.reviewViewer, '') || '').trim()
  if (existing) return existing
  const value = `viewer-${globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`}`
  writeStored(storageKeys.reviewViewer, value)
  return value
}

function boundedText(value, limit = 2400) {
  const text = String(value || '').replace(/\s+/g, ' ').trim()
  return text.length <= limit ? text : `${text.slice(0, limit - 1)}…`
}

function learningProposalTransition(records, updated) {
  if (!updated?.id) return records
  return [updated, ...records.filter(item => item.id !== updated.id)]
}

function learningProposalCounts(records) {
  return records.reduce((counts, item) => ({
    ...counts,
    [item.status]: (counts[item.status] || 0) + 1,
  }), { proposed: 0, accepted: 0, rejected: 0 })
}

function taskRecipeMissingFields(recipe, inputs) {
  return (recipe?.fields || [])
    .filter(field => field.required === true && !String(inputs?.[field.key] || '').trim())
    .map(field => field.key)
}

function sourceSubscriptionTransition(records, updated) {
  if (!updated?.id) return records
  return [updated, ...records.filter(item => item.id !== updated.id)]
}

function sourceSubscriptionCounts(records) {
  return records.reduce((counts, item) => ({
    ...counts,
    [item.status]: (counts[item.status] || 0) + 1,
  }), { active: 0, needs_setup: 0 })
}

function shouldRestoreDocumentThread(taskId, chatCount, alreadyHandled) {
  return !String(taskId || '').trim() && Number(chatCount) === 0 && alreadyHandled !== true
}

function reviewRoomProjection(records, suppliedParticipants = []) {
  const threads = records.filter(item => item.kind === 'thread')
  const participants = []
  for (const value of [
    ...suppliedParticipants,
    ...records.flatMap(item => [item.author, item.assigned_to]),
  ]) {
    const participant = String(value || '').trim()
    if (participant && !participants.includes(participant)) participants.push(participant)
  }
  return {
    participants,
    threads: [
      ...threads.filter(item => item.pinned === true),
      ...threads.filter(item => item.pinned !== true),
    ],
  }
}

function reviewPackageFromState(state, records, evidence, preparedAt) {
  const room = reviewRoomProjection(records)
  const replies = records.filter(item => item.kind === 'reply')
  return {
    contract: 'moondesk.review-package.v1',
    title: `${state.workspace || 'MoonDesk workspace'} — Review Package`,
    workspace: state.workspace || 'MoonDesk workspace',
    document: state.selected_document || '',
    prepared_at: preparedAt,
    conversation: (state.chat || [])
      .filter(entry => entry.role === 'user' || entry.role === 'assistant')
      .slice(-ReviewPackageMaxConversationEntries)
      .map(entry => ({
        role: entry.role,
        content: String(entry.content || '').slice(0, ReviewPackageEntryMaxChars),
      })),
    discussions: room.threads.map(thread => ({
      id: thread.id,
      anchor: thread.anchor_label || 'Document',
      detail: boundedText(thread.detail, ReviewPackageEntryMaxChars),
      assigned_to: thread.assigned_to || '',
      status: thread.status || 'open',
      pinned: thread.pinned === true,
      replies: replies
        .filter(reply => reply.thread_id === thread.id)
        .map(reply => ({
          author: reply.author || 'Reply',
          detail: boundedText(reply.detail, ReviewPackageEntryMaxChars),
        })),
    })),
    evidence: (evidence || []).map(item => ({
      label: boundedText(item.label, 240),
      type: item.type || 'source',
      value: boundedText(item.value, 4_096),
    })),
  }
}

function htmlEscape(value) {
  return String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character])
}

function reviewPackageHtml(data) {
  const discussion = item => `<article class="discussion${item.pinned ? ' pinned' : ''}"><div class="discussion-heading"><strong>${htmlEscape(item.anchor)}</strong><span>${item.pinned ? 'Pinned decision' : htmlEscape(item.status)}</span></div><p>${htmlEscape(item.detail)}</p><div class="meta">${item.assigned_to ? `Assigned to ${htmlEscape(item.assigned_to)} · ` : ''}${htmlEscape(item.status)}</div>${(item.replies || []).map(reply => `<blockquote><strong>${htmlEscape(reply.author)}</strong><br>${htmlEscape(reply.detail)}</blockquote>`).join('')}</article>`
  const section = (title, rows, renderRow) => rows?.length
    ? `<section><h2>${htmlEscape(title)}</h2>${rows.map(renderRow).join('')}</section>`
    : ''
  return `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${htmlEscape(data.title)}</title><style>
body{font:15px/1.55 Inter,system-ui,sans-serif;max-width:900px;margin:0 auto;padding:46px 26px;color:#1f2937;background:#fff}header{border-bottom:2px solid #dbe4ee;padding-bottom:20px;margin-bottom:28px}h1{font-size:28px;margin:0 0 8px}h2{font-size:18px;margin-top:32px}.meta{color:#667085;font-size:12px}.discussion,.message,.evidence{padding:12px;border:1px solid #e0e7ef;border-radius:9px;margin:8px 0}.discussion.pinned{border-color:#8baacb;background:#f5f9fe}.discussion-heading{display:flex;justify-content:space-between;gap:12px}.discussion-heading span{color:#58708a;font-size:11px;font-weight:700}blockquote{margin:10px 0 0 18px;padding-left:10px;border-left:2px solid #cbd8e6}.user{background:#f3f7fd}@media print{body{padding:18px}}</style></head><body>
<header><div class="meta">MoonDesk Review Package · ${htmlEscape(data.contract)} · ${htmlEscape(data.prepared_at)}</div><h1>${htmlEscape(data.title)}</h1><div class="meta">Document: ${htmlEscape(data.document || 'Workspace')}</div><p>Review the pinned decisions and open discussions. Return comments with the document anchor and discussion wording so they can be resolved in the MoonDesk Review Room.</p></header>
${section('Pinned decisions', data.discussions?.filter(item => item.pinned), discussion)}
${section('Open discussions', data.discussions?.filter(item => !item.pinned), discussion)}
${section('Conversation excerpt', data.conversation, item => `<article class="message ${item.role === 'user' ? 'user' : ''}"><strong>${item.role === 'user' ? 'You' : 'MoonDesk'}</strong><p>${htmlEscape(item.content).replace(/\n/g, '<br>')}</p></article>`)}
${section('Evidence', data.evidence, item => `<div class="evidence"><strong>${htmlEscape(item.label)}</strong><div class="meta">${htmlEscape(item.type)} · ${htmlEscape(item.value)}</div></div>`)}
</body></html>`
}

function downloadReviewPackage() {
  const data = reviewPackageFromState(
    serverState,
    featureState.review_threads,
    sourceEntries(serverState),
    new Date().toISOString(),
  )
  const blob = new Blob([reviewPackageHtml(data)], { type: 'text/html;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  const stem = String(data.workspace || 'moondesk-review').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'moondesk-review'
  link.href = url
  link.download = `${stem}-review-package.html`
  document.body.append(link)
  link.click()
  setTimeout(() => {
    link.remove()
    URL.revokeObjectURL(url)
  }, 1000)
}

function conversationPersistenceFingerprint(taskId, documentPath, status, chat) {
  const last = chat[chat.length - 1] || {}
  const content = String(last.content || '')
  return [
    taskId,
    documentPath,
    status,
    chat.length,
    last.role || '',
    content.length,
    content.slice(0, 32),
    content.slice(-64),
  ].join('|')
}

function chatProjectionFingerprint(state) {
  return [
    state.task_id || '',
    Number(state.chat_count) || 0,
    state.chat_revision || '',
    state.chat_tail_role || '',
    Number(state.chat_tail_bytes) || 0,
  ].join('|')
}

function chatEntryFromNode(node) {
  if (!(node instanceof HTMLElement)) return null
  if (node.classList.contains('wiki-chat-fragment')) {
    const role = String(node.dataset.kind || '').trim()
    const content = String(node.dataset.payload || '')
    return role && content ? { role, content } : null
  }
  if (!node.classList.contains('wiki-chat-message')) return null
  const role = String(node.dataset.chatRole || '').trim()
  const content = node.querySelector(':scope > p')?.textContent || ''
  return role && content.trim() ? { role, content } : null
}

function projectChatFromDom(state, previousChat = [], previousFingerprint = '') {
  const fingerprint = chatProjectionFingerprint(state)
  if (fingerprint === previousFingerprint) return previousChat
  const thread = document.querySelector('[data-testid="wiki-chat-thread"]')
  if (!(thread instanceof HTMLElement)) return previousChat
  const nodes = Array.from(thread.children).filter(node =>
    node.classList?.contains('wiki-chat-message') ||
    node.classList?.contains('wiki-chat-fragment'))
  const expectedCount = Math.max(0, Number(state.chat_count) || 0)
  if (expectedCount === previousChat.length && nodes.length === expectedCount && expectedCount > 0) {
    const tail = chatEntryFromNode(nodes.at(-1))
    return tail ? [...previousChat.slice(0, -1), tail] : previousChat
  }
  return nodes.map(chatEntryFromNode).filter(Boolean)
}

function typedSourceEntries(chat) {
  const sources = []
  for (const [messageIndex, entry] of (chat || []).entries()) {
    if (entry.role !== 'source_ref' && entry.role !== 'artifact_ref') continue
    try {
      const value = JSON.parse(String(entry.content || ''))
      const path = String(value.workspace_path || value.path || '')
      if (!path) continue
      sources.push({
        type: entry.role === 'artifact_ref' ? 'artifact' : 'workspace',
        label: String(value.label || path.split('/').pop() || 'Source'),
        value: path,
        location: entry.role === 'source_ref' ? value : null,
        message_index: messageIndex,
      })
    } catch {}
  }
  return sources
}

function typedLocationLabel(value) {
  const details = []
  if (Number(value?.page) > 0) details.push(`page ${Number(value.page)}`)
  if (Number(value?.slide) > 0) details.push(`slide ${Number(value.slide)}`)
  if (value?.sheet) details.push(String(value.sheet))
  if (value?.cell_range) details.push(String(value.cell_range))
  if (value?.section) details.push(String(value.section))
  return details.join(' · ')
}

function documentKey(state = serverState) {
  return `${state.workspace_id || 'workspace'}::${state.selected_document || 'workspace'}`
}

function currentThreads() {
  const workspaceId = serverState.workspace_id || 'workspace'
  if (serverThreadsByWorkspace.has(workspaceId)) {
    return serverThreadsByWorkspace.get(workspaceId)
  }
  const all = readStored(storageKeys.threads, {})
  return Array.isArray(all[workspaceId]) ? all[workspaceId] : []
}

function normalizeServerThread(record) {
  return {
    id: String(record.conversation_id || record.id || ''),
    title: String(record.title || 'Document conversation'),
    document: String(record.document_path || ''),
    baseline: String(record.document_baseline || ''),
    updated_at: Date.parse(record.updated_at || '') || Number(record.updated_at) || Date.now(),
    status: String(record.status || 'ready'),
    archived: Boolean(record.archived),
    revision: Number(record.revision) || 0,
    chat: Array.isArray(record.entries) ? record.entries : [],
  }
}

function loadServerThreads() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  if (!workspaceId || serverThreadLoads.has(workspaceId)) return
  serverThreadLoads.add(workspaceId)
  fetch(`/api/document-conversations?workspace_id=${encodeURIComponent(workspaceId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('conversation load failed')))
    .then(payload => {
      const records = Array.isArray(payload.conversations)
        ? payload.conversations.map(normalizeServerThread).filter(thread => thread.id)
        : []
      serverThreadsByWorkspace.set(workspaceId, records)
      if (serverState.workspace_id === workspaceId) {
        restoredDocumentKeys.delete(documentKey())
        render()
      }
    })
    .catch(() => {
      // Keep the bounded browser cache as an offline recovery copy.
      serverThreadLoads.delete(workspaceId)
    })
}

function queueServerConversationWrite(record) {
  const key = `${record.workspace_id}::${record.conversation_id}`
  pendingConversationWrites.set(key, record)
  globalThis.clearTimeout(pendingConversationWriteTimer)
  pendingConversationWriteTimer = globalThis.setTimeout(() => {
    const writes = Array.from(pendingConversationWrites.values())
    pendingConversationWrites.clear()
    for (const next of writes) {
      fetch('/api/document-conversations', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify(next),
      }).then(async response => {
        if (response.status === 409) {
          serverThreadLoads.delete(next.workspace_id)
          loadServerThreads()
          return
        }
        if (!response.ok) throw new Error('conversation save failed')
        const saved = normalizeServerThread(await response.json())
        const threads = serverThreadsByWorkspace.get(next.workspace_id) || []
        serverThreadsByWorkspace.set(next.workspace_id, [
          saved,
          ...threads.filter(thread => thread.id !== saved.id),
        ])
      }).catch(() => {})
    }
  }, 500)
}

function serverConversationRecord(thread, action = 'upsert') {
  return {
    action,
    workspace_id: serverState.workspace_id || '',
    conversation_id: thread.id,
    document_path: thread.document || '',
    document_baseline: thread.baseline || serverState.office?.baseline || '',
    title: thread.title || 'Document conversation',
    status: thread.status || 'ready',
    archived: Boolean(thread.archived),
    expected_revision: Number(thread.revision) || 0,
    entries: (thread.chat || []).slice(-240).map(entry => ({
      role: String(entry.role || ''),
      content: String(entry.content || '').slice(0, 240000),
    })),
  }
}

function enabledPackIds() {
  const stored = readStored(storageKeys.packs, {})
  if (Array.isArray(stored)) return new Set(stored)
  return new Set(stored[serverState.workspace_id || 'workspace'] || [])
}

function queuedFollowupKey() {
  return `${serverState.workspace_id || 'workspace'}::${serverState.task_id || 'new'}`
}

function loadQueuedFollowups() {
  const stored = readStored(storageKeys.followups, {})
  featureState.queued_followups = Array.isArray(stored[queuedFollowupKey()])
    ? stored[queuedFollowupKey()]
    : []
  featureState.followup_revision = 0
  const workspaceId = String(serverState.workspace_id || '').trim()
  const conversationId = String(serverState.task_id || '').trim()
  const identity = `${workspaceId}::${conversationId}`
  if (!workspaceId || !conversationId || featureState.followup_loaded_for === identity) return
  featureState.followup_loaded_for = identity
  fetch(`/api/document-followups?workspace_id=${encodeURIComponent(workspaceId)}&conversation_id=${encodeURIComponent(conversationId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('follow-up load failed')))
    .then(queue => {
      if (`${serverState.workspace_id || ''}::${serverState.task_id || ''}` !== identity) return
      const remote = Array.isArray(queue.items) ? queue.items.map(item => ({
        id: String(item.id || ''),
        text: String(item.text || ''),
        state: String(item.state || 'draft'),
        created_at: String(item.created_at || ''),
      })).filter(item => item.id && item.text) : []
      featureState.followup_revision = Number(queue.revision) || 0
      if (remote.length) {
        featureState.queued_followups = remote
        const all = readStored(storageKeys.followups, {})
        all[queuedFollowupKey()] = remote
        writeStored(storageKeys.followups, all)
      } else if (featureState.queued_followups.length) {
        scheduleServerFollowupSave()
      }
      render()
    })
    .catch(() => {
      featureState.followup_loaded_for = ''
      featureState.thread_status = 'Follow-ups are available offline; sync will retry.'
      render()
    })
}

function loadDocumentAutomationResults() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  const conversationId = String(serverState.task_id || '').trim()
  const identity = `${workspaceId}::${conversationId}`
  globalThis.clearTimeout(featureState.background_results_timer)
  if (!workspaceId || !conversationId || featureState.background_results_identity !== identity) return
  fetch(`/api/document-automation-results?workspace_id=${encodeURIComponent(workspaceId)}&conversation_id=${encodeURIComponent(conversationId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('background result load failed')))
    .then(payload => {
      if (`${serverState.workspace_id || ''}::${serverState.task_id || ''}` !== identity) return
      const unseen = (Array.isArray(payload.results) ? payload.results : []).filter(result => {
        const id = String(result.id || '')
        if (!id || featureState.background_result_ids.has(id)) return false
        featureState.background_result_ids.add(id)
        return true
      })
      if (unseen.length) forward('append-background-results', JSON.stringify(unseen))
    })
    .catch(() => {})
    .finally(() => {
      if (featureState.background_results_identity === identity) {
        featureState.background_results_timer = globalThis.setTimeout(loadDocumentAutomationResults, 15000)
      }
    })
}

function saveQueuedFollowups() {
  const stored = readStored(storageKeys.followups, {})
  stored[queuedFollowupKey()] = featureState.queued_followups
  writeStored(storageKeys.followups, stored)
  scheduleServerFollowupSave()
}

function scheduleServerFollowupSave() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  const conversationId = String(serverState.task_id || '').trim()
  if (!workspaceId || !conversationId) return
  featureState.followup_save_dirty = true
  globalThis.clearTimeout(featureState.followup_save_timer)
  featureState.followup_save_timer = globalThis.setTimeout(flushServerFollowupSave, 120)
}

function mergeFollowupQueues(remote, local) {
  const localById = new Map(local.map(item => [item.id, item]))
  const merged = remote.map(item => localById.get(item.id) || item)
  const remoteIds = new Set(remote.map(item => item.id))
  merged.push(...local.filter(item => !remoteIds.has(item.id)))
  return merged.slice(0, 64)
}

function flushServerFollowupSave() {
  if (featureState.followup_save_inflight || !featureState.followup_save_dirty) return
  const workspaceId = String(serverState.workspace_id || '').trim()
  const conversationId = String(serverState.task_id || '').trim()
  if (!workspaceId || !conversationId) return
  const identity = `${workspaceId}::${conversationId}`
  featureState.followup_save_dirty = false
  featureState.followup_save_inflight = true
  const items = featureState.queued_followups.map(item => ({
    id: item.id,
    text: item.text,
    state: item.state || 'draft',
    created_at: item.created_at || '',
  }))
  fetch('/api/document-followups', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      workspace_id: workspaceId,
      conversation_id: conversationId,
      task_id: conversationId,
      expected_revision: featureState.followup_revision,
      items,
    }),
  }).then(async response => {
    const payload = await response.json().catch(() => ({}))
    if (response.status === 409 && payload.queue) {
      if (`${serverState.workspace_id || ''}::${serverState.task_id || ''}` === identity) {
        const remote = Array.isArray(payload.queue.items) ? payload.queue.items : []
        featureState.queued_followups = mergeFollowupQueues(remote, featureState.queued_followups)
        featureState.followup_revision = Number(payload.queue.revision) || 0
        featureState.followup_save_dirty = true
        featureState.thread_status = 'Follow-ups changed elsewhere; MoonDesk merged the independent drafts.'
      }
      return
    }
    if (!response.ok) throw new Error('follow-up save failed')
    if (`${serverState.workspace_id || ''}::${serverState.task_id || ''}` === identity) {
      featureState.followup_revision = Number(payload.revision) || featureState.followup_revision
    }
  }).catch(() => {
    featureState.followup_save_dirty = true
    featureState.thread_status = 'Follow-up sync will retry.'
  }).finally(() => {
    featureState.followup_save_inflight = false
    if (featureState.followup_save_dirty) {
      featureState.followup_save_timer = globalThis.setTimeout(flushServerFollowupSave, 250)
    }
    render()
  })
}

function loadAgentPreferences() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  if (!workspaceId || featureState.preferences_loaded_for === workspaceId) return
  featureState.preferences_loaded_for = workspaceId
  fetch(`/api/preferences/agent-memory?workspace_id=${encodeURIComponent(workspaceId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.preferences = Array.isArray(payload.preferences) ? payload.preferences : []
      featureState.preferences_status = ''
      render()
    })
    .catch(() => {
      featureState.preferences_loaded_for = ''
      featureState.preferences_status = 'Preferences could not be loaded'
      render()
    })
}

function saveAgentPreference(record) {
  featureState.preferences_status = 'Saving…'
  const existing = featureState.preferences.find(item => item.id && item.id === record.id)
  fetch('/api/preferences/agent-memory', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      workspace_id: serverState.workspace_id || '',
      expected_revision: Number(existing?.revision) || 0,
      ...record,
    }),
  })
    .then(async response => {
      const payload = await response.json().catch(() => ({}))
      if (response.status === 409 && payload.preference) {
        featureState.preferences = [
          payload.preference,
          ...featureState.preferences.filter(item => item.id !== payload.preference.id),
        ]
        featureState.preference_draft = { ...payload.preference }
        featureState.preferences_status = 'This preference changed elsewhere. Review the latest version before saving.'
        render()
        return null
      }
      if (!response.ok) throw new Error('save failed')
      return payload
    })
    .then(saved => {
      if (!saved) return
      if (saved.forgotten) {
        featureState.preferences = featureState.preferences.filter(item => item.id !== saved.id)
      } else {
        featureState.preferences = [saved, ...featureState.preferences.filter(item => item.id !== saved.id)]
      }
      featureState.preferences_status = 'Saved'
      featureState.preference_draft = null
      render()
    })
    .catch(() => {
      featureState.preferences_status = 'Preference could not be saved'
      render()
    })
}

function loadLearningProposals() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  if (!workspaceId) {
    featureState.learning_proposals = []
    featureState.learning_loaded_for = ''
    return
  }
  if (featureState.learning_loaded_for === workspaceId) return
  featureState.learning_proposals = []
  featureState.learning_loaded_for = workspaceId
  fetch(`/api/learning-proposals?workspace_id=${encodeURIComponent(workspaceId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.learning_proposals = Array.isArray(payload.proposals) ? payload.proposals : []
      featureState.learning_status = ''
      render()
    })
    .catch(() => {
      featureState.learning_loaded_for = ''
      featureState.learning_status = 'Learning Review could not be loaded'
      render()
    })
}

function saveLearningProposal(record) {
  featureState.learning_status = record.action === 'propose' ? 'Saving proposal…' : 'Saving decision…'
  fetch('/api/learning-proposals', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ workspace_id: serverState.workspace_id || '', ...record }),
  })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('save failed')))
    .then(saved => {
      featureState.learning_proposals = learningProposalTransition(featureState.learning_proposals, saved)
      featureState.learning_draft = null
      featureState.learning_status = saved.status === 'accepted'
        ? 'Learned for future work in this book'
        : saved.status === 'rejected'
          ? 'Proposal dismissed'
          : 'Waiting for your review'
      render()
    })
    .catch(() => {
      featureState.learning_status = 'Learning proposal could not be saved'
      render()
    })
}

function loadTaskRecipes() {
  if (featureState.task_recipes_loaded) return
  featureState.task_recipes_loaded = true
  featureState.task_recipe_status = 'Loading tasks…'
  fetch('/api/task-recipes')
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.task_recipes = Array.isArray(payload.recipes) ? payload.recipes : []
      featureState.task_recipe_status = ''
      render()
    })
    .catch(() => {
      featureState.task_recipes_loaded = false
      featureState.task_recipe_status = 'Task recipes could not be loaded'
      render()
    })
}

function startTaskRecipe(recipeId, inputs) {
  const recipe = featureState.task_recipes.find(item => item.recipe_id === recipeId)
  const missing = taskRecipeMissingFields(recipe, inputs)
  if (missing.length) {
    featureState.task_recipe_status = 'Complete the required fields'
    render()
    return
  }
  featureState.task_recipe_status = 'Preparing your task…'
  fetch('/api/task-recipes', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      workspace_id: serverState.workspace_id || '',
      recipe_id: recipeId,
      inputs,
    }),
  })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('start failed')))
    .then(instance => {
      featureState.task_recipe_status = 'Starting in chat…'
      featureState.toolbox_open = false
      featureState.task_recipe_selected = ''
      forward('start-recipe', instance.prompt || '')
      render()
    })
    .catch(() => {
      featureState.task_recipe_status = 'This task could not be prepared'
      render()
    })
}

function loadSourceSubscriptions() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  if (!workspaceId) {
    featureState.source_subscriptions = []
    featureState.source_subscriptions_loaded_for = ''
    return
  }
  if (featureState.source_subscriptions_loaded_for === workspaceId) return
  featureState.source_subscriptions = []
  featureState.source_subscriptions_loaded_for = workspaceId
  fetch(`/api/source-subscriptions?workspace_id=${encodeURIComponent(workspaceId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.source_subscriptions = Array.isArray(payload.subscriptions)
        ? payload.subscriptions
        : []
      featureState.source_subscription_status = ''
      render()
    })
    .catch(() => {
      featureState.source_subscriptions_loaded_for = ''
      featureState.source_subscription_status = 'Subscriptions could not be loaded'
      render()
    })
}

function saveSourceSubscription(record) {
  featureState.source_subscription_status = 'Saving source…'
  fetch('/api/source-subscriptions', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({ workspace_id: serverState.workspace_id || '', ...record }),
  })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('save failed')))
    .then(saved => {
      featureState.source_subscriptions = sourceSubscriptionTransition(
        featureState.source_subscriptions,
        saved,
      )
      featureState.source_subscription_draft = null
      featureState.source_subscription_status = 'Source saved. Setting up background work…'
      render()
      setupSourceSubscription(saved)
    })
    .catch(() => {
      featureState.source_subscription_status = 'This source could not be saved'
      render()
    })
}

function setupSourceSubscription(record) {
  featureState.source_subscription_status = 'Setting up background work…'
  fetch('/api/town/standing-goals', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      title: record.title || 'Keep source current',
      prompt: record.prompt || '',
      target_book_id: serverState.workspace_id || '',
      cadence_ticks: Number(record.cadence_ticks) || 10080,
      source_policy: record.source_kind === 'folder' ? 'workspace-first' : 'web-first',
      review_policy: 'bookkeeper_review',
      enabled: true,
    }),
  })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('setup failed')))
    .then(goal => {
      const standingGoalId = String(goal.id || goal.standing_goal_id || '').trim()
      if (!standingGoalId) throw new Error('missing standing work identity')
      return fetch('/api/source-subscriptions', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          action: 'activate',
          workspace_id: serverState.workspace_id || '',
          id: record.id,
          standing_goal_id: standingGoalId,
        }),
      })
    })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('link failed')))
    .then(active => {
      featureState.source_subscriptions = sourceSubscriptionTransition(
        featureState.source_subscriptions,
        active,
      )
      featureState.source_subscription_status = 'This source will now be checked in the background'
      render()
    })
    .catch(() => {
      featureState.source_subscription_status = 'Source saved. Background setup needs MoonTown; you can retry here.'
      render()
    })
}

function loadLivingArtifacts() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  if (!workspaceId) {
    featureState.living_artifacts = []
    featureState.living_artifacts_loaded_for = ''
    return
  }
  ensureLivingArtifactRuntime().catch(() => {})
  if (featureState.living_artifacts_loaded_for === workspaceId) return
  featureState.living_artifacts = []
  featureState.living_artifacts_loaded_for = workspaceId
  featureState.living_artifact_status = 'Loading artifacts…'
  fetch(`/api/living-artifacts?workspace_id=${encodeURIComponent(workspaceId)}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.living_artifacts = Array.isArray(payload.artifacts)
        ? payload.artifacts
        : []
      featureState.living_artifact_status = ''
      render()
    })
    .catch(() => {
      featureState.living_artifacts_loaded_for = ''
      featureState.living_artifact_status = 'Living artifacts could not be loaded'
      render()
    })
}

function createLivingArtifact(record) {
  featureState.living_artifact_status = 'Creating artifact…'
  fetch('/api/living-artifacts', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      action: 'create',
      workspace_id: serverState.workspace_id || '',
      ...record,
    }),
  })
    .then(response => response.ok ? response.json() : Promise.reject(new Error('create failed')))
    .then(artifact => {
      featureState.living_artifacts = livingArtifactRuntime
        ? livingArtifactRuntime.livingArtifactTransition(featureState.living_artifacts, artifact)
        : [artifact, ...featureState.living_artifacts.filter(item => item.id !== artifact.id)]
      featureState.living_artifact_draft = null
      featureState.living_artifact_status = 'Artifact created'
      featureState.toolbox_open = false
      forward('open-path', artifact.path || '')
      render()
    })
    .catch(() => {
      featureState.living_artifact_status = 'This artifact could not be created'
      render()
    })
}

function loadDocumentReviewThreads() {
  const workspaceId = String(serverState.workspace_id || '').trim()
  const documentPath = String(serverState.selected_document || '').trim()
  if (!workspaceId || !documentPath) return
  const baseline = String(serverState.office?.baseline || '')
  const key = `${workspaceId}:${documentPath}:${baseline}`
  if (featureState.review_threads_loaded_for === key) return
  featureState.review_threads_loaded_for = key
  fetch(`/api/document-review-threads?workspace_id=${encodeURIComponent(workspaceId)}&document_path=${encodeURIComponent(documentPath)}&baseline=${encodeURIComponent(baseline)}&viewer_id=${encodeURIComponent(reviewViewerId())}`)
    .then(response => response.ok ? response.json() : Promise.reject(new Error('load failed')))
    .then(payload => {
      featureState.review_threads = Array.isArray(payload.threads) ? payload.threads : []
      featureState.review_counts = {
        open: Number(payload.open_count) || 0,
        unread: Number(payload.unread_count) || 0,
        required: Number(payload.required_action_count) || 0,
        pinned: Number(payload.pinned_count) || 0,
      }
      featureState.review_participants = Array.isArray(payload.participants)
        ? payload.participants
        : []
      featureState.review_thread_status = ''
      render()
    })
    .catch(() => {
      featureState.review_threads_loaded_for = ''
      featureState.review_thread_status = 'Review discussions could not be loaded'
      render()
    })
}

function saveDocumentReviewThread(record) {
  featureState.review_thread_status = 'Saving…'
  const parent = featureState.review_threads.find(item => item.kind === 'thread' && item.id === record.thread_id)
  fetch('/api/document-review-threads', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      workspace_id: serverState.workspace_id || '',
      document_path: serverState.selected_document || '',
      document_baseline: serverState.office?.baseline || '',
      author_id: reviewViewerId(),
      expected_revision: Number(parent?.revision) || 0,
      ...record,
    }),
  })
    .then(async response => {
      const payload = await response.json().catch(() => ({}))
      if (response.status === 409) {
        featureState.review_threads_loaded_for = ''
        featureState.review_thread_status = 'This discussion changed elsewhere. MoonDesk loaded the latest version.'
        loadDocumentReviewThreads()
        return null
      }
      if (!response.ok) throw new Error('save failed')
      return payload
    })
    .then(saved => {
      if (!saved) return
      featureState.review_threads_loaded_for = ''
      featureState.review_thread_status = 'Saved'
      loadDocumentReviewThreads()
    })
    .catch(() => {
      featureState.review_thread_status = 'Review discussion could not be saved'
      render()
    })
}

function markDocumentReviewsRead() {
  if (!serverState.workspace_id || !serverState.selected_document) return
  saveDocumentReviewThread({ action: 'mark-read', viewer_id: reviewViewerId() })
}

function queueFollowup(text) {
  const value = String(text || '').trim()
  if (!value) return
  featureState.queued_followups.push({
    id: `followup-${Date.now()}-${featureState.queued_followups.length}`,
    text: value,
    state: 'draft',
    created_at: new Date().toISOString(),
  })
  saveQueuedFollowups()
  forward('set-chat-prompt', '')
  featureState.thread_status = 'Follow-up queued. You can still edit or reorder it.'
  render()
}

function taskIsBusy() {
  const status = String(serverState.request_status || '').toLowerCase()
  return ['sending', 'working', 'generating', 'queued'].some(value => status.includes(value))
}

function shouldAutoSendFollowup(previousBusy, currentBusy, suppressed) {
  return previousBusy === true && currentBusy === false && !suppressed
}

function maybeSendNextFollowup() {
  if (taskIsBusy() || !featureState.queued_followups.length) return
  const next = featureState.queued_followups.find(item => item.state !== 'sending')
  if (!next) return
  next.state = 'sending'
  saveQueuedFollowups()
  globalThis.setTimeout(() => forward('submit-chat-prompt', next.text), 0)
}

function persistEnabledPackIds(enabled) {
  const stored = readStored(storageKeys.packs, {})
  const all = Array.isArray(stored) ? {} : stored
  all[serverState.workspace_id || 'workspace'] = Array.from(enabled)
  writeStored(storageKeys.packs, all)
}

function persistCurrentThread() {
  const taskId = String(serverState.task_id || '').trim()
  const chat = Array.isArray(serverState.chat) ? serverState.chat : []
  if (!taskId || !chat.length) return
  const persistenceFingerprint = conversationPersistenceFingerprint(
    taskId,
    serverState.selected_document || '',
    serverState.request_status || '',
    chat,
  )
  if (persistenceFingerprint === lastThreadPersistenceFingerprint) return
  const all = readStored(storageKeys.threads, {})
  const workspaceId = serverState.workspace_id || 'workspace'
  const threads = Array.isArray(all[workspaceId]) ? all[workspaceId] : []
  const firstUser = chat.find(entry => entry.role === 'user')?.content || 'Document conversation'
  const record = {
    id: taskId,
    title: boundedText(firstUser, 72),
    document: serverState.selected_document || '',
    baseline: serverState.office?.baseline || '',
    updated_at: Date.now(),
    status: serverState.request_status || 'ready',
    archived: false,
    revision: 0,
    chat: chat.slice(-240).map(entry => ({
      role: String(entry.role || ''),
      content: String(entry.content || '').slice(0, 240000),
    })),
  }
  const previous = threads.find(item => item.id === taskId)
  if (previous?.title && previous.title !== 'Document conversation') record.title = previous.title
  if (previous) record.revision = Number(previous.revision) || 0
  all[workspaceId] = [record, ...threads.filter(item => item.id !== taskId)]
    .sort((left, right) => right.updated_at - left.updated_at)
    .slice(0, 24)
  writeStored(storageKeys.threads, all)
  const serverThreads = currentThreads().filter(item => item.id !== taskId)
  serverThreadsByWorkspace.set(workspaceId, [record, ...serverThreads].slice(0, 256))
  queueServerConversationWrite(serverConversationRecord(record))
  lastThreadPersistenceFingerprint = persistenceFingerprint
}

function updateThread(threadId, update) {
  const all = readStored(storageKeys.threads, {})
  const workspaceId = serverState.workspace_id || 'workspace'
  const threads = Array.isArray(all[workspaceId]) ? all[workspaceId] : []
  all[workspaceId] = threads.map(thread => thread.id === threadId
    ? { ...thread, ...update, updated_at: Date.now() }
    : thread)
  writeStored(storageKeys.threads, all)
  const next = currentThreads().map(thread => thread.id === threadId
    ? { ...thread, ...update, updated_at: Date.now() }
    : thread)
  serverThreadsByWorkspace.set(workspaceId, next)
  const changed = next.find(thread => thread.id === threadId)
  if (changed) queueServerConversationWrite(serverConversationRecord(changed))
}

function maybeRestoreCurrentThread() {
  const key = documentKey()
  if (!shouldRestoreDocumentThread(
    serverState.task_id,
    (serverState.chat || []).length,
    restoredDocumentKeys.has(key),
  )) return
  if (!globalThis.__moondeskWorkspaceFeaturesDispatch) return
  restoredDocumentKeys.add(key)
  const thread = currentThreads().find(item =>
    !item.archived && (item.document || '') === (serverState.selected_document || ''))
  if (thread) {
    forward('restore-thread', thread.id, thread.document || '', JSON.stringify(thread.chat || []))
  }
}

function forward(action, first = '', second = '', third = '', fourth = '') {
  globalThis.__moondeskWorkspaceFeaturesDispatch?.(
    String(action),
    String(first),
    String(second),
    String(third),
    String(fourth),
  )
}

function pin(workspaceId, path, title, kind) {
  if (featureState.synthesis.some(item =>
    item.workspace_id === workspaceId && item.path === path)) {
    featureState.synthesis_status = 'Already pinned'
  } else {
    featureState.synthesis.push({
      workspace_id: workspaceId,
      path,
      title,
      kind,
    })
    featureState.synthesis_status = `Pinned ${title}`
  }
  featureState.search_open = false
  featureState.synthesis_open = true
  render()
}

function emit(action, first = '', second = '', third = '', fourth = '') {
  switch (action) {
    case 'close-toolbox':
      featureState.toolbox_open = false
      render()
      return
    case 'toolbox-tab':
      featureState.toolbox_tab = first
      featureState.toolbox_open = true
      if (first === 'preferences') loadAgentPreferences()
      if (first === 'learning') loadLearningProposals()
      if (first === 'tasks') loadTaskRecipes()
      if (first === 'sources') loadSourceSubscriptions()
      if (first === 'artifacts') loadLivingArtifacts()
      if (first === 'review') loadDocumentReviewThreads()
      render()
      return
    case 'new-thread':
      restoredDocumentKeys.add(documentKey())
      featureState.thread_status = 'Started a new document conversation'
      forward('new-thread')
      render()
      return
    case 'restore-thread': {
      const thread = currentThreads().find(item => item.id === first)
      if (!thread) {
        featureState.thread_status = 'That conversation is no longer available'
      } else {
        featureState.thread_status = `Restored ${thread.title}`
        featureState.toolbox_open = false
        forward('restore-thread', thread.id, thread.document || '', JSON.stringify(thread.chat || []))
      }
      render()
      return
    }
    case 'archive-thread':
      updateThread(first, { archived: second !== 'restore' })
      featureState.thread_status = second === 'restore'
        ? 'Conversation restored to the active list'
        : 'Conversation archived'
      render()
      return
    case 'rename-thread':
      updateThread(first, { title: boundedText(second, 72) || 'Document conversation' })
      featureState.thread_status = 'Conversation renamed'
      render()
      return
    case 'followup-edit': {
      const item = featureState.queued_followups.find(entry => entry.id === first)
      if (item) item.text = second
      saveQueuedFollowups()
      return
    }
    case 'followup-delete':
      featureState.queued_followups = featureState.queued_followups.filter(entry => entry.id !== first)
      saveQueuedFollowups()
      render()
      return
    case 'followup-move': {
      const index = featureState.queued_followups.findIndex(entry => entry.id === first)
      const offset = second === 'up' ? -1 : 1
      const target = index + offset
      if (index >= 0 && target >= 0 && target < featureState.queued_followups.length) {
        const [item] = featureState.queued_followups.splice(index, 1)
        featureState.queued_followups.splice(target, 0, item)
        saveQueuedFollowups()
        render()
      }
      return
    }
    case 'followup-send-now': {
      const index = featureState.queued_followups.findIndex(entry => entry.id === first)
      if (index < 0) return
      const item = featureState.queued_followups[index]
      item.state = 'sending'
      saveQueuedFollowups()
      forward('submit-chat-prompt', item.text)
      render()
      return
    }
    case 'followup-submitted': {
      const index = featureState.queued_followups.findIndex(entry =>
        entry.state === 'sending' && entry.text === first)
      if (index >= 0) featureState.queued_followups.splice(index, 1)
      saveQueuedFollowups()
      featureState.thread_status = 'Follow-up sent as its own turn.'
      render()
      return
    }
    case 'followup-failed': {
      const item = featureState.queued_followups.find(entry =>
        entry.state === 'sending' && entry.text === first)
      if (item) item.state = 'draft'
      saveQueuedFollowups()
      featureState.suppress_followup_auto_once = true
      featureState.thread_status = 'Follow-up was kept because it could not be sent.'
      render()
      return
    }
    case 'preference-toggle': {
      const item = featureState.preferences.find(entry => entry.id === first)
      if (item) saveAgentPreference({ ...item, enabled: !item.enabled })
      return
    }
    case 'preference-edit': {
      const item = featureState.preferences.find(entry => entry.id === first)
      if (item) featureState.preference_draft = { ...item }
      render()
      return
    }
    case 'preference-cancel':
      featureState.preference_draft = null
      render()
      return
    case 'preference-forget':
      saveAgentPreference({ action: 'forget', id: first })
      return
    case 'teach-answer':
      featureState.learning_draft = {
        kind: 'knowledge',
        detail: '',
        source: boundedText(decodeURIComponent(first), 8000),
      }
      featureState.toolbox_open = true
      featureState.toolbox_tab = 'learning'
      loadLearningProposals()
      render()
      return
    case 'learning-new':
      featureState.learning_draft = { kind: 'preference', detail: '', source: '' }
      render()
      return
    case 'learning-cancel':
      featureState.learning_draft = null
      render()
      return
    case 'learning-accept':
      saveLearningProposal({ action: 'accept', id: first })
      return
    case 'learning-reject':
      saveLearningProposal({ action: 'reject', id: first })
      return
    case 'recipe-select':
      featureState.task_recipe_selected = first
      featureState.task_recipe_status = ''
      render()
      return
    case 'recipe-back':
      featureState.task_recipe_selected = ''
      featureState.task_recipe_status = ''
      render()
      return
    case 'source-subscription-new':
      featureState.source_subscription_draft = {
        source_kind: 'website',
        source: '',
        title: '',
        cadence: 'weekly',
        change_rule: '',
      }
      featureState.source_subscription_status = ''
      render()
      return
    case 'source-subscription-cancel':
      featureState.source_subscription_draft = null
      featureState.source_subscription_status = ''
      render()
      return
    case 'source-subscription-retry': {
      const subscription = featureState.source_subscriptions.find(item => item.id === first)
      if (subscription) setupSourceSubscription(subscription)
      return
    }
    case 'source-subscription-run': {
      const subscription = featureState.source_subscriptions.find(item => item.id === first)
      if (!subscription) return
      featureState.toolbox_open = false
      forward('start-recipe', subscription.prompt || '')
      render()
      return
    }
    case 'living-artifact-new':
      featureState.living_artifact_draft = {
        kind: 'checklist',
        title: '',
        purpose: '',
        items: '',
      }
      featureState.living_artifact_status = ''
      render()
      return
    case 'living-artifact-cancel':
      featureState.living_artifact_draft = null
      featureState.living_artifact_status = ''
      render()
      return
    case 'living-artifact-open':
      featureState.toolbox_open = false
      forward('open-path', first)
      render()
      return
    case 'review-thread-resolve':
      saveDocumentReviewThread({ action: 'resolve', thread_id: first })
      return
    case 'review-thread-pin':
      saveDocumentReviewThread({
        action: second === 'unpin' ? 'unpin' : 'pin',
        thread_id: first,
      })
      return
    case 'review-thread-ask': {
      const thread = featureState.review_threads.find(item =>
        item.kind === 'thread' && item.id === first)
      if (!thread) return
      featureState.toolbox_open = false
      forward(
        'submit-chat-prompt',
        `Join the review discussion for ${thread.anchor_label || 'the current document'}. ` +
        `Discussion: ${thread.detail || ''}. ` +
        `${thread.assigned_to ? `It is assigned to ${thread.assigned_to}. ` : ''}` +
        'Respond in the normal chat with a concise recommendation. Keep any document change reviewable before saving.',
      )
      render()
      return
    }
    case 'review-package':
      downloadReviewPackage()
      featureState.review_thread_status = 'Review package download started'
      render()
      return
    case 'review-mark-read':
      markDocumentReviewsRead()
      return
    case 'typed-source': {
      let value
      try { value = JSON.parse(first) } catch { return }
      featureState.pending_source_location = value
      if (!trySelectTypedLocation(value)) forward('open-path', String(value.workspace_path || ''), 'document')
      render()
      return
    }
    case 'typed-artifact': {
      let value
      try { value = JSON.parse(first) } catch { return }
      const path = String(value.path || value.workspace_path || '')
      if (path) forward('open-path', path)
      return
    }
    case 'typed-automation-dismiss':
      featureState.dismissed_fragments.add(first)
      render()
      return
    case 'typed-automation-confirm': {
      let value
      try { value = JSON.parse(first) } catch { return }
      fetch('/api/town/standing-goals', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          title: value.title || 'Standing watch',
          prompt: value.prompt || 'Repeat the confirmed document check.',
          target_book_id: serverState.workspace_id || '',
          cadence_ticks: Number(value.cadence_ticks) || 60,
          source_policy: value.source_policy || 'workspace-only',
          review_policy: value.review_policy || 'bookkeeper_review',
          conversation_id: serverState.task_id || '',
          document_path: serverState.selected_document || '',
          enabled: true,
        }),
      }).then(response => {
        if (!response.ok) throw new Error('create failed')
        featureState.dismissed_fragments.add(first)
        featureState.thread_status = 'Background work confirmed'
        render()
      }).catch(() => {
        featureState.thread_status = 'Background work could not be created'
        render()
      })
      return
    }
    case 'selection-action': {
      const anchor = featureState.active_anchor
      if (!anchor) return
      const intent = first || 'ask'
      if (intent === 'comment') {
        featureState.selection_toolbar = null
        featureState.toolbox_open = true
        featureState.toolbox_tab = 'review'
        loadDocumentReviewThreads()
        render()
        return
      }
      const verbs = {
        ask: 'Help me with this selection.',
        explain: 'Explain this selection clearly and note any important context.',
        check: 'Check this selection for correctness, consistency, and material risks.',
        improve: 'Improve this selection while preserving its intent and factual meaning.',
        source: 'Use this selection as a source for my next request.',
      }
      const prompt = `${verbs[intent] || verbs.ask}\n\nDocument: ${anchor.path || 'current document'}\nLocation: ${anchor.section || ''}${anchor.reference ? ` · ${anchor.reference}` : ''}\nSelected content:\n“${anchor.text}”`
      featureState.selection_toolbar = null
      forward(
        'add-context',
        JSON.stringify({
          id: `selection:${anchor.path}:${anchor.index || anchor.reference || anchor.section}`,
          kind: 'selection',
          label: `${anchor.path || 'Current document'}${anchor.reference ? ` · ${anchor.reference}` : anchor.section ? ` · ${anchor.section}` : ''}`,
          value: anchor.path || '',
          detail: anchor.text,
        }),
        intent === 'source' ? '' : verbs[intent] || verbs.ask,
        intent === 'ask' || intent === 'source' ? 'draft' : 'send',
      )
      render()
      return
    }
    case 'context-conversation': {
      const thread = currentThreads().find(item => item.id === first)
      if (!thread) return
      featureState.search_open = false
      forward(
        'add-context',
        JSON.stringify({
          id: `conversation:${thread.id}`,
          kind: 'conversation',
          label: thread.title,
          value: thread.id,
          detail: '',
        }),
        '',
        'draft',
      )
      render()
      return
    }
    case 'context-artifact':
    case 'context-inbox': {
      const kind = action === 'context-artifact' ? 'artifact' : 'inbox'
      const path = String(second || '').trim()
      if (!path) return
      featureState.search_open = false
      forward(
        'add-context',
        JSON.stringify({
          id: `${kind}:${first || serverState.workspace_id || ''}:${path}`,
          kind,
          label: third || path.split('/').pop() || path,
          value: path,
          detail: fourth || '',
        }),
        '',
        'draft',
      )
      render()
      return
    }
    case 'context-url': {
      let url
      try { url = new URL(first) } catch { return }
      if (!['http:', 'https:'].includes(url.protocol)) return
      featureState.search_open = false
      forward('add-context', JSON.stringify({
        id: `url:${url.href}`,
        kind: 'url',
        label: url.hostname,
        value: url.href,
        detail: '',
      }), '', 'draft')
      render()
      return
    }
    case 'copy-answer': {
      const text = decodeURIComponent(first)
      globalThis.navigator?.clipboard?.writeText(text).catch(() => {})
      featureState.thread_status = 'Answer copied'
      render()
      return
    }
    case 'use-answer': {
      const text = decodeURIComponent(first)
      const prompt = `Use the following answer in the selected document. Choose the most appropriate location, preserve document style, and show the proposed change for review before saving.\n\n${text}`
      forward('ask-selection', prompt, 'send')
      return
    }
    case 'pin-answer': {
      const text = decodeURIComponent(first)
      featureState.synthesis.push({
        workspace_id: serverState.workspace_id || '',
        path: '',
        title: boundedText(text, 56),
        kind: 'MoonDesk answer',
        text,
      })
      featureState.synthesis_status = 'Answer pinned'
      featureState.synthesis_open = true
      render()
      return
    }
    case 'mark-reviewed': {
      const reviewed = new Set(readStored(storageKeys.reviewed, []))
      reviewed.add(first)
      writeStored(storageKeys.reviewed, Array.from(reviewed).slice(-500))
      featureState.reviewed_markers = reviewed
      render()
      return
    }
    case 'jump-marker':
      jumpToMarker(first)
      return
    case 'history-select':
      if (second === 'left') featureState.compare_left = first
      else featureState.compare_right = first
      render()
      return
    case 'history-filter':
      featureState.compare_filter = first
      render()
      return
    case 'toggle-pack': {
      const enabled = enabledPackIds()
      if (enabled.has(first)) enabled.delete(first)
      else enabled.add(first)
      persistEnabledPackIds(enabled)
      render()
      return
    }
    case 'run-pack': {
      const pack = checkPacks.find(item => item.id === first)
      if (pack) {
        featureState.toolbox_open = false
        forward('ask-selection', pack.prompt, 'send')
      }
      render()
      return
    }
    case 'reveal-inbox':
      forward('reveal-inbox')
      return
    case 'close-search':
      featureState.search_open = false
      render()
      return
    case 'mode':
      featureState.mode = first
      render()
      return
    case 'query':
      featureState.query = first
      forward('query', first)
      return
    case 'search':
      forward('search', featureState.mode, featureState.purpose)
      return
    case 'choose': {
      if (featureState.purpose === 'pin') {
        const hit = (serverState.hits || []).find(item =>
          item.workspace_id === first && item.path === second)
        if (hit) pin(first, second, hit.title, hit.kind)
      } else {
        featureState.search_open = false
        forward('choose', first, second, featureState.purpose)
        render()
      }
      return
    }
    case 'open-path':
      featureState.search_open = false
      forward('open-path', first, featureState.purpose)
      render()
      return
    case 'pin':
      pin(first, second, third, fourth)
      return
    case 'open-synthesis':
      featureState.search_open = false
      featureState.synthesis_open = true
      render()
      return
    case 'close-synthesis':
      featureState.synthesis_open = false
      render()
      return
    case 'synthesis-search':
      featureState.synthesis_open = false
      featureState.search_open = true
      featureState.purpose = 'pin'
      featureState.mode = 'files'
      featureState.query = serverState.query || ''
      render()
      return
    case 'synthesis-title':
      featureState.synthesis_title = first
      return
    case 'remove-pin':
      featureState.synthesis = featureState.synthesis.filter(item =>
        item.workspace_id !== first || item.path !== second)
      featureState.synthesis_status = 'Removed source'
      render()
      return
    case 'clear-synthesis':
      featureState.synthesis = []
      featureState.synthesis_status = 'Board cleared'
      render()
      return
    case 'start-synthesis':
      forward(
        'start-synthesis',
        first,
        featureState.synthesis_title,
        featureState.synthesis.map(item => item.path
          ? item.path
          : `note:${boundedText(item.text || item.title, 4000)}`).join('\n'),
      )
      featureState.synthesis_open = false
      render()
      return
    default:
      forward(action, first, second, third, fourth)
  }
}

function element(tag, className = '', text = '') {
  const value = document.createElement(tag)
  if (className) value.className = className
  if (text) value.textContent = text
  return value
}

function button(className, text, action, args = [], options = {}) {
  const value = element('button', className, text)
  value.type = 'button'
  value.disabled = options.disabled === true
  if (options.title) value.title = options.title
  if (options.label) value.setAttribute('aria-label', options.label)
  if (typeof options.pressed === 'boolean') {
    value.setAttribute('aria-pressed', String(options.pressed))
  }
  value.addEventListener('click', event => {
    event.stopPropagation()
    emit(action, ...args)
  })
  return value
}

function heading(eyebrow, title) {
  const copy = element('div')
  copy.append(element('p', 'eyebrow', eyebrow), element('h2', '', title))
  return copy
}

function purposeTitle(purpose) {
  if (purpose === 'document') return 'Choose a document'
  if (purpose === 'attach') return 'Add context'
  if (purpose === 'pin') return 'Add to synthesis'
  return 'Search everything'
}

function modeLabel(mode) {
  return {
    files: 'Exact', semantic: 'Meaning', structure: 'Structure',
    code: 'Code', issues: 'Issues', work: 'Work',
  }[mode] || 'Exact'
}

function renderEmpty(state) {
  const empty = element('div', 'universal-search-empty')
  const stateKey = state.search_state || (state.searching ? 'loading' : state.query ? 'legitimate-zero' : 'idle')
  const copy = {
    'first-use-empty': ['Start with a name, phrase, or symbol', 'Search files, knowledge, code, and work in this MoonBook.'],
    loading: ['Working on it', 'Searching your books.'],
    'legitimate-zero': ['No results', 'No matching pages, notes, or sources were found.'],
    stale: ['This may be out of date', 'Refresh to see the latest information.'],
    disconnected: ['You’re offline', 'Check your connection and try again.'],
    'capability-limited': ['This action isn’t available', 'Your current setup doesn’t support this action.'],
    'recoverable-error': ['Something went wrong', 'Try the search again.'],
    'terminal-error': ['This can’t continue', 'Return to Pages and choose another action.'],
  }[stateKey] || [state.query ? 'No matching work found' : 'Start with a name, phrase, or symbol', state.search_status || '']
  empty.dataset.testid = 'pages-search-state'
  empty.dataset.state = stateKey
  const announcement = element('div')
  announcement.dataset.testid = 'pages-search-state-announcement'
  announcement.setAttribute('role', 'status')
  announcement.setAttribute('aria-live', 'polite')
  announcement.setAttribute('aria-atomic', 'true')
  announcement.append(element('strong', '', copy[0]), element('p', '', copy[1]))
  empty.append(announcement)
  if (['stale', 'disconnected', 'capability-limited', 'recoverable-error', 'terminal-error'].includes(stateKey)) {
    const technical = element('details', 'technical-details')
    technical.append(
      element('summary', '', 'Technical details'),
      element('p', '', state.search_status || 'The request did not complete.'),
    )
    empty.append(technical)
  }
  if (!state.query && state.recent_paths?.length) {
    const recent = element('div', 'universal-recent-paths')
    for (const path of state.recent_paths) {
      recent.append(button('universal-recent-path', path, 'open-path', [path]))
    }
    empty.append(recent)
  }
  return empty
}

function renderFileResults(state) {
  const fragment = document.createDocumentFragment()
  if (!state.hits?.length) {
    fragment.append(renderEmpty(state))
    return fragment
  }
  for (const hit of state.hits) {
    const row = element('div', 'universal-result')
    const action = state.purpose === 'attach' && hit.layer === 'inbox'
      ? 'context-inbox'
      : 'choose'
    const main = button(
      'universal-result-main',
      '',
      action,
      action === 'context-inbox'
        ? [hit.workspace_id, hit.path, hit.title, hit.snippet || '']
        : [hit.workspace_id, hit.path],
    )
    main.append(
      element('strong', '', hit.title),
      element('small', '', `${hit.path} · ${hit.kind} · ${hit.workspace_name}`),
    )
    if (hit.snippet) main.append(element('p', '', hit.snippet))
    row.append(main)
    if (state.purpose !== 'document' && state.purpose !== 'pin') {
      row.append(button(
        'universal-result-pin',
        'Pin',
        'pin',
        [hit.workspace_id, hit.path, hit.title, hit.kind],
        { label: `Pin ${hit.title}`, title: 'Pin to synthesis board' },
      ))
    }
    fragment.append(row)
  }
  return fragment
}

function renderWorkResults(state) {
  const fragment = document.createDocumentFragment()
  const needle = String(state.query || '').trim().toLowerCase()
  const conversationRows = state.purpose === 'attach'
    ? currentThreads().filter(thread => !thread.archived).map(thread => ({
      type: 'conversation',
      title: thread.title,
      detail: `${thread.document || 'Workspace'} · earlier conversation`,
      conversation_id: thread.id,
    }))
    : []
  const rows = [...conversationRows, ...(state.work || [])].filter(row => !needle ||
    `${row.title} ${row.detail} ${row.path || ''}`.toLowerCase().includes(needle))
  if (!rows.length) {
    const empty = element('div', 'universal-search-empty')
    empty.append(
      element('strong', '', 'No matching work'),
      element('p', '', 'Tasks, runs, reviews, warnings, and artifacts will appear here.'),
    )
    fragment.append(empty)
    return fragment
  }
  for (const item of rows) {
    const row = element('div', 'universal-work-result with-actions')
    const action = item.type === 'conversation'
      ? 'context-conversation'
      : state.purpose === 'attach' && item.type === 'artifact' && item.path
        ? 'context-artifact'
      : item.path ? 'choose' : 'destination'
    const args = item.path
      ? [item.workspace_id || '', item.path, item.title || '', item.detail || '']
      : item.type === 'conversation'
        ? [item.conversation_id]
        : [item.destination || 'runs']
    const main = button('universal-work-main', '', action, args)
    main.append(element('strong', '', item.title), element('small', '', item.detail || ''))
    row.append(main)
    if (item.type === 'artifact' && item.path) {
      row.append(button(
        'universal-result-pin',
        'Pin',
        'pin',
        [item.workspace_id || '', item.path, item.title, 'Run artifact'],
      ))
    }
    fragment.append(row)
  }
  return fragment
}

function renderSearch(state) {
  const backdrop = element('div', 'universal-search-backdrop')
  backdrop.addEventListener('click', () => emit('close-search'))
  const panel = element('section', 'universal-search-panel')
  panel.setAttribute('role', 'dialog')
  panel.setAttribute('aria-modal', 'true')
  panel.setAttribute('aria-label', purposeTitle(state.purpose))
  panel.dataset.testid = 'universal-search'
  panel.addEventListener('click', event => event.stopPropagation())

  const header = element('header', 'universal-search-header')
  header.append(
    heading('Find & Add', purposeTitle(state.purpose)),
    button('icon-button', '×', 'close-search', [], { label: 'Close Find and Add' }),
  )
  panel.append(header)

  if (state.purpose !== 'document') {
    const modes = element('div', 'universal-search-modes')
    for (const mode of ['files', 'semantic', 'structure', 'code', 'issues', 'work']) {
      modes.append(button(
        `universal-search-mode${state.mode === mode ? ' active' : ''}`,
        modeLabel(mode),
        'mode',
        [mode],
        { pressed: state.mode === mode },
      ))
    }
    panel.append(modes)
  }

  const queryRow = element('div', 'universal-search-query-row')
  const input = element('input', 'universal-search-input')
  input.type = 'search'
  input.value = state.query || ''
  input.dataset.testid = 'universal-search-input'
  input.setAttribute('aria-label', 'Search workspace')
  input.placeholder = state.mode === 'work'
    ? 'Filter tasks, runs, warnings, and artifacts…'
    : state.mode === 'semantic'
      ? 'Describe the idea or subject you need…'
      : state.mode === 'structure'
        ? 'Find a heading, table, formula, slide, or declaration…'
        : state.mode === 'issues'
          ? 'Find warnings, open questions, and review items…'
    : state.mode === 'code'
      ? 'Find a symbol, declaration, or code pattern…'
      : 'Search names and contents…'
  input.addEventListener('input', () => emit('query', input.value))
  input.addEventListener('keydown', event => {
    if (event.key === 'Enter' && state.mode !== 'work' && input.value.trim()) emit('search')
    if (event.key === 'Escape') emit('close-search')
  })
  queryRow.append(input)
  if (state.mode !== 'work') {
    const search = button(
      'primary-button', 'Search', 'search', [], { disabled: !String(state.query || '').trim() },
    )
    search.dataset.testid = 'pages-search-state-action'
    queryRow.append(search)
  }
  panel.append(queryRow)

  if (state.purpose === 'attach') {
    const urlRow = element('div', 'universal-context-url')
    const urlInput = element('input')
    urlInput.type = 'url'
    urlInput.placeholder = 'https://…'
    urlInput.setAttribute('aria-label', 'Add an explicit web URL')
    const addUrl = element('button', 'secondary-button', 'Add URL')
    addUrl.type = 'button'
    addUrl.addEventListener('click', event => {
      event.preventDefault()
      emit('context-url', urlInput.value)
    })
    urlRow.append(urlInput, addUrl)
    panel.append(urlRow)

    const media = element('div', 'universal-media-intake')
    const copy = element('div')
    copy.append(
      element('strong', '', 'Add a screenshot, recording, or file'),
      element('small', '', 'Paste an image, drop local media, or choose a file. MoonDesk keeps the captured source with this book.'),
    )
    media.append(copy, button(
      'secondary-button', 'Choose media…', 'import-files', [],
      { label: 'Choose image, audio, video, or document files' },
    ))
    panel.append(media)
  }

  const results = element('div', 'universal-search-results')
  results.setAttribute('aria-live', 'polite')
  results.append(state.mode === 'work' ? renderWorkResults(state) : renderFileResults(state))
  panel.append(results)

  const drop = element('div', 'universal-intake-dropzone')
  drop.setAttribute('role', 'region')
  drop.setAttribute('aria-label', 'Drop a workspace item to open or reference it')
  drop.addEventListener('dragover', event => {
    event.preventDefault()
    if (event.dataTransfer) event.dataTransfer.dropEffect = 'copy'
  })
  drop.addEventListener('drop', event => {
    event.preventDefault()
    const path = event.dataTransfer?.getData('application/x-moondesk-workspace-path')
      || event.dataTransfer?.getData('text/plain') || ''
    if (path) emit('open-path', path)
  })
  drop.append(
    element('strong', '', 'Drop a workspace item here'),
    element('small', '', 'Or paste a workspace-relative path above and choose Open path.'),
    button(
      'secondary-button', 'Open path', 'open-path', [state.query || ''],
      { disabled: !String(state.query || '').trim() },
    ),
  )
  panel.append(drop)

  const footer = element('div', 'universal-search-footer')
  footer.append(element(
    'span', '', state.purpose === 'document'
      ? 'References stay in this workspace; nothing is copied.'
      : 'Open or reference existing work. Importing a copy is always explicit.',
  ))
  const actions = element('div')
  actions.append(
    ...(state.purpose === 'attach'
      ? []
      : [button('secondary-button', 'Import copies…', 'import-files')]),
    button('secondary-button', 'Import folder…', 'import-folder'),
    button('secondary-button', 'New folder or book…', 'desk-intake'),
    button('secondary-button', 'Synthesis board', 'open-synthesis'),
  )
  footer.append(actions)
  panel.append(footer)
  backdrop.append(panel)
  return backdrop
}

function renderSynthesis(state) {
  const backdrop = element('div', 'synthesis-backdrop')
  const board = element('aside', 'synthesis-board')
  board.setAttribute('role', 'dialog')
  board.setAttribute('aria-modal', 'true')
  board.setAttribute('aria-label', 'Synthesis board')
  board.dataset.testid = 'synthesis-board'
  const header = element('header', 'synthesis-header')
  header.append(
    heading('Pinned sources', 'Synthesis board'),
    button('icon-button', '×', 'close-synthesis', [], { label: 'Close synthesis board' }),
  )
  const content = element('div', 'synthesis-content')
  const label = element('label')
  label.append(element('span', '', 'Deliverable title'))
  const title = element('input')
  title.value = state.synthesis_title || ''
  title.addEventListener('input', () => emit('synthesis-title', title.value))
  label.append(title)
  content.append(label)
  if (!state.synthesis?.length) {
    const empty = element('div', 'synthesis-empty')
    empty.append(
      element('strong', '', 'Pin useful material from anywhere'),
      element('p', '', 'Files, evidence, and run artifacts keep their source paths.'),
      button('primary-button', 'Find sources', 'synthesis-search'),
    )
    content.append(empty)
  } else {
    const list = element('div', 'synthesis-list')
    for (const item of state.synthesis) {
      const row = element('div', 'synthesis-item')
      const copy = element('div')
      copy.append(
        element('strong', '', item.title),
        element('small', '', `${item.kind} · ${item.path}`),
      )
      row.append(
        copy,
        button(
          'icon-button', '×', 'remove-pin', [item.workspace_id, item.path],
          { label: `Remove ${item.title}` },
        ),
      )
      list.append(row)
    }
    content.append(list)
  }
  content.append(
    button('secondary-button', 'Add another source', 'synthesis-search'),
    element('p', 'status-line', state.synthesis_status || ''),
  )
  const actions = element('div', 'synthesis-actions')
  const disabled = !state.synthesis?.length
  actions.append(button('secondary-button', 'Clear', 'clear-synthesis', [], { disabled }))
  const outcomes = element('div')
  outcomes.append(
    button('secondary-button', 'Create brief', 'start-synthesis', ['brief'], { disabled }),
    button('secondary-button', 'Create report', 'start-synthesis', ['report'], { disabled }),
    button(
      'primary-button', 'Turn into…', 'start-synthesis',
      ['presentation or spreadsheet, whichever best fits the evidence'], { disabled },
    ),
  )
  actions.append(outcomes)
  board.append(header, content, actions)
  backdrop.append(board)
  return backdrop
}

function sourceEntries(state = serverState) {
  const sources = []
  const seen = new Set()
  const add = source => {
    const key = `${source.type}:${source.value}:${source.location ? JSON.stringify(source.location) : ''}`
    if (!source.value || seen.has(key)) return
    seen.add(key)
    sources.push({ ...source, key })
  }
  for (const source of typedSourceEntries(state.chat)) add(source)
  for (const [messageIndex, entry] of (state.chat || []).entries()) {
    if (entry.role === 'user') continue
    const content = String(entry.content || '')
    if (entry.role === 'source_ref' || entry.role === 'artifact_ref') continue
    for (const match of content.matchAll(/https?:\/\/[^\s<>"')\]]+/g)) {
      add({ type: 'web', label: (() => {
        try { return new URL(match[0]).hostname }
        catch { return 'Web source' }
      })(), value: match[0], message_index: messageIndex })
    }
    for (const match of content.matchAll(/(?:^|[\s(`])@?((?:wiki|raw|inbox|reviews|documents|book\/site)\/[\w./ -]+)/g)) {
      add({ type: 'workspace', label: match[1].split('/').pop(), value: match[1].trim(), message_index: messageIndex })
    }
  }
  for (const item of featureState.synthesis) {
    add({
      type: item.path ? 'workspace' : 'conversation',
      label: item.title,
      value: item.path || boundedText(item.text, 180),
      message_index: -1,
    })
  }
  return sources
}

function reviewMarkers(state = serverState) {
  const reviewed = new Set(readStored(storageKeys.reviewed, []))
  const markers = []
  for (const [index, warning] of (state.office?.warnings || []).entries()) {
    markers.push({
      id: `warning:${state.selected_document}:${index}:${warning}`,
      type: 'warning',
      title: warning,
      detail: 'Document warning',
      anchor: '',
    })
  }
  const saved = state.office?.saved_items || []
  const draft = state.office?.draft_items || []
  for (let index = 0; index < Math.min(saved.length, draft.length); index += 1) {
    if (JSON.stringify(saved[index]) === JSON.stringify(draft[index])) continue
    const item = draft[index]
    markers.push({
      id: `change:${state.selected_document}:${index}`,
      type: 'change',
      title: `${item.section || 'Document'} · ${item.reference || `Item ${index + 1}`}`,
      detail: officeReviewChanges({ before: saved[index], after: item, kind: state.office.kind }).join(', '),
      anchor: String(index),
    })
  }
  for (const source of sourceEntries(state)) {
    markers.push({
      id: `source:${source.key}`,
      type: 'source',
      title: source.label,
      detail: source.type === 'web' ? 'Web evidence' : 'Workspace evidence',
      anchor: source.message_index >= 0 ? `message:${source.message_index}` : '',
    })
  }
  for (const item of (state.work || []).filter(item =>
    item.type === 'review' && (!item.path || item.path === state.selected_document))) {
    markers.push({
      id: `review:${item.path}:${item.title}`,
      type: 'review',
      title: item.title.replace(/^Review · /, ''),
      detail: item.detail || item.status,
      anchor: '',
    })
  }
  return markers.map(marker => ({ ...marker, reviewed: reviewed.has(marker.id) }))
}

function jumpToMarker(anchor) {
  let target = null
  if (String(anchor).startsWith('message:')) {
    const index = Number(String(anchor).slice('message:'.length))
    target = document.querySelectorAll('.wiki-chat-message')[index]
  } else if (anchor !== '') {
    target = document.querySelector(`[data-document-anchor="${CSS.escape(String(anchor))}"]`)
  }
  target?.scrollIntoView({ behavior: 'smooth', block: 'center' })
  if (target instanceof HTMLElement) {
    target.classList.add('document-anchor-flash')
    setTimeout(() => target.classList.remove('document-anchor-flash'), 1400)
  }
}

function snapshotFingerprint(snapshot) {
  return JSON.stringify({ baseline: snapshot.baseline, items: snapshot.items })
}

function persistOfficeHistory() {
  const office = serverState.office
  if (!office?.open || !office.path) return
  const persistenceFingerprint = JSON.stringify({
    path: office.path,
    baseline: office.baseline,
    saved: office.saved_items,
    draft: office.draft_items,
  })
  if (persistenceFingerprint === lastHistoryPersistenceFingerprint) return
  const all = readStored(storageKeys.history, {})
  const key = documentKey({
    workspace_id: serverState.workspace_id,
    selected_document: office.path,
  })
  const versions = Array.isArray(all[key]) ? all[key] : []
  const candidates = [
    {
      id: `saved:${office.baseline}`,
      kind: 'saved',
      label: 'Saved version',
      created_at: Date.now(),
      baseline: office.baseline || '',
      items: office.saved_items || [],
    },
  ]
  if (JSON.stringify(office.saved_items || []) !== JSON.stringify(office.draft_items || [])) {
    candidates.unshift({
      id: `draft:${office.baseline}:${boundedText(JSON.stringify(office.draft_items || []), 96)}`,
      kind: 'proposed',
      label: 'Current proposal',
      created_at: Date.now(),
      baseline: office.baseline || '',
      items: office.draft_items || [],
    })
  }
  for (const candidate of candidates) {
    const fingerprint = snapshotFingerprint(candidate)
    if (versions.some(version => snapshotFingerprint(version) === fingerprint)) continue
    versions.unshift(candidate)
  }
  all[key] = versions.slice(0, 30)
  writeStored(storageKeys.history, all)
  lastHistoryPersistenceFingerprint = persistenceFingerprint
}

function currentHistory() {
  const all = readStored(storageKeys.history, {})
  return Array.isArray(all[documentKey()]) ? all[documentKey()] : []
}

function changeCategory(before = {}, after = {}) {
  if (before.formula !== after.formula) return 'formula'
  if (before.text !== after.text) return 'content'
  if (before.bold !== after.bold || before.italic !== after.italic || before.underline !== after.underline) {
    return 'formatting'
  }
  return 'layout'
}

function historyChanges(left, right, filter = 'all') {
  if (!left || !right) return []
  const rows = []
  const length = Math.max(left.items?.length || 0, right.items?.length || 0)
  for (let index = 0; index < length; index += 1) {
    const before = left.items?.[index] || {}
    const after = right.items?.[index] || {}
    if (JSON.stringify(before) === JSON.stringify(after)) continue
    const category = changeCategory(before, after)
    if (filter !== 'all' && filter !== category) continue
    rows.push({ index, before, after, category })
  }
  return rows
}

function renderReviewTab(state) {
  const content = element('div', 'document-tool-content')
  loadDocumentReviewThreads()
  const markers = reviewMarkers(state)
  const open = markers.filter(marker => !marker.reviewed)
  const intro = element('div', 'document-tool-intro with-action')
  const introCopy = element('div')
  introCopy.append(
    element('h3', '', 'Review room'),
    element('p', '', featureState.review_counts.open
      ? `${featureState.review_counts.open} open discussion${featureState.review_counts.open === 1 ? '' : 's'}${featureState.review_counts.required ? ` · ${featureState.review_counts.required} assigned` : ''}${featureState.review_counts.pinned ? ` · ${featureState.review_counts.pinned} pinned` : ''}${featureState.review_counts.unread ? ` · ${featureState.review_counts.unread} unread` : ''}.`
      : open.length
        ? `${open.length} open item${open.length === 1 ? '' : 's'} across this document.`
      : 'No open review items. MoonDesk will interrupt only for a material warning.'),
  )
  const introActions = element('div', 'review-room-header-actions')
  if (featureState.review_counts.unread) {
    introActions.append(button('secondary-button', 'Mark read', 'review-mark-read'))
  }
  introActions.append(button('secondary-button', 'Prepare review package', 'review-package'))
  intro.append(introCopy, introActions)
  content.append(intro)
  const room = reviewRoomProjection(
    featureState.review_threads,
    featureState.review_participants,
  )
  if (room.participants.length) {
    const participants = element('div', 'review-room-participants')
    participants.append(element('span', 'review-room-label', 'In this room'))
    for (const participant of room.participants) {
      participants.append(element('span', 'review-room-participant', participant))
    }
    content.append(participants)
  }
  if (state.selected_document) {
    const form = element('form', 'document-review-thread-form')
    const anchor = featureState.active_anchor
    const anchorLabel = anchor
      ? `${anchor.section || 'Selection'}${anchor.reference ? ` · ${anchor.reference}` : ''}`
      : 'Whole document'
    form.append(element('small', '', `Comment on ${anchorLabel}`))
    const detail = element('textarea')
    detail.required = true
    detail.placeholder = 'Add a question, decision, or requested change'
    const assignee = element('input')
    assignee.placeholder = 'Assign to a person or agent (optional)'
    const submit = element('button', 'primary-button', 'Start discussion')
    submit.type = 'submit'
    form.append(detail, assignee, submit)
    form.addEventListener('submit', event => {
      event.preventDefault()
      if (!detail.value.trim()) return
      saveDocumentReviewThread({
        action: 'create',
        detail: detail.value.trim(),
        assigned_to: assignee.value.trim(),
        anchor: anchor?.index || '',
        anchor_kind: anchor?.kind || 'document',
        anchor_label: anchorLabel,
      })
      detail.value = ''
    })
    content.append(form)
  }
  if (!markers.length) {
    content.append(element('div', 'document-tool-empty', 'Warnings, proposed edits, and evidence will appear here.'))
  } else {
    const list = element('div', 'document-review-list')
    for (const marker of markers) {
      const row = element('article', `document-review-row ${marker.type}${marker.reviewed ? ' reviewed' : ''}`)
      const main = button('document-review-main', '', 'jump-marker', [marker.anchor])
      main.append(
        element('span', `document-review-dot ${marker.type}`, ''),
        element('strong', '', marker.title),
        element('small', '', marker.detail),
      )
      row.append(main)
      if (!marker.reviewed) {
        row.append(button('document-review-done', 'Mark reviewed', 'mark-reviewed', [marker.id]))
      } else {
        row.append(element('span', 'document-review-state', 'Reviewed'))
      }
      list.append(row)
    }
    content.append(list)
  }
  const threadRecords = room.threads
  if (threadRecords.length) {
    const discussions = element('div', 'document-review-thread-list')
    for (const thread of threadRecords) {
      const row = element('article', `document-review-thread ${thread.status}${thread.pinned ? ' pinned' : ''}${thread.anchor_status === 'stale' ? ' stale' : ''}`)
      const threadHeading = element('div', 'review-room-thread-heading')
      threadHeading.append(
        element('strong', '', thread.anchor_label || 'Document'),
        element('span', 'review-room-thread-state', thread.pinned ? 'Pinned decision' : thread.status),
      )
      row.append(
        threadHeading,
        element('p', '', thread.detail),
        element('small', '', `${thread.assigned_to ? `Assigned to ${thread.assigned_to} · ` : ''}${thread.anchor_status === 'stale' ? 'Anchor needs revalidation' : thread.status}`),
      )
      const replies = featureState.review_threads.filter(item => item.kind === 'reply' && item.thread_id === thread.id)
      for (const reply of replies) {
        row.append(element('p', 'document-review-reply', `${reply.author || 'Reply'}: ${reply.detail}`))
      }
      const replyForm = element('form', 'document-review-reply-form')
      const reply = element('input')
      reply.placeholder = 'Reply…'
      const send = element('button', 'secondary-button', 'Reply')
      send.type = 'submit'
      replyForm.append(reply, send)
      replyForm.addEventListener('submit', event => {
        event.preventDefault()
        if (!reply.value.trim()) return
        saveDocumentReviewThread({ action: 'reply', thread_id: thread.id, detail: reply.value.trim() })
      })
      row.append(replyForm)
      const actions = element('div', 'review-room-thread-actions')
      actions.append(
        button('secondary-button', thread.pinned ? 'Unpin' : 'Pin decision', 'review-thread-pin', [thread.id, thread.pinned ? 'unpin' : 'pin']),
        button('secondary-button', 'Ask agent', 'review-thread-ask', [thread.id]),
      )
      if (thread.status !== 'resolved') {
        actions.append(button('secondary-button', 'Resolve', 'review-thread-resolve', [thread.id]))
      }
      row.append(actions)
      discussions.append(row)
    }
    content.append(discussions)
  }
  content.append(element('p', 'status-line', featureState.review_thread_status))
  return content
}

function renderThreadsTab() {
  const content = element('div', 'document-tool-content')
  const header = element('div', 'document-tool-intro with-action')
  const copy = element('div')
  copy.append(
    element('h3', '', 'Document conversations'),
    element('p', '', 'Resume visible answers and the general MoonClaw task for this workspace.'),
  )
  header.append(copy, button('secondary-button', 'New conversation', 'new-thread'))
  content.append(header)
  const threads = currentThreads()
  if (!threads.length) {
    content.append(element('div', 'document-tool-empty', 'Your first conversation will be saved with this workspace.'))
    return content
  }
  const list = element('div', 'document-thread-list')
  for (const thread of threads) {
    const row = element('article', `document-thread-row${thread.archived ? ' archived' : ''}`)
    const title = element('input', 'document-thread-title')
    title.value = thread.title || 'Document conversation'
    title.setAttribute('aria-label', 'Conversation title')
    title.addEventListener('change', () => emit('rename-thread', thread.id, title.value))
    const meta = element('small', '', `${thread.document || 'Workspace'} · ${new Date(thread.updated_at).toLocaleString()}`)
    const actions = element('div', 'document-thread-actions')
    actions.append(
      button('primary-button', 'Resume', 'restore-thread', [thread.id]),
      button(
        'secondary-button', thread.archived ? 'Restore' : 'Archive', 'archive-thread',
        [thread.id, thread.archived ? 'restore' : 'archive'],
      ),
    )
    row.append(title, meta, actions)
    list.append(row)
  }
  content.append(list, element('p', 'status-line', featureState.thread_status))
  return content
}

function renderSourcesTab(state) {
  const content = element('div', 'document-tool-content')
  loadSourceSubscriptions()
  content.append(element('div', 'document-tool-intro with-action'))
  const sourceIntro = element('div')
  sourceIntro.append(
    element('h3', '', 'Keep sources current'),
    element('p', '', 'Save a source once and receive an update only when a meaningful change affects this book.'),
  )
  content.firstChild.append(
    sourceIntro,
    button('primary-button', 'Keep a source current', 'source-subscription-new'),
  )
  if (featureState.source_subscription_draft) {
    const form = element('form', 'source-subscription-form')
    const kind = element('select')
    for (const [value, label] of [
      ['website', 'Website'], ['feed', 'Feed'], ['folder', 'Workspace folder'], ['repository', 'Repository'],
    ]) {
      const option = element('option', '', label)
      option.value = value
      kind.append(option)
    }
    const title = element('input')
    title.required = true
    title.maxLength = 160
    title.placeholder = 'Name this source'
    const source = element('input')
    source.required = true
    source.maxLength = 4096
    source.placeholder = 'URL, feed, repository, or workspace folder'
    const cadence = element('select')
    for (const value of ['daily', 'weekly', 'monthly']) {
      const option = element('option', '', value[0].toUpperCase() + value.slice(1))
      option.value = value
      cadence.append(option)
    }
    cadence.value = 'weekly'
    const changeRule = element('textarea')
    changeRule.maxLength = 2000
    changeRule.placeholder = 'What change is important enough to report?'
    const actions = element('div', 'source-subscription-actions')
    const submit = element('button', 'primary-button', 'Save and set up')
    submit.type = 'submit'
    actions.append(
      button('secondary-button', 'Cancel', 'source-subscription-cancel'),
      submit,
    )
    form.append(
      element('label', '', 'Source type'), kind,
      element('label', '', 'Name'), title,
      element('label', '', 'Source'), source,
      element('label', '', 'Check'), cadence,
      element('label', '', 'Meaningful change'), changeRule,
      actions,
    )
    form.addEventListener('submit', event => {
      event.preventDefault()
      saveSourceSubscription({
        action: 'create',
        source_kind: kind.value,
        source: source.value.trim(),
        title: title.value.trim(),
        cadence: cadence.value,
        change_rule: changeRule.value.trim(),
      })
    })
    content.append(form)
  }
  const counts = sourceSubscriptionCounts(featureState.source_subscriptions)
  if (featureState.source_subscriptions.length) {
    const summary = element('div', 'source-subscription-summary')
    summary.append(
      element('span', '', `${counts.active} active`),
      element('span', '', `${counts.needs_setup} need setup`),
    )
    const subscriptions = element('div', 'source-subscription-list')
    for (const item of featureState.source_subscriptions) {
      const row = element('article', `source-subscription-row ${item.status || 'needs_setup'}`)
      const heading = element('div', 'source-subscription-heading')
      heading.append(
        element('strong', '', item.title || 'Saved source'),
        element('span', 'source-subscription-state', item.status === 'active' ? 'Active' : 'Needs setup'),
      )
      const actions = element('div', 'source-subscription-actions')
      actions.append(button('secondary-button', 'Check now', 'source-subscription-run', [item.id]))
      if (item.status !== 'active') {
        actions.append(button('primary-button', 'Retry setup', 'source-subscription-retry', [item.id]))
      }
      row.append(
        heading,
        element('small', '', `${item.source_kind || 'source'} · ${item.cadence || 'weekly'}`),
        element('p', '', item.source || ''),
        element('p', 'source-subscription-rule', item.change_rule || 'Report only a material change that affects this book.'),
        actions,
      )
      subscriptions.append(row)
    }
    content.append(summary, subscriptions)
  }
  if (featureState.source_subscription_status) {
    content.append(element('p', 'status-line', featureState.source_subscription_status))
  }
  const evidenceIntro = element('div', 'document-tool-intro source-evidence-intro')
  evidenceIntro.append(
    element('h3', '', 'Evidence'),
    element('p', '', 'Sources referenced by visible answers and pinned synthesis material.'),
  )
  content.append(evidenceIntro)
  const sources = sourceEntries(state)
  if (!sources.length) {
    content.append(element('div', 'document-tool-empty', 'Citation chips appear after MoonDesk references workspace or web evidence.'))
    return content
  }
  const list = element('div', 'evidence-list')
  for (const source of sources) {
    const row = element('article', 'evidence-row')
    const copy = element('div')
    copy.append(element('strong', '', source.label), element('small', '', source.value))
    row.append(copy)
    if (source.type === 'web') {
      const link = element('a', 'secondary-button', 'Open source')
      link.href = source.value
      link.target = '_blank'
      link.rel = 'noreferrer'
      row.append(link)
    } else if (source.type === 'workspace' || source.type === 'artifact') {
      row.append(button(
        'secondary-button',
        source.location ? 'Open exact location' : 'Open',
        source.location ? 'open-source-location' : 'open-path',
        [source.location ? JSON.stringify(source.location) : source.value],
      ))
    }
    list.append(row)
  }
  content.append(list)
  return content
}

function renderHistoryTab() {
  const content = element('div', 'document-tool-content')
  const versions = currentHistory()
  const intro = element('div', 'document-tool-intro')
  intro.append(
    element('h3', '', 'History & compare'),
    element('p', '', 'Compare saved and proposed document states for this workspace.'),
  )
  content.append(intro)
  if (versions.length < 2) {
    content.append(element('div', 'document-tool-empty', 'A second version will appear after the document changes or is saved.'))
    return content
  }
  const controls = element('div', 'history-controls')
  const select = (side, current) => {
    const label = element('label')
    label.append(element('span', '', side === 'left' ? 'Earlier' : 'Later'))
    const input = element('select')
    for (const version of versions) {
      const option = element('option', '', `${version.label} · ${new Date(version.created_at).toLocaleTimeString()}`)
      option.value = version.id
      input.append(option)
    }
    input.value = current || (side === 'left' ? versions.at(-1).id : versions[0].id)
    input.addEventListener('change', () => emit('history-select', input.value, side))
    label.append(input)
    return label
  }
  const leftId = featureState.compare_left || versions.at(-1).id
  const rightId = featureState.compare_right || versions[0].id
  controls.append(select('left', leftId), select('right', rightId))
  content.append(controls)
  const filters = element('div', 'history-filters')
  for (const filter of ['all', 'content', 'formatting', 'formula', 'layout']) {
    filters.append(button(
      `history-filter${featureState.compare_filter === filter ? ' active' : ''}`,
      filter[0].toUpperCase() + filter.slice(1), 'history-filter', [filter],
      { pressed: featureState.compare_filter === filter },
    ))
  }
  content.append(filters)
  const changes = historyChanges(
    versions.find(version => version.id === leftId),
    versions.find(version => version.id === rightId),
    featureState.compare_filter,
  )
  if (!changes.length) {
    content.append(element('div', 'document-tool-empty', 'No changes match this comparison.'))
  } else {
    const list = element('div', 'history-change-list')
    for (const change of changes) {
      const row = element('article', 'history-change-row')
      row.append(
        element('span', 'history-change-kind', change.category),
        element('strong', '', change.after.reference || change.before.reference || `Item ${change.index + 1}`),
        element('del', '', boundedText(change.before.text || change.before.formula || 'Empty', 180)),
        element('ins', '', boundedText(change.after.text || change.after.formula || 'Empty', 180)),
      )
      list.append(row)
    }
    content.append(list)
  }
  return content
}

function renderPacksTab() {
  const content = element('div', 'document-tool-content')
  const intro = element('div', 'document-tool-intro')
  intro.append(
    element('h3', '', 'Check packs'),
    element('p', '', 'Focused checks for normal document work. MoonDesk keeps their prompts and internal stages out of view.'),
  )
  content.append(intro)
  const enabled = enabledPackIds()
  const list = element('div', 'check-pack-list')
  for (const pack of checkPacks) {
    const card = element('article', `check-pack-card${enabled.has(pack.id) ? ' enabled' : ''}`)
    const header = element('div', 'check-pack-heading')
    header.append(
      element('strong', '', pack.title),
      element('span', 'check-pack-state', enabled.has(pack.id) ? 'Enabled' : 'Available'),
    )
    const details = element('details')
    details.append(element('summary', '', 'What it reads and when it warns'))
    const facts = element('dl')
    facts.append(
      element('dt', '', 'Reads'), element('dd', '', pack.reads),
      element('dt', '', 'Warns'), element('dd', '', pack.warns),
    )
    details.append(facts)
    const actions = element('div', 'check-pack-actions')
    actions.append(
      button('secondary-button', enabled.has(pack.id) ? 'Disable' : 'Enable', 'toggle-pack', [pack.id]),
      button('primary-button', 'Run now', 'run-pack', [pack.id]),
    )
    card.append(header, element('p', '', pack.description), details, actions)
    list.append(card)
  }
  content.append(list)
  return content
}

function renderInboxTab(state) {
  const content = element('div', 'document-tool-content')
  const intro = element('div', 'document-tool-intro')
  intro.append(
    element('h3', '', 'MoonDesk Inbox'),
    element('p', '', 'A familiar folder for work you want MoonDesk to index and quietly check.'),
  )
  const path = state.workspace_path && state.workspace_path !== 'not connected'
    ? `${state.workspace_path.replace(/\/$/, '')}/inbox`
    : 'Select a MoonBook to see its Inbox'
  const pathBox = element('div', 'inbox-path')
  pathBox.append(element('code', '', path))
  const actions = element('div', 'inbox-actions')
  actions.append(
    button('primary-button', 'Open Inbox in Finder', 'reveal-inbox', [], { disabled: !state.workspace_id }),
    button('secondary-button', 'Import files…', 'import-files', [], { disabled: !state.workspace_id }),
    button('secondary-button', 'Import a folder…', 'import-folder', [], { disabled: !state.workspace_id }),
  )
  const note = element('div', 'inbox-behavior')
  note.append(
    element('strong', '', 'What happens after you add work'),
    element('p', '', 'MoonDesk indexes it with the book, makes it available to Find & Add, and keeps checks in the background. Only actionable warnings interrupt you.'),
  )
  content.append(intro, pathBox, actions, note)
  return content
}

function renderPreferencesTab() {
  loadAgentPreferences()
  const content = element('div', 'document-tool-content')
  const intro = element('div', 'document-tool-intro')
  intro.append(
    element('h3', '', 'Preferences & glossary'),
    element('p', '', 'Control terminology, names, tone, and document conventions MoonDesk may remember.'),
  )
  const form = element('form', 'agent-preference-form')
  const draft = featureState.preference_draft
  const kind = element('select')
  for (const [value, label] of [['preference', 'Preference'], ['glossary', 'Glossary'], ['name', 'Name & spelling'], ['convention', 'Document convention']]) {
    const option = element('option', '', label)
    option.value = value
    kind.append(option)
  }
  kind.value = draft?.kind || 'preference'
  const label = element('input')
  label.placeholder = 'Short label or term'
  label.required = true
  label.value = draft?.label || ''
  const detail = element('textarea')
  detail.placeholder = 'What MoonDesk should use or remember'
  detail.required = true
  detail.value = draft?.detail || ''
  const scope = element('select')
  for (const [value, copy] of [['workspace', 'This workspace'], ['global', 'All workspaces']]) {
    const option = element('option', '', copy)
    option.value = value
    scope.append(option)
  }
  scope.value = draft?.scope || 'workspace'
  const save = element('button', 'primary-button', draft ? 'Save changes' : 'Save preference')
  save.type = 'submit'
  form.append(kind, label, detail, scope, save)
  if (draft) form.append(button('secondary-button', 'Cancel', 'preference-cancel'))
  form.addEventListener('submit', event => {
    event.preventDefault()
    if (!label.value.trim() || !detail.value.trim()) return
    saveAgentPreference({
      id: draft?.id || '',
      kind: kind.value,
      label: label.value.trim(),
      detail: detail.value.trim(),
      scope: scope.value,
      enabled: draft?.enabled !== false,
    })
    label.value = ''
    detail.value = ''
  })
  content.append(intro, form)
  const list = element('div', 'agent-preference-list')
  for (const item of featureState.preferences) {
    const row = element('article', `agent-preference-row${item.enabled === false ? ' disabled' : ''}`)
    const copy = element('div')
    copy.append(
      element('strong', '', item.label),
      element('p', '', item.detail),
      element('small', '', `${item.kind} · ${item.scope === 'global' ? 'All workspaces' : 'This workspace'}`),
    )
    const actions = element('div', 'agent-preference-actions')
    actions.append(
      button('secondary-button', 'Edit', 'preference-edit', [item.id]),
      button('secondary-button', item.enabled === false ? 'Enable' : 'Disable', 'preference-toggle', [item.id]),
      button('secondary-button', 'Forget', 'preference-forget', [item.id]),
    )
    row.append(copy, actions)
    list.append(row)
  }
  content.append(list, element('p', 'status-line', featureState.preferences_status))
  return content
}

function renderLearningTab() {
  loadLearningProposals()
  const content = element('div', 'document-tool-content learning-review')
  const intro = element('div', 'document-tool-intro with-action')
  const copy = element('div')
  copy.append(
    element('h3', '', 'Learning Review'),
    element('p', '', 'Teach this book deliberately. Nothing becomes future guidance until you accept it.'),
  )
  intro.append(copy, button('secondary-button', 'Add learning', 'learning-new'))
  content.append(intro)
  const draft = featureState.learning_draft
  if (draft) {
    const form = element('form', 'learning-proposal-form')
    const kind = element('select')
    for (const [value, label] of [
      ['knowledge', 'Knowledge'], ['preference', 'Preference'],
      ['procedure', 'Way of working'], ['capability', 'Capability idea'],
    ]) {
      const option = element('option', '', label)
      option.value = value
      kind.append(option)
    }
    kind.value = draft.kind || 'knowledge'
    const detail = element('textarea')
    detail.placeholder = 'What should this book know or do next time?'
    detail.required = true
    detail.value = draft.detail || ''
    if (draft.source) {
      const source = element('details', 'learning-source')
      source.append(element('summary', '', 'Answer that prompted this'), element('p', '', draft.source))
      form.append(source)
    }
    const actions = element('div', 'learning-proposal-actions')
    const submit = element('button', 'primary-button', 'Save for review')
    submit.type = 'submit'
    actions.append(button('secondary-button', 'Cancel', 'learning-cancel'), submit)
    form.append(kind, detail, actions)
    form.addEventListener('submit', event => {
      event.preventDefault()
      if (!detail.value.trim()) return
      saveLearningProposal({
        action: 'propose',
        kind: kind.value,
        detail: detail.value.trim(),
        source: draft.source || '',
      })
    })
    content.append(form)
  }
  const counts = learningProposalCounts(featureState.learning_proposals)
  const summary = element('div', 'learning-review-summary')
  summary.append(
    element('span', '', `${counts.proposed} to review`),
    element('span', '', `${counts.accepted} learned`),
  )
  content.append(summary)
  const list = element('div', 'learning-proposal-list')
  for (const item of featureState.learning_proposals) {
    const row = element('article', `learning-proposal-row ${item.status || 'proposed'}`)
    const heading = element('div', 'learning-proposal-heading')
    heading.append(
      element('strong', '', item.detail),
      element('span', 'learning-proposal-state', item.status === 'proposed' ? 'Review' : item.status),
    )
    row.append(
      heading,
      element('small', '', item.kind === 'procedure' ? 'Way of working' : item.kind),
    )
    if (item.source) {
      const source = element('details', 'learning-source')
      source.append(element('summary', '', 'Original answer'), element('p', '', item.source))
      row.append(source)
    }
    if (item.status === 'proposed') {
      const actions = element('div', 'learning-proposal-actions')
      actions.append(
        button('secondary-button', 'Dismiss', 'learning-reject', [item.id]),
        button('primary-button', 'Accept learning', 'learning-accept', [item.id]),
      )
      row.append(actions)
    }
    list.append(row)
  }
  if (!featureState.learning_proposals.length) {
    list.append(element(
      'p',
      'document-tool-empty',
      'No learning proposals yet. Use “Teach this book” on an answer, or add one directly.',
    ))
  }
  content.append(list, element('p', 'status-line', featureState.learning_status))
  return content
}

function renderTaskRecipesTab() {
  loadTaskRecipes()
  const content = element('div', 'document-tool-content task-recipes')
  const selected = featureState.task_recipes.find(item =>
    item.recipe_id === featureState.task_recipe_selected)
  if (!selected) {
    const intro = element('div', 'document-tool-intro')
    intro.append(
      element('h3', '', 'Start a task'),
      element('p', '', 'Choose a repeatable task and answer only the decisions it needs.'),
    )
    content.append(intro)
    const list = element('div', 'task-recipe-list')
    for (const recipe of featureState.task_recipes) {
      const card = element('article', 'task-recipe-card')
      card.append(
        element('strong', '', recipe.title),
        element('p', '', recipe.summary),
        element('small', '', recipe.deliverable),
        button('primary-button', 'Use this task', 'recipe-select', [recipe.recipe_id]),
      )
      list.append(card)
    }
    if (!featureState.task_recipes.length && !featureState.task_recipe_status) {
      list.append(element('p', 'document-tool-empty', 'No task recipes are available.'))
    }
    content.append(list, element('p', 'status-line', featureState.task_recipe_status))
    return content
  }
  const intro = element('div', 'document-tool-intro with-action')
  const copy = element('div')
  copy.append(element('h3', '', selected.title), element('p', '', selected.summary))
  intro.append(copy, button('secondary-button', 'Back', 'recipe-back'))
  const form = element('form', 'task-recipe-form')
  for (const field of selected.fields || []) {
    const label = element('label', 'task-recipe-field')
    const caption = element('span', '', field.label)
    if (field.required === true) caption.append(element('em', '', 'Required'))
    const input = element('input')
    input.name = field.key
    input.placeholder = field.placeholder || ''
    input.required = field.required === true
    label.append(caption, input)
    form.append(label)
  }
  const deliverable = element('div', 'task-recipe-deliverable')
  deliverable.append(element('strong', '', 'You will get'), element('p', '', selected.deliverable))
  const submit = element('button', 'primary-button', 'Start in chat')
  submit.type = 'submit'
  form.append(deliverable, submit)
  form.addEventListener('submit', event => {
    event.preventDefault()
    const inputs = Object.fromEntries(new FormData(form).entries())
    startTaskRecipe(selected.recipe_id, inputs)
  })
  content.append(intro, form, element('p', 'status-line', featureState.task_recipe_status))
  return content
}

function renderLivingArtifactsTab() {
  const content = element('div', 'document-tool-content living-artifacts')
  loadLivingArtifacts()
  const intro = element('div', 'document-tool-intro with-action')
  const copy = element('div')
  copy.append(
    element('h3', '', 'Living artifacts'),
    element('p', '', 'Create a book-scoped checklist, tracker, or evidence table that stays editable beside chat.'),
  )
  intro.append(copy, button('primary-button', 'Create artifact', 'living-artifact-new'))
  content.append(intro)
  if (featureState.living_artifact_draft) {
    const form = element('form', 'living-artifact-form')
    const kind = element('select')
    for (const [value, label] of [
      ['checklist', 'Checklist'], ['tracker', 'Tracker'], ['evidence-table', 'Evidence table'],
    ]) {
      const option = element('option', '', label)
      option.value = value
      kind.append(option)
    }
    const title = element('input')
    title.required = true
    title.maxLength = 160
    title.placeholder = 'Artifact name'
    const purpose = element('textarea')
    purpose.maxLength = 2000
    purpose.placeholder = 'What should this artifact help you maintain?'
    const items = element('textarea')
    items.placeholder = 'Optional starting items, one per line'
    const actions = element('div', 'living-artifact-actions')
    const submit = element('button', 'primary-button', 'Create and open')
    submit.type = 'submit'
    actions.append(
      button('secondary-button', 'Cancel', 'living-artifact-cancel'),
      submit,
    )
    form.append(
      element('label', '', 'Type'), kind,
      element('label', '', 'Name'), title,
      element('label', '', 'Purpose'), purpose,
      element('label', '', 'Starting items'), items,
      actions,
    )
    form.addEventListener('submit', event => {
      event.preventDefault()
      createLivingArtifact({
        kind: kind.value,
        title: title.value.trim(),
        purpose: purpose.value.trim(),
        items: items.value.split(/\r?\n/).map(value => value.trim()).filter(Boolean),
      })
    })
    content.append(form)
  }
  if (!featureState.living_artifacts.length && !featureState.living_artifact_status) {
    content.append(element('div', 'document-tool-empty', 'Create an artifact to keep a small working surface with this MoonBook.'))
  } else if (featureState.living_artifacts.length) {
    const list = element('div', 'living-artifact-list')
    for (const artifact of featureState.living_artifacts) {
      const card = element('article', 'living-artifact-card')
      const heading = element('div', 'living-artifact-heading')
      heading.append(
        element('strong', '', artifact.title || 'Living artifact'),
        element('span', 'living-artifact-kind', String(artifact.kind || 'artifact').replace('-', ' ')),
      )
      card.append(
        heading,
        element('p', '', artifact.purpose || 'An editable artifact for this book.'),
        element('small', '', `${Array.isArray(artifact.items) ? artifact.items.length : 0} items · revision ${Number(artifact.revision) || 1}`),
        button('secondary-button', 'Open beside chat', 'living-artifact-open', [artifact.path || '']),
      )
      list.append(card)
    }
    content.append(list)
  }
  if (featureState.living_artifact_status) {
    content.append(element('p', 'status-line', featureState.living_artifact_status))
  }
  return content
}

function renderToolbox(state) {
  const backdrop = element('div', 'document-toolbox-backdrop')
  backdrop.addEventListener('click', () => emit('close-toolbox'))
  const panel = element('aside', 'document-toolbox')
  panel.dataset.testid = 'document-toolbox'
  panel.setAttribute('role', 'dialog')
  panel.setAttribute('aria-modal', 'true')
  panel.setAttribute('aria-label', 'Document tools')
  panel.addEventListener('click', event => event.stopPropagation())
  const header = element('header', 'document-toolbox-header')
  header.append(
    heading('Current work', 'Document tools'),
    button('icon-button', '×', 'close-toolbox', [], { label: 'Close document tools' }),
  )
  const tabs = element('div', 'document-toolbox-tabs')
  tabs.setAttribute('role', 'tablist')
  for (const [id, label] of [
    ['review', 'Review'], ['tasks', 'Tasks'], ['artifacts', 'Artifacts'], ['threads', 'Conversations'], ['sources', 'Sources'],
    ['history', 'History'], ['packs', 'Check packs'], ['learning', 'Learning'],
    ['preferences', 'Preferences'], ['inbox', 'Inbox'],
  ]) {
    const tab = button(
      `document-toolbox-tab${featureState.toolbox_tab === id ? ' active' : ''}`,
      label, 'toolbox-tab', [id], { pressed: featureState.toolbox_tab === id },
    )
    tab.setAttribute('role', 'tab')
    tab.setAttribute('aria-selected', String(featureState.toolbox_tab === id))
    tabs.append(tab)
  }
  const body = ({
    review: () => renderReviewTab(state),
    tasks: renderTaskRecipesTab,
    artifacts: renderLivingArtifactsTab,
    threads: renderThreadsTab,
    sources: () => renderSourcesTab(state),
    history: renderHistoryTab,
    packs: renderPacksTab,
    learning: renderLearningTab,
    preferences: renderPreferencesTab,
    inbox: () => renderInboxTab(state),
  })[featureState.toolbox_tab]?.() || renderReviewTab(state)
  panel.append(header, tabs, body)
  backdrop.append(panel)
  return backdrop
}

function officeReviewValue(kind, item) {
  if (kind === 'xlsx') {
    return item.text + (item.formula ? `\nFormula: ${item.formula}` : '')
  }
  if (kind === 'pptx') {
    return `${item.text}\nFrame: ${item.x}, ${item.y} · ${item.width} × ${item.height}`
  }
  const styles = [item.bold && 'bold', item.italic && 'italic', item.underline && 'underline']
    .filter(Boolean).join(', ')
  return `${item.text}\nStyles: ${styles || 'none'}`
}

function officeReviewChanges(state) {
  const { before, after, kind } = state
  const changes = []
  if (before.text !== after.text) changes.push('Text changed')
  if (kind === 'xlsx' && before.formula !== after.formula) changes.push('Formula changed')
  if (kind === 'docx' && [
    ['bold', 'Bold'], ['italic', 'Italic'], ['underline', 'Underline'],
  ].some(([key]) => before[key] !== after[key])) changes.push('Formatting changed')
  if (kind === 'pptx' && (before.x !== after.x || before.y !== after.y)) {
    changes.push('Position changed')
  }
  if (kind === 'pptx' &&
    (before.width !== after.width || before.height !== after.height)) {
    changes.push('Size changed')
  }
  return changes
}

function renderOfficeReviews() {
  for (const host of document.querySelectorAll('[data-testid="office-change-review-host"]')) {
    let state
    try {
      state = JSON.parse(host.dataset.state || '{}')
    } catch {
      continue
    }
    host.replaceChildren()
    if (!state.visible) continue
    const changes = officeReviewChanges(state)
    const review = element('section', 'office-change-review')
    review.dataset.testid = 'office-change-review'
    review.setAttribute('aria-label', 'Review document change')
    const header = element('div', 'office-change-review-heading')
    const title = element('div')
    title.append(
      element('p', 'eyebrow', 'Review before applying'),
      element('h3', '', `${state.section} · ${state.reference}`),
    )
    header.append(title, element('span', 'office-change-count', `${changes.length} changes`))
    const chips = element('div', 'office-change-summary')
    for (const change of changes) chips.append(element('span', '', change))
    const columns = element('div', 'office-change-columns')
    for (const [label, className, item] of [
      ['Before', 'before', state.before], ['Proposed', 'after', state.after],
    ]) {
      const side = element('div', `office-change-side ${className}`)
      side.append(element('strong', '', label), element('pre', '', officeReviewValue(state.kind, item)))
      columns.append(side)
    }
    const actions = element('div', 'office-change-actions')
    actions.append(
      button('secondary-button', 'Reject change', 'office-discard', [], { disabled: state.saving }),
      button(
        'primary-button', state.saving ? 'Applying…' : 'Apply change', 'office-save', [],
        { disabled: state.saving },
      ),
    )
    review.append(
      header,
      chips,
      columns,
      actions,
      element(
        'p', 'office-change-note',
        'MoonDesk validates the saved package and preserves unsupported Office features.',
      ),
    )
    host.append(review)
  }
}

function renderAutomationCards() {
  for (const host of document.querySelectorAll('[data-testid="automation-card-host"]')) {
    let state
    try {
      state = JSON.parse(host.dataset.state || '{}')
    } catch {
      continue
    }
    const card = element('article', `automation-card ${state.enabled ? 'active' : 'paused'}`)
    card.dataset.automationId = state.id
    const header = element('div', 'automation-card-heading')
    const title = element('div')
    title.append(element('strong', '', state.title), element('small', '', state.book))
    header.append(
      title,
      element(
        'span', `automation-state ${state.enabled ? 'active' : 'paused'}`,
        state.enabled ? 'Active' : 'Paused',
      ),
    )
    const facts = element('div', 'automation-facts')
    const last = state.last == null ? 'Not run yet' : `Last run at tick ${state.last}`
    facts.append(
      element('span', '', `Every ${state.cadence} ticks`),
      element('span', '', `Next · ${state.next}`),
      element('span', '', last),
    )
    const policies = element('details', 'automation-why')
    policies.append(element('summary', '', 'Why this runs and what it may use'))
    const definition = element('div', 'automation-definition-list')
    for (const [label, value] of [
      ['Sources', state.sources], ['Review', state.review], ['Book', state.book],
    ]) definition.append(element('strong', '', label), element('span', '', value))
    policies.append(definition)
    const actions = element('div', 'automation-card-actions')
    actions.append(
      button(
        'secondary-button', 'Run once now', 'run-goal', [state.id],
        { disabled: !state.enabled },
      ),
      button('secondary-button', 'View results', 'destination', ['runs']),
    )
    card.append(
      header,
      element('p', 'automation-purpose', state.prompt),
      facts,
      policies,
      actions,
    )
    host.replaceChildren(card)
  }
}

function renderQueuedFollowups() {
  const composer = document.querySelector('.wiki-chat-composer')
  if (!(composer instanceof HTMLElement)) return
  composer.querySelector(':scope > .wiki-chat-followups')?.remove()
  if (!featureState.queued_followups.length) return
  const tray = element('section', 'wiki-chat-followups')
  tray.dataset.testid = 'wiki-chat-followups'
  tray.append(element('strong', '', 'Up next'))
  for (const [index, item] of featureState.queued_followups.entries()) {
    const sending = item.state === 'sending'
    const row = element('div', `wiki-chat-followup${sending ? ' sending' : ''}`)
    const input = element('textarea')
    input.value = item.text
    input.rows = 2
    input.disabled = sending
    input.setAttribute('aria-label', `Queued follow-up ${index + 1}`)
    input.addEventListener('change', () => emit('followup-edit', item.id, input.value))
    const actions = element('div', 'wiki-chat-followup-actions')
    actions.append(
      button('icon-button', '↑', 'followup-move', [item.id, 'up'], { disabled: index === 0, label: 'Move follow-up earlier' }),
      button('icon-button', '↓', 'followup-move', [item.id, 'down'], { disabled: index === featureState.queued_followups.length - 1, label: 'Move follow-up later' }),
      button('secondary-button', sending ? 'Sending…' : 'Send now', 'followup-send-now', [item.id], { disabled: sending }),
      button('secondary-button', 'Delete', 'followup-delete', [item.id], { disabled: sending }),
    )
    row.append(input, actions)
    tray.append(row)
  }
  const actions = composer.querySelector(':scope > .wiki-chat-actions')
  composer.insertBefore(tray, actions || null)
}

function trySelectTypedLocation(value) {
  const path = String(value?.workspace_path || '')
  if (!path || serverState.selected_document !== path) return false
  if (/\.pdf$/i.test(path) && Number(value.page) > 0) {
    const frame = document.querySelector('[data-testid="pdf-preview-frame"]')
    if (!(frame instanceof HTMLIFrameElement)) return false
    const url = new URL(frame.src, globalThis.location?.href || 'http://127.0.0.1/')
    url.hash = `page=${Math.floor(Number(value.page))}`
    frame.src = url.href
    featureState.pending_source_location = null
    return true
  }
  if (serverState.office?.path !== path) return false
  const items = serverState.office?.draft_items || []
  const index = items.findIndex(item =>
    (value.cell_range && item.reference === value.cell_range) ||
    (value.anchor && item.reference === value.anchor) ||
    (value.sheet && item.section === value.sheet) ||
    (value.section && item.section === value.section) ||
    (Number(value.slide) > 0 && Number(item.section_index) + 1 === Number(value.slide)) ||
    (Number(value.page) > 0 && Number(item.section_index) + 1 === Number(value.page)))
  if (index < 0) return false
  const buttons = document.querySelectorAll('.wiki-office-navigation .wiki-office-nav-item')
  if (!(buttons[index] instanceof HTMLButtonElement)) return false
  buttons[index].click()
  featureState.pending_source_location = null
  return true
}

function renderTypedChatFragments() {
  if (featureState.pending_source_location) trySelectTypedLocation(featureState.pending_source_location)
  const thread = document.querySelector('[data-testid="wiki-chat-thread"]')
  if (!(thread instanceof HTMLElement)) return
  for (const host of thread.querySelectorAll(':scope > .wiki-chat-fragment')) {
    const payload = host.dataset.payload || ''
    if (!payload || featureState.dismissed_fragments.has(payload)) {
      host.remove()
      continue
    }
    let value
    try { value = JSON.parse(payload) } catch {
      host.remove()
      continue
    }
    const kind = host.dataset.kind || value.kind || ''
    host.className = kind === 'automation_suggestion'
      ? 'wiki-chat-automation-suggestion'
      : kind === 'preference_usage'
        ? 'wiki-chat-preference-usage'
        : kind === 'background_result'
          ? `wiki-chat-background-result${value.warning ? ' warning' : ''}`
        : `wiki-chat-reference ${kind === 'artifact_ref' ? 'artifact' : 'source'}`
    if (kind === 'source_ref') {
      const path = String(value.workspace_path || '')
      const copy = element('div')
      copy.append(
        element('strong', '', value.label || path.split('/').pop() || 'Source'),
        element('small', '', [path, typedLocationLabel(value)].filter(Boolean).join(' · ')),
      )
      host.replaceChildren(
        copy,
        button('secondary-button', 'Open exact location', 'typed-source', [payload], { disabled: !path }),
      )
    } else if (kind === 'artifact_ref') {
      const path = String(value.path || value.workspace_path || '')
      const copy = element('div')
      copy.append(
        element('strong', '', path.split('/').pop() || 'Generated artifact'),
        element('small', '', value.mime_type || 'Generated file'),
      )
      host.replaceChildren(copy, button('secondary-button', 'Open', 'typed-artifact', [payload], { disabled: !path }))
    } else if (kind === 'background_result') {
      const copy = element('div')
      copy.append(
        element('strong', '', value.warning ? 'Background check needs attention' : 'Background check completed'),
        element('p', '', value.summary || 'The scheduled work completed.'),
        element('small', '', [value.decision, value.run_id].filter(Boolean).join(' · ')),
      )
      host.replaceChildren(
        copy,
        button(
          'secondary-button', value.path ? 'Open result' : 'View work',
          value.path ? 'open-path' : 'destination',
          [value.path || 'runs'],
        ),
      )
    } else if (kind === 'preference_usage') {
      const count = Math.max(0, Number(value.count) || 0)
      host.replaceChildren(
        element('span', '', `Used ${count} ${count === 1 ? 'preference' : 'preferences'}`),
        button('secondary-button', 'Review', 'toolbox-tab', ['preferences']),
      )
    } else if (kind === 'automation_suggestion') {
      const facts = element('div', 'wiki-chat-automation-facts')
      facts.append(
        element('span', '', `Reads · ${value.reads || 'Only the selected workspace material'}`),
        element('span', '', `Cadence · ${value.cadence || 'As requested'}`),
        element('span', '', `Notify · ${value.notify_when || 'Only when your attention is required'}`),
      )
      const actions = element('div', 'wiki-chat-reference-actions')
      actions.append(
        button('primary-button', 'Confirm', 'typed-automation-confirm', [payload]),
        button('secondary-button', 'Not now', 'typed-automation-dismiss', [payload]),
      )
      host.replaceChildren(
        element('strong', '', value.title || 'Repeat this work?'),
        element('p', '', value.summary || 'MoonDesk can run this quietly in the background.'),
        facts,
        actions,
      )
    }
  }
}

function renderDocumentMap(state) {
  const viewer = document.querySelector('.wiki-document-viewer')
  if (!(viewer instanceof HTMLElement)) return
  viewer.querySelector(':scope > .document-review-map')?.remove()
  const markers = reviewMarkers(state)
  if (!markers.length || !state.selected_document) return
  const open = markers.filter(marker => !marker.reviewed)
  const rail = element('aside', 'document-review-map')
  rail.dataset.testid = 'document-review-map'
  rail.setAttribute('aria-label', 'Document review map')
  const header = button(
    'document-review-map-header', `${open.length} open`, 'toolbox-tab', ['review'],
    { label: 'Open document review map' },
  )
  rail.append(header)
  const dots = element('div', 'document-review-map-dots')
  for (const marker of markers.slice(0, 28)) {
    dots.append(button(
      `document-review-map-dot ${marker.type}${marker.reviewed ? ' reviewed' : ''}`,
      '', 'jump-marker', [marker.anchor],
      { label: `${marker.title}. ${marker.detail}`, title: marker.title },
    ))
  }
  rail.append(dots)
  viewer.append(rail)
}

function enhanceChatMessages(state) {
  const thread = document.querySelector('[data-testid="wiki-chat-thread"]')
  if (!(thread instanceof HTMLElement)) return
  const nodes = Array.from(thread.querySelectorAll(':scope > .wiki-chat-message'))
  const entries = (state.chat || []).filter(entry =>
    String(entry.content || '').trim() &&
    !['source_ref', 'artifact_ref', 'automation_suggestion', 'preference_usage', 'background_result'].includes(entry.role))
  for (const [index, node] of nodes.entries()) {
    const entry = entries[index]
    if (!entry || entry.role === 'user' || entry.role === 'assistant-stream') continue
    const signature = `${entry.role}:${String(entry.content || '').length}:${String(entry.content || '').slice(-64)}`
    if (chatEnhancementSignatures.get(node) === signature) continue
    chatEnhancementSignatures.set(node, signature)
    node.dataset.messageIndex = String(index)
    node.querySelector(':scope > .workspace-answer-actions')?.remove()
    node.querySelector(':scope > .workspace-answer-citations')?.remove()
    const actions = element('div', 'workspace-answer-actions')
    const encoded = encodeURIComponent(entry.content)
    actions.append(
      button('answer-action', 'Copy', 'copy-answer', [encoded], { label: 'Copy answer as Markdown' }),
      button('answer-action', 'Use in document', 'use-answer', [encoded]),
      button('answer-action', 'Pin', 'pin-answer', [encoded], { label: 'Pin answer to synthesis' }),
      button('answer-action', 'Try another version', 'try-another', [encoded]),
      button('answer-action', 'Teach this book', 'teach-answer', [encoded]),
    )
    node.append(actions)
    const citations = sourceEntries({ ...state, chat: [entry] })
    if (citations.length) {
      const list = element('div', 'workspace-answer-citations')
      list.append(element('span', '', 'Sources'))
      for (const source of citations.slice(0, 8)) {
        if (source.type === 'web') {
          const link = element('a', 'citation-chip', source.label)
          link.href = source.value
          link.target = '_blank'
          link.rel = 'noreferrer'
          list.append(link)
        } else {
          list.append(button('citation-chip', source.label, 'open-path', [source.value]))
        }
      }
      node.append(list)
    }
  }
}

function selectionAnchorFromTarget(target, selectedText = '') {
  const node = target instanceof Element ? target.closest('[data-document-anchor]') : null
  if (!(node instanceof HTMLElement)) return null
  const text = boundedText(selectedText || node.textContent || '', 2400)
  if (!text) return null
  return {
    path: serverState.selected_document || '',
    index: node.dataset.documentAnchor || '',
    kind: node.dataset.anchorKind || 'text',
    section: node.dataset.anchorSection || '',
    reference: node.dataset.anchorReference || '',
    text,
  }
}

function captureDocumentSelection(event, useWholeAnchor = false) {
  const selection = globalThis.getSelection?.()
  const selectedText = selection?.toString().trim() || ''
  if (!useWholeAnchor && !selectedText) return
  const anchor = selectionAnchorFromTarget(event.target, useWholeAnchor ? '' : selectedText)
  if (!anchor) return
  featureState.active_anchor = anchor
  featureState.selection_toolbar = {
    x: Math.min(event.clientX || globalThis.innerWidth / 2, globalThis.innerWidth - 260),
    y: Math.min(event.clientY || 140, globalThis.innerHeight - 90),
  }
  render()
}

function renderSelectionToolbar() {
  if (!featureState.selection_toolbar || !featureState.active_anchor) return null
  const toolbar = element('div', 'document-selection-toolbar')
  toolbar.dataset.testid = 'document-selection-toolbar'
  toolbar.setAttribute('role', 'toolbar')
  toolbar.setAttribute('aria-label', 'Ask MoonDesk about selection')
  toolbar.style.left = `${Math.max(12, featureState.selection_toolbar.x)}px`
  toolbar.style.top = `${Math.max(12, featureState.selection_toolbar.y)}px`
  for (const [id, label] of [
    ['ask', 'Ask'], ['explain', 'Explain'], ['check', 'Check'], ['improve', 'Improve'], ['source', 'Use as source'], ['comment', 'Comment'],
  ]) toolbar.append(button('selection-action', label, 'selection-action', [id]))
  return toolbar
}

function render() {
  const root = document.querySelector(rootSelector)
  if (!(root instanceof HTMLElement)) return
  let nextServerState
  try {
    nextServerState = JSON.parse(root.dataset.state || '{}')
  } catch {
    return
  }
  const previousChat = Array.isArray(serverState.chat) ? serverState.chat : []
  const previousChatFingerprint = serverState.chat_projection_fingerprint || ''
  nextServerState.chat = projectChatFromDom(
    nextServerState,
    previousChat,
    previousChatFingerprint,
  )
  nextServerState.chat_projection_fingerprint = chatProjectionFingerprint(nextServerState)
  serverState = nextServerState
  const followupIdentity = `${serverState.workspace_id || ''}:${serverState.task_id || ''}`
  if (featureState.followup_identity !== followupIdentity) {
    featureState.followup_identity = followupIdentity
    featureState.last_task_busy = null
    loadQueuedFollowups()
  }
  const backgroundIdentity = `${serverState.workspace_id || ''}::${serverState.task_id || ''}`
  if (featureState.background_results_identity !== backgroundIdentity) {
    featureState.background_results_identity = backgroundIdentity
    featureState.background_result_ids = new Set(
      (serverState.chat || []).filter(entry => entry.role === 'background_result').map(entry => {
        try { return String(JSON.parse(entry.content || '{}').id || '') } catch { return '' }
      }).filter(Boolean),
    )
    loadDocumentAutomationResults()
  }
  loadServerThreads()
  maybeRestoreCurrentThread()
  persistCurrentThread()
  persistOfficeHistory()
  const state = { ...serverState, ...featureState }
  if (isLivingArtifactPath(state.selected_document)) {
    ensureLivingArtifactRuntime().catch(() => {})
  }
  if (state.mode === 'code') {
    state.hits = (state.hits || []).filter(hit =>
      /\.(mbt|js|mjs|ts|tsx)$/i.test(hit.path))
  }
  if (state.purpose === 'document') {
    state.hits = (state.hits || []).filter(hit => /\.(docx|xlsx|pptx|pdf)$/i.test(hit.path))
  }
  root.replaceChildren()
  if (state.search_open) root.append(renderSearch(state))
  if (state.synthesis_open) root.append(renderSynthesis(state))
  if (state.toolbox_open) root.append(renderToolbox(state))
  const selectionToolbar = renderSelectionToolbar()
  if (selectionToolbar) root.append(selectionToolbar)
  if (state.export_status) {
    const status = element('p', 'visually-hidden workspace-export-status', state.export_status)
    status.setAttribute('role', 'status')
    root.append(status)
  }
  renderOfficeReviews()
  renderAutomationCards()
  renderQueuedFollowups()
  renderTypedChatFragments()
  const currentBusy = taskIsBusy()
  const shouldSendFollowup = shouldAutoSendFollowup(
    featureState.last_task_busy,
    currentBusy,
    featureState.suppress_followup_auto_once,
  )
  featureState.last_task_busy = currentBusy
  featureState.suppress_followup_auto_once = false
  if (shouldSendFollowup) maybeSendNextFollowup()
  renderDocumentMap(state)
  enhanceChatMessages(state)
}

function workPackageFromState() {
  const work = serverState.work || []
  const runs = work.filter(item => item.type === 'run').map(run => ({
    id: run.run_id,
    status: run.status,
    phase: run.phase,
    summary: run.title,
    artifacts: work.filter(item =>
      item.type === 'artifact' && item.run_id === run.run_id).map(item => ({
      title: item.title,
      path: item.path,
    })),
  }))
  return {
    contract: 'moondesk.work-package.v1',
    title: `${serverState.workspace || 'MoonDesk workspace'} — Work Package`,
    workspace: serverState.workspace || 'MoonDesk workspace',
    selected_document: serverState.selected_document || '',
    chat: serverState.chat || [],
    conversations: currentThreads().map(thread => ({
      id: thread.id,
      title: thread.title,
      document: thread.document,
      updated_at: new Date(thread.updated_at).toISOString(),
      archived: thread.archived === true,
      chat: thread.chat || [],
    })),
    runs,
    reviews: work.filter(item => item.type === 'review').map(item => ({
      title: item.title.replace(/^Review · /, ''),
      path: item.path,
      status: item.status,
      detail: item.detail,
    })),
    sources: featureState.synthesis.map(item => ({
      title: item.title,
      path: item.path,
      kind: item.kind,
    })),
    warnings: work.filter(item =>
      item.type === 'event' && ['warning', 'error'].includes(item.severity)).map(item => ({
      title: item.title,
      detail: item.detail,
      path: item.path,
    })),
    evidence: sourceEntries(),
    document_history: currentHistory().map(version => ({
      id: version.id,
      label: version.label,
      kind: version.kind,
      created_at: new Date(version.created_at).toISOString(),
      baseline: version.baseline,
    })),
    enabled_check_packs: Array.from(enabledPackIds()),
  }
}

globalThis.__moondeskWorkspaceFeatureSignal = (action, value = '') => {
  if (action === 'open-search') {
    featureState.search_open = true
    featureState.synthesis_open = false
    featureState.purpose = value || 'open'
    featureState.mode = value === 'document' ? 'files' : value === 'attach' ? 'work' : featureState.mode
    featureState.query = serverState.query || ''
  } else if (action === 'open-synthesis') {
    featureState.search_open = false
    featureState.synthesis_open = true
  } else if (action === 'open-toolbox') {
    featureState.search_open = false
    featureState.synthesis_open = false
    featureState.toolbox_open = true
    featureState.toolbox_tab = value || 'review'
  } else if (action === 'open-recipe') {
    featureState.search_open = false
    featureState.synthesis_open = false
    featureState.toolbox_open = true
    featureState.toolbox_tab = 'tasks'
    featureState.task_recipe_selected = ''
    featureState.task_recipe_status = ''
    loadTaskRecipes()
  } else if (action === 'synthesis-error') {
    featureState.synthesis_open = true
    featureState.synthesis_status = value
  } else if (action === 'followup-submitted') {
    emit('followup-submitted', value)
    return
  } else if (action === 'followup-failed') {
    emit('followup-failed', value)
    return
  } else if (action === 'export') {
    try {
      globalThis.__moondeskDownloadWorkPackage?.(
        JSON.stringify(workPackageFromState()),
      )
      featureState.export_status = 'Work Package download started'
    } catch (error) {
      featureState.export_status = 'Work Package download could not start'
      console.error(error)
    }
  }
  render()
}

for (const [action, value] of globalThis.__moondeskPendingWorkspaceFeatureSignals || []) {
  globalThis.__moondeskWorkspaceFeatureSignal(action, value)
}
globalThis.__moondeskPendingWorkspaceFeatureSignals = []

const observer = typeof MutationObserver === 'function' ? new MutationObserver(records => {
  if (records.some(record => {
    if (record.type === 'attributes' && record.attributeName === 'data-state') return true
    if (record.type !== 'childList') return false
    return Array.from(record.addedNodes).some(node =>
      node instanceof Element &&
      (node.matches(rootSelector) || node.querySelector(rootSelector) ||
        node.matches('[data-testid="office-change-review-host"]') ||
        node.querySelector('[data-testid="office-change-review-host"]') ||
        node.matches('[data-testid="automation-card-host"]') ||
        node.querySelector('[data-testid="automation-card-host"]')))
  })) {
    queueMicrotask(render)
  }
}) : null

function install() {
  observer?.observe(document.documentElement, {
    subtree: true,
    childList: true,
    attributes: true,
    attributeFilter: ['data-state'],
  })
  document.addEventListener('click', event => {
    const send = event.target instanceof Element
      ? event.target.closest('[data-testid="wiki-chat-send"]')
      : null
    if (!send || !taskIsBusy()) return
    const prompt = String(serverState.request_prompt || '').trim()
    if (!prompt) return
    event.preventDefault()
    event.stopImmediatePropagation()
    queueFollowup(prompt)
  }, true)
  document.addEventListener('pointerup', event => {
    if (event.target instanceof Element && event.target.closest('.office-supported-preview')) {
      captureDocumentSelection(event)
    }
  })
  document.addEventListener('dblclick', event => {
    if (event.target instanceof Element && event.target.closest('[data-document-anchor]')) {
      captureDocumentSelection(event, true)
    }
  })
  document.addEventListener('pointerdown', event => {
    if (!featureState.selection_toolbar) return
    if (event.target instanceof Element && event.target.closest('.document-selection-toolbar')) return
    featureState.selection_toolbar = null
  })
  document.addEventListener('keydown', event => {
    if (event.key !== 'Escape') return
    featureState.selection_toolbar = null
    if (featureState.toolbox_open) featureState.toolbox_open = false
    if (featureState.search_open) featureState.search_open = false
    if (featureState.synthesis_open) featureState.synthesis_open = false
    render()
  })
  render()
}

globalThis.__moondeskDownloadWorkPackage = payload => {
  const data = JSON.parse(payload)
  const esc = value => String(value ?? '').replace(/[&<>"']/g, character => ({
    '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;',
  })[character])
  const section = (title, rows, renderRow) => rows?.length
    ? `<section><h2>${esc(title)}</h2>${rows.map(renderRow).join('')}</section>`
    : ''
  const html = `<!doctype html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width"><title>${esc(data.title)}</title><style>
body{font:15px/1.55 Inter,system-ui,sans-serif;max-width:920px;margin:0 auto;padding:48px 28px;color:#1f2937;background:#fff}header{border-bottom:2px solid #dbe4ee;padding-bottom:22px;margin-bottom:30px}h1{font-size:30px;margin:0 0 8px}h2{font-size:18px;margin-top:34px}article,.row{padding:12px 0;border-bottom:1px solid #e6ebf0}.meta{color:#667085;font-size:13px}.user{background:#f3f7fd;padding:12px;border-radius:8px}.warning{border-left:3px solid #b7791f;padding-left:12px}code{font-family:ui-monospace,monospace}@media print{body{padding:18px}}</style></head><body>
<header><div class="meta">MoonDesk Work Package · ${esc(data.contract)}</div><h1>${esc(data.title)}</h1><div class="meta">Document: ${esc(data.selected_document || 'None selected')}</div></header>
	${section('Conversation', data.chat, row => `<article class="${row.role === 'user' ? 'user' : ''}"><strong>${esc(row.role === 'user' ? 'You' : 'MoonDesk')}</strong><div>${esc(row.content).replace(/\n/g, '<br>')}</div></article>`)}
	${section('Conversation archive', data.conversations, row => `<div class="row"><strong>${esc(row.title)}</strong><div class="meta">${esc(row.document || 'Workspace')} · ${esc(row.updated_at)}${row.archived ? ' · Archived' : ''}</div></div>`)}
${section('Completed work', data.runs, row => `<div class="row"><strong>${esc(row.summary || row.id)}</strong><div class="meta">${esc(row.status)} · ${esc(row.phase)}</div>${(row.artifacts || []).map(artifact => `<div><code>${esc(artifact.path)}</code> — ${esc(artifact.title)}</div>`).join('')}</div>`)}
${section('Review decisions', data.reviews, row => `<div class="row"><strong>${esc(row.title)}</strong><div>${esc(row.detail)}</div><div class="meta">${esc(row.status)} · ${esc(row.path)}</div></div>`)}
	${section('Pinned sources', data.sources, row => `<div class="row"><strong>${esc(row.title)}</strong><div class="meta">${esc(row.kind)} · ${esc(row.path)}</div></div>`)}
	${section('Evidence', data.evidence, row => `<div class="row"><strong>${esc(row.label)}</strong><div class="meta">${esc(row.type)} · ${esc(row.value)}</div></div>`)}
	${section('Document history', data.document_history, row => `<div class="row"><strong>${esc(row.label)}</strong><div class="meta">${esc(row.kind)} · ${esc(row.created_at)} · ${esc(row.baseline)}</div></div>`)}
${section('Warnings', data.warnings, row => `<div class="row warning"><strong>${esc(row.title)}</strong><div>${esc(row.detail)}</div><div class="meta">${esc(row.path)}</div></div>`)}
</body></html>`
  const blob = new Blob([html], { type: 'text/html;charset=utf-8' })
  const url = URL.createObjectURL(blob)
  const link = document.createElement('a')
  const stem = String(data.workspace || 'moondesk-work').toLowerCase()
    .replace(/[^a-z0-9]+/g, '-').replace(/^-|-$/g, '') || 'moondesk-work'
  link.href = url
  link.download = `${stem}-work-package.html`
  document.body.append(link)
  link.click()
  setTimeout(() => {
    link.remove()
    URL.revokeObjectURL(url)
  }, 1000)
}

if (typeof document !== 'undefined') {
  globalThis.addEventListener('moondesk-workspace-features-ready', render)
  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', install, { once: true })
  } else {
    install()
  }
}

export {
  boundedText,
  changeCategory,
  chatProjectionFingerprint,
  conversationPersistenceFingerprint,
  historyChanges,
  learningProposalCounts,
  learningProposalTransition,
  mergeFollowupQueues,
  modeLabel,
  officeReviewChanges,
  projectChatFromDom,
  reviewPackageFromState,
  reviewPackageHtml,
  reviewRoomProjection,
  shouldAutoSendFollowup,
  shouldRestoreDocumentThread,
  sourceSubscriptionCounts,
  sourceSubscriptionTransition,
  taskRecipeMissingFields,
  typedSourceEntries,
  typedLocationLabel,
}
