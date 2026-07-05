{#if open}
  <div class="modal-overlay" role="presentation" onclick={onclose}>
    <div role="dialog" aria-modal="true" tabindex="-1" onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
      {#if view === 'list' && eventId != null}
        <EntryList eventId={eventId} {onclose} />
      {:else}
        <RegistrationForm {eventCode} {payee} {iban} {onclose} {onviewlist} />
      {/if}
    </div>
  </div>
{/if}

<script lang="ts">
  import RegistrationForm from './RegistrationForm.svelte'
  import EntryList from './EntryList.svelte'

  let {
    open = false,
    eventCode = '',
    eventId = null as number | null,
    view = 'form' as 'form' | 'list',
    payee = 'SPWS',
    iban = '',
    onclose,
    onviewlist,
  }: {
    open?: boolean
    eventCode?: string
    eventId?: number | null
    view?: 'form' | 'list'
    payee?: string
    iban?: string
    onclose?: () => void
    onviewlist?: () => void
  } = $props()
</script>

<style>
  /* Same overlay/backdrop-close interaction pattern as DrilldownModal — pops
     the registration flow over the calendar; closing (backdrop click or the
     embedded component's own ×) returns to the calendar, no navigation. */
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    padding: 40px 16px;
    z-index: 1000;
    overflow-y: auto;
  }

  @media (max-width: 600px) {
    .modal-overlay {
      padding: 0;
    }
    /* Full-bleed on phone screens — reaches into RegistrationForm/EntryList's
       own scoped card classes (their internal styling otherwise matches the
       mockups already; only the modal-embed page-shell needs to adapt). */
    .modal-overlay :global(.reg-card),
    .modal-overlay :global(.el-card) {
      box-sizing: border-box;
      border-radius: 0;
      max-width: 100vw;
      width: 100vw;
      min-height: 100vh;
      margin: 0;
    }
  }
</style>
