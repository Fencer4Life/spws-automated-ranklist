import { vitePreprocess } from '@sveltejs/vite-plugin-svelte'

export default {
  preprocess: vitePreprocess(),
  // Both builds compile with customElement: true (vite.config.ts and
  // vite.config.ce.ts). svelte-check reads only this file, so without it every
  // <svelte:options customElement> under src/ce/ was flagged as missing the
  // option (options_missing_custom_element) although no build lacks it.
  compilerOptions: {
    customElement: true,
  },
}
