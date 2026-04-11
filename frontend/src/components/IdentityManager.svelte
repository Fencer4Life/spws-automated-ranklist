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

    {#if errorMsg}
      <div data-field="identity-error" class="error-banner">{errorMsg}</div>
    {/if}

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
          <th>{t('identity_gender')}</th>
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
            <td class={isGenderMismatch(candidate) ? 'gender-mismatch' : ''}>
              {#if candidate.id_fencer != null && candidate.enum_fencer_gender != null}
                <select
                  data-field="gender-select"
                  class="gender-select {isGenderMismatch(candidate) ? 'gender-mismatch-select' : ''}"
                  value={candidate.enum_fencer_gender}
                  onchange={(e) => { onupdategender(candidate.id_fencer!, (e.target as HTMLSelectElement).value as 'M' | 'F') }}
                >
                  <option value="M">M</option>
                  <option value="F">F</option>
                </select>
                {#if isGenderMismatch(candidate)}
                  <span class="mismatch-icon" title={t('identity_gender_mismatch')}>⚠</span>
                {/if}
              {:else if candidate.id_fencer != null}
                <select
                  data-field="gender-select"
                  class="gender-select gender-mismatch-select"
                  value=""
                  onchange={(e) => { onupdategender(candidate.id_fencer!, (e.target as HTMLSelectElement).value as 'M' | 'F') }}
                >
                  <option value="" disabled>—</option>
                  <option value="M">M</option>
                  <option value="F">F</option>
                </select>
              {:else}
                <span class="gender-na">—</span>
              {/if}
            </td>
            <td>
              <span data-field="status-badge" class="status-badge status-{candidate.enum_status.toLowerCase()}">
                {candidate.enum_status}
              </span>
            </td>
            <td class="actions">
              {#if isReadOnly(candidate)}
                <!-- read-only: 100% confidence + APPROVED -->
              {:else}
                {#if candidate.id_fencer != null && (candidate.enum_status === 'PENDING' || candidate.enum_status === 'AUTO_MATCHED')}
                  <button data-field="approve-btn" class="action-btn approve" onclick={() => { onapprove(candidate.id_match, candidate.id_fencer!) }}>
                    {t('identity_approve')}
                  </button>
                {/if}
                <button data-field="create-new-btn" class="action-btn create-new" onclick={() => { creatingMatchId = candidate.id_match }}>
                  {t('identity_create_new')}
                </button>
                <button data-field="assign-btn" class="action-btn assign" onclick={() => { assigningMatchId = candidate.id_match }}>
                  {t('identity_assign')}
                </button>
                {#if candidate.enum_status === 'PENDING' || candidate.enum_status === 'UNMATCHED' || candidate.enum_status === 'AUTO_MATCHED'}
                  <button data-field="dismiss-btn" class="action-btn dismiss" onclick={() => { ondismiss(candidate.id_match) }}>
                    {t('identity_dismiss')}
                  </button>
                {/if}
              {/if}
            </td>
          </tr>
        {/each}
      </tbody>
    </table>
  </div>

  <CreateFencerModal
    open={creatingMatchId != null}
    scrapedName={creatingCandidate?.txt_scraped_name ?? ''}
    tournamentGender={creatingCandidate?.enum_tournament_gender ?? null}
    onconfirm={handleCreateConfirm}
    onclose={() => { creatingMatchId = null }}
  />

  <FencerSearchModal
    open={assigningMatchId != null}
    scrapedName={assigningCandidate?.txt_scraped_name ?? ''}
    {fencers}
    onconfirm={handleAssignConfirm}
    onclose={() => { assigningMatchId = null }}
  />
{/if}

<script lang="ts">
  import type { MatchCandidate, MatchStatus, FencerListItem, GenderType } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import CreateFencerModal from './CreateFencerModal.svelte'
  import FencerSearchModal from './FencerSearchModal.svelte'

  let {
    candidates = [] as MatchCandidate[],
    fencers = [] as FencerListItem[],
    isAdmin = false,
    errorMsg = null as string | null,
    onapprove = (_id: number, _fencerId: number) => {},
    onassign = (_id: number, _fencerId: number) => {},
    oncreatenew = (_id: number, _surname: string, _firstName: string, _gender: GenderType, _birthYear?: number) => {},
    ondismiss = (_id: number) => {},
    onupdategender = (_fencerId: number, _gender: GenderType) => {},
  }: {
    candidates?: MatchCandidate[]
    fencers?: FencerListItem[]
    isAdmin?: boolean
    errorMsg?: string | null
    onapprove?: (id: number, fencerId: number) => void
    onassign?: (id: number, fencerId: number) => void
    oncreatenew?: (id: number, surname: string, firstName: string, gender: GenderType, birthYear?: number) => void
    ondismiss?: (id: number) => void
    onupdategender?: (fencerId: number, gender: GenderType) => void
  } = $props()

  let statusFilter = $state<MatchStatus | 'ALL'>('PENDING')
  let creatingMatchId: number | null = $state(null)
  let assigningMatchId: number | null = $state(null)

  const statusKeys: MatchStatus[] = ['PENDING', 'AUTO_MATCHED', 'UNMATCHED', 'APPROVED', 'NEW_FENCER', 'DISMISSED']

  let statusCounts = $derived(
    new Map(statusKeys.map(s => [s, candidates.filter(c => c.enum_status === s).length]))
  )

  let filteredCandidates = $derived(
    statusFilter === 'ALL'
      ? candidates
      : candidates.filter(c => c.enum_status === statusFilter)
  )

  let creatingCandidate = $derived(
    creatingMatchId != null ? candidates.find(c => c.id_match === creatingMatchId) ?? null : null
  )

  let assigningCandidate = $derived(
    assigningMatchId != null ? candidates.find(c => c.id_match === assigningMatchId) ?? null : null
  )

  function confidenceClass(confidence: number | null): string {
    if (confidence == null) return 'confidence-low'
    if (confidence >= 95) return 'confidence-high'
    if (confidence >= 50) return 'confidence-medium'
    return 'confidence-low'
  }

  function isReadOnly(candidate: MatchCandidate): boolean {
    return candidate.num_confidence === 100 && candidate.enum_status === 'APPROVED'
  }

  function isGenderMismatch(candidate: MatchCandidate): boolean {
    return candidate.enum_fencer_gender != null
      && candidate.enum_tournament_gender != null
      && candidate.enum_fencer_gender !== candidate.enum_tournament_gender
  }

  function handleCreateConfirm(surname: string, firstName: string, gender: GenderType, birthYear?: number) {
    if (creatingMatchId != null) {
      oncreatenew(creatingMatchId, surname, firstName, gender, birthYear)
      creatingMatchId = null
    }
  }

  function handleAssignConfirm(fencerId: number) {
    if (assigningMatchId != null) {
      onassign(assigningMatchId, fencerId)
      assigningMatchId = null
    }
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
    flex-wrap: wrap;
    gap: 8px;
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
  .error-banner {
    margin-bottom: 12px;
    padding: 10px 14px;
    background: #fff0f0;
    border: 1px solid #fcc;
    border-radius: 4px;
    color: #c33;
    font-size: 13px;
  }
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
  .gender-select {
    padding: 3px 6px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 12px;
    font-weight: 600;
  }
  .gender-mismatch-select {
    border-color: #dc3545;
    color: #dc3545;
  }
  .gender-mismatch {
    background: #fff0f0;
  }
  .mismatch-icon {
    color: #dc3545;
    font-size: 14px;
    margin-left: 4px;
  }
  .gender-na {
    color: #aaa;
  }
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
    flex-wrap: wrap;
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
  .action-btn.assign { background: #e2d4f0; color: #5a2d82; }
  .action-btn.dismiss { background: #f8d7da; color: #721c24; }
</style>
