import { defineConfig } from 'vite'
import rabbita from '@rabbita/vite'

export default defineConfig({
  build: {
    chunkSizeWarningLimit: 2200,
  },
  plugins: [rabbita()],
})
