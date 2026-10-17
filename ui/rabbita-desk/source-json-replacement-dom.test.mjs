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

    await t.test('copy journey keeps original subtree, previews destination and emits one ordinary draft input', () => {
      const raw = '{"source":{"id":9007199254740993,"n":-0,"s":"\\u0061"},"dest":[]}'
      reopen('copy.json', raw); inspect('/source'); control('copy-open').click()
      field('copy-destination').value = '/dest'; emit('input', field('copy-destination'))
      control('copy-review').click()
      assert.equal(editor.value, raw); assert.equal(surface.dataset.sourceRuntimeDirty, undefined)
      assert.match(field('copy-source').textContent, /9007199254740993/)
      assert.equal(field('copy-before').textContent, 'Destination before:\n[]')
      const count = sourceInputs.length; control('copy-apply').click()
      assert.equal(editor.value, '{"source":{"id":9007199254740993,"n":-0,"s":"\\u0061"},"dest":[{"id":9007199254740993,"n":-0,"s":"\\u0061"}]}')
      assert.equal(sourceInputs.length, count + 1); assert.equal(surface.dataset.sourceRuntimeDirty, 'true')
      assert.equal(field('pointer').value, '/dest/0'); assert.equal(field('copy-section').hidden, true)
      assert.match(field('status').textContent, /unsaved draft/)
      control('copy-apply').click(); assert.equal(sourceInputs.length, count + 1)
      inspect('/source'); control('replace-open').click(); assert.match(field('replacement').value, /9007199254740993/)
      reopen(); sourceInputs.length = 0
    })

    await t.test('copy cancellation, changed review inputs, draft, identity and availability invalidate review', () => {
      const raw = '[1e+02,[]]'
      const prepare = () => {
        reopen('copy.json', raw); inspect('/0'); control('copy-open').click()
        field('copy-destination').value = '/1'; control('copy-review').click()
        assert.equal(control('copy-apply').disabled, false)
      }
      prepare(); control('copy-cancel').click(); assert.equal(editor.value, raw); assert.equal(control('copy-apply').disabled, true)
      for (const name of ['destination', 'key', 'position']) {
        prepare(); field('copy-' + name).value += ' '; emit('input', field('copy-' + name)); assert.equal(control('copy-apply').disabled, true)
        prepare(); field('copy-' + name).value += ' '; control('copy-apply').click(); assert.equal(editor.value, raw); assert.match(field('copy-status').textContent, /changed/)
      }
      prepare(); editor.value = '[2,[]]'; emit('input', editor); assert.equal(control('copy-apply').disabled, true)
      prepare(); editor.disabled = true; emit('scroll', editor); assert.equal(control('copy-apply').disabled, true)
      editor.disabled = false; emit('scroll', editor); assert.equal(control('copy-apply').disabled, true)
      prepare(); inspect('/1'); assert.equal(field('copy-section').hidden, true)
      prepare(); surface.dataset.sourcePath = 'other.json'; emit('scroll', editor); assert.equal(field('copy-section').hidden, true)
      prepare(); surface.dataset.workspaceId = 'other-book'; emit('scroll', editor); assert.equal(field('copy-section').hidden, true)
      prepare(); language.textContent = 'Markdown'; emit('scroll', editor); assert.equal(field('copy-section').hidden, true)
      prepare(); field('copy-destination').value = '/0'; control('copy-review').click(); assert.equal(control('copy-apply').disabled, true); assert.equal(editor.value, raw)
      reopen(); sourceInputs.length = 0
    })

    await t.test('root snapshot copy reports shortened preview and applies complete value', () => {
      const raw = '{"items":[],"text":"' + 'x'.repeat(4500) + '"}'
      reopen('copy.json', raw); control('copy-open').click(); field('copy-destination').value = '/items'; control('copy-review').click()
      assert.match(field('copy-status').textContent, /shortened/); assert.match(field('copy-status').textContent, /\(root\)/)
      const count = sourceInputs.length; control('copy-apply').click()
      assert.equal(editor.value, '{"items":[' + raw + '],"text":"' + 'x'.repeat(4500) + '"}')
      assert.equal(sourceInputs.length, count + 1)
      reopen(); sourceInputs.length = 0
    })

    await t.test('failed copy adapter restores exact original draft and selection without input', () => {
      reopen('copy.json', '[1,[]]'); inspect('/0'); control('copy-open').click(); field('copy-destination').value = '/1'; control('copy-review').click()
      const count = sourceInputs.length, selection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
      editor.setRangeText = () => { editor.value = 'partial'; throw new Error('copy adapter refused') }
      control('copy-apply').click()
      assert.equal(editor.value, '[1,[]]'); assert.equal(sourceInputs.length, count)
      assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], selection)
      assert.equal(control('copy-apply').disabled, true); assert.match(field('copy-status').textContent, /adapter refused/)
      reopen(); sourceInputs.length = 0
    })

    await t.test('record ordering uses installed settings/preview/apply handlers and exactly one ordinary input', () => {
      const raw = '{"steps":[{"n":2,"id":"\\u0061"},{"n":1,"id":9007199254740993},{"n":1,"id":-0}]}'
      reopen('ordering.json', raw); inspect('/steps'); control('order-open').click()
      for (const [name, value] of [['field','/n'], ['type','number'], ['direction','asc'], ['missing','error']]) {
        field('order-' + name).value = value; emit('input', field('order-' + name))
      }
      control('order-review').click(); assert.equal(editor.value, raw)
      assert.match(field('order-status').textContent, /1, 2, 0/)
      assert.match(field('order-preview').textContent, /Before:/)
      const count = sourceInputs.length; control('order-apply').click()
      assert.equal(editor.value, '{"steps":[{"n":1,"id":9007199254740993},{"n":1,"id":-0},{"n":2,"id":"\\u0061"}]}')
      assert.equal(sourceInputs.length, count + 1); assert.equal(surface.dataset.sourceRuntimeDirty, 'true')
      assert.equal(field('pointer').value, '/steps'); assert.equal(field('order-section').hidden, true)
      control('order-apply').click(); assert.equal(sourceInputs.length, count + 1)
      reopen(); sourceInputs.length = 0
    })
    await t.test('ordering cancellation, stale settings/source/pointer/identity, disabled and failed editor refuse safely', () => {
      const raw = '[{"n":2},{"n":1}]'
      const prepare = () => {
        reopen('order.json', raw); control('order-open').click()
        for (const [name,value] of [['field','/n'],['type','number'],['direction','asc'],['missing','error']]) field('order-' + name).value = value
        control('order-review').click(); assert.equal(control('order-apply').disabled, false)
      }
      prepare(); control('order-cancel').click(); assert.equal(editor.value,raw); assert.equal(control('order-apply').disabled,true)
      for (const name of ['field','type','direction','missing']) {
        prepare(); field('order-' + name).value += ' '; emit('input',field('order-' + name)); assert.equal(control('order-apply').disabled,true)
        prepare(); field('order-' + name).value += ' '; control('order-apply').click(); assert.equal(editor.value,raw); assert.match(field('order-status').textContent,/changed/)
      }
      prepare(); editor.value = '[{"n":3},{"n":1}]'; emit('input',editor); assert.equal(control('order-apply').disabled,true)
      prepare(); editor.disabled = true; emit('scroll',editor); assert.equal(control('order-apply').disabled,true)
      prepare(); inspect('/0'); assert.equal(field('order-section').hidden,true)
      prepare(); surface.dataset.sourcePath = 'other.json'; emit('scroll',editor); assert.equal(field('order-section').hidden,true)
      prepare(); const count=sourceInputs.length; editor.setRangeText = () => { editor.value='broken'; throw new Error('simulated editor refusal') }; control('order-apply').click()
      assert.equal(editor.value,raw); assert.equal(sourceInputs.length,count); assert.match(field('order-status').textContent,/refusal/)
      prepare(); language.textContent='Markdown'; emit('scroll',editor); assert.equal(field('order-section').hidden,true)
      reopen(); sourceInputs.length=0
    })

    await t.test('move journey previews both locations, applies once and inspects shifted destination', () => {
      reopen('creator.json', '[1e+02,{"steps":[-0]}]')
      inspect('/0'); control('move-open').click()
      field('move-destination').value = '/1/steps'; emit('input', field('move-destination'))
      field('move-position').value = '1'; emit('input', field('move-position'))
      control('move-review').click()
      assert.match(field('move-source').textContent, /Source container before removal/)
      assert.match(field('move-destination-preview').textContent, /After insertion \(final\)/)
      assert.equal(editor.value, '[1e+02,{"steps":[-0]}]')
      const count = sourceInputs.length
      control('move-apply').click()
      assert.equal(editor.value, '[{"steps":[-0,1e+02]}]')
      assert.equal(field('pointer').value, '/0/steps/1'); assert.equal(sourceInputs.length, count + 1)
      assert.equal(field('move-section').hidden, true)
      control('move-apply').click(); assert.equal(sourceInputs.length, count + 1)
      reopen(); sourceInputs.length = 0
    })

    await t.test('move cancel, changed fields, changed source and disabled editor keep draft intact', () => {
      const raw = '{"steps":[0,1]}'
      const prepare = () => { reopen('creator.json', raw); inspect('/steps/0'); control('move-open').click(); field('move-position').value = '1'; emit('input', field('move-position')); control('move-review').click() }
      prepare(); control('move-cancel').click(); assert.equal(editor.value, raw); assert.equal(control('move-apply').disabled, true)
      prepare(); field('move-position').value = '0'; emit('input', field('move-position')); assert.equal(control('move-apply').disabled, true)
      prepare(); field('move-position').value = '0'; control('move-apply').click(); assert.equal(editor.value, raw); assert.match(field('move-status').textContent, /changed/)
      prepare(); editor.value = '{"steps":[2,1]}'; emit('input', editor); assert.equal(control('move-apply').disabled, true)
      prepare(); editor.disabled = true; emit('scroll', editor); assert.equal(control('move-review').disabled, true); assert.equal(control('move-apply').disabled, true)
      prepare(); inspect('/steps/1'); assert.equal(field('move-section').hidden, true)
      prepare(); surface.dataset.sourcePath = 'other.json'; emit('scroll', editor); assert.equal(field('move-section').hidden, true)
      reopen(); sourceInputs.length = 0
    })

    await t.test('removal previews and edits the installed draft and returns to parent', () => {
      reopen('remove.json', '{"items":[1e+02,-0,9007199254740993123]}')
      inspect('/items/1'); control('remove-review').click()
      assert.match(field('remove-preview').textContent, /Before:/)
      const count = sourceInputs.length
      control('remove-apply').click()
      assert.equal(editor.value, '{"items":[1e+02,9007199254740993123]}')
      assert.equal(field('pointer').value, '/items')
      assert.equal(sourceInputs.length, count + 1)
      assert.equal(control('remove-apply').disabled, true)
      inspect('/items/0'); control('remove-review').click()
      editor.value = '{"items":[5]}'
      emit('input', editor)
      assert.equal(control('remove-apply').disabled, true)
      reopen()
      sourceInputs.length = 0
    })

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

    await t.test('mounted insertion previews then emits one ordinary draft event at first, middle and last positions', () => {
      for (const [text, key, expected] of [
        ['[1e+02, 3]', '', ['[2.00,1e+02, 3]', '[1e+02, 2.00,3]', '[1e+02, 3,2.00]']],
        ['{"a":1e+02, "b":3}', 'c', ['{"c": 2.00,"a":1e+02, "b":3}', '{"a":1e+02, "c": 2.00,"b":3}', '{"a":1e+02, "b":3,"c": 2.00}']],
      ]) for (let position = 0; position < 3; position++) {
        reopen('insert.json', text); control('insert-open').click()
        assert.equal(field('insert-section').hidden, false)
        assert.equal(field('insert-position').value, '2')
        field('insert-key').value = key; field('insert-position').value = String(position); field('insert-value').value = '2.00'
        emit('input', field('insert-value')); control('insert-review').click()
        assert.equal(field('insert-before').textContent, `Before:\n${text}`)
        assert.equal(field('insert-after').textContent, `After:\n${expected[position]}`)
        const count = sourceInputs.length
        assert.equal(editor.value, text); assert.equal(surface.dataset.sourceRuntimeDirty, undefined)
        control('insert-apply').click()
        assert.equal(editor.value, expected[position]); assert.equal(sourceInputs.length, count + 1)
        assert.equal(surface.dataset.sourceRuntimeDirty, 'true'); assert.equal(field('insert-section').hidden, true)
        control('insert-apply').click(); assert.equal(sourceInputs.length, count + 1)
        // Existing replacement remains available immediately after insertion.
        inspect(text.startsWith('[') ? `/${position}` : '/c'); control('replace-open').click()
        assert.equal(field('replacement').value, '2.00')
      }
    })

    await t.test('mounted insertion invalidates previews on edits, target and file changes; rejects duplicate keys', () => {
      reopen('insert.json', '{"a":[],"b":0}')
      control('insert-open').click(); field('insert-key').value = 'a'; field('insert-value').value = '1'
      control('insert-review').click(); assert.match(field('insert-status').textContent, /decoded key/)
      field('insert-key').value = 'c'; emit('input', field('insert-key')); control('insert-review').click()
      field('insert-position').value = '0'; emit('input', field('insert-position'))
      assert.equal(control('insert-apply').disabled, true)
      control('insert-review').click(); field('insert-value').value = '2' // no event
      control('insert-apply').click(); assert.match(field('insert-status').textContent, /changed/)
      assert.equal(editor.value, '{"a":[],"b":0}')
      control('insert-review').click(); editor.value = '{"a":[],"b":1}'; emit('input', editor)
      assert.equal(control('insert-apply').disabled, true)
      control('insert-review').click(); editor.disabled = true; emit('scroll', editor)
      assert.equal(control('insert-apply').disabled, true)
      editor.disabled = false; emit('scroll', editor); assert.equal(control('insert-apply').disabled, true)
      inspect('/a'); assert.equal(field('insert-section').hidden, true)
      control('insert-open').click(); field('insert-value').value = 'true'; control('insert-review').click()
      control('insert-cancel').click(); assert.equal(field('insert-section').hidden, true)
      control('insert-open').click(); field('insert-value').value = 'true'; control('insert-review').click()
      surface.dataset.sourcePath = 'another.json'; emit('scroll', editor)
      assert.equal(field('insert-section').hidden, true)
      inspect('/b'); assert.equal(control('insert-open').disabled, true)
    })

    await t.test('mounted insertion failed adapter restores exact source without a draft event', () => {
      reopen('insert.json', '[1]'); control('insert-open').click()
      field('insert-value').value = 'true'; control('insert-review').click()
      const count = sourceInputs.length, selection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
      editor.setRangeText = () => { editor.value = 'partial'; throw new Error('insertion refused') }
      control('insert-apply').click()
      assert.equal(editor.value, '[1]'); assert.equal(sourceInputs.length, count)
      assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], selection)
      assert.match(field('insert-status').textContent, /insertion refused/)
      assert.equal(control('insert-apply').disabled, true)
    })

    await t.test('CSV derived column production preview Apply Undo and cancellation preserve ordinary draft semantics', () => {
      const original='id,value\n001, A:: B \n002,C\n';reopen('orders.csv',original);language.textContent='Plain text';emit('scroll',editor)
      const f=name=>activeSurface.querySelector(`[data-table-derive-${name}]`),b=name=>activeSurface.querySelector(`[data-action="source-table-derive-${name}"]`)
      f('column').value='value';f('delimiter').value='::';f('part').value='2';f('name').value='key';f('trim').checked=true
      b('review').click();assert.equal(editor.value,original);assert.match(f('preview').textContent,/"derived": "B"/)
      const count=sourceInputs.length;b('apply').click();assert.equal(sourceInputs.length,count+1);assert.match(editor.value,/"001"," A:: B ","B"/);assert.equal(surface.dataset.sourceRuntimeDirty,'true')
      b('undo').click();assert.equal(editor.value,original);assert.equal(sourceInputs.length,count+2);assert.equal(b('undo').disabled,true)
      b('review').click();b('cancel').click();assert.equal(editor.value,original);assert.equal(b('apply').disabled,true)
    })
    await t.test('derived Apply and Undo work through real-textarea newline normalization', () => {
      reopen('normalized.csv','');language.textContent='Plain text'
      let normalized=''
      Object.defineProperty(editor,'value',{get(){return normalized},set(value){normalized=String(value).replace(/\r\n?/g,'\n')},configurable:true})
      editor.value='id,value\r\n001,"A|B\r\nC"\r\n';emit('input',editor)
      const original=editor.value,count=sourceInputs.length
      const f=name=>activeSurface.querySelector(`[data-table-derive-${name}]`),b=name=>activeSurface.querySelector(`[data-action="source-table-derive-${name}"]`)
      f('column').value='value';f('delimiter').value='|';f('part').value='2';f('name').value='key'
      b('review').click();b('apply').click()
      assert.equal(sourceInputs.length,count+1);assert.equal(editor.value,'"id","value","key"\n"001","A|B\nC","B\nC"\n')
      assert.match(f('status').textContent,/applied/);assert.equal(b('undo').disabled,false)
      b('undo').click();assert.equal(editor.value,original);assert.equal(sourceInputs.length,count+2)
    })
    await t.test('derived column rejects stale settings, draft, file identity and unavailable editors', () => {
      reopen('sample.tsv','id\tvalue\n001\t A|B \n');language.textContent='Plain text';emit('scroll',editor)
      const f=name=>activeSurface.querySelector(`[data-table-derive-${name}]`),b=name=>activeSurface.querySelector(`[data-action="source-table-derive-${name}"]`)
      const configure=()=>{f('column').value='value';f('delimiter').value='|';f('name').value='key';f('part').value='2'};configure();b('review').click();f('part').value='1';b('apply').click();assert.match(f('status').textContent,/changed/)
      b('review').click();f('name').value='other';emit('input',f('name'));assert.equal(b('apply').disabled,true)
      b('review').click();editor.disabled=true;emit('scroll',editor);assert.equal(b('apply').disabled,true);editor.disabled=false;emit('scroll',editor);assert.equal(b('apply').disabled,true)
      configure();b('review').click();b('apply').click();assert.match(editor.value,/"001"\t" A\|B "\t"B "/)
      editor.value+='\n';emit('input',editor);assert.equal(b('undo').disabled,true)
      b('review').click();surface.dataset.sourcePath='other.tsv';emit('scroll',editor);assert.equal(b('apply').disabled,true);assert.equal(f('column').value,'')
    })
    await t.test('derived column editor failure rolls back bytes and selection without input event', () => {
      const original='value\na:b\n';reopen('fail.csv',original);emit('scroll',editor)
      const f=name=>activeSurface.querySelector(`[data-table-derive-${name}]`),b=name=>activeSurface.querySelector(`[data-action="source-table-derive-${name}"]`)
      f('column').value='value';f('delimiter').value=':';f('part').value='2';f('name').value='key';b('review').click()
      const count=sourceInputs.length,selection=[editor.selectionStart,editor.selectionEnd,editor.selectionDirection]
      editor.setRangeText=()=>{editor.value='partial';throw Error('table adapter failed')};b('apply').click()
      assert.equal(editor.value,original);assert.equal(sourceInputs.length,count);assert.deepEqual([editor.selectionStart,editor.selectionEnd,editor.selectionDirection],selection);assert.match(f('status').textContent,/table adapter failed/)
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
