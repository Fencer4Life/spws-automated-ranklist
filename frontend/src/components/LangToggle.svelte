<div class="lang-toggle" role="group" aria-label={t('language_label')}>
  {#each LANGUAGES as lang (lang.locale)}
    <button
      type="button"
      class="lang-btn"
      class:active={getLocale() === lang.locale}
      aria-pressed={getLocale() === lang.locale}
      aria-label={lang.name}
      title={lang.name}
      onclick={() => setLocale(lang.locale)}
    ><span class="lang-flag" aria-hidden="true"><CountryFlag code={lang.flag} /></span></button>
  {/each}
</div>

<script lang="ts">
  // The flags are the calendar's round CountryFlag images, not emoji: Windows
  // draws emoji flags as the letters "GB" and "PL" (UX proposal A,
  // doc/mockups/ranklist-controls-ux-2026-10-01.html). Each button is named in
  // its own language, as language pickers are.
  import { getLocale, setLocale, t } from '../lib/locale.svelte'
  import CountryFlag from './CountryFlag.svelte'

  const LANGUAGES = [
    { locale: 'en', flag: 'GB', name: 'English' },
    { locale: 'pl', flag: 'PL', name: 'Polski' },
  ] as const
</script>

<style>
  .lang-toggle {
    display: inline-flex;
    flex: none;
    padding: 2px;
    background: #f6f8fb;
    border: 1px solid #d5dbe3;
    border-radius: 999px;
  }
  .lang-btn {
    padding: 4px 7px;
    border: 0;
    border-radius: 999px;
    background: none;
    line-height: 0;
    cursor: pointer;
  }
  .lang-btn.active {
    background: #fff;
    box-shadow: 0 1px 2px rgba(16, 34, 64, 0.2);
  }
  .lang-btn:focus-visible {
    outline: 2px solid #12467e;
    outline-offset: 2px;
  }
  .lang-flag :global(.flag) {
    width: 20px;
    height: 20px;
    flex-basis: 20px;
    vertical-align: 0;
    transition: opacity 0.15s, filter 0.15s;
  }
  .lang-btn:not(.active) .lang-flag :global(.flag) {
    opacity: 0.42;
    filter: saturate(0.5);
  }
  .lang-btn:not(.active):hover .lang-flag :global(.flag) {
    opacity: 0.8;
    filter: none;
  }

  @media (max-width: 600px) {
    .lang-btn {
      padding: 6px 8px;
    }
    .lang-flag :global(.flag) {
      width: 22px;
      height: 22px;
      flex-basis: 22px;
    }
  }
</style>
