import { defineConfig } from 'vite'
import rabbita from '@rabbita/vite'

function moondeskMoonbitBrowserShim() {
  return {
    name: 'moondesk-moonbit-browser-shim',
    enforce: 'post',
    transform(code, id) {
      if (!id.includes('\0rabbita-main-entry') && !code.includes('require("process")')) {
        return null
      }
      let next = code
        .replaceAll(
          `let process = require("process");
  return process.platform === "win32";`,
          `return typeof navigator !== "undefined" &&
    /Windows/i.test(navigator.userAgent || navigator.platform || "");`,
        )
        .replaceAll(
          `return require("process").platform==="win32"`,
          `return typeof navigator!="undefined"&&/Windows/i.test(navigator.userAgent||navigator.platform||"")`,
        )
      return next === code ? null : { code: next, map: null }
    },
  }
}

export default defineConfig({
  build: {
    // The generated Rabbita route is intentionally lazy and stays below the
    // 2.8 MiB raw parse budget asserted by bundle-split.test.mjs. Vite reports
    // this as decimal kB, so keep the diagnostic threshold just above that
    // binary budget without hiding a materially oversized entry. The stricter
    // compressed transfer budget remains enforced by the bundle test.
    chunkSizeWarningLimit: 2940,
  },
  server: {
    proxy: {
      '/api': 'http://127.0.0.1:4321',
    },
  },
  preview: {
    proxy: {
      '/api': 'http://127.0.0.1:4321',
    },
  },
  plugins: [rabbita(), moondeskMoonbitBrowserShim()],
})
