const artifactMessageContract = 'moondesk.living-artifact-message.v1'
const hostMessageContract = 'moondesk.living-artifact-host.v1'
const livingArtifactPathPrefix = 'book/site/generated/living/'

function livingArtifactTransition(records, updated) {
  if (!updated?.id) return records
  return [updated, ...records.filter(item => item.id !== updated.id)]
}

function livingArtifactPath(id) {
  return `${livingArtifactPathPrefix}${String(id || '')}/index.html`
}

function livingArtifactMessage(value, selectedPath) {
  if (!value || value.contract !== artifactMessageContract) return null
  const artifactId = String(value.artifact_id || '').trim()
  if (!artifactId || artifactId.length > 400 || selectedPath !== livingArtifactPath(artifactId)) {
    return null
  }
  if (value.type === 'ready') {
    return { type: 'ready', artifact_id: artifactId }
  }
  if (value.type !== 'command') return null
  const command = String(value.command || '')
  if (!['add-item', 'toggle-item', 'set-value'].includes(command)) return null
  const label = String(value.label || '').trim()
  const itemId = String(value.item_id || '').trim()
  const itemValue = String(value.value || '').trim()
  if (label.length > 500 || itemId.length > 500 || itemValue.length > 4000) return null
  if (command === 'add-item' && !label) return null
  if (command !== 'add-item' && !itemId) return null
  return {
    type: 'command',
    artifact_id: artifactId,
    command,
    item_id: itemId,
    label,
    value: itemValue,
  }
}

function installLivingArtifactBridge({ getState, onSaved, onError }) {
  const sendState = (iframe, artifact) => {
    iframe.contentWindow?.postMessage({
      contract: hostMessageContract,
      artifact_id: artifact.id,
      artifact,
    }, '*')
  }
  const listener = async event => {
    const iframe = document.querySelector('[data-testid="browser-preview-frame"]')
    if (!(iframe instanceof HTMLIFrameElement) || event.source !== iframe.contentWindow) return
    const state = getState()
    const message = livingArtifactMessage(event.data, state.selectedPath)
    if (!message || !state.workspaceId) return
    try {
      if (message.type === 'ready') {
        const response = await fetch(`/api/living-artifacts?workspace_id=${encodeURIComponent(state.workspaceId)}&id=${encodeURIComponent(message.artifact_id)}`)
        if (!response.ok) throw new Error('load failed')
        const payload = await response.json()
        const artifact = Array.isArray(payload.artifacts) ? payload.artifacts[0] : null
        if (!artifact) throw new Error('artifact missing')
        sendState(iframe, artifact)
        onSaved?.(artifact)
        return
      }
      const response = await fetch('/api/living-artifacts', {
        method: 'POST',
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({
          action: 'command',
          workspace_id: state.workspaceId,
          id: message.artifact_id,
          command: message.command,
          item_id: message.item_id,
          label: message.label,
          value: message.value,
        }),
      })
      if (!response.ok) throw new Error('save failed')
      const artifact = await response.json()
      sendState(iframe, artifact)
      onSaved?.(artifact)
    } catch (error) {
      onError?.(String(error))
    }
  }
  globalThis.addEventListener('message', listener)
  return () => globalThis.removeEventListener('message', listener)
}

export {
  installLivingArtifactBridge,
  livingArtifactMessage,
  livingArtifactPath,
  livingArtifactTransition,
}
