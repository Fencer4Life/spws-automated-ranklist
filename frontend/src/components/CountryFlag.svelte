{#if svg}
  <span
    class="flag"
    class:sm={size === 'sm'}
    role="img"
    aria-label={label ?? code ?? ''}
    title={label ?? code ?? ''}
  >
    <svg viewBox="0 0 512 512" aria-hidden="true" focusable="false">
      <!-- eslint-disable-next-line svelte/no-at-html-tags -->
      {@html svg}
    </svg>
  </span>
{/if}

<script module lang="ts">
  let flagSeq = 0
  function nextFlagId(): number {
    return ++flagSeq
  }
</script>

<script lang="ts">
  // Circular country flags for the calendar card — ADR-084 §15.
  //
  // This replaced ~350 lines of hand-drawn CSS/SVG geometry, and the reason is
  // that hand-drawing produced WRONG flags, quietly. Three were found by eye in
  // one sitting out of about sixty-six drawn:
  //   * CH rendered as a Danish cross. The Swiss cross is free-standing and
  //     inset — arms stopping short of the edges — and the flag is SQUARE, so a
  //     19x13 box gave it unequal 3.1px/4.6px arms as well.
  //   * GE rendered as England: a plain red cross on white. Georgia's four
  //     Bolnisi crosses are the only thing separating the two.
  //   * GR rendered as nine bare stripes with its canton missing, which in a
  //     circle is indistinguishable from any other striped flag.
  // Each was live on an event the calendar actually shows — Lausanne, Tbilisi,
  // Athens — and each was caught only because someone recognised the wrong
  // country.
  //
  // The old component also carried a deliberate coverage gap: flags bearing a
  // coat of arms, star, crescent, hoist triangle or canton were ABSENT rather
  // than approximated, and several stripe-only pairs (Italy/Mexico,
  // Ireland/Côte d'Ivoire, Romania/Chad, Monaco/Indonesia) were acknowledged as
  // indistinguishable. All 265 ISO-3166 alpha-2 countries are drawn correctly
  // now, which matters because championships move: the calendar already reaches
  // Toronto and Tbilisi, and scoping the set to countries currently in the
  // database would fail the first time one goes somewhere new.
  //
  // Circular, not rectangular, so there is no aspect ratio to force a square
  // flag into.
  //
  // Still INLINE rather than fetched, and that constraint is real even though
  // the old comment mis-cited it: `vite.config.ce.ts` sets no `base`, so an
  // emitted asset URL resolves against the HOST page inside a custom element on
  // a third-party site and 404s. (ADR-007 was cited for a CSP that blocks
  // fetched assets; ADR-007 is "Shadow DOM (Implemented M8)" and says nothing
  // about CSP, and no CSP exists in the repo. The base problem is the real one.)
  import { FLAG_SVG } from '../lib/flags.generated'

  let {
    code = null,
    label = null,
    size = 'md',
  }: {
    /** ISO-3166 alpha-2, from `countryCode()`. Unlisted or null renders nothing. */
    code?: string | null
    /** Accessible name — the translated country name. Falls back to the code. */
    label?: string | null
    size?: 'sm' | 'md'
  } = $props()

  // Every source file reuses `mask id="a"`, so two flags on one page would
  // collide and one would render unmasked. Each instance gets its own suffix.
  const uid = `f${nextFlagId()}`

  const svg = $derived(
    code ? (FLAG_SVG[code.toUpperCase()]?.replaceAll('__ID__', uid) ?? null) : null,
  )
</script>

<style>
  /* Square, because the artwork is a disc. The old chip was 19x13 to imitate a
     rectangular flag, which is exactly what made Switzerland wrong. */
  .flag {
    display: inline-block;
    width: 18px;
    height: 18px;
    flex: 0 0 18px;
    vertical-align: -4px;
  }
  .flag.sm {
    width: 14px;
    height: 14px;
    flex-basis: 14px;
  }
  .flag svg {
    display: block;
    width: 100%;
    height: 100%;
  }
</style>
