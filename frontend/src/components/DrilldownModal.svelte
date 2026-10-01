<svelte:window onkeydowncapture={onWindowKeydown} />

{#if open}
  <div class="modal-overlay" role="presentation" onclick={onClose}>
    <div class="modal-content" role="dialog" aria-modal="true" aria-label={fencerName} tabindex="-1" bind:this={dialogEl} onclick={(e) => e.stopPropagation()} onkeydown={(e) => e.stopPropagation()}>
      <!-- UX proposal A (doc/mockups/ranklist-controls-ux-2026-10-01.html):
           the frame (language, close) in the top-right corner; under the name
           the headline — place and total, said once — with the view switch and
           the ODS download at the right end of the same row. On a phone this
           whole block stays at the top while the results scroll. -->
      <div class="modal-head">
        <div class="modal-header">
          <div class="modal-id">
            <h2>{fencerName}</h2>
            {#if context || seasonLabel}
              <div class="subheader">{metaLine}</div>
            {/if}
          </div>
          <div class="modal-actions">
            <LangToggle />
            <button type="button" class="btn-close" aria-label={t('close')} title={t('close_esc')} onclick={onClose}>
              <svg viewBox="0 0 20 20" aria-hidden="true" focusable="false"><path d="M5 5l10 10M15 5 5 15" /></svg>
            </button>
          </div>
        </div>

        <div class="headline-row">
          {#if showHeadline}
            <div class="score" role="group" aria-live="polite" aria-label={headlineLabel}>
              {#if context}
                <div class="score-fig">
                  <span class="score-num score-rank">{context.rank}</span>
                  <span class="score-lab">{t('dd_place')}</span>
                </div>
              {/if}
              <div class="score-fig big">
                <span class="score-num score-total">{fmt(headlineTotal)}</span>
                <span class="score-lab">{t('dd_points_total')}</span>
              </div>
            </div>
          {/if}
          <div class="view-tools">
            {#if showEvfToggle}
              <ViewSwitch {mode} onchange={setMode} />
            {/if}
            <OdsButton title={t('ods_tip_drilldown')} onclick={handleExport} />
          </div>
        </div>
      </div>

      {#if loading}
        <div class="loading">{t('loading')}</div>
      {:else if filteredScores.length === 0}
        <div class="empty">{t('no_tournament_results')}</div>
      {:else}
        <div class="breakdown-section">
          <h3>{t('points_breakdown')}</h3>
          <div class="breakdown-grid" class:single-col={mode === 'PPW'}>
            <div class="breakdown-col">
              <h4>{t('domestic_ppw_mpw')}: {fmt(counted.domesticTotal)} {t('pts')}</h4>
              <div class="chart-area">
                {#each domesticScores as s (s.id_result)}
                  {@render chartRow(s, 'domestic')}
                {/each}
              </div>
            </div>

            {#if mode === 'RANKING'}
              <div class="breakdown-col">
                <h4>{t('international_evf')}: {fmt(counted.internationalTotal)} {t('pts')}</h4>
                <div class="chart-area">
                  {#each internationalScores as s (s.id_result)}
                    {@render chartRow(s, 'international')}
                  {/each}
                </div>
              </div>
            {/if}
          </div>
          <div class="carried-legend">
            <div class="carried-legend-item"><div class="legend-swatch current"></div> {t('domestic_ppw_mpw').split(' (')[0]}</div>
            {#if hasCarryover}
              <div class="carried-legend-item"><div class="legend-swatch carried"></div> {t('rolling_carried_over')}</div>
            {/if}
            {#if mode === 'RANKING'}
              <div class="carried-legend-item"><div class="legend-swatch intl-current"></div> {t('international_evf').split(' (')[0]}</div>
              {#if hasCarryover}
                <div class="carried-legend-item"><div class="legend-swatch intl-carried"></div> {t('rolling_carried_over')} (EVF)</div>
              {/if}
              {#if hasPzszResults}
                <div class="carried-legend-item"><div class="legend-swatch evf-color"></div> {t('legend_evf_label')}</div>
                <div class="carried-legend-item"><div class="legend-swatch pzsz-color"></div> {t('legend_pzsz_label')}</div>
              {/if}
            {/if}
            <div class="carried-legend-item">★ {t('dd_counted')}</div>
            {#if hasCarryover}
              <div class="carried-legend-item">↩ {t('dd_previous_season')}</div>
            {/if}
          </div>
        </div>

        <div class="table-section">
          <h3>{t('domestic_tournaments')}</h3>
          <div class="table-panel">
            {@render tournamentTable(domesticScores)}
            {@render tournamentCards(domesticScores)}
          </div>
          {#if mode === 'RANKING' && internationalScores.length > 0}
            <h3>{t('international_tournaments_evf')}</h3>
            <div class="table-panel">
              {@render tournamentTable(internationalScores)}
              {@render tournamentCards(internationalScores)}
            </div>
          {/if}
        </div>
      {/if}

      <div class="modal-footer">
        <span><strong>{footerN[0]}</strong> — {footerN.slice(1).join(' — ')}</span>
        <span class="sep">·</span>
        <span><strong>{footerMult[0]}</strong> — {footerMult.slice(1).join(' — ')}</span>
      </div>
      <div class="type-legend">
        {#each legendTypes as type (type)}
          {@const parts = t('legend_' + type.toLowerCase()).split(' — ')}
          <span><strong>{parts[0]}</strong> — {parts.slice(1).join(' — ')}</span>
        {/each}
      </div>
    </div>
  </div>
{/if}

{#snippet chartRow(s: ScoreRow, pool: 'domestic' | 'international')}
  {@const carried = !!s.bool_carried_over}
  <div class="chart-row" class:carried-row={carried} class:not-counted={!counted.ids.has(s.id_result)} title={s.txt_tournament_code}>
    <span class="chart-value">{fmt(s.num_final_score)}</span>
    <div class="chart-bar-bg">
      <div
        class="chart-bar {pool}"
        class:domestic-carried={pool === 'domestic' && carried}
        class:international-carried={pool === 'international' && carried}
        class:chart-bar-evf={pool === 'international' && isEvf(s.enum_type)}
        class:chart-bar-pzsz={pool === 'international' && isPzsz(s.enum_type)}
        style="width: {maxScore > 0 ? ((s.num_final_score ?? 0) / maxScore) * 100 : 0}%"
      ></div>
    </div>
    <span class="chart-marker">{[marker(s), carried ? '↩' : ''].filter(Boolean).join(' ')}</span>
  </div>
{/snippet}

{#snippet tournamentName(s: ScoreRow)}
  {#if s.url_results}
    <a class="tournament-name" href={s.url_results} target="_blank" rel="noopener" title={s.txt_tournament_code}>{shortTournamentName(s)}</a>
  {:else}
    <span class="tournament-name" title={s.txt_tournament_code}>{shortTournamentName(s)}</span>
  {/if}
{/snippet}

{#snippet tournamentTable(rows: ScoreRow[])}
  <table>
    <thead>
      <tr>
        <th>{t('col_tournament')}</th>
        <th>{t('col_date')}</th>
        <th>{t('col_type')}</th>
        <th class="num">{t('col_place')}</th>
        <th class="num">N</th>
        <th class="num">{t('col_mult')}</th>
        <th class="num total">{t('col_points')}</th>
      </tr>
    </thead>
    <tbody>
      {#each rows as s (s.id_result)}
        {@const note = joinedNote(s)}
        <tr class:carried-row={s.bool_carried_over} class:not-counted={!counted.ids.has(s.id_result)}>
          <td>
            {@render tournamentName(s)}
            {#if s.txt_location}
              <div class="location">{s.txt_location}</div>
            {/if}
            {#if note}
              <div class="joined-note">{note}</div>
            {/if}
            {#if s.bool_carried_over && s.txt_source_season_code}
              <div class="carried-badge">↩ {s.txt_source_season_code}</div>
            {/if}
          </td>
          <td>{formatDate(s.dt_tournament)}</td>
          <td><span class="type-badge" class:domestic={isDomestic(s.enum_type)} class:international={isInternational(s.enum_type)}>{s.enum_type}</span></td>
          <td class="num place">{s.int_place}</td>
          <td class="num">{s.int_participant_count ?? '—'}</td>
          <td class="num">{s.num_multiplier != null ? Number(s.num_multiplier).toFixed(1) : '—'}</td>
          <td class="num total">{fmt(s.num_final_score)} {marker(s)}</td>
        </tr>
      {/each}
    </tbody>
  </table>
{/snippet}

{#snippet tournamentCards(rows: ScoreRow[])}
  <div class="card-list">
    {#each rows as s (s.id_result)}
      {@const note = joinedNote(s)}
      <div class="result-card" class:carried={s.bool_carried_over} class:not-counted={!counted.ids.has(s.id_result)}>
        <div class="card-top">
          <span class="card-tournament">{@render tournamentName(s)}</span>
          <span class="card-points">{fmt(s.num_final_score)} {marker(s)}</span>
        </div>
        <div class="card-meta">
          {#if s.txt_location}<span class="card-location">{s.txt_location}</span>{/if}
          <span class="card-date">{formatDate(s.dt_tournament)}</span>
          <span class="type-badge" class:domestic={isDomestic(s.enum_type)} class:international={isInternational(s.enum_type)}>{s.enum_type}</span>
          <span class="card-place">{s.int_place}/{s.int_participant_count ?? '—'}</span>
          <span class="card-mult">&times;{s.num_multiplier != null ? Number(s.num_multiplier).toFixed(1) : '—'}</span>
        </div>
        {#if note}
          <div class="joined-note">{note}</div>
        {/if}
        {#if s.bool_carried_over && s.txt_source_season_code}
          <div class="card-carried-badge">↩ {s.txt_source_season_code}</div>
        {/if}
      </div>
    {/each}
  </div>
{/snippet}

<script lang="ts">
  import type { ScoreRow, RankingMode, DrilldownContext, RankingRules } from '../lib/types'
  import { exportDrilldown } from '../lib/export'
  import { t, getLocale } from '../lib/locale.svelte'
  import {
    byPointsDesc,
    countResults,
    isDomestic,
    isEvf,
    isInternational,
    isPzsz,
    joinedBracketDetails,
    shortTournamentName,
  } from '../lib/drilldown-counting'
  import LangToggle from './LangToggle.svelte'
  import ViewSwitch from './ViewSwitch.svelte'
  import OdsButton from './OdsButton.svelte'

  let {
    open = false,
    fencerName = '',
    scores = [] as ScoreRow[],
    mode = 'PPW' as RankingMode,
    showEvfToggle = false,
    loading = false,
    context = null as DrilldownContext | null,
    rankingRules = null as RankingRules | null,
    seasonCode = null as string | null,
    onclose,
    onmodechange,
  }: {
    open?: boolean
    fencerName?: string
    scores?: ScoreRow[]
    mode?: RankingMode
    showEvfToggle?: boolean
    loading?: boolean
    context?: DrilldownContext | null
    rankingRules?: RankingRules | null
    // The season the ranking being drilled into belongs to (R.26–R.30).
    seasonCode?: string | null
    onclose?: () => void
    // A1: the page follows the modal's PPW | Ranking switch, so the list
    // behind the modal and the rank in its header show the same view.
    onmodechange?: (mode: RankingMode) => void
  } = $props()

  // --- Derived data ---

  // The header names the season being ranked. On a rolling ranking the
  // carried previous-season rows come first and each carries its own season,
  // so without one from the caller only a row that is not carried over can
  // name it — and with none, no season is named rather than the wrong one.
  let seasonLabel = $derived(
    seasonCode ?? scores.find((s) => !s.bool_carried_over)?.txt_season_code ?? null,
  )

  let filteredScores = $derived(mode === 'PPW' ? scores.filter((s) => isDomestic(s.enum_type)) : scores)

  // Both tables, their phone cards and both bar charts run by points, highest
  // first; equal points put the newer result first.
  let domesticScores = $derived(scores.filter((s) => isDomestic(s.enum_type)).sort(byPointsDesc))
  let internationalScores = $derived(scores.filter((s) => isInternational(s.enum_type)).sort(byPointsDesc))

  // The results that count and the totals they make: one set for the ★, the
  // greyed rows and bars, and every printed total.
  let counted = $derived(countResults(scores, rankingRules, context))

  // The line under the name: category, season, birth year.
  let metaLine = $derived(
    [
      context?.category ?? scores[0]?.enum_age_category ?? '',
      seasonLabel,
      context?.birthYear ? `${t('born')} ${context.birthYear}` : null,
    ]
      .filter(Boolean)
      .join(' · '),
  )

  // The headline: the place and total of the view shown. The total comes from
  // the ranklist row the drilldown was opened from, so it is the number on the
  // list; without one it is the counted total, which matches it (DD.PARITY.01).
  let headlineTotal = $derived(
    context?.totalScore ?? (mode === 'RANKING' ? counted.grandTotal : counted.domesticTotal),
  )
  let showHeadline = $derived(!loading && (context != null || filteredScores.length > 0))
  let headlineLabel = $derived(
    (context ? `${t('dd_place')} ${context.rank}, ` : '') + `${fmt(headlineTotal)} ${t('dd_points_total')}`,
  )

  // The legend explains only what is on screen.
  let hasCarryover = $derived(filteredScores.some((s) => s.bool_carried_over))
  // SS26.UI: only show the EVF/PZSz provenance legend when a PZSz result is
  // actually present — otherwise every bar is orange and the distinction is
  // noise, not information.
  let hasPzszResults = $derived(internationalScores.some((s) => isPzsz(s.enum_type)))
  const LEGEND_ORDER = ['PPW', 'MPW', 'PEW', 'MEW', 'MSW', 'PSW', 'PPS', 'MPS'] as const
  let legendTypes = $derived(LEGEND_ORDER.filter((type) => filteredScores.some((s) => s.enum_type === type)))

  let maxScore = $derived(
    Math.max(
      ...domesticScores.map((s) => s.num_final_score ?? 0),
      ...internationalScores.map((s) => s.num_final_score ?? 0),
      1,
    ),
  )

  // --- i18n derived ---
  let footerN = $derived(t('footer_n').split(' — '))
  let footerMult = $derived(t('footer_mult').split(' — '))

  // --- Helpers ---

  function fmt(v: number | null): string {
    if (v == null) return '—'
    const n = Math.round(Number(v) * 10) / 10
    return n % 1 === 0 ? n.toFixed(0) : n.toFixed(1)
  }

  function formatDate(dt: string | null): string {
    if (!dt) return '—'
    try {
      const d = new Date(dt)
      const day = d.getDate()
      const month = d.toLocaleString(getLocale() === 'pl' ? 'pl-PL' : 'en', { month: 'short' })
      const year = String(d.getFullYear()).slice(2)
      return `${day} ${month} ${year}`
    } catch {
      return dt
    }
  }

  function marker(s: ScoreRow): string {
    return counted.ids.has(s.id_result) ? '★' : ''
  }

  // B2 (ADR-104): a joined-bracket result's place and N are in the whole
  // bracket; the note says so and shows the premium (and any cap reduction).
  function joinedNote(s: ScoreRow): string | null {
    const j = joinedBracketDetails(s)
    if (!j) return null
    const parts = [t('dd_joined')]
    if (j.premium > 0) parts.push(`${t('dd_premium')} +${fmt(j.premium)}`)
    if (j.cap > 0) parts.push(`${t('dd_cap')} −${fmt(j.cap)}`)
    return parts.join(' · ')
  }

  function onClose() {
    onclose?.()
  }

  // Esc closes from anywhere — in the capture phase, because the dialog stops
  // its own key events from bubbling.
  function onWindowKeydown(e: KeyboardEvent) {
    if (open && e.key === 'Escape') onClose()
  }

  // Focus moves into the dialog when it opens and back where it was when it
  // closes.
  let dialogEl: HTMLElement | null = $state(null)
  let returnFocus: HTMLElement | null = null
  $effect(() => {
    if (open) {
      returnFocus = document.activeElement instanceof HTMLElement ? document.activeElement : null
      queueMicrotask(() => dialogEl?.focus({ preventScroll: true }))
    } else if (returnFocus) {
      const el = returnFocus
      returnFocus = null
      if (el.isConnected) el.focus({ preventScroll: true })
    }
  })

  function setMode(m: RankingMode) {
    mode = m
    onmodechange?.(m)
  }

  function handleExport() {
    exportDrilldown(fencerName, scores, mode)
  }
</script>

<style>
  .modal-overlay {
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
  .modal-content {
    background: #fff;
    border-radius: 8px;
    width: 100%;
    max-width: 900px;
    padding: 24px;
    box-shadow: 0 8px 32px rgba(0, 0, 0, 0.2);
  }
  /* Focus moves onto the dialog itself when it opens; the dialog is not a
     control, so it draws no focus ring. */
  .modal-content:focus {
    outline: none;
  }
  /* Header: name and meta with the frame controls (language, close) in the
     top-right corner; under them the headline row. */
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    gap: 12px;
  }
  .modal-id {
    min-width: 0;
  }
  .modal-header h2 {
    margin: 0;
    font-size: 20px;
    line-height: 1.25;
    color: #222;
  }
  .subheader {
    margin-top: 2px;
    font-size: 13px;
    color: #777;
  }
  .modal-actions {
    display: flex;
    flex: none;
    gap: 10px;
    align-items: center;
  }
  .btn-close {
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
  .btn-close svg {
    width: 18px;
    height: 18px;
    fill: none;
    stroke: currentColor;
    stroke-width: 2.2;
    stroke-linecap: round;
  }
  .btn-close:hover {
    background: #eef1f5;
    color: #222;
  }
  .btn-close:focus-visible {
    outline: 2px solid #12467e;
    outline-offset: 2px;
  }

  /* The headline: place and total, the largest figures on the screen, said
     once; the view switch and the ODS download at the right end. */
  .headline-row {
    display: flex;
    flex-wrap: wrap;
    align-items: center;
    gap: 12px;
    padding: 10px 0 14px;
    border-bottom: 1px solid #eee;
    margin-bottom: 16px;
  }
  .view-tools {
    display: flex;
    align-items: center;
    gap: 8px;
    margin-left: auto;
  }
  .score {
    display: inline-flex;
    align-items: stretch;
    background: #f3f6fb;
    border: 1px solid #d9e2ee;
    border-radius: 10px;
    box-shadow: 0 1px 2px rgba(16, 34, 64, 0.07), inset 0 1px 0 #fff;
  }
  .score-fig {
    display: flex;
    flex-direction: column;
    justify-content: center;
    padding: 6px 16px 7px;
    line-height: 1.05;
  }
  .score-fig + .score-fig {
    border-left: 1px solid #d9e2ee;
  }
  .score-num {
    font-size: 22px;
    font-weight: 800;
    color: #24364b;
    font-variant-numeric: tabular-nums;
    letter-spacing: -0.01em;
  }
  .score-fig.big .score-num {
    font-size: 28px;
    color: #12467e;
  }
  .score-lab {
    margin-top: 4px;
    font-size: 10.5px;
    font-weight: 700;
    letter-spacing: 0.07em;
    text-transform: uppercase;
    color: #6b7482;
  }

  .loading, .empty {
    text-align: center;
    padding: 32px;
    color: #999;
  }

  /* Score Breakdown */
  .breakdown-section {
    margin-bottom: 24px;
  }
  .breakdown-section h3 {
    font-size: 14px;
    color: #555;
    margin: 0 0 12px;
  }
  .breakdown-grid {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 24px;
  }
  .breakdown-grid.single-col {
    grid-template-columns: 1fr;
  }
  .breakdown-col h4 {
    font-size: 13px;
    color: #666;
    margin: 0 0 8px;
    font-weight: 600;
  }
  .chart-area {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .chart-row {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 12px;
  }
  .chart-value {
    width: 42px;
    text-align: right;
    font-weight: 600;
    color: #333;
  }
  .chart-bar-bg {
    flex: 1;
    height: 18px;
    background: #f0f0f0;
    border-radius: 3px;
    overflow: hidden;
  }
  .chart-bar {
    height: 100%;
    border-radius: 3px;
    transition: width 0.3s ease;
  }
  .chart-bar.domestic {
    background: #4a90d9;
  }
  .chart-row.carried-row .chart-value {
    color: #999;
  }
  .chart-bar.domestic-carried {
    background: repeating-linear-gradient(45deg, #b0c8e8, #b0c8e8 4px, #d0e0f4 4px, #d0e0f4 8px);
  }
  .chart-bar.international {
    background: #e8a838;
  }
  .chart-bar.international-carried {
    background: repeating-linear-gradient(45deg, #e8d5a0, #e8d5a0 4px, #f0e4c4 4px, #f0e4c4 8px);
  }
  /* SS26.UI (design step 7): provenance-only coloring inside the one EVF+
     bar chart — orange (.chart-bar-evf, same shade .international already
     used) stays the default, red overrides it for a PZSz result. Same PZSz
     brand red (#c72626) the calendar already uses (EventCard.svelte,
     CalendarBarrel.svelte). No separate subtotal is implied by either color. */
  .chart-bar.chart-bar-evf {
    background: #e8a838;
  }
  .chart-bar.chart-bar-pzsz {
    background: #c72626;
  }
  /* A carried-over result keeps the stripes in either colour, as the legend
     shows (DD.BAR.02); the solid colours above apply only to current results. */
  .chart-bar.chart-bar-evf.international-carried {
    background: repeating-linear-gradient(45deg, #e8d5a0, #e8d5a0 4px, #f0e4c4 4px, #f0e4c4 8px);
  }
  .chart-bar.chart-bar-pzsz.international-carried {
    background: repeating-linear-gradient(45deg, #e8a3a3, #e8a3a3 4px, #f4d1d1 4px, #f4d1d1 8px);
  }
  .chart-marker {
    min-width: 28px;
    text-align: center;
    font-size: 13px;
  }
  /* A result that does not count in the ranking: its bar fades. */
  .chart-row.not-counted {
    opacity: 0.3;
  }
  .type-legend {
    margin-top: 12px;
    display: flex;
    flex-direction: column;
    gap: 2px;
    font-size: 9px;
    color: #999;
  }
  .type-legend strong {
    color: #666;
  }
  .carried-legend {
    margin-top: 8px;
    display: flex;
    gap: 16px;
    flex-wrap: wrap;
    font-size: 11px;
    color: #888;
    padding: 6px 10px;
    background: #fafafa;
    border-radius: 4px;
  }
  .carried-legend-item {
    display: flex;
    align-items: center;
    gap: 4px;
  }
  .legend-swatch {
    width: 14px;
    height: 10px;
    border-radius: 2px;
    display: inline-block;
  }
  .legend-swatch.current {
    background: #4a90d9;
  }
  .legend-swatch.carried {
    background: repeating-linear-gradient(45deg, #b0c8e8, #b0c8e8 3px, #d0e0f4 3px, #d0e0f4 6px);
    border: 1px solid #9bb8d8;
  }
  .legend-swatch.intl-current {
    background: #e8a838;
  }
  .legend-swatch.intl-carried {
    background: repeating-linear-gradient(45deg, #e8d5a0, #e8d5a0 3px, #f0e4c4 3px, #f0e4c4 6px);
    border: 1px solid #d4b87a;
  }
  .legend-swatch.evf-color {
    background: #e8a838;
  }
  .legend-swatch.pzsz-color {
    background: #c72626;
  }

  /* Tables */
  .table-section h3 {
    font-size: 14px;
    color: #555;
    margin: 16px 0 8px;
  }
  table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
    margin-bottom: 16px;
  }
  th {
    padding: 8px;
    text-align: left;
    font-weight: 600;
    color: #555;
    border-bottom: 2px solid #ddd;
    background: #f5f7fa;
    white-space: nowrap;
  }
  td {
    padding: 6px 8px;
    border-bottom: 1px solid #eee;
  }
  .num {
    text-align: right;
  }
  .total {
    font-weight: 700;
  }
  .place {
    font-weight: 700;
    font-size: 15px;
  }
  .type-badge {
    display: inline-block;
    padding: 1px 6px;
    border-radius: 3px;
    font-size: 11px;
    font-weight: 600;
  }
  .type-badge.domestic {
    background: #e3effa;
    color: #2c6fad;
  }
  .type-badge.international {
    background: #fdf3e1;
    color: #b07d2b;
  }

  tr.carried-row {
    color: #999;
  }
  tr.carried-row td {
    border-bottom-color: #f5f5f5;
  }
  .carried-badge {
    font-size: 10px;
    color: #999;
    font-style: italic;
    margin-top: 2px;
  }
  .location {
    font-size: 11px;
    color: #999;
    margin-top: 2px;
  }
  td a {
    color: #2c6fad;
    text-decoration: underline;
    text-decoration-color: #b0c8e8;
  }
  td a:hover {
    text-decoration-color: #2c6fad;
  }
  .joined-note {
    font-size: 11px;
    color: #5b6f86;
    margin-top: 2px;
  }

  /* Each table and its phone cards sit in one framed, slightly raised panel. */
  .table-panel {
    background: #f3f6fb;
    border: 1px solid #d9e2ee;
    border-radius: 10px;
    padding: 2px 10px 4px;
    margin: 6px 0 16px;
    box-shadow:
      0 1px 2px rgba(16, 34, 64, 0.07),
      0 6px 18px rgba(16, 34, 64, 0.12),
      inset 0 1px 0 #fff;
    overflow-x: auto;
  }
  .table-panel table {
    margin-bottom: 0;
  }
  .table-panel th {
    background: transparent;
    border-bottom-color: #d9e2ee;
  }
  .table-panel td {
    border-bottom-color: #e3e9f2;
  }
  .table-panel tr:last-child td {
    border-bottom: 0;
  }

  /* A result that does not count in the ranking: grey background, grey text.
     Carried-over rows keep their own look and get this on top only when they
     do not count. */
  tr.not-counted td {
    background: #e1e3e6;
    color: #9d9d9d;
    border-bottom-color: #d3d6db;
  }
  tr.not-counted a {
    color: #9d9d9d;
    text-decoration-color: #c4c7cc;
  }
  tr.not-counted .type-badge,
  .result-card.not-counted .type-badge {
    opacity: 0.5;
  }
  tr.not-counted .place,
  tr.not-counted .total {
    font-weight: 500;
  }
  tr.not-counted .location,
  tr.not-counted .carried-badge,
  tr.not-counted .joined-note {
    color: #aaa;
  }

  .modal-footer {
    margin-top: 16px;
    padding-top: 10px;
    border-top: 1px solid #eee;
    font-size: 12px;
    color: #888;
    display: flex;
    flex-wrap: wrap;
    gap: 4px;
    align-items: center;
  }
  .modal-footer .sep {
    color: #ccc;
  }

  /* Card layout — hidden on desktop, shown on mobile */
  .card-list {
    display: none;
    flex-direction: column;
    gap: 8px;
    margin-bottom: 16px;
  }
  .result-card {
    border: 1px solid #d8d8d8;
    border-radius: 6px;
    padding: 10px 12px;
    background: #f8f9fa;
    color: #333;
  }
  .table-panel .card-list {
    margin: 0;
    padding: 6px 0;
  }
  .table-panel .result-card {
    background: #fff;
  }
  .table-panel .result-card.carried,
  .result-card.carried {
    color: #999;
    border-color: #e8e8e8;
    background: #f5f4f2;
  }
  .table-panel .result-card.not-counted {
    background: #e1e3e6;
    border-color: #d3d6db;
  }
  .result-card.not-counted,
  .result-card.not-counted :is(a, .card-points, .card-meta, .card-carried-badge, .joined-note) {
    color: #9d9d9d;
  }
  .result-card.not-counted .card-points {
    font-weight: 500;
  }
  .card-top {
    display: flex;
    justify-content: space-between;
    align-items: baseline;
    gap: 8px;
    margin-bottom: 4px;
  }
  .card-tournament {
    font-weight: 600;
    font-size: 13px;
  }
  .card-tournament a {
    color: #2c6fad;
    text-decoration: underline;
    text-decoration-color: #b0c8e8;
  }
  .card-tournament a:hover {
    text-decoration-color: #2c6fad;
  }
  .card-points {
    font-weight: 700;
    font-size: 14px;
    white-space: nowrap;
    color: #222;
  }
  .card-meta {
    display: flex;
    flex-wrap: wrap;
    gap: 2px 6px;
    font-size: 12px;
    color: #777;
  }
  .card-meta > span + span::before {
    content: '·';
    margin-right: 6px;
  }
  .card-place {
    font-weight: 600;
  }
  .card-carried-badge {
    font-size: 10px;
    color: #999;
    font-style: italic;
    margin-top: 4px;
  }

  @media (max-width: 600px) {
    .modal-overlay {
      padding: 0;
      align-items: flex-start;
      width: 100vw;
    }
    .modal-content {
      border-radius: 0;
      padding: 16px 12px;
      max-width: 100vw;
      width: 100vw;
      min-height: 100vh;
      background: #fff;
    }
    /* Name, headline and controls stay at the top while the results scroll. */
    .modal-head {
      position: sticky;
      top: 0;
      z-index: 5;
      margin: -16px -12px 12px;
      padding: 12px 12px 10px;
      background: #fff;
      border-bottom: 1px solid #e5e9ef;
      box-shadow: 0 6px 12px -8px rgba(16, 34, 64, 0.35);
    }
    .modal-header {
      align-items: flex-start;
    }
    .modal-header h2 {
      font-size: 17px;
      line-height: 1.2;
      overflow-wrap: anywhere;
    }
    .subheader {
      font-size: 12px;
    }
    .modal-actions {
      gap: 6px;
    }
    .btn-close {
      width: 44px;
      height: 44px;
    }
    .headline-row {
      gap: 10px;
      padding: 10px 0 0;
      border-bottom: 0;
      margin-bottom: 0;
    }
    .view-tools {
      flex: 1 1 100%;
      margin-left: 0;
    }
    .score-fig {
      padding: 5px 14px 6px;
    }
    .score-num {
      font-size: 19px;
    }
    .score-fig.big .score-num {
      font-size: 24px;
    }
    .breakdown-grid {
      grid-template-columns: 1fr;
      gap: 16px;
    }
    .breakdown-col h4 {
      font-size: 12px;
    }
    .chart-row {
      font-size: 11px;
    }
    .chart-value {
      width: 36px;
    }
    .chart-bar-bg {
      height: 16px;
    }
    .table-section table {
      display: none;
    }
    .card-list {
      display: flex;
    }
    th {
      padding: 6px;
    }
    td {
      padding: 4px 6px;
    }
  }
</style>
