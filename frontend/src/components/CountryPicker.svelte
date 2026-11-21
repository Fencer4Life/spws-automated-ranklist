<!--
  FR-169 — the country pick-list (plan registration-form-names-year-country
  rev 10, release 3; tests RFCTRY.05 in frontend/tests/CountryPicker.test.ts).

  A pick-list, never free text. The box shows the chosen country's name, its
  code beside it. Typing finds countries by Polish name, English name or code,
  folding accents and case („wiel”, „brit”, „gbr” → Wielka Brytania GBR); a
  pick (a tap, or Enter for the first found) sets the code. Leaving the box
  without a pick restores the chosen country, so typed text is never taken.
-->
<div class="cp" bind:this={wrap}>
  <label class="reg-lbl" for="reg-country">{t('reg_country')}</label>
  <div class="cp-box">
    <input
      id="reg-country"
      name="country"
      type="text"
      autocomplete="off"
      role="combobox"
      aria-expanded={open}
      aria-controls="reg-country-list"
      value={text}
      oninput={onInput}
      onfocus={onFocus}
      onkeydown={onKey}
      onblur={onLeave}
    />
    <span class="cp-code">{code}</span>
  </div>
  {#if open && found.length > 0}
    <div class="cp-list" id="reg-country-list" role="listbox" aria-label={t('reg_country')}>
      {#each found as c (c)}
        <button type="button" role="option" aria-selected={c === code} class="cp-opt" class:on={c === code}
          onmousedown={keepFocus} onclick={() => pick(c)} onblur={onLeave}>
          <span class="cp-name">{countryName(c, lang)}</span>
          <span class="cp-optcode">{c}</span>
        </button>
      {/each}
    </div>
  {/if}
</div>

<script lang="ts">
  import { getLocale, t } from '../lib/locale.svelte'
  import { FENCING_COUNTRIES, countryName, searchAliases } from '../lib/fencingCountries'
  import { foldName } from '../lib/foldName'

  let { code = $bindable(), onpick }: { code: string; onpick?: (code: string) => void } = $props()

  const lang = $derived(getLocale() === 'en' ? 'en' : 'pl')
  let wrap = $state<HTMLDivElement | null>(null)
  let query = $state<string | null>(null)
  let open = $state(false)

  // The box shows the chosen country until the visitor types.
  const text = $derived(query ?? countryName(code, lang))

  // Every country with its searchable names, in the page's language's order.
  const index = $derived(
    FENCING_COUNTRIES.map(({ code: c }) => ({
      code: c,
      name: countryName(c, lang),
      keys: [countryName(c, 'pl'), countryName(c, 'en'), c, ...searchAliases(c)].map(foldName),
    })).sort((a, b) => a.name.localeCompare(b.name, lang)),
  )

  const found = $derived.by(() => {
    const q = foldName((query ?? '').trim())
    if (!q) return index.map((e) => e.code)
    return index.filter((e) => e.keys.some((k) => k.includes(q))).map((e) => e.code)
  })

  function onFocus() {
    open = true
  }

  function onInput(e: Event) {
    query = (e.target as HTMLInputElement).value
    open = true
  }

  function pick(c: string) {
    code = c
    onpick?.(c)
    query = null
    open = false
  }

  function onKey(e: KeyboardEvent) {
    if (e.key === 'Enter' && open && found.length > 0) {
      e.preventDefault()
      pick(found[0])
    } else if (e.key === 'Escape') {
      query = null
      open = false
    }
  }

  // A press on the list keeps focus in the box (as the year grid does), so a
  // pick is never lost to the box's blur.
  function keepFocus(e: MouseEvent) {
    e.preventDefault()
  }

  // Leaving both the box and the list: typed text that was not picked goes,
  // and the chosen country shows again.
  function onLeave(e: FocusEvent) {
    const next = e.relatedTarget as Node | null
    if (next && wrap?.contains(next)) return
    query = null
    open = false
  }
</script>

<style>
  .cp {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  /* The form's own rules for a label and a box (RegistrationForm.svelte):
     Svelte scopes them per component. */
  .reg-lbl {
    font-size: 0.8em;
    color: #7fbadc;
  }
  .cp-box {
    position: relative;
  }
  input {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #e0e0e0;
    padding: 8px 52px 8px 10px;
    border-radius: 8px;
    font-size: 0.92em;
    font-family: inherit;
    width: 100%;
    box-sizing: border-box;
  }
  .cp-code {
    position: absolute;
    right: 10px;
    top: 50%;
    transform: translateY(-50%);
    color: #7fbadc;
    font-size: 0.8em;
    letter-spacing: 0.5px;
    pointer-events: none;
  }
  .cp-list {
    position: absolute;
    top: 100%;
    left: 0;
    right: 0;
    z-index: 5;
    margin-top: 4px;
    max-height: 240px;
    overflow-y: auto;
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 10px;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
  }
  .cp-opt {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 8px;
    width: 100%;
    padding: 8px 10px;
    background: none;
    border: 0;
    border-bottom: 1px solid #16273f;
    color: #e0e0e0;
    font-family: inherit;
    font-size: 0.9em;
    text-align: left;
    cursor: pointer;
  }
  .cp-opt:hover,
  .cp-opt:focus-visible,
  .cp-opt.on {
    background: rgba(0, 212, 255, 0.12);
  }
  .cp-optcode {
    color: #7fbadc;
    font-size: 0.85em;
  }
</style>
