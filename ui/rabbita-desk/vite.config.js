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
  // The platform build is mounted below /moondesk/; standalone preview keeps /.
  base: process.env.MOONDESK_BASE_PATH || '/',
  build: {
    minify: 'terser',
    terserOptions: {
      compress: {
        passes: 4,
        toplevel: true,
        unsafe_arrows: true,
        // JSON passed to typed MoonBit decoders must retain boolean values.
        booleans_as_integers: false,
      },
      mangle: { toplevel: true },
      format: { comments: false },
    },
    // Size budgets are temporarily non-blocking while the coding workflow grows.
    // bundle-split.test.mjs still reports the raw and gzip sizes for visibility.
    chunkSizeWarningLimit: Number.MAX_SAFE_INTEGER,
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
