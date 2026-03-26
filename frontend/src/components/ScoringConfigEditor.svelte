<div class="config-banner">Konfiguracja punktacji dla sezonu {seasonCode}</div>

<div class="config-editor">
  <!-- Base params -->
  <section class="config-section">
    <h3>Parametry bazowe</h3>
    <label>MP value <input type="number" data-field="mp_value" bind:value={draft.mp_value} /></label>
  </section>

  <!-- Podium bonuses -->
  <section class="config-section">
    <h3>Bonus podium</h3>
    <label>Gold <input type="number" data-field="podium_gold" bind:value={draft.podium_gold} /></label>
    <label>Silver <input type="number" data-field="podium_silver" bind:value={draft.podium_silver} /></label>
    <label>Bronze <input type="number" data-field="podium_bronze" bind:value={draft.podium_bronze} /></label>
  </section>

  <!-- Tournament multipliers -->
  <section class="config-section">
    <h3>Mnożniki turniejów</h3>
    <div class="multiplier-grid">
      <label>PPW <input type="number" step="0.1" data-field="ppw_multiplier" bind:value={draft.ppw_multiplier} /></label>
      <label>MPW <input type="number" step="0.1" data-field="mpw_multiplier" bind:value={draft.mpw_multiplier} /></label>
      <label>PEW <input type="number" step="0.1" data-field="pew_multiplier" bind:value={draft.pew_multiplier} /></label>
      <label>MEW <input type="number" step="0.1" data-field="mew_multiplier" bind:value={draft.mew_multiplier} /></label>
      <label>MSW <input type="number" step="0.1" data-field="msw_multiplier" bind:value={draft.msw_multiplier} /></label>
      <label>PSW <input type="number" step="0.1" data-field="psw_multiplier" bind:value={draft.psw_multiplier} /></label>
    </div>
  </section>

  <!-- Intake rules -->
  <section class="config-section">
    <h3>Reguły kwalifikacji</h3>
    <label>Min uczestników EVF <input type="number" data-field="min_participants_evf" bind:value={draft.min_participants_evf} /></label>
    <label>Min uczestników PPW <input type="number" data-field="min_participants_ppw" bind:value={draft.min_participants_ppw} /></label>
    <label>Liczba rund PPW <input type="number" data-field="ppw_total_rounds" bind:value={draft.ppw_total_rounds} /></label>
  </section>

  <!-- Ranking rules -->
  <section class="config-section">
    <h3>Reguły rankingowe</h3>

    <div class="rules-domestic">
      <h4>Krajowe</h4>
      {#each draftRules.domestic as bucket, i}
        <div class="bucket-row">
          <span>{bucket.types.join(', ')}</span>
          {#if bucket.best != null}
            <span>best {bucket.best}</span>
          {/if}
          {#if bucket.always}
            <span>always</span>
          {/if}
          <button class="remove-bucket-btn" onclick={() => removeBucket('domestic', i)}>✕</button>
        </div>
      {/each}
      <button class="add-bucket-btn" onclick={() => addBucket('domestic')}>+ Dodaj regułę</button>
    </div>

    <div class="rules-international">
      <h4>Międzynarodowe</h4>
      {#each draftRules.international as bucket, i}
        <div class="bucket-row">
          <span>{bucket.types.join(', ')}</span>
          {#if bucket.best != null}
            <span>best {bucket.best}</span>
          {/if}
          {#if bucket.always}
            <span>always</span>
          {/if}
          <button class="remove-bucket-btn" onclick={() => removeBucket('international', i)}>✕</button>
        </div>
      {/each}
      <button class="add-bucket-btn" onclick={() => addBucket('international')}>+ Dodaj regułę</button>
    </div>
  </section>

  <!-- Footer actions -->
  <div class="config-actions">
    <button class="config-export-btn" onclick={handleExport}>Eksport JSON</button>
    <button class="config-cancel-btn" onclick={oncancel}>Anuluj</button>
    <button class="config-save-btn" onclick={handleSave}>Zapisz i przelicz</button>
  </div>
</div>

<script lang="ts">
  import type { ScoringConfig, RankingBucket, RankingRules } from '../lib/types'

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

  let draft: ScoringConfig = $state(structuredClone(config))

  let draftRules: RankingRules = $state(
    config.ranking_rules
      ? structuredClone(config.ranking_rules)
      : { domestic: [], international: [] },
  )

  function addBucket(pool: 'domestic' | 'international') {
    draftRules[pool] = [...draftRules[pool], { types: ['PPW'], best: 1 }]
  }

  function removeBucket(pool: 'domestic' | 'international', index: number) {
    draftRules[pool] = draftRules[pool].filter((_, i) => i !== index)
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
  .config-banner {
    background: #4a90d9;
    color: #fff;
    padding: 10px 16px;
    border-radius: 6px 6px 0 0;
    font-weight: 600;
    font-size: 14px;
  }
  .config-editor {
    background: #fff;
    border: 1px solid #ddd;
    border-radius: 0 0 6px 6px;
    padding: 16px;
  }
  .config-section {
    margin-bottom: 20px;
  }
  .config-section h3 {
    font-size: 14px;
    color: #333;
    margin: 0 0 8px;
    border-bottom: 1px solid #eee;
    padding-bottom: 4px;
  }
  .config-section h4 {
    font-size: 13px;
    color: #555;
    margin: 8px 0 4px;
  }
  .config-section label {
    display: block;
    font-size: 13px;
    margin-bottom: 6px;
    color: #444;
  }
  .config-section input[type="number"] {
    width: 80px;
    padding: 4px 6px;
    border: 1px solid #ccc;
    border-radius: 3px;
    font-size: 13px;
    margin-left: 8px;
  }
  .multiplier-grid {
    display: grid;
    grid-template-columns: repeat(3, 1fr);
    gap: 6px;
  }
  .bucket-row {
    display: flex;
    align-items: center;
    gap: 8px;
    padding: 4px 0;
    font-size: 13px;
  }
  .remove-bucket-btn {
    background: none;
    border: none;
    color: #c33;
    cursor: pointer;
    font-size: 14px;
    padding: 0 4px;
  }
  .add-bucket-btn {
    background: none;
    border: 1px dashed #aaa;
    border-radius: 4px;
    padding: 4px 10px;
    font-size: 12px;
    color: #666;
    cursor: pointer;
    margin-top: 4px;
  }
  .config-actions {
    display: flex;
    gap: 10px;
    justify-content: flex-end;
    margin-top: 16px;
    padding-top: 12px;
    border-top: 1px solid #eee;
  }
  .config-save-btn {
    background: #4a90d9;
    color: #fff;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    font-weight: 600;
  }
  .config-cancel-btn {
    background: #eee;
    border: none;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
  }
  .config-export-btn {
    background: none;
    border: 1px solid #ccc;
    padding: 8px 16px;
    border-radius: 4px;
    cursor: pointer;
    margin-right: auto;
  }
</style>
