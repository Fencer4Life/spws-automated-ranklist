<div class="lang-toggle toggle">
  <button
    class="toggle-btn"
    class:active={getLocale() === 'en'}
    onclick={() => setLocale('en')}
  >🇬🇧</button>
  <button
    class="toggle-btn"
    class:active={getLocale() === 'pl'}
    onclick={() => setLocale('pl')}
  >🇵🇱</button>
</div>

<script lang="ts">
  import { getLocale, setLocale } from '../lib/locale.svelte'
</script>

<style>
  .lang-toggle {
    font-size: 13px;
  }
  .toggle {
    display: inline-flex;
    border: 1px solid #ccc;
    border-radius: 4px;
    overflow: hidden;
  }
  .toggle-btn {
    padding: 3px 8px;
    border: none;
    background: #fff;
    font-size: 16px;
    cursor: pointer;
    transition: all 0.15s;
    line-height: 1;
  }
  .toggle-btn:first-child {
    border-right: 1px solid #ccc;
  }
  .toggle-btn.active {
    background: #4a90d9;
    color: #fff;
  }
</style>
