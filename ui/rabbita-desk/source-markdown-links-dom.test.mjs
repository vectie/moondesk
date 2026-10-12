import test from 'node:test'
import assert from 'node:assert/strict'
import { readFileSync } from 'node:fs'
import { installSourceEditorRuntime } from './source-editor-runtime.js'

// Minimal browser adapters exercise the installed production event handlers.
// They do not establish browser, native host, save/reopen or layout behavior.
test('installed source runtime inspects and retargets Markdown links through the draft input boundary', async t => {
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
  const fixture = readFileSync(new URL('../../docs/samples/markdown-links/guide-before.md', import.meta.url), 'utf8')
  const open = (path = 'guide.md', text = fixture) => {
    const surface = new Element(); surface.className = 'source-editor'; surface.dataset = { testid: 'source-editor', sourcePath: path, workspaceId: 'book', sourceDirty: 'false' }
    const node = (tag, id) => { const item = element(tag); item.dataset.testid = id; surface.append(item); return item }
    const editor = node('textarea', 'source-editor-input'); editor.value = text
    const highlight = node('pre', 'source-highlight'); highlight.append(new Element('code'))
    node('div', 'source-completions'); node('div', 'source-local-diagnostics'); node('div', 'source-semantic-results')
    const language = node('span', 'source-language'); language.textContent = 'Plain text'
    document.body.append(surface); activeSurface = surface
    return { surface, editor, language }
  }
  try {
    let { surface, editor, language } = open()
    installSourceEditorRuntime()
    const control = name => activeSurface.querySelector(`[data-action="source-markdown-links-${name}"]`)
    const field = name => activeSurface.querySelector(`[data-markdown-links-${name}]`)
    const controls = name => activeSurface.querySelectorAll(`[data-action="source-markdown-links-${name}"]`)
    const input = value => { field('replacement').value = value; emit('input', field('replacement')) }
    const inspect = () => control('inspect').click()
    const edit = (index = 0) => controls('edit')[index].click()
    const preview = (replacement = 'docs/new-guide.md', scope = 'matching') => { input(replacement); control(`review-${scope}`).click() }
    const reopen = (path = 'guide.md', text = fixture) => {
      surface.remove(); ({ surface, editor, language } = open(path, text)); emit('scroll', editor)
    }

    await t.test('sample inspection, selection, reviewed all-match edit and one input event preserve exact output', () => {
      assert.ok(surface.querySelector('[data-markdown-links]'))
      inspect(); assert.equal(controls('edit').length, 4)
      controls('select')[0].click()
      assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), 'docs/old-guide.md')
      assert.equal(document.activeElement, editor)
      edit(); assert.equal(field('replacement').value, 'docs/old-guide.md')
      assert.equal(document.activeElement, field('replacement'))
      preview(); assert.match(field('review').textContent, /Affected occurrences \(2\)/)
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, 0)
      control('apply').click()
      assert.equal(editor.value, readFileSync(new URL('../../docs/samples/markdown-links/guide-after.md', import.meta.url), 'utf8'))
      assert.equal(sourceInputs.length, 1); assert.equal(sourceInputs[0], editor.value)
      assert.equal(surface.dataset.sourceRuntimeDirty, 'true')
      assert.equal(field('edit').hidden, true)
      assert.match(field('status').textContent, /Replaced 2 destinations in the unsaved draft/)
      control('apply').click(); assert.equal(sourceInputs.length, 1)
      assert.equal(downloads.length, 0)
    })

    await t.test('bulk replacement grows and shrinks exact tokens in links and images in one draft step', () => {
      const text = '[a](old) before ![b](old "Title") after [c](keep)'
      reopen('links.md', text); inspect(); edit(); preview('<a longer path 😀.md>')
      const count = sourceInputs.length
      control('apply').click()
      assert.equal(editor.value, '[a](<a longer path 😀.md>) before ![b](<a longer path 😀.md> "Title") after [c](keep)')
      assert.equal(sourceInputs.length, count + 1)
      inspect(); edit(); preview('x'); control('apply').click()
      assert.equal(editor.value, '[a](x) before ![b](x "Title") after [c](keep)')
      assert.equal(sourceInputs.length, count + 2)
    })

    await t.test('single occurrence edits leave equal later destinations unchanged and no-op preserves history', () => {
      reopen(); inspect(); edit(); control('review-one').click()
      assert.match(field('status').textContent, /No change/); assert.equal(control('apply').disabled, true)
      const count = sourceInputs.length
      preview('<new guide.md>', 'one'); control('apply').click()
      assert.equal(editor.value, fixture.replace('docs/old-guide.md', '<new guide.md>'))
      assert.equal(editor.value.slice(editor.selectionStart, editor.selectionEnd), '<new guide.md>')
      assert.equal(sourceInputs.length, count + 1)
    })

    await t.test('invalid destinations, cancellation and input changes require another review without edits', () => {
      reopen(); inspect(); edit(); const count = sourceInputs.length
      preview('bad path'); assert.match(field('status').textContent, /destination token/)
      assert.equal(control('apply').disabled, true); assert.equal(editor.value, fixture)
      preview(); input('docs/another.md'); assert.equal(control('apply').disabled, true)
      control('review-one').click(); control('cancel').click()
      assert.equal(field('edit').hidden, true); assert.equal(field('replacement').value, '')
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, count)
      edit(); preview(); field('replacement').value = 'changed-without-event'
      control('apply').click(); assert.match(field('status').textContent, /changed/)
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, count)
    })

    await t.test('draft changes invalidate inspected ranges and direct changes cannot replay stale reviews', () => {
      reopen(); inspect(); edit(); preview()
      editor.value = '# Changed\n' + fixture; emit('input', editor)
      assert.equal(controls('edit').length, 0); assert.equal(field('edit').hidden, true)
      assert.equal(control('apply').disabled, true)
      inspect(); edit(); preview(); const count = sourceInputs.length
      editor.value = '# Changed again\n' + fixture // deliberately no input event
      control('apply').click()
      assert.equal(editor.value, '# Changed again\n' + fixture); assert.equal(sourceInputs.length, count)
      assert.match(field('status').textContent, /Draft or editor availability changed/)
      inspect(); edit(); preview(); control('apply').click()
      assert.equal(sourceInputs.length, count + 1)
    })

    await t.test('loading, path/workspace changes and removed editors cannot mutate a replacement context', () => {
      reopen(); inspect(); edit(); preview(); const count = sourceInputs.length
      editor.disabled = true; emit('scroll', editor)
      assert.equal(control('inspect').disabled, true); assert.equal(control('apply').disabled, true)
      editor.disabled = false; emit('scroll', editor)
      assert.equal(control('apply').disabled, true)
      inspect(); edit(); preview(); surface.dataset.sourcePath = 'other.md'
      control('apply').click(); assert.equal(editor.value, fixture); assert.equal(field('replacement').value, '')
      inspect(); edit(); preview(); surface.dataset.workspaceId = 'other-book'; emit('scroll', editor)
      assert.equal(field('edit').hidden, true)
      inspect(); edit(); preview(); surface.dataset.sourcePath = 'other.txt'; emit('scroll', editor)
      assert.equal(surface.querySelector('[data-markdown-links]').hidden, true)
      surface.dataset.sourcePath = 'other.md'; emit('scroll', editor)
      assert.equal(field('edit').hidden, true)
      inspect(); edit(); preview(); const oldApply = control('apply')
      reopen('other.md', '[new](keep)'); oldApply.click()
      assert.equal(editor.value, '[new](keep)'); assert.equal(sourceInputs.length, count)
    })

    await t.test('paginated inventories reach the final occurrence and old row controls are ignored', () => {
      const text = Array.from({ length: 31 }, (_, index) => `[Item ${index}](target${index}.md)`).join('\n')
      reopen('many.markdown', text); inspect()
      assert.equal(controls('edit').length, 25); assert.equal(control('previous').disabled, true)
      const stale = controls('edit')[0]; control('next').click()
      assert.equal(controls('edit').length, 6); assert.equal(control('next').disabled, true)
      stale.click(); assert.equal(field('edit').hidden, true)
      edit(5); assert.equal(field('replacement').value, 'target30.md')
      preview('last.md', 'one'); control('apply').click()
      assert.equal(editor.value, text.replace('target30.md', 'last.md'))
    })

    await t.test('failed insertion restores source/selection; a fresh preview can recover', () => {
      reopen(); inspect(); edit(); preview()
      const count = sourceInputs.length, selection = [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
      const originalSetRangeText = editor.setRangeText
      editor.setRangeText = () => { editor.value = 'partial'; throw new Error('adapter insertion refused') }
      control('apply').click()
      assert.equal(editor.value, fixture); assert.equal(sourceInputs.length, count)
      assert.deepEqual([editor.selectionStart, editor.selectionEnd, editor.selectionDirection], selection)
      assert.match(field('status').textContent, /adapter insertion refused/); assert.equal(control('apply').disabled, true)
      editor.setRangeText = originalSetRangeText; control('review-matching').click(); control('apply').click()
      assert.equal(sourceInputs.length, count + 1)
    })

    await t.test('bounds and long previews disclose unavailable or shortened output without partial editing', () => {
      reopen('large.md', 'x'.repeat(120001)); inspect()
      assert.match(field('status').textContent, /120,000/); assert.equal(controls('edit').length, 0)
      reopen('long.md', '[Long](' + 'x'.repeat(4200) + ')'); inspect(); edit(); preview('new', 'one')
      assert.match(field('review').textContent, /Token previews shortened/)
      control('apply').click(); assert.equal(editor.value, '[Long](new)')
    })
  } finally {
    Object.assign(globalThis, original); URL.createObjectURL = originalCreate; URL.revokeObjectURL = originalRevoke
  }
})
