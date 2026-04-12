{#if isAdmin}
  <div data-field="fencer-view" class="fencer-view">
    <div class="fencer-header">
      <span data-field="fencer-count" class="fencer-count">{t('fencer_header_count', { count: fencers.length })}</span>
    </div>

    <div data-field="tab-bar" class="tab-bar">
      <button
        data-field="tab-identities"
        class="tab-btn"
        class:active={activeTab === 'identities'}
        onclick={() => { activeTab = 'identities' }}
      >
        {t('fencer_tab_identities')}
        {#if identityCount > 0}
          <span data-field="tab-badge-identities" class="tab-badge">{identityCount}</span>
        {/if}
      </button>
      <button
        data-field="tab-birth-year"
        class="tab-btn"
        class:active={activeTab === 'birth_year_review'}
        onclick={() => { activeTab = 'birth_year_review' }}
      >
        {t('fencer_tab_birth_year')}
        {#if birthYearReviewCount > 0}
          <span data-field="tab-badge-birth-year" class="tab-badge">{birthYearReviewCount}</span>
        {/if}
      </button>
    </div>

    <div class="tab-content">
      {#if activeTab === 'identities'}
        <IdentityManager
          {candidates}
          {fencers}
          {isAdmin}
          {errorMsg}
          {onapprove}
          {onassign}
          {oncreatenew}
          {ondismiss}
          {onundismiss}
          {onupdategender}
        />
      {:else}
        <BirthYearReview
          {fencers}
          {isAdmin}
          errorMsg={birthYearError}
          {onupdatebirthyear}
          {onfetchhistory}
        />
      {/if}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { MatchCandidate, FencerListItem, FencerTournamentRow, FencerTab, GenderType } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import IdentityManager from './IdentityManager.svelte'
  import BirthYearReview from './BirthYearReview.svelte'

  let {
    candidates = [] as MatchCandidate[],
    fencers = [] as FencerListItem[],
    isAdmin = false,
    errorMsg = null as string | null,
    birthYearError = null as string | null,
    onapprove = (_id: number, _fencerId: number) => {},
    onassign = (_id: number, _fencerId: number) => {},
    oncreatenew = (_id: number, _surname: string, _firstName: string, _gender: GenderType, _birthYear?: number, _birthYearEstimated?: boolean) => {},
    ondismiss = (_id: number) => {},
    onundismiss = (_id: number) => {},
    onupdategender = (_fencerId: number, _gender: GenderType) => {},
    onupdatebirthyear = (_fencerId: number, _birthYear: number, _estimated: boolean) => {},
    onfetchhistory = (_fencerId: number): Promise<FencerTournamentRow[]> => Promise.resolve([]),
  }: {
    candidates?: MatchCandidate[]
    fencers?: FencerListItem[]
    isAdmin?: boolean
    errorMsg?: string | null
    birthYearError?: string | null
    onapprove?: (id: number, fencerId: number) => void
    onassign?: (id: number, fencerId: number) => void
    oncreatenew?: (id: number, surname: string, firstName: string, gender: GenderType, birthYear?: number, birthYearEstimated?: boolean) => void
    ondismiss?: (id: number) => void
    onundismiss?: (id: number) => void
    onupdategender?: (fencerId: number, gender: GenderType) => void
    onupdatebirthyear?: (fencerId: number, birthYear: number, estimated: boolean) => void
    onfetchhistory?: (fencerId: number) => Promise<FencerTournamentRow[]>
  } = $props()

  let activeTab = $state<FencerTab>('identities')

  let identityCount = $derived(
    candidates.filter(c => c.enum_status === 'PENDING' || c.enum_status === 'AUTO_MATCHED' || c.enum_status === 'UNMATCHED').length
  )

  let birthYearReviewCount = $derived(
    fencers.filter(f => f.int_birth_year == null || f.bool_birth_year_estimated).length
  )
</script>

<style>
  .fencer-view { padding: 16px; }
  .fencer-header { margin-bottom: 8px; }
  .fencer-count { font-size: 14px; font-weight: 600; color: #555; }

  .tab-bar { display: flex; gap: 0; border-bottom: 2px solid #dee2e6; margin-bottom: 14px; }
  .tab-btn {
    padding: 8px 16px;
    border: none;
    background: none;
    font-size: 13px;
    font-weight: 600;
    color: #888;
    cursor: pointer;
    border-bottom: 2px solid transparent;
    margin-bottom: -2px;
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .tab-btn:hover { color: #555; }
  .tab-btn.active { color: #4a90d9; border-bottom-color: #4a90d9; }
  .tab-badge {
    font-size: 11px;
    padding: 1px 7px;
    border-radius: 10px;
    font-weight: 700;
    background: #fff3cd;
    color: #856404;
  }
  .tab-btn.active .tab-badge { background: #cce5ff; color: #004085; }
</style>
