const EVIDENCE_PROTOCOL = 'moondesk-preview-evidence-v1'
const HOST_PROTOCOL = 'moondesk-browser-host-v1'
const PREVIEW_PROTOCOL = 'moondesk-preview-v1'

export function moonCodeBrowserEvidenceRequestId() {
  return globalThis.crypto?.randomUUID?.() ||
    `browser-evidence-${Date.now()}-${Math.random().toString(16).slice(2)}`
}

export function moonCodeBrowserEvidencePayload(root, data, consoleText = '', runtimeText = '') {
  const resources = Array.isArray(data?.resources) ? data.resources.map(String) : []
  return {
    protocol: EVIDENCE_PROTOCOL,
    request_id: String(root?.dataset?.evidenceRequestId || ''),
    source_path: String(root?.dataset?.sourcePath || ''),
    accessibility: String(data?.accessibility || ''),
    resources,
    console: String(consoleText || ''),
    runtime: String(runtimeText || ''),
  }
}

export function applyMoonCodeBrowserEvidenceStatus(panel, status, detail) {
  if (!(panel instanceof HTMLElement) || !detail || detail.protocol !== HOST_PROTOCOL) return false
  const persisted = detail.state === 'persisted' &&
    typeof detail.hostReceiptId === 'string' && detail.hostReceiptId.length > 0 &&
    typeof detail.evidenceRef === 'string' && detail.evidenceRef.length > 0
  if (persisted) {
    panel.dataset.evidenceState = 'persisted'
    panel.dataset.hostReceiptId = detail.hostReceiptId
    panel.dataset.evidenceRef = detail.evidenceRef
    if (status) status.textContent = 'Evidence persisted · awaiting Bookkeeper review'
    return true
  }
  panel.dataset.evidenceState = detail.state === 'failed' ? 'failed' : 'prepared'
  delete panel.dataset.hostReceiptId
  delete panel.dataset.evidenceRef
  if (status) {
    status.textContent = detail.state === 'failed'
      ? `Evidence not persisted${detail.reason ? ` · ${detail.reason}` : ''}`
      : 'Evidence request prepared · not persisted'
  }
  return false
}

function ensureMoonCodeBrowserEvidenceShell(panel) {
  if (panel.querySelector('[data-testid="mooncode-developer-browser-prepare-evidence"]')) return
  const statusbar = panel.querySelector('.mooncode-developer-browser-statusbar')
  if (!(statusbar instanceof HTMLElement)) return
  statusbar.insertAdjacentHTML('beforeend', '<button class="mooncode-developer-browser-button" type="button" data-testid="mooncode-developer-browser-prepare-evidence" data-developer-browser-evidence="prepare" disabled>Prepare evidence</button>')
  statusbar.insertAdjacentHTML('afterend', `
    <div class="mooncode-developer-browser-evidence" data-evidence-state="not-persisted">
      <span data-testid="mooncode-developer-browser-evidence-status" role="status" aria-live="polite">Evidence not prepared</span>
      <details data-testid="mooncode-developer-browser-diagnostics">
        <summary>Diagnostics</summary>
        <div class="mooncode-developer-browser-diagnostics-grid">
          <section><strong>Console</strong><pre data-testid="mooncode-developer-browser-console">No console output observed</pre></section>
          <section><strong>Runtime</strong><pre data-testid="mooncode-developer-browser-runtime">No runtime errors observed</pre></section>
          <section><strong>Network</strong><pre data-testid="mooncode-developer-browser-network">No resources recorded</pre></section>
          <section><strong>Accessibility</strong><pre data-testid="mooncode-developer-browser-accessibility">Prepare evidence to inspect semantics</pre></section>
        </div>
      </details>
    </div>`)
}

