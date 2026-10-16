import assert from 'node:assert/strict'
import test from 'node:test'
import { readFileSync } from 'node:fs'
import { parseProviderConnection, connectionPreview, providerConnectionRequest, decodeProviderConnection } from './provider-connection-runtime.js'
const fixture = () => ({ version: 'openai.connection.v1', api: 'chat.completions', base_url: 'https://example.invalid:8443/user/v1', api_key: 'test-only-not-a-live-key', model: 'glm-5.3.flash', max_output_tokens: 16384 })

test('generic QR settings preserve the reviewed URL, model, secret and output limit', () => {
  const source = fixture()
  assert.deepEqual(parseProviderConnection(JSON.stringify(source)), source)
  const request = providerConnectionRequest(source)
  assert.equal(request.method, 'POST')
  assert.equal(request.credentials, 'same-origin')
  assert.equal(request.redirect, 'error')
  assert.equal(request.cache, 'no-store')
  assert.deepEqual(JSON.parse(request.body), source)
  assert.ok(!JSON.stringify(connectionPreview(source)).includes(source.api_key))
  const extra = parseProviderConnection(JSON.stringify({ ...source, script: '<script>run()</script>', redirect_url: 'https://other.invalid' }))
  assert.deepEqual(extra, source)
})

test('malformed and credential-bearing URLs cannot become connection requests', () => {
  for (const patch of [
    { version: 'other' }, { api: 'responses' }, { api_key: 'api-key-record-id' }, { api_key: 'key\nheader' },
    { api_key: '' }, { api_key: 'x'.repeat(513) }, { model: '' }, { max_output_tokens: 0 }, { max_output_tokens: 131073 },
    { base_url: 'http://public.example/v1' }, { base_url: 'https://user:secret@example.com/v1' },
    { base_url: 'https://example.com/v1?key=secret' }, { base_url: 'https://example.com/v1#key' },
    { base_url: 'https://example.com/v1/chat/completions' }, { base_url: 'http://127.0.0.1.evil/v1' },
  ]) assert.throws(() => providerConnectionRequest({ ...fixture(), ...patch }))
  assert.throws(() => parseProviderConnection('x'.repeat(8193)))
  assert.throws(() => parseProviderConnection('{broken-private-value'), /Invalid connection settings/)
})

test('an image without a QR cannot import or transmit a connection', () => {
  assert.equal(decodeProviderConnection({ width: 64, height: 64, data: new Uint8ClampedArray(64 * 64 * 4).fill(255) }), null)
})

test('MoonBit MaaS QR decodes into the same generic connection settings', () => {
  // Synthetic secret only. Matrix generated with PaiGack/moonbitqrcode 0.1.0,
  // the encoder used by the signed-in MaaS page.
  const fixture = JSON.parse(readFileSync(new URL('./fixtures/openai-connection-qr.json', import.meta.url)))
  const scale = 5, quiet = 4, width = (fixture.modules.length + quiet * 2) * scale
  const data = new Uint8ClampedArray(width * width * 4).fill(255)
  fixture.modules.forEach((row, y) => row.forEach((black, x) => {
    if (!black) return
    for (let dy = 0; dy < scale; dy++) for (let dx = 0; dx < scale; dx++) {
      const offset = (((y + quiet) * scale + dy) * width + (x + quiet) * scale + dx) * 4
      data[offset] = data[offset + 1] = data[offset + 2] = 0
    }
  }))
  assert.deepEqual(decodeProviderConnection({ data, width, height: width }), fixture.settings)
})
