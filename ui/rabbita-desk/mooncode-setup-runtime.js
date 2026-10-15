import { captureKnowledgeDraft, renderKnowledge, renderKnowledgeEmbeddingSettings, knowledgeAction } from './mooncode-knowledge-runtime.js'
import { iconMarkup } from './ui-icons.js'

const panels = new WeakMap()
const retainedDrafts = new Map()
const retainedFieldNames = ['new-file-path', 'preset-name', 'preset-model', 'preset-reasoning', 'preset-intent', 'integration-id', 'integration-url', 'integration-token', 'knowledge-embedding-url', 'knowledge-embedding-model', 'knowledge-embedding-token', 'knowledge-query']
const defaultLoads = new WeakMap()
const escape = value => String(value ?? '').replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' })[c])
const template = '---\nname: review-changes\ndescription: Review changes for correctness and clarity.\n---\n\n# Review changes\n\nDescribe when and how the agent should use this skill.\n'
const sections = [
  ['skills', 'Skills', 'files'], ['instructions', 'Instructions', 'book'],
  ['knowledge', 'Knowledge', 'search'], ['presets', 'Models', 'settings'],
  ['prompts', 'Prompts', 'chat'], ['integrations', 'Connections', 'plug'],
  ['history', 'History', 'history'],
]

export function setupTabForKey(current, key) {
  const index = sections.findIndex(([id]) => id === current)
  if (key === 'Home') return sections[0][0]
  if (key === 'End') return sections.at(-1)[0]
  const step = key === 'ArrowRight' ? 1 : key === 'ArrowLeft' ? -1 : 0
  return step ? sections[(Math.max(0, index) + step + sections.length) % sections.length][0] : null
}

function closeSetup(state, restoreFocus = true) {
  retainCodingSetupDraft(state)
  const trigger = state.root.closest('[data-testid="mooncode-center"]')?.querySelector('.mooncode-skill-toggle')
  trigger?.click()
  if (restoreFocus) requestAnimationFrame(() => {
    if (trigger?.isConnected) trigger.focus()
    else document.querySelector('.mooncode-skill-toggle')?.focus()
  })
}

export function normalizeSkillImport(value, filename = 'skill.json') {
  const declaredName = value.match(/^name:\s*["']?([^\r\n"']+)["']?\s*$/m)?.[1]?.trim()
  const parsed = filename.toLowerCase().endsWith('.json') ? JSON.parse(value) : {
    id: declaredName || filename.replace(/\.md$/i, '').replace(/^skill$/i, 'imported-skill'),
    files: [{ path: 'SKILL.md', content: value }],
  }
  if (!parsed.id || !Array.isArray(parsed.files) || !parsed.files.some(file => file.path === 'SKILL.md')) throw new Error('Choose a skill bundle or a SKILL.md file.')
  return { id: String(parsed.id), files: parsed.files.map(file => ({ path: String(file.path), content: String(file.content ?? '') })) }
}

export function applyCodingPreset(preset, scope = document) {
  const controls = scope.querySelector('[data-runtime="mooncode-composer-controls-v1"]')
  if (!controls) throw new Error('Open a coding conversation to apply this preset.')
  const available = (controls.dataset.models || '').split('\n')
  if (!available.includes(preset.model)) throw new Error('This model is not connected. Choose an available model and save a new preset.')
  for (const [key, value] of [['model', preset.model], ['reasoning', preset.reasoning || 'none'], ['task-intent', preset.task_intent || 'auto']]) {
    const input = controls.querySelector(`[data-mooncode-control-sync="${key}"]`)
    if (!input) continue
    input.value = value
    input.dispatchEvent(new Event('input', { bubbles: true }))
  }
}

function notify(state, message, error = false) {
  state.message = message
  state.error = error
  const status = panels.get(state.root) === state ? state.root.querySelector('[data-setup-status]') : null
  if (status) { status.textContent = message; status.dataset.error = String(error) }
}

async function request(state, payload) {
  const response = await fetch(`/api/mooncode/setup/${encodeURIComponent(state.workspaceId)}`, payload ? {
    method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(payload),
  } : undefined)
  const result = await response.json()
  if (!response.ok) throw new Error(typeof result.error === 'string' ? result.error : result.message || 'Could not save coding setup.')
  return result
}

