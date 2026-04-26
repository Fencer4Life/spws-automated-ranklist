{#if isAdmin}
  <div class="season-manager">
    <div class="season-header">
      <h3>{t('nav_admin_seasons')}</h3>
      <button data-field="add-season-btn" class="add-btn" onclick={() => { wizardOpen = true }}>
        {t('season_add')}
      </button>
    </div>

    <SeasonManagerWizard
      open={wizardOpen}
      {seasons}
      onclose={() => { wizardOpen = false }}
      onloadpriorconfig={onwizardloadprior}
      oncommit={onwizardcommit}
    />

    <div data-field="season-list" class="season-list">
      {#each seasons as season}
        <div data-field="season-card" class="season-card">
          {#if showForm && editingId === season.id_season}
            <div data-field="season-form" class="season-form">
              <!-- 🎯 Konfiguracja punktacji button — visible only for future + active seasons.
                   Past-complete seasons (dt_end < today) hide it (ADR-045). The existing
                   `readonly` prop on ScoringConfigEditor stays as defense-in-depth. -->
              {#if !isSeasonPast(season)}
                <div class="form-top-row">
                  <span class="tooltip-wrapper">
                    <button data-field="scoring-btn" class="scoring-btn" onclick={() => { onscoringconfig(season.id_season) }}>
                      🎯 {t('nav_admin_scoring')}
                    </button>
                    <span class="tooltip-text">{t('season_scoring_tooltip')}</span>
                  </span>
                </div>
              {/if}
              <label>
                {t('season_code_label')}
                <input data-field="form-code" type="text" bind:value={draftCode} />
              </label>
              <label>
                {t('season_start_label')}
                <input data-field="form-start" type="date" bind:value={draftStart} />
              </label>
              <label>
                {t('season_end_label')}
                <input data-field="form-end" type="date" bind:value={draftEnd} />
              </label>
              <label class="checkbox-label">
                <input data-field="form-evf-toggle" type="checkbox" bind:checked={draftShowEvf} />
                {t('sc_show_evf_toggle')}
              </label>

              <!-- Phase 3 — carry-over fields (ADR-044) -->
              <div class="form-section-header" data-field="carryover-section-header">🔁 Carry-over</div>
              <label data-field="carryover-days-label">
                {t('season_field_carryover_days')}
                <input
                  data-field="form-carryover-days"
                  type="number"
                  min="1"
                  max="9999"
                  bind:value={draftCarryoverDays}
                />
              </label>
              <label data-field="european-label">
                {t('season_field_european')}
                <div class="segmented" data-field="form-european-segmented">
                  <button
                    type="button"
                    class="seg"
                    class:active={draftEuropean === null}
                    onclick={() => { draftEuropean = null }}
                    data-field="form-european-none"
                  >{t('wizard_european_none')}</button>
                  <button
                    type="button"
                    class="seg"
                    class:active={draftEuropean === 'IMEW'}
                    onclick={() => { draftEuropean = 'IMEW' }}
                    data-field="form-european-imew"
                  >IMEW</button>
                  <button
                    type="button"
                    class="seg"
                    class:active={draftEuropean === 'DMEW'}
                    onclick={() => { draftEuropean = 'DMEW' }}
                    data-field="form-european-dmew"
                  >DMEW</button>
                </div>
              </label>
              <div class="european-hint">{t('season_field_european_lock_hint')}</div>

              {#if formError}
                <div class="form-error">{formError}</div>
              {/if}
              <div class="form-actions">
                <button data-field="form-save-btn" class="save-btn" onclick={() => { handleSave() }}>
                  {t('season_save')}
                </button>
                <button data-field="form-cancel-btn" class="cancel-btn" onclick={() => { closeForm() }}>
                  {t('season_cancel')}
                </button>
              </div>

              <!-- Phase 3 — skeleton inventory (ADR-044) -->
              {#if editingSkeletons.length > 0}
                <div class="skel-section-header" data-field="skel-section-header">
                  {t('season_skel_section')}
                  <span class="skel-meta">
                    {t('season_skel_count').replace('{count}', String(editingSkeletons.length))} ·
                    <button
                      type="button"
                      class="skel-revert-link"
                      data-field="skel-revert-btn"
                      onclick={handleRevert}
                    >{t('season_skel_revert')}</button>
                  </span>
                </div>
                {#if revertError}
                  <div class="form-error" data-field="skel-revert-error">{revertError}</div>
                {/if}
                {#each ['PPW', 'PEW', 'CHAMPIONSHIPS', 'OTHER'] as group}
                  {@const groupSkeletons = skeletonsBy(group as 'PPW' | 'PEW' | 'CHAMPIONSHIPS' | 'OTHER')}
                  {#if groupSkeletons.length > 0}
                    <div class="skel-group-header" data-field="skel-group-header">
                      {#if group === 'PPW'}{t('wizard_skel_ppw')}{/if}
                      {#if group === 'PEW'}{t('wizard_skel_pew')}{/if}
                      {#if group === 'CHAMPIONSHIPS'}Mistrzostwa{/if}
                      {#if group === 'OTHER'}Inne{/if}
                      <span class="skel-group-count">{groupSkeletons.length}</span>
                    </div>
                    <div class="skel-grid" data-field="skel-grid">
                      {#each groupSkeletons as skel}
                        <div class="skel-box" data-field="skel-box">
                          <span class="skel-code {codeKindClass(skel.txt_code)}">{codeKindLabel(skel.txt_code)}</span>
                          <span class="skel-name">
                            {#if skel.txt_location}
                              {skel.txt_location}{#if skel.txt_country}, {skel.txt_country}{/if}
                            {:else}
                              <span class="empty">{t('season_skel_pending')}</span>
                            {/if}
                          </span>
                          <span class="skel-badge">{t('season_skel_badge_created')}</span>
                        </div>
                      {/each}
                    </div>
                  {/if}
                {/each}
              {/if}
            </div>
            {#if scoringConfig && scoringSeasonId === season.id_season}
              <ScoringConfigEditor
                config={scoringConfig}
                seasonCode={season.txt_code}
                readonly={isSeasonPast(season)}
                onsave={onsavescoring}
                oncancel={onclosescoring}
              />
            {/if}
          {/if}
          <div data-field="season-row" class="season-row">
            <span data-field="season-code" class="season-cell">{season.txt_code}</span>
            <span data-field="season-start" class="season-cell">{season.dt_start}</span>
            <span data-field="season-end" class="season-cell">{season.dt_end}</span>
            <span class="season-cell">
              {#if season.bool_active}
                <span class="active-badge">{t('season_active_badge')}</span>
              {/if}
            </span>
            <span class="season-cell actions">
              <button data-field="edit-btn" class="icon-btn" onclick={() => { openEditForm(season) }}>&#9998;</button>
              <button data-field="delete-btn" class="icon-btn delete" onclick={() => { ondelete(season.id_season) }}>&#128465;</button>
            </span>
          </div>
        </div>
      {/each}

    </div>
  </div>
{/if}

<script lang="ts">
  import type { Season, ScoringConfig, EuropeanEventType, CarryoverEngine, SkeletonByKind, CalendarEvent } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import ScoringConfigEditor from './ScoringConfigEditor.svelte'
  import SeasonManagerWizard from './SeasonManagerWizard.svelte'

  interface WizardCommitPayload {
    code: string
    dt_start: string
    dt_end: string
    carryover_days: number
    european_type: EuropeanEventType
    carryover_engine: CarryoverEngine
    scoring_config: ScoringConfig
    show_evf: boolean
  }

  let {
    seasons = [] as Season[],
    isAdmin = false,
    onupdate = (_id: number, _code: string, _start: string, _end: string, _showEvf: boolean, _carryoverDays: number, _europeanType: EuropeanEventType): Promise<string | null> => Promise.resolve(null),
    ondelete = (_id: number) => {},
    onfetchevf = (_id: number): Promise<boolean> => Promise.resolve(false),
    onscoringconfig = (_id: number) => {},
    scoringConfig = null as ScoringConfig | null,
    scoringSeasonId = null as number | null,
    onsavescoring = (_c: ScoringConfig) => {},
    onclosescoring = () => {},
    onwizardloadprior = (_dtStart: string): Promise<{ priorConfig: ScoringConfig | null, priorCode: string | null, priorBreakdown: Required<SkeletonByKind> | null }> => Promise.resolve({ priorConfig: null, priorCode: null, priorBreakdown: null }),
    onwizardcommit = (_p: WizardCommitPayload): Promise<string | null> => Promise.resolve(null),
    onfetchskeletons = (_id: number): Promise<CalendarEvent[]> => Promise.resolve([]),
    onrevertinit = (_id: number): Promise<string | null> => Promise.resolve(null),
  }: {
    seasons?: Season[]
    isAdmin?: boolean
    onupdate?: (id: number, code: string, start: string, end: string, showEvf: boolean, carryoverDays: number, europeanType: EuropeanEventType) => Promise<string | null>
    ondelete?: (id: number) => void
    onfetchevf?: (id: number) => Promise<boolean>
    onscoringconfig?: (id: number) => void
    scoringConfig?: ScoringConfig | null
    scoringSeasonId?: number | null
    onsavescoring?: (config: ScoringConfig) => void
    onclosescoring?: () => void
    onwizardloadprior?: (dtStart: string) => Promise<{ priorConfig: ScoringConfig | null, priorCode: string | null, priorBreakdown: Required<SkeletonByKind> | null }>
    onwizardcommit?: (payload: WizardCommitPayload) => Promise<string | null>
    onfetchskeletons?: (id: number) => Promise<CalendarEvent[]>
    onrevertinit?: (id: number) => Promise<string | null>
  } = $props()

  let wizardOpen = $state(false)
  let editingSkeletons = $state<CalendarEvent[]>([])

  let showForm = $state(false)
  let editingId: number | null = $state(null)
  let draftCode = $state('')
  let draftStart = $state('')
  let draftEnd = $state('')
  let draftShowEvf = $state(false)
  let draftCarryoverDays = $state(366)
  let draftEuropean = $state<EuropeanEventType>(null)
  let formError: string | null = $state(null)
  let revertError: string | null = $state(null)

  // Past-complete season = dt_end strictly before today's date (local TZ).
  // Used to hide the 🎯 Konfiguracja punktacji button per ADR-045.
  function isSeasonPast(s: Season): boolean {
    return new Date(s.dt_end) < new Date(new Date().toDateString())
  }

  async function openEditForm(season: Season) {
    editingId = season.id_season
    draftCode = season.txt_code
    draftStart = season.dt_start
    draftEnd = season.dt_end
    draftShowEvf = await onfetchevf(season.id_season)
    draftCarryoverDays = season.int_carryover_days ?? 366
    draftEuropean = (season.enum_european_event_type ?? null) as EuropeanEventType
    formError = null
    revertError = null
    showForm = true
    // Load skeleton inventory for the edited season (CREATED status only).
    editingSkeletons = await onfetchskeletons(season.id_season)
  }

  function closeForm() {
    showForm = false
    editingId = null
    formError = null
    revertError = null
    editingSkeletons = []
  }

  async function handleSave() {
    if (editingId == null) {
      // Create flow goes through the wizard; this guard should be unreachable.
      return
    }
    formError = null
    const err = await onupdate(
      editingId,
      draftCode,
      draftStart,
      draftEnd,
      draftShowEvf,
      draftCarryoverDays,
      draftEuropean,
    )
    if (err) {
      formError = err
    } else {
      closeForm()
    }
  }

  async function handleRevert(): Promise<void> {
    if (editingId == null) return
    const count = editingSkeletons.length
    if (count === 0) return
    const confirmMsg = t('season_skel_revert_confirm').replace('{count}', String(count))
    if (!confirm(confirmMsg)) return
    revertError = null
    const err = await onrevertinit(editingId)
    if (err) {
      revertError = err
    } else {
      // Season is gone after revert; close the form.
      closeForm()
    }
  }

  // Group skeletons by kind for the inventory render. Order: PPW, PEW, then
  // championships (MPW, MSW, IMEW, DMEW). Codes that don't match any of these
  // groups land in 'other' and are appended last.
  function skeletonGroup(code: string): 'PPW' | 'PEW' | 'CHAMPIONSHIPS' | 'OTHER' {
    if (/^PPW\d/.test(code)) return 'PPW'
    if (/^PEW\d/.test(code)) return 'PEW'
    if (/^(MPW|MSW|IMEW|DMEW)/.test(code)) return 'CHAMPIONSHIPS'
    return 'OTHER'
  }

  function skeletonsBy(group: 'PPW' | 'PEW' | 'CHAMPIONSHIPS' | 'OTHER'): CalendarEvent[] {
    return editingSkeletons.filter((e) => skeletonGroup(e.txt_code) === group)
  }

  function codeKindClass(code: string): string {
    if (code.startsWith('PPW')) return 'ppw'
    if (code.startsWith('PEW')) return 'pew'
    if (code.startsWith('MPW')) return 'mpw'
    if (code.startsWith('MSW')) return 'msw'
    if (code.startsWith('IMEW')) return 'imew'
    if (code.startsWith('DMEW')) return 'dmew'
    return ''
  }

  function codeKindLabel(code: string): string {
    const m = code.match(/^([A-Z]+\d*)/)
    return m ? m[1] : code
  }
</script>

<style>
  .season-manager {
    padding: 16px;
  }
  .season-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    margin-bottom: 16px;
  }
  .season-header h3 {
    margin: 0;
    font-size: 18px;
    color: #333;
  }
  .add-btn {
    padding: 8px 16px;
    border: none;
    border-radius: 4px;
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .add-btn:hover {
    background: #3a7bc8;
  }
  .season-form {
    display: flex;
    gap: 12px;
    align-items: flex-end;
    padding: 12px;
    margin-bottom: 8px;
    background: #eef4fb;
    border: 1px solid #b8d4ee;
    border-radius: 4px;
    flex-wrap: wrap;
  }
  .season-form label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 13px;
    color: #555;
  }
  .season-form input {
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
  }
  .form-top-row {
    width: 100%;
    display: flex;
    justify-content: flex-start;
  }
  .form-actions {
    display: flex;
    gap: 8px;
    align-items: flex-end;
  }
  .save-btn {
    padding: 6px 14px;
    border: none;
    border-radius: 4px;
    background: #2ecc71;
    color: #fff;
    font-size: 13px;
    cursor: pointer;
  }
  .cancel-btn {
    padding: 6px 14px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #fff;
    color: #555;
    font-size: 13px;
    cursor: pointer;
  }
  .scoring-btn {
    padding: 6px 14px;
    border: 1px solid #e8a020;
    border-radius: 4px;
    background: #fff8e8;
    color: #8a6010;
    font-size: 14px;
    cursor: pointer;
    font-weight: 600;
  }
  .scoring-btn:hover {
    background: #fff0c8;
  }
  .tooltip-wrapper {
    position: relative;
    display: inline-block;
  }
  .tooltip-text {
    visibility: hidden;
    opacity: 0;
    position: absolute;
    bottom: 100%;
    left: 50%;
    transform: translateX(-50%);
    background: #333;
    color: #fff;
    font-size: 12px;
    padding: 6px 10px;
    border-radius: 4px;
    white-space: nowrap;
    pointer-events: none;
    transition: opacity 0.2s;
    margin-bottom: 4px;
    z-index: 10;
  }
  .tooltip-wrapper:hover .tooltip-text {
    visibility: visible;
    opacity: 1;
  }
  .form-error {
    width: 100%;
    padding: 8px 12px;
    background: #fee;
    border: 1px solid #c33;
    border-radius: 4px;
    color: #c33;
    font-size: 13px;
  }
  .season-list {
    display: flex;
    flex-direction: column;
    gap: 2px;
  }
  .season-card {
    margin-bottom: 2px;
  }
  .season-row {
    display: flex;
    align-items: center;
    gap: 16px;
    padding: 10px 12px;
    background: #fff;
    border: 1px solid #e8e8e8;
    border-radius: 4px;
  }
  .season-row:hover {
    background: #f8f9fa;
  }
  .season-cell {
    font-size: 14px;
    color: #333;
  }
  .season-cell.actions {
    margin-left: auto;
    display: flex;
    gap: 6px;
  }
  .active-badge {
    font-size: 11px;
    padding: 2px 8px;
    border-radius: 10px;
    background: #d4edda;
    color: #155724;
    font-weight: 600;
  }
  .icon-btn {
    border: none;
    background: none;
    cursor: pointer;
    font-size: 16px;
    padding: 4px;
    color: #666;
  }
  .icon-btn:hover {
    color: #333;
  }
  .icon-btn.delete:hover {
    color: #c33;
  }
  .checkbox-label {
    display: flex;
    align-items: center;
    gap: 6px;
    font-size: 13px;
    color: #555;
    cursor: pointer;
    white-space: nowrap;
  }
  .checkbox-label input[type="checkbox"] {
    accent-color: #4a90d9;
    cursor: pointer;
  }
  /* Phase 3 — carry-over fields + skeleton inventory */
  .form-section-header {
    width: 100%;
    padding: 8px 0 4px 0;
    margin-top: 8px;
    border-top: 1px dashed #ccc;
    font-size: 12px;
    color: #8a6d1b;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    font-weight: 700;
  }
  .segmented {
    display: inline-flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
    background: #fff;
    margin-top: 4px;
  }
  .segmented .seg {
    padding: 6px 12px;
    font-size: 13px;
    cursor: pointer;
    color: #555;
    border: none;
    border-right: 1px solid #ccc;
    background: transparent;
  }
  .segmented .seg:last-child {
    border-right: none;
  }
  .segmented .seg.active {
    background: #4a90d9;
    color: #fff;
    font-weight: 700;
  }
  .segmented .seg:hover:not(.active) {
    background: #f5f5f5;
  }
  .european-hint {
    font-size: 12px;
    color: #888;
    margin-top: 4px;
    width: 100%;
  }
  .skel-section-header {
    width: 100%;
    padding: 10px 0 6px 0;
    margin-top: 12px;
    border-top: 1px dashed #b794f6;
    font-size: 14px;
    color: #6b46c1;
    font-weight: 700;
    display: flex;
    align-items: center;
    gap: 10px;
    flex-wrap: wrap;
  }
  .skel-meta {
    font-size: 12px;
    color: #888;
    font-weight: 400;
  }
  .skel-revert-link {
    color: #c33;
    background: none;
    border: none;
    text-decoration: underline;
    cursor: pointer;
    padding: 0;
    font: inherit;
  }
  .skel-revert-link:hover {
    color: #a00;
  }
  .skel-group-header {
    width: 100%;
    font-size: 11px;
    color: #888;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    padding: 8px 0 4px 0;
    margin-top: 8px;
    border-bottom: 1px solid #e8e8e8;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .skel-group-count {
    background: #e1f0ff;
    color: #1a6fbf;
    padding: 1px 7px;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
  }
  .skel-grid {
    width: 100%;
    display: grid;
    grid-template-columns: repeat(auto-fill, minmax(220px, 1fr));
    gap: 6px;
    margin-top: 6px;
  }
  .skel-box {
    display: flex;
    gap: 8px;
    align-items: center;
    padding: 8px 10px;
    border: 1px solid #ddd;
    border-left: 3px solid #b794f6;
    border-radius: 4px;
    background: #f7f3ff;
    font-size: 13px;
  }
  .skel-code {
    font-family: 'SF Mono', Monaco, monospace;
    font-size: 11px;
    font-weight: 700;
    padding: 2px 8px;
    border-radius: 10px;
    min-width: 60px;
    text-align: center;
  }
  .skel-code.ppw { background: #d4edda; color: #155724; }
  .skel-code.pew { background: #d1ecf1; color: #0c5460; }
  .skel-code.mpw { background: #d4edda; color: #155724; }
  .skel-code.msw { background: #fff3cd; color: #856404; }
  .skel-code.imew { background: #fff3cd; color: #856404; }
  .skel-code.dmew { background: #e2d4f6; color: #4a2a8a; }
  .skel-name {
    flex: 1;
    color: #444;
    font-size: 13px;
  }
  .skel-name .empty {
    color: #999;
    font-style: italic;
  }
  .skel-badge {
    background: #b794f6;
    color: #fff;
    padding: 2px 6px;
    border-radius: 8px;
    font-size: 10px;
    font-weight: 700;
    text-transform: uppercase;
    letter-spacing: 0.5px;
  }
</style>
