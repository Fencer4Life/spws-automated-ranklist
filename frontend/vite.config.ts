/// <reference types="vitest/config" />
// The reference adds Vitest's `test` block to Vite's config type (TS2769 without it).
import { defineConfig } from 'vite'
import { svelte } from '@sveltejs/vite-plugin-svelte'

// Node has its own Web Storage (on by default from Node 25), and reading its
// localStorage with no --localstorage-file prints a warning in every test
// worker. The tests use jsdom's localStorage, so Node's is switched off wherever
// the flag exists; before Node 25 the feature is off unless asked for.
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
    // Vite 5's default browsers. Vite 8's default is Baseline Widely Available
    // (Safari 16.4, Chrome 111), which would drop the phones and tablets the site
    // served before the Vite 8 upgrade. vite.config.ce.ts holds the same list.
    target: ['es2020', 'edge88', 'firefox78', 'chrome87', 'safari14'],
  },
  server: {
    fs: {
      // '.' is Vite's default, this folder. tests/assets.test.ts compares the two
      // published static pages with their copies in doc/tools/ (8.88, 8.94), and
      // Vite 6 and later refuse a ?raw import from outside the allowed folders.
      // A folder, not the two files: Vite also checks the id with ?raw attached,
      // which only a folder entry contains.
      allow: ['.', '../doc/tools'],
    },
  },
  test: {
    environment: 'jsdom',
    globals: true,
    exclude: ['e2e/**', 'node_modules/**'],
    execArgv: nodeWebStorageOff,
  },
})
