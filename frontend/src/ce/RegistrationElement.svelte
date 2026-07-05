<svelte:options customElement="spws-registration" />

<RegistrationForm eventCode={event} {payee} {iban} />

<script lang="ts">
  import RegistrationForm from '../components/RegistrationForm.svelte'
  import { initClient } from '../lib/api'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    event = '',
    payee = 'SPWS',
    iban = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    event?: string
    payee?: string
    iban?: string
    demo?: boolean
  } = $props()

  // This is a single shareable public page deployed against exactly one
  // Supabase project per environment — unlike the admin app's RanklistElement,
  // there is no runtime CERT/PROD toggle exposed to a fencer. cert-* is
  // populated for LOCAL/CERT deploys, prod-* for the PROD deploy (build-time
  // sed picks one pair per deploy target; see register.html).
  //
  // initClient runs synchronously here (module init), NOT inside $effect:
  // Svelte 5 runs child effects before the parent's own effects, so an
  // $effect here would race RegistrationForm's child $effect (which reads
  // the client immediately to fetch the event) — the child could run first
  // and throw on an uninitialized client. Attrs are static (set once at
  // element creation), so no reactivity is needed for this call anyway.
  if (!demo) {
    const url = supabaseCertUrl || supabaseProdUrl
    const key = supabaseCertKey || supabaseProdKey
    if (url && key) initClient(url, key)
  }
</script>
