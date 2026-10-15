import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import test from 'node:test'
import vm from 'node:vm'
import { iconMarkup, setIconButton } from './ui-icons.js'

const source = (await readFile(new URL('./mooncode-media-tools-runtime.js', import.meta.url), 'utf8'))
  .replace(/^import .*$/gm, '')
  .replace('export function installMoonCodeMediaTools', 'function installMoonCodeMediaTools')

function fixture() {
  class Element {
    constructor() { this.dataset = {}; this.events = {}; this.children = []; this.value = ''; this.textContent = ''; this.isConnected = true; this.classList = { add() {} } }
    addEventListener(name, callback) { this.events[name] = callback }
    setAttribute(name, value) { this[name] = value }
    getAttribute(name) { return this[name] ?? null }
    append(...children) { for (const child of children) { child.parentElement = this; this.children.push(child) } }
    insertBefore(child, reference) { child.parentElement = this; this.children = this.children.filter(item => item !== child); const index = this.children.indexOf(reference); this.children.splice(index < 0 ? this.children.length : index, 0, child) }
    get nextElementSibling() { const siblings = this.parentElement?.children || []; return siblings[siblings.indexOf(this) + 1] || null }
    contains(element) { return element === this || this.children.some(child => child.contains(element)) }
    querySelector() { return null }
    dispatchEvent(event) { this.events[event.type]?.(event) }
    click() { this.events.click?.() }
    closest() { return target }
    focus() { this.focused = true }
  }
  const target = new Element()
  const footer = new Element()
  const attachment = new Element()
  footer.append(attachment)
  target.append(footer)
  target.querySelector = selector => selector === '.composer-footer' ? footer : null
  footer.querySelector = selector => selector.includes('mooncode-attach-image') ? attachment : null
  const field = new Element()
  const root = new Element()
  root.dataset = { workspaceId: 'book', sessionId: 'chat' }
  const send = new Element()
  let sent = 0
  send.addEventListener('click', () => { sent++; field.value = '' })
  const recognition = []
  const spoken = []
  const answers = []
  let mounted = false
  class Recognition {
    constructor() { recognition.push(this) }
    start() {}
    abort() {}
    stop() { this.onend() }
  }
  const window = {
    SpeechRecognition: Recognition,
    SpeechSynthesisUtterance: class { constructor(text) { this.text = text } },
    speechSynthesis: { cancel() {}, speak(value) { spoken.push(value) } },
    events: {}, addEventListener(name, callback) { this.events[name] = callback }, dispatchEvent() {},
  }
  const document = {
    documentElement: new Element(),
    createElement: () => new Element(),
    querySelector: selector => !mounted ? null : selector.includes('mooncode-input') ? field : selector.includes('mooncode-center') ? root : selector.includes('mooncode-send') ? send : null,
    querySelectorAll: () => answers,
  }
  const sandbox = {
    iconMarkup, setIconButton,
    document, window, navigator: { language: 'en-US' },
    SpeechSynthesisUtterance: window.SpeechSynthesisUtterance,
    MutationObserver: class { observe() {} },
    InputEvent: class { constructor(type, values) { this.type = type; Object.assign(this, values) } },
    requestAnimationFrame: callback => callback(),
  }
  vm.runInNewContext(`${source}\nglobalThis.api = { state, installMoonCodeMediaTools, startListening, stopVoice, speak, startCapture };`, sandbox)
  mounted = true
  sandbox.api.installMoonCodeMediaTools()
  return { ...sandbox, field, root, target, footer, attachment, recognition, spoken, answers, sent: () => sent }
}

function finishRecognition(recognition, text) {
  const result = [{ transcript: text }]
  result.isFinal = true
  recognition.onresult({ resultIndex: 0, results: [result] })
  recognition.onend()
}

test('dictation preserves the draft and requires review before sending', () => {
  const f = fixture()
  assert.equal(f.api.state.shell.parentElement, f.footer)
  assert.equal(f.api.state.shell.nextElementSibling, f.attachment)
  f.field.value = 'Existing question'
  f.api.startListening()
  assert.equal(f.api.state.dictate.getAttribute('aria-pressed'), 'true')
  assert.equal(f.api.state.dictate.getAttribute('aria-label'), 'Stop dictation')
  finishRecognition(f.recognition.at(-1), 'Please explain this error')
  assert.equal(f.field.value, 'Existing question\nPlease explain this error')
  assert.equal(f.sent(), 0)
  assert.equal(f.api.state.dictate.getAttribute('aria-pressed'), 'false')
})

test('media popover dismisses on Escape with focus return and on outside pointer', () => {
  const f = fixture()
  f.api.state.shell.open = true
  let prevented = false
  f.window.events.keydown({ key: 'Escape', preventDefault() { prevented = true }, stopPropagation() {} })
  assert.equal(f.api.state.shell.open, false)
  assert.equal(f.api.state.summary.focused, true)
  assert.equal(prevented, true)
  f.api.state.shell.open = true
  f.window.events.pointerdown({ target: f.api.state.dictate })
  assert.equal(f.api.state.shell.open, true)
  f.window.events.pointerdown({ target: f.field })
  assert.equal(f.api.state.shell.open, false)
})

test('voice turns send once, wait for a completed answer, then listen again', () => {
  const f = fixture()
  f.api.state.voiceButton.click()
  finishRecognition(f.recognition.at(-1), 'What changed?')
  assert.equal(f.sent(), 1)
  assert.equal(f.api.state.waiting, true)
  const answer = { dataset: { status: 'running', commandId: 'turn' }, querySelector: () => ({ innerText: 'The build is fixed.' }) }
  f.answers.push(answer)
  f.api.installMoonCodeMediaTools()
  assert.equal(f.spoken.length, 0)
  answer.dataset.status = 'done'
  f.api.installMoonCodeMediaTools()
  assert.equal(f.spoken.length, 1)
  assert.equal(f.api.state.waiting, false)
  f.spoken[0].onend()
  assert.equal(f.recognition.length, 2)
})

test('stopping read aloud prevents a cancelled utterance from resuming', () => {
  const f = fixture()
  f.api.speak('First sentence. Second sentence.')
  assert.equal(f.spoken.length, 1)
  f.api.stopVoice()
  f.spoken[0].onend()
  assert.equal(f.spoken.length, 1)
})

test('a camera permission result arriving after navigation closes its tracks', async () => {
  const f = fixture()
  let resolve
  let stopped = 0
  f.navigator.mediaDevices = { getUserMedia: () => new Promise(done => { resolve = done }) }
  const pending = f.api.startCapture('camera')
  f.root.dataset.sessionId = 'another-chat'
  resolve({ getTracks: () => [{ stop: () => stopped++ }] })
  await pending
  assert.equal(stopped, 1)
  assert.equal(f.api.state.stream, null)
})

test('switching chats ends provider voice and clears its transient transcript', () => {
  const f = fixture()
  let closed = 0
  f.api.state.realtime = { close() { closed++ } }
  f.api.state.realtimeTranscript.textContent = 'You: discuss the previous Book'
  f.root.dataset.sessionId = 'another-chat'
  f.api.installMoonCodeMediaTools()
  assert.equal(closed, 1)
  assert.equal(f.api.state.realtimeTranscript.textContent, '')
})
