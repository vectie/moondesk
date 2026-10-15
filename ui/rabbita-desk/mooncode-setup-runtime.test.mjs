import test from 'node:test'
import assert from 'node:assert/strict'
import { normalizeSkillImport, applyCodingPreset, setupTabForKey, retainCodingSetupDraft, restoreCodingSetupDraft } from './mooncode-setup-runtime.js'

test('closing and remounting retains edited fields per book without saving server state', () => {
  const values = {
    'skill-id': 'my-review', 'skill-content': 'unsaved skill', 'new-file-path': 'notes/examples.md',
    instructions: 'unsaved instructions', 'prompt-name': 'Review', 'prompt-text': 'unsaved prompt',
    'preset-name': 'Careful', 'preset-model': 'provider/model', 'preset-reasoning': 'high', 'preset-intent': 'read_only',
    'integration-id': 'tools', 'integration-url': 'https://example.com/mcp', 'integration-token': 'unsaved-token',
    'knowledge-title': 'Guide', 'knowledge-path': 'guide.md', 'knowledge-text': 'unsaved extraction', 'knowledge-query': 'question',
    'knowledge-embedding-url': 'https://example.com/embeddings', 'knowledge-embedding-model': 'embed', 'knowledge-embedding-token': 'embedding-token',
  }
  const root = { dataset: { workspaceId: 'draft-book-a' }, querySelector(selector) { const name = selector.match(/name="([^"]+)"/)?.[1]; return name in values ? { value: values[name] } : null } }
  const state = { ...restoreCodingSetupDraft(root), tab: 'skills', draft: { id: 'old', files: [{ path: 'SKILL.md', content: 'old' }] }, data: { instructions: 'saved instructions' } }
  retainCodingSetupDraft(state)
  const reopened = restoreCodingSetupDraft({ dataset: { workspaceId: 'draft-book-a' } })
  assert.equal(reopened.draft.id, 'my-review')
  assert.equal(reopened.draft.files[0].content, 'unsaved skill')
  assert.equal(reopened.instructions, 'unsaved instructions')
  assert.deepEqual(reopened.promptDraft, { name: 'Review', text: 'unsaved prompt' })
  assert.equal(reopened.knowledgeDraft.extracted_text, 'unsaved extraction')
  for (const name of ['new-file-path', 'preset-name', 'preset-model', 'preset-reasoning', 'preset-intent', 'integration-id', 'integration-url', 'integration-token', 'knowledge-query', 'knowledge-embedding-url', 'knowledge-embedding-model', 'knowledge-embedding-token']) assert.equal(reopened.fieldDrafts[name], values[name])
  assert.equal(reopened.data.instructions, 'saved instructions')
  assert.equal(restoreCodingSetupDraft({ dataset: { workspaceId: 'draft-book-b' } }).draft, null)
  reopened.draft.files[0].content = 'changed after reopening'
  assert.equal(restoreCodingSetupDraft({ dataset: { workspaceId: 'draft-book-a' } }).draft.files[0].content, 'unsaved skill')
})

test('setup sections follow keyboard tab navigation without intercepting unrelated keys', () => {
  assert.equal(setupTabForKey('skills', 'ArrowLeft'), 'history')
  assert.equal(setupTabForKey('history', 'ArrowRight'), 'skills')
  assert.equal(setupTabForKey('knowledge', 'ArrowRight'), 'presets')
  assert.equal(setupTabForKey('knowledge', 'Home'), 'skills')
  assert.equal(setupTabForKey('knowledge', 'End'), 'history')
  assert.equal(setupTabForKey('knowledge', 'Tab'), null)
})

test('Markdown skill import uses declared skill name and retains source', () => {
  const source = '---\nname: review-changes\ndescription: Review changes\n---\n# Review\n'
  assert.deepEqual(normalizeSkillImport(source, 'SKILL.md'), { id: 'review-changes', files: [{ path: 'SKILL.md', content: source }] })
})

test('bundle import retains supporting files and requires skill entry point', () => {
  const bundle = { id: 'review', files: [{ path: 'SKILL.md', content: 'instructions' }, { path: 'references/demo.md', content: '示例' }] }
  assert.deepEqual(normalizeSkillImport(JSON.stringify(bundle)), bundle)
  assert.throws(() => normalizeSkillImport('{"id":"broken","files":[]}'), /skill bundle/)
})

test('preset applies through live model controls and refuses disconnected models', () => {
  const calls = []
  const controls = { dataset: { models: 'moongate/fast\nmoongate/careful' }, querySelector: selector => ({ value: '', dispatchEvent(event) { calls.push([selector, this.value, event.type]) } }) }
  const scope = { querySelector: () => controls }
  applyCodingPreset({ model: 'moongate/careful', reasoning: 'high', task_intent: 'read_only' }, scope)
  assert.deepEqual(calls.map(call => call.slice(1)), [['moongate/careful', 'input'], ['high', 'input'], ['read_only', 'input']])
  assert.throws(() => applyCodingPreset({ model: 'disconnected' }, scope), /not connected/)
  assert.equal(calls.length, 3)
})
