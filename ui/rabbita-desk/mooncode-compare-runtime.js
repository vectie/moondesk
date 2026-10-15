async function createComparisonSession(root, branch) {
  const response = await fetch('/api/mooncode/sessions', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      action: 'prompt',
      workspace_id: root.dataset.workspaceId || '',
      title: branch.title,
      message: branch.prompt,
      model: branch.model || '',
      ...(branch.task_intent ? { task_intent: branch.task_intent } : {}),
      client_turn_id: branch.client_turn_id || `compare-${branch.label.toLowerCase()}-${globalThis.crypto?.randomUUID?.() || Date.now()}`,
      planner_reasoning_effort: 'high',
      context_path: root.dataset.contextPath || '',
      comparison: {
        contract: 'moondesk.mooncode_comparison_branch.v1',
        comparison_id: branch.comparison_id,
        baseline_request_digest: branch.baseline_request_digest,
        branch: branch.label,
      },
    }),
  })
  const payload = await response.json().catch(() => ({}))
  if (!response.ok || !payload.id) throw new Error(payload.error?.message || payload.error || payload.message || `Branch ${branch.label} was not accepted`)
  return { ...branch, id: payload.id, status: payload.status || 'queued' }
}

async function refreshComparisonSessions(sessions) {
  const { comparisonSessionProjection, comparisonAnswerProjection } = await import('./mooncode-compare-evidence-runtime.js')
  return Promise.all(sessions.map(async session => {
    try {
      const response = await fetch(`/api/mooncode/sessions/${encodeURIComponent(session.id)}?format=compact`)
      if (!response.ok) throw new Error(`Conversation unavailable (${response.status})`)
      const payload = await response.json()
      const taskResponse = await fetch(`/api/mooncode/sessions/${encodeURIComponent(session.id)}/task-controls`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ action: 'inspect' }),
      })
      const task = taskResponse.ok ? await taskResponse.json() : null
      const answer = task ? comparisonAnswerProjection(task) : {}
      return { ...session, ...comparisonSessionProjection(payload), ...answer, model: answer.model || session.model || '', refresh_error: '' }
    } catch {
      return { ...session, refresh_error: 'Could not refresh this conversation. Its last result is preserved.' }
    }
  }))
}

export async function startComparisonBranches(branches, create, progress = async () => {}) {
  const sessions = [], failed = []
  let save = Promise.resolve()
  await Promise.all(branches.map(async branch => {
    try { sessions.push(await create(branch)) }
    catch (error) { failed.push({ ...branch, error: String(error?.message || error) }) }
    const snapshot = { sessions: [...sessions], failed_branches: [...failed] }
    save = save.then(() => progress(snapshot))
    await save
  }))
  return { sessions: sessions.sort((a, b) => a.label.localeCompare(b.label)), failed_branches: failed }
}

const comparisons = new WeakMap()
export function comparisonNeedsRefresh(sessions) {
  return sessions.some(session => {
    const status = session.turn_status || session.status
    if (['completed', 'done', 'failed', 'cancelled', 'stopped'].includes(status)) return false
    if (status === 'idle' && session.answer) return false
    return true
  })
}
function watchComparison(panel, root, comparison) {
  const previous = comparisons.get(panel)
  if (previous?.timer) clearTimeout(previous.timer)
  const state = { comparison, timer: null }; comparisons.set(panel, state)
  const tick = async () => {
    if (!panel.isConnected || comparisons.get(panel) !== state) return
    if (document.visibilityState !== 'hidden') {
      const sessions = await refreshComparisonSessions(comparison.sessions)
      if (comparisons.get(panel) !== state || !panel.isConnected) return
      if (JSON.stringify(sessions) !== JSON.stringify(comparison.sessions)) {
        comparison.sessions = sessions
        comparison.updated_at = new Date().toISOString()
        const { saveComparison } = await import('./mooncode-compare-evidence-runtime.js')
        Object.assign(comparison, await saveComparison(root, comparison))
        await renderComparisonSessions(panel, root, comparison)
      }
    }
    if (comparisons.get(panel) === state && panel.isConnected && comparisonNeedsRefresh(comparison.sessions)) state.timer = setTimeout(tick, 4000)
  }
  state.timer = setTimeout(tick, 1500)
}

