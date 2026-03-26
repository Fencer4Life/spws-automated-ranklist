{#if isAdmin}
  <div data-field="identity-queue" class="identity-queue">
    <div class="queue-header">
      <h3>{t('identity_title')}</h3>
      <div class="status-counts">
        {#each statusKeys as status}
          <span data-field="count-{status}" class="count-badge count-{status.toLowerCase()}">
            {status}: {statusCounts.get(status) ?? 0}
          </span>
        {/each}
      </div>
    </div>

    <div class="filter-bar">
      <select data-field="status-filter" class="status-filter" bind:value={statusFilter}>
        <option value="ALL">{t('identity_filter_all')}</option>
        <option value="PENDING">{t('identity_filter_pending')}</option>
        <option value="AUTO_MATCHED">AUTO_MATCHED</option>
        <option value="UNMATCHED">UNMATCHED</option>
        <option value="APPROVED">APPROVED</option>
        <option value="NEW_FENCER">NEW_FENCER</option>
        <option value="DISMISSED">DISMISSED</option>
      </select>
    </div>

    <table class="queue-table">
      <thead>
        <tr>
          <th>{t('identity_scraped_name')}</th>
          <th>{t('identity_confidence')}</th>
          <th>{t('identity_suggested')}</th>
          <th>Status</th>
          <th>Actions</th>
        </tr>
      </thead>
      <tbody>
        {#each filteredCandidates as candidate (candidate.id_match)}
          <tr data-field="candidate-row" class="candidate-row">
            <td>
              <span class="scraped-name">{candidate.txt_scraped_name}</span>
              {#if candidate.txt_tournament_code}
                <span class="tournament-code">{candidate.txt_tournament_code}</span>
              {/if}
            </td>
            <td>
              <span
                data-field="confidence-badge"
                class="confidence-badge {confidenceClass(candidate.num_confidence)}"
              >
                {candidate.num_confidence ?? '—'}%
              </span>
            </td>
            <td>{candidate.txt_fencer_name ?? '—'}</td>
            <td>
              <span data-field="status-badge" class="status-badge status-{candidate.enum_status.toLowerCase()}">
                {candidate.enum_status}
              </span>
            </td>
            <td class="actions">
              {#if candidate.enum_status === 'PENDING' && candidate.id_fencer != null}
                <button data-field="approve-btn" class="action-btn approve" onclick={() => { onapprove(candidate.id_match, candidate.id_fencer!) }}>
                  {t('identity_approve')}
                </button>
              {/if}
              {#if candidate.enum_status === 'UNMATCHED' && isDomestic(candidate.enum_type)}
                <button data-field="create-new-btn" class="action-btn create-new" onclick={() => { oncreatenew(candidate.id_match) }}>
                  {t('identity_create_new')}
                </button>
              {/if}
              {#if candidate.enum_status === 'PENDING' || candidate.enum_status === 'UNMATCHED'}
                <button data-field="dismiss-btn" class="action-btn dismiss" onclick={() => { ondismiss(candidate.id_match) }}>
                  {t('identity_dismiss')}
                </button>
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<script lang="ts">
  import type { MatchCandidate, MatchStatus, TournamentType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    candidates = [] as MatchCandidate[],
    isAdmin = false,
    onapprove = (_id: number, _fencerId: number) => {},
    oncreatenew = (_id: number) => {},
    ondismiss = (_id: number) => {},
  }: {
    candidates?: MatchCandidate[]
    isAdmin?: boolean
    onapprove?: (id: number, fencerId: number) => void
    oncreatenew?: (id: number) => void
    ondismiss?: (id: number) => void
  } = $props()

  let statusFilter: MatchStatus | 'ALL' = $state('PENDING')

  const statusKeys: MatchStatus[] = ['PENDING', 'AUTO_MATCHED', 'UNMATCHED', 'APPROVED', 'NEW_FENCER', 'DISMISSED']

  let statusCounts = $derived(
    new Map(statusKeys.map(s => [s, candidates.filter(c => c.enum_status === s).length]))
  )

  let filteredCandidates = $derived(
    statusFilter === 'ALL'
      ? candidates
      : candidates.filter(c => c.enum_status === statusFilter)
  )

  function confidenceClass(confidence: number | null): string {
    if (confidence == null) return 'confidence-low'
    if (confidence >= 95) return 'confidence-high'
    if (confidence >= 50) return 'confidence-medium'
    return 'confidence-low'
  }

  function isDomestic(type: TournamentType | null): boolean {
    return type === 'PPW' || type === 'MPW'
  }
</script>

<style>
  .identity-queue {
    padding: 16px;
  }
  .queue-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 12px;
  }
  .queue-header h3 {
    margin: 0;
    font-size: 18px;
    color: #333;
  }
  .status-counts {
    display: flex;
    gap: 6px;
    flex-wrap: wrap;
  }
  .count-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
    background: #e9ecef;
    color: #555;
  }
  .count-badge.count-pending { background: #fff3cd; color: #856404; }
  .count-badge.count-approved { background: #d4edda; color: #155724; }
  .count-badge.count-unmatched { background: #f8d7da; color: #721c24; }
  .filter-bar {
    margin-bottom: 12px;
  }
  .status-filter {
    padding: 6px 12px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
  }
  .queue-table {
    width: 100%;
    border-collapse: collapse;
    font-size: 13px;
  }
  .queue-table th {
    text-align: left;
    padding: 8px 10px;
    border-bottom: 2px solid #dee2e6;
    color: #555;
    font-weight: 600;
  }
  .queue-table td {
    padding: 8px 10px;
    border-bottom: 1px solid #f0f0f0;
    vertical-align: middle;
  }
  .scraped-name {
    font-weight: 600;
    color: #333;
  }
  .tournament-code {
    display: block;
    font-size: 11px;
    color: #888;
  }
  .confidence-badge {
    padding: 2px 8px;
    border-radius: 10px;
    font-size: 12px;
    font-weight: 600;
  }
  .confidence-high { background: #d4edda; color: #155724; }
  .confidence-medium { background: #fff3cd; color: #856404; }
  .confidence-low { background: #f8d7da; color: #721c24; }
  .status-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    font-weight: 600;
  }
  .status-badge.status-pending { background: #fff3cd; color: #856404; }
  .status-badge.status-auto_matched { background: #d4edda; color: #155724; }
  .status-badge.status-unmatched { background: #f8d7da; color: #721c24; }
  .status-badge.status-approved { background: #d4edda; color: #155724; }
  .status-badge.status-new_fencer { background: #cce5ff; color: #004085; }
  .status-badge.status-dismissed { background: #e9ecef; color: #555; }
  .actions {
    display: flex;
    gap: 6px;
  }
  .action-btn {
    padding: 4px 10px;
    border: none;
    border-radius: 4px;
    font-size: 12px;
    cursor: pointer;
    font-weight: 600;
  }
  .action-btn.approve { background: #d4edda; color: #155724; }
  .action-btn.create-new { background: #cce5ff; color: #004085; }
  .action-btn.dismiss { background: #f8d7da; color: #721c24; }
</style>
