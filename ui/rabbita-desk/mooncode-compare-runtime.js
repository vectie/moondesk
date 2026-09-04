async function createComparisonSession(root, branch) {
  const response = await fetch('/api/mooncode/sessions', {
    method: 'POST',
    headers: { 'content-type': 'application/json' },
    body: JSON.stringify({
      action: 'prompt',
      workspace_id: root.dataset.workspaceId || '',
      title: branch.title,
      message: branch.prompt,
      client_turn_id: `compare-${branch.label.toLowerCase()}-${globalThis.crypto?.randomUUID?.() || Date.now()}`,
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
  if (!response.ok || !payload.id) throw new Error(payload.message || `Branch ${branch.label} was not accepted`)
  return { ...branch, id: payload.id, status: payload.status || 'queued' }
}

async function refreshComparisonSessions(sessions) {
  const { comparisonSessionProjection } = await import('./mooncode-compare-evidence-runtime.js')
  return Promise.all(sessions.map(async session => {
    try {
      const response = await fetch(`/api/mooncode/sessions/${encodeURIComponent(session.id)}?format=compact`)
      if (!response.ok) return session
      const payload = await response.json()
      return { ...session, ...comparisonSessionProjection(payload) }
    } catch {
      return session
    }
  }))
}

function openComparisonSession(session) {
  const sessionButton = document.querySelector(`[data-testid="mooncode-session"][data-session-id="${CSS.escape(session.id)}"]`)
  if (sessionButton instanceof HTMLButtonElement) sessionButton.click()
  else globalThis.location.reload()
}

export function openMoonCodeCompareFrom(root, action) {
  const messages = Array.from(document.querySelectorAll('[data-testid="mooncode-message"]'))
  const currentIndex = messages.indexOf(action.closest('[data-testid="mooncode-message"]'))
  const prior = messages.slice(0, Math.max(0, currentIndex)).reverse()
    .find(message => message.dataset.role === 'user')
  const goal = prior?.querySelector('.mooncode-message-body')?.textContent?.trim() ||
    'Try a materially different implementation for the current result.'
  root.open = true
  root.querySelector('[data-developer-tool-tab="compare"]')?.click()
  const field = root.querySelector('[data-developer-compare-goal]')
  if (field instanceof HTMLTextAreaElement) {
    field.value = goal
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
  heading.innerHTML = `<strong>Shared comparison</strong><small></small>`
  heading.querySelector('small').textContent = `${comparison.id} · ${comparison.baseline_request_digest}`
  results.append(heading)
  for (const session of comparison.sessions) {
    const card = document.createElement('article')
    card.className = 'mooncode-compare-result'
    const title = document.createElement('strong')
    title.textContent = `Branch ${session.label}`
    const detail = document.createElement('small')
    detail.textContent = `${session.status} · ${session.event_count || 0} events · ${session.verified_test_count || 0} verified checks · ${session.id}`
    const open = document.createElement('button')
    open.type = 'button'
    open.className = 'mooncode-developer-terminal-submit'
    open.textContent = 'Open branch'
    open.addEventListener('click', () => openComparisonSession(session))
    const choose = document.createElement('button')
    choose.type = 'button'
    choose.className = 'mooncode-developer-terminal-submit'
    choose.textContent = comparison.selected_branch === session.label
      ? 'Selected for promotion review'
      : 'Select for promotion review'
    choose.disabled = comparison.selected_branch === session.label
    choose.addEventListener('click', async () => {
      choose.disabled = true
      comparison.selected_branch = session.label
      comparison.selected_at = new Date().toISOString()
      const persisted = await saveComparison(root, comparison)
      Object.assign(comparison, persisted)
      renderComparisonSessions(panel, root, comparison)
      openComparisonSession(session)
    })
    card.append(title, detail, open, choose)
    results.append(card)
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
  if (!panel.querySelector('[data-developer-compare-form]')) panel.innerHTML = `
    <div class="mooncode-developer-tool-heading">
      <div><h3>Fork & compare</h3><p>Trial two approaches from one workspace baseline, then promote only the winner.</p></div>
      <span class="mooncode-developer-tool-badge">MoonFort isolated</span>
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
  submit.disabled = false
  submit.dataset.compareReady = 'true'
  import('./mooncode-compare-evidence-runtime.js').then(async ({ loadComparison }) => {
    const saved = await loadComparison(root)
    if (saved?.id && Array.isArray(saved.sessions) && saved.sessions.length === 2) {
      renderComparisonSessions(panel, root, saved)
      if (status) status.textContent = saved.persistence === 'durable'
        ? 'Restored durable comparison and branch evidence.'
        : 'Restored a local recovery copy; the service receipt is unavailable.'
    }
  })
  if (root.__mooncodeCompareDraft) {
    goal.value = root.__mooncodeCompareDraft
    approachA.value = 'Improve the current result with the smallest safe change.'
    approachB.value = 'Use a materially different implementation strategy.'
    root.__mooncodeCompareDraft = ''
  }
  form.addEventListener('submit', async event => {
    event.preventDefault()
    const {
      comparisonRequestIdentity,
      moonCodeComparisonBranches,
      saveComparison,
    } = await import('./mooncode-compare-evidence-runtime.js')
    const identity = await comparisonRequestIdentity(root, goal.value)
    const branches = moonCodeComparisonBranches(goal.value, approachA.value, approachB.value, identity)
    if (!branches.length) return
    submit.disabled = true
    status.textContent = 'Starting two isolated MoonCode branches…'
    try {
      const sessions = await Promise.all(branches.map(branch => createComparisonSession(root, branch)))
      let comparison = {
        contract: 'moondesk.mooncode_comparison.v1',
        ...identity,
        goal: goal.value.trim(),
        sessions,
        selected_branch: '',
        created_at: new Date().toISOString(),
      }
      comparison = await saveComparison(root, comparison)
      renderComparisonSessions(panel, root, comparison)
      status.textContent = comparison.persistence === 'durable'
        ? 'Both branches are durably recorded under one baseline request. Selection opens the branch receipt; promotion still requires explicit reviewed MoonFort evidence.'
        : `Both branches started, but only a local recovery copy was saved: ${comparison.persistence_error || 'service unavailable'}`
      goal.value = ''
      approachA.value = ''
      approachB.value = ''
    } catch (error) {
      status.textContent = `Comparison could not start: ${error?.message || error}`
    } finally {
      submit.disabled = false
    }
  })
}
