<!--
  FR-173 — the name list under the registration form's SURNAME box (plan
  registration-name-list-under-surname rev 1; tests RFAC.18–24 in
  frontend/tests/NameSuggest.test.ts).

  The component owns the surname input, because the list and the keyboard need
  it; the form keeps the value, writes its capitals (oninput) and its name form
  (onblur), and fills the other boxes on a pick (onpick). From two typed letters,
  200 ms after the last keystroke, it asks fn_registration_name_suggestions for
  at most eight people. A row never shows a birth year: every person gives their
  own. Ignoring the list, or a failed request, leaves today's form.
-->
<div class="reg-sg">
  <input
    id="reg-surname"
    name="surname"
    autocomplete="off"
    role="combobox"
    aria-autocomplete="list"
    aria-expanded={open}
    aria-controls={LIST_ID}
    aria-activedescendant={open && active >= 0 ? optionId(active) : undefined}
    {value}
    oninput={onInput}
    onkeydown={onKeyDown}
    onblur={onBlur}
  />
  {#if open}
    <ul id={LIST_ID} class="reg-sg-list" role="listbox" aria-label={t('reg_suggest_list_label')} onmousedown={keepFocus}>
      {#each rows as row, i (i)}
        <li
          id={optionId(i)}
          class="reg-sg-row"
          class:on={i === active}
          role="option"
          tabindex="-1"
          aria-selected={i === active}
          onclick={() => pick(row)}
          onkeydown={(e) => { if (e.key === 'Enter') pick(row) }}
        >
          <span class="reg-sg-name">
            <b>{row.surname}</b> {row.firstName}
            {#if row.entered}<span class="reg-sg-entered">{t('reg_suggest_entered')}</span>{/if}
          </span>
          <span class="reg-sg-meta">
            {#if row.vcat}<span class="reg-sg-cat">{row.vcat}</span>{/if}
            {#if row.country}
              <span class="reg-sg-country">
                {#if isFencingCountry(row.country)}<CountryFlag code={flagIso(row.country)} label={countryName(row.country, lang)} size="sm" />{/if}
                {row.country}
              </span>
            {/if}
            <span class="reg-sg-src">{t(SOURCE_KEY[row.source])}</span>
          </span>
        </li>
      {/each}
      <li class="reg-sg-foot" role="presentation">{t('reg_suggest_footer')}</li>
    </ul>
  {/if}
</div>

<script lang="ts">
  import { getLocale, t } from '../lib/locale.svelte'
  import { fetchNameSuggestions } from '../lib/api'
  import { countryName, flagIso, isFencingCountry } from '../lib/fencingCountries'
  import CountryFlag from './CountryFlag.svelte'
  import type { NameSource, NameSuggestion } from '../lib/types'

  let {
    value,
    eventId,
    oninput,
    onblur,
    onpick,
  }: {
    value: string
    eventId: number | null
    oninput: (e: Event) => void
    onblur: () => void
    onpick: (s: NameSuggestion) => void
  } = $props()

  const LIST_ID = 'reg-sg-list'
  const WAIT_MS = 200
  const SOURCE_KEY: Record<NameSource, string> = {
    ROSTER: 'reg_suggest_source_roster',
    EVF: 'reg_suggest_source_evf',
    ENTRY: 'reg_suggest_source_entry',
  }

  let rows = $state<NameSuggestion[]>([])
  let active = $state(-1)
  const open = $derived(rows.length > 0)
  const lang = $derived(getLocale() === 'pl' ? 'pl' : 'en')

  let timer: ReturnType<typeof setTimeout> | null = null
  // Only the latest request may fill the list; an earlier answer arriving late
  // is dropped.
  let asked = 0

  function optionId(i: number): string {
    return `reg-sg-opt-${i}`
  }

  function close() {
    rows = []
    active = -1
  }

  function cancel() {
    if (timer) clearTimeout(timer)
    timer = null
    asked += 1
  }

  function onInput(e: Event) {
    oninput(e)
    const typed = (e.target as HTMLInputElement).value.trim()
    cancel()
    if (typed.length < 2 || eventId == null) {
      close()
      return
    }
    const id = eventId
    const mine = asked
    timer = setTimeout(() => {
      timer = null
      fetchNameSuggestions(id, typed)
        .then((found) => {
          if (mine !== asked) return
          rows = found
          active = -1
        })
        .catch(() => {
          if (mine === asked) close()
        })
    }, WAIT_MS)
  }

  function pick(row: NameSuggestion) {
    cancel()
    close()
    onpick(row)
  }

  function onKeyDown(e: KeyboardEvent) {
    if (!open) return
    if (e.key === 'ArrowDown') {
      e.preventDefault()
      active = (active + 1) % rows.length
    } else if (e.key === 'ArrowUp') {
      e.preventDefault()
      active = active <= 0 ? rows.length - 1 : active - 1
    } else if (e.key === 'Enter') {
      if (active >= 0) {
        e.preventDefault()
        pick(rows[active])
      }
    } else if (e.key === 'Escape') {
      cancel()
      close()
    }
  }

  // A press on the list keeps the focus in the box, so the blur below does not
  // close the list before the click lands (as YearPicker's grid does).
  function keepFocus(e: MouseEvent) {
    e.preventDefault()
  }

  function onBlur() {
    cancel()
    close()
    onblur()
  }
</script>

<style>
  .reg-sg {
    position: relative;
  }
  /* The form's own rule for a box (RegistrationForm.svelte), so the surname box
     looks as the others do: Svelte scopes styles per component. */
  input {
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
  .reg-sg-list {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 6;
    margin: 4px 0 0;
    padding: 4px 0;
    list-style: none;
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 10px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
    max-height: 360px;
    overflow-y: auto;
  }
  .reg-sg-row {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    min-height: 40px;
    padding: 6px 11px;
    box-sizing: border-box;
    cursor: pointer;
    color: #e0e0e0;
    font-size: 0.9em;
  }
  .reg-sg-row.on,
  .reg-sg-row:hover {
    background: #13304f;
  }
  .reg-sg-name {
    min-width: 0;
    overflow-wrap: anywhere;
  }
  .reg-sg-entered {
    display: inline-block;
    margin-left: 6px;
    padding: 1px 6px;
    border-radius: 4px;
    background: #4a3b10;
    color: #ffd76a;
    font-size: 0.8em;
  }
  .reg-sg-meta {
    display: flex;
    align-items: center;
    gap: 8px;
    flex-shrink: 0;
    color: #7fbadc;
    font-size: 0.82em;
  }
  .reg-sg-country {
    display: inline-flex;
    align-items: center;
    gap: 4px;
  }
  .reg-sg-foot {
    padding: 7px 11px 5px;
    border-top: 1px solid #1a4a8a;
    color: #7fbadc;
    font-size: 0.8em;
  }
</style>
