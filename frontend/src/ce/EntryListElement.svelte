<svelte:options customElement="spws-entry-list" />

{#if resolvedEventId != null}
  <EntryList eventId={resolvedEventId} onclose={backToRegistration} />
{:else if event}
  <p class="el-not-found">{t('reg_event_not_found')}</p>
{/if}

<script lang="ts">
  import EntryList from '../components/EntryList.svelte'
  import { initClient, fetchEventForRegistration } from '../lib/api'
  import { t } from '../lib/locale.svelte'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    event = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    event?: string
    demo?: boolean
  } = $props()

  let resolvedEventId = $state<number | null>(null)

  // This page renders the roster with no registration form around it, so unlike
  // the modal there is nothing to dismiss to — and unlike the in-flow roster
  // (RegistrationForm's `list` step) there is no back button either, because a
  // visitor who followed the shared link never passed through the form. That
  // left the shared roster link a dead end.
  //
  // Closing here therefore means going to the registration form for the same
  // event: the one place there is to go. It is a real navigation, not a step
  // change, because register.html mounts a different custom element per view.
  function backToRegistration() {
    location.assign(`?event=${encodeURIComponent(event)}`)
  }

  // initClient runs synchronously (module init), matching RegistrationElement
  // — see that file's comment for why this can't safely live in an $effect.
  if (!demo) {
    const url = supabaseCertUrl || supabaseProdUrl
    const key = supabaseCertKey || supabaseProdKey
    if (url && key) initClient(url, key)
  }

  $effect(() => {
    if (demo || !event) return
    fetchEventForRegistration(event).then((ev) => {
      resolvedEventId = ev?.id_event ?? null
    })
  })
</script>

<style>
  .el-not-found {
    max-width: 640px;
    margin: 40px auto;
    text-align: center;
    color: #8894a8;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
</style>
