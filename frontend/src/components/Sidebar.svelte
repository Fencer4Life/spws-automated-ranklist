{#if open}
  <div class="sidebar-overlay" onclick={onclose} role="presentation"></div>
{/if}
<nav class="sidebar" class:open>
  <div class="sidebar-brand">
    <img src="SPWS-logo.png" alt="SPWS" class="sidebar-logo" />
  </div>
  <ul class="nav-list">
    <li>
      <button
        class="nav-item"
        class:active={currentView === 'ranklist'}
        onclick={() => { onnavigate('ranklist'); onclose() }}
      >
        {t('nav_ranklist')}
      </button>
    </li>
    <li>
      <button
        class="nav-item"
        class:active={currentView === 'calendar'}
        onclick={() => { onnavigate('calendar'); onclose() }}
      >
        {t('nav_calendar')}
      </button>
    </li>
  </ul>

  {#if isAdmin}
    <div class="admin-section">
      <div class="admin-section-title">{t('admin_section')}</div>
      <ul class="nav-list">
        <li><button class="nav-item admin-item" class:active={currentView === 'admin_seasons'} onclick={() => { onnavigate('admin_seasons'); onclose() }}>{t('nav_admin_seasons')}</button></li>
        <li><button class="nav-item admin-item" class:active={currentView === 'admin_events'} onclick={() => { onnavigate('admin_events'); onclose() }}>{t('nav_admin_events')}</button></li>
        <li><button class="nav-item admin-item" class:active={currentView === 'admin_identities'} onclick={() => { onnavigate('admin_identities'); onclose() }}>{t('nav_admin_identities')}</button></li>
        <li><button class="nav-item admin-item" class:active={currentView === 'admin_scoring'} onclick={() => { onnavigate('admin_scoring'); onclose() }}>{t('nav_admin_scoring')}</button></li>
      </ul>
    </div>
  {/if}
</nav>

<script lang="ts">
  import type { AppView } from '../lib/types'
  import { t } from '../lib/locale.svelte'

  let {
    open = false,
    currentView = 'ranklist' as AppView,
    isAdmin = false,
    onnavigate = (_view: AppView) => {},
    onclose = () => {},
  }: {
    open?: boolean
    currentView?: AppView
    isAdmin?: boolean
    onnavigate?: (view: AppView) => void
    onclose?: () => void
  } = $props()
</script>

<style>
  .sidebar-overlay {
    position: fixed;
    inset: 0;
    background: rgba(0, 0, 0, 0.4);
    z-index: 99;
  }
  .sidebar {
    position: fixed;
    top: 0;
    left: -260px;
    width: 260px;
    height: 100%;
    background: #fff;
    box-shadow: 2px 0 8px rgba(0, 0, 0, 0.15);
    z-index: 100;
    transition: left 0.25s ease;
    display: flex;
    flex-direction: column;
    padding: 0;
  }
  .sidebar.open {
    left: 0;
  }
  .sidebar-brand {
    padding: 20px 20px 12px;
  }
  .sidebar-logo {
    width: 120px;
    height: auto;
  }
  .nav-list {
    list-style: none;
    margin: 0;
    padding: 0;
  }
  .nav-item {
    display: block;
    width: 100%;
    padding: 12px 20px;
    border: none;
    background: none;
    text-align: left;
    font-size: 15px;
    color: #333;
    cursor: pointer;
    transition: background 0.15s;
  }
  .nav-item:hover {
    background: #f0f2f5;
  }
  .nav-item.active {
    color: #4a90d9;
    font-weight: 600;
    background: #eef3fb;
  }
  .admin-section {
    margin-top: auto;
    border-top: 1px solid #e0e0e0;
    padding-top: 8px;
  }
  .admin-section-title {
    font-size: 11px;
    font-weight: 600;
    text-transform: uppercase;
    color: #999;
    padding: 8px 20px 4px;
    letter-spacing: 0.5px;
  }
  .admin-item {
    color: #ff6b35;
  }
</style>
