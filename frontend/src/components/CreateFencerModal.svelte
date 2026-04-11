{#if open}
  <div class="modal-overlay" onclick={() => { onclose() }}>
    <div data-field="create-fencer-modal" class="modal-box" onclick={(e) => e.stopPropagation()}>
      <div class="modal-header">
        <h3>{t('identity_create_form_title')}</h3>
        <button class="close-btn" onclick={() => { onclose() }}>&times;</button>
      </div>

      <div class="scraped-info">
        <span class="label">{t('identity_scraped_name')}:</span>
        <span class="scraped-name">{scrapedName}</span>
      </div>

      <div class="form-body">
        <label class="form-field">
          <span class="field-label">{t('identity_surname')}</span>
          <input data-field="surname-input" type="text" bind:value={surname} class="field-input" />
        </label>

        <label class="form-field">
          <span class="field-label">{t('identity_first_name')}</span>
          <input data-field="first-name-input" type="text" bind:value={firstName} class="field-input" />
        </label>

        <label class="form-field">
          <span class="field-label">{t('identity_gender')}</span>
          <select data-field="gender-select" bind:value={gender} class="field-input">
            <option value="M">M</option>
            <option value="F">F</option>
          </select>
        </label>

        <label class="form-field">
          <span class="field-label">{t('identity_birth_year')}</span>
          <input data-field="birth-year-input" type="number" bind:value={birthYearInput} class="field-input" placeholder="e.g. 1970" />
        </label>
      </div>

      <div class="modal-footer">
        <button class="cancel-btn" onclick={() => { onclose() }}>
          {t('import_cancel')}
        </button>
        <button
          data-field="confirm-btn"
          class="confirm-btn"
          disabled={!surname.trim() || !firstName.trim()}
          onclick={() => { handleConfirm() }}
        >
          {t('identity_create_new')}
        </button>
      </div>
    </div>
  </div>
{/if}

<script lang="ts">
  import type { GenderType } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    open = false,
    scrapedName = '',
    tournamentGender = null as GenderType | null,
    onconfirm = (_surname: string, _firstName: string, _gender: GenderType, _birthYear?: number) => {},
    onclose = () => {},
  }: {
    open?: boolean
    scrapedName?: string
    tournamentGender?: GenderType | null
    onconfirm?: (surname: string, firstName: string, gender: GenderType, birthYear?: number) => void
    onclose?: () => void
  } = $props()

  let surname = $state('')
  let firstName = $state('')
  let gender: GenderType = $state('M')
  let birthYearInput: number | undefined = $state(undefined)

  $effect(() => {
    if (open) {
      const spaceIdx = scrapedName.indexOf(' ')
      surname = spaceIdx > 0 ? scrapedName.substring(0, spaceIdx) : scrapedName
      firstName = spaceIdx > 0 ? scrapedName.substring(spaceIdx + 1) : ''
      gender = tournamentGender ?? 'M'
      birthYearInput = undefined
    }
  })

  function handleConfirm() {
    onconfirm(surname.trim(), firstName.trim(), gender, birthYearInput || undefined)
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
    width: 440px;
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
  }
  .label {
    font-size: 13px;
    color: #666;
  }
  .scraped-name {
    font-weight: 600;
    font-size: 14px;
    color: #333;
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
    background: #4a90d9;
    color: #fff;
    font-size: 14px;
    cursor: pointer;
  }
  .confirm-btn:disabled {
    background: #b0c4de;
    cursor: not-allowed;
  }
</style>
