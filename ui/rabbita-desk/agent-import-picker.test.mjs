import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'
import vm from 'node:vm'

const source = await readFile(new URL('./main/agent_import_commands.mbt', import.meta.url), 'utf8')
const extern = source.split('extern "js" fn browser_pick_agent_package() -> @js.Promise =')[1]?.split('\n///|')[0]
assert.ok(extern, 'package picker extern is present')
const pickerSource = extern.split('\n').filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\| ?/, '')).join('\n')

function harness(action, { readError = false } = {}) {
  const listeners = new Map()
  const timers = []
  let removed = false
  let reads = 0
  const input = {
    files: [],
    click() { queueMicrotask(() => action(input, listeners, timers)) },
    remove() { removed = true },
  }
  const context = vm.createContext({
    document: { createElement: () => input, body: { appendChild() {} } },
    window: {
      addEventListener(name, callback) { listeners.set(name, callback) },
      removeEventListener(name, callback) { if (listeners.get(name) === callback) listeners.delete(name) },
    },
    setTimeout(callback) { timers.push(callback) },
    FileReader: class {
      readAsDataURL(file) {
        reads += 1
        queueMicrotask(() => {
          if (readError) this.onerror()
          else { this.result = file.data; this.onload() }
        })
      }
    },
  })
  const pick = vm.runInContext(`(${pickerSource})`, context)
  return { pick, input, listeners, timers, get removed() { return removed }, get reads() { return reads } }
}

test('package picker reads one immutable file once and cleans transient controls', async () => {
  const h = harness(input => {
    input.files = [{ name: 'shared.moonbook-agent', size: 707957, lastModified: 1, data: 'data:application/octet-stream;base64,e30=' }]
    input.onchange()
  })
  const result = JSON.parse(await h.pick())
  assert.equal(result.ok, true)
  assert.equal(result.files.length, 1)
  assert.equal(result.files[0].name, 'shared.moonbook-agent')
  assert.equal(result.files[0].content, 'data:application/octet-stream;base64,e30=')
  assert.equal(h.reads, 1)
  assert.equal(h.input.accept, '.moonbook-agent')
  assert.equal(h.removed, true)
  assert.equal(h.listeners.size, 0)
})

test('package picker cancel and focus fallback settle without upload bytes', async () => {
  for (const action of [input => input.oncancel(), (_input, listeners, timers) => { listeners.get('focus')(); timers[0]() }]) {
    const h = harness(action)
    const result = JSON.parse(await h.pick())
    assert.deepEqual(result, { ok: true, files: [] })
    assert.equal(h.reads, 0)
    assert.equal(h.removed, true)
  }
})

test('package picker rejects wrong extension empty oversized and unreadable files', async () => {
  for (const file of [
    { name: 'book.zip', size: 1 },
    { name: 'book.moonbook-agent', size: 0 },
    { name: 'book.moonbook-agent', size: 64 * 1024 * 1024 + 1 },
  ]) {
    const h = harness(input => { input.files = [file]; input.onchange() })
    const result = JSON.parse(await h.pick())
    assert.equal(result.ok, false)
    assert.equal(h.reads, 0)
    assert.equal(h.removed, true)
  }
  const h = harness(input => { input.files = [{ name: 'book.moonbook-agent', size: 1 }]; input.onchange() }, { readError: true })
  const result = JSON.parse(await h.pick())
  assert.equal(result.ok, false)
  assert.match(result.error, /Could not read/)
  assert.equal(h.removed, true)
})

test('package picker ignores duplicate change and delayed focus events', async () => {
  const h = harness((input, listeners, timers) => {
    input.files = [{ name: 'shared.moonbook-agent', size: 1, lastModified: 1, data: 'data:application/octet-stream;base64,e30=' }]
    listeners.get('focus')()
    input.onchange()
    input.onchange()
    timers[0]()
  })
  const result = JSON.parse(await h.pick())
  assert.equal(result.ok, true)
  assert.equal(h.reads, 1)
  assert.equal(result.files.length, 1)
})

const bindingFile = await readFile(new URL('./main/agent_import_binding_picker.mbt', import.meta.url), 'utf8')
const bindingExtern = bindingFile.split('extern "js" fn browser_pick_agent_binding() -> @js.Promise =')[1]
assert.ok(bindingExtern, 'binding picker extern is present')
const bindingSource = bindingExtern.split('\n').filter(line => /^\s*#\|/.test(line)).map(line => line.replace(/^\s*#\| ?/, '')).join('\n')

function bindingHarness(action) {
  const listeners = new Map()
  const timers = []
  let removed = false
  let reads = 0
  const input = {
    files: [],
    click() { queueMicrotask(() => action(input, listeners, timers)) },
    remove() { removed = true },
  }
  const pick = vm.runInContext(`(${bindingSource})`, vm.createContext({
    document: { createElement: () => input, body: { appendChild() {} } },
    window: {
      addEventListener(name, callback) { listeners.set(name, callback) },
      removeEventListener(name, callback) { if (listeners.get(name) === callback) listeners.delete(name) },
    },
    setTimeout(callback) { timers.push(callback) },
  }))
  return { pick, input, listeners, timers, file(name = 'original.binding.json', size = 64, content = '{}') {
    return { name, size, lastModified: 1, async text() { reads += 1; return content } }
  }, get reads() { return reads }, get removed() { return removed } }
}

test('Town binding picker reads original text once and cleans controls after repeated events', async () => {
  const original = '{"contract":"moontown.portable-listing-binding.v1"}'
  const h = bindingHarness((input, listeners, timers) => {
    input.files = [h.file('original.binding.json', original.length, original)]
    listeners.get('focus')()
    input.onchange(); input.onchange(); timers[0]()
  })
  const result = JSON.parse(await h.pick())
  assert.equal(result.ok, true)
  assert.equal(result.files[0].content, original)
  assert.equal(h.reads, 1)
  assert.equal(h.removed, true)
  assert.equal(h.listeners.size, 0)
})

test('Town binding cancel and focus fallback do not read a file or start import', async () => {
  for (const action of [input => input.oncancel(), (_input, listeners, timers) => { listeners.get('focus')(); timers[0]() }]) {
    const h = bindingHarness(action)
    assert.deepEqual(JSON.parse(await h.pick()), { ok: true, files: [] })
    assert.equal(h.reads, 0)
    assert.equal(h.removed, true)
  }
})

test('Town binding picker rejects wrong extension size and read failure without retaining controls', async () => {
  for (const [name, size] of [['binding.txt', 1], ['binding.json', 0], ['binding.json', 128 * 1024 + 1]]) {
    const h = bindingHarness(input => { input.files = [h.file(name, size)]; input.onchange() })
    assert.equal(JSON.parse(await h.pick()).ok, false)
    assert.equal(h.reads, 0)
    assert.equal(h.removed, true)
  }
  const h = bindingHarness(input => {
    input.files = [{ name: 'binding.json', size: 10, async text() { throw new Error('read failed') } }]
    input.onchange()
  })
  assert.equal(JSON.parse(await h.pick()).ok, false)
  assert.equal(h.removed, true)
})
