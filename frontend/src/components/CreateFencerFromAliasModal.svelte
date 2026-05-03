<!--
  Phase 5.5 (ADR-058+059) — modal form for "Create new fencer from alias".

  Replaces the four sequential window.prompt() calls in App.svelte's
  handleAliasCreate. Prepopulated from the alias's staging context:
    surname / first name parsed from the scraped alias string,
    BY suggested from (categoryHint, seasonEndYear) via estimateBirthYear.

  Mirrors CreateFencerModal.svelte 1:1 for layout + lifecycle. The two key
  additions are:
    1. BY suggestion from V-cat × season (renders an inline hint).
    2. Stricter validation (BY required, in [1900, 2030]).

  Plan-test-ID 5.2 (frontend/tests/CreateFencerFromAliasModal.test.ts).
-->

{#if open}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="create-fencer-from-alias-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>+ Create new fencer from alias</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div class="scraped-info">
        <span class="label">Alias:</span>
        <span class="scraped-name">{alias}</span>
        {#if categoryHint}
          <span class="ctx-pill" data-field="ctx-pill">{categoryHint}{seasonEndYear ? ` · ${seasonEndYear}` : ''}</span>
        {/if}
      </div>

      <div class="form-body">
        <label class="form-field">
          <span class="field-label">Surname</span>
          <input data-field="surname-input" type="text" bind:value={surname} class="field-input" />
        </label>

        <label class="form-field">
          <span class="field-label">First name</span>
          <input data-field="first-name-input" type="text" bind:value={firstName} class="field-input" />
        </label>

        <label class="form-field">
          <span class="field-label">Gender</span>
          <select data-field="gender-select" bind:value={gender} class="field-input">
            <option value="M">M</option>
            <option value="F">F</option>
          </select>
        </label>

        <label class="form-field">
          <span class="field-label">Birth year</span>
          <input
            data-field="birth-year-input"
            type="number"
            bind:value={birthYearInput}
            class="field-input"
            placeholder="e.g. 1974"
            min="1900"
            max="2030"
          />
          {#if estimate}
            <span data-field="by-hint" class="hint">
              Suggested {estimate.suggested} for {categoryHint} (range {estimate.range[0]}–{estimate.range[1]})
            </span>
          {/if}
        </label>
      </div>

      <div class="modal-footer">
        <button class="cancel-btn" onclick={() => { onclose() }}>Cancel</button>
        <button
          data-field="confirm-btn"
          class="confirm-btn"
          disabled={!isValid}
          onclick={() => { handleConfirm() }}
        >
          + Create
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import { estimateBirthYear } from '../lib/birthYearEstimate'

  type GenderType = 'M' | 'F'

  export interface NewFencerData {
    txt_surname: string
    txt_first_name: string
    int_birth_year: number
    enum_gender: GenderType
  }

  let {
    open = false,
    alias = '',
    fromFencerId = 0,
    categoryHint = null as string | null,
    seasonEndYear = null as number | null,
    onconfirm = (_data: NewFencerData) => {},
    onclose = () => {},
  }: {
    open?: boolean
    alias?: string
    fromFencerId?: number
    categoryHint?: string | null
    seasonEndYear?: number | null
    onconfirm?: (data: NewFencerData) => void
    onclose?: () => void
  } = $props()

  let surname = $state('')
  let firstName = $state('')
  let gender: GenderType = $state('M')
  let birthYearInput: number | undefined = $state(undefined)

  // Computed BY suggestion based on alias staging context.
  const estimate = $derived(estimateBirthYear(categoryHint, seasonEndYear))

  // Reset form whenever the modal opens with new context.
  $effect(() => {
    if (open) {
      const spaceIdx = alias.indexOf(' ')
      surname = spaceIdx > 0 ? alias.substring(0, spaceIdx) : alias
      firstName = spaceIdx > 0 ? alias.substring(spaceIdx + 1) : ''
      gender = 'M'
      birthYearInput = estimate ? estimate.suggested : undefined
    }
  })

  // Confirm button gating:
  //   - surname + firstName non-empty after trim
  //   - birthYearInput is finite, in [1900, 2030]
  const isValid = $derived(
    !!surname.trim() &&
    !!firstName.trim() &&
    Number.isFinite(birthYearInput) &&
    (birthYearInput as number) >= 1900 &&
    (birthYearInput as number) <= 2030,
  )

  function handleConfirm() {
    onconfirm({
      txt_surname: surname.trim(),
      txt_first_name: firstName.trim(),
      int_birth_year: birthYearInput as number,
      enum_gender: gender,
    })
  }
</script>

<style>
  .modal-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.5);
    display: flex;
    align-items: center;
    justify-content: center;
    z-index: 1000;
  }
  .modal-box {
    background: #fff;
    border-radius: 8px;
    width: 460px;
    max-width: 95vw;
    box-shadow: 0 4px 24px rgba(0, 0, 0, 0.15);
  }
  .modal-header {
    display: flex;
    align-items: center;
    justify-content: space-between;
    padding: 16px 20px;
    border-bottom: 1px solid #e0e0e0;
  }
  .modal-header h3 {
    margin: 0;
    font-size: 16px;
    color: #333;
  }
  .close-btn {
    border: none;
    background: none;
    font-size: 22px;
    cursor: pointer;
    color: #666;
    padding: 0 4px;
  }
  .scraped-info {
    padding: 14px 20px;
    background: #f8f9fa;
    display: flex;
    gap: 8px;
    align-items: center;
    flex-wrap: wrap;
  }
  .label {
    font-size: 13px;
    color: #666;
  }
  .scraped-name {
    font-weight: 600;
    font-size: 14px;
    color: #333;
    flex: 1;
  }
  .ctx-pill {
    font-size: 11px;
    background: #ffeac4;
    color: #b07d2b;
    padding: 2px 8px;
    border-radius: 11px;
    font-weight: 600;
  }
  .form-body {
    padding: 16px 20px;
    display: flex;
    flex-direction: column;
    gap: 12px;
  }
  .form-field {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .field-label {
    font-size: 13px;
    font-weight: 600;
    color: #555;
  }
  .field-input {
    padding: 8px 10px;
    border: 1px solid #ccc;
    border-radius: 4px;
    font-size: 14px;
  }
  .hint {
    font-size: 11px;
    color: #b07d2b;
    margin-top: 2px;
    font-style: italic;
  }
  .modal-footer {
    display: flex;
    justify-content: flex-end;
    gap: 10px;
    padding: 14px 20px;
    border-top: 1px solid #e0e0e0;
  }
  .cancel-btn {
    padding: 8px 18px;
    border: 1px solid #ccc;
    border-radius: 4px;
    background: #fff;
    color: #555;
    font-size: 14px;
    cursor: pointer;
  }
  .confirm-btn {
    padding: 8px 18px;
    border: none;
    border-radius: 4px;
    background: #1a7f37;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
    font-weight: 600;
  }
  .confirm-btn:disabled {
    background: #b8d4be;
    cursor: not-allowed;
  }
</style>
