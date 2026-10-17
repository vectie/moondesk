import test from 'node:test'
import assert from 'node:assert/strict'
import { readFile } from 'node:fs/promises'

// Exercise the production restoration coordinator, including a delayed real
// loadServerThreads callback. Accessors are appended only to this test module.
const source = await readFile(new URL('./workspace-features-runtime.js', import.meta.url), 'utf8')
const runtime = await import(`data:text/javascript;base64,${Buffer.from(source + `
export function setPreparedHistoryFixture(prompt = 'Exact specialist brief', hasContext = true) {
  serverState = { workspace_id: 'specialist-book', selected_document: '', task_id: '', chat: [],
    request_prompt: prompt, chat_draft_has_context: hasContext,
    request_status: 'Example prepared. Review it and click Send to try your specialist.' }
}
export function seedHistoryFixture() {
  serverThreadsByWorkspace.set('specialist-book', [{ id: 'previous-thread', document: '',
    archived: false, chat: [{ role: 'user', content: 'Unrelated previous work' }] }])
}
export { maybeRestoreCurrentThread as maybeRestoreFixture, loadServerThreads as loadHistoryFixture }
export function explicitlyResumeFixture() { emit('restore-thread', 'previous-thread') }
`).toString('base64')}`)

test('prepared specialist survives cached and late server history; automatic restore remains distinct from deliberate Resume', async () => {
  const keys = ['document', 'HTMLElement', 'fetch', '__moondeskWorkspaceFeaturesDispatch']
  const prior = keys.map(key => [key, Object.getOwnPropertyDescriptor(globalThis, key)])
  const calls = []; let resolveHistory
  Object.assign(globalThis, {
    document: { querySelector: () => null }, HTMLElement: class {},
    fetch: () => new Promise(resolve => { resolveHistory = resolve }),
    __moondeskWorkspaceFeaturesDispatch: (...args) => calls.push(args),
  })
  try {
    runtime.setPreparedHistoryFixture(); runtime.seedHistoryFixture()
    runtime.maybeRestoreFixture(); assert.equal(calls.length, 0)
    runtime.loadHistoryFixture()
    resolveHistory({ ok: true, json: async () => ({ conversations: [{
      conversation_id: 'previous-thread', document_path: '', archived: false,
      entries: [{ role: 'user', content: 'Old unrelated conversation' }],
    }] }) })
    for (let i = 0; i < 8; i++) await Promise.resolve()
    runtime.maybeRestoreFixture(); assert.equal(calls.length, 0, 'late history may not erase prepared text or references')
    runtime.setPreparedHistoryFixture('', true); runtime.maybeRestoreFixture()
    assert.equal(calls.length, 0, 'selected knowledge survives even after the user clears the prompt')
    runtime.setPreparedHistoryFixture('', false); runtime.maybeRestoreFixture()
    assert.equal(calls.length, 1, 'ordinary empty conversation still restores')
    assert.deepEqual([calls[0][0], calls[0][1], calls[0][4]], ['restore-thread', 'previous-thread', 'automatic'])
    runtime.setPreparedHistoryFixture(); runtime.explicitlyResumeFixture()
    assert.equal(calls.length, 2)
    assert.deepEqual([calls[1][0], calls[1][1], calls[1][4]], ['restore-thread', 'previous-thread', ''])
  } finally {
    for (const [key, descriptor] of prior) {
      if (descriptor) Object.defineProperty(globalThis, key, descriptor)
      else delete globalThis[key]
    }
  }
})
