<div class="vp" bind:this={viewportEl}>
  <div
    class="drum"
    class:anim={animate}
    style:transform={`translateZ(${-DRUM_R}px) rotateX(${-active * ROW_ANGLE}deg)`}
  >
    {#each rows as row, qi (row.key)}
      {@const state = rowState(qi)}
      {@const layout = qi === active ? midLayout : null}
      <!-- Only a receded row is a control: tapping it rotates it to centre.
           The focused row is not interactive as a whole — its panels are — so it
           carries neither a role nor a tab stop. -->
      {@const rotatable = state === 'up' || state === 'dn'}
      <div
        class="ln {state}"
        style:transform={`rotateX(${qi * ROW_ANGLE}deg) translateZ(${DRUM_R}px)`}
        style:opacity={rowOpacity(qi)}
        style:pointer-events={Math.abs(qi - active) * ROW_ANGLE > HORIZON ? 'none' : null}
        role="button"
        tabindex={rotatable ? 0 : undefined}
        aria-disabled={rotatable ? undefined : 'true'}
        aria-label={row.label}
        onclick={() => rotateTo(qi)}
        onkeydown={(e) => onRowKey(e, qi)}
      >
        <!-- The engraved seam: row label, a hairline, and the season code.
             The code shows on the focused row and permanently on a season
             boundary, whose rule is also drawn heavier — this is where the
             deleted season dropdown's information went. -->
        {#if showJumpOn === state}
          <!-- Jump back to where the drum opens. It rides the receded row in
               the DIRECTION the drum has to roll, so its position already
               carries that cue; the leading arrow makes the button read as a
               destination — "→ to the nearest competition" — rather than as a
               label for the row it happens to sit on.

               The arrow is an aria-hidden SVG, not a character in the
               translated string. A screen reader announces the button by its
               label alone, which is the useful half. Drawn rather than typed
               because "→" renders at whatever weight and baseline the system
               font decides — it sat visibly low against an 11px cap height and
               did not match the label's stroke. The path inherits
               `currentColor`, so it tracks the accent through both themes.

               stopPropagation because the row underneath is itself a tap target
               that rotates one step — without it, the jump and a single step
               would fight over the same tap. -->
          <button
            class="jmp"
            type="button"
            onclick={(e) => {
              e.stopPropagation()
              jumpToAnchor()
            }}
          ><svg class="arw" viewBox="0 0 16 16" aria-hidden="true" focusable="false"
            ><path
              d="M2.5 8h10M8.75 4.25 12.5 8l-3.75 3.75"
              fill="none"
              stroke="currentColor"
              stroke-width="2"
              stroke-linecap="round"
              stroke-linejoin="round"
            /></svg
          >{t('calendar_jump_to_next')}</button>
        {/if}
        <div class="sm" class:bd={row.isSeasonBoundary}>
          <b>{seamLabel(row)}</b>
          <i></i>
          <em>{seamSeason(qi, row)}</em>
        </div>

        <div class="rw">
          {#if row.isEmpty}
            <span class="mt">{t('calendar_empty_quarter')}</span>
          {:else}
            <div class="rwi" style:gap={layout?.overlapping ? '0px' : null}>
              {#each row.events as event, j (event.id_event)}
                {@const place = layout?.panels[j]}
                {@const isSelected = qi === active && liveSelected === j}
                <button
                  type="button"
                  class="p {panelType(event.txt_code)}"
                  class:past={eventTimeState(event) === 'past'}
                  class:soon={eventTimeState(event) === 'soon'}
                  class:nx={isNext(event)}
                  class:sel={isSelected}
                  class:ov={layout?.overlapping ?? false}
                  class:t1={place?.textTier === 1}
                  class:t2={place?.textTier === 2}
                  class:canc={event.enum_status === 'CANCELLED'}
                  class:regopen={isRegistrationOpen(event)}
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
                  <span class="cdc"
                    >{labelParts(event.txt_code).alpha}{#if labelParts(event.txt_code).num}<i
                        class="cdn">{labelParts(event.txt_code).num}</i>{/if}</span
                  >
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
    <div class="crt {caretType}" style:left={`${caretLeft}px`}></div>
  {/if}
</div>

<script lang="ts">
  // The rotating three-row row barrel — ADR-084 §§1-7.
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
    settleRow,
    eventTimeState,
    isRegistrationOpen,
    splitLocation,
    type MonthRow,
    type RowLayout,
  } from '../lib/calendarMonths'

  /** Must match `.ln` height in the stylesheet. */
  const ROW_H = 82

  /* ===== True-cylinder geometry ============================================
     Each row sits on the surface of a cylinder — `rotateX(i·θ) translateZ(R)`
     — and the drum rotates as one body. Foreshortening at the rim, the
     compression of spacing toward the horizon and rows turning away from the
     viewer all fall out of the perspective projection rather than being drawn.

     R is fixed by θ and the row height: the chord between two adjacent rows
     must equal ROW_H, so R = (ROW_H/2) / tan(θ/2).

     A row's own angle NEVER changes — only the drum's does. That matters: a
     CSS transition cannot animate across replaced nodes, so a drum whose rows
     were re-transformed on every rotate would snap rather than turn. Svelte
     keys the each-block on `row.key`, so the nodes persist.

     θ = 26° puts seven rows inside the 80° horizon (5 at 34°, 9 at 18°).

     Time runs UPWARD: the future sits above the focused row and the past below
     it. A point at angle θ on the cylinder is at y = -R·sin θ, so a positive
     angle lifts a row up the screen, and rows are laid out in chronological
     index order — which puts later months higher.

     This inverts the flat drum, where `.ln.up` was `active - 1` and the past
     sat above. It is deliberate: you rotate a physical drum forward to bring
     what is coming toward you, and the events that matter are ahead, so the
     drum surfaces them by turning up rather than down. */
  const ROW_ANGLE = 26
  const HORIZON = 80
  const DRUM_R = Math.round(ROW_H / 2 / Math.tan((ROW_ANGLE / 2) * (Math.PI / 180)))

  /**
   * The drum must ARRIVE at its opening angle, not travel to it.
   *
   * Rotation is `-active × θ`, so opening on row 56 of 66 is
   * `rotateX(-1456deg)` — four complete turns. With the transition live from
   * the first paint the drum spins through every one of them before settling,
   * which looks broken. Animation is therefore enabled only after the opening
   * frame; from then on a step between adjacent rows is 26deg and animates
   * normally.
   *
   * A timeout rather than requestAnimationFrame: rAF never fires in a
   * background tab, which would strand the transition permanently off.
   */
  let animate = $state(false)
  $effect(() => {
    const id = setTimeout(() => { animate = true }, 0)
    return () => clearTimeout(id)
  })

  /** Rows fade toward the rim and vanish past the horizon. */
  function rowOpacity(qi: number): number {
    const delta = Math.abs(qi - active) * ROW_ANGLE
    if (delta > HORIZON) return 0
    if (delta === 0) return 1
    return Math.max(0, Math.cos((delta * Math.PI) / 180) * 0.9)
  }

  let {
    rows,
    anchorIndex = 0,
    nextUpcoming = null,
    onselect,
  }: {
    rows: MonthRow[]
    anchorIndex?: number
    nextUpcoming?: CalendarEvent | null
    onselect?: (event: CalendarEvent) => void
  } = $props()

  let viewportEl = $state<HTMLElement | null>(null)
  let available = $state(0)
  let active = $state(0)
  /** Index within the focused row's events, or null when the row is empty. */
  let selected = $state<number | null>(null)

  /**
   * The selection, clamped to the row it is actually being read against.
   *
   * `selected` is an index into the focused row's events, and the events can be
   * replaced under it — an admin save refills the calendar, and a month that
   * held four events can come back holding one while the fourth is still
   * selected. Everything below reads the row THROUGH this, so a stale index
   * lands on the last event rather than off the end.
   *
   * It matters because these readers are `$derived`, evaluated during render
   * and before any effect can re-anchor: on 2026-09-02 an out-of-range index
   * threw out of `midLayout`, which tears down the component tree. The page
   * kept running and stopped responding to everything — the hamburger too —
   * until it was reloaded.
   */
  const liveSelected = $derived.by((): number | null => {
    const count = rows[active]?.events.length ?? 0
    if (count === 0) return null
    return Math.min(selected ?? 0, count - 1)
  })

  let initKey = ''

  // Re-anchor when the data or the resolved anchor changes, but never in
  // response to the user's own selection.
  $effect(() => {
    const key = `${rows.length}:${rows[0]?.key ?? ''}:${anchorIndex}`
    if (key === initKey) return
    initKey = key
    active = Math.max(0, Math.min(rows.length - 1, anchorIndex))
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
    const events = rows[qi]?.events ?? []
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
  /**
   * Rotate to a row, skipping quiet months.
   *
   * Monthly seams materialise a row for every calendar month, so the drum now
   * meets long runs of empty ones — 18 of 66 on the current PROD pool, against
   * a handful at quarterly. It renders them, but never comes to REST on one:
   * `settleRow` carries on in the direction of travel until it reaches a month
   * that actually holds something, and reverses at the end of the drum rather
   * than falling off.
   */
  function rotateTo(qi: number): void {
    if (qi === active) return
    const settled = settleRow(rows, qi, qi > active ? 1 : -1)
    if (settled === active) return
    active = settled
    selectDefault(settled)
  }

  function onRowKey(event: KeyboardEvent, qi: number): void {
    if (event.key === 'Enter' || event.key === ' ') {
      event.preventDefault()
      rotateTo(qi)
    }
  }

  /**
   * Tap a panel: bring its row to centre if it is not there already, and select
   * THAT panel.
   *
   * It used to rotate and then fall back to the row's default — the ringed
   * next-upcoming, else the first event — which discarded the one thing the tap
   * had already said. Tapping the third event in a receded row and landing on
   * the first is a small, repeated annoyance: you have to tap twice to reach
   * what you aimed at.
   *
   * Tapping the row BODY still uses the default (`rotateTo`), because no event
   * was named there.
   */
  /**
   * Which receded row carries the jump control, or '' when the drum is already
   * where it opens.
   *
   * Index order is chronological, and the cylinder puts LATER months higher up
   * the screen — so `dn` (active + 1) renders above and `up` (active - 1)
   * below. An anchor ahead of the focused row therefore lives on `dn`.
   *
   * The destination is `anchorIndex`, NOT the month containing today: today's
   * month is frequently empty — August 2026 holds no events at all — and the
   * drum never rests on an empty row, so a literal "jump to today" would land
   * somewhere it immediately rolls off.
   */
  const showJumpOn = $derived(
    anchorIndex === active || !rows[anchorIndex] ? '' : anchorIndex > active ? 'dn' : 'up',
  )

  /**
   * Instant, not animated. Rotation is `-active × θ`, so crossing forty rows is
   * over a thousand degrees — nearly three full turns of spinning before it
   * settles, the same failure the opening frame has to avoid.
   */
  function jumpToAnchor(): void {
    if (!rows[anchorIndex]) return
    animate = false
    active = settleRow(rows, anchorIndex, anchorIndex > active ? 1 : -1)
    selectDefault(active)
    setTimeout(() => { animate = true }, 0)
  }

  function pick(qi: number, j: number): void {
    if (qi !== active) {
      // settleRow can land elsewhere if the target row is empty; a panel tap
      // means it is not, but if that ever changes the row default is the only
      // sane fallback — index j would point into a different month's events.
      const settled = settleRow(rows, qi, qi > active ? 1 : -1)
      active = settled
      if (settled !== qi) {
        selectDefault(settled)
        return
      }
    }
    selected = j
    const event = rows[qi]?.events[j]
    if (event) onselect?.(event)
  }

  function isNext(event: CalendarEvent): boolean {
    return nextUpcoming != null && nextUpcoming.id_event === event.id_event
  }

  /**
   * The tile's location line is a city or nothing — never a guessed venue.
   * txt_location sometimes holds a venue-only string the scraper wrote into
   * it ("Sporthalle der Städtischen Berufsschule"), which splitLocation()
   * correctly classifies as venue rather than city. Printing that guess in an
   * 11px tile line used to be the only place it showed at all; now that every
   * event can carry a real txt_venue_address (the PZSz komunikat enrichment,
   * and EVF's existing address field), the venue has a proper home on the
   * card's address line and the tile no longer needs to fall back to it.
   */
  function cityOf(event: CalendarEvent): string {
    return splitLocation(event.txt_location).city
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
   * The seam names the month on its own, so Polish needs the NOMINATIVE
   * ("Wrzesień") from `month_N`. The tile prints a day beside the month and so
   * needs the GENITIVE ("26 września") from `cal_month_N` — which is what
   * monthShort/monthFull above return. English collapses the distinction, so
   * the two only diverge in Polish, and using one form for both is visibly
   * wrong there.
   */
  function seamLabel(row: MonthRow): string {
    return `${t(`month_${row.month}`)} ${row.year}`
  }

  /**
   * The series number, split out so it can be set in a monospace face.
   * At 11px in the UI sans "EVF5" reads as "EVFS", and every EVF code ends in
   * weapon letters (e, f, s), so a trailing S is a plausible parse rather than
   * merely an odd glyph. Tabular figures remove the ambiguity.
   */
  function labelParts(code: string): { alpha: string; num: string } {
    const label = panelLabel(code)
    const m = /^(\D+)(\d*)$/.exec(label)
    return { alpha: m?.[1] ?? label, num: m?.[2] ?? '' }
  }

  /**
   * The season code is engraved on the focused row and permanently on a
   * boundary seam. A row holding two seasons is marked, because CERT really
   * does contain them.
   */
  function seamSeason(qi: number, row: MonthRow): string {
    if (qi !== active && !row.isSeasonBoundary) return ''
    const codes = row.seasonCodes
    if (codes.length === 0) return ''
    const short = seasonShortCode(codes[codes.length - 1])
    return codes.length > 1 ? `${short} *` : short
  }

  const midLayout = $derived.by((): RowLayout | null => {
    const row = rows[active]
    if (!row || row.events.length === 0) return null
    // Before measurement — and in jsdom, which has no layout engine and reports
    // every clientWidth as 0 — fall back to a flat row with no inline geometry.
    if (available <= 0) return null
    const index = liveSelected ?? 0
    const event = row.events[index]
    return layoutRow({
      count: row.events.length,
      selectedIndex: index,
      available,
      selectedHasCity: !!event && !!cityOf(event),
    })
  })

  /** How far the focused row is scrolled — 0 unless its content overflows. */
  const scroll = $derived.by(() => {
    const layout = midLayout
    return layout ? rowScroll(layout, liveSelected, available) : 0
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
  /**
   * The caret takes the SELECTED event's organizer hue, matching the coloured
   * top edge of the card below it, so the two read as one edge tapering to a
   * point at the tile the card is showing.
   *
   * It used to be drawn in `--surface-1` — the card's background. Against the
   * page that is a pale triangle sitting directly above a 3px coloured edge,
   * which reads as a smudge rather than a pointer, and the thing that ties the
   * two halves of the calendar together went unnoticed.
   */
  const caretType = $derived.by((): string => {
    const events = rows[active]?.events ?? []
    const event = liveSelected != null ? events[liveSelected] : undefined
    return event ? panelType(event.txt_code) : ''
  })

  const caretLeft = $derived.by((): number | null => {
    const layout = midLayout
    if (!layout) return null
    return caretOffset(layout, liveSelected, available)
  })
</script>

<style>
  .vp {
    height: 246px;
    overflow: hidden;
    perspective: 760px;
    margin-top: 6px;
    position: relative;
  }
  /* The drum turns as one body; rows hold their own fixed angle on its surface.
     No overshoot and no motion blur — both were tried and both made the
     rotation feel wrong. A plain decelerate reads as a quiet mechanical step. */
  .drum {
    position: absolute;
    inset: 0;
    transform-style: preserve-3d;
  }
  .drum.anim {
    transition: transform 0.42s cubic-bezier(0.22, 0.61, 0.36, 1);
  }
  @media (prefers-reduced-motion: reduce) {
    .drum.anim {
      transition: none;
    }
  }
  .ln {
    position: absolute;
    left: 0;
    right: 0;
    top: 50%;
    margin-top: -41px;
    height: 82px;
    backface-visibility: hidden;
    /* Anchored left, not centre: the receded rows are scaled to 0.88, and a
       centre origin would inset them from the left edge by ~6% of the row —
       so the rows would no longer share a left edge. */
    transition: opacity 0.3s linear;
    cursor: pointer;
    border: none;
    background: none;
    padding: 0;
    text-align: left;
    width: 100%;
  }
  /* Facing angle and opacity are now inline, computed from the row's place on
     the cylinder. `.up`/`.dn`/`.far` survive only as behavioural hooks. */
  .ln.far {
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
    position: relative;
    overflow: hidden;
  }
  .p > * {
    flex: 0 0 auto;
  }
  /* ===== The inverted palette — treatment B, "edge-coded" ==================
     Time drives the BODY: an upcoming event is tinted, an imminent one is
     saturated, a past one goes neutral grey. Organizer drives a 3px TOP EDGE
     and nothing else.

     This is the reverse of the original barrel, which filled on
     `enum_status === 'COMPLETED'`. On the PROD pool that is 67 of 114 events,
     so the entire colour budget went to the finished majority while the events
     you can still enter rendered as plain white. Hue now means "how soon", and
     organizer keeps a channel of its own rather than sharing one with time —
     which is what ADR-084 set out to do before tying fill to status.

     A past tile loses its hue on purpose. The type stays legible in the label
     (`PPW1`, `EVF3`), and past events are the ones nobody scans. */
  .p {
    background: var(--surface-2, #fff);
    color: var(--text-primary, #1c1b19);
  }
  .p::before {
    content: '';
    position: absolute;
    top: 0;
    left: 0;
    right: 0;
    height: 3px;
    background: var(--org, #6f7d8f);
  }
  .p.ppw,
  .p.mpw {
    --org: #2e7d52;
    background: #eef7f1;
  }
  .p.pew {
    --org: #1f6fb0;
    background: #ecf4fc;
  }
  .p.int {
    --org: #b1791d;
    background: #fdf3e2;
  }
  /* PZSz's own brand red is #c72626, desaturated here so it sits in the same
     tonal family as the three above rather than shouting over them. */
  .p.pzs {
    --org: #c05555;
    background: #fdf0f0;
  }
  /* Imminent — inside seven days. The saturated step, so the row a fencer has
     to act on this week is the loudest thing on the drum. */
  .p.soon.ppw,
  .p.soon.mpw {
    background: #cfe8d9;
  }
  .p.soon.pew {
    background: #d4e6f7;
  }
  .p.soon.int {
    background: #fbe9c4;
  }
  .p.soon.pzs {
    background: #f7d5d5;
  }
  /* Past — more than thirty days finished. Neutral, and the organizer edge
     desaturates with it so the row recedes as one object. */
  .p.past {
    background: var(--surface-1, #f1efe9);
    color: var(--text-muted, #8a887f);
  }
  .p.past::before {
    background: #c3c8cf;
  }
  .p.canc {
    opacity: 0.45;
  }
  .p.canc .dd {
    text-decoration: line-through;
  }
  /* Ring carries next-upcoming. */
  .p.nx {
    border: 2px solid var(--accent, #185fa5);
  }
  .p.sel {
    outline: 2px solid var(--text-primary, #1c1b19);
    outline-offset: 1px;
  }
  /* Registration is live — ADR-030. Top-right, clear of the organizer edge. */
  .p.regopen::after {
    content: '';
    position: absolute;
    top: 5px;
    right: 3px;
    width: 6px;
    height: 6px;
    border-radius: 50%;
    background: var(--accent, #185fa5);
    box-shadow: 0 0 0 1.5px var(--surface-2, #fff);
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
  /* The selected tile alone widens to fit the full month. Polish genitive
     "października" measures 72px at 11px/700 — far longer than the next longest
     ("listopada", 52px) and than English ("September", 62px). Widening every
     tile to fit it would put four of them over a 320px viewport; widening only
     the selected one keeps the worst case at 3x68 + 78 + gaps = 291px. */
  .p {
    flex: 0 0 68px;
  }
  .p.sel {
    flex: 0 0 78px;
  }
  .dd {
    font-size: 15px;
    font-weight: 600;
    line-height: 1.1;
  }
  .dm {
    font-size: 11px;
    /* The month is what the seam is now organised around, so it should not be
       the faintest thing on the tile. */
    font-weight: 700;
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
  /* The series number is monospace with tabular figures. At 11px in the UI sans
     "EVF5" reads as "EVFS", and every EVF code ends in weapon letters (e, f, s)
     so a trailing S is a plausible parse rather than merely an odd glyph. */
  .cdn {
    font-family: ui-monospace, SFMono-Regular, Menlo, Consolas, monospace;
    font-variant-numeric: tabular-nums;
    font-style: normal;
    font-weight: 700;
    font-size: 10px;
    margin-left: 1px;
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
  /* City shows on every FOCUSED tile, not only the selected one. A monthly row
     holds at most four events on the current pool, against up to nine at
     quarterly, so there is finally room for it. Receded rows still drop to
     day + code. */
  .cty {
    font-size: 9px;
    line-height: 1.05;
    max-width: 100%;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    margin-top: 1px;
  }
  .up .cty,
  .dn .cty {
    display: none;
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
  /* Distinct enough not to be mistaken for the row it sits on, and a real hit
     area rather than a text link — this appears exactly when someone is already
     lost in the drum. */
  .jmp {
    position: absolute;
    right: 0;
    top: -2px;
    z-index: 10;
    display: inline-flex;
    align-items: center;
    gap: 5px;
    font-size: 11px;
    font-weight: 600;
    line-height: 1;
    padding: 5px 10px;
    border-radius: 12px;
    border: 1px solid var(--accent, #185fa5);
    background: var(--surface-2, #fff);
    color: var(--accent, #185fa5);
    cursor: pointer;
    white-space: nowrap;
  }
  /* Sized to the label's cap height rather than its font size, so the icon
     reads as the same weight as the text beside it. */
  .arw {
    width: 11px;
    height: 11px;
    flex: 0 0 11px;
  }
  .mt {
    font-size: 11px;
    color: var(--text-muted, #8a887f);
    margin: 0 auto;
    align-self: center;
  }
  .crw {
    height: 8px;
    position: relative;
  }
  .crt {
    position: absolute;
    top: 0;
    width: 0;
    height: 0;
    /* Wider and taller than the original 6/7: it has to carry across the gap
       between the drum and the card and be seen doing it. */
    border-left: 8px solid transparent;
    border-right: 8px solid transparent;
    border-bottom: 8px solid var(--caret, #6f7d8f);
    transition:
      left 0.3s,
      border-bottom-color 0.3s;
  }
  .crt.ppw,
  .crt.mpw {
    --caret: #2e7d52;
  }
  .crt.pew {
    --caret: #1f6fb0;
  }
  .crt.int {
    --caret: #b1791d;
  }
  .crt.pzs {
    --caret: #c05555;
  }
</style>
