<!--
  FR-170 — a signed-in administrator edits an entry (plan registration-form-
  names-year-country rev 10, release 4; D2 A, D5 A). Opened only from the
  signed-in entry list (EntryList.svelte), which closes it when the
  administrator signs out. Every declared field can change; a linked entry's
  name cannot, because the roster's name is what the database keeps for it.
  The database's own rules decide the rest (name form, year range, country
  code); a refused save keeps the dialog open with the reason. A linked
  entry's changed birth year, gender and country reach the roster in the same
  save (22 Nov addition, R1–R3 A); the dialog shows the roster's new year and
  a category change before „Zapisz”.
-->
<div class="ee-backdrop" role="presentation" onclick={cancel}>
  <div
    class="ee"
    role="dialog"
    aria-modal="true"
    aria-labelledby="ee-title"
    tabindex="-1"
    bind:this={dialogEl}
    onclick={(e) => e.stopPropagation()}
    onkeydown={(e) => {
      if (e.key === 'Escape') cancel()
    }}>
    <p id="ee-title" class="ee-title">{t('reg_admin_edit_title')}</p>

    <div class="reg-grid2">
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_surname')}</span>
        <input name="surname" autocomplete="off" disabled={linked} bind:value={surname} />
      </label>
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_first_name')}</span>
        <input name="firstName" autocomplete="off" disabled={linked} bind:value={firstName} />
      </label>
    </div>
    {#if linked}
      <p class="ee-locked">{t('reg_admin_edit_locked')}</p>
    {/if}

    <div class="reg-grid2">
      <label class="reg-fld">
        <span class="reg-lbl">{t('reg_gender')}</span>
        <select name="gender" bind:value={gender}>
          <option value="M">{t('reg_gender_m')}</option>
          <option value="F">{t('reg_gender_f')}</option>
        </select>
      </label>
      <div class="reg-fld">
        <YearPicker bind:year={birthYear} range={yearRange} />
        <!-- D5: the roster's year beside the declared one, ≠ when they differ.
             A changed year that the save will copy to the roster shows the
             roster's old and new year, and a category change (RFADM.24). -->
        {#if rosterYearChange}
          <span class="ee-roster-year">{t('reg_admin_edit_roster_year_change', { from: detail.roster_birth_year ?? '—', to: birthYear ?? '' })}</span>
          {#if rosterCategoryChange}
            <span class="ee-roster-cat">{t('reg_admin_edit_roster_category', rosterCategoryChange)}</span>
          {/if}
        {:else if linked && detail.roster_birth_year != null}
          <span class="ee-roster-year">{t('reg_admin_edit_roster_year', { year: detail.roster_birth_year })}{#if detail.roster_birth_year !== birthYear}{' '}<span class="ee-differs" title={t('reg_admin_edit_year_differs')}>≠</span>{/if}</span>
        {/if}
      </div>
    </div>

    <p class="reg-lbl ee-wlabel">{t('reg_admin_edit_weapons')}</p>
    <div class="reg-grid3">
      {#each WEAPONS as w (w)}
        <label class="reg-wrow">
          <input type="checkbox" value={w} checked={weapons.includes(w)} onchange={() => toggleWeapon(w)} />
          <span>{t(WEAPON_LABEL[w])}</span>
        </label>
      {/each}
    </div>

    <label class="reg-fld">
      <span class="reg-lbl">{t('reg_club_optional')}</span>
      <input name="club" autocomplete="off" bind:value={club} />
    </label>

    <div class="reg-fld">
      <CountryPicker bind:code={country} />
    </div>

    {#if error}<p class="ee-error" role="alert">{error}</p>{/if}

    <div class="ee-acts">
      <button type="button" class="ee-save" disabled={saving || !valid} onclick={save}>{t('reg_admin_edit_save')}</button>
      <button type="button" class="ee-cancel" disabled={saving} onclick={cancel}>{t('reg_admin_edit_cancel')}</button>
    </div>
  </div>
</div>

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import { updateRegistrationAsAdmin } from '../lib/api'
  import { birthYearRange, inRange, isYearRefusal } from '../lib/birthYearRange'
  import { birthYearToVcat } from '../lib/birthYearEstimate'
  import YearPicker from './YearPicker.svelte'
  import CountryPicker from './CountryPicker.svelte'
  import type { AdminEntryDetail, GenderType, RegistrationEntry, WeaponType } from '../lib/types'

  let {
    entry,
    detail,
    seasonEndYear,
    onsaved,
    oncancel,
  }: {
    entry: RegistrationEntry
    detail: AdminEntryDetail
    // The event's season's later year: the year range is the form's (FR-168).
    seasonEndYear: number | null
    onsaved: () => void
    oncancel: () => void
  } = $props()

  const WEAPONS: WeaponType[] = ['EPEE', 'FOIL', 'SABRE']
  const WEAPON_LABEL: Record<WeaponType, string> = {
    EPEE: 'reg_weapon_epee',
    FOIL: 'reg_weapon_foil',
    SABRE: 'reg_weapon_sabre',
  }

  // The dialog edits its own copy; nothing reaches the list until the
  // database confirms the save. The entry is fixed for the dialog's lifetime
  // (the list opens a new dialog per entry), so reading it once is intended.
  // svelte-ignore state_referenced_locally
  const linked = detail.id_fencer != null
  // svelte-ignore state_referenced_locally
  let surname = $state(entry.txt_surname)
  // svelte-ignore state_referenced_locally
  let firstName = $state(entry.txt_first_name)
  // svelte-ignore state_referenced_locally
  let gender = $state<GenderType>(entry.enum_gender)
  // svelte-ignore state_referenced_locally
  let birthYear = $state<number | null>(detail.int_birth_year)
  // svelte-ignore state_referenced_locally
  let weapons = $state<WeaponType[]>([...entry.arr_weapons])
  // svelte-ignore state_referenced_locally
  let club = $state(detail.txt_club ?? '')
  // svelte-ignore state_referenced_locally
  let country = $state(detail.txt_country ?? '')

  let saving = $state(false)
  let error = $state('')
  let dialogEl = $state<HTMLElement | null>(null)

  const yearRange = $derived(birthYearRange(seasonEndYear))
  // The save copies a linked entry's changed year to the roster
  // (fn_update_registration_as_admin): say so before „Zapisz”.
  const rosterYearChange = $derived(
    linked && birthYear != null && birthYear !== detail.int_birth_year && birthYear !== detail.roster_birth_year,
  )
  const rosterCategoryChange = $derived.by(() => {
    if (!rosterYearChange) return null
    const from = birthYearToVcat(detail.roster_birth_year, seasonEndYear)
    const to = birthYearToVcat(birthYear, seasonEndYear)
    return from && to && from !== to ? { from, to } : null
  })
  const valid = $derived(
    surname.trim() !== '' && firstName.trim() !== '' && weapons.length > 0 && inRange(birthYear, yearRange),
  )

  // Focus moves into the dialog as it opens, so Escape lands on it (the
  // calendar's modal stops key events from reaching the window).
  $effect(() => {
    dialogEl?.focus()
  })

  function toggleWeapon(w: WeaponType) {
    weapons = weapons.includes(w) ? weapons.filter((x) => x !== w) : WEAPONS.filter((x) => x === w || weapons.includes(x))
  }

  function cancel() {
    if (saving) return
    oncancel()
  }

  function reason(e: unknown): string {
    if (isYearRefusal(e)) return t('reg_year_out_of_range', { min: yearRange.min, max: yearRange.max })
    if ((e as { code?: unknown } | null)?.code === '23505') return t('reg_admin_edit_duplicate')
    return t('reg_admin_edit_failed')
  }

  async function save() {
    if (saving || !valid || birthYear == null) return
    saving = true
    error = ''
    try {
      await updateRegistrationAsAdmin(entry.id_registration, {
        ...(linked ? {} : { surname, firstName }),
        gender,
        birthYear,
        weapons,
        club,
        country,
      })
      onsaved()
    } catch (e) {
      error = reason(e)
    } finally {
      saving = false
    }
  }
</script>

<style>
  .ee-backdrop {
    position: fixed;
    inset: 0;
    z-index: 1100;
    background: rgba(0, 0, 0, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
  }
  .ee {
    width: 100%;
    max-width: 460px;
    max-height: calc(100vh - 32px);
    overflow-y: auto;
    box-sizing: border-box;
    background: #0f1f35;
    border: 1px solid #1a4a8a;
    border-radius: 10px;
    padding: 16px;
    color: #e0e0e0;
    font-size: 0.92em;
    line-height: 1.4;
    text-align: left;
  }
  .ee:focus {
    outline: none;
  }
  .ee-title {
    font-weight: 600;
    color: #fff;
    font-size: 1.05em;
    margin: 0 0 12px;
  }
  .ee-locked {
    margin: -4px 0 12px;
    font-size: 0.8em;
    color: #8894a8;
  }
  .ee-roster-year {
    font-size: 0.8em;
    color: #8894a8;
  }
  .ee-roster-cat {
    font-size: 0.8em;
    color: #f5b942;
  }
  .ee-differs {
    color: #f5b942;
    font-weight: 700;
  }
  .ee-wlabel {
    margin: 0 0 6px;
  }
  .ee-error {
    color: #ffb4b4;
    font-weight: 600;
    margin: 0 0 6px;
  }
  .ee-acts {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-top: 14px;
  }
  .ee-save,
  .ee-cancel {
    border-radius: 8px;
    padding: 9px 16px;
    min-height: 40px;
    font-weight: 600;
    font-size: 0.92em;
    font-family: inherit;
    cursor: pointer;
  }
  .ee-save {
    background: #1a6fd1;
    color: #fff;
    border: none;
  }
  .ee-cancel {
    background: transparent;
    color: #9fc4dc;
    border: 1px solid #1a4a8a;
  }
  .ee-save:disabled,
  .ee-cancel:disabled {
    opacity: 0.6;
    cursor: default;
  }

  /* The form's own rules for a label, a box and the weapon rows
     (RegistrationForm.svelte): Svelte scopes styles per component, so the
     dialog carries them itself, as YearPicker and CountryPicker do. */
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
  input,
  select {
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
  input:disabled {
    color: #8894a8;
    border-color: #1a2c4a;
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
    .reg-grid2 {
      grid-template-columns: 1fr;
      gap: 0;
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
</style>
