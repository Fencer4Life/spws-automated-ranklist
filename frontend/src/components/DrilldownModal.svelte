{#if open}
  <!-- svelte-ignore a11y_click_events_have_key_events a11y_interactive_supports_focus -->
  <div class="modal-overlay" onclick={onClose} role="dialog" aria-modal="true" aria-label="Fencer details" tabindex="-1">
    <!-- svelte-ignore a11y_click_events_have_key_events a11y_no_static_element_interactions a11y_no_noninteractive_element_interactions -->
    <div class="modal-content" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h2>{fencerName}</h2>
        <div class="modal-actions">
          <LangToggle />
          <button class="btn-close" onclick={onClose}>&times;</button>
        </div>
      </div>

      {#if context || seasonCode}
        <div class="subheader">
          {#if context}
            <span>{t('rank')} #{context.rank}</span>
            <span class="sep">|</span>
          {/if}
          <span>
            {context?.category ?? scores[0]?.enum_age_category ?? ''}
            {#if seasonCode} · {seasonCode}{/if}
            {#if context?.birthYear} ({t('born')} {context.birthYear}){/if}
          </span>
          {#if showEvfToggle}
            <div class="toggle" class:kadra-disabled={kadraDisabled}>
              <button
                class="toggle-btn"
                class:active={mode === 'PPW'}
                onclick={() => setMode('PPW')}
              >PPW</button>
              <button
                class="toggle-btn"
                class:active={mode === 'KADRA'}
                disabled={kadraDisabled}
                onclick={() => setMode('KADRA')}
              >+EVF</button>
            </div>
          {/if}
          <button class="btn-export-sub" title={t('export_to_ods')} onclick={handleExport}>&#9113;</button>
        </div>
      {/if}

      {#if loading}
        <div class="loading">{t('loading')}</div>
      {:else if filteredScores.length === 0}
        <div class="empty">{t('no_tournament_results')}</div>
      {:else}
        {#if hasCarryover}
          <div class="rolling-info">
            ↩ <strong>{t('rolling_banner_text')}</strong>
          </div>
        {/if}
        <div class="breakdown-section">
          <h3>{t('points_breakdown')}</h3>
          <div class="breakdown-grid" class:single-col={mode === 'PPW'}>
            <div class="breakdown-col">
              <h4>{t('domestic_ppw_mpw')}: {fmt(domesticTotal)} {t('pts')}</h4>
              <div class="chart-area">
                {#each domesticChart as item}
                  <div class="chart-row" class:carried-row={item.carried}>
                    <span class="chart-value">{Math.round(item.score)}</span>
                    <div class="chart-bar-bg">
                      <div
                        class="chart-bar domestic"
                        class:domestic-carried={item.carried}
                        style="width: {maxScore > 0 ? (item.score / maxScore) * 100 : 0}%"
                      ></div>
                    </div>
                    <span class="chart-marker">{item.marker}</span>
                  </div>
                {/each}
              </div>
            </div>

            {#if mode === 'KADRA'}
              <div class="breakdown-col">
                <h4>{t('international_evf')}: {fmt(internationalTotal)} {t('pts')}</h4>
                <div class="chart-area">
                  {#each internationalChart as item}
                    <div class="chart-row" class:carried-row={item.carried}>
                      <span class="chart-value">{Math.round(item.score)}</span>
                      <div class="chart-bar-bg">
                        <div
                          class="chart-bar international"
                          class:international-carried={item.carried}
                          style="width: {maxScore > 0 ? (item.score / maxScore) * 100 : 0}%"
                        ></div>
                      </div>
                      <span class="chart-marker">{item.marker}</span>
                    </div>
                  {/each}
                </div>
              </div>
            {/if}
          </div>
          {#if hasCarryover}
            <div class="carried-legend">
              <div class="carried-legend-item"><div class="legend-swatch current"></div> {t('domestic_ppw_mpw').split(' (')[0]}</div>
              <div class="carried-legend-item"><div class="legend-swatch carried"></div> {t('rolling_carried_over')}</div>
              {#if mode === 'KADRA'}
                <div class="carried-legend-item"><div class="legend-swatch intl-current"></div> {t('international_evf').split(' (')[0]}</div>
                <div class="carried-legend-item"><div class="legend-swatch intl-carried"></div> {t('rolling_carried_over')} (EVF)</div>
              {/if}
              <div class="carried-legend-item">★ Best</div>
              <div class="carried-legend-item">✓ {t('sc_rule_always')}</div>
              <div class="carried-legend-item">↩ {t('rolling_carried_over')}</div>
            </div>
          {/if}
        </div>

        <div class="table-total">
          {mode === 'KADRA' ? t('kadra_total_label') : t('ppw_total_label')}: {mode === 'KADRA' ? fmt(grandTotal) : fmt(ppwModeTotal)} {t('pts')}
        </div>

        <div class="table-section">
          <h3>{t('domestic_tournaments')}</h3>
          {@render tournamentTable(domesticScores)}
          {#if mode === 'KADRA' && internationalScores.length > 0}
            <h3>{t('international_tournaments_evf')}</h3>
            {@render tournamentTable(internationalScores)}
          {/if}
        </div>
      {/if}

      <div class="modal-footer">
        <span><strong>{footerN[0]}</strong> — {footerN.slice(1).join(' — ')}</span>
        <span class="sep">·</span>
        <span><strong>{footerMult[0]}</strong> — {footerMult.slice(1).join(' — ')}</span>
      </div>
      <div class="type-legend">
        {#each ['legend_ppw', 'legend_mpw', 'legend_pew', 'legend_mew', 'legend_msw'] as key}
          {@const parts = t(key).split(' — ')}
          <span><strong>{parts[0]}</strong> — {parts.slice(1).join(' — ')}</span>
        {/each}
      </div>
    </div>
  </div>
{/if}

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
      {#each rows as s}
        <tr class:carried-row={s.bool_carried_over}>
          <td>
            {#if s.url_results}
              <a href={s.url_results} target="_blank" rel="noopener">{s.txt_tournament_code}</a>
            {:else}
              {s.txt_tournament_code}
            {/if}
            {#if s.txt_location}
              <div class="location">{s.txt_location}</div>
            {/if}
            {#if s.bool_carried_over && s.txt_source_season_code}
              <div class="carried-badge">↩ {s.txt_source_season_code}</div>
            {/if}
          </td>
          <td>{formatDate(s.dt_tournament)}</td>
          <td><span class="type-badge" class:domestic={s.enum_type === 'PPW' || s.enum_type === 'MPW'} class:international={INTL_TYPES.includes(s.enum_type as (typeof INTL_TYPES)[number])}>{s.enum_type}</span></td>
          <td class="num place">{s.int_place}</td>
          <td class="num">{s.int_participant_count ?? '—'}</td>
          <td class="num">{s.num_multiplier != null ? Number(s.num_multiplier).toFixed(1) : '—'}</td>
          <td class="num total">{fmt(s.num_final_score)} {getMarker(s)}</td>
        </tr>
      {/each}
    </tbody>
  </table>
{/snippet}

<script lang="ts">
  import type { ScoreRow, RankingMode, DrilldownContext, RankingRules } from '../lib/types'
  import { exportDrilldown } from '../lib/export'
  import { t, getLocale } from '../lib/locale.svelte'
  import LangToggle from './LangToggle.svelte'

  const INTL_TYPES = ['PEW', 'MEW', 'MSW', 'PSW'] as const

  let {
    open = false,
    fencerName = '',
    scores = [] as ScoreRow[],
    mode = 'PPW' as RankingMode,
    kadraDisabled = false,
    showEvfToggle = false,
    loading = false,
    context = null as DrilldownContext | null,
    rankingRules = null as RankingRules | null,
    onclose,
  }: {
    open?: boolean
    fencerName?: string
    scores?: ScoreRow[]
    mode?: RankingMode
    kadraDisabled?: boolean
    showEvfToggle?: boolean
    loading?: boolean
    context?: DrilldownContext | null
    rankingRules?: RankingRules | null
    onclose?: () => void
  } = $props()

  // --- Derived data ---

  let seasonCode = $derived(scores[0]?.txt_season_code ?? null)

  let filteredScores = $derived(
    mode === 'PPW'
      ? scores.filter((s) => s.enum_type === 'PPW' || s.enum_type === 'MPW')
      : scores
  )

  // Sort: current season first (bool_carried_over=false), then carried-over, within each group by date asc
  function sortCurrentFirst<T extends { bool_carried_over?: boolean; dt_tournament?: string | null }>(a: T, b: T): number {
    const ac = a.bool_carried_over ? 1 : 0
    const bc = b.bool_carried_over ? 1 : 0
    if (ac !== bc) return ac - bc
    return (a.dt_tournament ?? '').localeCompare(b.dt_tournament ?? '')
  }

  let domesticScores = $derived(
    scores
      .filter((s) => s.enum_type === 'PPW' || s.enum_type === 'MPW')
      .sort(sortCurrentFirst)
  )

  let internationalScores = $derived(
    scores
      .filter((s) => INTL_TYPES.includes(s.enum_type as (typeof INTL_TYPES)[number]))
      .sort(sortCurrentFirst)
  )

  // Pool selection for JSONB rules: all international scores sorted desc
  let intlPoolSorted = $derived(
    scores
      .filter((s) => INTL_TYPES.includes(s.enum_type as (typeof INTL_TYPES)[number]))
      .sort((a, b) => (b.num_final_score ?? 0) - (a.num_final_score ?? 0))
  )

  let intlPoolBestIds = $derived(new Set(intlPoolSorted.slice(0, bestJ).map((s) => s.id_result)))

  // Best-K PPW scores
  let ppwScoresSorted = $derived(
    scores
      .filter((s) => s.enum_type === 'PPW')
      .sort((a, b) => (b.num_final_score ?? 0) - (a.num_final_score ?? 0))
  )

  let useJsonbRules = $derived(rankingRules != null)

  let bestK = $derived.by(() => {
    if (rankingRules) {
      const bucket = rankingRules.domestic.find((b) => b.types.includes('PPW'))
      return bucket?.best ?? 4
    }
    return context?.ppwBestCount ?? 4
  })

  let bestJ = $derived.by(() => {
    if (rankingRules) {
      const bucket = rankingRules.international.find((b) =>
        b.types.some((t) => INTL_TYPES.includes(t as (typeof INTL_TYPES)[number])),
      )
      return bucket?.best ?? 3
    }
    return context?.pewBestCount ?? 3
  })

  let ppwBestIds = $derived(new Set(ppwScoresSorted.slice(0, bestK).map((s) => s.id_result)))
  let ppwSum = $derived(
    Math.round(ppwScoresSorted.slice(0, bestK).reduce((acc, s) => acc + (s.num_final_score ?? 0), 0) * 10) / 10
  )

  // MPW inclusion
  let mpwScore = $derived(scores.find((s) => s.enum_type === 'MPW'))
  let mpwIncluded = $derived(Math.round((mpwScore?.num_final_score ?? 0) * 10) / 10)

  let domesticTotal = $derived(Math.round((ppwSum + mpwIncluded) * 10) / 10)

  // Best-J PEW scores
  let pewScoresSorted = $derived(
    scores
      .filter((s) => s.enum_type === 'PEW')
      .sort((a, b) => (b.num_final_score ?? 0) - (a.num_final_score ?? 0))
  )

  let pewBestIds = $derived(new Set(pewScoresSorted.slice(0, bestJ).map((s) => s.id_result)))
  let pewSum = $derived(
    Math.round(pewScoresSorted.slice(0, bestJ).reduce((acc, s) => acc + (s.num_final_score ?? 0), 0) * 10) / 10
  )

  let mewScore = $derived(scores.find((s) => s.enum_type === 'MEW'))
  let mewIncluded = $derived(Math.round((mewScore?.num_final_score ?? 0) * 10) / 10)

  let internationalTotal = $derived(
    useJsonbRules
      ? Math.round(
          intlPoolSorted
            .slice(0, bestJ)
            .reduce((acc, s) => acc + (s.num_final_score ?? 0), 0) * 10,
        ) / 10
      : Math.round((pewSum + mewIncluded) * 10) / 10,
  )
  let grandTotal = $derived(Math.round((domesticTotal + internationalTotal) * 10) / 10)

  let ppwModeTotal = $derived(domesticTotal)

  // Chart data
  let hasCarryover = $derived(scores.some(s => s.bool_carried_over))
  let carriedResultIds = $derived(new Set(scores.filter(s => s.bool_carried_over).map(s => s.id_result)))

  interface ChartItem {
    score: number
    code: string
    marker: string
    type: string
    carried: boolean
  }

  let domesticChart = $derived.by((): ChartItem[] => {
    // Current PPW first (by score desc), then carried PPW (by score desc), then MPW last
    const currentPpw = ppwScoresSorted.filter(s => !s.bool_carried_over)
    const carriedPpw = ppwScoresSorted.filter(s => !!s.bool_carried_over)
    const items: ChartItem[] = []
    for (const s of currentPpw) {
      items.push({
        score: s.num_final_score ?? 0,
        code: s.txt_tournament_code,
        marker: ppwBestIds.has(s.id_result) ? '★' : '',
        type: 'PPW',
        carried: false,
      })
    }
    for (const s of carriedPpw) {
      const best = ppwBestIds.has(s.id_result) ? '★' : ''
      items.push({
        score: s.num_final_score ?? 0,
        code: s.txt_tournament_code,
        marker: best + ' ↩',
        type: 'PPW',
        carried: true,
      })
    }
    if (mpwScore) {
      const carried = !!mpwScore.bool_carried_over
      items.push({
        score: mpwScore.num_final_score ?? 0,
        code: mpwScore.txt_tournament_code,
        marker: '✓' + (carried ? ' ↩' : ''),
        type: 'MPW',
        carried,
      })
    }
    return items
  })

  let internationalChart = $derived.by((): ChartItem[] => {
    if (useJsonbRules) {
      // Current first (by score desc), then carried (by score desc)
      const current = intlPoolSorted.filter(s => !s.bool_carried_over)
      const carried = intlPoolSorted.filter(s => !!s.bool_carried_over)
      return [...current, ...carried].map((s) => {
        const isCarried = !!s.bool_carried_over
        const best = intlPoolBestIds.has(s.id_result) ? '★' : ''
        return {
          score: s.num_final_score ?? 0,
          code: s.txt_tournament_code,
          marker: best + (isCarried ? ' ↩' : ''),
          type: s.enum_type,
          carried: isCarried,
        }
      })
    }
    // Legacy path
    const items: ChartItem[] = []
    if (mewScore) {
      const carried = !!mewScore.bool_carried_over
      items.push({
        score: mewScore.num_final_score ?? 0,
        code: mewScore.txt_tournament_code,
        marker: '✓' + (carried ? ' ↩' : ''),
        type: 'MEW',
        carried,
      })
    }
    for (const s of pewScoresSorted) {
      const carried = !!s.bool_carried_over
      items.push({
        score: s.num_final_score ?? 0,
        code: s.txt_tournament_code,
        marker: (pewBestIds.has(s.id_result) ? '★' : '') + (carried ? ' ↩' : ''),
        type: 'PEW',
        carried,
      })
    }
    // Current first, then carried; within each group by score desc
    items.sort((a, b) => {
      if (a.carried !== b.carried) return a.carried ? 1 : -1
      return b.score - a.score
    })
    return items
  })

  let maxScore = $derived(
    Math.max(
      ...domesticChart.map((i) => i.score),
      ...internationalChart.map((i) => i.score),
      1
    )
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

  function getMarker(s: ScoreRow): string {
    if (s.enum_type === 'PPW' && ppwBestIds.has(s.id_result)) return '★'
    if (s.enum_type === 'MPW') return '✓'
    if (useJsonbRules) {
      if (INTL_TYPES.includes(s.enum_type as (typeof INTL_TYPES)[number])) {
        return intlPoolBestIds.has(s.id_result) ? '★' : ''
      }
      return ''
    }
    // Legacy
    if (s.enum_type === 'PEW' && pewBestIds.has(s.id_result)) return '★'
    if (s.enum_type === 'MEW') return '✓'
    return ''
  }

  function onClose() {
    onclose?.()
  }

  function setMode(m: RankingMode) {
    if (m === 'KADRA' && kadraDisabled) return
    mode = m
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
  .modal-header {
    display: flex;
    justify-content: space-between;
    align-items: center;
    margin-bottom: 4px;
  }
  .modal-header h2 {
    margin: 0;
    font-size: 20px;
    color: #333;
  }
  .modal-actions {
    display: flex;
    gap: 12px;
    align-items: center;
  }
  .toggle {
    display: inline-flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
  }
  .toggle-btn {
    padding: 5px 12px;
    border: none;
    background: #fff;
    font-size: 13px;
    font-weight: 500;
    cursor: pointer;
    transition: all 0.15s;
  }
  .toggle-btn:first-child {
    border-right: 1px solid #ccc;
  }
  .toggle-btn.active {
    background: #4a90d9;
    color: #fff;
  }
  .toggle-btn:disabled {
    opacity: 0.4;
    cursor: not-allowed;
  }
  .kadra-disabled .toggle-btn:last-child {
    background: #f5f5f5;
    color: #aaa;
  }
  .btn-close {
    background: none;
    border: none;
    font-size: 24px;
    cursor: pointer;
    color: #999;
    padding: 0 4px;
  }
  .btn-close:hover {
    color: #333;
  }

  /* Subheader */
  .subheader {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: #666;
    padding: 6px 0 12px;
    border-bottom: 1px solid #eee;
    margin-bottom: 16px;
    flex-wrap: wrap;
  }
  .subheader .sep {
    color: #ccc;
  }
  .btn-export-sub {
    margin-left: auto;
    background: none;
    border: 1px solid #ccc;
    border-radius: 4px;
    padding: 3px 8px;
    font-size: 14px;
    cursor: pointer;
    color: #555;
  }
  .btn-export-sub:hover {
    background: #f0f0f0;
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
    width: 36px;
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
  .chart-marker {
    min-width: 28px;
    text-align: center;
    font-size: 13px;
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
  .table-total {
    text-align: right;
    font-size: 15px;
    font-weight: 700;
    color: #222;
    margin-bottom: 4px;
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

  .rolling-info {
    background: #fff8e6;
    border: 1px solid #f0d88a;
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 12px;
    color: #92730c;
    margin-bottom: 16px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .rolling-info strong {
    color: #7a6520;
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

  /* Tables scroll horizontally on mobile */
  .table-section {
    overflow-x: auto;
  }

  @media (max-width: 600px) {
    .modal-overlay {
      padding: 0;
      align-items: stretch;
    }
    .modal-content {
      border-radius: 0;
      padding: 16px 12px;
      max-width: none;
      min-height: 100vh;
    }
    .modal-header h2 {
      font-size: 17px;
    }
    .modal-actions {
      gap: 8px;
    }
    .toggle-btn {
      padding: 4px 8px;
      font-size: 12px;
    }
    .subheader {
      font-size: 12px;
      gap: 4px;
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
      width: 30px;
    }
    .chart-bar-bg {
      height: 16px;
    }
    table {
      font-size: 12px;
      min-width: 480px;
    }
    th {
      padding: 6px;
    }
    td {
      padding: 4px 6px;
    }
  }
</style>
