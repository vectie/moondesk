import '/styles.css'
import '/styles/product-shell.css'
import '/styles/mooncode-workflow.css'
import '/styles/mooncode.css'
import '/styles/moondesk-ux.css'

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

// Keep the shell and the generated Rabbita application as independent async
// chunks. The shell can parse and paint the loading surface without waiting
// for either the interaction handlers or the multi-megabyte application.
void import('./shell-runtime.js')
requestAnimationFrame(() => {
  void import('/main.js')
})
