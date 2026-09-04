import '/styles.css'
import '/styles/product-shell.css'
import '/styles/mooncode-workflow.css'
import '/styles/mooncode-tool-transcript.css'
import '/styles/mooncode.css'
import '/styles/mooncode-controls.css'
import '/styles/mooncode-developer-tools.css'
import '/styles/moondesk-ux.css'
import {
  connectedWorkspaceUrl,
  parseProviderHandoff,
  providerHandoffRequest,
} from './provider-handoff-runtime.js'

const app = document.getElementById('app')

if (app) {
  app.innerHTML = `
    <div class="boot-shell">
      <div class="boot-panel">
        <p class="eyebrow">MoonDesk</p>
        <h1>Loading workspace</h1>
        <p>Preparing the explorer, previews, inspector, and activity drawer.</p>
      </div>
    </div>
  `
}

const startWorkspace = () => {
  // Keep the shell and the generated Rabbita application as independent async
  // chunks. The shell can parse and paint the loading surface without waiting
  // for either the interaction handlers or the multi-megabyte application.
  void import('./shell-runtime.js')
  void import('./workspace-features-runtime.js')
  void import('./mooncode-developer-tools-runtime.js')
  requestAnimationFrame(() => {
    void import('/main.js')
  })
}

const consumeProviderHandoff = async () => {
  const handoff = parseProviderHandoff(globalThis.location.hash)
  if (!handoff) return false

  // Remove the capability from visible URL state before the first network
  // operation. It is never copied to local/session storage or application
  // model state.
  history.replaceState(null, '', `${location.pathname}${location.search}`)
  const response = await fetch(
    '/api/desktop/provider-handoff',
    providerHandoffRequest(handoff),
  )
  const text = await response.text()
  if (text.length > 65536) throw new Error('The provider response was too large.')
  if (!response.ok) {
    let detail = `HTTP ${response.status}`
    try { detail = JSON.parse(text)?.error || detail } catch (_) {}
    throw new Error(detail)
  }
  const result = JSON.parse(text)
  if (result?.ok !== true || result?.status !== 'connected') {
    throw new Error('MoonDesk could not verify the provider connection.')
  }
  location.replace(connectedWorkspaceUrl(location.href))
  return true
}

consumeProviderHandoff()
  .then(navigating => {
    if (!navigating) startWorkspace()
  })
  .catch(error => {
    if (!app) return
    app.innerHTML = `
      <div class="boot-shell">
        <div class="boot-panel" role="alert">
          <p class="eyebrow">Secure provider connection</p>
          <h1>MoonDesk could not connect</h1>
          <p>${String(error?.message || error).replace(/[<>&"']/g, character => ({
            '<': '&lt;', '>': '&gt;', '&': '&amp;', '"': '&quot;', "'": '&#39;'
          })[character])}</p>
          <p>Ask your administrator to verify the pinned LunaNexa issuer and that MoonGate is running, then create a new connection from the enterprise portal.</p>
          <button type="button" id="continue-without-provider">Open MoonDesk without connecting</button>
        </div>
      </div>
    `
    document.getElementById('continue-without-provider')?.addEventListener('click', () => {
      startWorkspace()
    }, { once: true })
  })