function captureDraft(state) {
  captureKnowledgeDraft(state)
  if (state.tab === 'skills' && state.draft) {
    const id = state.root.querySelector('[name="skill-id"]')
    const text = state.root.querySelector('[name="skill-content"]')
    if (id) state.draft.id = id.value
    if (text && state.draft.files[state.fileIndex]) state.draft.files[state.fileIndex].content = text.value
  }
  const instructions = state.root.querySelector('[name="instructions"]')
  if (instructions) state.instructions = instructions.value
  const promptName = state.root.querySelector('[name="prompt-name"]')
  const promptText = state.root.querySelector('[name="prompt-text"]')
  if (promptName && promptText) state.promptDraft = { name: promptName.value, text: promptText.value }
  state.fieldDrafts ||= {}
  for (const name of retainedFieldNames) {
    const input = state.root.querySelector(`[name="${name}"]`)
    if (input) state.fieldDrafts[name] = input.value
  }
}

export function retainCodingSetupDraft(state) {
  captureDraft(state)
  const { root, ...snapshot } = state
  retainedDrafts.set(state.workspaceId, structuredClone(snapshot))
}

export function restoreCodingSetupDraft(root) {
  const saved = retainedDrafts.get(root.dataset.workspaceId)
  return saved ? { ...structuredClone(saved), root } : { root, workspaceId: root.dataset.workspaceId, tab: 'skills', fileIndex: 0, draft: null, data: null, instructions: '', message: '', fieldDrafts: {} }
}

function clearFieldDrafts(state, prefix) {
  for (const name of Object.keys(state.fieldDrafts || {})) if (name.startsWith(prefix)) delete state.fieldDrafts[name]
}

function skillEditor(state) {
  const draft = state.draft
  const records = state.data.skills || []
  return `<div class="coding-setup-skill-grid"><aside aria-label="Skill library"><button type="button" data-action="new-skill">${iconMarkup('plus')}New skill</button>
    <details class="coding-setup-import-options"><summary>Import skill</summary><label class="coding-setup-import">File<input type="file" data-import accept=".md,.json" aria-label="Import skill file"></label>
    <label class="coding-setup-import">Folder<input type="file" data-import-folder webkitdirectory multiple aria-label="Import skill folder"></label></details>
    ${records.map((item, index) => `<button type="button" class="coding-setup-skill${draft?.id === item.id ? ' selected' : ''}" data-action="select-skill" data-index="${index}">${escape(item.id)}<small>${item.files.length} files</small></button>`).join('')}
    ${!records.length ? '<p>Create or import your first reusable coding skill.</p>' : ''}</aside>
    <div>${draft ? `<label>Skill folder<input name="skill-id" value="${escape(draft.id)}" autocomplete="off"></label>
      <div class="coding-setup-filebar"><label>File<select name="skill-file">${draft.files.map((file, index) => `<option value="${index}"${index === state.fileIndex ? ' selected' : ''}>${escape(file.path)}</option>`).join('')}</select></label>
      <label>New file path<input name="new-file-path" placeholder="references/examples.md"></label><button type="button" data-action="add-file">Add file</button><button type="button" data-action="remove-file"${draft.files[state.fileIndex]?.path === 'SKILL.md' ? ' disabled' : ''}>Remove file</button></div>
      <label>${escape(draft.files[state.fileIndex]?.path || 'File contents')}<textarea name="skill-content" spellcheck="false" rows="16">${escape(draft.files[state.fileIndex]?.content || '')}</textarea></label>
      <div class="coding-setup-actions"><button type="button" data-action="save-skill">Save and install</button><button type="button" data-action="export-skill">Export bundle</button>${records.some(item => item.id === draft.id) ? '<button type="button" data-action="remove-skill">Uninstall skill</button>' : ''}</div>
      <p class="coding-setup-hint">Available from the next coding turn.</p>` : '<p>Select a skill to edit its files.</p>'}</div></div>`
}

