import test from 'node:test'
import assert from 'node:assert/strict'
import { MoonCodeRealtimeClient } from './mooncode-realtime-client.js'

function fixture(overrides = {}) {
  const events = [], requests = [], transcripts = [], coding = []
  const track = { enabled: true, stopped: 0, stop() { this.stopped++ } }
  const stream = { getTracks: () => [track], getAudioTracks: () => [track] }
  const channel = { readyState: 'open', send: value => events.push(JSON.parse(value)), close() { this.readyState = 'closed' } }
  let peer
  class Peer {
    constructor() { peer = this }
    addTrack(value) { this.track = value }
    createDataChannel(name) { this.channelName = name; return channel }
    async createOffer() { return { type: 'offer', sdp: 'fixture-sdp-offer' } }
    async setLocalDescription(value) { this.local = value }
    async setRemoteDescription(value) { this.remote = value }
    close() { this.closed = true }
  }
  const audio = { pause() {}, play: async () => {} }
  const client = new MoonCodeRealtimeClient({
    Peer, audio, media: { getUserMedia: async () => stream },
    createSession: async () => ({ value: 'ephemeral-fixture', endpoint: 'https://voice.fixture/v1/realtime/calls' }),
    fetch: async (...args) => { requests.push(args); return { ok: true, text: async () => 'fixture-sdp-answer' } },
    onTranscript: (...args) => transcripts.push(args),
    onCodingRequest: async request => { coding.push(request); return { status: 'running' } },
    ...overrides,
  })
  return { client, channel, events, requests, transcripts, coding, track, audio, peer: () => peer }
}

test('WebRTC exchanges SDP with ephemeral token and configures real coding tool', async () => {
  const f = fixture()
  await f.client.start()
  assert.equal(f.peer().channelName, 'oai-events')
  assert.equal(f.peer().track, f.track)
  assert.deepEqual(f.peer().remote, { type: 'answer', sdp: 'fixture-sdp-answer' })
  assert.equal(f.requests[0][1].headers.Authorization, 'Bearer ephemeral-fixture')
  assert.equal(f.requests[0][1].body, 'fixture-sdp-offer')
  f.channel.onopen()
  assert.equal(f.events[0].session.tools[0].name, 'send_coding_request')
  f.client.mute(true)
  assert.equal(f.track.enabled, false)
  f.client.interrupt()
  assert.deepEqual(f.events.slice(-2).map(event => event.type), ['response.cancel', 'output_audio_buffer.clear'])
  f.client.close()
  assert.equal(f.track.stopped, 1)
  assert.equal(f.peer().closed, true)
})

test('provider transcripts and coding calls are forwarded once, results returned to provider', async () => {
  const f = fixture()
  await f.client.start()
  f.client.receive({ type: 'conversation.item.input_audio_transcription.completed', transcript: 'Fix tests', item_id: 'u1' })
  f.client.receive({ type: 'response.output_audio_transcript.done', transcript: 'Starting the task', item_id: 'a1' })
  const event = { type: 'response.done', response: { output: [{ type: 'function_call', name: 'send_coding_request', call_id: 'call1', arguments: '{"request":"Fix tests"}' }] } }
  f.client.receive(event)
  f.client.receive(event)
  await new Promise(resolve => setImmediate(resolve))
  assert.deepEqual(f.coding, ['Fix tests'])
  assert.equal(f.transcripts.length, 2)
  assert.equal(f.events[0].item.type, 'function_call_output')
  assert.equal(f.events[0].item.call_id, 'call1')
  assert.equal(f.events[1].type, 'response.create')
  f.client.close()
})

test('late microphone permission after close is discarded without provider request', async () => {
  let grant, stopped = 0, sessions = 0
  const f = fixture({ media: { getUserMedia: () => new Promise(resolve => { grant = resolve }) }, createSession: async () => { sessions++; return {} } })
  const pending = f.client.start()
  f.client.close()
  grant({ getTracks: () => [{ stop() { stopped++ } }] })
  await pending
  assert.equal(stopped, 1)
  assert.equal(sessions, 0)
})

test('provider negotiation failure releases the microphone and peer', async () => {
  const states = []
  const f = fixture({ fetch: async () => ({ ok: false, status: 400 }), onState: (...args) => states.push(args) })
  await f.client.start()
  assert.equal(f.track.stopped, 1)
  assert.equal(f.peer().closed, true)
  assert.equal(states.at(-1)[0], 'error')
  assert.match(states.at(-1)[1], /400/)
})
