<div class="reg-card">
  <div class="reg-top">
    <div class="reg-title-block">
      {#if event}<div class="reg-evt-name">{event.txt_name}</div>{/if}
    </div>
    <div class="reg-top-actions">
      <LangToggle />
      {#if onclose}
        <button class="reg-close" onclick={onclose} aria-label="Close">&times;</button>
      {/if}
    </div>
  </div>

  {#if step === 'loading'}
    <p class="reg-muted">…</p>
  {:else if step === 'not_found'}
    <p class="reg-muted">{t('reg_event_not_found')}</p>
  {:else if step === 'external'}
    <p class="reg-muted">{t('reg_external_registration_note')}</p>
    {#if event?.url_registration}
      <a class="reg-btn" href={event.url_registration} target="_blank" rel="noopener">{t('reg_external_registration_link')} &rarr;</a>
    {/if}
  {:else if step === 'expired'}
    <p class="reg-muted">{t('reg_status_expired')}</p>
  {:else if step === 'closed'}
    <p class="reg-muted">{t('reg_status_closed')}</p>
    <p class="reg-muted">{t('reg_status_closed_note')}</p>
    {#if onviewlist}
      <button class="reg-btn" onclick={onviewlist}>{t('reg_entry_list_link')} &rarr;</button>
    {:else}
      <a class="reg-btn" href={entryListHref}>{t('reg_entry_list_link')} &rarr;</a>
    {/if}
  {:else if step === 'identity'}
    <p class="reg-stepline">{t('reg_step1_title')}</p>

    <div class="reg-grid2">
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_surname')}</span>
        <input name="surname" value={surname} oninput={onSurnameInput} style="text-transform:uppercase" />
      </label>
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_first_name')}</span>
        <input name="firstName" bind:value={firstName} />
      </label>
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_gender')}</span>
        <select bind:value={gender}>
          <option value="M">{t('reg_gender_m')}</option>
          <option value="F">{t('reg_gender_f')}</option>
        </select>
      </label>
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_birth_year')}</span>
        <input name="birthYear" type="number" value={birthYear ?? ''} oninput={onBirthYearInput} />
      </label>
    </div>

    <p class="reg-lbl reg-weapon-heading">{t('reg_weapon_choose')}</p>
    <div class="reg-grid3">
      {#each (['EPEE', 'FOIL', 'SABRE'] as const) as w}
        <label class="reg-wrow">
          <input type="checkbox" value={w} checked={weapons.includes(w)} onchange={() => toggleWeapon(w)} />
          <span>{weaponLabel(w)} {#if weapons.includes(w) && vcat}<span class="reg-wcat">&middot; {vcat}</span>{/if}</span>
        </label>
      {/each}
    </div>

    <div class="reg-catrow">
      <span class="reg-lbl">{t('reg_category_computed')}</span>
      <span class="reg-chip">{vcat ?? '—'}</span>
    </div>

    <label class="reg-fld">
      <span class="reg-lbl">{t('reg_club_optional')}</span>
      <input bind:value={club} placeholder={t('reg_club_placeholder')} />
    </label>

    <div class="reg-feebar">
      <div>
        <span class="reg-lbl">{t('reg_entry_fee')}</span><br />
        <span class="reg-muted">{t('reg_weapons_count', { n: weapons.length })}</span>
      </div>
      <div class="reg-feeval">{fee != null ? `${fee} PLN` : '—'}</div>
    </div>

    <p class="reg-muted reg-by-note">{t('reg_by_visibility_note')}</p>

    <div class="reg-end">
      <button class="reg-btn reg-continue" disabled={!canContinue} onclick={submitIdentity}>{t('reg_continue')}</button>
    </div>
  {:else if step === 'verify'}
    <p class="reg-stepline">{t('reg_verify_step_label')}</p>
    <div class="reg-notice">{t('reg_verify_notice')}</div>
    <p class="reg-muted">{t('reg_verify_coming_soon')}</p>
  {:else if step === 'rodo'}
    <p class="reg-rodo-heading">{t('reg_rodo_title')}</p>
    <p class="reg-stepline">{t('reg_rodo_controller')}</p>
    <div class="reg-panel">
      <p class="reg-panel-title">{t('reg_rodo_basis_title')}</p>
      <div class="reg-brow"><span>{t('reg_rodo_basis_identity')}</span><span class="reg-basis">{t('reg_rodo_basis_identity_law')}</span></div>
      <div class="reg-brow"><span>{t('reg_rodo_basis_weapon')}</span><span class="reg-basis">{t('reg_rodo_basis_weapon_law')}</span></div>
      <div class="reg-brow"><span>{t('reg_rodo_basis_email')}</span><span class="reg-basis">{t('reg_rodo_basis_email_law')}</span></div>
      <div class="reg-brow"><span>{t('reg_rodo_basis_club')}</span><span class="reg-basis">{t('reg_rodo_basis_club_law')}</span></div>
    </div>
    <p class="reg-muted">{t('reg_rodo_retention_note')}</p>
    <p class="reg-muted">{t('reg_rodo_by_note')}</p>
    <p class="reg-lbl">{t('reg_rodo_rights_title')}</p>
    <div class="reg-rights">
      <span class="reg-rchip">{t('reg_rodo_right_access')}</span>
      <span class="reg-rchip">{t('reg_rodo_right_rectify')}</span>
      <span class="reg-rchip">{t('reg_rodo_right_erase')}</span>
      <span class="reg-rchip">{t('reg_rodo_right_object')}</span>
    </div>
    <label class="reg-ack">
      <input
        type="checkbox"
        class="reg-rodo-checkbox"
        class:reg-invalid={consentInvalid}
        bind:checked={consentChecked}
        onchange={() => {
          if (consentChecked) consentInvalid = false
        }}
      />
      <span>{t('reg_rodo_accept_label')}</span>
    </label>
    <p class="reg-muted">{t('reg_rodo_legitimate_note')}</p>
    <div class="reg-end">
      <button class="reg-btn reg-rodo-accept" class:reg-btn-inactive={!consentChecked} onclick={acceptRodo}>{t('reg_rodo_accept_button')}</button>
    </div>
  {:else if step === 'payment'}
    <p class="reg-ok">{t('reg_payment_confirmed')}</p>
    <div class="reg-panel">
      <div class="reg-phead">
        <span class="reg-panel-title">{t('reg_payment_details_title')}</span>
        <button class="reg-cp" onclick={copyAll}>{copiedField === 'all' ? t('reg_copied') : t('reg_copy_all')}</button>
      </div>
      <div class="reg-prow"><span class="reg-pk">{t('reg_payee_label')}</span><span class="reg-pv">{payee}</span><button class="reg-cp" onclick={() => copy('payee', payee)}>{copiedField === 'payee' ? t('reg_copied') : '⧉'}</button></div>
      <div class="reg-prow"><span class="reg-pk">{t('reg_iban_label')}</span><span class="reg-pv">{iban}</span><button class="reg-cp" onclick={() => copy('iban', iban)}>{copiedField === 'iban' ? t('reg_copied') : '⧉'}</button></div>
      <div class="reg-prow"><span class="reg-pk">{t('reg_title_label')}</span><span class="reg-pv">{title}</span><button class="reg-cp" onclick={() => copy('title', title)}>{copiedField === 'title' ? t('reg_copied') : '⧉'}</button></div>
      <div class="reg-prow"><span class="reg-pk">{t('reg_amount_label')}</span><span class="reg-pv">{fee != null ? `${fee} PLN` : '—'}</span><button class="reg-cp" onclick={() => copy('amount', `${fee} PLN`)}>{copiedField === 'amount' ? t('reg_copied') : '⧉'}</button></div>
    </div>
    <p class="reg-muted">{t('reg_payment_deadline_note')}</p>
    {#if onviewlist}
      <button class="reg-entry-list-link" onclick={onviewlist}>{t('reg_entry_list_link')} &rarr;</button>
    {:else}
      <a class="reg-entry-list-link" href={entryListHref}>{t('reg_entry_list_link')} &rarr;</a>
    {/if}
  {/if}
</div>

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import LangToggle from './LangToggle.svelte'
  import { fetchEventForRegistration, matchRegistrationFencer, createRegistration } from '../lib/api'
  import { birthYearToVcat } from '../lib/birthYearEstimate'
  import type { RegistrationEventInfo, GenderType, WeaponType } from '../lib/types'

  const CONSENT_VERSION = 'v1.0'

  let {
    eventCode = '',
    payee = 'SPWS',
    iban = '',
    onclose,
    onviewlist,
  }: {
    eventCode?: string
    payee?: string
    iban?: string
    // Modal-embed (RegistrationModal, opened from CalendarView) — when
    // provided, renders a close (×) affordance and routes the entry-list
    // link through a view-switch callback instead of a page navigation.
    // Undefined on the standalone register.html page (nothing to close to).
    onclose?: () => void
    onviewlist?: () => void
  } = $props()

  type Step = 'loading' | 'not_found' | 'external' | 'expired' | 'closed' | 'identity' | 'verify' | 'rodo' | 'payment'
  let step = $state<Step>('loading')
  let event = $state<RegistrationEventInfo | null>(null)

  let surname = $state('')
  let firstName = $state('')
  let gender = $state<GenderType>('M')
  let birthYear = $state<number | null>(null)
  let weapons = $state<WeaponType[]>([])
  let club = $state('')
  let fencerId = $state<number | null>(null)
  let consentChecked = $state(false)
  let consentInvalid = $state(false)
  let copiedField = $state<string | null>(null)

  const seasonEndYear = $derived.by(() => {
    if (!event) return null
    const m = event.txt_season_code.match(/(\d{4})$/)
    return m ? parseInt(m[1], 10) : null
  })
  const vcat = $derived(birthYearToVcat(birthYear, seasonEndYear))
  const fee = $derived.by(() => {
    if (!event || weapons.length === 0) return null
    if (weapons.length === 1) return event.num_entry_fee
    if (weapons.length === 2) return event.num_entry_fee_2w
    return event.num_entry_fee_3w
  })
  const canContinue = $derived(surname.trim() !== '' && firstName.trim() !== '' && birthYear != null && weapons.length > 0)
  const title = $derived(event ? `${event.txt_code} ${surname.toUpperCase()} ${firstName.toUpperCase()}` : '')
  const entryListHref = $derived(`?event=${encodeURIComponent(eventCode)}&view=list`)

  $effect(() => {
    const code = eventCode
    if (!code) {
      step = 'not_found'
      return
    }
    fetchEventForRegistration(code).then((ev) => {
      event = ev
      if (!ev) {
        step = 'not_found'
        return
      }
      if (!ev.bool_use_spws_registration) {
        step = 'external'
        return
      }
      const today = new Date().toISOString().slice(0, 10)
      if (ev.dt_end && today > ev.dt_end) {
        step = 'expired'
        return
      }
      const cutoff = ev.dt_registration_deadline ?? ev.dt_start
      if (cutoff && today > cutoff) {
        step = 'closed'
        return
      }
      step = 'identity'
    }).catch(() => {
      step = 'not_found'
    })
  })

  function weaponLabel(w: WeaponType): string {
    if (w === 'EPEE') return t('reg_weapon_epee')
    if (w === 'FOIL') return t('reg_weapon_foil')
    return t('reg_weapon_sabre')
  }

  function toggleWeapon(w: WeaponType) {
    weapons = weapons.includes(w) ? weapons.filter((x) => x !== w) : [...weapons, w]
  }

  function onSurnameInput(e: Event) {
    surname = (e.target as HTMLInputElement).value.toUpperCase()
  }

  function onBirthYearInput(e: Event) {
    const v = (e.target as HTMLInputElement).value
    birthYear = v === '' ? null : parseInt(v, 10)
  }

  async function submitIdentity() {
    if (!canContinue) return
    const id = await matchRegistrationFencer(surname, firstName, birthYear as number)
    fencerId = id
    step = id != null ? 'rodo' : 'verify'
  }

  async function acceptRodo() {
    if (!consentChecked) {
      consentInvalid = true
      return
    }
    if (!event) return
    await createRegistration({
      eventId: event.id_event,
      surname,
      firstName,
      gender,
      birthYear: birthYear as number,
      weapons,
      fencerId,
      consentVersion: CONSENT_VERSION,
    })
    step = 'payment'
  }

  async function copy(label: string, value: string) {
    try {
      await navigator.clipboard.writeText(value)
    } catch {
      // best-effort only; clipboard access can be denied by the browser
    }
    copiedField = label
    setTimeout(() => {
      copiedField = null
    }, 1300)
  }

  function copyAll() {
    copy('all', `${payee}\n${iban}\n${title}\n${fee != null ? `${fee} PLN` : ''}`)
  }
</script>

<style>
  .reg-card {
    max-width: 640px;
    margin: 0 auto;
    background: #16213e;
    border: 1px solid #0f3460;
    border-radius: 12px;
    padding: 22px;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
  .reg-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 18px;
  }
  .reg-top-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .reg-close {
    background: none;
    border: none;
    font-size: 24px;
    line-height: 1;
    cursor: pointer;
    color: #7fbadc;
    padding: 0 2px;
  }
  .reg-close:hover {
    color: #fff;
  }
  .reg-evt-name {
    font-weight: 600;
    color: #fff;
    font-size: 1.05em;
  }
  .reg-stepline {
    color: #7fbadc;
    font-size: 0.82em;
    margin-bottom: 12px;
  }
  .reg-rodo-heading {
    font-weight: 600;
    color: #fff;
    font-size: 1em;
    margin-bottom: 4px;
  }
  .reg-fld {
    display: flex;
    flex-direction: column;
    gap: 5px;
    margin-bottom: 12px;
  }
  .reg-lbl {
    font-size: 0.8em;
    color: #7fbadc;
  }
  input, select {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #e0e0e0;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 0.92em;
    font-family: inherit;
    width: 100%;
    box-sizing: border-box;
  }
  .reg-grid2 {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 12px;
  }
  .reg-grid3 {
    display: grid;
    grid-template-columns: 1fr 1fr 1fr;
    gap: 8px;
    margin-bottom: 10px;
  }
  @media (max-width: 480px) {
    .reg-grid2, .reg-grid3 {
      grid-template-columns: 1fr;
    }
  }
  .reg-wrow {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 9px 11px;
    border: 1px solid #1a4a8a;
    border-radius: 8px;
    cursor: pointer;
  }
  .reg-wrow input {
    width: auto;
  }
  .reg-wcat {
    color: #7fd8ff;
    font-size: 0.8em;
  }
  .reg-catrow {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-bottom: 14px;
  }
  .reg-chip, .reg-rchip {
    display: inline-flex;
    align-items: center;
    gap: 6px;
    font-size: 0.82em;
    padding: 3px 10px;
    border-radius: 999px;
    background: rgba(0, 212, 255, 0.12);
    color: #7fd8ff;
  }
  .reg-feebar {
    display: flex;
    justify-content: space-between;
    align-items: center;
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 8px;
    padding: 11px 13px;
    margin-bottom: 12px;
  }
  .reg-feeval {
    font-size: 1.35em;
    font-weight: 600;
    color: #fff;
  }
  .reg-muted {
    color: #8894a8;
    font-size: 0.85em;
    line-height: 1.5;
  }
  .reg-by-note {
    margin-bottom: 16px;
  }
  .reg-end {
    display: flex;
    justify-content: flex-end;
    margin-top: 8px;
  }
  .reg-btn {
    background: #00d4ff;
    color: #0d1b2a;
    border: none;
    border-radius: 8px;
    padding: 10px 18px;
    font-weight: 600;
    cursor: pointer;
    font-size: 0.92em;
    min-height: 40px;
    text-decoration: none;
    display: inline-block;
  }
  .reg-btn:disabled {
    opacity: 0.5;
    cursor: not-allowed;
  }
  .reg-notice {
    border-radius: 8px;
    padding: 12px 14px;
    font-size: 0.9em;
    line-height: 1.55;
    background: rgba(240, 159, 39, 0.12);
    color: #f0b967;
    margin-bottom: 18px;
  }
  .reg-panel {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 10px;
    padding: 12px 14px;
    margin-bottom: 14px;
  }
  .reg-panel-title {
    font-weight: 600;
    font-size: 0.92em;
    color: #fff;
  }
  .reg-brow {
    display: flex;
    justify-content: space-between;
    gap: 12px;
    padding: 8px 0;
    border-top: 1px solid #1a2c4a;
    font-size: 0.85em;
  }
  .reg-basis {
    color: #7fd8ff;
    font-size: 0.82em;
    white-space: nowrap;
  }
  .reg-rights {
    display: flex;
    gap: 8px;
    flex-wrap: wrap;
    margin-bottom: 16px;
  }
  .reg-ack {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    margin-bottom: 8px;
    cursor: pointer;
  }
  .reg-ack span {
    min-width: 0;
    flex: 1;
  }
  .reg-rodo-checkbox {
    appearance: none;
    -webkit-appearance: none;
    width: 20px;
    height: 20px;
    flex: none;
    margin: 1px 0 0;
    border: 2px solid #1a4a8a;
    border-radius: 5px;
    background: #0d1b2a;
    cursor: pointer;
    position: relative;
  }
  .reg-rodo-checkbox:checked {
    background: #00d4ff;
    border-color: #00d4ff;
  }
  .reg-rodo-checkbox:checked::after {
    content: '';
    position: absolute;
    left: 6px;
    top: 2px;
    width: 5px;
    height: 10px;
    border: solid #0d1b2a;
    border-width: 0 2px 2px 0;
    transform: rotate(45deg);
  }
  .reg-rodo-checkbox.reg-invalid {
    background: rgba(255, 92, 92, 0.45);
    border-color: #ff5c5c;
  }
  .reg-btn-inactive {
    opacity: 0.5;
  }
  .reg-ok {
    color: #4ade80;
    font-size: 0.95em;
    margin-bottom: 14px;
  }
  .reg-phead {
    display: flex;
    justify-content: space-between;
    align-items: center;
    padding: 10px 0 4px;
  }
  .reg-prow {
    display: flex;
    align-items: center;
    gap: 10px;
    padding: 9px 0;
    border-top: 1px solid #1a2c4a;
    flex-wrap: wrap;
  }
  .reg-pk {
    flex: none;
    width: 90px;
    color: #7fbadc;
    font-size: 0.8em;
  }
  .reg-pv {
    flex: 1;
    font-family: 'SF Mono', Menlo, Consolas, monospace;
    font-size: 0.85em;
    word-break: break-all;
    color: #e6edf5;
    min-width: 0;
  }
  .reg-cp {
    flex: none;
    font-size: 0.78em;
    padding: 6px 10px;
    border: 1px solid #1a4a8a;
    border-radius: 8px;
    background: #16213e;
    color: #9fc4dc;
    cursor: pointer;
    min-height: 36px;
  }
  .reg-entry-list-link {
    display: inline-block;
    margin-top: 8px;
    color: #00d4ff;
    text-decoration: none;
    font-size: 0.9em;
    /* button-variant reset (onviewlist/modal-embed) — visually identical to
       the anchor used on the standalone page */
    background: none;
    border: none;
    font-family: inherit;
    cursor: pointer;
    padding: 0;
  }
</style>
