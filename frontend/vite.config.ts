/// <reference types="vitest" />
// The reference adds Vitest's `test` block to Vite's config type (TS2769 without it).
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// Node has its own Web Storage (on by default from Node 25), and reading its
// localStorage with no --localstorage-file prints a warning in every test
// worker. The tests use jsdom's localStorage, so Node's is switched off wherever
// the flag exists; Node 20 (CI) has neither the feature nor the flag.
const nodeWebStorageOff = process.allowedNodeEnvironmentFlags.has('--no-experimental-webstorage')
  ? ['--no-experimental-webstorage']
  : []

export default defineConfig({
  plugins: [
    svelte({
      compilerOptions: {
        customElement: true,
        compatibility: {
          componentApi: 4,
        },
      },
    }),
  ],
  resolve: {
    conditions: ['browser'],
  },
  build: {
    // A size budget, not a silencer. Measured 2026-10-24: the app is one
    // 1,188 kB chunk (351 kB gzip). Splitting the admin screens into a lazy
    // chunk would shrink what public visitors load; until that is done, the
    // warning returns as soon as the bundle grows past this budget.
    chunkSizeWarningLimit: 1300,
  },
  test: {
    environment: 'jsdom',
    globals: true,
    exclude: ['e2e/**', 'node_modules/**'],
    poolOptions: {
      threads: { execArgv: nodeWebStorageOff },
      forks: { execArgv: nodeWebStorageOff },
    },
  },
})
