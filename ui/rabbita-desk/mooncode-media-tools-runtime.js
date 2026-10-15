import './styles/mooncode-media-tools.css'
import './styles/mooncode-media-clean.css'
import { MoonCodeRealtimeClient } from './mooncode-realtime-client.js'
import { iconMarkup, setIconButton } from './ui-icons.js'

const state = { shell: null, context: '', recognition: null, stream: null, voice: false, waiting: false, replyBefore: '', captureKind: '', busyCapture: false, speechToken: 0, captureToken: 0 }
const recognitionClass = () => window.SpeechRecognition || window.webkitSpeechRecognition
const composer = () => document.querySelector('[data-testid="mooncode-input"]')
const context = () => {
  const root = document.querySelector('[data-testid="mooncode-center"]')
  return `${root?.dataset.workspaceId || ''}:${root?.dataset.sessionId || ''}`
}

function node(tag, className, text) {
  const element = document.createElement(tag)
  element.className = className
  if (text) element.textContent = text
  return element
}

function button(label, action) {
  const element = node('button', 'mooncode-media-button', label)
  element.type = 'button'
  element.addEventListener('click', action)
  const icon = { Dictate: 'mic', 'Voice turns': 'chat', 'Stop speaking': 'stop', 'Share screen': 'browser', 'Attach this frame': 'attach', 'Stop capture': 'stop', 'Start provider voice': 'mic', Mute: 'mic', 'Interrupt voice': 'stop', 'Transcript to draft': 'chat' }[label]
  if (icon) setIconButton(element, icon, label)
  return element
}

function status(message, severity = 'info') {
  if (state.status && state.status.textContent !== message) state.status.textContent = message
  state.noticeSeverity = severity
  if (state.status) state.status.dataset.severity = severity
  updateSummary()
}

function updateSummary() {
  if (!state.summary) return
  const active = []
  if (state.realtime) {
    if (state.realtimePhase === 'connected') active.push(state.realtimeMuted ? 'Muted' : 'Voice connected')
    else if (state.realtimePhase === 'connecting') active.push('Connecting')
    else if (state.realtimePhase === 'reconnecting') active.push('Reconnecting')
    else if (state.realtimePhase === 'playback-blocked') active.push('Audio paused')
  }
  if (state.recognition) active.push('Listening')
  else if (state.speaking) active.push('Speaking')
  else if (state.voice) active.push(state.waiting ? 'Waiting for answer' : 'Voice turns on')
  if (state.stream) active.push(state.captureKind === 'screen' ? 'Screen shared' : 'Camera on')
  if (state.noticeSeverity === 'error') active.push('Needs attention')
  const label = `Voice & screen${active.length ? ` · ${active.join(' · ')}` : ''}`
  const icon = state.noticeSeverity === 'error' ? 'failed' : state.realtimeMuted ? 'mic-off' : 'mic'
  const signature = `${icon}:${label}`
  if (state.summary.dataset.signature !== signature) {
    state.summary.dataset.signature = signature
    state.summary.innerHTML = `${iconMarkup(icon)}${active.length ? `<span class="mooncode-media-indicator">${active.join(' · ')}</span>` : ''}`
    state.summary.setAttribute('aria-label', label)
    state.summary.title = label
    state.summary.dataset.tooltip = label
    state.summary.dataset.active = String(Boolean(active.length))
    state.summary.dataset.severity = state.noticeSeverity || 'info'
  }
  if (state.screenButton) setIconButton(state.screenButton, 'browser', state.stream && state.captureKind === 'screen' ? 'Choose another screen' : 'Share screen', { pressed: Boolean(state.stream && state.captureKind === 'screen') })
  state.cameraButton?.setAttribute('aria-pressed', String(Boolean(state.stream && state.captureKind === 'camera')))
  if (state.stopSpeaking) state.stopSpeaking.disabled = !state.voice && !state.speaking
}

function stopListening() {
  const recognition = state.recognition
  state.recognition = null
  recognition?.abort()
  updateSummary()
  if (state.dictate) setIconButton(state.dictate, 'mic', 'Dictate into draft', { pressed: false })
}

function stopVoice() {
  state.speechToken++
  state.voice = false
  state.waiting = false
  state.speaking = false
  stopListening()
  window.speechSynthesis?.cancel()
  if (state.voiceButton) setIconButton(state.voiceButton, 'chat', 'Start voice turns: send each phrase and read the answer', { pressed: false })
  updateSummary()
}

