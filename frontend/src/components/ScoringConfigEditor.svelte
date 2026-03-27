<div class="config-banner">{t('sc_banner', { season: seasonCode })}</div>

<div class="config-editor">
  <!-- Info banner -->
  <div class="config-info">
    <span class="info-icon">i</span>
    {@html t('sc_info', { season: seasonCode })}
  </div>

  <!-- Section 1: Base params -->
  <div class="config-section">
    <div class="config-section-header" onclick={() => toggleSection('base')}>
      <span class="section-icon">&#9881;</span>
      {t('sc_base_params')}
      <span class="chevron" class:collapsed={collapsedSections.base}>&#9660;</span>
    </div>
    {#if !collapsedSections.base}
      <div class="config-section-body">
        <div class="field-row">
          <label>{t('sc_mp_value')}</label>
          <input type="number" data-field="mp_value" bind:value={draft.mp_value} />
          <span class="hint">{t('sc_mp_hint')}</span>
        </div>
        <div class="field-row">
          <label>{t('sc_expected_rounds')}</label>
          <input type="number" data-field="ppw_total_rounds" bind:value={draft.ppw_total_rounds} />
          <span class="hint">{t('sc_rounds_hint')}</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 2: Podium bonuses -->
  <div class="config-section">
    <div class="config-section-header" onclick={() => toggleSection('podium')}>
      <span class="section-icon">&#127942;</span>
      {t('sc_podium')}
      <span class="chevron" class:collapsed={collapsedSections.podium}>&#9660;</span>
    </div>
    {#if !collapsedSections.podium}
      <div class="config-section-body">
        <div class="field-row">
          <label>&#129351; {t('sc_gold')}</label>
          <input type="number" data-field="podium_gold" bind:value={draft.podium_gold} />
          <span class="hint">{t('sc_gold_hint')}</span>
        </div>
        <div class="field-row">
          <label>&#129352; {t('sc_silver')}</label>
          <input type="number" data-field="podium_silver" bind:value={draft.podium_silver} />
        </div>
        <div class="field-row">
          <label>&#129353; {t('sc_bronze')}</label>
          <input type="number" data-field="podium_bronze" bind:value={draft.podium_bronze} />
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 3: Tournament multipliers -->
  <div class="config-section">
    <div class="config-section-header" onclick={() => toggleSection('mult')}>
      <span class="section-icon">&#128202;</span>
      {t('sc_multipliers')}
      <span class="chevron" class:collapsed={collapsedSections.mult}>&#9660;</span>
    </div>
    {#if !collapsedSections.mult}
      <div class="config-section-body">
        <div class="mult-grid">
          <div class="mult-card">
            <div><span class="type-badge domestic">PPW</span></div>
            <input type="number" step="0.0001" data-field="ppw_multiplier" bind:value={draft.ppw_multiplier} />
            <div class="card-label">{t('sc_ppw_label')}</div>
          </div>
          <div class="mult-card">
            <div><span class="type-badge domestic">MPW</span></div>
            <input type="number" step="0.0001" data-field="mpw_multiplier" bind:value={draft.mpw_multiplier} />
            <div class="card-label">{t('sc_mpw_label')}</div>
          </div>
          <div class="mult-card">
            <div><span class="type-badge international">PEW</span></div>
            <input type="number" step="0.0001" data-field="pew_multiplier" bind:value={draft.pew_multiplier} />
            <div class="card-label">{t('sc_pew_label')}</div>
          </div>
          <div class="mult-card">
            <div><span class="type-badge international">MEW</span></div>
            <input type="number" step="0.0001" data-field="mew_multiplier" bind:value={draft.mew_multiplier} />
            <div class="card-label">{t('sc_mew_label')}</div>
          </div>
          <div class="mult-card">
            <div><span class="type-badge international">MSW</span></div>
            <input type="number" step="0.0001" data-field="msw_multiplier" bind:value={draft.msw_multiplier} />
            <div class="card-label">{t('sc_msw_label')}</div>
          </div>
          <div class="mult-card">
            <div><span class="type-badge international">PSW</span></div>
            <input type="number" step="0.0001" data-field="psw_multiplier" bind:value={draft.psw_multiplier} />
            <div class="card-label">{t('sc_psw_label')}</div>
          </div>
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 4: Intake rules -->
  <div class="config-section">
    <div class="config-section-header" onclick={() => toggleSection('intake')}>
      <span class="section-icon">&#128678;</span>
      {t('sc_intake')}
      <span class="chevron" class:collapsed={collapsedSections.intake}>&#9660;</span>
    </div>
    {#if !collapsedSections.intake}
      <div class="config-section-body">
        <div class="field-row">
          <label>{t('sc_min_ppw')}</label>
          <input type="number" data-field="min_participants_ppw" bind:value={draft.min_participants_ppw} />
        </div>
        <div class="field-row">
          <label>{t('sc_min_evf')}</label>
          <input type="number" data-field="min_participants_evf" bind:value={draft.min_participants_evf} />
          <span class="hint">{t('sc_min_evf_hint')}</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 5: Ranking rules (buckets) -->
  <div class="config-section">
    <div class="config-section-header" onclick={() => toggleSection('rules')}>
      <span class="section-icon">&#129926;</span>
      {t('sc_rules')}
      <span class="chevron" class:collapsed={collapsedSections.rules}>&#9660;</span>
    </div>
    {#if !collapsedSections.rules}
      <div class="config-section-body">
        <div class="rules-domestic">
          <div class="pool-label">&#127968; {t('sc_pool_domestic')}</div>
          {#each draftRules.domestic as bucket, i}
            <div class="bucket-row">
              <div class="bucket-types">
                {#each bucket.types as tp}
                  <span class="tag" class:domestic={isDomesticType(tp)} class:international={!isDomesticType(tp)}>{tp}</span>
                {/each}
              </div>
              <div class="bucket-rule">
                <select value={bucket.always ? 'all' : 'best'} onchange={(e) => toggleBucketMode('domestic', i, (e.target as HTMLSelectElement).value)}>
                  <option value="best">{t('sc_rule_best')}</option>
                  <option value="all">{t('sc_rule_all')}</option>
                </select>
                {#if !bucket.always}
                  <input type="number" value={bucket.best ?? 1} onchange={(e) => updateBucketBest('domestic', i, parseInt((e.target as HTMLInputElement).value))} />
                  <span class="rule-label">{t('sc_rule_results')}</span>
                {:else}
                  <span class="always-label">{t('sc_rule_always')}</span>
                {/if}
              </div>
              <button class="remove-bucket-btn" title="Remove" onclick={() => removeBucket('domestic', i)}>&#10005;</button>
            </div>
          {/each}
          {#if addingBucket?.pool === 'domestic'}
            <div class="new-bucket-picker">
              <div class="picker-types">
                {#each [...DOMESTIC_TYPES, ...INTERNATIONAL_TYPES] as tp}
                  <button
                    class="picker-type-btn"
                    class:selected={addingBucket.types.has(tp)}
                    class:domestic={isDomesticType(tp)}
                    class:international={!isDomesticType(tp)}
                    onclick={() => toggleNewBucketType(tp)}
                  >{tp}</button>
                {/each}
              </div>
              <button class="picker-confirm" disabled={addingBucket.types.size === 0} onclick={confirmAddBucket}>&#10003;</button>
              <button class="picker-cancel" onclick={cancelAddBucket}>&#10005;</button>
            </div>
          {:else}
            <button class="add-bucket-btn" onclick={() => startAddBucket('domestic')}>{t('sc_add_bucket')}</button>
          {/if}
        </div>

        <hr class="bucket-divider" />

        <div class="rules-international">
          <div class="pool-label">&#127758; {t('sc_pool_international')}</div>
          {#each draftRules.international as bucket, i}
            <div class="bucket-row">
              <div class="bucket-types">
                {#each bucket.types as tp}
                  <span class="tag" class:domestic={isDomesticType(tp)} class:international={!isDomesticType(tp)}>{tp}</span>
                {/each}
              </div>
              <div class="bucket-rule">
                <select value={bucket.always ? 'all' : 'best'} onchange={(e) => toggleBucketMode('international', i, (e.target as HTMLSelectElement).value)}>
                  <option value="best">{t('sc_rule_best')}</option>
                  <option value="all">{t('sc_rule_all')}</option>
                </select>
                {#if !bucket.always}
                  <input type="number" value={bucket.best ?? 1} onchange={(e) => updateBucketBest('international', i, parseInt((e.target as HTMLInputElement).value))} />
                  <span class="rule-label">{t('sc_rule_results')}</span>
                {:else}
                  <span class="always-label">{t('sc_rule_always')}</span>
                {/if}
              </div>
              <button class="remove-bucket-btn" title="Remove" onclick={() => removeBucket('international', i)}>&#10005;</button>
            </div>
          {/each}
          {#if addingBucket?.pool === 'international'}
            <div class="new-bucket-picker">
              <div class="picker-types">
                {#each [...DOMESTIC_TYPES, ...INTERNATIONAL_TYPES] as tp}
                  <button
                    class="picker-type-btn"
                    class:selected={addingBucket.types.has(tp)}
                    class:domestic={isDomesticType(tp)}
                    class:international={!isDomesticType(tp)}
                    onclick={() => toggleNewBucketType(tp)}
                  >{tp}</button>
                {/each}
              </div>
              <button class="picker-confirm" disabled={addingBucket.types.size === 0} onclick={confirmAddBucket}>&#10003;</button>
              <button class="picker-cancel" onclick={cancelAddBucket}>&#10005;</button>
            </div>
          {:else}
            <button class="add-bucket-btn" onclick={() => startAddBucket('international')}>{t('sc_add_bucket')}</button>
          {/if}
        </div>
      </div>
    {/if}
  </div>

  <!-- Footer actions -->
  <div class="config-footer">
    <button class="config-export-btn" onclick={handleExport}>{t('sc_export')}</button>
    <button class="config-cancel-btn" onclick={oncancel}>{t('sc_cancel')}</button>
    <button class="config-save-btn" onclick={handleSave}>{t('sc_save')}</button>
  </div>
</div>

<script lang="ts">
  import type { ScoringConfig, RankingBucket, RankingRules } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    config,
    seasonCode,
    onsave = (_c: ScoringConfig) => {},
    oncancel = () => {},
  }: {
    config: ScoringConfig
    seasonCode: string
    onsave?: (config: ScoringConfig) => void
    oncancel?: () => void
  } = $props()

  let draft: ScoringConfig = $state(JSON.parse(JSON.stringify(config)))

  let draftRules: RankingRules = $state(
    config.ranking_rules
      ? JSON.parse(JSON.stringify(config.ranking_rules))
      : { domestic: [], international: [] },
  )

  let collapsedSections: Record<string, boolean> = $state({
    base: false,
    podium: false,
    mult: false,
    intake: false,
    rules: false,
  })

  function toggleSection(key: string) {
    collapsedSections[key] = !collapsedSections[key]
  }

  function isDomesticType(tp: string): boolean {
    return tp === 'PPW' || tp === 'MPW'
  }

  const DOMESTIC_TYPES = ['PPW', 'MPW']
  const INTERNATIONAL_TYPES = ['PEW', 'MEW', 'MSW', 'PSW']

  let addingBucket: { pool: 'domestic' | 'international', types: Set<string> } | null = $state(null)

  function startAddBucket(pool: 'domestic' | 'international') {
    addingBucket = { pool, types: new Set<string>() }
  }

  function toggleNewBucketType(tp: string) {
    if (!addingBucket) return
    const next = new Set(addingBucket.types)
    if (next.has(tp)) next.delete(tp)
    else next.add(tp)
    addingBucket = { ...addingBucket, types: next }
  }

  function confirmAddBucket() {
    if (!addingBucket || addingBucket.types.size === 0) return
    const pool = addingBucket.pool
    draftRules[pool] = [...draftRules[pool], { types: [...addingBucket.types], best: 1 }]
    addingBucket = null
  }

  function cancelAddBucket() {
    addingBucket = null
  }

  function removeBucket(pool: 'domestic' | 'international', index: number) {
    draftRules[pool] = draftRules[pool].filter((_, i) => i !== index)
  }

  function toggleBucketMode(pool: 'domestic' | 'international', index: number, mode: string) {
    const bucket = { ...draftRules[pool][index] }
    if (mode === 'all') {
      bucket.always = true
      delete bucket.best
    } else {
      bucket.always = false
      bucket.best = 1
    }
    draftRules[pool] = draftRules[pool].map((b, i) => (i === index ? bucket : b))
  }

  function updateBucketBest(pool: 'domestic' | 'international', index: number, value: number) {
    const bucket = { ...draftRules[pool][index], best: value }
    draftRules[pool] = draftRules[pool].map((b, i) => (i === index ? bucket : b))
  }

  function handleSave() {
    const updated: ScoringConfig = { ...draft, ranking_rules: draftRules }
    onsave(updated)
  }

  function handleExport() {
    const json = JSON.stringify({ ...draft, ranking_rules: draftRules }, null, 2)
    const blob = new Blob([json], { type: 'application/json' })
    const url = URL.createObjectURL(blob)
    const a = document.createElement('a')
    a.href = url
    a.download = `scoring_config_${seasonCode}.json`
    a.click()
    URL.revokeObjectURL(url)
  }
</script>

<style>
  /* Banner */
  .config-banner {
    background: #4a90d9;
    color: #fff;
    padding: 10px 16px;
    border-radius: 6px 6px 0 0;
    font-weight: 600;
    font-size: 14px;
  }

  /* Editor container */
  .config-editor {
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 0 0 6px 6px;
    padding: 14px;
  }

  /* Info banner */
  .config-info {
    background: #e1f0ff;
    border: 1px solid #b3d4f0;
    border-radius: 6px;
    padding: 10px 14px;
    font-size: 13px;
    color: #1a6fbf;
    margin-bottom: 14px;
    display: flex;
    align-items: center;
    gap: 8px;
  }
  .info-icon {
    display: inline-flex;
    align-items: center;
    justify-content: center;
    width: 20px;
    height: 20px;
    border-radius: 50%;
    background: #4a90d9;
    color: #fff;
    font-size: 12px;
    font-weight: 700;
    flex-shrink: 0;
  }

  /* Collapsible sections */
  .config-section {
    background: #fafbfc;
    border: 1px solid #e0e0e0;
    border-radius: 6px;
    margin-bottom: 12px;
    overflow: hidden;
  }
  .config-section-header {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 8px 14px;
    background: #f0f2f5;
    border-bottom: 1px solid #e0e0e0;
    font-size: 13px;
    font-weight: 700;
    color: #444;
    cursor: pointer;
    user-select: none;
  }
  .config-section-header:hover {
    background: #e8ecf1;
  }
  .section-icon {
    font-size: 15px;
  }
  .chevron {
    margin-left: auto;
    font-size: 10px;
    color: #999;
    transition: transform 0.2s;
  }
  .chevron.collapsed {
    transform: rotate(-90deg);
  }
  .config-section-body {
    padding: 12px 14px;
  }

  /* Field rows */
  .field-row {
    display: flex;
    align-items: center;
    gap: 10px;
    margin-bottom: 8px;
  }
  .field-row label {
    flex: 0 0 200px;
    font-size: 13px;
    color: #555;
    text-align: right;
  }
  .field-row input {
    width: 100px;
    padding: 5px 8px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
    font-family: monospace;
    background: #fff;
  }
  .field-row input:focus {
    outline: none;
    border-color: #4a90d9;
  }
  .hint {
    font-size: 11px;
    color: #aaa;
    font-style: italic;
  }

  /* Multiplier grid */
  .mult-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 8px;
  }
  .mult-card {
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 6px;
    padding: 10px;
    text-align: center;
  }
  .type-badge {
    display: inline-block;
    padding: 2px 8px;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
    margin-bottom: 6px;
  }
  .type-badge.domestic {
    background: #e6f4ea;
    color: #1a7f37;
  }
  .type-badge.international {
    background: #fff8e1;
    color: #b8860b;
  }
  .mult-card input {
    width: 80px;
    padding: 5px 8px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
    font-family: monospace;
    text-align: center;
  }
  .mult-card input:focus {
    outline: none;
    border-color: #4a90d9;
  }
  .card-label {
    font-size: 11px;
    color: #888;
    margin-top: 4px;
  }

  /* Pool labels */
  .pool-label {
    font-size: 12px;
    font-weight: 700;
    color: #444;
    text-transform: uppercase;
    letter-spacing: 0.5px;
    margin: 8px 0 6px;
  }

  /* Bucket rows */
  .bucket-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    background: #fff;
    border: 1px solid #e0e0e0;
    border-radius: 4px;
    margin-bottom: 6px;
  }
  .bucket-types {
    display: flex;
    gap: 4px;
    flex: 1;
  }
  .tag {
    padding: 2px 6px;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
  }
  .tag.domestic {
    background: #e6f4ea;
    color: #1a7f37;
  }
  .tag.international {
    background: #fff8e1;
    color: #b8860b;
  }
  .bucket-rule {
    display: flex;
    align-items: center;
    gap: 6px;
  }
  .bucket-rule select {
    padding: 3px 6px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 12px;
    background: #fff;
  }
  .bucket-rule input {
    width: 40px;
    padding: 3px 6px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 12px;
    font-family: monospace;
    text-align: center;
  }
  .rule-label {
    font-size: 12px;
    color: #888;
  }
  .always-label {
    font-size: 12px;
    color: #1a7f37;
    font-weight: 600;
  }
  .remove-bucket-btn {
    background: none;
    border: none;
    color: #c33;
    cursor: pointer;
    font-size: 14px;
    padding: 2px 4px;
  }
  .add-bucket-btn {
    color: #ff6b35;
    font-size: 12px;
    font-weight: 600;
    cursor: pointer;
    padding: 4px 8px;
    border: 1px dashed #ff6b35;
    border-radius: 4px;
    background: transparent;
    margin-top: 4px;
  }
  .add-bucket-btn:hover {
    background: #fff4e6;
  }

  /* New bucket type picker */
  .new-bucket-picker {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 6px 10px;
    background: #fff;
    border: 1px dashed #ff6b35;
    border-radius: 4px;
    margin-top: 4px;
  }
  .picker-types {
    display: flex;
    gap: 4px;
    flex: 1;
  }
  .picker-type-btn {
    padding: 3px 8px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 11px;
    font-weight: 600;
    cursor: pointer;
    background: #f5f5f5;
    color: #888;
    transition: all 0.15s;
  }
  .picker-type-btn.selected.domestic {
    background: #e6f4ea;
    color: #1a7f37;
    border-color: #1a7f37;
  }
  .picker-type-btn.selected.international {
    background: #fff8e1;
    color: #b8860b;
    border-color: #b8860b;
  }
  .picker-type-btn:hover {
    border-color: #999;
  }
  .picker-confirm {
    background: none;
    border: none;
    color: #1a7f37;
    cursor: pointer;
    font-size: 16px;
    font-weight: 700;
    padding: 2px 6px;
  }
  .picker-confirm:disabled {
    color: #ccc;
    cursor: default;
  }
  .picker-cancel {
    background: none;
    border: none;
    color: #c33;
    cursor: pointer;
    font-size: 14px;
    padding: 2px 4px;
  }
  .bucket-divider {
    border: none;
    border-top: 1px solid #e0e0e0;
    margin: 10px 0;
  }

  /* Footer */
  .config-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 10px 0 0;
    margin-top: 14px;
    border-top: 1px solid #ddd;
  }
  .config-export-btn {
    padding: 8px 16px;
    border: 1px solid #ccc;
    border-radius: 6px;
    background: #fff;
    color: #666;
    font-size: 13px;
    cursor: pointer;
    margin-right: auto;
  }
  .config-export-btn:hover {
    border-color: #999;
    color: #333;
  }
  .config-cancel-btn {
    padding: 8px 16px;
    border: 1px solid #ccc;
    border-radius: 6px;
    background: #fff;
    color: #666;
    font-size: 13px;
    cursor: pointer;
  }
  .config-cancel-btn:hover {
    border-color: #999;
    color: #333;
  }
  .config-save-btn {
    padding: 8px 16px;
    border: none;
    border-radius: 6px;
    background: #4a90d9;
    color: #fff;
    font-size: 13px;
    font-weight: 600;
    cursor: pointer;
  }
  .config-save-btn:hover {
    background: #3a7bc8;
  }
</style>
