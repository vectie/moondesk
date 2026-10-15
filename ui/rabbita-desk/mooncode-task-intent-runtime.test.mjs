import assert from 'node:assert/strict'
import test from 'node:test'
import { installMoonCodeDeveloperTools } from './mooncode-developer-tools-runtime.js'

// Small DOM contract fixture. It executes the production lazy installer and
// change listener, including repeated updates and a newly mounted composer.
class Element {
  constructor(tag = 'div') { this.tag = tag; this.dataset = {}; this.children = []; this.listeners = {}; this.attributes = {}; }
  append(...children) { for (const child of children) { child.parentElement = this; this.children.push(child); } }
  prepend(...children) { for (const child of children.reverse()) { child.parentElement = this; this.children.unshift(child); } }
  setAttribute(key, value) { this.attributes[key] = value; }
  getAttribute(key) { return this.attributes[key] ?? null; }
  closest() { return this.dataset.runtime ? this : this.parentElement?.closest(); }
  addEventListener(kind, listener) { this.listeners[kind] = listener; }
  dispatchEvent(event) { this.lastEvent = event; this.listeners[event.type]?.(event); }
  querySelector(selector) {
    if (selector === '.mooncode-composer-settings > summary') {
      return this.children.find(child => child.tag === 'summary') ?? this.children.find(child => child.className === 'mooncode-composer-settings')?.querySelector(selector) ?? null
    }
    const [, attr, value] = selector.match(/^\[data-(testid|mooncode-control-sync)="([^"]+)"\]$/) || []
    const key = attr === 'testid' ? 'testid' : 'mooncodeControlSync'
    for (const child of this.children) {
      if (child.dataset[key] === value) return child
      const match = child.querySelector(selector); if (match) return match
    }
    return null
  }
}
class Input extends Element { constructor() { super('input'); this.value = ''; } }
class Select extends Element {
  constructor() { super('select'); this.selectedValue = undefined; }
  get options() { return this.children; }
  get value() { return this.selectedValue ?? this.children.find(option => option.selected)?.value ?? this.children[0]?.value ?? ''; }
  set value(value) { this.selectedValue = value; }
  replaceChildren(...children) { this.children = []; this.append(...children); }
}
const mount = (taskIntent = 'auto') => {
  const root = new Element()
  root.dataset = { runtime: 'mooncode-composer-controls-v1', models: 'moongate/example', selectedModel: 'moongate/example', taskIntent }
  const sync = new Input(); sync.dataset.mooncodeControlSync = 'task-intent'; root.append(sync)
  const scope = { querySelectorAll: selector => selector === '[data-runtime="mooncode-composer-controls-v1"]' ? [root] : [] }
  return { root, sync, scope }
}

test('task purpose lazy control survives repeat install reset and reopen', () => {
  const names = ['HTMLElement', 'HTMLInputElement', 'HTMLSelectElement', 'InputEvent', 'document']
  const prior = new Map(names.map(name => [name, globalThis[name]]))
  try {
    Object.assign(globalThis, {
      HTMLElement: Element, HTMLInputElement: Input, HTMLSelectElement: Select,
      InputEvent: class { constructor(type, options) { this.type = type; Object.assign(this, options); } },
      document: { createElement: tag => tag === 'select' ? new Select() : new Element(tag) },
    })
    const { root, sync, scope } = mount()
    installMoonCodeDeveloperTools(scope)
    const select = root.querySelector('[data-testid="mooncode-task-intent-select"]')
    assert.ok(select)
    assert.deepEqual(select.options.map(option => option.value), ['auto', 'read_only', 'workspace_change'])
    assert.equal(select.value, 'auto')
    select.value = 'read_only'; select.dispatchEvent({ type: 'change' })
    assert.equal(sync.value, 'read_only')
    assert.equal(sync.lastEvent.type, 'input')
    root.dataset.taskIntent = 'read_only'
    installMoonCodeDeveloperTools(scope)
    assert.equal(select.value, 'read_only')
    assert.equal(root.children.length, 3)
    root.dataset.taskIntent = 'auto'
    installMoonCodeDeveloperTools(scope)
    assert.equal(select.value, 'auto')
    const reopened = mount('workspace_change')
    installMoonCodeDeveloperTools(reopened.scope)
    assert.equal(reopened.root.querySelector('[data-testid="mooncode-task-intent-select"]').value, 'workspace_change')
    assert.equal(reopened.root.children.length, 3)
  } finally {
    for (const [name, value] of prior) value === undefined ? delete globalThis[name] : globalThis[name] = value
  }
})
