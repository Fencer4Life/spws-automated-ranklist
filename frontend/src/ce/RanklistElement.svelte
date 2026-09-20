<svelte:options
  customElement={{ tag: 'spws-ranklist', props: { demo: { type: 'Boolean' } } }}
/>

<App
  supabase-cert-url={supabaseCertUrl}
  supabase-cert-key={supabaseCertKey}
  supabase-prod-url={supabaseProdUrl}
  supabase-prod-key={supabaseProdKey}
  demo={demo}
/>

<script lang="ts">
  import App from '../App.svelte'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    demo?: boolean
  } = $props()
</script>
