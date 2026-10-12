import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

// Minimal browser adapters exercise the installed production event handlers.
// They do not establish browser, native host, save/reopen or layout behavior.
test('installed source editor reviews and applies JSON replacements through one draft input event', async t => {
  const listeners = new Map(), blobs = new Map(), downloads = [], timers = [], revoked = []
  const sourceInputs = []
  let activeSurface
  const emit = (type, target, rest = {}) => { if (type === 'input' && target.dataset.testid === 'source-editor-input') sourceInputs.push(target.value); const event = { target, key: '', preventDefault() { this.prevented = true }, ...rest }; for (const fn of listeners.get(type) || []) fn(event); return event }
  const datasetKey = key => key.replace(/^data-/, '').replace(/-([a-z])/g, (_, x) => x.toUpperCase())
  class Element {
    constructor(tag = 'div') { this.tagName = tag; this.dataset = {}; this.children = []; this.attrs = {}; this.style = {}; this.textContent = ''; this.className = ''; this.disabled = false; this.isConnected = true; this.classList = { toggle() {}, add() {}, remove() {} } }
    setAttribute(key, value) { this.attrs[key] = value; if (key.startsWith('data-')) this.dataset[datasetKey(key)] = value }
    removeAttribute(key) { delete this.attrs[key] }
    append(...nodes) { for (const node of nodes) { node.parentElement = this; this.children.push(node) } }
    replaceChildren(...nodes) { this.children = []; this.append(...nodes) }
    remove() { this.parentElement.children = this.parentElement.children.filter(child => child !== this); this.isConnected = false }
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
    click() { if (!this.disabled) { if (this.tagName === 'a') downloads.push({ name: this.download, blob: blobs.get(this.href) }); else emit('click', this) } }
    dispatchEvent(event) { emit(event.type, this); return true }
  }
  class Input extends Element { constructor() { super('input'); this.value = '' } }
  class Button extends Element { constructor() { super('button') } }
  class Textarea extends Element {
    constructor() { super('textarea'); this.value = ''; this.selectionStart = 1; this.selectionEnd = 4; this.selectionDirection = 'backward'; this.scrollTop = 12; this.scrollLeft = 7 }
    setRangeText(value, start, end) { this.value = this.value.slice(0, start) + value + this.value.slice(end); this.setSelectionRange(start, start + value.length) }
    setSelectionRange(start, end, direction = 'none') { this.selectionStart = start; this.selectionEnd = end; this.selectionDirection = direction }
  }
  const globals = ['Element', 'HTMLElement', 'HTMLInputElement', 'HTMLButtonElement', 'HTMLTextAreaElement', 'getComputedStyle', 'requestAnimationFrame', 'MutationObserver', 'document', 'setTimeout']
  const original = Object.fromEntries(globals.map(name => [name, globalThis[name]]))
  const originalCreate = URL.createObjectURL, originalRevoke = URL.revokeObjectURL
  Object.assign(globalThis, { Element, HTMLElement: Element, HTMLInputElement: Input, HTMLButtonElement: Button, HTMLTextAreaElement: Textarea,
    getComputedStyle: () => ({ lineHeight: '20px' }), requestAnimationFrame: fn => fn(), MutationObserver: class { observe() {} },
    setTimeout: fn => { timers.push(fn) } })
  URL.createObjectURL = blob => { const key = `blob:test-${blobs.size}`; blobs.set(key, blob); return key }
  URL.revokeObjectURL = key => revoked.push(key)
  const element = tag => tag === 'input' ? new Input() : tag === 'button' ? new Button() : tag === 'textarea' ? new Textarea() : new Element(tag)
  globalThis.document = { body: new Element('body'), activeElement: null, getElementById: () => activeSurface,
    addEventListener(type, fn) { listeners.set(type, [...(listeners.get(type) || []), fn]) }, createElement: element,
    querySelectorAll: selector => activeSurface?.querySelectorAll(selector) || [] }
  const fixture = readFileSync(new URL('../../docs/samples/json-values/orders.json', import.meta.url), 'utf8')
  const open = (path = 'orders.json', text = fixture) => {
    const surface = new Element(); surface.className = 'source-editor'; surface.dataset = { testid: 'source-editor', sourcePath: path, workspaceId: 'book', sourceDirty: 'false' }
    const node = (tag, id) => { const item = element(tag); item.dataset.testid = id; surface.append(item); return item }
    const editor = node('textarea', 'source-editor-input'); editor.value = text
    const highlight = node('pre', 'source-highlight'); highlight.append(new Element('code'))
    node('div', 'source-completions'); node('div', 'source-local-diagnostics'); node('div', 'source-semantic-results')
    const language = node('span', 'source-language'); language.textContent = 'JSON'
    document.body.append(surface); activeSurface = surface
    return { surface, editor, language }
  }
  try {
    let { surface, editor, language } = open()
    installSourceEditorRuntime()
    const control = action => activeSurface.querySelector(`[data-action="source-json-${action}"]`)
    const field = name => activeSurface.querySelector(`[data-json-${name}]`)
    const inspect = pointer => { field('pointer').value = pointer; control('go').click() }
    const input = value => { field('replacement').value = value; emit('input', field('replacement')) }
    const preview = value => { input(value); control('replace-review').click() }
    const reopen = (path = 'orders.json', text = fixture) => {
      surface.remove(); ({ surface, editor, language } = open(path, text)); emit('scroll', editor)
    }

    await t.test('sample correction previews exact before/after then emits one editor edit; repeated apply does nothing', async () => {
      inspect('/orders/0/details/paid'); control('replace-open').click()
      assert.equal(field('replacement').value, 'false')
      assert.equal(field('replacement-section').hidden, false)
      assert.equal(document.activeElement, field('replacement'))
      assert.equal(control('replace-apply').disabled, true)
      control('replace-review').click()
      assert.match(field('replacement-status').textContent, /No change/)
      assert.equal(control('replace-apply').disabled, true)
      preview(' true ')
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, 0)
      assert.equal(surface.dataset.sourceRuntimeDirty, undefined)
      assert.equal(field('replacement-before').textContent, 'Before (boolean):\nfalse')
      assert.equal(field('replacement-after').textContent, 'After (boolean):\ntrue')
      assert.match(field('replacement-status').textContent, /\/orders\/0\/details\/paid/)
      // A typed but uninspected pointer does not silently change the reviewed target.
      field('pointer').value = '/orders/1/amount'
      control('replace-apply').click()
      assert.equal(editor.value, fixture.replace('"paid": false', '"paid": true'))
      assert.equal(sourceInputs.length, 1); assert.equal(sourceInputs[0], editor.value)
      assert.equal(surface.dataset.sourceRuntimeDirty, 'true')
      assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), 'true')
      assert.equal(field('replacement-section').hidden, true)
      assert.match(field('status').textContent, /Replaced \/orders\/0\/details\/paid in the unsaved draft/)
      control('replace-apply').click(); assert.equal(sourceInputs.length, 1)
      control('download').click(); assert.equal(await downloads.at(-1).blob.text(), 'true')
    })

    await t.test('cancel and invalid replacement leave source and input history untouched; correction remains possible', () => {
      reopen(); inspect('/orders/0/details'); control('replace-open').click()
      const before = sourceInputs.length
      preview('{"paid":true,}')
      assert.match(field('replacement-status').textContent, /strict JSON value/)
      assert.equal(control('replace-apply').disabled, true); assert.equal(editor.value, fixture)
      preview('{"paid":true}')
      control('replace-cancel').click()
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, before)
      assert.equal(field('replacement-section').hidden, true); assert.equal(field('replacement').value, '')
      control('replace-open').click(); preview('{"paid":true}'); control('replace-apply').click()
      assert.equal(editor.value, fixture.replace('{ "paid": false, "note": "\\u4e2D" }', '{"paid":true}'))
      assert.equal(sourceInputs.length, before + 1)
    })

    await t.test('editing replacement or source requires a new preview before any apply', () => {
      reopen(); inspect('/orders/0/details/paid'); control('replace-open').click(); preview('true')
      input('null'); assert.equal(control('replace-apply').disabled, true)
      control('replace-review').click()
      field('replacement').value = 'false' // no input event
      const before = sourceInputs.length
      control('replace-apply').click()
      assert.match(field('replacement-status').textContent, /changed/)
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, before)
      preview('true')
      editor.value = fixture.replace('12.50', '25.00'); emit('input', editor)
      assert.equal(control('replace-apply').disabled, true)
      assert.equal(field('replacement').value, 'true')
      assert.match(field('replacement-status').textContent, /Draft or editor availability changed/)
      control('replace-review').click(); control('replace-apply').click()
      assert.ok(editor.value.includes('25.00')); assert.ok(editor.value.includes('"paid": true'))
      control('replace-open').click(); preview('null')
      editor.value = fixture // no input event
      const unchangedCount = sourceInputs.length
      control('replace-apply').click()
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, unchangedCount)
      assert.equal(control('replace-apply').disabled, true)
      assert.match(field('status').textContent, /Draft changed/)
    })

    await t.test('target changes and unavailable editors clear or invalidate review without editing', () => {
      reopen(); inspect('/orders/0'); control('replace-open').click(); preview('null')
      editor.disabled = true; emit('scroll', editor)
      assert.equal(field('replacement').disabled, true); assert.equal(control('replace-apply').disabled, true)
      editor.disabled = false; emit('scroll', editor)
      assert.equal(control('replace-apply').disabled, true)
      control('replace-review').click()
      inspect('/orders/1')
      assert.equal(field('replacement-section').hidden, true); assert.equal(field('replacement').value, '')
      control('replace-open').click(); preview('[]')
      surface.dataset.sourcePath = 'different.json'; emit('scroll', editor)
      assert.equal(field('replacement-section').hidden, true)
      control('replace-open').click(); preview('null')
      surface.dataset.workspaceId = 'different-book'; emit('scroll', editor)
      assert.equal(field('replacement-section').hidden, true)
      control('replace-open').click(); preview('null')
      language.textContent = 'Plain text'; emit('scroll', editor)
      language.textContent = 'JSON'; emit('scroll', editor)
      assert.equal(field('replacement-section').hidden, true)
      control('replace-open').click(); preview('null')
      const oldApply = control('replace-apply'), before = sourceInputs.length
      reopen('orders.json', '{"new":false}')
      oldApply.click(); assert.equal(editor.value, '{"new":false}')
      assert.equal(sourceInputs.length, before); assert.equal(field('replacement-section').hidden, true)
    })

    await t.test('large root replacement reports shortened previews but applies full exact value', () => {
      reopen('array.json', ' [0, 1] \n')
      control('replace-open').click()
      const replacement = '{"label":"' + 'x'.repeat(4500) + '","id":900719925474099312345}'
      preview(replacement)
      assert.match(field('replacement-status').textContent, /Preview shortened/)
      assert.match(field('replacement-status').textContent, /\(root\)/)
      const before = sourceInputs.length
      control('replace-apply').click()
      assert.equal(editor.value, ` ${replacement} \n`); assert.equal(sourceInputs.length, before + 1)
    })

    await t.test('failed editor insertion restores exact draft and selection without reporting success', () => {
      reopen(); inspect('/orders/0/details/paid'); control('replace-open').click(); preview('true')
      const selection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
      const before = sourceInputs.length
      editor.setRangeText = () => { editor.value = 'partial'; throw new Error('adapter insertion refused') }
      control('replace-apply').click()
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, before)
      assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], selection)
      assert.match(field('replacement-status').textContent, /adapter insertion refused/)
      assert.equal(field('replacement-section').hidden, false)
      assert.equal(control('replace-apply').disabled, true)
    })
  } finally {
    Object.assign(globalThis, original); URL.createObjectURL = originalCreate; URL.revokeObjectURL = originalRevoke
  }
})
