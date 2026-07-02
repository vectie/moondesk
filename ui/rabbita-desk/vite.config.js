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
    chunkSizeWarningLimit: 2200,
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
