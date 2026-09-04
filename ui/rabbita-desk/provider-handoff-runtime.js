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
  return next.href
}
