import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  plugins: [
    svelte({
      compilerOptions: {
        customElement: true,
      },
    }),
  ],
  resolve: {
    conditions: ['browser'],
  },
  build: {
    outDir: 'dist-ce',
    rollupOptions: {
      input: 'index.ce.html',
    },
  },
})