export function installMoonCodeBrowserEvidence(root) {
  if (!(root instanceof HTMLElement)) return
  const panel = root.querySelector('[data-testid="mooncode-developer-browser"]')
  const frame = root.querySelector('[data-testid="mooncode-developer-browser-frame"]')
  if (!(panel instanceof HTMLElement) || !(frame instanceof HTMLIFrameElement)) return
  root.__moonCodeBrowserEvidenceCleanup?.()
  ensureMoonCodeBrowserEvidenceShell(panel)
  const prepare = root.querySelector('[data-testid="mooncode-developer-browser-prepare-evidence"]')
  const status = root.querySelector('[data-testid="mooncode-developer-browser-evidence-status"]')
  if (!(prepare instanceof HTMLButtonElement)) return
  root.dataset.browserEvidenceInstalled = 'true'
  panel.dataset.evidenceState = 'not-persisted'
  prepare.disabled = true
  delete prepare.dataset.evidenceReady

  const consoleOut = root.querySelector('[data-testid="mooncode-developer-browser-console"]')
  const runtimeOut = root.querySelector('[data-testid="mooncode-developer-browser-runtime"]')
  const networkOut = root.querySelector('[data-testid="mooncode-developer-browser-network"]')
  const accessibilityOut = root.querySelector('[data-testid="mooncode-developer-browser-accessibility"]')
  const controller = new AbortController()
  const options = { signal: controller.signal }
  let previewReady = false
  const requestPreviewReady = () => {
    if (controller.signal.aborted || !frame.contentWindow || frame.src === 'about:blank') return
    frame.contentWindow.postMessage({ protocol: PREVIEW_PROTOCOL, type: 'ready-request' }, '*')
  }

  prepare.addEventListener('click', () => {
    if (!previewReady) {
      if (status) status.textContent = 'Waiting for the isolated preview'
      requestPreviewReady()
      return
    }
    if (!frame.contentWindow || frame.src === 'about:blank') {
      if (status) status.textContent = 'Open a workspace preview before preparing evidence'
      return
    }
    if (!root.dataset.workspaceId || !root.dataset.sourcePath) {
      if (status) status.textContent = 'Evidence requires a workspace-backed preview'
      return
    }
    root.dataset.evidenceRequestId = moonCodeBrowserEvidenceRequestId()
    panel.dataset.evidenceState = 'prepared'
    delete panel.dataset.evidenceRef
    delete panel.dataset.hostReceiptId
    if (status) status.textContent = 'Preparing observations · not persisted'
    frame.contentWindow.postMessage({ protocol: PREVIEW_PROTOCOL, type: 'snapshot-request' }, '*')
  }, options)

  globalThis.addEventListener('message', async event => {
    if (event.source !== frame.contentWindow) return
    const data = event.data
    if (!data || data.protocol !== PREVIEW_PROTOCOL) return
    if (data.type === 'ready') {
      previewReady = true
      prepare.disabled = false
      prepare.dataset.evidenceReady = 'true'
      if (status && panel.dataset.evidenceState === 'not-persisted') status.textContent = 'Preview ready · evidence not prepared'
      return
    }
    if (data.type === 'console' && consoleOut) {
      consoleOut.textContent = `${data.level || 'log'}: ${data.message || ''}`
      return
    }
    if (data.type === 'runtime' && runtimeOut) {
      runtimeOut.textContent = String(data.message || 'Runtime error')
      return
    }
    if (data.type !== 'snapshot') return
    if (networkOut) networkOut.textContent = (Array.isArray(data.resources) ? data.resources : []).join('\n') || 'No loaded subresources'
    if (accessibilityOut) accessibilityOut.textContent = String(data.accessibility || 'No accessibility summary')
    const payload = moonCodeBrowserEvidencePayload(
      root,
      data,
      consoleOut?.textContent || '',
      runtimeOut?.textContent || '',
    )
    if (!payload.request_id || !payload.source_path || !root.dataset.workspaceId) return
    if (status) status.textContent = 'Evidence request prepared · waiting for durable receipt'
    try {
      const response = await fetch(`/api/workspaces/${encodeURIComponent(root.dataset.workspaceId)}/browser-evidence`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify(payload),
      })
      const receipt = await response.json().catch(() => ({}))
      if (!response.ok || receipt.status !== 'persisted' || !receipt.host_receipt_id || !receipt.evidence_ref) {
        throw new Error(receipt.message || `HTTP ${response.status}`)
      }
      applyMoonCodeBrowserEvidenceStatus(panel, status, {
        protocol: HOST_PROTOCOL,
        state: 'persisted',
        hostReceiptId: receipt.host_receipt_id,
        evidenceRef: receipt.evidence_ref,
      })
    } catch (error) {
      applyMoonCodeBrowserEvidenceStatus(panel, status, {
        protocol: HOST_PROTOCOL,
        state: 'failed',
        reason: String(error?.message || error || 'persistence failed'),
      })
    }
  }, options)

  globalThis.addEventListener('moondesk-browser-evidence-status', event => {
    const detail = event instanceof CustomEvent ? event.detail : null
    applyMoonCodeBrowserEvidenceStatus(panel, status, detail)
  }, options)
  globalThis.addEventListener('moondesk-browser-host-status', event => {
    const detail = event instanceof CustomEvent ? event.detail : null
    if (!detail || detail.protocol !== HOST_PROTOCOL || detail.state !== 'restarted') return
    panel.dataset.evidenceState = 'not-persisted'
    delete panel.dataset.evidenceRef
    delete panel.dataset.hostReceiptId
    if (status) status.textContent = `${detail.label || 'Browser host restarted'} · evidence not persisted`
  }, options)
  frame.addEventListener('load', () => {
    previewReady = false
    prepare.disabled = true
    delete prepare.dataset.evidenceReady
    requestPreviewReady()
    setTimeout(requestPreviewReady, 50)
  }, options)
  requestPreviewReady()
  setTimeout(requestPreviewReady, 50)

  const observer = new MutationObserver(() => {
    if (root.isConnected) return
    controller.abort()
    observer.disconnect()
  })
  observer.observe(document.documentElement, { childList: true, subtree: true })
  root.__moonCodeBrowserEvidenceCleanup = () => {
    prepare.disabled = true
    delete prepare.dataset.evidenceReady
    controller.abort()
    observer.disconnect()
    delete root.__moonCodeBrowserEvidenceCleanup
    delete root.dataset.browserEvidenceInstalled
  }
}