function presetEditor(state) {
  const controls = document.querySelector('[data-runtime="mooncode-composer-controls-v1"]')
  const models = (controls?.dataset.models || '').split('\n').filter(Boolean)
  return `<p class="coding-setup-hint">Save a model and reasoning level for repeated work.</p>
    <div class="coding-setup-preset-form"><label>Preset name<input name="preset-name" placeholder="Careful review"></label>
    <label>Connected model<select name="preset-model">${models.map(model => `<option${model === controls?.dataset.selectedModel ? ' selected' : ''}>${escape(model)}</option>`).join('')}</select></label>
    <label>Reasoning<select name="preset-reasoning">${['none', 'minimal', 'low', 'medium', 'high', 'xhigh'].map(value => `<option${value === controls?.dataset.reasoning ? ' selected' : ''}>${value}</option>`).join('')}</select></label>
    <label>Task purpose<select name="preset-intent"><option value="auto">Automatic</option><option value="read_only">Review only</option><option value="workspace_change">Make changes</option></select></label>
    <button type="button" data-action="save-preset"${models.length ? '' : ' disabled'}>Save preset</button></div>
    ${!models.length ? '<p>No models are connected. Connect a provider from the Code setup controls, then refresh this panel.</p>' : ''}
    <div class="coding-setup-presets">${(state.data.presets || []).map((preset, index) => `<article><div><strong>${escape(preset.name)}${preset.default ? ' · Book default' : ''}</strong><p>${escape(preset.model)} · ${escape(preset.reasoning)} · ${escape(preset.task_intent)}</p></div><button type="button" data-action="apply-preset" data-index="${index}">Use preset</button><button type="button" data-action="default-preset" data-index="${index}">${preset.default ? 'Clear default' : 'Use for new chats'}</button><button type="button" data-action="delete-preset" data-index="${index}">Remove</button></article>`).join('')}</div>`
}

function promptEditor(state) {
  return `<p class="coding-setup-hint">Add saved requests to your conversation before sending.</p><label>Prompt name<input name="prompt-name" value="${escape(state.promptDraft?.name || '')}" placeholder="Review before merge"></label><label>Instructions<textarea name="prompt-text" rows="8">${escape(state.promptDraft?.text || '')}</textarea></label><button type="button" data-action="save-template">Save prompt</button><div class="coding-setup-presets">${(state.data.templates || []).map((item, index) => `<article><div><strong>${escape(item.name)}</strong><p>${escape(item.text.slice(0, 180))}</p></div><button type="button" data-action="use-template" data-index="${index}">Add to conversation</button><button type="button" data-action="edit-template" data-index="${index}">Edit</button><button type="button" data-action="delete-template" data-index="${index}">Remove</button></article>`).join('')}</div>`
}

function integrationsEditor(state) {
  const draft = state.integrationDraft || {}
  return `<p class="coding-setup-hint">Connect external tools for coding work.</p><details class="coding-setup-help"><summary>Supported connections</summary><p>MCP HTTP endpoints with JSON or server-sent-event responses (2025-11-25 protocol). Save, then test to discover tools.</p></details><div class="coding-setup-preset-form"><label>Connection name<input name="integration-id" value="${escape(draft.id || '')}" placeholder="project-tools"></label><label>MCP endpoint<input type="url" name="integration-url" value="${escape(draft.url || '')}" placeholder="https://example.com/mcp"></label><label>Bearer token (optional)<input type="password" name="integration-token" autocomplete="new-password" placeholder="${draft.has_token ? 'Saved token — leave blank to keep' : 'Optional access token'}"></label><button type="button" data-action="save-integration">Save connection</button></div><div class="coding-setup-presets">${(state.data.integrations || []).map((item, index) => `<article><div><strong>${escape(item.id)}</strong><p>${escape(item.url)}</p><span class="coding-setup-connection-state">${iconMarkup(item.enabled ? 'plug' : 'paused')}${item.enabled ? 'Enabled' : 'Paused'}${item.has_token ? ' · Token saved' : ''}</span></div><button type="button" data-action="test-integration" data-index="${index}"${item.enabled ? '' : ' disabled'}>Test tools</button><button type="button" data-action="edit-integration" data-index="${index}">Edit</button><button type="button" data-action="toggle-integration" data-index="${index}">${item.enabled ? 'Pause' : 'Enable'}</button><button type="button" data-action="remove-integration" data-index="${index}">Remove</button></article>`).join('')}</div>${state.integrationResult ? `<pre class="coding-setup-tool-result">${escape(state.integrationResult)}</pre>` : ''}`
}