function stopRealtime() {
  const realtime = state.realtime
  state.realtime = null
  realtime?.close()
  state.realtimeWaiting = false
  state.realtimeMuted = false
  state.realtimePhase = 'closed'
  if (state.realtimeAudio) state.realtimeAudio.hidden = true
  if (state.realtimeStart) setIconButton(state.realtimeStart, 'mic', 'Start provider voice', { pressed: false })
  if (state.realtimeMute) { state.realtimeMute.disabled = true; setIconButton(state.realtimeMute, 'mic', 'Mute microphone', { pressed: false }) }
  if (state.realtimeInterrupt) state.realtimeInterrupt.disabled = true
  updateSummary()
}

async function startRealtime() {
  if (state.realtime) { stopRealtime(); status('Provider voice ended.'); return }
  if (composer()?.value.trim()) { status('Send or clear your existing draft before starting provider voice.'); composer().focus(); return }
  stopVoice()
  const root = document.querySelector('[data-testid="mooncode-center"]')
  const workspaceId = root?.dataset.workspaceId
  if (!workspaceId) { status('Choose a Book before starting provider voice.'); return }
  state.realtimeLines = []
  state.realtimeTranscript.textContent = ''
  state.transcriptToDraft.disabled = true
  const client = new MoonCodeRealtimeClient({
    audio: state.realtimeAudio,
    createSession: async signal => {
      const model = document.querySelector('[data-testid="mooncode-model-select"]')?.value || ''
      const response = await fetch(`/api/mooncode/workspaces/${encodeURIComponent(workspaceId)}/realtime-session`, {
        method: 'POST', headers: { 'Content-Type': 'application/json' }, signal,
        body: JSON.stringify({ session_id: root.dataset.sessionId || '', model, realtime_model: state.realtimeModel.value.trim() || 'gpt-realtime', voice: 'marin', context: `You are a spoken coding companion in MoonDesk. For repository investigation or edits, use send_coding_request; actual work happens in the coding chat. Do not claim work is complete until the chat result is provided. Latest chat answer:\n${latestAnswer()?.text.slice(-12000) || '(new chat)'}` }),
      })
      const result = await response.json()
      if (!response.ok) throw new Error(result.error?.message || result.error || result.message || 'Could not start provider voice. Check the selected provider configuration.')
      return result
    },
    onState: (phase, message) => {
      if (state.realtime !== client) return
      state.realtimePhase = phase
      if (phase === 'error') { stopRealtime(); status(message, 'error'); return }
      const labels = { connecting: 'Connecting provider voice…', connected: 'Provider voice connected. Speak naturally; coding requests run in this chat.', reconnecting: 'Voice connection interrupted. Waiting for the network…', 'playback-blocked': 'Press Play voice to enable audio playback.' }
      if (labels[phase] || message) status(message || labels[phase], phase === 'notice' ? 'error' : 'info')
      if (['connected', 'playback-blocked'].includes(phase)) state.realtimeAudio.hidden = false
      if (phase === 'connected') { state.realtimeMute.disabled = false; state.realtimeInterrupt.disabled = false }
      updateSummary()
    },
    onTranscript: (speaker, text, id) => {
      if (!text || state.realtime !== client) return
      const existing = state.realtimeLines.find(line => line.id === id && line.speaker === speaker)
      if (existing) existing.text = text
      else state.realtimeLines.push({ speaker, text, id })
      state.realtimeTranscript.textContent = state.realtimeLines.map(line => `${line.speaker}: ${line.text}`).join('\n')
      state.transcriptToDraft.disabled = false
    },
    onCodingRequest: async request => {
      if (state.realtime !== client || typeof request !== 'string' || !request.trim()) return { error: 'No coding request provided' }
      if (state.realtimeWaiting || composer()?.value.trim()) return { error: 'A coding request or user draft is already in progress. Ask the user to review it first.' }
      if (!appendDraft(request)) return { error: 'The coding chat is no longer available' }
      await new Promise(resolve => requestAnimationFrame(resolve))
      if (state.realtime !== client) return { error: 'Voice session ended' }
      const send = document.querySelector('[data-testid="mooncode-send"]')
      if (!send || send.disabled) return { status: 'draft', message: 'Request added to draft. User needs to review and send it.' }
      state.realtimeReplyBefore = latestAnswer()?.key || ''
      state.realtimeWaiting = true
      send.click()
      return { status: 'running', message: 'Coding task started in the chat. Results will follow when it completes.' }
    },
  })
  state.realtime = client
  state.realtimePhase = 'connecting'
  setIconButton(state.realtimeStart, 'stop', 'End provider voice', { pressed: true })
  state.realtimeMute.disabled = true
  state.realtimeInterrupt.disabled = true
  updateSummary()
  await client.start()
}

