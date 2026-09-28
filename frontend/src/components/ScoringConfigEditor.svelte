<div class="config-banner">{t('sc_banner', { season: seasonCode })}</div>

<div class="config-editor" class:config-readonly={readonly}>
  <!-- Info banner -->
  <div class="config-info">
    <span class="info-icon">i</span>
    {@html t('sc_info', { season: seasonCode })}
  </div>

  <!-- Section 1: Base params -->
  <div class="config-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('base')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('base') } }}>
      <span class="section-icon">&#9881;</span>
      {t('sc_base_params')}
      <span class="chevron" class:collapsed={collapsedSections.base}>&#9660;</span>
    </div>
    {#if !collapsedSections.base}
      <div class="config-section-body">
        <div class="field-row">
          <label for="mp_value">{t('sc_mp_value')}</label>
          <input id="mp_value" type="number" data-field="mp_value" bind:value={draft.mp_value} disabled={readonly} />
          <span class="hint" data-field="mp-hint">{evfHint()}</span>
        </div>
        <div class="field-row">
          <label for="ppw_total_rounds">{t('sc_expected_rounds')}</label>
          <input id="ppw_total_rounds" type="number" data-field="ppw_total_rounds" bind:value={draft.ppw_total_rounds} disabled={readonly} />
          <span class="hint">{t('sc_rounds_hint')}</span>
        </div>
        <div class="field-row">
          <label for="scoring-engine-select">{t('sc_scoring_engine_label')}</label>
          <select id="scoring-engine-select" data-field="scoring-engine-select" bind:value={draft.engine_code} disabled={readonly}>
            {#each scoringEngines as eng}
              <option value={eng.code}>{eng.label}</option>
            {/each}
          </select>
          <span class="hint">{t('sc_scoring_engine_hint')}</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 2: Podium bonuses -->
  <div class="config-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('podium')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('podium') } }}>
      <span class="section-icon">&#127942;</span>
      {t('sc_podium')}
      <span class="chevron" class:collapsed={collapsedSections.podium}>&#9660;</span>
    </div>
    {#if !collapsedSections.podium}
      <div class="config-section-body">
        <div class="field-row">
          <label for="podium_gold">&#129351; {t('sc_gold')}</label>
          <input id="podium_gold" type="number" data-field="podium_gold" bind:value={draft.podium_gold} disabled={readonly} />
          <span class="hint">{t('sc_gold_hint')}</span>
        </div>
        <div class="field-row">
          <label for="podium_silver">&#129352; {t('sc_silver')}</label>
          <input id="podium_silver" type="number" data-field="podium_silver" bind:value={draft.podium_silver} disabled={readonly} />
        </div>
        <div class="field-row">
          <label for="podium_bronze">&#129353; {t('sc_bronze')}</label>
          <input id="podium_bronze" type="number" data-field="podium_bronze" bind:value={draft.podium_bronze} disabled={readonly} />
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 3: Tournament types — engine and coefficient (ADR-103 §2) -->
  <div class="config-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('mult')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('mult') } }}>
      <span class="section-icon">&#128202;</span>
      {t('sc_multipliers')}
      <span class="chevron" class:collapsed={collapsedSections.mult}>&#9660;</span>
    </div>
    {#if !collapsedSections.mult}
      <div class="config-section-body">
        <div class="mult-grid">
          {#each TYPE_CARDS as card (card.type)}
            {@const module = moduleOf(card)}
            <div class="mult-card">
              <div><span class="type-badge {card.badge}">{card.type}</span></div>
              <input type="number" step="0.0001" data-field="{card.type.toLowerCase()}_multiplier" bind:value={draft[card.field]} disabled={readonly} />
              <select
                data-field="type-engine-{card.type}"
                aria-label={t('sc_type_engine_label', { type: card.type })}
                value={engineOf(card.type)}
                onchange={(e) => setTypeEngine(card.type, (e.target as HTMLSelectElement).value)}
                disabled={readonly}
              >
                {#each scoringEngines as eng}
                  <option value={eng.code}>{shortEngineLabel(eng)}</option>
                {/each}
              </select>
              <div class="module" data-field="type-module-{card.type}"><b>{module.code}</b>{module.text}</div>
              <div class="card-label">{t(card.labelKey)}</div>
            </div>
          {/each}
        </div>

        {#each scoringEngines.filter((eng) => ENGINE_RULES[eng.code]) as eng (eng.code)}
          <div class="ro-panel" data-field="engine-panel-{eng.code}">
            <h4>{eng.code} <span class="ro-tag">{t('sc_ro_tag')}</span></h4>
            <table>
              <tbody>
                {#each ENGINE_RULES[eng.code](eng) as row}
                  <tr><td>{row.label}</td><td>{row.text}</td></tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/each}
      </div>
    {/if}
  </div>

  <!-- Section 4: Intake rules -->
  <div class="config-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('intake')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('intake') } }}>
      <span class="section-icon">&#128678;</span>
      {t('sc_intake')}
      <span class="chevron" class:collapsed={collapsedSections.intake}>&#9660;</span>
    </div>
    {#if !collapsedSections.intake}
      <div class="config-section-body">
        <div class="field-row">
          <label for="min_participants_ppw">{t('sc_min_ppw')}</label>
          <input id="min_participants_ppw" type="number" data-field="min_participants_ppw" bind:value={draft.min_participants_ppw} disabled={readonly} />
        </div>
        <div class="field-row">
          <label for="min_participants_evf">{t('sc_min_evf')}</label>
          <input id="min_participants_evf" type="number" data-field="min_participants_evf" bind:value={draft.min_participants_evf} disabled={readonly} />
          <span class="hint">{t('sc_min_evf_hint')}</span>
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 4b: Carry-over engine selector (Phase 3, ADR-045) -->
  <div class="config-section engine-section" data-field="engine-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('engine')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('engine') } }}>
      <span class="section-icon">&#128256;</span>
      {t('sc_section_engine')}
      <span class="chevron" class:collapsed={collapsedSections.engine}>&#9660;</span>
    </div>
    {#if !collapsedSections.engine}
      <div class="config-section-body">
        <div class="field-row">
          <label for="engine-select">{t('sc_engine_label')}</label>
          <select
            id="engine-select"
            data-field="engine-select"
            bind:value={draft.carryover_engine}
            disabled={readonly}
            class:legacy={draft.carryover_engine === 'EVENT_CODE_MATCHING'}
          >
            {#each CARRYOVER_ENGINE_VALUES as engineValue}
              <option value={engineValue}>{engineLabel(engineValue)}</option>
            {/each}
          </select>
          {#if draft.carryover_engine === 'EVENT_CODE_MATCHING'}
            <span class="engine-legacy-tag" data-field="engine-legacy-tag">{t('sc_engine_legacy_tag')}</span>
          {/if}
        </div>
        <div class="engine-hint" data-field="engine-hint">
          {#if draft.carryover_engine === 'EVENT_CODE_MATCHING'}
            <strong>{t('sc_engine_hint_code')}</strong>
          {:else}
            <strong>{t('sc_engine_hint_fk')}</strong>
          {/if}
          <br />
          {t('sc_engine_hint_immediate')} · {t('sc_engine_hint_extensible')}
        </div>
      </div>
    {/if}
  </div>

  <!-- Section 5: Ranking rules (buckets) -->
  <div class="config-section">
    <div class="config-section-header" role="button" tabindex="0" onclick={() => toggleSection('rules')} onkeydown={(e) => { if (e.key === 'Enter' || e.key === ' ') { e.preventDefault(); toggleSection('rules') } }}>
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
                  <span class="tag" class:domestic={typeBadge(tp) === 'domestic'} class:pzs={typeBadge(tp) === 'pzs'} class:international={typeBadge(tp) === 'international'}>{tp}</span>
                {/each}
              </div>
              <div class="bucket-rule">
                <select disabled={readonly} value={bucket.always ? 'all' : 'best'} onchange={(e) => toggleBucketMode('domestic', i, (e.target as HTMLSelectElement).value)}>
                  <option value="best">{t('sc_rule_best')}</option>
                  <option value="all">{t('sc_rule_all')}</option>
                </select>
                {#if !bucket.always}
                  <input type="number" min="1" step="1" disabled={readonly} value={bucket.best ?? 1} onchange={(e) => updateBucketBest('domestic', i, parseInt((e.target as HTMLInputElement).value))} />
                  <span class="rule-label">{t('sc_rule_results')}</span>
                {:else}
                  <span class="always-label">{t('sc_rule_always')}</span>
                {/if}
              </div>
              <button class="remove-bucket-btn" disabled={readonly} title="Remove" onclick={() => removeBucket('domestic', i)}>&#10005;</button>
              {#each problemsOf('domestic', i) as problem}
                <div class="bucket-warning" data-field="bucket-warning">{problemText('domestic', problem)}</div>
              {/each}
            </div>
          {/each}
          {#if addingBucket?.pool === 'domestic'}
            <div class="new-bucket-picker">
              <div class="picker-types">
                {#each POOL_TYPES[addingBucket.pool] as tp}
                  <button
                    class="picker-type-btn"
                    class:selected={addingBucket.types.has(tp)}
                    class:domestic={typeBadge(tp) === 'domestic'}
                    class:pzs={typeBadge(tp) === 'pzs'}
                    class:international={typeBadge(tp) === 'international'}
                    disabled={usedTypes.has(tp)}
                    title={usedTypes.has(tp) ? t('sc_rules_type_used') : undefined}
                    onclick={() => toggleNewBucketType(tp)}
                  >{tp}</button>
                {/each}
              </div>
              <button class="picker-confirm" disabled={addingBucket.types.size === 0} onclick={confirmAddBucket}>&#10003;</button>
              <button class="picker-cancel" onclick={cancelAddBucket}>&#10005;</button>
            </div>
          {:else}
            <button class="add-bucket-btn" disabled={readonly} onclick={() => startAddBucket('domestic')}>{t('sc_add_bucket')}</button>
          {/if}
        </div>

        <hr class="bucket-divider" />

        <div class="rules-international">
          <div class="pool-label">&#127758; {t('sc_pool_international')}</div>
          {#each draftRules.international as bucket, i}
            <div class="bucket-row">
              <div class="bucket-types">
                {#each bucket.types as tp}
                  <span class="tag" class:domestic={typeBadge(tp) === 'domestic'} class:pzs={typeBadge(tp) === 'pzs'} class:international={typeBadge(tp) === 'international'}>{tp}</span>
                {/each}
              </div>
              <div class="bucket-rule">
                <select disabled={readonly} value={bucket.always ? 'all' : 'best'} onchange={(e) => toggleBucketMode('international', i, (e.target as HTMLSelectElement).value)}>
                  <option value="best">{t('sc_rule_best')}</option>
                  <option value="all">{t('sc_rule_all')}</option>
                </select>
                {#if !bucket.always}
                  <input type="number" min="1" step="1" disabled={readonly} value={bucket.best ?? 1} onchange={(e) => updateBucketBest('international', i, parseInt((e.target as HTMLInputElement).value))} />
                  <span class="rule-label">{t('sc_rule_results')}</span>
                {:else}
                  <span class="always-label">{t('sc_rule_always')}</span>
                {/if}
              </div>
              <button class="remove-bucket-btn" disabled={readonly} title="Remove" onclick={() => removeBucket('international', i)}>&#10005;</button>
              {#each problemsOf('international', i) as problem}
                <div class="bucket-warning" data-field="bucket-warning">{problemText('international', problem)}</div>
              {/each}
            </div>
          {/each}
          {#if addingBucket?.pool === 'international'}
            <div class="new-bucket-picker">
              <div class="picker-types">
                {#each POOL_TYPES[addingBucket.pool] as tp}
                  <button
                    class="picker-type-btn"
                    class:selected={addingBucket.types.has(tp)}
                    class:domestic={typeBadge(tp) === 'domestic'}
                    class:pzs={typeBadge(tp) === 'pzs'}
                    class:international={typeBadge(tp) === 'international'}
                    disabled={usedTypes.has(tp)}
                    title={usedTypes.has(tp) ? t('sc_rules_type_used') : undefined}
                    onclick={() => toggleNewBucketType(tp)}
                  >{tp}</button>
                {/each}
              </div>
              <button class="picker-confirm" disabled={addingBucket.types.size === 0} onclick={confirmAddBucket}>&#10003;</button>
              <button class="picker-cancel" onclick={cancelAddBucket}>&#10005;</button>
            </div>
          {:else}
            <button class="add-bucket-btn" disabled={readonly} onclick={() => startAddBucket('international')}>{t('sc_add_bucket')}</button>
          {/if}
        </div>
      </div>
    {/if}
  </div>

  <!-- Footer actions -->
  <div class="config-footer">
    <button class="config-export-btn" onclick={handleExport}>{t('sc_export')}</button>
    <button class="config-cancel-btn" onclick={oncancel}>{readonly ? t('sc_close') : t('sc_cancel')}</button>
    <button class="config-save-btn" onclick={handleSave}>{t('sc_save')}</button>
  </div>

  {#if rulesSaveBlocked && rulesProblems.length > 0}
    <div class="config-rules-error" data-field="rules-error" role="alert">{t('sc_rules_invalid_save')}</div>
  {/if}

  {#if readonly && showLockedNotice}
    <div class="config-locked-notice" data-field="locked-notice" role="alert">
      <strong>{t('sc_locked_title')}</strong>
      <p>{t('sc_locked_explanation')}</p>
    </div>
  {/if}
</div>

<script lang="ts">
  import type { ScoringConfig, ScoringEngineOption, RankingRules, TournamentType } from '../lib/types'
  import { CARRYOVER_ENGINE_VALUES } from '../lib/types'
  import { CLASSIC_ENGINE, PLACE_MEDAL, PLACE_MEDAL_ENGINE } from '../lib/scoring'
  import { POOL_TYPES, rankingRulesProblems, sameRankingRules, type BucketProblem, type Pool } from '../lib/ranking-rules'
  import { getLocale, t } from '../lib/locale.svelte'

  let {
    config,
    seasonCode,
    readonly = false,
    scoringEngines = [],
    onsave = (_c: ScoringConfig) => {},
    oncancel = () => {},
    onchange = (_c: ScoringConfig) => {},
  }: {
    config: ScoringConfig
    seasonCode: string
    readonly?: boolean
    // SS26.LOCK.01/§05: released scoring-engine codes for the new selector
    // below, fetched once by the caller (App.svelte) — never hardcoded here,
    // so a third released engine needs no frontend redeploy.
    scoringEngines?: ScoringEngineOption[]
    onsave?: (config: ScoringConfig) => void
    oncancel?: () => void
    // Part 4 (ADR-044): fires on every draft edit so a parent wizard can capture
    // the live config without waiting for the internal Save button.
    onchange?: (config: ScoringConfig) => void
  } = $props()

  // Default engine for new seasons (no incoming config.carryover_engine) is
  // the FK engine — see ADR-045. Existing configs preserve whatever the
  // season currently has on tbl_season.enum_carryover_engine.
  // Intentional one-time snapshot, not a live derivation: `draft` is an
  // editable working copy seeded from the incoming `config` prop. It must
  // NOT track `config` reactively — that would clobber in-progress edits
  // every time the parent re-renders.
  // svelte-ignore state_referenced_locally
  let draft: ScoringConfig = $state({
    ...JSON.parse(JSON.stringify(config)),
    carryover_engine: config.carryover_engine ?? 'EVENT_FK_MATCHING',
    engine_code: config.engine_code ?? scoringEngines[0]?.code ?? '',
  })

  // SS26.LOCK.11: clicking Save while locked shows this instead of calling
  // onsave — a native `disabled` attribute on the button would work for the
  // input fields above but cannot "communicate on click" (§05), so the
  // button stays enabled and the guard lives in handleSave instead.
  let showLockedNotice = $state(false)

  // ADR-103 §2: the engine each type card shows. Seeded from the exported
  // type_engines, which are RESOLVED, so a type absent from it (a config that
  // predates per-type engines, or a wizard's static default) shows — and
  // follows — the season default until its own selector is changed.
  // Same one-time-snapshot rationale as `draft` above.
  // svelte-ignore state_referenced_locally
  let typeEngines: Partial<Record<TournamentType, string>> = $state({ ...(config.type_engines ?? {}) })

  type MultiplierField =
    | 'ppw_multiplier' | 'mpw_multiplier' | 'pps_multiplier' | 'mps_multiplier'
    | 'pew_multiplier' | 'mew_multiplier' | 'msw_multiplier' | 'psw_multiplier'

  interface TypeCard {
    type: TournamentType
    badge: 'domestic' | 'pzs' | 'international'
    field: MultiplierField
    labelKey: string
    // A type whose bracket is never split names no joined-bracket module,
    // whatever its engine: PZSz is one senior bracket (K = N, m = place), and
    // an international result arrives already per category from its publisher.
    fixedModuleKey?: string
  }

  // Card order of the approved mockup (se27_scoring_config_per_type.html):
  // the two SPWS types, the two PZSz types, then the international circuit.
  const TYPE_CARDS: TypeCard[] = [
    { type: 'PPW', badge: 'domestic', field: 'ppw_multiplier', labelKey: 'sc_ppw_label' },
    { type: 'MPW', badge: 'domestic', field: 'mpw_multiplier', labelKey: 'sc_mpw_label' },
    { type: 'PPS', badge: 'pzs', field: 'pps_multiplier', labelKey: 'sc_pps_label', fixedModuleKey: 'sc_module_none_pzs' },
    { type: 'MPS', badge: 'pzs', field: 'mps_multiplier', labelKey: 'sc_mps_label', fixedModuleKey: 'sc_module_none_pzs' },
    { type: 'PEW', badge: 'international', field: 'pew_multiplier', labelKey: 'sc_pew_label', fixedModuleKey: 'sc_module_none_evf' },
    { type: 'MEW', badge: 'international', field: 'mew_multiplier', labelKey: 'sc_mew_label', fixedModuleKey: 'sc_module_none_evf' },
    { type: 'MSW', badge: 'international', field: 'msw_multiplier', labelKey: 'sc_msw_label', fixedModuleKey: 'sc_module_none_fie' },
    { type: 'PSW', badge: 'international', field: 'psw_multiplier', labelKey: 'sc_psw_label', fixedModuleKey: 'sc_module_none_org' },
  ]

  function engineOf(type: TournamentType): string {
    return typeEngines[type] ?? draft.engine_code ?? ''
  }

  function setTypeEngine(type: TournamentType, code: string) {
    typeEngines = { ...typeEngines, [type]: code }
  }

  /** A locale string, or '' when the locale has no entry for that key. */
  function tOptional(key: string, vars?: Record<string, string | number>): string {
    const text = t(key, vars)
    return text === key ? '' : text
  }

  // The per-type selector uses the short name of the mockup; an engine released
  // after this build has none, and falls back to its own tbl_scoring_engine label.
  function shortEngineLabel(eng: ScoringEngineOption): string {
    return tOptional(`sc_engine_short_${eng.code}`) || eng.label
  }

  // ADR-103 §4: an engine is paired with exactly one joined-bracket module,
  // named on its tbl_scoring_engine row.
  function moduleOf(card: TypeCard): { code: string, text: string } {
    if (card.fixedModuleKey) return { code: '—', text: t(card.fixedModuleKey) }
    const module = scoringEngines.find((eng) => eng.code === engineOf(card.type))?.module
    if (!module) return { code: '—', text: '' }
    return { code: module, text: tOptional(`sc_module_${module}`) }
  }

  function joinAnd(items: string[]): string {
    if (items.length < 2) return items.join('')
    return items.slice(0, -1).join(', ') + t('sc_and') + items[items.length - 1]
  }

  // Which results the EVF base value and podium fields actually feed: every
  // type on EVF classic, and the 32-and-over range of every type on the
  // 2026/2027 engine. Derived from the cards, so a season up to 2025/2026 —
  // every type on EVF classic — does not claim a range it never had.
  function evfHint(): string {
    const whole = TYPE_CARDS.filter((c) => engineOf(c.type) === CLASSIC_ENGINE).map((c) => c.type)
    const from32 = TYPE_CARDS.filter((c) => engineOf(c.type) === PLACE_MEDAL_ENGINE).map((c) => c.type)
    const parts: string[] = []
    if (whole.length) parts.push(whole.join(', '))
    if (from32.length) parts.push(t('sc_mp_hint_from32', { from: PLACE_MEDAL.evfFrom, types: joinAnd(from32) }))
    return t('sc_mp_hint', { types: parts.join(t('sc_also')) })
  }

  function decimal(value: number): string {
    return getLocale() === 'pl' ? String(value).replace('.', ',') : String(value)
  }

  // The fixed rules of each known engine, shown read-only beside the settings
  // that feed them. Nothing here is a setting: EVF classic's scale, its 10
  // points per elimination round and its podium scaling are fixed in SQL, and
  // the 2026/2027 engine's ranges and constants come from scoring.ts's
  // PLACE_MEDAL — the same constants the pages and the SQL strategy use.
  // Functions, so the text follows a language switch.
  const ENGINE_RULES: Record<string, (eng: ScoringEngineOption) => { label: string, text: string }[]> = {
    [CLASSIC_ENGINE]: (eng) => [
      { label: t('sc_ro_classic_place_label'), text: t('sc_ro_classic_place') },
      { label: t('sc_ro_classic_de_label'), text: t('sc_ro_classic_de') },
      { label: t('sc_ro_classic_podium_label'), text: t('sc_ro_classic_podium') },
      { label: t('sc_ro_module'), text: withModule(eng, t('sc_ro_classic_module')) },
    ],
    [PLACE_MEDAL_ENGINE]: (eng) => [
      { label: t('sc_ro_range', { from: 1, to: PLACE_MEDAL.tableUpTo }), text: t('sc_ro_pm_table') },
      {
        label: t('sc_ro_range', { from: PLACE_MEDAL.tableUpTo + 1, to: PLACE_MEDAL.evfFrom - 1 }),
        text: t('sc_ro_pm_mid', { per: decimal(PLACE_MEDAL.perBelow), medal: PLACE_MEDAL.medal.join(' / ') }),
      },
      { label: t('sc_ro_range_from', { from: PLACE_MEDAL.evfFrom }), text: t('sc_ro_pm_evf') },
      { label: t('sc_ro_module'), text: withModule(eng, t('sc_ro_pm_module')) },
    ],
  }

  function withModule(eng: ScoringEngineOption, text: string): string {
    return eng.module ? `${eng.module} — ${text}` : text
  }

  /**
   * The config this form stands for — what Save, the wizard's live capture and
   * the JSON export all send. `type_engines` carries the engine each card
   * SHOWS: fn_apply_scoring_config_write writes a type only when that differs
   * from its resolved engine after `engine_code` is applied, so an unchanged
   * form pins nothing and a new season default never silently moves a type
   * the admin can see on screen. With no per-type entry at all it is omitted,
   * and every type keeps following the season default.
   */
  function currentConfig(): ScoringConfig {
    const types = Object.keys(typeEngines).length ? { ...typeEngines } : undefined
    return {
      ...draft,
      ranking_rules: draftRules,
      carryover_engine: draft.carryover_engine,
      engine_code: draft.engine_code,
      type_engines: types,
    }
  }

  function engineLabel(engine: string): string {
    if (engine === 'EVENT_FK_MATCHING') return t('sc_engine_opt_fk')
    if (engine === 'EVENT_CODE_MATCHING') return t('sc_engine_opt_code')
    return engine
  }

  // Same one-time-snapshot rationale as `draft` above.
  // svelte-ignore state_referenced_locally
  let draftRules: RankingRules = $state(
    config.ranking_rules
      ? JSON.parse(JSON.stringify(config.ranking_rules))
      : { domestic: [], international: [] },
  )

  // Part 4 (ADR-044): emit the live config on every edit so a parent wizard can
  // advance with the current values via its own Next button (the internal Save
  // button still works for the standalone edit-config flow). Reads draft +
  // draftRules so the effect re-runs on any change; onchange defaults to a no-op.
  $effect(() => {
    onchange(currentConfig())
  })

  let collapsedSections: Record<string, boolean> = $state({
    base: false,
    podium: false,
    mult: false,
    intake: false,
    engine: false,
    rules: false,
  })

  function toggleSection(key: string) {
    collapsedSections[key] = !collapsedSections[key]
  }

  // A bucket tag and picker button take the colour of the type's card badge.
  function typeBadge(tp: string): TypeCard['badge'] {
    return TYPE_CARDS.find((card) => card.type === tp)?.badge ?? 'international'
  }

  // ADM27: a type may sit in one bucket only, and every fault the server
  // refuses (fn_validate_ranking_rules_write) is flagged at its bucket.
  let usedTypes = $derived(new Set([...draftRules.domestic, ...draftRules.international].flatMap((b) => b.types)))
  let rulesProblems = $derived(rankingRulesProblems(draftRules))
  let rulesSaveBlocked = $state(false)

  function problemsOf(pool: Pool, index: number): BucketProblem[] {
    return rulesProblems.filter((p) => p.pool === pool && p.index === index).map((p) => p.problem)
  }

  function problemText(pool: Pool, problem: BucketProblem): string {
    switch (problem.kind) {
      case 'wrong_pool': return t(`sc_rules_warn_pool_${pool}`, { type: problem.type })
      case 'duplicate': return t('sc_rules_warn_duplicate', { type: problem.type })
      case 'unknown_type': return t('sc_rules_warn_unknown_type', { type: problem.type })
      case 'no_types': return t('sc_rules_warn_no_types')
      case 'best_or_always': return t('sc_rules_warn_best_or_always')
      case 'best_below_one': return t('sc_rules_warn_best_below_one')
    }
  }

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
    if (readonly) {
      showLockedNotice = true
      return
    }
    // ADM27: changed rules must be rules the ranking can use, as the server
    // requires. Unchanged rules save as they are, so a season whose older
    // rules repeat the domestic buckets internationally stays savable.
    if (rulesProblems.length > 0 && !sameRankingRules(draftRules, config.ranking_rules)) {
      rulesSaveBlocked = true
      return
    }
    rulesSaveBlocked = false
    // Includes `carryover_engine` so App.svelte's handler can patch
    // tbl_season.enum_carryover_engine separately from tbl_scoring_config
    // (instant flip, no migration).
    onsave(currentConfig())
  }

  function handleExport() {
    const json = JSON.stringify(currentConfig(), null, 2)
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
  .config-section.engine-section {
    border: 2px solid #fbbf24;
    background: #fff8e1;
  }
  .config-section.engine-section .config-section-header {
    background: #fff8e1;
    color: #8a6d1b;
  }
  .config-section.engine-section .config-section-header:hover {
    background: #fff0c8;
  }
  .config-section.engine-section select {
    min-width: 320px;
    padding: 6px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 13px;
    background: #fff;
    color: #333;
    font-family: inherit;
  }
  .config-section.engine-section select.legacy {
    border-color: #c97a00;
    color: #8a4a00;
  }
  .engine-legacy-tag {
    display: inline-block;
    background: #fff3cd;
    color: #856404;
    padding: 2px 8px;
    border-radius: 8px;
    font-size: 11px;
    font-weight: 700;
    margin-left: 6px;
  }
  .engine-hint {
    background: #e1f0ff;
    border: 1px solid #b3d4f0;
    border-radius: 6px;
    padding: 8px 12px;
    font-size: 12px;
    color: #1a6fbf;
    line-height: 1.5;
    margin-top: 8px;
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
  /* PZSz senior events (PPS/MPS). Same desaturated PZSz red as the calendar
     drum's own .p.pzs panel (CalendarBarrel.svelte) — the brand red #c72626
     toned down to sit beside domestic green / international gold rather than
     shout over them. */
  .type-badge.pzs {
    background: #fdf0f0;
    color: #a92020;
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
  /* ADR-103 §2: each card's engine and the joined-bracket module it implies
     (mockup se27_scoring_config_per_type.html, revision 2). */
  .mult-card select {
    display: block;
    width: 100%;
    margin-top: 6px;
    padding: 4px 6px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 12px;
    background: #fff;
  }
  .module {
    margin-top: 6px;
    font-size: 11px;
    color: #374151;
    background: #f3f4f6;
    border-radius: 4px;
    padding: 3px 6px;
    text-align: left;
  }
  .module b {
    display: block;
    font-family: ui-monospace, Menlo, monospace;
    font-size: 10px;
    font-weight: 600;
    color: #6b7280;
  }
  /* The engines' fixed rules: read-only by construction (no inputs inside). */
  .ro-panel {
    border: 2px solid #c7d2fe;
    background: #eef2ff;
    border-radius: 6px;
    padding: 10px 14px;
    margin-top: 10px;
  }
  .ro-panel h4 {
    margin: 0 0 6px;
    font-size: 13px;
    font-family: ui-monospace, Menlo, monospace;
    overflow-wrap: anywhere;
  }
  .ro-panel table {
    border-collapse: collapse;
    width: 100%;
    font-size: 12.5px;
  }
  .ro-panel td {
    padding: 4px 6px;
    border-bottom: 1px solid #dbe1fb;
    vertical-align: top;
  }
  .ro-panel td:first-child {
    white-space: nowrap;
    color: #4b5563;
  }
  .ro-tag {
    display: inline-block;
    background: #e0e7ff;
    color: #3730a3;
    font-family: inherit;
    font-size: 10px;
    font-weight: 700;
    border-radius: 8px;
    padding: 1px 7px;
    margin-left: 6px;
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
    flex-wrap: wrap;
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
  .tag.pzs {
    background: #fdf0f0;
    color: #a92020;
  }
  .bucket-warning {
    flex-basis: 100%;
    font-size: 12px;
    color: #a92020;
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
  .picker-type-btn.selected.pzs {
    background: #fdf0f0;
    color: #a92020;
    border-color: #a92020;
  }
  .picker-type-btn:disabled {
    cursor: not-allowed;
    opacity: 0.4;
    text-decoration: line-through;
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
  .config-rules-error {
    margin-top: 12px;
    padding: 10px 14px;
    background: #fdf0f0;
    border: 1px solid #f0b4b4;
    border-radius: 6px;
    color: #a92020;
  }
  .config-locked-notice {
    margin-top: 12px;
    padding: 12px 16px;
    background: #fff3cd;
    border: 1px solid #ffe08a;
    border-radius: 6px;
    color: #664d03;
  }
  .config-locked-notice p {
    margin: 4px 0 0;
  }
  /* Read-only mode: disable all inputs visually */
  .config-readonly :global(input),
  .config-readonly :global(select),
  .config-readonly :global(.add-bucket-btn),
  .config-readonly :global(.remove-bucket-btn),
  .config-readonly :global(.picker-type-btn) {
    pointer-events: none;
    opacity: 0.6;
  }
</style>
