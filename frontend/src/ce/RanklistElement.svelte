<!-- `admin-entry` is written as a bare attribute on the WordPress page, whose
     value is "": declared Boolean, its presence reads as true. The compiler
     takes only identifier keys here, so the prop is adminEntry, mapped to the
     attribute. -->
<svelte:options
  customElement={{
    tag: 'spws-ranklist',
    props: { demo: { type: 'Boolean' }, adminEntry: { type: 'Boolean', attribute: 'admin-entry' } },
  }}
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
  admin-entry={adminEntry}
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
    // Only /ranking/ carries it: ?admin=1 opens the sign-in there (FR-149).
    adminEntry = false,
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
    adminEntry?: boolean
    demo?: boolean
  } = $props()
</script>