function stopCapture() {
  state.captureToken++
  state.stream?.getTracks().forEach(track => track.stop())
  state.stream = null
  if (state.video) state.video.srcObject = null
  if (state.preview) state.preview.hidden = true
  if (state.snapshot) state.snapshot.disabled = true
  updateSummary()
}

function appendDraft(text) {
  const field = composer()
  if (!field || context() !== state.context) return false
  field.value = `${field.value}${field.value.trim() ? '\n' : ''}${text}`
  field.dispatchEvent(new InputEvent('input', { bubbles: true, composed: true, inputType: 'insertText', data: text }))
  return true
}

function latestAnswer() {
  const messages = [...document.querySelectorAll('.mooncode-message[data-role="assistant"]')]
  const message = messages.at(-1)
  if (!message) return null
  const body = message.querySelector('.mooncode-message-body')
  const text = body?.innerText?.trim() || body?.textContent?.trim() || ''
  const identity = `${message.dataset.commandId || ''}:${message.dataset.clientTurnId || ''}`
  return { text, status: message.dataset.status, key: identity === ':' ? text : identity }
}

function speak(text, after) {
  if (!window.speechSynthesis || !window.SpeechSynthesisUtterance) { status('Read aloud is not available in this browser.'); after?.(); return }
  stopListening()
  const token = ++state.speechToken
  state.speaking = true
  window.speechSynthesis.cancel()
  // Speak short chunks so stopping/interrupting works on browser speech engines.
  const chunks = text.match(/[^.!?。！？\n]+[.!?。！？\n]*/g) || [text]
  let index = 0
  const next = () => {
    if (token !== state.speechToken) return
    if (index >= chunks.length) { state.speaking = false; status('Finished reading.'); after?.(); return }
    const utterance = new SpeechSynthesisUtterance(chunks[index++])
    utterance.lang = state.language.value
    utterance.onend = next
    utterance.onerror = () => { if (token === state.speechToken) { stopVoice(); status('Reading stopped.', 'error') } }
    window.speechSynthesis.speak(utterance)
  }
  status('Reading the answer aloud…')
  next()
}

function startListening() {
  const Recognition = recognitionClass()
  if (!Recognition) { status('Dictation is not supported in this browser. You can still attach screen or camera images.'); return }
  stopListening()
  state.speechToken++
  window.speechSynthesis?.cancel()
  const recognition = new Recognition()
  state.recognition = recognition
  recognition.lang = state.language.value
  recognition.continuous = false
  recognition.interimResults = true
  let finalText = ''
  recognition.onresult = event => {
    let interim = ''
    for (let index = event.resultIndex; index < event.results.length; index++) {
      const text = event.results[index][0].transcript
      if (event.results[index].isFinal) finalText += text
      else interim += text
    }
    state.transcript.textContent = finalText + interim
  }
  recognition.onerror = event => {
    if (state.recognition !== recognition || event.error === 'aborted') return
    stopVoice()
    status(event.error === 'not-allowed' ? 'Microphone access was not granted. Enable it in browser settings and try again.' : `Dictation stopped: ${event.error}. You can try again.`, 'error')
  }
  recognition.onend = () => {
    if (state.recognition !== recognition) return
    state.recognition = null
    updateSummary()
    setIconButton(state.dictate, 'mic', 'Dictate into draft', { pressed: false })
    const text = finalText.trim()
    if (!text) { stopVoice(); status('No speech detected. Press Dictate to try again.'); return }
    if (!appendDraft(text)) { stopVoice(); return }
    if (!state.voice) { status('Dictation added to your draft. Review and send when ready.'); return }
    requestAnimationFrame(() => {
      if (!state.voice) return
      const send = document.querySelector('[data-testid="mooncode-send"]')
      if (!send || send.disabled) { stopVoice(); status('Your voice message is in the draft. Review and send when ready.'); return }
      state.replyBefore = latestAnswer()?.key || ''
      state.waiting = true
      send.click()
      status('Waiting for the answer. Voice turns will read it aloud, then listen again.')
    })
  }
  try {
    recognition.start()
    updateSummary()
    setIconButton(state.dictate, 'mic', 'Stop dictation', { pressed: true })
    status(state.voice ? 'Listening. Your next phrase will be sent when you finish speaking.' : 'Listening. Your words will be added to the draft for review.')
  } catch (error) { stopVoice(); status(error.message || 'Could not start dictation.', 'error') }
}

