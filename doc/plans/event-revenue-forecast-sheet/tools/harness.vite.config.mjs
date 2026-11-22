// Builds a sheet harness with the app's own Svelte settings
// (frontend/vite.config.ts). Run from <checkout>/frontend by build_harness.sh.
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

export default defineConfig({
  root: '.sheet-harness',
  base: './',
  plugins: [svelte({ compilerOptions: { customElement: true, compatibility: { componentApi: 4 } } })],
  resolve: { conditions: ['browser'] },
  build: { target: ['es2020'], chunkSizeWarningLimit: 4000 },
})
