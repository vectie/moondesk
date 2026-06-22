import { defineConfig } from 'vite'
import rabbita from '@rabbita/vite'

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
  plugins: [rabbita()],
})
