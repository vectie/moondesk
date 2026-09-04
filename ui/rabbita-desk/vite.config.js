import { defineConfig } from 'vite'
import rabbita from '@rabbita/vite'

const LAZY_RABBITA_ROUTE_PARSE_BUDGET_KIB = 3 * 1024

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
    minify: 'terser',
    terserOptions: {
      compress: {
        passes: 4,
        toplevel: true,
        unsafe_arrows: true,
        booleans_as_integers: true,
      },
      mangle: { toplevel: true },
      format: { comments: false },
    },
    // The generated Rabbita route is intentionally lazy. Keep the build warning
    // aligned with the named 3 MiB raw parse budget asserted by the bundle test;
    // compressed transfer and focused lazy chunks have stricter independent caps.
    chunkSizeWarningLimit: LAZY_RABBITA_ROUTE_PARSE_BUDGET_KIB,
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
