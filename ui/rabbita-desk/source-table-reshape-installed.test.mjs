import test from 'node:test'
import assert from 'node:assert/strict'
import { installSourceEditorRuntime } from './source-editor-runtime.js'
import { parseTaskCsv } from './specialist-task-csv.js'

// Minimal DOM contract adapter exercising installed production handlers.
// This is not a graphical browser, native Save/reopen or accessibility test.
// Textarea values normalize newlines, as required by the HTML textarea API.
const listeners = new Map(), inputs = []
const key = text => text.replace(/^data-/, '').replace(/-([a-z])/g, (_, char) => char.toUpperCase())
function emit(type, target) {
  if (type === 'input' && target.dataset.testid === 'source-editor-input') inputs.push(target.value)
  for (const handler of listeners.get(type) || []) handler({type, target, preventDefault() {}})
}
class El {
  constructor(tag = 'div') { Object.assign(this, {tagName: tag, dataset: {}, attrs: {}, children: [], style: {}, textContent: '', className: '', disabled: false, isConnected: true, classList: {toggle() {}, add() {}, remove() {}}}) }
  setAttribute(name, value) { this.attrs[name] = value; if (name.startsWith('data-')) this.dataset[key(name)] = value }
  removeAttribute(name) { delete this.attrs[name] }
  append(...items) { for (const child of items) { child.parentElement = this; this.children.push(child) } }
  replaceChildren(...items) { this.children = []; this.append(...items) }
  matches(selector) {
    if (selector === '.source-editor') return this.className === 'source-editor'
    if (selector === 'code') return this.tagName === 'code'
    const match = /^\[([^=\]]+)(?:="([^"]*)")?\]$/.exec(selector)
    if (!match) return false
    const value = match[1].startsWith('data-') ? this.dataset[key(match[1])] : this.attrs[match[1]]
    return value !== undefined && (match[2] === undefined || match[2] === value)
  }
  closest(selector) { return this.matches(selector) ? this : this.parentElement?.closest(selector) || null }
  querySelectorAll(selector) {
    if (selector.includes(' ')) { const [a, b] = selector.split(' '); return this.querySelector(a)?.querySelectorAll(b) || [] }
    return this.children.flatMap(child => [...(child.matches(selector) ? [child] : []), ...child.querySelectorAll(selector)])
  }
  querySelector(selector) { return this.querySelectorAll(selector)[0] || null }
  focus() { document.activeElement = this }
  click() { if (!this.disabled) emit('click', this) }
  dispatchEvent(event) { emit(event.type, this); return true }
}
class Input extends El { constructor() { super('input'); this.value = ''; this.checked = false } }
class Textarea extends El {
  constructor() { super('textarea'); this.raw = ''; this.selectionStart = 0; this.selectionEnd = 0; this.selectionDirection = 'none'; this.scrollTop = 0; this.scrollLeft = 0; this.readOnly = false }
  get value() { return this.raw.replace(/\r\n?/g, '\n') }
  set value(value) { this.raw = String(value) }
  setRangeText(text, start, end) { this.value = this.value.slice(0, start) + text + this.value.slice(end); this.setSelectionRange(start, start + text.length) }
  setSelectionRange(start, end, direction = 'none') { this.selectionStart = Math.min(start, this.value.length); this.selectionEnd = Math.min(end, this.value.length); this.selectionDirection = direction }
}
const make = tag => tag === 'textarea' ? new Textarea() : tag === 'input' ? new Input() : new El(tag)
let surface
Object.assign(globalThis, {Element: El, HTMLElement: El, HTMLInputElement: Input, HTMLTextAreaElement: Textarea, HTMLButtonElement: El, requestAnimationFrame: fn => fn(), MutationObserver: class {observe() {}}, getComputedStyle: () => ({lineHeight: '20px'}), document: {body: new El('body'), activeElement: null, createElement: make, getElementById: () => surface, querySelectorAll: selector => surface?.querySelectorAll(selector) || [], addEventListener(type, handler) { listeners.set(type, [...(listeners.get(type) || []), handler]) }}})
function open(path = 'draft.csv', raw = 'id,Jan,Feb\n001,10,20\n002,,=1+1\n') {
  surface = new El(); surface.className = 'source-editor'; Object.assign(surface.dataset, {testid: 'source-editor', sourcePath: path, workspaceId: 'workspace-a', sourceDirty: 'false'})
  const add = (tag, id) => { const element = make(tag); element.dataset.testid = id; surface.append(element); return element }
  const editor = add('textarea', 'source-editor-input'); editor.value = raw
  add('pre', 'source-highlight').append(new El('code'))
  for (const id of ['source-completions', 'source-local-diagnostics', 'source-semantic-results']) add('div', id)
  add('span', 'source-language').textContent = 'Plain text'
  emit('scroll', editor); inputs.length = 0
  return editor
}
const field = name => surface.querySelector(`[data-table-reshape-${name}]`)
const button = name => surface.querySelector(`[data-action="source-table-reshape-${name}"]`)
const measures = () => surface.querySelectorAll('[data-table-reshape-measure]')
const choose = name => { const input = measures().find(item => item.value === name); input.checked = true; emit('input', input) }
const name = (kind, value) => { field(kind).value = value; emit('input', field(kind)) }
function configure() { choose('Feb'); choose('Jan'); name('variable', 'month'); name('value', 'amount') }
const selection = editor => [editor.selectionStart, editor.selectionEnd, editor.selectionDirection]
open(); installSourceEditorRuntime()