function historyView(state) {
  const history = state.data.history || []
  return `<p class="coding-setup-hint">Compare saved versions. Skills and instructions reopen as drafts; other settings restore immediately.</p><details class="coding-setup-help"><summary>About restoration</summary><p>Restoring settings creates a new version. Connection tokens are kept separately and are not included in history.</p></details>${history.map((entry, index) => {
    const fileDraft = ['skill', 'instructions'].includes(entry.kind)
    const key = entry.kind === 'integrations' ? 'servers' : entry.kind === 'embeddings' ? 'configuration' : entry.kind
    const before = entry.kind === 'skill' ? entry.previous_files : entry.kind === 'instructions' ? entry.previous_content : entry.previous
    const after = entry.kind === 'skill' ? entry.files : entry.kind === 'instructions' ? entry.content : entry[key]
    const show = value => escape(typeof value === 'string' ? value : JSON.stringify(value ?? [], null, 2))
    return `<article class="coding-setup-history"><div><strong>${escape(entry.kind === 'skill' ? entry.id : entry.kind === 'instructions' ? 'Book instructions' : entry.kind === 'templates' ? 'Saved prompts' : entry.kind === 'integrations' ? 'Integrations' : 'Model presets')}</strong><p>${escape(entry.saved_at)}</p></div>${fileDraft ? `<button type="button" data-action="restore-version" data-index="${index}">Open saved version</button><button type="button" data-action="restore-previous" data-index="${index}">Open previous version</button>` : `<button type="button" data-action="restore-configuration" data-index="${index}">Restore saved version</button><button type="button" data-action="restore-configuration-previous" data-index="${index}">Restore previous version</button>`}<details class="coding-setup-version"><summary>Compare changes</summary><div><section><h4>Before</h4><pre>${show(before)}</pre></section><section><h4>Saved version</h4><pre>${show(after)}</pre></section></div></details></article>`
  }).join('') || '<p>Saved changes will appear here.</p>'}`
}

function render(state) {
  if (!state.root.isConnected || panels.get(state.root) !== state) return
  const focused = state.root.contains(document.activeElement) ? document.activeElement : null
  const focusTarget = focused?.dataset.tab ? `[data-tab="${focused.dataset.tab}"]` : focused?.dataset.action ? `[data-action="${focused.dataset.action}"]${focused.dataset.index == null ? '' : `[data-index="${focused.dataset.index}"]`}` : null
  const host = state.root.closest('.mooncode-skill-catalog')
  if (host) {
    host.classList.add('coding-setup-drawer')
    host.dataset.popup = 'coding-setup'
    host.dataset.popupTrigger = '.mooncode-skill-toggle'
    host.dataset.setupTab = state.tab
    host.dataset.setupCatalogOpen = String(Boolean(state.catalogOpen))
    host.setAttribute('role', 'dialog')
    host.setAttribute('aria-label', 'Coding setup')
    host.removeAttribute('data-i18n-aria-label')
  }
  const prefix = `coding-setup-${encodeURIComponent(state.workspaceId)}`
  const counts = { skills: state.data?.skills?.length, knowledge: state.data?.knowledge?.length, presets: state.data?.presets?.length, prompts: state.data?.templates?.length, integrations: state.data?.integrations?.length, history: state.data?.history?.length }
  state.root.innerHTML = `<section class="coding-setup" aria-label="Coding setup"><header><h3>${iconMarkup('settings')}Coding setup</h3><div class="coding-setup-header-actions"><button type="button" class="moon-icon-button" data-action="refresh" title="Refresh setup" aria-label="Refresh setup">${iconMarkup('refresh')}</button><button type="button" class="moon-icon-button" data-action="close" data-popup-dismiss title="Close coding setup" aria-label="Close coding setup">${iconMarkup('close')}</button></div></header>
    <div class="coding-setup-tabs" role="tablist" aria-label="Coding setup sections">${sections.map(([id, label, icon]) => `<button type="button" id="${prefix}-${id}-tab" data-tab="${id}" role="tab" aria-selected="${id === state.tab}" aria-controls="${prefix}-panel" tabindex="${id === state.tab ? '0' : '-1'}">${iconMarkup(icon)}<span>${label}</span>${counts[id] ? `<small>${counts[id]}</small>` : ''}</button>`).join('')}</div>
    <div class="coding-setup-content" id="${prefix}-panel" role="tabpanel" aria-labelledby="${prefix}-${state.tab}-tab" tabindex="0">
    <p data-setup-status data-error="${Boolean(state.error)}" role="status" aria-live="polite">${escape(state.message || '')}</p>
    ${state.data && state.tab === 'knowledge' ? renderKnowledgeEmbeddingSettings(state) : ''}
    ${['skills', 'integrations'].includes(state.tab) ? `<p class="coding-setup-scope">${iconMarkup('info')}Shared across books in this MoonSuite</p>` : '<p class="coding-setup-scope">Applies to this book</p>'}
    ${!state.data ? '<p>Loading setup…</p>' : state.tab === 'skills' ? skillEditor(state) : state.tab === 'knowledge' ? renderKnowledge(state) : state.tab === 'presets' ? presetEditor(state) : state.tab === 'prompts' ? promptEditor(state) : state.tab === 'integrations' ? integrationsEditor(state) : state.tab === 'history' ? historyView(state) : `<label>Book instructions<textarea name="instructions" rows="18" spellcheck="false">${escape(state.instructions)}</textarea></label><div class="coding-setup-actions"><button type="button" data-action="save-instructions">Save instructions</button><span class="coding-setup-hint">AGENTS.md · Used from the next turn</span></div>`}
    ${state.tab === 'skills' ? `<button type="button" class="coding-setup-catalog-toggle" data-action="toggle-catalog" aria-expanded="${Boolean(state.catalogOpen)}">${iconMarkup(state.catalogOpen ? 'chevron-down' : 'chevron-right')}Discovered skills</button>` : ''}</div></section>`
  for (const [name, value] of Object.entries(state.fieldDrafts || {})) {
    const input = state.root.querySelector(`[name="${name}"]`)
    if (input) input.value = value
  }
  if (focusTarget) state.root.querySelector(focusTarget)?.focus({ preventScroll: true })
}

