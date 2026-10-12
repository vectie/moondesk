import test from 'node:test'
import assert from 'node:assert/strict'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

test('installed source runtime jumps, restores selection/scroll, opens files and cancels pending navigation', () => {
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
  const control = action => surface.querySelector(`[data-action="source-navigation-${action}"]`)
  const location = surface.querySelector('[data-source-location]')
  const status = () => surface.querySelector('[data-source-navigation-status]').textContent
  const original = editor.value
  location.value = '3:2'; control('go').click()
  assert.equal(editor.selectionStart, 14); assert.equal(editor.selectionEnd, 14)
  control('back').click(); assert.equal(editor.selectionStart, 1); assert.equal(editor.selectionEnd, 4)
  assert.equal(editor.selectionDirection, 'backward'); assert.equal(editor.scrollTop, 12); assert.equal(editor.scrollLeft, 7)
  control('forward').click(); assert.equal(editor.selectionStart, 14)
  location.value = '99'; control('go').click(); assert.match(status(), /3 lines/); assert.equal(editor.selectionStart, 14)
  location.value = '2'; emit('keydown', location, { key: 'Enter' }); assert.equal(editor.selectionStart, 6)
  assert.equal(emit('keydown', editor, { key: 'g', ctrlKey: true }).prevented, true); assert.equal(document.activeElement, location)
  assert.equal(editor.value, original)
  // Existing semantic-result handler enters the same navigation path.
  const result = new Button(); result.dataset = { semanticPath: 'b.mbt', semanticLine: '2', semanticColumn: '2' }; surface.append(result)
  result.click(); assert.equal(opened, 'b.mbt'); assert.equal(control('back').disabled, true)
  control('cancel').click(); assert.equal(control('cancel').disabled, true); assert.match(status(), /canceled/)
  result.click(); surface.dataset.sourcePath = 'b.mbt'; editor.value = 'other\nfile'; editor.disabled = true
  emit('scroll', editor); assert.equal(control('back').disabled, true)
  editor.disabled = false; emit('scroll', editor); assert.equal(editor.selectionStart, 7); assert.equal(control('back').disabled, false)
  control('back').click(); assert.equal(opened, 'a.mbt')
  surface.dataset.sourcePath = 'a.mbt'; editor.value = original; emit('scroll', editor)
  assert.equal(editor.selectionStart, 6); assert.equal(editor.value, original)
  // Local F12 definitions and changed drafts retain reviewable return context.
  surface.dataset.sourceDirty = 'true'; editor.value = 'fn target() {}\ntarget()'; editor.setSelectionRange(17, 17)
  emit('keydown', editor, { key: 'F12' }); assert.equal(editor.selectionStart, 3); assert.equal(editor.selectionEnd, 9)
  editor.value = 'short'; emit('input', editor)
  control('back').click(); assert.equal(editor.selectionStart, 5); assert.match(status(), /text changed/)
  // Composition shortcuts do not hijack text input.
  assert.equal(emit('keydown', editor, { key: 'g', ctrlKey: true, isComposing: true }).prevented, undefined)
  // Pending return is not allowed to mutate a different workspace.
  control('forward').click(); surface.dataset.workspaceId = 'different'; emit('scroll', editor)
  assert.equal(control('back').disabled, true); assert.equal(control('forward').disabled, true); assert.equal(control('cancel').disabled, true)
})
