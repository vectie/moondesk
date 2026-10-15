import test from 'node:test'
import assert from 'node:assert/strict'
import { createOpenBufferTypeScriptService } from './source-typescript-service.js'
import { SourcePositionMemory, boundedEditorPosition } from './source-position-memory.js'
import { SourceNavigation } from './source-navigation.js'

test('TypeScript service resolves declarations and references across opened imports', () => {
  const service = createOpenBufferTypeScriptService()
  service.update('lib.ts', 'export function answer() { return 42 }')
  const source = 'import { answer } from "./lib";\nconst result = answer();'
  service.update('main.ts', source)
  const definitions = service.definitions('main.ts', source.lastIndexOf('answer') + 1)
  assert.equal(definitions[0].path, 'lib.ts'); assert.equal(definitions[0].line, 1)
  assert.ok(service.references('lib.ts', 17).some(item => item.path === 'main.ts'))
  service.update('main.ts', 'const result = ;')
  assert.ok(service.diagnostics('main.ts').some(item => item.line === 1))
  service.dispose()
})

test('JavaScript buffers use parser diagnostics without a runtime evaluation', () => {
  const service = createOpenBufferTypeScriptService()
  service.update('script.js', 'function value() { return 2 }\nvalue()')
  assert.equal(service.diagnostics('script.js').length, 0)
  assert.equal(service.definitions('script.js', 33)[0].path, 'script.js')
  service.dispose()
})

test('position and navigation restore per book without saving source contents', () => {
  const store = new Map(), storage = { setItem: (key, value) => store.set(key, value), getItem: key => store.get(key) }
  const positions = new SourcePositionMemory(storage)
  positions.save('book', 'a.ts', { start: 20, end: 30, scrollTop: 150, text: 'secret source' })
  assert.equal(new SourcePositionMemory(storage).read('book', 'a.ts', 'short').start, 5)
  assert.equal(positions.read('other', 'a.ts', 'short'), null)
  assert.equal(boundedEditorPosition({ start: 2, end: 2 }, 'a😀b').start, 1)
  const history = new SourceNavigation(50, storage); history.context('book')
  history.begin({ path: 'a.ts', start: 2, text: 'secret source' }, { path: 'b.ts', start: 0 }); history.arrive('b.ts')
  history.context('other'); history.context('book'); assert.equal(history.back[0].path, 'a.ts')
  assert.ok([...store.values()].every(text => !text.includes('secret source')))
})
