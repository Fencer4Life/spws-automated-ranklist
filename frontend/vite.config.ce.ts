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
      // PROD deployment step 1 — a STABLE entry file name.
      //
      // The WordPress page at /znajdz-zawody/ hard-codes this URL in its body.
      // With Vite's default `main.ce-<hash>.js` every release would rename the
      // bundle and silently break the live page until someone hand-edited it.
      // A stable name means WordPress is touched once, and later releases reach
      // the site by replacing the file at the same address.
      //
      // The trade-off is deliberate: no content hash means no cache-busting, so
      // the bundle is cached by file name. GitHub Pages serves it with a short
      // max-age and the page is not latency-critical.
      output: {
        entryFileNames: 'assets/[name].js',
        chunkFileNames: 'assets/[name].js',
      },
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
