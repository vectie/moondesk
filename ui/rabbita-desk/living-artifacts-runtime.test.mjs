import assert from 'node:assert/strict'
import test from 'node:test'

import {
  livingArtifactMessage,
  livingArtifactPath,
  livingArtifactTransition,
} from './living-artifacts-runtime.js'

test('living artifact transitions preserve prior state immutably', () => {
  const current = [{ id: 'one', revision: 1 }, { id: 'two', revision: 1 }]
  const next = livingArtifactTransition(current, { id: 'one', revision: 2 })
  assert.deepEqual(next.map(item => item.id), ['one', 'two'])
  assert.equal(next[0].revision, 2)
  assert.equal(current[0].revision, 1)
})

test('living artifact bridge messages require the selected isolated artifact', () => {
  const path = livingArtifactPath('artifact-one')
  assert.deepEqual(livingArtifactMessage({
    contract: 'moondesk.living-artifact-message.v1',
    type: 'ready',
    artifact_id: 'artifact-one',
  }, path), { type: 'ready', artifact_id: 'artifact-one' })
  assert.equal(livingArtifactMessage({
    contract: 'moondesk.living-artifact-message.v1',
    type: 'ready',
    artifact_id: 'artifact-two',
  }, path), null)
  assert.equal(livingArtifactMessage({
    contract: 'other',
    type: 'ready',
    artifact_id: 'artifact-one',
  }, path), null)
})

test('living artifact commands are allowlisted and bounded', () => {
  const path = livingArtifactPath('artifact-one')
  assert.equal(livingArtifactMessage({
    contract: 'moondesk.living-artifact-message.v1',
    type: 'command',
    artifact_id: 'artifact-one',
    command: 'run-code',
  }, path), null)
  assert.equal(livingArtifactMessage({
    contract: 'moondesk.living-artifact-message.v1',
    type: 'command',
    artifact_id: 'artifact-one',
    command: 'add-item',
    label: '',
  }, path), null)
  assert.equal(livingArtifactMessage({
    contract: 'moondesk.living-artifact-message.v1',
    type: 'command',
    artifact_id: 'artifact-one',
    command: 'toggle-item',
    item_id: 'item-one',
  }, path)?.command, 'toggle-item')
})
