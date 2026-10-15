// OpenAI-compatible Realtime WebRTC transport. Only an ephemeral session key
// crosses into the browser; provider configuration remains in MoonClaw.
export class MoonCodeRealtimeClient {
  constructor({ createSession, audio, onState = () => {}, onTranscript = () => {}, onCodingRequest = async () => ({ error: 'Coding is unavailable' }), fetch = globalThis.fetch, Peer = globalThis.RTCPeerConnection, media = globalThis.navigator?.mediaDevices }) {
    Object.assign(this, { createSession, audio, onState, onTranscript, onCodingRequest, fetch, Peer, media })
    this.generation = 0
    this.calls = new Set()
  }

  async start() {
    this.close()
    const generation = this.generation
    const current = () => generation === this.generation
    this.abort = new AbortController()
    this.onState('connecting')
    try {
      if (!this.Peer || !this.media?.getUserMedia) throw new Error('Realtime voice requires WebRTC and microphone access in this browser.')
      const stream = await this.media.getUserMedia({ audio: true })
      if (!current()) { stream.getTracks().forEach(track => track.stop()); return }
      this.stream = stream
      const session = await this.createSession(this.abort.signal)
      if (!current()) return
      if (!session.value || !session.endpoint) throw new Error('The provider did not return a realtime session.')
      const peer = this.peer = new this.Peer()
      peer.ontrack = event => { if (current()) { this.audio.srcObject = event.streams[0]; this.audio.play()?.catch(() => this.onState('playback-blocked')) } }
      peer.onconnectionstatechange = () => {
        if (!current()) return
        if (['failed', 'closed'].includes(peer.connectionState)) { this.close(); this.onState('error', 'Voice connection ended. Start again to reconnect.') }
        else if (peer.connectionState === 'disconnected') this.onState('reconnecting')
        else if (peer.connectionState === 'connected') this.onState('connected')
      }
      for (const track of stream.getAudioTracks()) peer.addTrack(track, stream)
      const channel = this.channel = peer.createDataChannel('oai-events')
      channel.onclose = () => { if (current()) { this.close(); this.onState('error', 'Voice session ended. Start again to reconnect.') } }
      channel.onerror = () => { if (current()) { this.close(); this.onState('error', 'Voice connection failed. Start again to reconnect.') } }
      channel.onopen = () => {
        if (!current()) return
        this.send({ type: 'session.update', session: { type: 'realtime', audio: { input: { transcription: { model: 'gpt-4o-mini-transcribe' } } }, tools: [{ type: 'function', name: 'send_coding_request', description: 'Send a requested code change, repository investigation, or command to the current MoonDesk coding chat. Use this tool for repository work; do not claim files were changed yourself.', parameters: { type: 'object', properties: { request: { type: 'string' } }, required: ['request'], additionalProperties: false } }], tool_choice: 'auto' } })
        this.onState('connected')
      }
      channel.onmessage = event => {
        if (!current()) return
        try { this.receive(JSON.parse(event.data), generation) } catch { /* Ignore non-JSON control frames. */ }
      }
      const offer = await peer.createOffer()
      if (!current()) return
      await peer.setLocalDescription(offer)
      if (!current()) return
      const response = await this.fetch(session.endpoint, { method: 'POST', body: offer.sdp, headers: { Authorization: `Bearer ${session.value}`, 'Content-Type': 'application/sdp' }, signal: this.abort.signal })
      if (!response.ok) throw new Error(`Realtime connection failed (${response.status}). Check that this provider supports WebRTC voice.`)
      const sdp = await response.text()
      if (current()) await peer.setRemoteDescription({ type: 'answer', sdp })
    } catch (error) {
      if (!current()) return
      this.close()
      this.onState('error', error.name === 'NotAllowedError' ? 'Microphone access was not granted.' : error.message)
    }
  }

  send(event) {
    if (this.channel?.readyState !== 'open') return false
    this.channel.send(JSON.stringify(event))
    return true
  }

  receive(event, generation = this.generation) {
    if (event.type === 'conversation.item.input_audio_transcription.completed') this.onTranscript('You', event.transcript, event.item_id)
    if (event.type === 'response.output_audio_transcript.done') this.onTranscript('Voice', event.transcript, event.item_id)
    if (event.type === 'error') this.onState('notice', event.error?.message || 'The voice provider reported an error.')
    if (event.type === 'response.done') {
      for (const item of event.response?.output || []) {
        if (item.type !== 'function_call' || this.calls.has(item.call_id)) continue
        this.calls.add(item.call_id)
        Promise.resolve().then(() => {
          if (generation !== this.generation) return null
          if (item.name !== 'send_coding_request') return { error: 'Unknown tool' }
          return this.onCodingRequest(JSON.parse(item.arguments).request)
        }).catch(error => ({ error: error.message })).then(result => {
          if (generation !== this.generation) return
          this.send({ type: 'conversation.item.create', item: { type: 'function_call_output', call_id: item.call_id, output: JSON.stringify(result) } })
          this.send({ type: 'response.create' })
        })
      }
    }
  }

  mute(value) { this.stream?.getAudioTracks().forEach(track => { track.enabled = !value }) }
  interrupt() { this.send({ type: 'response.cancel' }); this.send({ type: 'output_audio_buffer.clear' }) }
  addContext(text) {
    this.send({ type: 'conversation.item.create', item: { type: 'message', role: 'user', content: [{ type: 'input_text', text }] } })
    this.send({ type: 'response.create' })
  }
  close() {
    this.generation++
    this.abort?.abort()
    this.stream?.getTracks().forEach(track => track.stop())
    this.stream = null
    if (this.peer) this.peer.onconnectionstatechange = null
    this.channel?.close()
    this.peer?.close()
    this.channel = null
    this.peer = null
    this.calls.clear()
    if (this.audio) { this.audio.pause?.(); this.audio.srcObject = null }
    this.onState('closed')
  }
}
