import * as XLSX from 'xlsx'
import type { RankingPpwRow, RankingFullRow, ScoreRow, RankingMode } from './types'

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

export function exportDrilldown(
  fencerName: string,
  scores: ScoreRow[],
  mode: RankingMode,
): void {
  const filtered =
    mode === 'PPW'
      ? scores.filter((s) => s.enum_type === 'PPW' || s.enum_type === 'MPW')
      : scores

  const data = filtered.map((s) => ({
    Tournament: s.txt_tournament_code,
    Date: s.dt_tournament ?? '',
    Type: s.enum_type,
    Place: s.int_place,
    Participants: s.int_participant_count ?? '',
    Multiplier: s.num_multiplier != null ? Number(s.num_multiplier) : '',
    'Place Pts': s.num_place_pts != null ? Number(s.num_place_pts) : '',
    'DE Bonus': s.num_de_bonus != null ? Number(s.num_de_bonus) : '',
    'Podium Bonus': s.num_podium_bonus != null ? Number(s.num_podium_bonus) : '',
    'Final Score': s.num_final_score != null ? Number(s.num_final_score) : '',
  }))

  const ws = XLSX.utils.json_to_sheet(data)
  const wb = XLSX.utils.book_new()
  XLSX.utils.book_append_sheet(wb, ws, fencerName.substring(0, 31))
  triggerDownload(wb, `${fencerName} - ${mode}.ods`)
}
