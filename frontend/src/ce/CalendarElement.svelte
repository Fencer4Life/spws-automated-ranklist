<svelte:options customElement="spws-calendar" />

<App
  supabase-cert-url={supabaseCertUrl}
  supabase-cert-key={supabaseCertKey}
  supabase-prod-url={supabaseProdUrl}
  supabase-prod-key={supabaseProdKey}
  asset-base={assetBase}
  view="calendar"
  chrome="none"
  demo={demo}
/>

<script lang="ts">
  // The calendar as published on weteraniszermierki.pl — PROD deployment step 1.
  // Plan: doc/plans/prod-deployment-wordpress-2026-09-05.html.
  //
  // This was a mock stub: its only prop was `demo`, it rendered two hard-coded
  // events, and it had never queried a database. Everything that actually loads
  // calendar data — initClient, fetchAllCalendarEvents (ALL seasons, because
  // the barrel crosses season boundaries), the scoring-config lookup behind the
  // +EVF scope, the locale store — already lives in App.svelte. So the element
  // mounts the application rather than reimplementing any of it, exactly as
  // RanklistElement does.
  //
  // `chrome="none"` drops the header, hamburger and drawer: a single embed has
  // no second view to navigate to. `view="calendar"` opens on the barrel.

  import App from '../App.svelte'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    // Points at the GitHub Pages origin, where the four organizer marks already
    // deploy. Without it they resolve against /znajdz-zawody/ and 404.
    'asset-base': assetBase = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    'asset-base'?: string
    demo?: boolean
  } = $props()
</script>

<style>
  /* A custom element is `display: inline` until told otherwise, so the host box
     collapsed to the line height and the barrel — which is built from geometry
     and needs real height — had none to work with. The height lives on the HOST
     rather than inside the shadow root because nothing outside can style the
     shadow tree, and the WordPress page gives the element no height of its own.

     `dvh` rather than `vh`: on a phone the address bar collapses on scroll, and
     `vh` measures the taller layout viewport, which cropped the bottom row. */
  :host {
    display: block;
    height: 100dvh;
  }
</style>