async function startCapture(kind) {
  stopCapture()
  const captureToken = state.captureToken
  try {
    const media = navigator.mediaDevices
    if (!media || (kind === 'screen' && !media.getDisplayMedia)) throw new Error('Screen sharing is not supported in this browser. Attach a screenshot instead.')
    if (kind === 'camera' && !media.getUserMedia) throw new Error('Camera capture is not supported in this browser. Attach a photo instead.')
    const startedIn = context()
    const stream = kind === 'screen'
      ? await media.getDisplayMedia({ video: true, audio: false })
      : await media.getUserMedia({ video: { facingMode: 'environment' }, audio: false })
    if (captureToken !== state.captureToken || startedIn !== context() || !state.shell.isConnected) { stream.getTracks().forEach(track => track.stop()); return }
    state.stream = stream
    state.captureKind = kind
    updateSummary()
    state.video.srcObject = stream
    state.preview.hidden = false
    await state.video.play()
    state.snapshot.disabled = false
    stream.getVideoTracks()[0].addEventListener('ended', () => {
      if (state.stream === stream) { stopCapture(); status('Capture stopped.') }
    }, { once: true })
    status(`Showing ${kind === 'screen' ? 'your shared screen' : 'your camera'}. Only frames you attach are sent with a message.`)
  } catch (error) {
    if (captureToken !== state.captureToken) return
    stopCapture()
    status(error.name === 'NotAllowedError' ? 'Capture was cancelled or permission was not granted.' : error.message || 'Could not start capture.', 'error')
  }
}

async function attachFrame() {
  if (!state.stream || state.busyCapture) return
  const input = document.querySelector('[data-testid="mooncode-image-file-input"]')
  if (!input || input.disabled) { status('The image tray is full or a message is sending. Remove an image or wait, then attach the frame.'); return }
  const video = state.video
  if (!video.videoWidth || !video.videoHeight) { status('Waiting for the first video frame…'); return }
  const selectedContext = context()
  state.busyCapture = true
  try {
    const scale = Math.min(1, 2560 / Math.max(video.videoWidth, video.videoHeight))
    const canvas = document.createElement('canvas')
    canvas.width = Math.round(video.videoWidth * scale)
    canvas.height = Math.round(video.videoHeight * scale)
    canvas.getContext('2d').drawImage(video, 0, 0, canvas.width, canvas.height)
    let blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/png'))
    if (!blob) throw new Error('Could not capture the frame. Try again.')
    if (blob.size > 8 * 1024 * 1024) blob = await new Promise(resolve => canvas.toBlob(resolve, 'image/jpeg', 0.9))
    if (!blob || blob.size > 8 * 1024 * 1024) throw new Error('This frame is too large. Share a smaller window and try again.')
    if (selectedContext !== context()) return
    const name = `${state.captureKind}-${new Date().toISOString().replaceAll(':', '-')}.${blob.type === 'image/png' ? 'png' : 'jpg'}`
    const file = new File([blob], name, { type: blob.type })
    window.dispatchEvent(new CustomEvent('moondesk:code-images', { detail: { files: [file], source: state.captureKind } }))
    status('Frame attached to the image tray. Add your question, then send it.')
  } catch (error) { status(error.message || 'Could not attach this frame.', 'error') }
  finally { state.busyCapture = false }
}

