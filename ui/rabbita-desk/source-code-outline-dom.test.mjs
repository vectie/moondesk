import test from 'node:test'
import assert from 'node:assert/strict'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

test('installed code outline filters current drafts and navigates without editing', () => {
  const listeners = new Map()
  const emit = (type, target, rest = {}) => { const event = { target, key: '', preventDefault() { this.prevented = true }, ...rest }; for (const fn of listeners.get(type) || []) fn(event); return event }
  const datasetKey = key => key.replace(/^data-/, '').replace(/-([a-z])/g, (_, x) => x.toUpperCase())
  class Element {
    constructor(tag = 'div') { this.tagName = tag; this.dataset = {}; this.children = []; this.attrs = {}; this.textContent = ''; this.className = ''; this.disabled = false; this.isConnected = true; this.classList = { toggle() {}, add() {}, remove() {} } }
    setAttribute(key, value) { this.attrs[key] = value; if (key.startsWith('data-')) this.dataset[datasetKey(key)] = value }
    removeAttribute(key) { delete this.attrs[key] }
    append(...nodes) { for (const node of nodes) { node.parentElement = this; this.children.push(node) } }
    replaceChildren(...nodes) { this.children = []; this.append(...nodes) }
    matches(selector) {
      if (selector === '.source-editor') return this.className === 'source-editor'
      if (selector === 'code') return this.tagName === 'code'
      const match = /^\[([^=\]]+)(?:="([^"]*)")?\]$/.exec(selector)
      if (!match) return false
      const value = match[1].startsWith('data-') ? this.dataset[datasetKey(match[1])] : this.attrs[match[1]]
      return value !== undefined && (match[2] === undefined || value === match[2])
    }
    closest(selector) { return this.matches(selector) ? this : this.parentElement?.closest(selector) || null }
    querySelectorAll(selector) {
      if (selector.includes(' ')) { const [first, second] = selector.split(' '); return this.querySelector(first)?.querySelectorAll(second) || [] }
      return this.children.flatMap(child => [...(child.matches(selector) ? [child] : []), ...child.querySelectorAll(selector)])
    }
    querySelector(selector) { return this.querySelectorAll(selector)[0] || null }
    focus() { document.activeElement = this }
    click() { if (!this.disabled) { emit('click', this); this.onClick?.() } }
    dispatchEvent(event) { emit(event.type, this); return true }
  }
  class Input extends Element { constructor() { super('input'); this.value = '' } }
  class Button extends Element { constructor() { super('button') } }
  class Textarea extends Element {
    constructor() { super('textarea'); this.value = 'first\nsecond\nthird'; this.selectionStart = 1; this.selectionEnd = 4; this.selectionDirection = 'backward'; this.scrollTop = 12; this.scrollLeft = 7 }
    setSelectionRange(start, end, direction = 'none') { this.selectionStart = start; this.selectionEnd = end; this.selectionDirection = direction }
  }
  Object.assign(globalThis, { Element, HTMLElement: Element, HTMLInputElement: Input, HTMLButtonElement: Button, HTMLTextAreaElement: Textarea,
    getComputedStyle: () => ({ lineHeight: '20px' }), requestAnimationFrame: fn => fn(), MutationObserver: class { observe() {} } })
  const surface = new Element(); surface.className = 'source-editor'; surface.dataset = { testid: 'source-editor', sourcePath: 'a.mbt', workspaceId: 'book', sourceDirty: 'false' }
  const node = (tag, id) => { const item = tag === 'textarea' ? new Textarea() : tag === 'input' ? new Input() : tag === 'button' ? new Button() : new Element(tag); item.dataset.testid = id; surface.append(item); return item }
  const editor = node('textarea', 'source-editor-input')
  const highlight = node('pre', 'source-highlight'); highlight.append(new Element('code'))
  node('div', 'source-completions'); node('div', 'source-local-diagnostics'); node('div', 'source-semantic-results')
  node('span', 'source-language').textContent = 'MoonBit'
  const path = node('input', 'source-path'), open = node('button', 'source-open')
  let opened = ''
  open.onClick = () => { opened = path.value }
  globalThis.document = { body: surface, activeElement: null, getElementById: () => surface,
    addEventListener(type, fn) { listeners.set(type, [...(listeners.get(type) || []), fn]) },
    createElement: tag => tag === 'input' ? new Input() : tag === 'button' ? new Button() : new Element(tag),
    querySelectorAll: selector => surface.querySelectorAll(selector) }
  installSourceEditorRuntime()
  const filter = surface.querySelector('[data-code-outline-filter]')
  const status = () => surface.querySelector('[data-code-outline-status]').textContent
  const items = () => surface.querySelector('[data-code-outline-list]').children
  editor.value = '///|\npub fn Cat::jump() {}\n// fn fake() {}\nstruct Cat {}\nfn later() {}'
  editor.setSelectionRange(0, 0); emit('input', editor)
  assert.equal(items().length, 3)
  assert.match(items()[0].textContent, /Cat::jump · L2/)
  assert.match(status(), /Not compiler symbols/)
  const bytes = editor.value; const dirty = surface.dataset.sourceRuntimeDirty
  items()[0].click()
  assert.equal(editor.selectionStart, bytes.indexOf('Cat::jump'))
  assert.equal(editor.selectionEnd, bytes.indexOf('Cat::jump') + 'Cat::jump'.length)
  assert.equal(editor.value, bytes); assert.equal(surface.dataset.sourceRuntimeDirty, dirty)
  surface.querySelector('[data-action="source-navigation-back"]').click()
  assert.equal(editor.selectionStart, 0)
  filter.value = 'LATER'; emit('input', filter)
  assert.equal(items().length, 1); assert.match(items()[0].textContent, /later/)
  filter.value = 'missing'; emit('input', filter)
  assert.equal(items().length, 0); assert.match(status(), /0 matching/)
  filter.value = ''; emit('input', filter)
  const stale = items()[0]
  editor.value = 'fn refreshed() {}'
  stale.click(); assert.equal(editor.selectionStart, 0); assert.equal(items().length, 1)
  assert.match(items()[0].textContent, /refreshed/)
  filter.value = 'ref'; emit('input', filter)
  surface.dataset.sourcePath = 'b.mbt'; editor.value = 'fn other() {}'; emit('scroll', editor)
  assert.equal(filter.value, ''); assert.match(items()[0].textContent, /other/)
  editor.disabled = true; emit('scroll', editor)
  assert.equal(items()[0].disabled, true); assert.equal(filter.disabled, true)
  editor.disabled = false; editor.value = Array.from({length: 105}, (_, i) => `fn item${i}() {}`).join('\n'); emit('input', editor)
  assert.equal(items().length, 100); assert.match(status(), /105 matching; showing 100/)
  filter.value = 'item104'; emit('input', filter); assert.equal(items().length, 1)
  editor.value = 'x'.repeat(120001); emit('input', editor)
  assert.equal(items().length, 0); assert.match(status(), /unavailable above/)
  node('span', 'unused')
})
