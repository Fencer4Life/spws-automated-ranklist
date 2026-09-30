import * as XLSX from 'xlsx'
import type { RankingPpwRow, RankingFullRow, ScoreRow, RankingMode } from './types'
import { t } from './locale.svelte'

function triggerDownload(wb: XLSX.WorkBook, filename: string): void {
  XLSX.writeFile(wb, filename, { bookType: 'ods' })
}

export function exportRankingPpw(rows: RankingPpwRow[], title: string): void {
  const data = rows.map((r) => ({
    Rank: r.rank,
    Fencer: r.fencer_name,
    Points: Number(r.total_score),
  }))
  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'PPW Ranking')
  triggerDownload(wb, `${title}.ods`)
}

// SS26.UI (design step 7, ADR-101): renamed from exportRankingKadra — the
// export mirrors fn_ranking_full's own spws_total/evf_plus_total/total_score
// columns, replacing the legacy fn_ranking_kadra shape.
export function exportRankingFull(rows: RankingFullRow[], title: string): void {
  const data = rows.map((r) => ({
    Rank: r.rank,
    Fencer: r.fencer_name,
    SPWS: Number(r.spws_total),
    'EVF+': Number(r.evf_plus_total),
    Razem: Number(r.total_score),
  }))
  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, 'Ranking')
  triggerDownload(wb, `${title}.ods`)
}

/**
 * One stored score component as a cell. ADR-103 (FR-140) stores -1 for a
 * component the result's method does not use, so -1 is never points: it reads
 * „nie dotyczy”. NULL, or a payload that predates the column, stays empty.
 */
function component(value: number | null | undefined): number | string {
  if (value == null) return ''
  const n = Number(value)
  return n === -1 ? t('export_not_applicable') : n
}

export function exportDrilldown(
  fencerName: string,
  scores: ScoreRow[],
  mode: RankingMode,
): void {
  const filtered =
    mode === 'PPW'
      ? scores.filter((s) => s.enum_type === 'PPW' || s.enum_type === 'MPW')
      : scores

  // SE27.UI.08: the headers follow the UI language — the export reaches
  // fencers — and name each component as the calculator does. In English they
  // keep the names this export has always used.
  const data = filtered.map((s) => ({
    [t('export_col_tournament')]: s.txt_tournament_code,
    [t('export_col_date')]: s.dt_tournament ?? '',
    [t('export_col_type')]: s.enum_type,
    [t('export_col_place')]: s.int_place,
    [t('export_col_participants')]: s.int_participant_count ?? '',
    [t('export_col_multiplier')]: s.num_multiplier != null ? Number(s.num_multiplier) : '',
    [t('export_col_method')]: s.enum_score_method ? t(`export_method_${s.enum_score_method}`) : '',
    [t('export_col_place_pts')]: component(s.num_place_pts),
    [t('export_col_de_bonus')]: component(s.num_de_bonus),
    [t('export_col_podium_bonus')]: component(s.num_podium_bonus),
    [t('export_col_category_steps')]: component(s.int_category_steps),
    [t('export_col_joined_premium')]: component(s.num_joined_premium),
    [t('export_col_cap_reduction')]: component(s.num_cap_reduction),
    [t('export_col_final_score')]: s.num_final_score != null ? Number(s.num_final_score) : '',
  }))

  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, fencerName.substring(0, 31))
  triggerDownload(wb, `${fencerName} - ${mode}.ods`)
}