function createShell() {
  const shell = node('details', 'mooncode-media-tools')
  shell.dataset.testid = 'mooncode-media-tools'
  state.summary = node('summary', 'mooncode-media-disclosure')
  shell.append(state.summary)
  const body = node('div', 'mooncode-media-body')
  body.setAttribute('role', 'group')
  body.setAttribute('aria-label', 'Voice and screen tools')
  const toolbar = node('div', 'mooncode-media-toolbar')
  toolbar.setAttribute('role', 'group')
  toolbar.setAttribute('aria-label', 'Browser speech')
  toolbar.append(node('span', 'mooncode-media-group-label', 'Speech'))
  state.dictate = button('Dictate', () => {
    if (state.recognition) { state.recognition.stop(); return }
    stopRealtime(); stopVoice(); startListening()
  })
  setIconButton(state.dictate, 'mic', 'Dictate into draft', { pressed: false })
  state.voiceButton = button('Voice turns', () => {
    if (state.voice) { stopVoice(); status('Voice turns ended.'); return }
    if (composer()?.value.trim()) { status('Send or clear your existing draft before starting voice turns.'); composer().focus(); return }
    if (!recognitionClass()) { status('Voice turns need browser speech recognition, which is unavailable here.'); return }
    stopRealtime()
    state.voice = true
    setIconButton(state.voiceButton, 'stop', 'End voice turns', { pressed: true })
    startListening()
  })
  setIconButton(state.voiceButton, 'chat', 'Start voice turns: send each phrase and read the answer', { pressed: false })
  const read = button('Read answer', () => {
    stopRealtime()
    stopVoice()
    const answer = latestAnswer()
    if (!answer?.text) { status('There is no answer to read yet.'); return }
    speak(answer.text)
  })
  state.stopSpeaking = button('Stop speaking', () => { stopVoice(); status('Speaking stopped.') })
  state.language = node('select', 'mooncode-media-language')
  state.language.setAttribute('aria-label', 'Spoken language')
  for (const [value, label] of [['en-US', 'English'], ['zh-CN', '中文'], ['ja-JP', '日本語'], ['es-ES', 'Español'], ['fr-FR', 'Français'], ['de-DE', 'Deutsch'], ['ko-KR', '한국어']]) {
    const option = node('option', '', label); option.value = value; state.language.append(option)
  }
  state.language.value = navigator.language?.startsWith('zh') ? 'zh-CN' : 'en-US'
  toolbar.append(state.dictate, state.voiceButton, read, state.stopSpeaking, state.language)
  const captureToolbar = node('div', 'mooncode-media-toolbar')
  captureToolbar.setAttribute('role', 'group')
  captureToolbar.setAttribute('aria-label', 'Screen and camera capture')
  state.screenButton = button('Share screen', () => startCapture('screen'))
  state.cameraButton = button('Camera', () => startCapture('camera'))
  state.cameraButton.title = 'Open camera preview; attach only the frames you choose'
  captureToolbar.append(node('span', 'mooncode-media-group-label', 'Capture'), state.screenButton, state.cameraButton)
  state.transcript = node('p', 'mooncode-media-transcript')
  state.transcript.setAttribute('aria-live', 'polite')
  state.status = node('p', 'mooncode-media-status')
  state.status.setAttribute('role', 'status')
  state.preview = node('div', 'mooncode-media-preview')
  state.preview.hidden = true
  state.video = node('video', 'mooncode-media-video')
  state.video.muted = true
  state.video.playsInline = true
  state.video.setAttribute('aria-label', 'Live capture preview')
  state.snapshot = button('Attach this frame', attachFrame)
  state.snapshot.disabled = true
  const captureActions = node('div', 'mooncode-media-toolbar')
  captureActions.append(state.snapshot, button('Stop capture', () => { stopCapture(); status('Capture stopped.') }))
  state.preview.append(state.video, captureActions)
  const realtime = node('details', 'mooncode-realtime-tools')
  realtime.append(node('summary', '', 'Provider realtime voice'))
  const realtimeToolbar = node('div', 'mooncode-media-toolbar')
  state.realtimeModel = node('input', 'mooncode-media-language')
  state.realtimeModel.value = 'gpt-realtime'
  state.realtimeModel.setAttribute('aria-label', 'Realtime model')
  const realtimeModelLabel = node('label', 'mooncode-media-model-label')
  realtimeModelLabel.append(node('span', 'mooncode-media-group-label', 'Model'), state.realtimeModel)
  state.realtimeStart = button('Start provider voice', startRealtime)
  setIconButton(state.realtimeStart, 'mic', 'Start provider voice', { pressed: false })
  state.realtimeMute = button('Mute', () => {
    const muted = state.realtimeMute.getAttribute('aria-pressed') !== 'true'
    state.realtime?.mute(muted)
    state.realtimeMuted = muted
    setIconButton(state.realtimeMute, muted ? 'mic-off' : 'mic', muted ? 'Unmute microphone' : 'Mute microphone', { pressed: muted })
    updateSummary()
  })
  setIconButton(state.realtimeMute, 'mic', 'Mute microphone', { pressed: false })
  state.realtimeMute.disabled = true
  state.realtimeInterrupt = button('Interrupt voice', () => state.realtime?.interrupt())
  state.realtimeInterrupt.disabled = true
  state.realtimeAudio = node('audio', '')
  state.realtimeAudio.autoplay = true
  state.realtimeAudio.controls = true
  state.realtimeAudio.hidden = true
  state.realtimeAudio.setAttribute('aria-label', 'Play voice')
  state.realtimeTranscript = node('p', 'mooncode-media-transcript mooncode-realtime-transcript')
  state.transcriptToDraft = button('Transcript to draft', () => {
    const text = state.realtimeTranscript.textContent
    if (text && appendDraft(`Voice conversation:\n${text}`)) status('Voice transcript added to your draft. Review and send to save it in this chat.')
  })
  state.transcriptToDraft.disabled = true
  realtimeToolbar.append(state.realtimeStart, state.realtimeMute, state.realtimeInterrupt, state.transcriptToDraft)
  realtime.append(node('p', 'mooncode-media-status', 'Uses your chat provider’s Realtime API and microphone. Coding requests run in this chat. Add the transcript to your draft to keep it.'), realtimeModelLabel, realtimeToolbar, state.realtimeAudio, state.realtimeTranscript)
  body.append(toolbar, captureToolbar, realtime, state.transcript, state.status, state.preview)
  shell.append(body)
  state.shell = shell
  updateSummary()
  return shell
}