test('installed Preview, Apply and Undo preserve current unsaved values and exact original selection', () => {
  const editor = open('draft.csv', '\uFEFFid,Jan,Feb\r\n001,"line1\r\nline2",\r\n002,003,=1+1\r\n')
  editor.value += '003,9,10\n'; emit('input', editor); inputs.length = 0
  const original = editor.value; editor.setSelectionRange(3, 11, 'backward'); configure(); button('review').click()
  assert.equal(editor.value, original); assert.equal(inputs.length, 0)
  assert.deepEqual(JSON.parse(field('preview').textContent).rows.map(row => row.cells), [['001', 'Jan', 'line1\nline2'], ['001', 'Feb', ''], ['002', 'Jan', '003'], ['002', 'Feb', '=1+1'], ['003', 'Jan', '9'], ['003', 'Feb', '10']])
  button('apply').click(); assert.equal(inputs.length, 1); assert.equal(button('undo').disabled, false)
  assert.equal(parseTaskCsv(editor.value).rows.length, 6); assert.equal(editor.value.includes('\r'), false)
  button('undo').click(); assert.equal(editor.value, original); assert.deepEqual(selection(editor), [3, 11, 'backward']); assert.equal(inputs.length, 2); assert.equal(button('undo').disabled, true)
})
test('installed cancel and stale measurement/name selections do not mutate the draft', () => {
  const editor = open(), original = editor.value; configure(); button('review').click(); button('cancel').click()
  assert.equal(button('apply').disabled, true); assert.equal(editor.value, original)
  button('review').click(); measures()[1].checked = false; emit('input', measures()[1]); assert.equal(button('apply').disabled, true)
  choose('Jan'); button('review').click(); name('value', 'quantity'); assert.equal(button('apply').disabled, true)
  button('review').click(); field('variable').value = 'period'; emit('click', button('apply'))
  assert.equal(editor.value, original); assert.equal(inputs.length, 0); assert.equal(button('apply').disabled, true)
})
test('installed stale draft invalidates preview and scoped Undo', () => {
  const editor = open(); configure(); button('review').click(); editor.value += '003,5,6\n'; emit('input', editor)
  assert.equal(button('apply').disabled, true)
  button('review').click(); button('apply').click(); assert.equal(button('undo').disabled, false)
  editor.value += '004,Jan,7\n'; const edited = editor.value; emit('input', editor); emit('click', button('undo'))
  assert.equal(button('undo').disabled, true); assert.equal(editor.value, edited)
})
test('installed Apply rejects a stale draft even when its input event was missed', () => {
  const editor = open(); configure(); button('review').click(); editor.value += '003,5,6\n'; const edited = editor.value
  emit('click', button('apply')); assert.equal(editor.value, edited); assert.equal(button('apply').disabled, true); assert.equal(inputs.length, 0)
})
test('installed replacement editor instance discards old plans even at the same path', () => {
  const editor = open(); configure(); button('review').click()
  const replacement = new Textarea(); replacement.dataset.testid = 'source-editor-input'; replacement.value = editor.value; replacement.parentElement = surface; surface.children[0] = replacement
  emit('click', button('apply')); assert.equal(replacement.value, editor.value); assert.equal(button('apply').disabled, true); assert.equal(measures().some(item => item.checked), false)
})
test('installed settings edits invalidate scoped Undo even without an input event', () => {
  const editor = open(); configure(); button('review').click(); button('apply').click(); const applied = editor.value
  field('variable').value = 'different'; emit('click', button('undo'))
  assert.equal(editor.value, applied); assert.equal(button('undo').disabled, true)
})
test('installed file, workspace and unsupported context changes clear selections, preview and Undo', () => {
  for (const change of [() => {surface.dataset.sourcePath = 'other.csv'}, () => {surface.dataset.workspaceId = 'workspace-b'}]) {
    const editor = open(); configure(); button('review').click(); change(); emit('scroll', editor)
    assert.equal(button('apply').disabled, true); assert.equal(measures().some(item => item.checked), false); assert.equal(field('variable').value, '')
    configure(); button('review').click(); button('apply').click(); surface.dataset.sourcePath = 'notes.txt'; emit('scroll', editor)
    assert.equal(surface.querySelector('[data-table-reshape]').hidden, true)
    surface.dataset.sourcePath = 'other.csv'; emit('scroll', editor); assert.equal(button('undo').disabled, true)
  }
})
test('installed disabled and read-only access transitions invalidate plans and Undo', () => {
  for (const access of ['disabled', 'readOnly']) {
    const editor = open(), original = editor.value; configure(); button('review').click(); editor[access] = true; emit('click', button('apply'))
    assert.equal(editor.value, original); assert.equal(button('apply').disabled, true); assert.equal(button('review').disabled, true)
    editor[access] = false; emit('scroll', editor); button('review').click(); button('apply').click(); const applied = editor.value
    editor[access] = true; emit('scroll', editor); editor[access] = false; emit('scroll', editor); emit('click', button('undo'))
    assert.equal(editor.value, applied); assert.equal(button('undo').disabled, true)
  }
})
test('installed failed partial replacement restores content and selection without input', () => {
  const editor = open(), original = editor.value; configure(); button('review').click(); editor.setSelectionRange(2, 8, 'backward')
  editor.setRangeText = function () { this.value = 'partial'; this.setSelectionRange(0, 1); throw new Error('Injected replacement failure') }
  button('apply').click(); assert.equal(editor.value, original); assert.deepEqual(selection(editor), [2, 8, 'backward']); assert.equal(inputs.length, 0); assert.match(field('status').textContent, /Injected/); assert.equal(button('undo').disabled, true)
})
test('installed retained-output mismatch and dispatch failure both restore original draft and selection', () => {
  for (const fault of ['retention', 'dispatch']) {
    const editor = open(), original = editor.value; configure(); button('review').click(); editor.setSelectionRange(1, 5, 'forward')
    if (fault === 'retention') editor.setRangeText = function () { this.value = 'truncated' }
    else editor.dispatchEvent = () => { throw new Error('Injected event failure') }
    button('apply').click(); assert.equal(editor.value, original); assert.deepEqual(selection(editor), [1, 5, 'forward']); assert.equal(button('undo').disabled, true)
  }
})
test('installed failed Undo restores the already-applied draft and selection', () => {
  const editor = open(); configure(); button('review').click(); button('apply').click(); const applied = editor.value
  editor.setSelectionRange(4, 9, 'backward'); editor.setRangeText = function () { this.value = 'partial'; throw new Error('Injected undo failure') }
  button('undo').click(); assert.equal(editor.value, applied); assert.deepEqual(selection(editor), [4, 9, 'backward'])
})
test('installed TSV uses exact Unicode headers and displays text without HTML interpretation', () => {
  const editor = open('draft.tsv', 'id\t 月 \t<script>\n001\t😀\t"a\tb"\n')
  choose('<script>'); choose(' 月 '); name('variable', '項目'); name('value', '値'); button('review').click()
  assert.match(field('preview').textContent, /<script>/); button('apply').click()
  assert.deepEqual(parseTaskCsv(editor.value, '\t').rows.map(row => row.cells), [['001', ' 月 ', '😀'], ['001', '<script>', 'a\tb']])
})
test('installed malformed input, collisions and expansion errors leave the unsaved draft unchanged', () => {
  let editor = open('draft.csv', 'id,Jan,Feb\n' + 'x,1,2\n'.repeat(51)), original = editor.value
  configure(); button('review').click(); assert.match(field('status').textContent, /102 records/); assert.equal(button('apply').disabled, true); assert.equal(editor.value, original)
  editor = open(); original = editor.value; configure(); name('variable', 'id'); button('review').click()
  assert.match(field('status').textContent, /distinct/); assert.equal(editor.value, original)
  editor.value = 'id,Jan\n"unterminated'; emit('input', editor); assert.equal(button('review').disabled, true); assert.equal(button('undo').disabled, true)
})
