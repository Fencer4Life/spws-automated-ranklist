{#if open}
  <div class="wizard-overlay" data-field="wizard-overlay">
    <div class="wizard-modal" class:confirm-step={currentStep === 3} data-field="wizard-modal">
      <!-- ===== STEP 1: identity + carry-over ===== -->
      {#if currentStep === 1}
        <div data-field="wizard-step1">
          <div class="wizard-header">
            <span class="step-pill">{t('wizard_step_pill').replace('{n}', '1')}</span>
            {t('wizard_title_step1')}
          </div>
          <div class="wizard-body">
            <p class="wizard-lead">{t('wizard_lead_step1')}</p>

            <label class="wizard-label">
              {t('wizard_field_code').toUpperCase()}
              <input
                data-field="wizard-code"
                type="text"
                placeholder="SPWS-2026-2027"
                bind:value={draftCode}
              />
            </label>

            <div class="row-2col">
              <label class="wizard-label">
                {t('wizard_field_dt_start').toUpperCase()}
                <input data-field="wizard-dt-start" type="date" bind:value={draftStart} />
              </label>
              <label class="wizard-label">
                {t('wizard_field_dt_end').toUpperCase()}
                <input data-field="wizard-dt-end" type="date" bind:value={draftEnd} />
              </label>
            </div>

            <div class="annotate-new">
              <label class="wizard-label">
                {t('wizard_field_carryover_days').toUpperCase()}
                <input
                  data-field="wizard-carryover-days"
                  type="number"
                  min="1"
                  max="9999"
                  bind:value={draftCarryoverDays}
                />
              </label>
              <div class="field-hint">
                {t('wizard_field_carryover_days_hint').replace('{n}', String(draftCarryoverDays || 366))}
              </div>
            </div>

            <div class="annotate-new" style="margin-top: 12px;">
              <label class="wizard-label">{t('wizard_field_european').toUpperCase()}</label>
              <div class="segmented" data-field="wizard-european-segmented">
                <button
                  type="button"
                  class="seg"
                  class:active={draftEuropean === null}
                  onclick={() => { draftEuropean = null }}
                  data-field="wizard-european-none"
                >{t('wizard_european_none')}</button>
                <button
                  type="button"
                  class="seg"
                  class:active={draftEuropean === 'IMEW'}
                  onclick={() => { draftEuropean = 'IMEW' }}
                  data-field="wizard-european-imew"
                >{t('wizard_european_imew')}</button>
                <button
                  type="button"
                  class="seg"
                  class:active={draftEuropean === 'DMEW'}
                  onclick={() => { draftEuropean = 'DMEW' }}
                  data-field="wizard-european-dmew"
                >{t('wizard_european_dmew')}</button>
              </div>
              <div class="field-hint">{t('wizard_field_european_hint')}</div>
            </div>

            {#if validationError}
              <div class="wizard-error" data-field="wizard-validation-error">{validationError}</div>
            {/if}

            <div class="wizard-info">{t('wizard_info_atomic')}</div>
          </div>
          <div class="wizard-actions">
            <span class="progress" data-field="wizard-progress">●○○ — {t('wizard_progress').replace('{n}', '1')}</span>
            <div class="btn-group">
              <button class="cancel-btn danger" data-field="wizard-cancel-btn" onclick={handleCancel}>
                {t('wizard_cancel')}
              </button>
              <button
                class="next-btn"
                data-field="wizard-next-btn"
                disabled={!isStep1Valid()}
                onclick={advanceToStep2}
              >{t('wizard_next')}</button>
            </div>
          </div>
        </div>
      {/if}

      <!-- ===== STEP 2: scoring config ===== -->
      {#if currentStep === 2}
        <div data-field="wizard-step2">
          <div class="wizard-header">
            <span class="step-pill">{t('wizard_step_pill').replace('{n}', '2')}</span>
            {t('wizard_title_step2').replace('{code}', draftCode)}
          </div>
          <div class="wizard-body" style="padding: 12px;">
            <p class="wizard-lead">{t('wizard_lead_step2')}</p>

            <div class="banner" data-field="wizard-banner">
              {#if priorScoringConfig && priorSeasonCode}
                ↩ {t('wizard_banner_copied').replace('{prior_code}', priorSeasonCode)}
              {:else}
                ℹ {t('wizard_banner_defaults')}
              {/if}
            </div>

            <ScoringConfigEditor
              config={effectiveScoringConfig}
              seasonCode={draftCode}
              onsave={(updated) => { capturedScoring = updated; advanceToStep3() }}
              oncancel={handleCancel}
            />
          </div>
          <div class="wizard-actions">
            <span class="progress" data-field="wizard-progress">●●○ — {t('wizard_progress').replace('{n}', '2')}</span>
            <div class="btn-group">
              <button class="cancel-btn danger" data-field="wizard-cancel-btn" onclick={handleCancel}>
                {t('wizard_cancel_all')}
              </button>
              <button class="back-btn" data-field="wizard-back-btn" onclick={() => { currentStep = 1 }}>
                {t('wizard_back')}
              </button>
            </div>
          </div>
        </div>
      {/if}

      <!-- ===== STEP 3: skeleton preview ===== -->
      {#if currentStep === 3}
        <div data-field="wizard-step3">
          <div class="wizard-header">
            <span class="step-pill">{t('wizard_step_pill').replace('{n}', '3')}</span>
            {t('wizard_title_step3').replace('{code}', draftCode)}
          </div>
          <div class="wizard-body">
            {#if priorBreakdown}
              <p class="wizard-lead">
                {t('wizard_lead_step3_with_prior')
                  .replace('{count}', String(previewTotal))
                  .replace('{child_count}', String(previewTotal * 6))
                  .replace('{prior_code}', priorSeasonCode ?? '')}
              </p>
              <div class="checklist" data-field="wizard-skel-breakdown">
                {#if priorBreakdown.PPW > 0}
                  <div class="item">
                    <span class="count" data-field="wizard-skel-ppw">{priorBreakdown.PPW}</span>
                    <span class="label">{t('wizard_skel_ppw')}</span>
                  </div>
                {/if}
                {#if priorBreakdown.PEW > 0}
                  <div class="item">
                    <span class="count" data-field="wizard-skel-pew">{priorBreakdown.PEW}</span>
                    <span class="label">{t('wizard_skel_pew')}</span>
                  </div>
                {/if}
                <div class="item">
                  <span class="count" data-field="wizard-skel-mpw">1</span>
                  <span class="label">{t('wizard_skel_mpw')}</span>
                </div>
                <div class="item">
                  <span class="count" data-field="wizard-skel-msw">1</span>
                  <span class="label">{t('wizard_skel_msw')}</span>
                </div>
                {#if draftEuropean === 'IMEW'}
                  <div class="item">
                    <span class="count" data-field="wizard-skel-imew">1</span>
                    <span class="label">{t('wizard_skel_imew')}</span>
                  </div>
                {/if}
                {#if draftEuropean === 'DMEW'}
                  <div class="item">
                    <span class="count" data-field="wizard-skel-dmew">1</span>
                    <span class="label">{t('wizard_skel_dmew')}</span>
                  </div>
                {/if}
              </div>
            {:else}
              <p class="wizard-lead">{t('wizard_lead_step3_first')}</p>
            {/if}

            {#if commitError}
              <div class="wizard-error" data-field="wizard-commit-error">{commitError}</div>
            {/if}

            <div class="wizard-info">{t('wizard_info_atomic')}</div>
          </div>
          <div class="wizard-actions">
            <span class="progress" data-field="wizard-progress">●●● — {t('wizard_progress').replace('{n}', '3')}</span>
            <div class="btn-group">
              <button class="cancel-btn danger" data-field="wizard-cancel-btn" onclick={handleCancel}>
                {t('wizard_cancel_all')}
              </button>
              <button class="back-btn" data-field="wizard-back-btn" onclick={() => { currentStep = 2 }}>
                {t('wizard_back')}
              </button>
              <button
                class="commit-btn"
                data-field="wizard-commit-btn"
                disabled={committing}
                onclick={handleCommit}
              >{t('wizard_commit')} {previewTotal > 0 ? `(${previewTotal})` : ''}</button>
            </div>
          </div>
        </div>
      {/if}
    </div>
  </div>
{/if}

<script lang="ts">
  import type { ScoringConfig, EuropeanEventType, CarryoverEngine, Season, SkeletonByKind } from '../lib/types'
  import { t } from '../lib/locale.svelte'
  import ScoringConfigEditor from './ScoringConfigEditor.svelte'

  interface CommitPayload {
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
    open = false,
    seasons = [] as Season[],
    onclose = () => {},
    onloadpriorconfig = (_dtStart: string): Promise<{ priorConfig: ScoringConfig | null, priorCode: string | null, priorBreakdown: Required<SkeletonByKind> | null }> => Promise.resolve({ priorConfig: null, priorCode: null, priorBreakdown: null }),
    oncommit = (_payload: CommitPayload): Promise<string | null> => Promise.resolve(null),
  }: {
    open?: boolean
    seasons?: Season[]
    onclose?: () => void
    onloadpriorconfig?: (dtStart: string) => Promise<{ priorConfig: ScoringConfig | null, priorCode: string | null, priorBreakdown: Required<SkeletonByKind> | null }>
    oncommit?: (payload: CommitPayload) => Promise<string | null>
  } = $props()

  // Static fallback used when no prior exists. Keep synced with
  // tbl_scoring_config column defaults; ScoringConfigEditor will deep-copy
  // this into its own draft.
  const STATIC_DEFAULT_CONFIG: ScoringConfig = {
    season_code: '',
    mp_value: 50,
    podium_gold: 3,
    podium_silver: 2,
    podium_bronze: 1,
    ppw_multiplier: 1.0,
    ppw_best_count: 4,
    ppw_total_rounds: 5,
    mpw_multiplier: 1.2,
    mpw_droppable: true,
    pew_multiplier: 1.0,
    pew_best_count: 3,
    mew_multiplier: 2.0,
    mew_droppable: true,
    msw_multiplier: 2.0,
    psw_multiplier: 2.0,
    min_participants_evf: 5,
    min_participants_ppw: 1,
    show_evf_toggle: false,
    ranking_rules: null,
    engine: 'EVENT_FK_MATCHING',
  }

  let currentStep = $state<1 | 2 | 3>(1)
  let draftCode = $state('')
  let draftStart = $state('')
  let draftEnd = $state('')
  let draftCarryoverDays = $state(366)
  let draftEuropean = $state<EuropeanEventType>(null)
  let priorScoringConfig = $state<ScoringConfig | null>(null)
  let priorSeasonCode = $state<string | null>(null)
  let priorBreakdown = $state<Required<SkeletonByKind> | null>(null)
  let capturedScoring = $state<ScoringConfig | null>(null)
  let validationError = $state<string | null>(null)
  let commitError = $state<string | null>(null)
  let committing = $state(false)

  // What we hand to ScoringConfigEditor in step 2: prior config (or static default).
  let effectiveScoringConfig = $derived(
    capturedScoring ?? priorScoringConfig ?? { ...STATIC_DEFAULT_CONFIG, season_code: draftCode || 'NEW-SEASON' },
  )

  // Total skeleton count for the commit button. Uses prior PPW + PEW counts
  // (when prior exists) plus 1 MPW + 1 MSW + optional 1 European singleton.
  let previewTotal = $derived(
    (priorBreakdown ? priorBreakdown.PPW + priorBreakdown.PEW : 0)
    + 1 // MPW
    + 1 // MSW
    + (draftEuropean ? 1 : 0),
  )

  function isStep1Valid(): boolean {
    if (!draftCode.trim() || !draftStart || !draftEnd) return false
    if (draftCarryoverDays < 1) return false
    return true
  }

  function reset(): void {
    currentStep = 1
    draftCode = ''
    draftStart = ''
    draftEnd = ''
    draftCarryoverDays = 366
    draftEuropean = null
    priorScoringConfig = null
    priorSeasonCode = null
    priorBreakdown = null
    capturedScoring = null
    validationError = null
    commitError = null
    committing = false
  }

  function handleCancel(): void {
    reset()
    onclose()
  }

  async function advanceToStep2(): Promise<void> {
    validationError = null
    if (!isStep1Valid()) {
      validationError = t('wizard_validation_required')
      return
    }
    if (new Date(draftEnd) <= new Date(draftStart)) {
      validationError = t('wizard_validation_dates')
      return
    }
    if (seasons.some((s) => s.txt_code === draftCode)) {
      validationError = t('wizard_validation_code_unique')
      return
    }
    // Pre-fetch prior season's scoring config + breakdown for steps 2 + 3.
    try {
      const prior = await onloadpriorconfig(draftStart)
      priorScoringConfig = prior.priorConfig
      priorSeasonCode = prior.priorCode
      priorBreakdown = prior.priorBreakdown
    } catch (e: unknown) {
      validationError = e instanceof Error ? e.message : String(e)
      return
    }
    currentStep = 2
  }

  function advanceToStep3(): void {
    currentStep = 3
  }

  async function handleCommit(): Promise<void> {
    if (committing) return
    commitError = null
    committing = true
    const config = capturedScoring ?? effectiveScoringConfig
    const engine: CarryoverEngine = (config.engine as CarryoverEngine | undefined) ?? 'EVENT_FK_MATCHING'
    try {
      const err = await oncommit({
        code: draftCode,
        dt_start: draftStart,
        dt_end: draftEnd,
        carryover_days: draftCarryoverDays,
        european_type: draftEuropean,
        carryover_engine: engine,
        scoring_config: config,
        show_evf: config.show_evf_toggle ?? false,
      })
      if (err) {
        commitError = err
        committing = false
        return
      }
      reset()
      onclose()
    } catch (e: unknown) {
      commitError = e instanceof Error ? e.message : String(e)
      committing = false
    }
  }
</script>

<style>
  .wizard-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.45);
    display: flex;
    align-items: flex-start;
    justify-content: center;
    padding: 36px 18px;
    z-index: 100;
    overflow-y: auto;
  }
  .wizard-modal {
    background: #fff;
    border: 2px solid #00d4ff;
    border-radius: 10px;
    width: 100%;
    max-width: 760px;
    box-shadow: 0 4px 16px rgba(0, 0, 0, 0.4);
    overflow: hidden;
  }
  .wizard-modal.confirm-step {
    border-color: #b794f6;
  }
  .wizard-header {
    background: #0f3460;
    color: #00d4ff;
    padding: 12px 18px;
    font-weight: 700;
    font-size: 15px;
    border-bottom: 1px solid #00d4ff;
    display: flex;
    align-items: center;
    gap: 10px;
  }
  .wizard-modal.confirm-step .wizard-header {
    background: #251a3a;
    color: #b794f6;
    border-bottom-color: #b794f6;
  }
  .step-pill {
    background: rgba(0, 212, 255, 0.18);
    color: #00d4ff;
    padding: 2px 10px;
    border-radius: 10px;
    font-size: 12px;
    font-weight: 700;
  }
  .wizard-modal.confirm-step .step-pill {
    background: rgba(183, 148, 246, 0.18);
    color: #b794f6;
  }
  .wizard-body {
    padding: 18px;
    color: #333;
    font-size: 14px;
    line-height: 1.55;
  }
  .wizard-lead {
    color: #444;
    margin-bottom: 12px;
  }
  .wizard-label {
    display: flex;
    flex-direction: column;
    gap: 4px;
    font-size: 11px;
    color: #4a90d9;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin-bottom: 12px;
  }
  .wizard-label input {
    background: #fff;
    border: 1px solid #ccc;
    color: #333;
    padding: 7px 10px;
    border-radius: 4px;
    font-size: 14px;
    font-family: inherit;
  }
  .wizard-label input:focus {
    outline: 1px solid #4a90d9;
    border-color: #4a90d9;
  }
  .row-2col {
    display: grid;
    grid-template-columns: 1fr 1fr;
    gap: 10px;
    margin-bottom: 12px;
  }
  .annotate-new {
    border-left: 3px solid #fbbf24;
    padding: 8px 12px;
    background: rgba(251, 191, 36, 0.06);
    border-radius: 0 6px 6px 0;
    margin-bottom: 8px;
  }
  .field-hint {
    font-size: 12px;
    color: #8a6d1b;
    margin-top: 6px;
    padding: 6px 10px;
    background: rgba(251, 191, 36, 0.10);
    border-radius: 4px;
  }
  .segmented {
    display: inline-flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
    background: #fff;
  }
  .segmented .seg {
    padding: 7px 14px;
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
  .wizard-actions {
    padding: 12px 18px;
    border-top: 1px solid #ddd;
    display: flex;
    gap: 8px;
    justify-content: space-between;
    align-items: center;
    background: #fafbfc;
  }
  .wizard-actions .progress {
    color: #888;
    font-size: 12px;
  }
  .wizard-actions .btn-group {
    display: flex;
    gap: 8px;
  }
  .next-btn, .commit-btn {
    background: #4a90d9;
    color: #fff;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;
    font-weight: 600;
  }
  .next-btn:hover:not(:disabled), .commit-btn:hover:not(:disabled) {
    background: #3a7bc8;
  }
  .next-btn:disabled, .commit-btn:disabled {
    opacity: 0.45;
    cursor: not-allowed;
  }
  .commit-btn {
    background: #b794f6;
  }
  .commit-btn:hover:not(:disabled) {
    background: #9d75e0;
  }
  .back-btn {
    background: #fff;
    color: #555;
    border: 1px solid #ccc;
    padding: 8px 14px;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;
  }
  .cancel-btn {
    background: #fff;
    color: #666;
    border: 1px solid #ccc;
    padding: 8px 14px;
    border-radius: 4px;
    font-size: 14px;
    cursor: pointer;
  }
  .cancel-btn.danger {
    color: #c33;
    border-color: #f5b5b5;
  }
  .cancel-btn.danger:hover {
    background: #fee;
  }
  .wizard-info {
    background: #e1f0ff;
    color: #1a6fbf;
    padding: 8px 12px;
    border-radius: 4px;
    font-size: 12px;
    border-left: 3px solid #4a90d9;
    margin-top: 10px;
    line-height: 1.5;
  }
  .wizard-error {
    background: #fee;
    color: #c33;
    padding: 8px 12px;
    border: 1px solid #c33;
    border-radius: 4px;
    font-size: 13px;
    margin-top: 10px;
  }
  .banner {
    background: #fff8e1;
    color: #8a6d1b;
    padding: 8px 14px;
    border-radius: 4px;
    border: 1px solid #f5dc7a;
    font-weight: 600;
    font-size: 13px;
    margin-bottom: 12px;
  }
  .checklist {
    background: #f8f9fa;
    border: 1px solid #ddd;
    border-radius: 6px;
    padding: 10px 14px;
    margin: 12px 0;
  }
  .checklist .item {
    display: flex;
    gap: 10px;
    align-items: center;
    padding: 4px 0;
    font-size: 14px;
  }
  .checklist .item .count {
    background: #e1f0ff;
    color: #1a6fbf;
    padding: 1px 8px;
    border-radius: 8px;
    font-size: 12px;
    font-weight: 700;
    min-width: 30px;
    text-align: center;
  }
  .checklist .item .label {
    flex: 1;
    color: #444;
  }
</style>
