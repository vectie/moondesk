import '/styles.css'
import '/styles/moonsuite-theme.css'
import '/styles/product-shell.css'
import '/styles/mooncode.css'

const app = document.getElementById('app')

if (app) {
  app.innerHTML = `
    <div class="boot-shell">
      <div class="boot-panel">
        <p class="eyebrow">Moondesk</p>
        <h1>Loading workspace</h1>
        <p>Preparing the explorer, previews, inspector, and activity drawer.</p>
      </div>
    </div>
  `
}

await import('/main.js')
