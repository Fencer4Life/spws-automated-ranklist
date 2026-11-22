<div class="el-card">
  {#if onback}
    <div class="el-backrow">
      <button class="el-back" onclick={onback}>&larr; {backLabel || t('reg_back')}</button>
    </div>
  {/if}
  <div class="el-top">
    <span class="el-title">{t('reg_entry_list_title')}</span>
    <div class="el-top-actions">
      <LangToggle />
      {#if onclose}
        <button class="el-close" onclick={onclose} aria-label="Close">&times;</button>
      {/if}
    </div>
  </div>

  <!-- FR-165: while anything narrows the list, each tile reads "selection z
       total"; the selection is exactly the rows listed below. -->
  <div class="el-metrics" class:el-narrowed={isNarrowed} aria-live="polite">
    {#each TILES as tile (tile.label)}
      <div class="el-metric" class:el-dim={tile.weapon !== null && weaponFilter !== '' && tile.weapon !== weaponFilter}>
        <div class="el-k">{t(tile.label)}</div>
        <div class="el-v">{count(isNarrowed ? filteredRows : rows, tile.weapon)}{#if isNarrowed}{' '}<span class="el-of">{t('reg_sel_of_total', { total: count(rows, tile.weapon) })}</span>{/if}</div>
      </div>
    {/each}
  </div>

  <div class="el-filters">
    <div class="el-searchwrap">
      <input name="search" class="el-search" class:el-active={search.trim() !== ''} placeholder={t('reg_search_surname')} bind:value={search} />
      <!-- Shown for any text, spaces included: spaces do not narrow the list,
           but the × still lets the visitor empty the box in one tap (S2). -->
      {#if search !== ''}
        <button type="button" class="el-search-clear" aria-label={t('reg_search_clear')} onclick={() => (search = '')}>&times;</button>
      {/if}
    </div>
    <div class="el-fgroup" class:el-four={hasCountry}>
      <label class="el-flabel">
        <span>{t('weapon')}</span>
        <select name="weaponFilter" class:el-active={weaponFilter !== ''} bind:value={weaponFilter}>
          <option value="">--</option>
          <option value="EPEE">{t('reg_weapon_epee')}</option>
          <option value="FOIL">{t('reg_weapon_foil')}</option>
          <option value="SABRE">{t('reg_weapon_sabre')}</option>
        </select>
      </label>
      <label class="el-flabel">
        <span>{t('category')}</span>
        <select name="categoryFilter" class:el-active={categoryFilter !== ''} bind:value={categoryFilter}>
          <option value="">--</option>
          <option value="V0">V0 (30+)</option>
          <option value="V1">V1 (40+)</option>
          <option value="V2">V2 (50+)</option>
          <option value="V3">V3 (60+)</option>
          <option value="V4">V4 (70+)</option>
        </select>
      </label>
      <label class="el-flabel">
        <span>{t('gender')}</span>
        <select name="genderFilter" class:el-active={genderFilter !== ''} bind:value={genderFilter}>
          <option value="">--</option>
          <option value="F">{t('reg_filter_women')}</option>
          <option value="M">{t('reg_filter_men')}</option>
        </select>
      </label>
      <!-- FR-169: offered only when an entry has a country; codes alone, the
           letters on each fencer's jacket, for the countries present. -->
      {#if hasCountry}
        <label class="el-flabel">
          <span>{t('reg_filter_country')}</span>
          <select name="countryFilter" class:el-active={countryFilter !== ''} bind:value={countryFilter}>
            <option value="">--</option>
            {#each presentCountries as c (c)}
              <option value={c}>{c}</option>
            {/each}
          </select>
        </label>
      {/if}
    </div>
    {#if isNarrowed}
      <button type="button" class="el-clear-all" onclick={clearAll}>{t('reg_clear_filters')}</button>
    {/if}
  </div>

  {#if removedName}
    <p class="el-remove-done" role="status" tabindex="-1" bind:this={doneEl}>{t('reg_remove_done', { name: removedName })}</p>
  {/if}
  {#if savedName}
    <p class="el-remove-done el-edit-done" role="status" tabindex="-1" bind:this={savedEl}>{t('reg_admin_edit_done', { name: savedName })}</p>
  {/if}

  {#if filteredRows.length > 0}
    <table>
      <thead>
        <tr>
          <th>{t('reg_col_name')}</th>
          <th class="el-narrow">{t('reg_col_category')}</th>
          <th>{t('reg_col_weapon')}</th>
          {#if hasCountry}<th class="el-flag"></th>{/if}
          {#if canRemove}<th class="el-act"></th>{/if}
        </tr>
      </thead>
      <tbody>
        {#each filteredRows as row (row.id_registration)}
          <tr class:el-adminrow={canRemove}>
            <td class="el-name">{row.txt_surname} {row.txt_first_name}</td>
            <td>
              {#if row.enum_age_category}<span class="el-cat">{row.enum_age_category}</span>{/if}
            </td>
            <td>
              {#each row.arr_weapons as w}
                <span class="el-wpn el-w-{weaponCode(w)}">{weaponCode(w)}</span>
              {/each}
            </td>
            {#if hasCountry}
              <!-- FR-169: the flag alone, labelled with the country's name; a code
                   with no drawn flag shows its letters (D1); no country, nothing. -->
              <td class="el-flag">
                {#if row.txt_country && flagIso(row.txt_country)}
                  <CountryFlag code={flagIso(row.txt_country)} label={countryName(row.txt_country, lang)} />
                {:else if row.txt_country}
                  <span class="el-flagcode" role="img" aria-label={countryName(row.txt_country, lang)} title={countryName(row.txt_country, lang)}>{row.txt_country}</span>
                {/if}
              </td>
            {/if}
            {#if canRemove}
              <td class="el-act">
                <!-- FR-170 (D5): ≠ where the declared year differs from the
                     roster's; „Edytuj” once the entry's details are read. -->
                {#if yearDiffers(row)}
                  <span class="el-yeardiff" role="img" aria-label={t('reg_admin_edit_year_differs')} title={t('reg_admin_edit_year_differs')}>≠</span>
                {/if}
                <button
                  type="button"
                  class="el-edit"
                  disabled={!details.has(row.id_registration)}
                  aria-label={t('reg_admin_edit_row', { name: fullName(row) })}
                  onclick={() => askEdit(row)}>{t('reg_admin_edit')}</button>
                <button
                  type="button"
                  class="el-remove"
                  aria-label={t('reg_remove_row', { name: fullName(row) })}
                  onclick={() => askRemove(row)}>{t('reg_remove')}</button>
              </td>
            {/if}
          </tr>
        {/each}
      </tbody>
    </table>
  {:else}
    <p class="el-empty">{t('reg_no_entries')}</p>
  {/if}

  <p class="el-legend">{t('reg_weapon_legend')}</p>

  <!-- FR-166: the administrator's confirmation. It takes focus when it opens
       and handles Escape itself, because the calendar's modal stops key events
       from reaching the window. Shown only while removal is allowed, so
       signing out also closes a confirmation left open. -->
  <!-- FR-170: the administrator's edit. Shown only while removal is allowed,
       so signing out also closes a dialog left open. -->
  {#if editing && canRemove && details.get(editing.id_registration)}
    <EntryEdit
      entry={editing}
      detail={details.get(editing.id_registration)!}
      {seasonEndYear}
      onsaved={edited}
      oncancel={() => (editing = null)} />
  {/if}

  {#if pending && canRemove}
    <div class="el-confirm-backdrop" role="presentation" onclick={cancelRemove}>
      <div
        class="el-confirm"
        role="alertdialog"
        aria-modal="true"
        aria-labelledby="el-confirm-title"
        tabindex="-1"
        bind:this={confirmEl}
        onclick={(e) => e.stopPropagation()}
        onkeydown={(e) => {
          if (e.key === 'Escape') cancelRemove()
        }}>
        <p id="el-confirm-title" class="el-confirm-title">{t('reg_remove_title')}</p>
        <p class="el-confirm-who">{fullName(pending)} · {weaponsText(pending)}{#if pending.enum_age_category}{' · '}{pending.enum_age_category}{/if}</p>
        {#if eventName}<p class="el-confirm-event">{eventName}</p>{/if}
        <p class="el-confirm-note">{removeNote(pending)}</p>
        {#if removeFailed}<p class="el-remove-failed" role="alert">{t('reg_remove_failed')}</p>{/if}
        <div class="el-confirm-acts">
          <button type="button" class="el-remove-confirm" disabled={removing} onclick={confirmRemove}>{t('reg_remove_confirm')}</button>
          <button type="button" class="el-remove-cancel" disabled={removing} onclick={cancelRemove}>{t('reg_remove_cancel')}</button>
        </div>
      </div>
    </div>
  {/if}
</div>

<script lang="ts">
  import { tick } from 'svelte'
  import { getLocale, t } from '../lib/locale.svelte'
  import LangToggle from './LangToggle.svelte'
  import CountryFlag from './CountryFlag.svelte'
  import { countryName, flagIso } from '../lib/fencingCountries'
  import EntryEdit from './EntryEdit.svelte'
  import {
    fetchEntryList,
    deleteRegistration,
    fetchAdminEntryDetails,
    fetchEventSeasonEndYear,
  } from '../lib/api'
  import { foldName } from '../lib/foldName'
  import { surnameWithoutTitle } from '../lib/registrationName'
  import type { AdminEntryDetail, RegistrationEntry, WeaponType, GenderType, AgeCategory } from '../lib/types'

  let {
    eventId,
    onclose,
    onback,
    backLabel = '',
    canRemove = false,
    eventName = '',
    registrationOpen = true,
  }: {
    eventId: number
    // FR-166 — true only from the admin application's calendar while an
    // administrator is signed in (App → CalendarView → RegistrationModal).
    // The public custom element never passes it. Without it the list renders
    // exactly as for a visitor.
    canRemove?: boolean
    // Named in the removal's confirmation.
    eventName?: string
    // Whether the fencer could still register again: decides the
    // confirmation's second sentence (FR-166, Q1 of the plan).
    registrationOpen?: boolean
    // Modal-embed (RegistrationModal, opened from CalendarView) — when
    // provided, renders a close (×) affordance. Undefined on the standalone
    // register.html page (nothing to close to).
    onclose?: () => void
    // In-flow (RegistrationForm's `list` step) — when provided, renders a back
    // affordance. Undefined for a cold arrival: a shared ?view=list link, or
    // the roster opened straight from a calendar card, never passed through
    // the form, so there is nothing to go back to. Same conditional pattern as
    // onclose above.
    onback?: () => void
    // The caller names the destination, because it differs: the payment step
    // has the transfer details worth returning to, the closed step does not.
    // Empty falls back to a plain "Back".
    backLabel?: string
  } = $props()

  let rows = $state<RegistrationEntry[]>([])
  let search = $state('')
  let weaponFilter = $state<WeaponType | ''>('')
  let categoryFilter = $state<AgeCategory | ''>('')
  let genderFilter = $state<GenderType | ''>('')
  let countryFilter = $state('')
  const lang = $derived(getLocale() === 'en' ? 'en' : 'pl')

  // FR-169: the flag column and the „Kraj” filter appear only when an entry
  // has a country, so a list without any looks exactly as before.
  const hasCountry = $derived(rows.some((r) => !!r.txt_country))
  const presentCountries = $derived([...new Set(rows.map((r) => r.txt_country).filter((c): c is string => !!c))].sort())

  // Polish collation, fixed regardless of the PL/EN toggle: the surnames are
  // Polish whatever language the labels are in, and tying the order to the
  // toggle would visibly reshuffle the roster when a visitor switches
  // language. A naive comparison would be worse than wrong on one rung — it
  // compares UTF-16 code units, so Ć, Ł and Ż all sort after Z. Built once at
  // module scope because constructing a collator is the expensive part;
  // .compare is cheap. sensitivity 'base' keeps a lower-case surname with its
  // peers: the seeded roster is upper-case, but the self-registration form
  // takes free text from fencers.
  const byName = new Intl.Collator('pl', { sensitivity: 'base' })

  // Sorted here, once, as the roster enters the component rather than inside
  // filteredRows — so the filtering below is left exactly as it was.
  // Array.prototype.filter preserves input order, so every filtered view
  // inherits the alphabet for free. The server's own .order('id_registration')
  // in fetchEntryList is deliberately kept: Array.prototype.sort is stable, so
  // registration order survives as the final tie-break for two fencers sharing
  // both names.
  // FR-167: a title is not part of the surname — „Dr. KOVÁCS” stands under
  // K, not D. Also used to reload the list after an administrator's edit.
  async function loadRows(): Promise<void> {
    const r = await fetchEntryList(eventId)
    rows = [...r].sort(
      (a, b) =>
        byName.compare(surnameWithoutTitle(a.txt_surname), surnameWithoutTitle(b.txt_surname)) ||
        byName.compare(a.txt_first_name, b.txt_first_name),
    )
  }

  $effect(() => {
    void loadRows()
  })

  // Both sides folded (foldName): a visitor without Polish keys types "zak"
  // and finds ŻAK (FR-165, ELSEL.16).
  const filteredRows = $derived.by(() => {
    const q = foldName(search.trim())
    return rows.filter((r) => {
      if (q && !foldName(`${surnameWithoutTitle(r.txt_surname)} ${r.txt_first_name}`).includes(q)) return false
      if (weaponFilter && !r.arr_weapons.includes(weaponFilter)) return false
      if (categoryFilter && r.enum_age_category !== categoryFilter) return false
      if (genderFilter && r.enum_gender !== genderFilter) return false
      if (countryFilter && r.txt_country !== countryFilter) return false
      return true
    })
  })

  // Anything that narrows the list: search text (spaces alone do not count)
  // or any of the three filters (FR-165).
  const isNarrowed = $derived(
    search.trim() !== '' || weaponFilter !== '' || categoryFilter !== '' || genderFilter !== '' || countryFilter !== '',
  )

  // "Wyczyść filtry" (S3): the search and all three filters back to empty.
  function clearAll() {
    search = ''
    weaponFilter = ''
    categoryFilter = ''
    genderFilter = ''
    countryFilter = ''
  }

  // The tiles in their fixed order: everyone, then one per weapon.
  const TILES: { label: string; weapon: WeaponType | null }[] = [
    { label: 'reg_registered_count', weapon: null },
    { label: 'reg_weapon_epee', weapon: 'EPEE' },
    { label: 'reg_weapon_foil', weapon: 'FOIL' },
    { label: 'reg_weapon_sabre', weapon: 'SABRE' },
  ]

  // Fencers in `list`, or those of them entered in `weapon`. A fencer entered
  // in two weapons counts on both weapon tiles, as before.
  function count(list: RegistrationEntry[], weapon: WeaponType | null): number {
    return weapon ? list.filter((r) => r.arr_weapons.includes(weapon)).length : list.length
  }

  // ---- FR-166: an administrator removes an entry -------------------------

  // The entry awaiting confirmation; null while no confirmation is open.
  let pending = $state<RegistrationEntry | null>(null)
  let removing = $state(false)
  let removeFailed = $state(false)
  // The last removed fencer, for the done line.
  let removedName = $state('')
  let confirmEl = $state<HTMLElement | null>(null)
  let doneEl = $state<HTMLElement | null>(null)

  // Focus moves into the confirmation as it opens, so Escape and the keyboard
  // land on it rather than on the row underneath.
  $effect(() => {
    confirmEl?.focus()
  })

  const WEAPON_LABEL: Record<WeaponType, string> = {
    EPEE: 'reg_weapon_epee',
    FOIL: 'reg_weapon_foil',
    SABRE: 'reg_weapon_sabre',
  }

  function fullName(r: RegistrationEntry): string {
    return `${r.txt_surname} ${r.txt_first_name}`
  }

  function weaponsText(r: RegistrationEntry): string {
    return r.arr_weapons.map((w) => t(WEAPON_LABEL[w]).toLowerCase()).join(', ')
  }

  // Signed decision: after the deadline the fencer cannot register again, so
  // the second sentence says the deadline has passed instead.
  function removeNote(r: RegistrationEntry): string {
    if (!registrationOpen) return t('reg_remove_note_closed')
    return t(r.enum_gender === 'F' ? 'reg_remove_note_open_f' : 'reg_remove_note_open_m')
  }

  function askRemove(r: RegistrationEntry) {
    pending = r
    removeFailed = false
    removedName = ''
  }

  function cancelRemove() {
    if (removing) return
    pending = null
    removeFailed = false
  }

  // The row leaves the list only once the database confirms the delete; a
  // failure keeps the row and the confirmation open with the failed line.
  async function confirmRemove() {
    const r = pending
    if (!r || removing) return
    removing = true
    removeFailed = false
    try {
      await deleteRegistration(r.id_registration)
      rows = rows.filter((x) => x.id_registration !== r.id_registration)
      removedName = fullName(r)
      pending = null
      // The confirmation that held focus is gone: hand focus to the done line,
      // which also scrolls it into view after a removal far down the list.
      await tick()
      doneEl?.focus()
    } catch {
      removeFailed = true
    } finally {
      removing = false
    }
  }

  // ---- FR-170: an administrator edits an entry ----------------------------

  // What only a signed-in administrator reads: each entry's declared year,
  // club, country and link, and the roster's year (D5). Never read for a
  // visitor, whose list must stay exactly as before.
  let details = $state(new Map<number, AdminEntryDetail>())
  let seasonEndYear = $state<number | null>(null)
  let editing = $state<RegistrationEntry | null>(null)
  let savedName = $state('')
  let savedEl = $state<HTMLElement | null>(null)

  async function loadDetails(): Promise<void> {
    const d = await fetchAdminEntryDetails(eventId)
    details = new Map(d.map((x) => [x.id_registration, x]))
  }

  $effect(() => {
    if (!canRemove) {
      editing = null
      return
    }
    void loadDetails().catch(() => {})
    void fetchEventSeasonEndYear(eventId).then((y) => (seasonEndYear = y))
  })

  // D5: a linked entry whose declared year is not the roster's.
  function yearDiffers(r: RegistrationEntry): boolean {
    const d = details.get(r.id_registration)
    return !!d && d.id_fencer != null && d.roster_birth_year != null && d.roster_birth_year !== d.int_birth_year
  }

  function askEdit(r: RegistrationEntry) {
    editing = r
    savedName = ''
    removedName = ''
  }

  // The database confirmed the save: the list and the details are read again,
  // so every row shows what the database now holds (the name form, the
  // category), and the done line names the entry as stored.
  async function edited() {
    const id = editing?.id_registration
    editing = null
    await Promise.all([loadRows(), loadDetails().catch(() => {})])
    const r = rows.find((x) => x.id_registration === id)
    savedName = r ? fullName(r) : ''
    await tick()
    savedEl?.focus()
  }

  function weaponCode(w: WeaponType): string {
    if (w === 'EPEE') return 'E'
    if (w === 'FOIL') return 'F'
    return 'S'
  }
</script>

<style>
  .el-backrow {
    margin-bottom: 12px;
  }
  .el-back {
    display: inline-flex;
    align-items: center;
    gap: 7px;
    background: transparent;
    border: 1px solid #1a4a8a;
    color: #7fd8ff;
    border-radius: 8px;
    padding: 6px 13px;
    cursor: pointer;
    font-size: 0.85em;
    font-family: inherit;
  }
  .el-back:hover {
    border-color: #00d4ff;
    color: #00d4ff;
    background: rgba(0, 212, 255, 0.06);
  }

  .el-card {
    max-width: 760px;
    margin: 0 auto;
    background: #16213e;
    border: 1px solid #0f3460;
    border-radius: 12px;
    padding: 22px;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }
  .el-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 12px;
    margin-bottom: 16px;
  }
  .el-top-actions {
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .el-close {
    background: none;
    border: none;
    font-size: 24px;
    line-height: 1;
    cursor: pointer;
    color: #7fbadc;
    padding: 0 2px;
  }
  .el-close:hover {
    color: #fff;
  }
  .el-title {
    font-weight: 600;
    color: #fff;
    font-size: 1.05em;
  }
  .el-metrics {
    display: grid;
    grid-template-columns: repeat(4, 1fr);
    gap: 8px;
    margin-bottom: 16px;
  }
  @media (max-width: 480px) {
    .el-metrics {
      grid-template-columns: repeat(2, 1fr);
    }
  }
  .el-metric {
    background: #0d1b2a;
    border-radius: 8px;
    padding: 9px 12px;
  }
  .el-k {
    font-size: 0.72em;
    color: #7fbadc;
  }
  .el-v {
    font-size: 1.3em;
    font-weight: 600;
    color: #fff;
  }
  /* While narrowed (FR-165): the tiles are framed (S5) and every control that
     narrows the list is highlighted (S1). */
  .el-metrics.el-narrowed {
    outline: 2px dashed #ffd24a;
    outline-offset: 4px;
    border-radius: 8px;
  }
  .el-filters .el-active {
    border-color: #00d4ff;
    box-shadow: 0 0 0 1px #00d4ff;
  }
  /* The × that empties the search (S2). 36px touch area (FR-130); the input
     keeps its text clear of it only while there is text. */
  .el-searchwrap {
    position: relative;
  }
  .el-searchwrap .el-search.el-active {
    padding-right: 44px;
  }
  .el-search-clear {
    position: absolute;
    right: 4px;
    top: 50%;
    transform: translateY(-50%);
    width: 36px;
    height: 36px;
    border: 0;
    border-radius: 50%;
    background: transparent;
    color: #7fbadc;
    font-size: 20px;
    line-height: 1;
    cursor: pointer;
    font-family: inherit;
  }
  .el-search-clear:hover {
    color: #fff;
    background: rgba(0, 212, 255, 0.1);
  }
  .el-search-clear:focus-visible {
    outline: 2px solid #00d4ff;
    outline-offset: 1px;
  }
  /* "Wyczyść filtry" (S3): right-aligned under the filters, shown only while
     narrowed. Drawn as a link, with a 36px touch height (FR-130). */
  .el-clear-all {
    align-self: flex-end;
    min-height: 36px;
    padding: 0 2px;
    background: none;
    border: 0;
    color: #7fd8ff;
    font-family: inherit;
    font-size: 0.82em;
    text-decoration: underline;
    cursor: pointer;
  }
  .el-clear-all:hover {
    color: #00d4ff;
  }
  .el-clear-all:focus-visible {
    outline: 2px solid #00d4ff;
    outline-offset: 2px;
    border-radius: 4px;
  }
  /* A chosen weapon dims the other two weapon tiles (S4). */
  .el-metric.el-dim {
    opacity: 0.4;
  }
  /* The total beside the selection, while narrowed (FR-165). */
  .el-of {
    font-size: 0.6em;
    font-weight: 500;
    color: #7fbadc;
  }
  .el-filters {
    display: flex;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 14px;
  }
  .el-filters input, .el-filters select {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #e0e0e0;
    padding: 8px 10px;
    border-radius: 8px;
    font-size: 16px;
    font-family: inherit;
    min-height: 44px;
    width: 100%;
    box-sizing: border-box;
  }
  .el-search {
    width: 100%;
  }
  .el-fgroup {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  /* FR-169: with „Kraj”, four filters in one row on a desktop, two rows of two
     on a phone. */
  .el-fgroup.el-four {
    grid-template-columns: repeat(4, 1fr);
  }
  @media (max-width: 480px) {
    .el-fgroup.el-four {
      grid-template-columns: repeat(2, 1fr);
    }
  }
  .el-flabel {
    display: flex;
    flex-direction: column;
    gap: 4px;
    min-width: 0;
  }
  .el-flabel span {
    font-size: 0.72em;
    color: #7fbadc;
    text-transform: uppercase;
    letter-spacing: 0.3px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
  }
  th {
    text-align: left;
    font-size: 0.74em;
    color: #7fbadc;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 8px;
    border-bottom: 1px solid #1a4a8a;
  }
  td {
    padding: 9px 8px;
    font-size: 0.88em;
    border-bottom: 1px solid #16273f;
  }
  .el-narrow {
    width: 40px;
  }
  .el-cat {
    font-size: 0.78em;
    padding: 2px 9px;
    border-radius: 999px;
    background: rgba(0, 212, 255, 0.12);
    color: #7fd8ff;
  }
  .el-wpn {
    display: inline-block;
    width: 22px;
    text-align: center;
    font-size: 0.72em;
    padding: 2px 0;
    border-radius: 6px;
    margin-right: 3px;
    font-weight: 600;
  }
  .el-w-E {
    background: rgba(96, 196, 89, 0.18);
    color: #9fe08c;
  }
  .el-w-F {
    background: rgba(0, 212, 255, 0.16);
    color: #7fd8ff;
  }
  .el-w-S {
    background: rgba(240, 159, 39, 0.18);
    color: #f0b967;
  }
  .el-empty {
    text-align: center;
    color: #8894a8;
    font-size: 0.9em;
    padding: 20px;
  }
  .el-legend {
    color: #8894a8;
    font-size: 0.78em;
    margin-top: 12px;
  }

  /* FR-169: the flag at the end of the line, 18px, never wrapping; no pill,
     border or background. A code with no drawn flag shows its letters (D1). */
  .el-flag {
    width: 1%;
    white-space: nowrap;
    text-align: right;
  }
  .el-flagcode {
    display: inline-block;
    min-width: 18px;
    font-size: 0.66em;
    color: #8894a8;
    letter-spacing: 0.3px;
  }

  /* FR-166 — the administrator's removal. Nothing below renders for a
     visitor. */
  .el-act {
    width: 1%;
    text-align: right;
    white-space: nowrap;
  }
  .el-remove {
    background: transparent;
    color: #ff8a8a;
    border: 1px solid #7a2e3a;
    border-radius: 8px;
    padding: 4px 10px;
    min-height: 32px;
    font-size: 0.82em;
    font-family: inherit;
    cursor: pointer;
  }
  .el-remove:hover {
    border-color: #ff8a8a;
    background: rgba(255, 138, 138, 0.08);
  }
  /* FR-170 — „Edytuj” beside „Usuń”, in the list's own blue; the ≠ mark in
     the same amber as the dialog's. Nothing here renders for a visitor. */
  .el-edit {
    background: transparent;
    color: #7fd8ff;
    border: 1px solid #1a4a8a;
    border-radius: 8px;
    padding: 4px 10px;
    min-height: 32px;
    margin-right: 6px;
    font-size: 0.82em;
    font-family: inherit;
    cursor: pointer;
  }
  .el-edit:hover {
    border-color: #7fd8ff;
    background: rgba(127, 216, 255, 0.08);
  }
  .el-edit:disabled {
    opacity: 0.5;
    cursor: default;
  }
  .el-yeardiff {
    color: #f5b942;
    font-weight: 700;
    margin-right: 8px;
  }
  .el-remove-done {
    color: #4ade80;
    font-size: 0.9em;
    margin: 0 0 12px;
    scroll-margin-top: 16px;
  }
  .el-remove-done:focus {
    outline: none;
  }
  .el-confirm-backdrop {
    position: fixed;
    inset: 0;
    z-index: 1100;
    background: rgba(0, 0, 0, 0.55);
    display: flex;
    align-items: center;
    justify-content: center;
    padding: 16px;
  }
  .el-confirm {
    width: 100%;
    max-width: 420px;
    background: #2a1520;
    border: 1px solid #7a2e3a;
    border-radius: 10px;
    padding: 16px;
    color: #ffd7d7;
    font-size: 0.92em;
    line-height: 1.5;
  }
  .el-confirm:focus {
    outline: none;
  }
  .el-confirm p {
    margin: 0 0 6px;
  }
  .el-confirm-title {
    font-weight: 600;
    color: #fff;
    font-size: 1.05em;
  }
  .el-confirm-who,
  .el-confirm-event {
    color: #fff;
  }
  .el-confirm .el-confirm-note {
    margin-top: 10px;
  }
  .el-remove-failed {
    color: #ffb4b4;
    font-weight: 600;
  }
  .el-confirm-acts {
    display: flex;
    flex-wrap: wrap;
    gap: 12px;
    margin-top: 14px;
  }
  .el-remove-confirm,
  .el-remove-cancel {
    border-radius: 8px;
    padding: 9px 16px;
    min-height: 40px;
    font-weight: 600;
    font-size: 0.92em;
    font-family: inherit;
    cursor: pointer;
  }
  .el-remove-confirm {
    background: #e5484d;
    color: #fff;
    border: none;
  }
  .el-remove-cancel {
    background: transparent;
    color: #9fc4dc;
    border: 1px solid #1a4a8a;
  }
  .el-remove-confirm:disabled,
  .el-remove-cancel:disabled {
    opacity: 0.6;
    cursor: default;
  }

  @media (max-width: 480px) {
    table, tbody {
      display: block;
      width: 100%;
    }
    thead {
      display: none;
    }
    tr {
      display: flex;
      flex-wrap: nowrap;
      align-items: center;
      gap: 6px;
      border-bottom: 1px solid #1a2c4a;
      padding: 8px 0;
    }
    td {
      display: inline-flex;
      align-items: center;
      flex: none;
      border-bottom: none;
      padding: 0;
      width: auto;
    }
    /* FR-166: the row's last cell takes the button's own width; the desktop
       1% would squeeze it to a few pixels and clip the button. */
    .el-act {
      width: auto;
    }
    .el-flag {
      width: auto;
      flex: none;
    }
    /* I25: a block, not the cells' inline-flex: a browser draws „…” only in
       a block, so a name that does not fit ends in „…” instead of a cut
       letter. */
    .el-name {
      display: block;
      flex: 1 1 auto;
      min-width: 0;
      font-weight: 600;
      color: #fff;
      overflow: hidden;
      text-overflow: ellipsis;
      white-space: nowrap;
    }
    /* I25 A: a signed-in row wraps, so ≠, „Edytuj” and „Usuń” sit on a line
       of their own under the name and the name keeps the row's width. A
       visitor's row has no actions and stays one line. */
    tr.el-adminrow {
      flex-wrap: wrap;
    }
    .el-adminrow .el-act {
      flex-basis: 100%;
      justify-content: flex-start;
    }
    /* In a wrapping row the name starts from no width and takes what the
       chips leave, so a long name never pushes them off its line. */
    .el-adminrow .el-name {
      flex-basis: 0;
    }
  }
</style>
