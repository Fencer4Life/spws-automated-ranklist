{#if spec}
  <span
    class="flag"
    class:sm={size === 'sm'}
    role="img"
    aria-label={label ?? code ?? ''}
    title={label ?? code ?? ''}
  >
    {#if spec.kind === 'art' && spec.art === 'greece'}
      <svg class="art" viewBox="0 0 27 18" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="27" height="18" fill="#0D5EAF" />
        <rect y="2" width="27" height="2" fill="#ffffff" />
        <rect y="6" width="27" height="2" fill="#ffffff" />
        <rect y="10" width="27" height="2" fill="#ffffff" />
        <rect y="14" width="27" height="2" fill="#ffffff" />
        <rect width="10" height="10" fill="#0D5EAF" />
        <rect x="4" width="2" height="10" fill="#ffffff" />
        <rect y="4" width="10" height="2" fill="#ffffff" />
      </svg>
    {:else if spec.kind === 'art' && spec.art === 'croatia'}
      <svg class="art" viewBox="0 0 60 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="60" height="13.34" fill="#FF0000" />
        <rect y="13.34" width="60" height="13.33" fill="#ffffff" />
        <rect y="26.67" width="60" height="13.33" fill="#171796" />
        <rect x="24" y="13" width="12" height="14" fill="#ffffff" />
        <rect x="24" y="13" width="6" height="7" fill="#FF0000" />
        <rect x="30" y="20" width="6" height="7" fill="#FF0000" />
      </svg>
    {:else if spec.kind === 'art' && spec.art === 'slovakia'}
      <svg class="art" viewBox="0 0 60 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="60" height="13.34" fill="#ffffff" />
        <rect y="13.34" width="60" height="13.33" fill="#0B4EA2" />
        <rect y="26.67" width="60" height="13.33" fill="#EE1C25" />
        <path d="M14 9 h16 v14 q0 6 -8 9 q-8 -3 -8 -9 z" fill="#EE1C25" />
        <rect x="20" y="12" width="4" height="17" fill="#ffffff" />
        <rect x="16" y="16" width="12" height="3" fill="#ffffff" />
        <rect x="15" y="22" width="14" height="3" fill="#ffffff" />
      </svg>
    {:else if spec.kind === 'art' && spec.art === 'slovenia'}
      <svg class="art" viewBox="0 0 60 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="60" height="13.34" fill="#ffffff" />
        <rect y="13.34" width="60" height="13.33" fill="#0000FF" />
        <rect y="26.67" width="60" height="13.33" fill="#FF0000" />
        <path d="M10 7 h16 v11 q0 5 -8 8 q-8 -3 -8 -8 z" fill="#0000FF" stroke="#FF0000" stroke-width="1.4" />
        <path d="M18 10 l6 8 h-12 z" fill="#ffffff" />
      </svg>
    {:else if spec.kind === 'art' && spec.art === 'serbia'}
      <svg class="art" viewBox="0 0 60 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="60" height="13.34" fill="#C6363C" />
        <rect y="13.34" width="60" height="13.33" fill="#0C4076" />
        <rect y="26.67" width="60" height="13.33" fill="#ffffff" />
        <path d="M14 10 h14 v12 q0 5 -7 8 q-7 -3 -7 -8 z" fill="#C6363C" stroke="#ffffff" stroke-width="1.2" />
        <rect x="19" y="13" width="4" height="14" fill="#ffffff" />
        <rect x="15" y="17" width="12" height="3" fill="#ffffff" />
      </svg>
    {:else if spec.kind === 'art' && spec.art === 'portugal'}
      <svg class="art" viewBox="0 0 60 40" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <rect width="24" height="40" fill="#046A38" />
        <rect x="24" width="36" height="40" fill="#DA291C" />
        <circle cx="24" cy="20" r="9" fill="none" stroke="#FFE900" stroke-width="2.4" />
        <rect x="20" y="16" width="8" height="9" fill="#ffffff" stroke="#DA291C" stroke-width="1.2" />
      </svg>
    {:else if spec.kind === 'union'}
      <!-- Authored inline, not fetched: a request would be blocked by the
           embed's CSP, and a document-relative <img src> resolves against the
           host page (the bug latent in SPWS-logo.png). -->
      <svg class="art" viewBox="0 0 60 30" preserveAspectRatio="none" aria-hidden="true" focusable="false">
        <clipPath id={`uj-${uid}`}>
          <path d="M30,15 h30 v15 z v15 h-30 z h-30 v-15 z v-15 h30 z" />
        </clipPath>
        <rect width="60" height="30" fill="#012169" />
        <path d="M0,0 L60,30 M60,0 L0,30" stroke="#ffffff" stroke-width="6" />
        <path
          d="M0,0 L60,30 M60,0 L0,30"
          clip-path={`url(#uj-${uid})`}
          stroke="#C8102E"
          stroke-width="4"
        />
        <path d="M30,0 v30 M0,15 h60" stroke="#ffffff" stroke-width="10" />
        <path d="M30,0 v30 M0,15 h60" stroke="#C8102E" stroke-width="6" />
      </svg>
    {:else}
      {#each bands as band}
        <span class="band" style={band}></span>
      {/each}
    {/if}
  </span>
{/if}

<script module lang="ts">
  let flagSeq = 0
  function nextFlagId(): number {
    return ++flagSeq
  }
</script>

<script lang="ts">
  // CSS flag chips for the calendar's location line — ADR-084 §15.
  //
  // Why CSS geometry rather than images or emoji (ADR-007): emoji flags are
  // inconsistent on Android and absent on many devices, and the public
  // `spws-calendar` embed runs under a strict CSP where every external asset is
  // one more thing that can fail to load.
  //
  // SCOPE — only flags this component draws CORRECTLY.
  // Four primitives: stripes (optionally weighted), a cross (centred or offset
  // toward the hoist), a plain centred disc, and hand-authored inline SVG for a
  // flag whose geometry the others cannot express. A flag is listed only when
  // one of those reproduces it exactly.
  //
  // Flags carrying a coat of arms, star, crescent, hoist triangle or canton are
  // deliberately ABSENT rather than approximated. An unlisted code renders
  // nothing, and EventCard then shows the place without a flag — the designed
  // fallback, and better than a wrong flag. Note the consequence: a few
  // stripe-only pairs are genuinely indistinguishable at chip size (Italy/
  // Mexico, Ireland/Côte d'Ivoire, Romania/Chad, Monaco/Indonesia), so the
  // emblem-bearing member of each pair is the one omitted.
  //
  // On inline SVG vs an image: an image is not forbidden because it is an
  // image, but because of HOW it would have to be referenced. A runtime fetch
  // is blocked by the embed's CSP (ADR-007). A bundled `<img src="x.png">` is
  // document-relative, so inside a custom element on a third-party page it
  // resolves against the HOST's URL and 404s — the bug already latent in
  // `SPWS-logo.png`. Inline SVG has neither problem, costs no request, and is
  // authored here rather than downloaded, so its provenance is not in question.

  type FlagSpec =
    | { kind: 'h' | 'v'; colors: string[]; weights?: number[] }
    | { kind: 'cross'; base: string; cross: string; offset?: boolean; inner?: string }
    | { kind: 'disc'; base: string; color: string; cx?: number; r?: number }
    | { kind: 'union' }
    /**
     * Hand-drawn. Two reasons an entry lands here:
     *
     * 1. The geometry has no band equivalent (Greece's canton, the Union
     *    saltire).
     * 2. Bands alone would COLLIDE with another country. Croatia is red/white/
     *    blue exactly like the Netherlands, and Slovakia and Slovenia are
     *    white/blue/red exactly like Russia — the emblem is the only thing that
     *    tells them apart, so drawing a reduced form of it is what makes the
     *    flag correct rather than merely present.
     *
     * The emblems here are REDUCED, not faithful: a two-square checker for
     * Croatia's chequy, a cross-on-shield for Slovakia, a Triglav triangle for
     * Slovenia, a ring-and-shield for Portugal's armillary sphere. At 19x13 a
     * faithful coat of arms is sub-pixel; the job of the mark is to
     * disambiguate, and it is sized to do that and nothing more.
     */
    | {
        kind: 'art'
        art: 'greece' | 'croatia' | 'slovakia' | 'slovenia' | 'serbia' | 'portugal'
      }

  const W = '#ffffff'

  const h = (...colors: string[]): FlagSpec => ({ kind: 'h', colors })
  const v = (...colors: string[]): FlagSpec => ({ kind: 'v', colors })
  const hw = (colors: string[], weights: number[]): FlagSpec => ({ kind: 'h', colors, weights })
  const vw = (colors: string[], weights: number[]): FlagSpec => ({ kind: 'v', colors, weights })
  /** Cross offset toward the hoist, as on every Nordic flag. */
  const nordic = (base: string, cross: string, inner?: string): FlagSpec => ({
    kind: 'cross',
    base,
    cross,
    offset: true,
    inner,
  })
  const cross = (base: string, c: string): FlagSpec => ({ kind: 'cross', base, cross: c })

  const FLAGS: Record<string, FlagSpec> = {
    // --- Nordic (offset) crosses -----------------------------------------
    DK: nordic('#C60C30', W),
    SE: nordic('#006AA7', '#FECC00'),
    NO: nordic('#BA0C2F', W, '#00205B'),
    FI: nordic(W, '#003580'),
    IS: nordic('#02529C', W, '#DC1E35'),
    FO: nordic(W, '#0065BD', '#ED2939'),
    AX: nordic('#0053A5', '#FFCE00', '#D21034'),

    // --- Centred crosses --------------------------------------------------
    CH: cross('#DA291C', W),
    GE: cross(W, '#FF0000'),

    // --- Inline SVG -------------------------------------------------------
    // Britain is real EVF data (Guildford, Bath), so "no flag" was a visible
    // cost rather than an acceptable gap. The saltire-over-cross geometry has
    // no band equivalent, so it is drawn.
    GB: { kind: 'union' },
    GR: { kind: 'art', art: 'greece' },
    HR: { kind: 'art', art: 'croatia' },
    SK: { kind: 'art', art: 'slovakia' },
    SI: { kind: 'art', art: 'slovenia' },
    RS: { kind: 'art', art: 'serbia' },
    PT: { kind: 'art', art: 'portugal' },

    // --- Plain field + plain disc ----------------------------------------
    // Only where the field really is plain. Laos is deliberately absent: its
    // disc sits over red/blue/red stripes, which this primitive cannot express,
    // and a plain blue field with a white disc is simply a different flag.
    JP: { kind: 'disc', base: W, color: '#BC002D', r: 30 },
    BD: { kind: 'disc', base: '#006A4E', color: '#F42A41', cx: 45, r: 32 },
    PW: { kind: 'disc', base: '#4AADD6', color: '#FFDE00', cx: 42, r: 30 },

    // --- Horizontal stripes -----------------------------------------------
    AT: h('#ED2939', W, '#ED2939'),
    DE: h('#000000', '#DD0000', '#FFCE00'),
    HU: h('#CD2A3E', W, '#436F4D'),
    NL: h('#AE1C28', W, '#21468B'),
    RU: h(W, '#0039A6', '#D52B1E'),
    PL: h(W, '#DC143C'),
    MC: h('#CE1126', W),
    ID: h('#FF0000', W),
    LI: h('#002B7F', '#CE1126'),
    UA: h('#0057B7', '#FFD700'),
    EE: h('#0072CE', '#000000', W),
    LT: h('#FDB913', '#006A44', '#C1272D'),
    LU: h('#ED2939', W, '#00A1DE'),
    BG: h(W, '#00966E', '#D62612'),
    SM: h(W, '#5EB6E4'),
    AM: h('#D90012', '#0033A0', '#F2A800'),
    RW: h('#00A1DE', '#FAD201', '#20603D'),
    GA: h('#009E60', '#FCD116', '#3A75C4'),
    SL: h('#1EB53A', W, '#0072C6'),
    MU: h('#EA2839', '#1A206D', '#FFD500', '#00A551'),
    BO: h('#D52B1E', '#F9E300', '#007934'),
    HT: h('#00209F', '#D21034'),
    YE: h('#CE1126', W, '#000000'),
    LV: hw(['#9E3039', W, '#9E3039'], [2, 1, 2]),
    ES: hw(['#AA151B', '#F1BF00', '#AA151B'], [1, 2, 1]),
    BY: hw(['#C8313E', '#4AA657'], [2, 1]),
    GI: hw([W, '#DA000C'], [2, 1]),
    CO: hw(['#FCD116', '#003893', '#CE1126'], [2, 1, 1]),
    EC: hw(['#FFDD00', '#034EA2', '#ED1C24'], [2, 1, 1]),
    LY: hw(['#E70013', '#000000', '#239E46'], [1, 2, 1]),
    TH: hw(['#A51931', W, '#2D2A4A', W, '#A51931'], [1, 1, 2, 1, 1]),
    CR: hw(['#002B7F', W, '#CE1126', W, '#002B7F'], [1, 1, 2, 1, 1]),
    GM: hw(['#CE1126', W, '#0C1C8C', W, '#3A7728'], [4, 1, 4, 1, 4]),
    BW: hw(['#6DA9D2', W, '#000000', W, '#6DA9D2'], [3, 1, 2, 1, 3]),

    // --- Vertical stripes -------------------------------------------------
    FR: v('#0055A4', W, '#EF4135'),
    IT: v('#009246', W, '#CE2B37'),
    BE: v('#000000', '#FAE042', '#ED2939'),
    IE: v('#169B62', W, '#FF883E'),
    RO: v('#002B7F', '#FCD116', '#CE1126'),
    NG: v('#008751', W, '#008751'),
    GN: v('#CE1126', '#FCD116', '#009460'),
    ML: v('#14B53A', '#FCD116', '#CE1126'),
    TD: v('#002664', '#FECB00', '#C60C30'),
    PE: v('#D91023', W, '#D91023'),
    CA: vw(['#D80621', W, '#D80621'], [1, 2, 1]),
    BH: vw([W, '#CE1126'], [1, 3]),
    QA: vw([W, '#8A1538'], [1, 2]),
  }

  // A clipPath id must be unique per instance, or several flags on one page
  // would all clip against whichever definition rendered last.
  const uid = nextFlagId()

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

  function offsets(weights: number[]): { start: number; size: number }[] {
    const total = weights.reduce((a, b) => a + b, 0)
    const out: { start: number; size: number }[] = []
    let run = 0
    for (const weight of weights) {
      out.push({ start: (run / total) * 100, size: (weight / total) * 100 })
      run += weight
    }
    return out
  }

  /** Every spec except the hand-drawn ones, which do not use bands. */
  type BandSpec = Exclude<FlagSpec, { kind: 'union' } | { kind: 'art'; art: string }>

  function bandsFor(spec: BandSpec): string[] {
    // Each branch narrows positively. Checking `kind === 'h' || kind === 'v'`
    // first and falling through does not narrow reliably, because that member's
    // own `kind` is a union and TypeScript will not subtract both literals.
    if (spec.kind === 'cross') {
      const arm = spec.offset ? 30 : 38
      const out = [
        `inset:0;background:${spec.base}`,
        `left:0;right:0;top:38%;height:24%;background:${spec.cross}`,
        `top:0;bottom:0;left:${arm}%;width:24%;background:${spec.cross}`,
      ]
      if (spec.inner) {
        out.push(`left:0;right:0;top:45%;height:10%;background:${spec.inner}`)
        out.push(`top:0;bottom:0;left:${arm + 7}%;width:10%;background:${spec.inner}`)
      }
      return out
    }

    if (spec.kind === 'disc') {
      const cx = spec.cx ?? 50
      const r = spec.r ?? 30
      return [
        `inset:0;background:${spec.base}`,
        `left:${cx}%;top:50%;width:${r * 2}%;aspect-ratio:1;transform:translate(-50%,-50%);border-radius:50%;background:${spec.color}`,
      ]
    }

    const horizontal = spec.kind === 'h'
    const weights = spec.weights ?? spec.colors.map(() => 1)
    return offsets(weights).map(({ start, size: extent }, i) =>
      horizontal
        ? `left:0;right:0;top:${start}%;height:${extent}%;background:${spec.colors[i]}`
        : `top:0;bottom:0;left:${start}%;width:${extent}%;background:${spec.colors[i]}`,
    )
  }

  const spec = $derived(code ? (FLAGS[code.toUpperCase()] ?? null) : null)
  const bands = $derived(spec && spec.kind !== 'union' && spec.kind !== 'art' ? bandsFor(spec) : [])
</script>

<style>
  .flag {
    position: relative;
    display: inline-block;
    width: 19px;
    height: 13px;
    flex: 0 0 19px;
    overflow: hidden;
    border-radius: 2px;
    border: 1px solid rgba(0, 0, 0, 0.28);
    vertical-align: -2px;
  }
  .flag.sm {
    width: 14px;
    height: 10px;
    flex-basis: 14px;
  }
  .band {
    position: absolute;
  }
  .art {
    display: block;
    width: 100%;
    height: 100%;
  }
</style>
