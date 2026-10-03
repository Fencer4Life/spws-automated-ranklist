<svelte:options
  customElement={{ tag: 'spws-ranklist', props: { demo: { type: 'Boolean' } } }}
/>

<App
  supabase-cert-url={supabaseCertUrl}
  supabase-cert-key={supabaseCertKey}
  supabase-prod-url={supabaseProdUrl}
  supabase-prod-key={supabaseProdKey}
  asset-base={assetBase}
  {view}
  {chrome}
  href-home={hrefHome}
  href-ranking={hrefRanking}
  href-calendar={hrefCalendar}
  href-calculator={hrefCalculator}
  href-table={hrefTable}
  demo={demo}
/>

<script lang="ts">
  // The ranking as published on the association's WordPress page /ranking/
  // (ADR-090 amendment 2026-10-03, FR-148): chrome="site" draws the SPWS bar
  // and a drawer of the site's pages, from the addresses the page body gives.
  // Without those attributes the element is the full application, as before.
  import App from '../App.svelte'
  import type { AppView } from '../lib/types'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    // Points at the GitHub Pages origin, where the logo and the marks deploy.
    'asset-base': assetBase = '',
    view = 'ranklist',
    chrome = 'full',
    'href-home': hrefHome = '',
    'href-ranking': hrefRanking = '',
    'href-calendar': hrefCalendar = '',
    'href-calculator': hrefCalculator = '',
    'href-table': hrefTable = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    'asset-base'?: string
    view?: AppView
    chrome?: 'full' | 'site' | 'none'
    'href-home'?: string
    'href-ranking'?: string
    'href-calendar'?: string
    'href-calculator'?: string
    'href-table'?: string
    demo?: boolean
  } = $props()
</script>