async function save(state, payload, message) {
  const workspaceId = state.workspaceId
  notify(state, 'Saving…')
  const result = await request(state, payload)
  if (workspaceId !== state.workspaceId) return
  state.data = result
  if (payload.action === 'save-integrations') delete state.fieldDrafts?.['integration-token']
  state.message = message
  render(state)
}

async function action(state, button) {
  captureDraft(state)
  if (button.dataset.action?.startsWith('knowledge-')) {
    const workspaceId = state.workspaceId
    notify(state, 'Updating knowledge…')
    const message = await knowledgeAction(state, button)
    if (workspaceId !== state.workspaceId) return
    if (button.dataset.action === 'knowledge-save-embeddings') clearFieldDrafts(state, 'knowledge-embedding-')
    state.message = message; render(state); return
  }
  const index = Number(button.dataset.index)
  const get = name => state.root.querySelector(`[name="${name}"]`)?.value || ''
  switch (button.dataset.action) {
    case 'close': closeSetup(state, button.dataset.popupRestoreFocus !== 'false'); return
    case 'toggle-catalog': state.catalogOpen = !state.catalogOpen; break
    case 'refresh': {
      const workspaceId = state.workspaceId, data = await request(state)
      if (workspaceId !== state.workspaceId) return
      state.data = data; state.message = 'Coding setup refreshed'; break
    }
    case 'new-skill': state.draft = { id: 'review-changes', files: [{ path: 'SKILL.md', content: template }] }; state.fileIndex = 0; break
    case 'select-skill': state.draft = structuredClone(state.data.skills[index]); state.fileIndex = Math.max(0, state.draft.files.findIndex(file => file.path === 'SKILL.md')); break
    case 'add-file': {
      const path = get('new-file-path').trim()
      if (!path || state.draft.files.some(file => file.path === path)) throw new Error('Choose a new relative file path.')
      state.draft.files.push({ path, content: '' }); state.fileIndex = state.draft.files.length - 1; clearFieldDrafts(state, 'new-file-path'); break
    }
    case 'remove-file': if (state.draft.files[state.fileIndex]?.path !== 'SKILL.md') { state.draft.files.splice(state.fileIndex, 1); state.fileIndex = 0 }; break
    case 'save-skill': return save(state, { action: 'save-skill', ...state.draft }, 'Skill saved and available for the next coding turn')
    case 'remove-skill': { const id = state.draft.id; state.draft = null; return save(state, { action: 'remove-skill', id }, 'Skill uninstalled. Restore its previous version from History if needed.') }
    case 'export-skill': {
      const url = URL.createObjectURL(new Blob([JSON.stringify(state.draft, null, 2)], { type: 'application/json' }))
      const link = document.createElement('a'); link.href = url; link.download = `${state.draft.id}.skill.json`; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000); return
    }
    case 'save-instructions': return save(state, { action: 'save-instructions', content: state.instructions }, 'Book instructions saved')
    case 'save-integration': {
      const item = { id: get('integration-id').trim(), url: get('integration-url').trim(), token: get('integration-token'), enabled: true }
      return save(state, { action: 'save-integrations', servers: [...state.data.integrations.filter(server => server.id !== item.id), item] }, 'Integration saved. Test it to discover available tools.')
    }
    case 'edit-integration': clearFieldDrafts(state, 'integration-'); state.integrationDraft = { ...state.data.integrations[index] }; break
    case 'toggle-integration': return save(state, { action: 'save-integrations', servers: state.data.integrations.map((item, i) => i === index ? { ...item, enabled: !item.enabled } : item) }, 'Integration updated')
    case 'remove-integration': return save(state, { action: 'save-integrations', servers: state.data.integrations.filter((_, i) => i !== index) }, 'Integration removed')
    case 'test-integration': {
      const workspaceId = state.workspaceId
      notify(state, 'Connecting and discovering tools…')
      const result = await request(state, { action: 'test-integration', server: state.data.integrations[index].id })
      if (workspaceId !== state.workspaceId) return
      state.integrationResult = JSON.stringify(result.servers, null, 2)
      state.message = result.ok ? 'Connection works. These tools are available to MoonCode.' : 'The connection needs attention. See the response below.'
      break
    }
    case 'save-template': {
      if (!state.promptDraft?.name.trim() || !state.promptDraft?.text.trim()) throw new Error('Give this prompt a name and instructions.')
      return save(state, { action: 'save-templates', templates: [...(state.data.templates || []).filter(item => item.name !== state.promptDraft.name), state.promptDraft] }, 'Prompt saved')
    }
    case 'edit-template': state.promptDraft = { ...state.data.templates[index] }; break
    case 'delete-template': return save(state, { action: 'save-templates', templates: state.data.templates.filter((_, i) => i !== index) }, 'Prompt removed')
    case 'use-template': {
      const item = state.data.templates[index]
      globalThis.dispatchEvent(new CustomEvent('moondesk:add-context', { detail: { kind: 'prompt', label: item.name, text: item.text, workspaceId: state.workspaceId } }))
      notify(state, 'Prompt added to conversation context'); return
    }
    case 'save-preset': {
      const preset = { name: get('preset-name').trim(), model: get('preset-model'), reasoning: get('preset-reasoning'), task_intent: get('preset-intent') }
      if (!preset.name) throw new Error('Give your preset a name.')
      const presets = [...state.data.presets.filter(item => item.name !== preset.name), preset]
      return save(state, { action: 'save-presets', presets }, 'Model preset saved')
    }
    case 'delete-preset': return save(state, { action: 'save-presets', presets: state.data.presets.filter((_, i) => i !== index) }, 'Preset removed')
    case 'default-preset': return save(state, { action: 'save-presets', presets: state.data.presets.map((preset, i) => ({ ...preset, default: i === index && !preset.default })) }, 'Default for new coding chats updated')
    case 'apply-preset': applyCodingPreset(state.data.presets[index]); notify(state, `Using ${state.data.presets[index].name} for the next request`); return
    case 'restore-configuration':
    case 'restore-configuration-previous': {
      const entry = state.data.history[index], key = entry.kind === 'integrations' ? 'servers' : entry.kind === 'embeddings' ? 'configuration' : entry.kind
      const value = button.dataset.action.endsWith('-previous') ? entry.previous : entry[key]
      if (entry.kind === 'embeddings' && value && typeof value === 'object') return save(state, { action: 'save-embeddings', ...value }, 'Embedding configuration restored. Re-index sources if the model changed.')
      if (!Array.isArray(value)) throw new Error('This historical version has no configuration snapshot.')
      return save(state, { action: `save-${entry.kind}`, [key]: value }, 'Configuration restored as a new version')
    }
    case 'restore-version':
    case 'restore-previous': {
      const entry = state.data.history[index], previous = button.dataset.action === 'restore-previous'
      if (entry.kind === 'skill') { state.draft = { id: entry.id, files: structuredClone(previous ? entry.previous_files : entry.files) }; if (!state.draft.files.length) throw new Error('This skill did not exist before this version.'); state.fileIndex = 0; state.tab = 'skills' }
      else { state.instructions = previous ? entry.previous_content : entry.content; state.tab = 'instructions' }
      state.message = 'Version opened as a draft. Review it, then save to restore.'; break
    }
  }
  render(state)
}

