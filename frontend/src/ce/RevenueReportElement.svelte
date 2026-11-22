<!-- FR-176 — the organiser's revenue forecast, register.html?view=revenue.
     `demo` is a Boolean attribute, as on the other SPWS elements (CE.DEMO.01). -->
<svelte:options customElement={{ tag: 'spws-revenue-report', props: { demo: { type: 'Boolean' } } }} />

{#if !demo}
  <RevenueReport eventCode={event} token={key} />
{/if}

<script lang="ts">
  import RevenueReport from '../components/RevenueReport.svelte'
  import { initClient } from '../lib/api'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    event = '',
    k = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    event?: string
    k?: string
    demo?: boolean
  } = $props()

  // The key: the `k` attribute, else ?k= in the address (a host page that
  // mounts the element with its own attributes). Checked inside the database
  // function; the bundle is public, so a check here would be decoration.
  const key = $derived(
    k || (typeof location !== 'undefined' ? new URLSearchParams(location.search).get('k') : '') || '',
  )

  // initClient runs synchronously (module init), matching EntryListElement.
  // svelte-ignore state_referenced_locally
  if (!demo) {
    const url = supabaseCertUrl || supabaseProdUrl
    const anonKey = supabaseCertKey || supabaseProdKey
    if (url && anonKey) initClient(url, anonKey)
  }
</script>
