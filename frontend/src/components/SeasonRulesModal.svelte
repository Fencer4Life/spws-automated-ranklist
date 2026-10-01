<svelte:window onkeydowncapture={onWindowKeydown} />

{#if open && rules && season}
  <div class="rules-overlay" role="presentation" onclick={onClose}>
    <div class="rules-panel" role="dialog" aria-modal="true" aria-label={title} tabindex="-1" bind:this={dialogEl} onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
      <div class="rules-head">
        <h2 class="rules-title">{title}</h2>
        <div class="rules-actions">
          <LangToggle />
          <button type="button" class="rules-close" aria-label={t('close')} title={t('close_esc')} onclick={onClose}>
            <svg viewBox="0 0 20 20" aria-hidden="true" focusable="false"><path d="M5 5l10 10M15 5 5 15" /></svg>
          </button>
        </div>
        <div class="rules-meta"><b>{season.txt_code}</b><span class="dotsep">·</span>{seasonState}<span class="dotsep">·</span>{t('sr_meta_all')}</div>
      </div>

      <div class="rules-body">
        <!-- The sum, in the table's own column names. -->
        <div class="rules-band">
          {#if full}
            <div class="band-box spws"><span class="band-key">{t('col_spws')}</span><span class="band-sub">{bandText(rules.domestic)}</span></div>
            <span class="band-op" aria-hidden="true">+</span>
            <div class="band-box evf"><span class="band-key">{t('col_evf_plus')}</span><span class="band-sub">{bandText(rules.international)}</span></div>
            <span class="band-op" aria-hidden="true">=</span>
            <div class="band-box total"><span class="band-key">{t('col_total')}</span><span class="band-sub">{t('sr_total_sub')}</span></div>
          {:else}
            <div class="band-box total"><span class="band-key">{t('col_points')}</span><span class="band-sub">{bandText(rules.domestic)}</span></div>
          {/if}
        </div>
        <p class="band-note">{full ? t('sr_ppw_note') : t('sr_ppw_only_note')}</p>

        <div class="pools" class:single={!full}>
          {#each pools as pool (pool.key)}
            <section class="pool" class:pool-evf={pool.key === 'evf'}>
              <h3><span class="pool-key">{pool.label}</span> <small>{pool.title}</small></h3>
              <div class="buckets">
                {#each pool.buckets as bucket, i (i)}
                  <div class="bucket">
                    <div class="bucket-types">
                      {#each bucket.types as type (type)}
                        <span class="type-chip" class:domestic={DOMESTIC.has(type)} class:international={!DOMESTIC.has(type)}>{type}</span>
                      {/each}
                    </div>
                    <div class="bucket-rule" class:always={bucket.always}>{bucketRule(bucket)}</div>
                    <div class="slots" aria-hidden="true">
                      {#each Array.from({ length: slotCount(bucket) }) as _, s (s)}<span class="slot">★</span>{/each}
                    </div>
                  </div>
                {/each}
              </div>
              <ul class="type-names">
                {#each pool.buckets.flatMap((b) => b.types) as type (type)}
                  <li>{t(`legend_${type.toLowerCase()}`)}</li>
                {/each}
              </ul>
              <div class="pool-sum">{t('sr_sum_to')} → <span class="pool-sum-to">{pool.sumTo}</span></div>
            </section>
          {/each}
        </div>

        <div class="facts">
          {#if rules.entry_types?.length}
            <div class="fact" data-fact="entry"><span class="fact-icon" aria-hidden="true">→</span><div><b>{t('sr_who_title')}</b> {t('sr_who', { types: rules.entry_types.join(t('sr_or')) })}</div></div>
          {/if}
          {#if season.bool_active}
            <div class="fact" data-fact="rolling"><span class="fact-icon" aria-hidden="true">↩</span><div><b>{t('sr_roll_title')}</b> {t('sr_roll')}</div></div>
          {/if}
          {#if coefficients}
            <div class="fact" data-fact="coefficients"><span class="fact-icon" aria-hidden="true">×</span><div><b>{t('sr_coef_title')}</b> {t('sr_coef')}
              <div class="coefs">
                {#each shownTypes.filter((type) => coefficients?.[type] != null) as type (type)}
                  <span class="coef">{type} ×{coefficients[type]}</span>
                {/each}
              </div>
            </div></div>
          {/if}
        </div>
      </div>

      <div class="rules-foot">
        <a class="rules-annex" href={assetUrl(`tabela-punktacji.html?lang=${getLocale()}`)} target="_blank" rel="noopener">{t('sr_annex')}</a>
        <span class="star-note"><span class="star" aria-hidden="true">★</span> {t('sr_star_note')}</span>
      </div>
    </div>
  </div>
{/if}

<script module lang="ts">
  /** "SPWS-2026-2027" → "2026/2027" — the season as the link and title name it. */
  export function seasonYears(code: string): string {
    return code.replace(/^SPWS-/, '').replace('-', '/')
  }
</script>

<script lang="ts">
  // The chosen season's ranking rules: which results count and how they add up
  // to the ranklist's columns (doc/mockups/ranking-rules-modal-2026-10-01.html,
  // answered A on 2026-10-01). Everything comes from the season's own
  // definition — its buckets, entry types, publication and coefficients — so
  // the modal cannot drift from the ranking. The modal shell (corner flags,
  // close, Esc, focus, a sticky header on a phone) matches the drilldown's.
  import type { RankingBucket, RankingRules, Season } from '../lib/types'
  import { getLocale, t } from '../lib/locale.svelte'
  // Embedded in WordPress, a bare file name would resolve against the host
  // page; assetUrl resolves it against the published app (D1, 2026-10-01).
  import { assetUrl } from '../lib/assetBase'
  import LangToggle from './LangToggle.svelte'

  let {
    open = false,
    season = null,
    rules = null,
    coefficients = null,
    onclose,
  }: {
    open?: boolean
    season?: Season | null
    rules?: RankingRules | null
    coefficients?: Record<string, number> | null
    onclose?: () => void
  } = $props()

  const DOMESTIC = new Set(['PPW', 'MPW'])

  // A PPW-only season publishes the domestic pool alone (ADR-099).
  let full = $derived(season?.enum_ranking_publication !== 'PPW_ONLY')
  let title = $derived(season ? t('sr_link', { season: seasonYears(season.txt_code) }) : '')
  let seasonState = $derived.by(() => {
    if (!season) return ''
    if (season.bool_active) return t('sr_meta_active')
    return new Date(season.dt_end) < new Date() ? t('sr_meta_past') : t('sr_meta_future')
  })
  let pools = $derived.by(() => {
    if (!rules) return []
    const list = [{ key: 'spws', label: full ? t('col_spws') : 'SPWS', title: t('sr_spws_title'), buckets: rules.domestic, sumTo: full ? t('col_spws') : t('col_points') }]
    if (full) list.push({ key: 'evf', label: t('col_evf_plus'), title: t('sr_evf_title'), buckets: rules.international, sumTo: t('col_evf_plus') })
    return list
  })
  let shownTypes = $derived([...new Set(pools.flatMap((pool) => pool.buckets.flatMap((b) => b.types)))])

  // Polish counts take three forms: 1 najlepszy, 2–4 najlepsze (but 12–14
  // najlepszych), 5+ najlepszych. English needs the same three keys.
  function pluralKey(n: number): 'one' | 'few' | 'many' {
    if (n === 1) return 'one'
    const tens = n % 100
    return n % 10 >= 2 && n % 10 <= 4 && (tens < 12 || tens > 14) ? 'few' : 'many'
  }

  function bucketRule(bucket: RankingBucket): string {
    if (bucket.always) return t('sr_always')
    const n = bucket.best ?? 0
    const rule = t(`sr_best_${pluralKey(n)}`, { n })
    return bucket.types.length > 1 ? `${rule} ${t('sr_together')}` : rule
  }

  function bandText(buckets: RankingBucket[]): string {
    return buckets
      .map((b) => {
        if (b.always) return b.types.join(', ')
        const best = t(`sr_band_${pluralKey(b.best ?? 0)}`, { n: b.best ?? 0 })
        return b.types.length > 1 ? best : `${best} ${b.types[0]}`
      })
      .join(' + ')
  }

  // One ★ per counted result: N for „N najlepszych”, one per type for a bucket
  // that always counts (MPW: one) — the mark the drilldown puts on a counted result.
  function slotCount(bucket: RankingBucket): number {
    return Math.min(bucket.always ? bucket.types.length : (bucket.best ?? 0), 10)
  }

  function onClose() {
    onclose?.()
  }

  // Esc closes from anywhere — in the capture phase, because the dialog stops
  // its own key events from bubbling.
  function onWindowKeydown(e: KeyboardEvent) {
    if (open && rules && e.key === 'Escape') onClose()
  }

  // Focus moves into the dialog when it opens and back where it was when it
  // closes.
  let dialogEl: HTMLElement | null = $state(null)
  let returnFocus: HTMLElement | null = null
  $effect(() => {
    if (open && rules) {
      returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
      queueMicrotask(() => dialogEl?.focus({ preventScroll: true }))
    } else if (returnFocus) {
      const el = returnFocus
      returnFocus = null
      if (el.isConnected) el.focus({ preventScroll: true })
    }
  })
</script>

<style>
  .rules-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    justify-content: center;
    align-items: flex-start;
    padding: 40px 16px;
    z-index: 1000;
    overflow-y: auto;
  }
  .rules-panel {
    background: #fff;
    border-radius: 8px;
    width: 100%;
    max-width: 800px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
    color: #333;
  }
  .rules-panel:focus {
    outline: none;
  }

  /* Title row: the title, then the frame controls in the corner; the season
     line on its own row below. */
  .rules-head {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 0 12px;
    padding: 18px 20px 12px;
    border-bottom: 1px solid #eee;
  }
  .rules-title {
    flex: 1 1 0;
    min-width: 0;
    margin: 0;
    font-size: 20px;
    line-height: 1.25;
    color: #222;
  }
  .rules-actions {
    display: flex;
    flex: none;
    gap: 10px;
    align-items: center;
  }
  .rules-meta {
    flex-basis: 100%;
    margin-top: 2px;
    font-size: 13px;
    color: #777;
  }
  .rules-meta b {
    color: #333;
    font-weight: 600;
  }
  .dotsep {
    margin: 0 6px;
    color: #bbb;
  }
  .rules-close {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 36px;
    height: 36px;
    border: 0;
    border-radius: 50%;
    background: none;
    color: #6b7482;
    cursor: pointer;
  }
  .rules-close svg {
    width: 18px;
    height: 18px;
    fill: none;
    stroke: currentColor;
    stroke-width: 2.2;
    stroke-linecap: round;
  }
  .rules-close:hover {
    background: #eef1f5;
    color: #222;
  }
  .rules-close:focus-visible,
  .rules-annex:focus-visible {
    outline: 2px solid #12467e;
    outline-offset: 2px;
  }

  .rules-body {
    padding: 16px 20px 4px;
  }

  /* The sum, in the drilldown headline's panel style. */
  .rules-band {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 8px 10px;
  }
  .band-box {
    display: flex;
    flex-direction: column;
    justify-content: center;
    min-width: 118px;
    padding: 7px 15px 8px;
    border: 1px solid #d9e2ee;
    border-radius: 10px;
    background: #f3f6fb;
    box-shadow: 0 1px 2px rgba(16, 34, 64, 0.07), inset 0 1px 0 #fff;
    line-height: 1.15;
  }
  .band-key {
    font-size: 19px;
    font-weight: 800;
    letter-spacing: -0.01em;
  }
  .band-sub {
    margin-top: 3px;
    font-size: 12px;
    font-weight: 600;
    color: #4a5a70;
  }
  .band-box.spws .band-key {
    color: #2c6fad;
  }
  .band-box.evf .band-key {
    color: #b07d2b;
  }
  .band-box.total {
    background: #e9f0fa;
    border-color: #c9d8ec;
  }
  .band-box.total .band-key {
    color: #12467e;
  }
  .band-op {
    font-size: 22px;
    font-weight: 700;
    color: #8a94a3;
  }
  .band-note {
    margin: 8px 0 0;
    font-size: 12.5px;
    color: #6b7482;
  }

  /* One card per pool, in the drilldown charts' colours. */
  .pools {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 14px;
    margin-top: 16px;
  }
  .pools.single {
    grid-template-columns: 1fr;
  }
  .pool {
    padding: 10px 14px 12px;
    border: 1px solid #d9e2ee;
    border-top: 4px solid #4a90d9;
    border-radius: 10px;
    background: #fff;
    box-shadow: 0 1px 2px rgba(16, 34, 64, 0.06);
  }
  .pool.pool-evf {
    border-top-color: #e8a838;
  }
  .pool h3 {
    display: flex;
    flex-wrap: wrap;
    align-items: baseline;
    gap: 0 8px;
    margin: 0;
    font-size: 16px;
    font-weight: 800;
    color: #24364b;
  }
  .pool h3 small {
    font-size: 12px;
    font-weight: 600;
    color: #7a8492;
  }
  .bucket {
    display: grid;
    grid-template-columns: 1fr auto;
    grid-template-areas: 'types types' 'rule slots';
    align-items: center;
    gap: 6px 10px;
    padding: 10px 0;
    border-bottom: 1px solid #eef1f5;
  }
  .bucket:last-child {
    border-bottom: 0;
  }
  .bucket-types {
    grid-area: types;
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
  }
  .type-chip {
    display: inline-block;
    padding: 2px 7px;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 700;
    letter-spacing: 0.02em;
  }
  .type-chip.domestic {
    background: #e3effa;
    color: #2c6fad;
  }
  .type-chip.international {
    background: #fdf3e1;
    color: #b07d2b;
  }
  .bucket-rule {
    grid-area: rule;
    min-width: 0;
    font-size: 13.5px;
    font-weight: 600;
    color: #333;
  }
  .bucket-rule.always {
    color: #2e7d4f;
  }
  .slots {
    grid-area: slots;
    display: inline-flex;
    gap: 3px;
  }
  .slot {
    width: 18px;
    height: 18px;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 11px;
    line-height: 18px;
    text-align: center;
  }
  .pool-evf .slot {
    background: #e8a838;
  }
  .type-names {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 1px 14px;
    margin: 4px 0 0;
    padding: 0;
    list-style: none;
    font-size: 11.5px;
    color: #8a93a0;
  }
  .pool-sum {
    margin-top: 8px;
    padding: 6px 10px;
    border-radius: 6px;
    background: #f6f8fb;
    font-size: 12.5px;
    font-weight: 600;
    color: #4a5a70;
  }
  .pool-sum-to {
    font-weight: 800;
    color: #2c6fad;
  }
  .pool-evf .pool-sum-to {
    color: #b07d2b;
  }

  .facts {
    display: grid;
    gap: 8px;
    margin-top: 14px;
  }
  .fact {
    display: flex;
    gap: 10px;
    align-items: flex-start;
    padding: 9px 12px;
    border: 1px solid #eceff4;
    border-radius: 8px;
    background: #fafbfc;
    font-size: 13px;
    color: #444;
  }
  .fact b {
    color: #24364b;
  }
  .fact-icon {
    flex: none;
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 22px;
    height: 22px;
    border-radius: 50%;
    background: #e9eef5;
    color: #4a5a70;
    font-size: 12px;
    font-weight: 800;
  }
  .coefs {
    display: flex;
    flex-wrap: wrap;
    gap: 5px;
    margin-top: 5px;
  }
  .coef {
    padding: 1px 6px;
    border: 1px solid #dfe5ed;
    border-radius: 5px;
    background: #fff;
    font-family: ui-monospace, Menlo, Consolas, monospace;
    font-size: 12px;
    font-weight: 600;
    color: #333;
    white-space: nowrap;
  }

  .rules-foot {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    justify-content: space-between;
    gap: 6px 16px;
    margin-top: 12px;
    padding: 12px 20px 16px;
    border-top: 1px solid #eee;
    font-size: 12.5px;
    color: #777;
  }
  .rules-annex {
    color: #2c6fad;
    font-weight: 600;
    text-decoration: underline;
    text-decoration-color: #b0c8e8;
  }
  .rules-annex:hover {
    text-decoration-color: #2c6fad;
  }
  .star {
    color: #e8a838;
  }

  /* On a phone the rules fill the screen and the title stays at the top. */
  @media (max-width: 600px) {
    .rules-overlay {
      padding: 0;
      width: 100vw;
    }
    .rules-panel {
      border-radius: 0;
      max-width: 100vw;
      width: 100vw;
      min-height: 100vh;
    }
    .rules-head {
      position: sticky;
      top: 0;
      z-index: 5;
      padding: 12px;
      background: #fff;
      border-bottom: 1px solid #e5e9ef;
      box-shadow: 0 6px 12px -8px rgba(16, 34, 64, 0.35);
    }
    .rules-title {
      font-size: 17px;
      line-height: 1.2;
      overflow-wrap: anywhere;
    }
    .rules-meta {
      font-size: 12px;
    }
    .rules-actions {
      gap: 6px;
    }
    .rules-close {
      width: 44px;
      height: 44px;
    }
    .rules-body {
      padding: 12px 12px 4px;
    }
    .rules-band {
      display: grid;
      grid-template-columns: 1fr auto 1fr auto 1fr;
      gap: 4px;
    }
    .rules-band:has(.band-box:only-child) {
      grid-template-columns: 1fr;
    }
    .band-box {
      min-width: 0;
      padding: 6px 8px 7px;
    }
    .band-key {
      font-size: 15px;
    }
    .band-sub {
      font-size: 10.5px;
    }
    .band-op {
      font-size: 16px;
    }
    .pools {
      grid-template-columns: 1fr;
    }
    .type-names {
      grid-template-columns: 1fr;
    }
    .rules-foot {
      padding: 12px;
    }
  }
</style>
