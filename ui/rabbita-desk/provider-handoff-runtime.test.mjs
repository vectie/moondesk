import test from 'node:test'
import assert from 'node:assert/strict'
import {
  connectedWorkspaceUrl,
  parseProviderHandoff,
  providerHandoffRequest,
} from './provider-handoff-runtime.js'

test('desktop fragment accepts one bounded code and never accepts an issuer', () => {
  const code = `lnxc_${'a'.repeat(64)}`
  assert.deepEqual(
    parseProviderHandoff(`#lunanexa_client_id=desktop-workspace&lunanexa_handoff=${code}`),
    { clientId: 'desktop-workspace', handoffCode: code },
  )
  assert.equal(parseProviderHandoff(''), null)
  for (const fragment of [
    '#lunanexa_client_id=desktop-workspace',
    `#lunanexa_handoff=${code}`,
    `#lunanexa_client_id=bad%2Fclient&lunanexa_handoff=${code}`,
    `#lunanexa_client_id=desktop-workspace&lunanexa_handoff=lnxc_short`,
    `#lunanexa_client_id=${'a'.repeat(257)}&lunanexa_handoff=${code}`,
  ]) assert.throws(() => parseProviderHandoff(fragment))
})

test('handoff request contains no issuer or reusable provider secret', () => {
  const request = providerHandoffRequest({
    clientId: 'desktop-workspace',
    handoffCode: `lnxc_${'b'.repeat(64)}`,
  })
  assert.equal(request.credentials, 'same-origin')
  assert.equal(request.cache, 'no-store')
  assert.equal(request.redirect, 'error')
  const body = JSON.parse(request.body)
  assert.deepEqual(Object.keys(body).sort(), ['client_id', 'handoff_code'])
  assert.equal('issuer' in body, false)
  assert.equal('api_secret' in body, false)
})

test('connected MoonCode URL drops every fragment capability', () => {
  const result = new URL(connectedWorkspaceUrl(
    `http://127.0.0.1:4188/?source=portal#lunanexa_handoff=secret`,
  ))
  assert.equal(result.hash, '')
  assert.equal(result.searchParams.get('mode'), 'mooncode')
  assert.equal(result.searchParams.get('source'), 'portal')
})