export function installMoonCodeMediaTools() {
  const target = composer()?.closest('.mooncode-composer')
  if (!target) {
    if (state.context) { stopRealtime(); stopVoice(); stopCapture(); state.context = '' }
    return
  }
  const footer = target.querySelector('.composer-footer')
  if (!footer) return
  const nextContext = context()
  if (state.context !== nextContext) {
    // Creating the first chat assigns its session ID after sending a voice turn.
    const creatingSession = ((state.voice && state.waiting) || (state.realtime && state.realtimeWaiting)) && state.context.endsWith(':') && nextContext.startsWith(state.context)
    if (!creatingSession) {
      stopRealtime(); stopVoice(); stopCapture()
      state.realtimeLines = []
      if (state.realtimeTranscript) state.realtimeTranscript.textContent = ''
      if (state.transcript) state.transcript.textContent = ''
      if (state.transcriptToDraft) state.transcriptToDraft.disabled = true
      if (state.shell) state.shell.open = false
      status('')
    }
    state.context = nextContext
  }
  if (!state.shell) createShell()
  const attachment = footer.querySelector('[data-testid="mooncode-attach-image"]')
  if (state.shell.parentElement !== footer || (attachment && state.shell.nextElementSibling !== attachment)) footer.insertBefore(state.shell, attachment)
  if (state.realtime && state.realtimeWaiting) {
    const answer = latestAnswer()
    if (answer?.text && answer.key !== state.realtimeReplyBefore && ['done', 'complete', 'completed', 'succeeded', 'failed', 'interrupted', 'cancelled'].includes(answer.status)) {
      state.realtimeWaiting = false
      state.realtime.addContext(`Coding chat result (${answer.status}):\n${answer.text.slice(-24000)}`)
    }
  }
  if (state.voice && state.waiting) {
    const answer = latestAnswer()
    if (answer?.text && answer.key !== state.replyBefore && ['done', 'complete', 'completed', 'succeeded'].includes(answer.status)) {
      state.waiting = false
      speak(answer.text, () => { if (state.voice) startListening() })
    }
  }
}

if (typeof document !== 'undefined') {
  installMoonCodeMediaTools()
  new MutationObserver(installMoonCodeMediaTools).observe(document.documentElement, {
    childList: true, subtree: true, attributes: true, attributeFilter: ['data-session-id', 'data-workspace-id', 'data-status'],
  })
  window.addEventListener('pagehide', () => { stopRealtime(); stopVoice(); stopCapture() })
  window.addEventListener('keydown', event => {
    if (event.key !== 'Escape' || !state.shell?.open) return
    event.preventDefault()
    event.stopPropagation()
    state.shell.open = false
    state.summary.focus()
  })
  window.addEventListener('pointerdown', event => {
    if (state.shell?.open && !state.shell.contains(event.target)) state.shell.open = false
  })
}
