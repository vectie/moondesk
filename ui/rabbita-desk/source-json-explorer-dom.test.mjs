import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

// Minimal browser adapters exercise the installed production event handlers.
// They do not establish browser, native host, save/reopen or layout behavior.
test('installed editor explores, selects, downloads and refreshes exact JSON draft values', async () => {
  const listeners = new Map(), blobs = new Map(), downloads = [], timers = [], revoked = []
  let activeSurface
  const emit = (type, target, rest = {}) => { const event = { target, key: '', preventDefault() { this.prevented = true }, ...rest }; for (const fn of listeners.get(type) || []) fn(event); return event }
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
    const status = () => field('status').textContent
    const inspect = pointer => { field('pointer').value = pointer; control('go').click() }
    const child = pointer => field('children').children.find(item => item.dataset.jsonTarget === pointer)
    assert.equal(field('explorer').tagName, 'details')
    assert.match(status(), /\(root\) · object/)
    assert.equal(field('children').children.length, 5)
    child('/orders').click(); child('/orders/0').click(); child('/orders/0/id').click()
    assert.equal(field('pointer').value, '/orders/0/id')
    assert.equal(field('preview').textContent, '900719925474099312345')
    const beforeSelection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
    control('select').click()
    assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), '900719925474099312345')
    surface.querySelector('[data-action="source-navigation-back"]').click()
    assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], beforeSelection)
    control('download').click()
    assert.equal(downloads[0].name, 'json-value.json')
    assert.equal(downloads[0].blob.type, 'application/json;charset=utf-8')
    assert.equal(await downloads[0].blob.text(), '900719925474099312345')
    assert.equal(editor.value, fixture); assert.equal(surface.dataset.sourceRuntimeDirty, undefined)
    control('parent').click(); control('download').click()
    assert.equal(await downloads[1].blob.text(), '{ "id": 900719925474099312345, "amount": -0.00E+09, "details": { "paid": false, "note": "\\u4e2D" } }')
    field('pointer').value = '/a~1b/~0label'
    assert.equal(emit('keydown', field('pointer'), { key: 'Enter', isComposing: true }).prevented, undefined)
    assert.equal(emit('keydown', field('pointer'), { key: 'Enter' }).prevented, true)
    assert.equal(field('preview').textContent, '"🚀"')
    inspect('/review'); assert.ok(field('children').children.every(item => item.disabled))
    inspect('/review/tag'); assert.match(status(), /ambiguous/); assert.equal(control('download').disabled, true)
    control('parent').click(); assert.match(status(), /object/)
    inspect('/orders/0/id')
    editor.value = fixture.replace('900719925474099312345', '900719925474099399999'); emit('input', editor)
    assert.equal(field('preview').textContent, '900719925474099399999'); control('download').click()
    assert.equal(await downloads.at(-1).blob.text(), '900719925474099399999')
    assert.equal(surface.dataset.sourceRuntimeDirty, 'true')
    // A value changed without an input event requires a fresh inspection.
    editor.value = fixture; const count = downloads.length; control('download').click()
    assert.equal(downloads.length, count); assert.match(status(), /Draft changed/)
    control('download').click(); assert.equal(await downloads.at(-1).blob.text(), '900719925474099312345')
    editor.value = '{"orders":'; emit('input', editor)
    assert.equal(control('select').disabled, true); assert.equal(control('download').disabled, true)
    assert.equal(field('preview').textContent, ''); assert.match(status(), /offset/)
    editor.value = '{"other":true}'; emit('input', editor)
    assert.match(status(), /does not exist/); control('root').click(); assert.match(status(), /root/)
    editor.disabled = true; emit('scroll', editor)
    assert.equal(control('go').disabled, true); assert.equal(control('download').disabled, true)
    editor.disabled = false; editor.value = JSON.stringify(Array.from({ length: 125 }, (_, i) => i)); emit('input', editor)
    assert.equal(field('children').children.length, 50); assert.match(status(), /1–50 of 125/)
    const oldChild = child('/0')
    control('next').click(); assert.match(status(), /51–100 of 125/)
    oldChild.click(); assert.equal(field('pointer').value, '')
    control('next').click(); assert.equal(field('children').children.length, 25); assert.match(status(), /101–125 of 125/)
    child('/124').click(); assert.equal(field('preview').textContent, '124')
    control('parent').click(); control('next').click(); control('previous').click(); assert.match(status(), /1–50 of 125/)
    editor.value = JSON.stringify({ long: 'x'.repeat(4500) }); emit('input', editor); inspect('/long')
    assert.equal(field('preview').textContent.length, 4000); assert.match(status(), /preview shortened/)
    control('download').click(); assert.equal((await downloads.at(-1).blob.text()).length, 4502)
    // Changing file or workspace clears the pointer instead of leaking the previous view.
    surface.dataset.sourcePath = 'other.json'; editor.value = '{"safe":true}'; emit('scroll', editor)
    assert.equal(field('pointer').value, ''); inspect('/safe')
    surface.dataset.workspaceId = 'another-book'; emit('scroll', editor); assert.equal(field('pointer').value, '')
    language.textContent = 'Plain text'; emit('scroll', editor); assert.equal(field('explorer').hidden, true)
    language.textContent = 'JSON'; emit('scroll', editor); assert.equal(field('explorer').hidden, false)
    inspect('/safe'); const closedDownload = control('download'); surface.remove()
    ;({ surface, editor, language } = open('other.json', '{"new":false}')); emit('scroll', editor)
    assert.equal(field('pointer').value, ''); assert.match(field('preview').textContent, /new/)
    const closedCount = downloads.length; closedDownload.click(); assert.equal(downloads.length, closedCount)
    // Browser refusal is visible and leaves the draft untouched.
    URL.createObjectURL = () => { throw new Error('download unavailable') }; control('download').click()
    assert.match(status(), /Could not download JSON value: download unavailable/)
    assert.equal(editor.value, '{"new":false}')
    for (const fn of timers) fn()
    assert.equal(revoked.length, downloads.length)
  } finally {
    Object.assign(globalThis, original); URL.createObjectURL = originalCreate; URL.revokeObjectURL = originalRevoke
  }
})
