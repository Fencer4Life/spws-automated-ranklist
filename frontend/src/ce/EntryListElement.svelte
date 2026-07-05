<svelte:options customElement="spws-entry-list" />

{#if resolvedEventId != null}
  <EntryList eventId={resolvedEventId} />
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