function openComparisonSession(session) {
  window.dispatchEvent(new CustomEvent('moondesk:open-code-session', { detail: { sessionId: session.id } }))
}

export function openMoonCodeCompareFrom(root, action) {
  const messages = Array.from(document.querySelectorAll('[data-testid="mooncode-message"]'))
  const currentIndex = messages.indexOf(action.closest('[data-testid="mooncode-message"]'))
  const prior = messages.slice(0, Math.max(0, currentIndex)).reverse()
    .find(message => message.dataset.role === 'user')
  const goal = prior?.querySelector('.mooncode-message-body')?.textContent?.trim() ||
    'Try a materially different implementation for the current result.'
  root.open = true
  root.closest('[data-testid="mooncode-center"]')?.querySelector('button[data-workbench-view="compare"]')?.click()
  root.querySelector('[data-developer-tool-tab="compare"]')?.click()
  const field = root.querySelector('[data-developer-compare-goal]')
  if (field instanceof HTMLTextAreaElement) {
    field.value = goal
    field.dispatchEvent(new Event('input', { bubbles: true }))
    field.focus()
  } else {
    root.__mooncodeCompareDraft = goal
  }
}

async function renderComparisonSessions(panel, root, comparison) {
  const { saveComparison } = await import('./mooncode-compare-evidence-runtime.js')
  const host = panel.querySelector('[data-developer-compare-results-host]') || panel
  host.replaceChildren()
  const results = document.createElement('div')
  results.className = 'mooncode-compare-results'
  results.dataset.developerCompareResults = 'true'
  const heading = document.createElement('div')
  heading.className = 'mooncode-compare-run-heading'
  heading.innerHTML = `<strong></strong><small></small>`
  heading.querySelector('strong').textContent = comparison.mode === 'models' ? 'Compare model answers' : 'Compare approaches'
  heading.querySelector('small').textContent = comparison.goal
  results.append(heading)
  for (const session of comparison.sessions) {
    const card = document.createElement('article')
    card.className = 'mooncode-compare-result'
    const title = document.createElement('strong')
    title.textContent = `${session.label} · ${session.model || 'Default model'}`
    const detail = document.createElement('small')
    detail.textContent = `${session.status} · ${session.verified_test_count || 0} checks · ${session.pending_diff_count || 0} changes`
    const answer = document.createElement('pre')
    answer.className = 'mooncode-comparison-answer'
    answer.textContent = session.answer || 'The answer will appear here as this task progresses.'
    const usage = document.createElement('small')
    usage.textContent = session.usage_measured ? `${session.input_tokens.toLocaleString()} input · ${session.output_tokens.toLocaleString()} output tokens` : 'Usage has not been reported by the provider.'
    const open = document.createElement('button')
    open.type = 'button'
    open.className = 'mooncode-developer-terminal-submit'
    open.textContent = 'Open conversation'
    open.addEventListener('click', () => openComparisonSession(session))
    const choose = document.createElement('button')
    choose.type = 'button'
    choose.className = 'mooncode-developer-terminal-submit'
    choose.textContent = comparison.selected_branch === session.label
      ? 'Chosen approach'
      : 'Continue with this'
    choose.disabled = comparison.selected_branch === session.label
    choose.addEventListener('click', async () => {
      choose.disabled = true
      comparison.selected_branch = session.label
      comparison.selected_at = new Date().toISOString()
      const persisted = await saveComparison(root, comparison)
      Object.assign(comparison, persisted)
      await renderComparisonSessions(panel, root, comparison)
      openComparisonSession(session)
    })
    card.append(title, detail, answer, usage, open, choose)
    if (session.refresh_error) { const warning = document.createElement('p'); warning.textContent = session.refresh_error; card.append(warning) }
    results.append(card)
  }
  for (const failed of comparison.failed_branches || []) {
    const card = document.createElement('article'); card.className = 'mooncode-compare-result'
    const title = document.createElement('strong'); title.textContent = `${failed.label} · Not started`
    const problem = document.createElement('p'); problem.textContent = failed.error || 'This branch has not started.'
    const retry = document.createElement('button'); retry.type = 'button'; retry.className = 'secondary-button'; retry.textContent = `Retry ${failed.label} only`
    retry.addEventListener('click', async () => {
      retry.disabled = true
      try {
        const session = await createComparisonSession(root, failed)
        comparison.sessions.push(session); comparison.sessions.sort((a, b) => a.label.localeCompare(b.label))
        comparison.failed_branches = comparison.failed_branches.filter(branch => branch.label !== failed.label)
        comparison.updated_at = new Date().toISOString(); Object.assign(comparison, await saveComparison(root, comparison))
        await renderComparisonSessions(panel, root, comparison); watchComparison(panel, root, comparison)
      } catch (error) {
        failed.error = error.message; problem.textContent = error.message; retry.disabled = false
        comparison.updated_at = new Date().toISOString(); Object.assign(comparison, await saveComparison(root, comparison))
      }
    })
    card.append(title, problem, retry); results.append(card)
  }
  const refresh = document.createElement('button')
  refresh.type = 'button'
  refresh.className = 'secondary-button mooncode-compare-refresh'
  refresh.textContent = 'Refresh branch evidence'
  refresh.addEventListener('click', async () => {
    refresh.disabled = true
    comparison.sessions = await refreshComparisonSessions(comparison.sessions)
    comparison.updated_at = new Date().toISOString()
    const persisted = await saveComparison(root, comparison)
    Object.assign(comparison, persisted)
    renderComparisonSessions(panel, root, comparison)
  })
  results.append(refresh)
  host.append(results)
}

