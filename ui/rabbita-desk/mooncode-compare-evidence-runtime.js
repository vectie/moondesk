export function moonCodeComparisonRequest(goal, approachA, approachB) {
  const task = String(goal || '').trim()
  if (!task) return ''
  return `Compare two approaches from the same current workspace baseline. Keep both trials isolated in MoonFort until I choose a winner.\n\nGoal:\n${task}\n\nApproach A:\n${String(approachA || '').trim() || 'Choose the most direct safe approach.'}\n\nApproach B:\n${String(approachB || '').trim() || 'Choose a materially different safe approach.'}\n\nFor each branch report the output, diff, checks, warnings, latency, token usage, and estimated cost. Recommend a winner, but do not promote either branch without my explicit choice.`
}

export function moonCodeComparisonBranches(goal, approachA, approachB, comparison = {}) {
  const task = String(goal || '').trim()
  if (!task) return []
  const comparisonId = String(comparison.id || '').trim()
  const baselineDigest = String(comparison.baseline_request_digest || '').trim()
  return [
    ['A', String(approachA || '').trim() || 'Choose the most direct safe approach.'],
    ['B', String(approachB || '').trim() || 'Choose a materially different safe approach.'],
  ].map(([label, approach]) => ({
    label,
    title: `Compare ${label}: ${task}`.slice(0, 96),
    comparison_id: comparisonId,
    baseline_request_digest: baselineDigest,
    prompt: `Run branch ${label} of an explicit comparison from one shared workspace baseline. Use a MoonFort fork child and do not promote its changes.\n\nComparison ID:\n${comparisonId || 'not supplied'}\n\nShared baseline request digest:\n${baselineDigest || 'not supplied'}\n\nGoal:\n${task}\n\nApproach:\n${approach}\n\nBefore changing files, require a MoonFort snapshot/fork receipt bound to the comparison ID and shared baseline request digest. Refuse the comparison branch if that binding is unavailable. Return typed output, diff, checks, warnings, latency, token usage, estimated cost, sandbox receipt, parent snapshot ID, and promotion evidence.`,
  }))
}

export async function comparisonRequestIdentity(root, goal) {
  const id = `comparison-${globalThis.crypto?.randomUUID?.() || `${Date.now()}-${Math.random().toString(36).slice(2)}`}`
  const text = JSON.stringify({
    contract: 'moondesk.mooncode_comparison.v1',
    id,
    workspace_id: root?.dataset?.workspaceId || '',
    context_path: root?.dataset?.contextPath || '',
    goal: String(goal || '').trim(),
  })
  if (globalThis.crypto?.subtle) {
    const bytes = await globalThis.crypto.subtle.digest('SHA-256', new TextEncoder().encode(text))
    const digest = Array.from(new Uint8Array(bytes), value => value.toString(16).padStart(2, '0')).join('')
    return { id, baseline_request_digest: `sha256:${digest}` }
  }
  return { id, baseline_request_digest: `request:${encodeURIComponent(text).slice(0, 120)}` }
}

export function comparisonSessionProjection(session) {
  const summary = session?.mooncode_summary || {}
  return {
    id: String(session?.id || ''),
    status: String(session?.status || 'unknown'),
    event_count: Math.max(0, Number(summary.event_count) || 0),
    verified_test_count: Math.max(0, Number(summary.verified_test_count) || 0),
    pending_diff_count: Math.max(0, Number(summary.pending_diff_count) || 0),
  }
}

function comparisonStorageKey(root) {
  return `moondesk.mooncode.comparisons.v1:${root.dataset.workspaceId || 'general'}`
}

function saveRecoveryCopy(root, comparison) {
  try { globalThis.localStorage?.setItem(comparisonStorageKey(root), JSON.stringify(comparison)) } catch {}
}

function loadRecoveryCopy(root) {
  try { return JSON.parse(globalThis.localStorage?.getItem(comparisonStorageKey(root)) || 'null') } catch { return null }
}

export async function saveComparison(root, comparison) {
  const candidate = {
    ...comparison,
    contract: 'moondesk.mooncode_comparison.v1',
    workspace_id: root.dataset.workspaceId || '',
    context_path: root.dataset.contextPath || '',
  }
  try {
    const response = await fetch('/api/mooncode/comparisons', {
      method: 'POST',
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify(candidate),
    })
    const payload = await response.json().catch(() => ({}))
    if (!response.ok || payload.contract !== 'moondesk.mooncode_comparison.v1') {
      throw new Error(payload.message || `HTTP ${response.status}`)
    }
    const durable = { ...payload, persistence: 'durable' }
    saveRecoveryCopy(root, durable)
    return durable
  } catch (error) {
    const recovery = {
      ...candidate,
      persistence: 'local-recovery',
      persistence_error: String(error?.message || error || 'comparison persistence failed'),
    }
    saveRecoveryCopy(root, recovery)
    return recovery
  }
}

export async function loadComparison(root) {
  const workspaceId = root.dataset.workspaceId || ''
  if (workspaceId) {
    try {
      const response = await fetch(`/api/mooncode/comparisons?workspace_id=${encodeURIComponent(workspaceId)}`)
      const payload = await response.json().catch(() => ({}))
      const comparisons = Array.isArray(payload.comparisons) ? payload.comparisons : []
      if (response.ok && comparisons[0]?.id) {
        const durable = { ...comparisons[0], persistence: 'durable' }
        saveRecoveryCopy(root, durable)
        return durable
      }
    } catch {}
  }
  return loadRecoveryCopy(root)
}
