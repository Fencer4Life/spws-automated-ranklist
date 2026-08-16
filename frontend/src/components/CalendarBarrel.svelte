<div class="vp" bind:this={viewportEl}>
  <div class="drum" style:transform={`translateY(${-(active - 1) * ROW_H}px)`}>
    {#each quarters as quarter, qi (quarter.key)}
      {@const state = rowState(qi)}
      {@const layout = qi === active ? midLayout : null}
      <!-- Only a receded row is a control: tapping it rotates it to centre.
           The focused row is not interactive as a whole — its panels are — so it
           carries neither a role nor a tab stop. -->
      {@const rotatable = state === 'up' || state === 'dn'}
      <div
        class="ln {state}"
        role="button"
        tabindex={rotatable ? 0 : undefined}
        aria-disabled={rotatable ? undefined : 'true'}
        aria-label={quarter.label}
        onclick={() => rotateTo(qi)}
        onkeydown={(e) => onRowKey(e, qi)}
      >
        <!-- The engraved seam: quarter label, a hairline, and the season code.
             The code shows on the focused row and permanently on a season
             boundary, whose rule is also drawn heavier — this is where the
             deleted season dropdown's information went. -->
        <div class="sm" class:bd={quarter.isSeasonBoundary}>
          <b>{quarter.label}</b>
          <i></i>
          <em>{seamSeason(qi, quarter)}</em>
        </div>

        <div class="rw">
          {#if quarter.isEmpty}
            <span class="mt">{t('calendar_empty_quarter')}</span>
          {:else}
            <div class="rwi" style:gap={layout?.overlapping ? '0px' : null}>
              {#each quarter.events as event, j (event.id_event)}
                {@const place = layout?.panels[j]}
                {@const isSelected = qi === active && selected === j}
                <button
                  type="button"
                  class="p {panelType(event.txt_code)}"
                  class:f={event.enum_status === 'COMPLETED'}
                  class:nx={isNext(event)}
                  class:sel={isSelected}
                  class:ov={layout?.overlapping ?? false}
                  class:t1={place?.textTier === 1}
                  class:t2={place?.textTier === 2}
                  class:canc={event.enum_status === 'CANCELLED'}
                  style:flex={place ? `0 0 ${place.width}px` : null}
                  style:margin-left={place && place.marginLeft ? `${place.marginLeft}px` : null}
                  style:z-index={place?.zIndex ?? null}
                  aria-pressed={isSelected}
                  onclick={(e) => {
                    e.stopPropagation()
                    pick(qi, j)
                  }}
                >
                  <span class="dd">{dayOf(event.dt_start)}</span>
                  <span class="dm">
                    <i class="ms">{monthShort(event.dt_start)}</i>
                    <i class="mf">{monthFull(event.dt_start)}</i>
                  </span>
                  <span class="cdc">{panelLabel(event.txt_code)}</span>
                  {#if cityOf(event)}
                    <span class="cty">{cityOf(event)}</span>
                  {/if}
                </button>
              {/each}
            </div>
          {/if}
        </div>
      </div>
    {/each}
  </div>
</div>

<div class="crw">
  {#if caretLeft !== null}
    <div class="crt" style:left={`${caretLeft}px`}></div>
  {/if}
</div>

<script lang="ts">
  // The rotating three-row quarter barrel — ADR-084 §§1-7.
  //
  // It is the calendar's primary control: it replaces the month-grouped list,
  // the flat rolling-progress strip AND the season dropdown, and it drives the
  // single event card beneath it.
  //
  // Each variable gets its own visual channel, which is what the old strip got
  // wrong by encoding type as hue and completion as lightness OF THAT SAME HUE:
  //   hue  → event type
  //   fill → completed
  //   ring → next upcoming
  //
  // Rotation is a translateY on the drum; the per-row facing angle is a
  // rotateX. The DOM never re-renders on rotate — only classes change.

  import type { CalendarEvent } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import {
    caretOffset,
    layoutRow,
    rowScroll,
    panelLabel,
    panelType,
    seasonShortCode,
    splitLocation,
    type Quarter,
    type RowLayout,
  } from '../lib/calendarQuarters'

  /** Must match `.ln` height in the stylesheet. */
  const ROW_H = 82

  let {
    quarters,
    anchorIndex = 0,
    nextUpcoming = null,
    onselect,
  }: {
    quarters: Quarter[]
    anchorIndex?: number
    nextUpcoming?: CalendarEvent | null
    onselect?: (event: CalendarEvent) => void
  } = $props()

  let viewportEl = $state<HTMLElement | null>(null)
  let available = $state(0)
  let active = $state(0)
  /** Index within the focused row's events, or null when the row is empty. */
  let selected = $state<number | null>(null)

  let initKey = ''

  // Re-anchor when the data or the resolved anchor changes, but never in
  // response to the user's own selection.
  $effect(() => {
    const key = `${quarters.length}:${quarters[0]?.key ?? ''}:${anchorIndex}`
    if (key === initKey) return
    initKey = key
    active = Math.max(0, Math.min(quarters.length - 1, anchorIndex))
    selectDefault(active)
  })

  // The row spans the viewport, so one observer serves every rotation.
  $effect(() => {
    const el = viewportEl
    if (!el) return
    const measure = () => (available = el.clientWidth)
    measure()
    if (typeof ResizeObserver === 'undefined') return
    const ro = new ResizeObserver(measure)
    ro.observe(el)
    return () => ro.disconnect()
  })

  function selectDefault(qi: number): void {
    const events = quarters[qi]?.events ?? []
    if (events.length === 0) {
      selected = null
      return
    }
    const ringed = nextUpcoming
      ? events.findIndex((e) => e.id_event === nextUpcoming.id_event)
      : -1
    selected = ringed >= 0 ? ringed : 0
    onselect?.(events[selected]!)
  }

  function rowState(qi: number): 'up' | 'mid' | 'dn' | 'far' {
    const d = qi - active
    return d === -1 ? 'up' : d === 0 ? 'mid' : d === 1 ? 'dn' : 'far'
  }

  /** Tapping a receded row rotates it to centre; the whole row is the target. */
  function rotateTo(qi: number): void {
    if (qi === active) return
    active = qi
    selectDefault(qi)
  }

  function onRowKey(event: KeyboardEvent, qi: number): void {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      rotateTo(qi)
    }
  }

  function pick(qi: number, j: number): void {
    if (qi !== active) {
      rotateTo(qi)
      return
    }
    selected = j
    const event = quarters[qi]?.events[j]
    if (event) onselect?.(event)
  }

  function isNext(event: CalendarEvent): boolean {
    return nextUpcoming != null && nextUpcoming.id_event === event.id_event
  }

  function cityOf(event: CalendarEvent): string {
    const { city, venue } = splitLocation(event.txt_location)
    return city || venue
  }

  function dayOf(iso: string | null): string {
    return iso ? String(Number(iso.slice(8, 10))) : ''
  }

  function monthIndex(iso: string | null): number | null {
    return iso ? Number(iso.slice(5, 7)) : null
  }

  function monthShort(iso: string | null): string {
    const m = monthIndex(iso)
    return m ? t(`cal_month_short_${m}`) : ''
  }

  function monthFull(iso: string | null): string {
    const m = monthIndex(iso)
    return m ? t(`cal_month_${m}`) : ''
  }

  /**
   * The season code is engraved on the focused row and permanently on a
   * boundary seam. A quarter holding two seasons is marked, because CERT really
   * does contain them.
   */
  function seamSeason(qi: number, quarter: Quarter): string {
    if (qi !== active && !quarter.isSeasonBoundary) return ''
    const codes = quarter.seasonCodes
    if (codes.length === 0) return ''
    const short = seasonShortCode(codes[codes.length - 1])
    return codes.length > 1 ? `${short} *` : short
  }

  const midLayout = $derived.by((): RowLayout | null => {
    const row = quarters[active]
    if (!row || row.events.length === 0) return null
    // Before measurement — and in jsdom, which has no layout engine and reports
    // every clientWidth as 0 — fall back to a flat row with no inline geometry.
    if (available <= 0) return null
    return layoutRow({
      count: row.events.length,
      selectedIndex: selected ?? 0,
      available,
      selectedHasCity: !!cityOf(row.events[selected ?? 0]!),
    })
  })

  /** How far the focused row is scrolled — 0 unless its content overflows. */
  const scroll = $derived.by(() => {
    const layout = midLayout
    return layout ? rowScroll(layout, selected, available) : 0
  })

  // Scroll the focused row so its selection sits under the caret.
  //
  // Timing is the whole difficulty here, and it cost three wrong attempts:
  //
  //  - A `use:` action looked right, because an action's parameter update runs
  //    after the element's attributes are patched. But **Svelte 5 removed
  //    `action.update`** — the callback ran once, on mount, while the row was
  //    unlaid-out, and never again. Every later write simply never happened.
  //  - Cancelling the retry frame in the effect's cleanup meant each re-run
  //    killed the pending retry, so only the synchronous write survived — and
  //    that one is clamped to 0 whenever `scrollWidth` still equals
  //    `clientWidth`, which is exactly the case in the patch that adds the
  //    padding.
  //  - On rotation the row was receded a frame ago, where `overflow-x` is
  //    hidden and scrollLeft is pinned at 0, so one retry frame is too early.
  //
  // Hence: no cleanup, and retries on the next two frames. Frames fire in
  // order, so a newer selection's writes always land after an older one's.
  $effect(() => {
    // Depend on the selection and the layout, but resolve the ROW inside the
    // retries. The anchor effect assigns `active` from within an effect, so on
    // the opening render this effect can run in the same flush — before Svelte
    // has moved the `mid` class onto the anchor row. Querying up front found
    // the outgoing row and centred that one, which is why every rotation
    // looked right and only the first screen was off.
    void active
    const target = scroll
    if (!viewportEl) return
    const fix = () => {
      const el = viewportEl?.querySelector<HTMLElement>('.ln.mid .rw')
      if (el) el.scrollLeft = target
    }
    fix()
    requestAnimationFrame(fix)
    const late = setTimeout(fix, 120)
    return () => clearTimeout(late)
  })

  /** Caret position — the centre, since the row scrolls its selection there. */
  const caretLeft = $derived.by((): number | null => {
    const layout = midLayout
    if (!layout) return null
    return caretOffset(layout, selected, available)
  })
</script>

<style>
  .vp {
    height: 246px;
    overflow: hidden;
    perspective: 760px;
    margin-top: 6px;
  }
  .drum {
    display: flex;
    flex-direction: column;
    transition: transform 0.45s cubic-bezier(0.22, 0.61, 0.36, 1);
  }
  .ln {
    height: 82px;
    flex: 0 0 82px;
    /* Anchored left, not centre: the receded rows are scaled to 0.88, and a
       centre origin would inset them from the left edge by ~6% of the row —
       so the rows would no longer share a left edge. */
    transform-origin: 0 50%;
    transition:
      transform 0.45s cubic-bezier(0.22, 0.61, 0.36, 1),
      opacity 0.45s;
    cursor: pointer;
    border: none;
    background: none;
    padding: 0;
    text-align: left;
    width: 100%;
  }
  /* Facing angle is per row; the drum itself only translates. */
  .ln.up {
    transform: rotateX(46deg) scale(0.88);
    opacity: 0.42;
  }
  .ln.dn {
    transform: rotateX(-46deg) scale(0.88);
    opacity: 0.42;
  }
  .ln.far {
    opacity: 0;
    pointer-events: none;
  }
  .ln.mid {
    cursor: default;
  }
  .sm {
    display: flex;
    align-items: center;
    gap: 5px;
    height: 14px;
  }
  .sm b {
    font-size: 11px;
    font-weight: 400;
    color: var(--text-muted, #8a887f);
    letter-spacing: 0.6px;
  }
  .ln.mid .sm b {
    color: var(--text-secondary, #565550);
  }
  .sm i {
    flex: 1;
    height: 1px;
    background: var(--border, rgba(0, 0, 0, 0.13));
    font-style: normal;
  }
  /* A season boundary takes a heavier rule. */
  .sm.bd i {
    height: 2px;
    background: var(--text-muted, #8a887f);
  }
  .sm em {
    font-size: 11px;
    color: var(--text-muted, #8a887f);
    font-style: normal;
  }
  /* The focused row scrolls. Overlap absorbs overflow only down to
     PANEL_STEP_FLOOR (CQ.70); past that the row is genuinely wider than the
     viewport, and a panel can be reached ONLY by tapping it — rotation moves
     between rows, never within one. Clipping here would strand the trailing
     panels with no way back to them. The scrollbar is hidden, not the overflow. */
  .rw {
    display: flex;
    overflow-x: auto;
    scrollbar-width: none;
    padding-top: 3px;
    padding-bottom: 4px;
  }
  .rw::-webkit-scrollbar {
    display: none;
  }
  /* Receded rows are not tap targets for their panels, so they clip instead. */
  .up .rw,
  .dn .rw {
    overflow-x: hidden;
  }
  /* `margin: 0 auto`, not `justify-content: center`: auto margins absorb only
     POSITIVE free space, so a row that fits is centred and one that overflows
     left-aligns and stays scrollable. Centring would push the leading panels
     into negative scroll space, where nothing can reach them. */
  /* Left-aligned. Every row starts on the same edge, so nothing drifts as the
     drum rotates between rows of different widths. */
  .rwi {
    display: flex;
    gap: 3px;
    margin: 0;
    position: relative;
  }
  .p {
    flex: 0 0 48px;
    min-width: 0;
    display: flex;
    flex-direction: column;
    align-items: center;
    justify-content: center;
    padding: 2px 1px;
    border-radius: 6px;
    border: 1px solid var(--border, rgba(0, 0, 0, 0.13));
    background: var(--surface-2, #fff);
    cursor: pointer;
    height: 56px;
  }
  .p > * {
    flex: 0 0 auto;
  }
  /* Fill carries completion — its own channel, not a shade of the type hue. */
  .p.f {
    border: none;
  }
  .p.ppw,
  .p.mpw {
    color: #173404;
  }
  .p.ppw.f,
  .p.mpw.f {
    background: #eaf3de;
  }
  .p.pew {
    color: #042c53;
  }
  .p.pew.f {
    background: #e6f1fb;
  }
  .p.int {
    color: #412402;
  }
  .p.int.f {
    background: #faeeda;
  }
  .p.canc {
    opacity: 0.45;
  }
  /* Ring carries next-upcoming. */
  .p.nx {
    border: 2px solid var(--accent, #185fa5);
  }
  .p.sel {
    outline: 2px solid var(--text-primary, #1c1b19);
    outline-offset: 1px;
  }
  .p.ov {
    position: relative;
    box-shadow: -1px 0 0 0 rgba(0, 0, 0, 0.28);
  }
  .p.ov.sel {
    box-shadow: none;
  }
  .up .p,
  .dn .p {
    flex: 0 0 38px;
  }
  .dd {
    font-size: 15px;
    font-weight: 600;
    line-height: 1.1;
  }
  .dm {
    font-size: 11px;
    line-height: 1;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .dm i {
    font-style: normal;
  }
  /* Receded rows drop to day + code. */
  .up .dm,
  .dn .dm {
    display: none;
  }
  .mf {
    display: none;
  }
  .p.sel .ms {
    display: none;
  }
  .p.sel .mf {
    display: inline;
  }
  .cdc {
    font-size: 11px;
    font-weight: 600;
    line-height: 1.1;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .cty {
    display: none;
    font-size: 9px;
    line-height: 1.05;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    margin-top: 1px;
  }
  .p.sel .cty {
    display: block;
  }
  /* Text tightens as the overlap step narrows. */
  .p.t1 .dd {
    font-size: 13px;
  }
  .p.t1 .dm {
    font-size: 10px;
  }
  .p.t1 .cdc {
    font-size: 10px;
    letter-spacing: -0.2px;
  }
  .p.t2 {
    padding-left: 0;
    padding-right: 0;
  }
  .p.t2 .dd {
    font-size: 13px;
  }
  .p.t2 .dm {
    font-size: 9px;
  }
  .p.t2 .cdc {
    font-size: 9px;
    letter-spacing: -0.4px;
  }
  .mt {
    font-size: 11px;
    color: var(--text-muted, #8a887f);
    margin: 0 auto;
    align-self: center;
  }
  .crw {
    height: 7px;
    position: relative;
  }
  .crt {
    position: absolute;
    top: 0;
    width: 0;
    height: 0;
    border-left: 6px solid transparent;
    border-right: 6px solid transparent;
    border-bottom: 7px solid var(--surface-1, #f1efe9);
    transition: left 0.3s;
  }
</style>