export function installMoonCodeCompare(root) {
  const panel = root.querySelector('[data-developer-tool-panel="compare"]')
  if (!(panel instanceof HTMLElement)) return
  if (panel.dataset.comparisonRuntimeInstalled === 'true') return
  panel.dataset.comparisonRuntimeInstalled = 'true'
  if (!panel.querySelector('[data-developer-compare-form]')) panel.innerHTML = `
    <div class="mooncode-developer-tool-heading">
      <div><h3>Compare answers or approaches</h3><p>Run two conversations, compare their results, and continue with your choice.</p></div>
    </div>
    <form class="mooncode-compare-form" data-developer-compare-form="true">
      <label>Goal<textarea data-developer-compare-goal required placeholder="What should both approaches accomplish?"></textarea></label>
      <div class="mooncode-compare-branches">
        <label>Approach A<textarea data-developer-compare-a placeholder="Direct implementation, library choice, or route A"></textarea></label>
        <label>Approach B<textarea data-developer-compare-b placeholder="Alternative implementation, library choice, or route B"></textarea></label>
      </div>
      <button class="mooncode-developer-terminal-submit" type="submit">Run isolated comparison</button>
      <p class="mooncode-developer-tool-footnote" data-testid="mooncode-developer-compare-status" role="status" aria-live="polite">Results, diffs, checks, latency, tokens, and cost stay in the MoonCode transcript.</p>
    </form><div class="mooncode-compare-results-host" data-developer-compare-results-host="true"></div>`
  const form = panel.querySelector('[data-developer-compare-form]')
  const goal = panel.querySelector('[data-developer-compare-goal]')
  const approachA = panel.querySelector('[data-developer-compare-a]')
  const approachB = panel.querySelector('[data-developer-compare-b]')
  const status = panel.querySelector('[data-testid="mooncode-developer-compare-status"]')
  const submit = form?.querySelector('[data-testid="mooncode-developer-compare-submit"], button[type="submit"]')
  if (!(form instanceof HTMLFormElement) ||
      !(goal instanceof HTMLTextAreaElement) ||
      !(approachA instanceof HTMLTextAreaElement) ||
      !(approachB instanceof HTMLTextAreaElement) ||
      !(submit instanceof HTMLButtonElement)) return
  const options = document.createElement('div')
  options.className = 'mooncode-comparison-options'
  const labeledSelect = (label, entries) => {
    const wrap = document.createElement('label')
    wrap.textContent = label
    const select = document.createElement('select')
    for (const [value, title] of entries) select.add(new Option(title, value))
    wrap.append(select)
    options.append(wrap)
    return select
  }
  const mode = labeledSelect('Compare', [['approaches', 'Implementation approaches'], ['models', 'Model answers · read only']])
  const modelSource = root.closest('[data-testid="mooncode-center"]')?.querySelector('[data-models]') || document.querySelector('[data-models]')
  const available = String(root.dataset.models || modelSource?.dataset.models || '').split('\n').filter(Boolean)
  const modelEntries = [['', 'Default model'], ...available.map(value => [value, value])]
  const modelA = labeledSelect('Model A', modelEntries)
  const modelB = labeledSelect('Model B', modelEntries)
  modelA.value = modelSource?.dataset.selectedModel || available[0] || ''
  if (available.length > 1) modelB.value = available[1]
  const draftKey = () => `moondesk.compare.draft:${root.dataset.workspaceId || 'general'}`
  const liveDrafts = new Map()
  const saveDraft = () => {
    const draft = { goal: goal.value, a: approachA.value, b: approachB.value, mode: mode.value, modelA: modelA.value, modelB: modelB.value }
    liveDrafts.set(draftKey(), draft)
    try { localStorage.setItem(draftKey(), JSON.stringify(draft)) } catch { /* Keep current inputs. */ }
  }
  const restoreDraft = () => {
    let draft = liveDrafts.get(draftKey()) || {}; if (!liveDrafts.has(draftKey())) try { draft = JSON.parse(localStorage.getItem(draftKey()) || '{}') } catch { /* No saved draft. */ }
    goal.value = draft.goal || ''; approachA.value = draft.a || ''; approachB.value = draft.b || ''
    mode.value = draft.mode || 'approaches'
    for (const [select, selected] of [[modelA, draft.modelA], [modelB, draft.modelB]]) {
      if (selected === undefined) continue
      if (selected && !Array.from(select.options).some(option => option.value === selected)) select.add(new Option(`${selected} (saved selection)`, selected))
      select.value = selected
    }
    approachA.disabled = mode.value === 'models'; approachB.disabled = mode.value === 'models'
    submit.textContent = mode.value === 'models' ? 'Compare model answers' : 'Run isolated comparison'
  }
  form.addEventListener('input', saveDraft); form.addEventListener('change', saveDraft)
  mode.addEventListener('change', () => {
    approachA.disabled = mode.value === 'models'
    approachB.disabled = mode.value === 'models'
    submit.textContent = mode.value === 'models' ? 'Compare model answers' : 'Run isolated comparison'
  })
  form.prepend(options)
  restoreDraft()
  submit.disabled = false
  submit.dataset.compareReady = 'true'
  let scope = root.dataset.workspaceId || ''
  let restoreEpoch = 0
  const restoreComparison = async () => {
    const epoch = ++restoreEpoch
    const { loadComparison } = await import('./mooncode-compare-evidence-runtime.js')
    const origin = { dataset: { workspaceId: root.dataset.workspaceId || '', contextPath: root.dataset.contextPath || '' } }
    const saved = await loadComparison(origin)
    if (epoch !== restoreEpoch || (root.dataset.workspaceId || '') !== origin.dataset.workspaceId || !panel.isConnected) return
    if (saved?.id && Array.isArray(saved.sessions)) {
      await renderComparisonSessions(panel, origin, saved)
      watchComparison(panel, origin, saved)
      if (status) status.textContent = saved.persistence === 'durable'
        ? 'Restored durable comparison and branch evidence.'
        : 'Restored a local recovery copy; the service receipt is unavailable.'
    }
  }
  void restoreComparison()
  let modelSignature = available.join('\n')
  const observer = new MutationObserver(() => {
    if (!root.isConnected) { observer.disconnect(); return }
    if ((root.dataset.workspaceId || '') !== scope) {
      scope = root.dataset.workspaceId || ''
      const previous = comparisons.get(panel); if (previous?.timer) clearTimeout(previous.timer); comparisons.delete(panel)
      panel.querySelector('[data-developer-compare-results-host]')?.replaceChildren()
      restoreDraft(); void restoreComparison()
    }
    const source = root.closest('[data-testid="mooncode-center"]')?.querySelector('[data-models]')
    const models = String(root.dataset.models || source?.dataset.models || '').split('\n').filter(Boolean)
    if (models.join('\n') !== modelSignature) {
      modelSignature = models.join('\n')
      for (const select of [modelA, modelB]) {
        const selected = select.value
        select.replaceChildren(new Option('Default model', ''), ...models.map(model => new Option(model, model)))
        select.value = models.includes(selected) ? selected : ''
      }
      restoreDraft()
    }
  })
  observer.observe(root.closest('[data-testid="mooncode-center"]') || root, { childList: true, subtree: true, attributes: true, attributeFilter: ['data-models', 'data-workspace-id'] })
  if (root.__mooncodeCompareDraft) {
    goal.value = root.__mooncodeCompareDraft
    approachA.value = 'Improve the current result with the smallest safe change.'
    approachB.value = 'Use a materially different implementation strategy.'
    root.__mooncodeCompareDraft = ''
    saveDraft()
  }
  form.addEventListener('submit', async event => {
    event.preventDefault()
    if (submit.disabled) return
    submit.disabled = true
    restoreEpoch++
    try {
    const {
      comparisonRequestIdentity,
      moonCodeComparisonBranches,
      configureComparisonBranches,
      saveComparison,
    } = await import('./mooncode-compare-evidence-runtime.js')
    const origin = { dataset: { workspaceId: root.dataset.workspaceId || '', contextPath: root.dataset.contextPath || '' } }
    const identity = await comparisonRequestIdentity(origin, goal.value)
    const branches = configureComparisonBranches(moonCodeComparisonBranches(goal.value, approachA.value, approachB.value, identity), mode.value, [modelA.value, modelB.value], goal.value).map(branch => ({ ...branch, client_turn_id: `compare-${branch.label.toLowerCase()}-${globalThis.crypto?.randomUUID?.() || Date.now()}` }))
    if (!branches.length) { submit.disabled = false; return }
    status.textContent = mode.value === 'models' ? 'Asking both models…' : 'Starting two isolated MoonCode branches…'
      let comparison = {
        contract: 'moondesk.mooncode_comparison.v1',
        ...identity,
        goal: goal.value.trim(),
        mode: mode.value,
        sessions: [],
        failed_branches: branches.map(branch => ({ ...branch, error: 'Not started yet' })),
        selected_branch: '',
        created_at: new Date().toISOString(),
      }
      comparison = await saveComparison(origin, comparison)
      const started = await startComparisonBranches(branches, branch => createComparisonSession(origin, branch), async progress => {
        // Save every accepted conversation even if the other request fails.
        comparison.sessions = progress.sessions
        comparison.failed_branches = branches.filter(branch => !progress.sessions.some(session => session.label === branch.label)).map(branch => progress.failed_branches.find(failed => failed.label === branch.label) || { ...branch, error: 'Waiting for start response…' })
        comparison.updated_at = new Date().toISOString()
        comparison = await saveComparison(origin, comparison)
      })
      Object.assign(comparison, started); comparison.updated_at = new Date().toISOString()
      comparison = await saveComparison(origin, comparison)
      if ((root.dataset.workspaceId || '') !== origin.dataset.workspaceId) return
      await renderComparisonSessions(panel, origin, comparison); watchComparison(panel, origin, comparison)
      status.textContent = comparison.failed_branches.length
        ? `${comparison.sessions.length} of 2 conversations started. Accepted conversations are preserved; retry only the failed branch below.`
        : comparison.persistence === 'durable'
        ? 'Both conversations are saved. Answers update automatically; continue with your choice when ready.'
        : `Both branches started, but only a local recovery copy was saved: ${comparison.persistence_error || 'service unavailable'}`
      if (!comparison.failed_branches.length) { goal.value = ''; approachA.value = ''; approachB.value = ''; saveDraft() }
    } catch (error) {
      status.textContent = `Comparison could not start: ${error?.message || error}`
    } finally {
      submit.disabled = false
    }
  })
}
