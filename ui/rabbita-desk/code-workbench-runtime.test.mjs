import test from 'node:test'
import assert from 'node:assert/strict'
import { contextKey, normalizeCodeContext, composeCodeContext, addContextToList, navigateTabList, initialWorkbenchLayout } from './code-workbench-runtime.js'

test('new workspaces start with chat while explicitly opened tools are remembered', () => {
  assert.deepEqual(initialWorkbenchLayout(), { view: 'source', focus: 'chat' })
  assert.deepEqual(initialWorkbenchLayout({ view: 'terminal', focus: 'split' }), { view: 'terminal', focus: 'split' })
  assert.deepEqual(initialWorkbenchLayout({ view: 'stale-pane', focus: 'invalid' }), { view: 'source', focus: 'chat' })
})

test('context is attached once with an inspectable source and exact selected text', () => {
  const input = { kind: 'code', label: 'main.mbt:8', path: 'main.mbt', line: 8, text: 'fn main {\n  println("hello")\n}' }
  const contexts = addContextToList([], input)
  assert.equal(addContextToList(contexts, input).length, 1)
  assert.equal(composeCodeContext('Explain the error', contexts), 'Explain the error\n\nAttached context\n### main.mbt:8\nSource: main.mbt:8\nfn main {\n  println("hello")\n}')
  assert.equal(composeCodeContext('Plain prompt', []), 'Plain prompt')
})

test('context identities do not mix books, chats or separator-containing names', () => {
  assert.notEqual(contextKey('book:a', 'b'), contextKey('book', 'a:b'))
  assert.notEqual(contextKey('book', 'first'), contextKey('book', 'second'))
  assert.equal(normalizeCodeContext({ text: '   ' }), null)
  assert.equal(normalizeCodeContext(null), null)
  const terminal = normalizeCodeContext({ kind: 'terminal', text: '\u001b[31merror\n', label: 'Build output' })
  assert.equal(terminal.text, '\u001b[31merror\n')
  assert.equal(terminal.line, null)
})

test('keyboard tabs wrap, skip unavailable tabs, and keep browser/editor shortcuts', () => {
  const focused = []
  const activated = []
  const tabs = ['files', 'changes', 'preview', 'terminal'].map(name => ({
    name, disabled: name === 'changes',
    focus: () => focused.push(name), scrollIntoView() {},
  }))
  let prevented = 0
  const press = (key, index, modifiers = {}) => navigateTabList({
    key, target: tabs[index], preventDefault: () => prevented++, ...modifiers,
  }, tabs, tab => activated.push(tab.name))
  assert.equal(press('ArrowRight', 0), true)
  assert.equal(activated.at(-1), 'preview')
  press('ArrowRight', 3)
  assert.equal(activated.at(-1), 'files')
  press('ArrowLeft', 0)
  assert.equal(activated.at(-1), 'terminal')
  press('Home', 3)
  assert.equal(activated.at(-1), 'files')
  press('End', 0)
  assert.equal(activated.at(-1), 'terminal')
  assert.deepEqual(focused, activated)
  for (const [key, modifiers] of [['Tab', {}], ['ArrowDown', {}], ['ArrowLeft', { altKey: true }], ['Home', { ctrlKey: true }], ['ArrowRight', { isComposing: true }]]) {
    assert.equal(press(key, 0, modifiers), false)
  }
  assert.equal(press('ArrowRight', 1), false)
  assert.equal(prevented, 5)
})
