import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

// Minimal browser adapters exercise the installed production event handlers.
// They do not establish browser, native host, save/reopen or layout behavior.
test('installed source editor compares reference JSON, inspects changes and exports a read-only report', async t => {
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
  const fixture = readFileSync(new URL('../../docs/samples/json-comparison/current.json', import.meta.url), 'utf8')
  const reference = readFileSync(new URL('../../docs/samples/json-comparison/reference.json', import.meta.url), 'utf8')
  const open = (path = 'current.json', text = fixture) => {
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
    const control = name => activeSurface.querySelector(`[data-action="source-json-compare-${name}"]`)
    const field = name => activeSurface.querySelector(`[data-json-compare-${name}]`)
    const status = () => field('status').textContent
    const input = value => { field('reference').value = value; emit('input', field('reference')) }
    const compare = (value = reference) => { input(value); control('run').click() }
    const rows = () => field('results').children
    const selects = () => field('results').querySelectorAll('[data-action="source-json-compare-select"]')
    const reopen = (path = 'current.json', text = fixture) => {
      surface.remove(); ({ surface, editor, language } = open(path, text)); emit('scroll', editor)
    }

    await t.test('sample comparison shows precise changes, navigates and downloads without a draft input', async () => {
      assert.equal(surface.querySelector('[data-json-comparison]').tagName, 'details')
      assert.equal(control('download').disabled, true)
      compare()
      assert.match(status(), /2 added, 1 removed, 3 changed/)
      assert.equal(rows().length, 6)
      assert.equal(rows()[0].children[0].textContent, 'changed · "/account/plan"')
      assert.equal(rows()[0].children[1].textContent, 'Reference (string):\n"trial"')
      assert.equal(rows()[0].children[2].textContent, 'Current draft (string):\n"paid"')
      assert.equal(selects()[1].disabled, true)
      const oldSelection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
      selects()[0].click()
      assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), '"paid"')
      surface.querySelector('[data-action="source-navigation-back"]').click()
      assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], oldSelection)
      control('download').click()
      const download = downloads.at(-1)
      assert.equal(download.name, 'json-differences.json'); assert.equal(download.blob.type, 'application/json;charset=utf-8')
      const report = JSON.parse(await download.blob.text())
      assert.deepEqual(report.counts, { added: 2, removed: 1, changed: 3, total: 6 })
      assert.equal(report.source.path, 'current.json'); assert.equal(report.source.workspaceId, 'book')
      assert.equal(report.changes[3].after.json, '{"sku": "003", "amount": 3}')
      assert.match(status(), /download requested/)
      assert.equal(sourceInputs.length, 0); assert.equal(editor.value, fixture)
      assert.equal(surface.dataset.sourceRuntimeDirty, undefined)
    })

    await t.test('reference edits invalidate reports, including a silent textarea change', () => {
      input('{}'); assert.equal(control('download').disabled, true); assert.equal(rows().length, 0)
      assert.match(status(), /Reference changed/)
      control('run').click(); assert.match(status(), /4 added/)
      field('reference').value = '[]'
      const count = downloads.length; control('download').click()
      assert.equal(downloads.length, count); assert.match(status(), /Reference changed/)
      assert.equal(control('download').disabled, true)
      compare(); assert.match(status(), /2 added, 1 removed, 3 changed/)
    })

    await t.test('draft changes discard stale reports but retain reference for another comparison', () => {
      const old = selects()[0]
      editor.value = fixture.replace('"paid"', '"premium"'); emit('input', editor)
      assert.equal(field('reference').value, reference); assert.equal(rows().length, 0)
      assert.equal(control('download').disabled, true); assert.match(status(), /Draft or editor availability changed/)
      old.click(); assert.equal(rows().length, 0)
      control('run').click(); assert.match(rows()[0].children[2].textContent, /premium/)
      // Stale ranges cannot be used if an out-of-band edit bypasses input.
      const before = [editor.selectionStart, editor.selectionEnd]
      editor.value = ' ' + editor.value
      selects()[0].click()
      assert.deepEqual([editor.selectionStart, editor.selectionEnd], before)
      assert.equal(control('download').disabled, true); assert.equal(rows().length, 0)
      control('run').click(); assert.match(status(), /6/)
    })

    await t.test('invalid or ambiguous inputs yield recoverable errors and never a partial export', () => {
      reopen(); compare('{"bad":}')
      assert.match(status(), /Reference JSON:.*offset/); assert.equal(control('download').disabled, true)
      compare('{"x":1,"x":2}'); assert.match(status(), /duplicate object member/)
      compare(); editor.value = '{'; emit('input', editor); control('run').click()
      assert.match(status(), /Current draft:/); assert.equal(control('download').disabled, true)
      editor.value = fixture; emit('input', editor); control('run').click()
      assert.match(status(), /2 added, 1 removed, 3 changed/)
      input(' '.repeat(120001)); control('run').click()
      assert.match(status(), /120,000/); assert.equal(rows().length, 0)
      assert.equal(editor.value, fixture)
    })

    await t.test('pagination covers all differences and stale page controls cannot select', async () => {
      reopen('list.json', JSON.stringify(Array.from({ length: 61 }, (_, i) => i + 1)))
      compare(JSON.stringify(Array(61).fill(0)))
      assert.equal(rows().length, 25); assert.match(status(), /1–25 of 61/)
      const old = selects()[0]
      control('next').click(); assert.match(status(), /26–50 of 61/)
      const before = [editor.selectionStart, editor.selectionEnd]
      old.click(); assert.deepEqual([editor.selectionStart, editor.selectionEnd], before)
      control('next').click(); assert.equal(rows().length, 11); assert.match(status(), /51–61 of 61/)
      assert.equal(control('next').disabled, true)
      selects().at(-1).click(); assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), '61')
      control('download').click(); assert.equal(JSON.parse(await downloads.at(-1).blob.text()).changes.length, 61)
      control('previous').click(); assert.match(status(), /26–50 of 61/)
      control('previous').click(); assert.equal(control('previous').disabled, true)
    })

    await t.test('long previews remain bounded while report retains full content; root changes can be selected', async () => {
      reopen('long.json', '"' + 'x'.repeat(4500) + '"'); compare('null')
      assert.match(rows()[0].children[0].textContent, /\(root\)/)
      assert.match(rows()[0].children[2].textContent, /Preview shortened/)
      assert.ok(rows()[0].children[2].textContent.length < 1200)
      selects()[0].click(); assert.equal(editor.selectionStart, 0); assert.equal(editor.selectionEnd, 4502)
      control('download').click(); assert.equal(JSON.parse(await downloads.at(-1).blob.text()).changes[0].after.json.length, 4502)
      compare(editor.value); assert.equal(rows().length, 0); assert.match(status(), /No value differences/)
      assert.equal(control('download').disabled, false); control('download').click()
      assert.equal(JSON.parse(await downloads.at(-1).blob.text()).counts.total, 0)
    })

    await t.test('loading or saving blocks actions and requires an explicit new comparison on recovery', () => {
      reopen(); compare()
      editor.disabled = true; emit('scroll', editor)
      assert.equal(field('reference').disabled, true); assert.equal(control('run').disabled, true)
      assert.equal(control('clear').disabled, true); assert.equal(control('download').disabled, true)
      editor.disabled = false; emit('scroll', editor)
      assert.equal(field('reference').value, reference); assert.equal(control('run').disabled, false)
      assert.equal(control('download').disabled, true); control('run').click(); assert.equal(rows().length, 6)
    })

    await t.test('context switches, non-JSON mode, clear and reopen forget previous reference and report', () => {
      const old = control('run')
      surface.dataset.sourcePath = 'other.json'; old.click()
      assert.equal(field('reference').value, ''); assert.equal(rows().length, 0)
      compare(); surface.dataset.workspaceId = 'other-book'; emit('scroll', editor)
      assert.equal(field('reference').value, ''); assert.equal(control('download').disabled, true)
      compare(); language.textContent = 'Plain text'; emit('scroll', editor)
      assert.equal(surface.querySelector('[data-json-comparison]').hidden, true); assert.equal(field('reference').value, '')
      language.textContent = 'JSON'; emit('scroll', editor); assert.equal(rows().length, 0)
      compare(); control('clear').click(); assert.equal(field('reference').value, '')
      assert.match(status(), /Comparison cleared/); assert.equal(control('download').disabled, true)
      compare(); const closed = control('download'); const count = downloads.length
      reopen(); closed.click(); assert.equal(downloads.length, count)
      assert.equal(field('reference').value, ''); assert.equal(rows().length, 0)
    })

    await t.test('download failure is visible and does not edit source or lose the report', () => {
      compare(); const count = sourceInputs.length
      URL.createObjectURL = () => { throw new Error('download unavailable') }
      control('download').click(); assert.match(status(), /Could not download comparison: download unavailable/)
      assert.equal(rows().length, 6); assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, count)
      for (const fn of timers) fn()
      assert.equal(revoked.length, downloads.length)
    })
  } finally {
    Object.assign(globalThis, original); URL.createObjectURL = originalCreate; URL.revokeObjectURL = originalRevoke
  }
})