function load(state) {
  const workspaceId = state.workspaceId
  void request(state).then(data => {
    if (workspaceId !== state.workspaceId) return
    const firstLoad = !state.data
    state.data = data; if (firstLoad) state.instructions = data.instructions; render(state)
  }).catch(error => { if (workspaceId === state.workspaceId) notify(state, error.message, true) })
}

function mount(root) {
  const state = restoreCodingSetupDraft(root)
  panels.set(root, state)
  render(state)
  root.addEventListener('click', event => {
    const state = panels.get(root)
    const button = event.target.closest('button')
    if (!button || !root.contains(button)) return
    if (button.dataset.tab) { captureDraft(state); state.tab = button.dataset.tab; render(state); root.querySelector(`[data-tab="${state.tab}"]`)?.focus(); return }
    if (button.dataset.action) void action(state, button).catch(error => notify(state, error.message, true))
  })
  root.addEventListener('keydown', event => {
    const state = panels.get(root)
    const tab = event.target.closest('[role="tab"]')
    if (!tab || !root.contains(tab)) return
    const next = setupTabForKey(tab.dataset.tab, event.key)
    if (!next) return
    event.preventDefault()
    captureDraft(state); state.tab = next; render(state)
    root.querySelector(`[data-tab="${next}"]`)?.focus()
  })
  root.addEventListener('change', event => {
    const state = panels.get(root)
    const input = event.target
    if (input.name === 'skill-file') { captureDraft(state); state.fileIndex = Number(input.value); render(state) }
    if (input.matches('[data-import],[data-import-folder]')) void (async () => {
      const workspaceId = state.workspaceId
      captureDraft(state)
      const files = [...(input.files || [])]
      if (!files.length) return
      if (input.hasAttribute('data-import-folder')) {
        const id = files[0].webkitRelativePath.split('/')[0]
        state.draft = { id, files: await Promise.all(files.map(async file => ({ path: file.webkitRelativePath.split('/').slice(1).join('/'), content: await file.text() }))) }
        if (!state.draft.files.some(file => file.path === 'SKILL.md')) throw new Error('The folder needs a SKILL.md file.')
      } else state.draft = normalizeSkillImport(await files[0].text(), files[0].name)
      if (workspaceId !== state.workspaceId) { state.draft = null; return }
      state.fileIndex = Math.max(0, state.draft.files.findIndex(file => file.path === 'SKILL.md'))
      state.tab = 'skills'; state.message = 'Imported as a draft. Review the files, then Save and install.'; render(state)
    })().catch(error => notify(state, error.message, true))
  })
  load(state)
  requestAnimationFrame(() => root.querySelector('[role="tab"][aria-selected="true"]')?.focus())
}

