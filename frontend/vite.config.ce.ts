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
      // register.html MUST stay in this CE build (not the main one, ADR-079
      // amend correction): Svelte only bundles a nested (non-customElement)
      // child component's <style> into a shadow root when the WHOLE compile
      // graph runs with customElement:true. Under the main build's plain
      // config, RegistrationForm/EntryList's styles are injected into the
      // document head instead — invisible inside <spws-registration>'s shadow
      // DOM, rendering completely unstyled ("bare html"). Verified empirically
      // (A/B build test) before reverting the earlier main-build attempt.
      input: ['index.ce.html', 'register.html'],
    },
  },
})
