const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c])

export function renderKnowledgeEmbeddingSettings(state) {
  const config = state.data?.embeddings || {}
  return `<details class="coding-setup-embedding-settings"><summary>Semantic search ${config.configured ? '· Provider configured' : '· Optional'}</summary><p>Connect an OpenAI-compatible embeddings endpoint to combine phrase matching with semantic similarity. Re-extract or save sources after configuring or changing the model. This embedding connection is shared by books using this MoonSuite.</p><div class="coding-setup-preset-form"><label>Embeddings endpoint<input type="url" name="knowledge-embedding-url" value="${escape(config.url || '')}" placeholder="https://example.com/v1/embeddings"></label><label>Embedding model<input name="knowledge-embedding-model" value="${escape(config.model || '')}" placeholder="embedding-model"></label><label>API token (optional)<input type="password" name="knowledge-embedding-token" autocomplete="new-password" placeholder="${config.has_token ? 'Saved token — leave blank to keep' : 'Optional API token'}"></label><button type="button" data-action="knowledge-save-embeddings">Save embedding connection</button></div><p class="coding-setup-hint">Clear the endpoint to use text search only. Indexing and semantic queries send searchable text to this provider.</p></details>`
}

export function captureKnowledgeDraft(state) {
  const title = state.root.querySelector('[name="knowledge-title"]')
  if (!title) return
  state.knowledgeDraft = {
    ...state.knowledgeDraft,
    title: title.value,
    path: state.root.querySelector('[name="knowledge-path"]').value,
    extracted_text: state.root.querySelector('[name="knowledge-text"]').value,
  }
}

export function renderKnowledge(state) {
  const records = state.data.knowledge || [], draft = state.knowledgeDraft || {}
  const raw = draft.path ? `/api/workspaces/${encodeURIComponent(state.workspaceId)}/raw?path=${encodeURIComponent(draft.path)}` : ''
  const retrieval = state.knowledgeRetrieval === 'hybrid' ? 'Last search combined semantic similarity and text matches.' : state.data.embeddings?.configured ? 'Embedding provider configured. Sources need a saved semantic index before hybrid search is available.' : 'Ranked text retrieval · Embeddings are not configured.'
  return `<p>Build a reference library for coding work. Text and Office documents are extracted into searchable passages. Relevant passages are included with source citations in subsequent coding turns.</p>
    <div class="coding-setup-skill-grid"><aside aria-label="Knowledge sources"><button type="button" data-action="knowledge-new">Add source</button>
    ${records.map((record, index) => `<button type="button" class="coding-setup-skill" data-action="knowledge-select" data-index="${index}">${escape(record.title)}<small>${record.chunks?.length || 0} passages${record.embedding_key ? ' · Semantic index' : ''}${record.enabled ? '' : ' · Paused'}</small></button>`).join('')}</aside>
    <div><label>Source title<input name="knowledge-title" value="${escape(draft.title || '')}" placeholder="Architecture notes"></label>
    <label>File in this book<input name="knowledge-path" value="${escape(draft.path || '')}" placeholder="docs/architecture.md"></label>
    <div class="coding-setup-actions"><button type="button" data-action="knowledge-index">Extract from file</button>${raw ? `<a href="${escape(raw)}" target="_blank" rel="noopener">Open original</a>` : ''}</div>
    <label>Searchable text<textarea name="knowledge-text" rows="12">${escape(draft.extracted_text || '')}</textarea></label>
    <div class="coding-setup-actions"><button type="button" data-action="knowledge-save">Save searchable text</button>${draft.id ? '<button type="button" data-action="knowledge-remove">Remove from library</button>' : ''}</div>
    <p class="coding-setup-hint">Editing searchable text does not change the original file. Re-extract after the original changes.</p></div></div>
    <hr><label>Find a passage<input name="knowledge-query" value="${escape(state.knowledgeQuery || '')}" placeholder="How does authentication work?"></label>
    <button type="button" data-action="knowledge-search">Search library</button><p class="coding-setup-hint">${escape(retrieval)}</p>
    <div>${(state.knowledgeHits || []).map((hit, index) => `<article class="coding-setup-knowledge-hit"><strong>${escape(hit.citation)}</strong><p>${escape(hit.path)}</p><pre>${escape(hit.text)}</pre><button type="button" data-action="knowledge-context" data-index="${index}">Add passage to conversation</button></article>`).join('')}</div>`
}

export async function knowledgeAction(state, button) {
  const workspaceId = state.workspaceId
  const action = button.dataset.action, index = Number(button.dataset.index)
  const records = state.data.knowledge || []
  if (action === 'knowledge-save-embeddings') {
    const get = name => state.root.querySelector(`[name="${name}"]`).value
    const response = await fetch(`/api/mooncode/setup/${encodeURIComponent(workspaceId)}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'save-embeddings', url: get('knowledge-embedding-url'), model: get('knowledge-embedding-model'), token: get('knowledge-embedding-token') }) })
    const result = await response.json()
    if (!response.ok) throw new Error(typeof result.error === 'string' ? result.error : result.message || 'Could not save embedding configuration.')
    if (workspaceId !== state.workspaceId) return ''
    state.data = result
    return result.embeddings.configured ? 'Embedding provider saved. Re-extract or save sources to build their semantic index.' : 'Semantic search disabled; text search remains available.'
  }
  const draft = state.knowledgeDraft || {}
  if (action === 'knowledge-new') { state.knowledgeDraft = {}; return 'Add a file path or paste reference text.' }
  if (action === 'knowledge-select') { state.knowledgeDraft = structuredClone(records[index]); return '' }
  if (action === 'knowledge-context') {
    const hit = state.knowledgeHits[index]
    globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'knowledge', label: hit.citation, text: `${hit.citation}\nSource: ${hit.path}\n${hit.text}`, path: hit.path, workspaceId: state.workspaceId } }))
    return 'Passage added with its source citation.'
  }
  const payload = action === 'knowledge-search' ? { action: 'search', query: state.root.querySelector('[name="knowledge-query"]').value } : {
    action: action === 'knowledge-index' ? 'index' : action === 'knowledge-remove' ? 'remove' : 'save-text',
    id: draft.id || '', title: draft.title || draft.path || 'Reference', path: draft.path || '', text: draft.extracted_text || '', enabled: true,
  }
  if (payload.action === 'search') state.knowledgeQuery = payload.query
  const response = await fetch(`/api/mooncode/knowledge/${encodeURIComponent(state.workspaceId)}`, { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload) })
  const result = await response.json()
  if (!response.ok) throw new Error(typeof result.error === 'string' ? result.error : result.message || 'Could not update the knowledge library.')
  if (state.workspaceId !== workspaceId) return ''
  if (result.hits) {
    state.knowledgeHits = result.hits; state.knowledgeRetrieval = result.retrieval
    return result.semantic_error ? `${result.semantic_error}. Showing text matches.` : result.hits.length ? `Found ${result.hits.length} passages using ${result.retrieval === 'hybrid' ? 'hybrid semantic and text' : 'ranked text'} search.` : 'No matching passages. Try a phrase used in your sources.'
  }
  state.data.knowledge = result.records
  state.knowledgeDraft = result.records.find(item => item.id === draft.id || item.path === draft.path && item.title === payload.title) || {}
  if (state.knowledgeDraft.semantic_error) return `Text saved. ${state.knowledgeDraft.semantic_error}`
  return payload.action === 'remove' ? 'Source removed from the library.' : 'Knowledge source saved and available to coding conversations.'
}
