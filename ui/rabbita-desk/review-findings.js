const KEY = 'moondesk.review.findings.v1'
export function readReviewFindings(storage = globalThis.localStorage) {
  try { const value = JSON.parse(storage?.getItem(KEY) || '[]'); return Array.isArray(value) ? value : [] } catch { return [] }
}
export function saveReviewFindings(findings, storage = globalThis.localStorage) { try { storage?.setItem(KEY, JSON.stringify(findings)) } catch { /* Context submission can still proceed. */ } }
export function linkSubmittedFindings(findings, submission) {
  const text = JSON.stringify(submission.contexts || [])
  return findings.map(finding => finding.workspaceId === submission.workspaceId && text.includes(`[Review finding ${finding.id}]`) ? {
    ...finding, sessionId: submission.sessionId, clientTurnId: submission.clientTurnId || '', status: 'submitted',
  } : finding)
}
export function reconcileReviewFinding(finding, conversation) {
  const turn = [...conversation].reverse().find(turn => JSON.stringify(turn.user || {}).includes(`[Review finding ${finding.id}]`))
  return turn ? { ...finding, commandId: turn.command_id, taskStatus: turn.status, taskAnswer: turn.assistant?.content || turn.assistant?.message || turn.assistant?.text || '' } : finding
}
