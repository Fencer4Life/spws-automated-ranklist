<!--
  FR-168 — the birth-year box with its decade grid (plan registration-form-
  names-year-country rev 10, release 2; tests RFYEAR.03–06 in
  frontend/tests/RegistrationForm.test.ts).

  Focusing or clicking the box opens a grid of one decade: the decade of the
  year in the box, else of a 50-year-old. It pages by decade as far as the
  range reaches and greys out years outside it. Typing still works, digits
  only, four at most, and closes the grid, as Escape does. A year outside the range shows a line under the box naming the range,
  once four digits are typed or the box is left.
-->
<div class="yp" bind:this={wrap}>
  <label class="reg-lbl" for="reg-birth-year">{t('reg_birth_year')}</label>
  <input
    bind:this={box}
    id="reg-birth-year"
    name="birthYear"
    type="text"
    inputmode="numeric"
    autocomplete="bday-year"
    maxlength="4"
    value={text}
    aria-invalid={showError}
    oninput={onInput}
    onfocus={openGrid}
    onclick={openGrid}
    onkeydown={(e) => { if (e.key === 'Escape') open = false }}
    onblur={onLeave}
  />
  {#if open}
    <div class="reg-yeargrid" role="group" aria-label={t('reg_year_grid')}>
      <div class="yg-head">
        <button type="button" class="reg-yeargrid-prev" aria-label={t('reg_year_prev')}
          disabled={decade <= decadeOf(range.min)} onclick={() => (decade -= 10)} onmousedown={keepFocus} onblur={onLeave}>‹</button>
        <b class="reg-yeargrid-decade">{decade} – {decade + 9}</b>
        <button type="button" class="reg-yeargrid-next" aria-label={t('reg_year_next')}
          disabled={decade >= decadeOf(range.max)} onclick={() => (decade += 10)} onmousedown={keepFocus} onblur={onLeave}>›</button>
      </div>
      <div class="yg-years">
        {#each Array.from({ length: 10 }, (_, i) => decade + i) as y (y)}
          <button type="button" class="reg-yeargrid-year" class:on={y === year}
            disabled={!inRange(y, range)} onclick={() => pick(y)} onmousedown={keepFocus} onblur={onLeave}>{y}</button>
        {/each}
      </div>
      <div class="yg-foot">
        <span class="reg-yeargrid-range">{range.min} … {range.max}</span>
        <span class="reg-yeargrid-cat">{vcat ?? ''}</span>
      </div>
    </div>
  {/if}
  {#if showError}
    <span class="reg-year-error">{t('reg_year_out_of_range', { min: range.min, max: range.max })}</span>
  {/if}
</div>

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import { cleanYearInput, decadeOf, inRange, type YearRange } from '../lib/birthYearRange'

  let {
    year = $bindable(null),
    range,
    vcat = null,
    // FR-173 (D12): after a pick from the name list, the decade of the
    // person's age category. The year is still the fencer's own to give.
    hintDecade = null,
  }: { year: number | null; range: YearRange; vcat?: string | null; hintDecade?: number | null } = $props()

  let box = $state<HTMLInputElement | null>(null)

  let wrap = $state<HTMLDivElement | null>(null)
  let text = $state(year == null ? '' : String(year))
  let open = $state(false)
  let left = $state(false)
  let decade = $state(0)

  // The parent may set the year itself (the roster's year adopted on the
  // birth-year question); the box follows it.
  $effect(() => {
    const shown = text === '' ? null : parseInt(text, 10)
    if (shown !== year) text = year == null ? '' : String(year)
  })

  const showError = $derived(year != null && !inRange(year, range) && (text.length === 4 || left))

  function clampDecade(d: number): number {
    return Math.min(Math.max(d, decadeOf(range.min)), decadeOf(range.max))
  }

  function openGrid() {
    if (inRange(year, range)) decade = clampDecade(decadeOf(year as number))
    else if (hintDecade != null) decade = clampDecade(hintDecade)
    else decade = clampDecade(decadeOf(range.max + 30 - 50))
    open = true
  }

  // FR-173: the form moves the focus here after a pick, with the grid open.
  export function focusBox() {
    box?.focus()
    openGrid()
  }

  function onInput(e: Event) {
    const el = e.target as HTMLInputElement
    const kept = cleanYearInput(el.value)
    el.value = kept
    text = kept
    year = kept === '' ? null : parseInt(kept, 10)
    // Typing means the keyboard was chosen: the grid closes so it never covers
    // the next field („Szpada” sits under it). A click on the box reopens it.
    open = false
  }

  function pick(y: number) {
    // A year outside the range cannot be chosen, whatever delivered the click.
    if (!inRange(y, range)) return
    year = y
    text = String(y)
    open = false
    left = true
  }

  // A press on a grid button keeps focus in the box: Chrome blurs a pager it
  // disables at the last decade, and Safari never focuses a pressed button,
  // so either would close the grid mid-choice. Keyboard users still Tab in.
  function keepFocus(e: MouseEvent) {
    e.preventDefault()
  }

  // Focus moving between the box and the grid keeps it open; leaving both
  // closes it and lets a short year („47”) show its line.
  function onLeave(e: FocusEvent) {
    const next = e.relatedTarget as Node | null
    if (next && wrap?.contains(next)) return
    open = false
    left = true
  }
</script>

<style>
  .yp {
    position: relative;
    display: flex;
    flex-direction: column;
    gap: 5px;
  }
  /* The form's own rules for a label and a box (RegistrationForm.svelte), so
     the year box looks as the others do: Svelte scopes them per component. */
  .reg-lbl {
    font-size: 0.8em;
    color: #7fbadc;
  }
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
  .reg-yeargrid {
    position: absolute;
    top: 100%;
    left: 0;
    z-index: 5;
    width: 260px;
    max-width: calc(100vw - 48px);
    margin-top: 4px;
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 10px;
    padding: 10px;
    box-sizing: border-box;
    box-shadow: 0 8px 24px rgba(0, 0, 0, 0.45);
  }
  .yg-head,
  .yg-foot {
    display: flex;
    justify-content: space-between;
    align-items: center;
    color: #7fbadc;
    font-size: 0.85em;
  }
  .yg-head b {
    color: #fff;
  }
  .yg-head button {
    background: none;
    border: none;
    color: #7fbadc;
    font-size: 1.2em;
    padding: 0 8px;
    cursor: pointer;
    width: auto;
  }
  .yg-head button:disabled {
    opacity: 0.3;
    cursor: default;
  }
  .yg-years {
    display: grid;
    grid-template-columns: repeat(5, 1fr);
    gap: 5px;
    margin: 8px 0;
  }
  .reg-yeargrid-year {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    border-radius: 6px;
    padding: 5px 0;
    color: #e0e0e0;
    font-size: 0.85em;
    font-family: inherit;
    cursor: pointer;
  }
  .reg-yeargrid-year.on {
    background: #00d4ff;
    border-color: #00d4ff;
    color: #0d1b2a;
    font-weight: 700;
  }
  .reg-yeargrid-year:disabled {
    opacity: 0.3;
    cursor: default;
  }
  .reg-yeargrid-cat {
    color: #7fd8ff;
  }
  .reg-year-error {
    color: #ff8a8a;
    font-size: 0.8em;
  }
</style>