export function installCodingSetupRuntime(scope = document) {
  const mounted = new Set()
  const scan = () => {
    for (const root of mounted) {
      if (!root.isConnected) { retainCodingSetupDraft(panels.get(root)); mounted.delete(root) }
    }
    for (const center of scope.querySelectorAll('[data-testid="mooncode-center"]')) {
      const workspaceId = center.dataset.workspaceId
      if (!workspaceId || center.dataset.sessionId) { defaultLoads.delete(center); continue }
      const controls = center.querySelector('[data-runtime="mooncode-composer-controls-v1"]')
      if (!controls?.dataset.models || defaultLoads.get(center) === workspaceId) continue
      defaultLoads.set(center, workspaceId)
      void fetch(`/api/mooncode/presets/${encodeURIComponent(workspaceId)}`).then(async response => {
        if (!response.ok) return
        const presets = await response.json()
        if (center.dataset.workspaceId !== workspaceId || center.dataset.sessionId) return
        const preset = presets.find(item => item.default)
        if (preset) applyCodingPreset(preset, center)
      }).catch(() => { /* A disconnected default never prevents starting a chat. */ })
    }
    for (const root of scope.querySelectorAll('[data-runtime="mooncode-setup-v1"]')) {
      mounted.add(root)
      if (!panels.has(root)) mount(root)
      else if (panels.get(root).workspaceId !== root.dataset.workspaceId) {
        retainCodingSetupDraft(panels.get(root))
        const state = restoreCodingSetupDraft(root)
        panels.set(root, state)
        render(state); load(state)
      }
    }
  }
  scan()
  const observer = new MutationObserver(scan)
  observer.observe(scope.body || scope, { subtree: true, childList: true, attributes: true, attributeFilter: ['data-workspace-id', 'data-session-id', 'data-models'] })
  return () => observer.disconnect()
}

if (typeof document !== 'undefined') installCodingSetupRuntime()
