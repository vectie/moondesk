import assert from 'node:assert/strict'
import { installSourceEditorRuntime } from './source-editor-runtime.js'
import { parseTaskCsv } from './specialist-task-csv.js'
// Independent minimal DOM contract adapter, not graphical-browser qualification.
// Textarea getter follows HTML API-value newline normalization:
// https://html.spec.whatwg.org/multipage/form-elements.html#the-textarea-element
const listeners = new Map(), inputs = []
const key = s => s.replace(/^data-/, '').replace(/-([a-z])/g, (_, c) => c.toUpperCase())
function emit(type, target) {
  if (type === 'input' && target.dataset.testid === 'source-editor-input') inputs.push(target.value)
  for (const handler of listeners.get(type) || []) handler({ type, target, preventDefault() {} })
}
class El {
  constructor(tag = 'div') { Object.assign(this, { tagName: tag, dataset: {}, attrs: {}, children: [], style: {}, textContent: '', className: '', disabled: false, isConnected: true, classList: { toggle() {}, add() {}, remove() {} } }) }
  setAttribute(k,v) { this.attrs[k] = v; if (k.startsWith('data-')) this.dataset[key(k)] = v }
  removeAttribute(k) { delete this.attrs[k] }
  append(...items) { for (const child of items) { child.parentElement = this; this.children.push(child) } }
  replaceChildren(...items) { this.children = []; this.append(...items) }
  matches(s) {
    if (s === '.source-editor') return this.className === 'source-editor'
    if (s === 'code') return this.tagName === 'code'
    const m = /^\[([^=\]]+)(?:="([^"]*)")?\]$/.exec(s)
    if (!m) return false
    const v = m[1].startsWith('data-') ? this.dataset[key(m[1])] : this.attrs[m[1]]
    return v !== undefined && (m[2] === undefined || m[2] === v)
  }
  closest(s) { return this.matches(s) ? this : this.parentElement?.closest(s) || null }
  querySelectorAll(s) {
    if (s.includes(' ')) { const [a,b] = s.split(' '); return this.querySelector(a)?.querySelectorAll(b) || [] }
    return this.children.flatMap(c => [...(c.matches(s) ? [c] : []), ...c.querySelectorAll(s)])
  }
  querySelector(s) { return this.querySelectorAll(s)[0] || null }
  focus() { document.activeElement = this }
  click() { if (!this.disabled) emit('click', this) }
  dispatchEvent(e) { emit(e.type, this); return true }
}
class Input extends El { constructor() { super('input'); this.value = ''; this.checked = false } }
class Textarea extends El {
  constructor() { super('textarea'); this.raw = ''; this.selectionStart = 0; this.selectionEnd = 0; this.selectionDirection = 'none'; this.scrollTop = 0; this.scrollLeft = 0 }
  get value() { return this.raw.replace(/\r\n?/g, '\n') }
  set value(v) { this.raw = String(v) }
  setRangeText(s,a,b) { this.value = this.value.slice(0,a) + s + this.value.slice(b); this.setSelectionRange(a,a+s.length) }
  setSelectionRange(a,b,d='none') { this.selectionStart = Math.min(a,this.value.length); this.selectionEnd = Math.min(b,this.value.length); this.selectionDirection = d }
}
const make = tag => tag === 'textarea' ? new Textarea() : tag === 'input' ? new Input() : new El(tag)
let surface
Object.assign(globalThis, { Element: El, HTMLElement: El, HTMLInputElement: Input, HTMLTextAreaElement: Textarea, HTMLButtonElement: El, requestAnimationFrame: fn => fn(), MutationObserver: class { observe() {} }, getComputedStyle: () => ({lineHeight:'20px'}), document: { body: new El('body'), activeElement: null, createElement: make, getElementById: () => surface, querySelectorAll: s => surface?.querySelectorAll(s) || [], addEventListener(type,fn) { listeners.set(type,[...(listeners.get(type)||[]),fn]) } } })
function open(path, raw) {
  surface = new El(); surface.className = 'source-editor'; Object.assign(surface.dataset,{testid:'source-editor', sourcePath:path, workspaceId:'review-workspace',sourceDirty:'false'})
  const add = (tag,id) => { const el = make(tag); el.dataset.testid = id; surface.append(el); return el }
  const editor = add('textarea','source-editor-input'); editor.value = raw
  add('pre','source-highlight').append(new El('code'))
  for (const id of ['source-completions','source-local-diagnostics','source-semantic-results']) add('div',id)
  add('span','source-language').textContent = 'Plain text'
  emit('scroll',editor)
  return editor
}
const f = name => surface.querySelector(`[data-table-deduplicate-${name}]`)
const b = name => surface.querySelector(`[data-action="source-table-deduplicate-${name}"]`)
const keys = () => surface.querySelectorAll('[data-table-deduplicate-key]')
const choose = name => { const input=keys().find(i=>i.value===name);input.checked=true;emit('input',input) }
let editor=open('lookup.csv','id,name\r\n001,"old\r\nvalue"\r\n002,other\r\n001,new\r\n')
installSourceEditorRuntime()
const original=editor.value
choose('id'); b('last').click()
assert.equal(editor.value,original);assert.equal(inputs.length,0)
const preview=JSON.parse(f('preview').textContent)
assert.deepEqual(preview.removed.map(r=>r.number),[2]);assert.equal(preview.duplicates[0].records[0].cells[1],'old\nvalue')
b('apply').click();assert.equal(inputs.length,1)
assert.deepEqual(parseTaskCsv(editor.value).rows.map(r=>r.cells),[['002','other'],['001','new']])
assert.equal(editor.value.includes('\r'),false)
b('undo').click();assert.equal(editor.value,original);assert.equal(inputs.length,2)
b('first').click();b('cancel').click();assert.equal(b('apply').disabled,true);assert.equal(editor.value,original)
b('first').click();keys()[0].checked=false;emit('input',keys()[0]);assert.equal(b('apply').disabled,true)
choose('id');b('first').click();editor.value+='003,extra\n';emit('input',editor);assert.equal(b('apply').disabled,true)
b('last').click();b('apply').click();editor.value+='004,next\n';emit('input',editor);assert.equal(b('undo').disabled,true)
// Identity changes reset selected headers even with the same table schema.
surface.dataset.sourcePath='different.csv';emit('scroll',editor);assert.equal(keys().some(i=>i.checked),false);assert.equal(b('undo').disabled,true)
choose('id');b('last').click();editor.disabled=true;emit('scroll',editor);assert.equal(b('apply').disabled,true)
editor=open('lookup.tsv','id\tname\n\tblank\n\tother\na\tfirst\na\tlast\n')
choose('id');b('last').click();assert.match(f('status').textContent,/2 blank-key/);b('apply').click()
assert.deepEqual(parseTaskCsv(editor.value,'\t').rows.map(r=>r.cells),[['','blank'],['','other'],['a','last']])
// The unique, nonblank sample above meets the documented native lookup precondition.
console.log('Installed production event handlers: preview, first/last, Apply, cancel, scoped Undo, LF textarea, stale draft/settings/file and TSV blank-key retention passed. Native save/reopen/lookup unrun.')
