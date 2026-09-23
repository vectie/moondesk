const HANDOFF_CODE = /^lnxc_[0-9a-f]{64}$/i
const CLIENT_ID = /^[A-Za-z0-9_.:-]{1,256}$/

export const parseProviderHandoff = hash => {
  const fragment = new URLSearchParams(String(hash || '').replace(/^#/, ''))
  const handoffCode = fragment.get('lunanexa_handoff') || ''
  const clientId = fragment.get('lunanexa_client_id') || ''
  if (!handoffCode && !clientId) return null
  if (!HANDOFF_CODE.test(handoffCode) || !CLIENT_ID.test(clientId)) {
    throw new Error('The desktop handoff link is malformed or incomplete.')
  }
  return { clientId, handoffCode }
}

export const providerHandoffRequest = ({ clientId, handoffCode }) => ({
  method: 'POST',
  headers: { 'Accept': 'application/json', 'Content-Type': 'application/json' },
  credentials: 'same-origin',
  cache: 'no-store',
  redirect: 'error',
  body: JSON.stringify({ client_id: clientId, handoff_code: handoffCode }),
})

export const connectedWorkspaceUrl = href => {
  const next = new URL(href)
  next.hash = ''
  next.searchParams.set('mode', 'mooncode')
  next.searchParams.set('activity', 'code')
  return next.href
}

// Only advance these checkpoints after the corresponding observable result.
// The redemption and MoonGate installation happen in one server request, so
// the browser must not claim either has completed while that request is open.
export const providerHandoffSteps = [
  'Validate one-time link',
  'Verify account and workspace lease',
  'Connect the serving model through MoonGate',
  'Open Code workspace',
]

export const providerHandoffPercent = completed =>
  Math.max(0, Math.min(providerHandoffSteps.length, completed)) * 25
