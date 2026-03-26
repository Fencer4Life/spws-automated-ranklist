<div class="floating-toolbar">
  <span class="admin-badge">ADMIN</span>
  <span class="admin-timer">{formatTime(remainingMs)}</span>
  <button class="admin-logout-btn" onclick={onlogout}>{t('admin_logout')}</button>
</div>

<script lang="ts">
  import { t } from '../lib/locale.svelte'
  import { onMount } from 'svelte'

  let {
    onlogout = () => {},
    ontimeout = () => {},
    timeoutMs = 120 * 60 * 1000,
  }: {
    onlogout?: () => void
    ontimeout?: () => void
    timeoutMs?: number
  } = $props()

  let remainingMs = $state(timeoutMs)
  let timerId: ReturnType<typeof setInterval> | null = null
  let timeoutId: ReturnType<typeof setTimeout> | null = null

  onMount(() => {
    const start = Date.now()
    timerId = setInterval(() => {
      const elapsed = Date.now() - start
      remainingMs = Math.max(0, timeoutMs - elapsed)
    }, 1000)
    timeoutId = setTimeout(() => {
      ontimeout()
    }, timeoutMs)
    return () => {
      if (timerId) clearInterval(timerId)
      if (timeoutId) clearTimeout(timeoutId)
    }
  })

  function formatTime(ms: number): string {
    const totalMin = Math.floor(ms / 60000)
    const h = Math.floor(totalMin / 60)
    const m = totalMin % 60
    if (h > 0) return `${h}h ${m}m`
    return `${m}m`
  }
</script>

<style>
  .floating-toolbar {
    position: fixed;
    bottom: 12px;
    left: 12px;
    background: #2c3e50;
    color: #fff;
    border-radius: 8px;
    padding: 10px 14px;
    box-shadow: 0 4px 12px rgba(0, 0, 0, 0.3);
    font-size: 12px;
    display: flex;
    align-items: center;
    gap: 12px;
    z-index: 150;
  }
  .admin-badge {
    background: #ff6b35;
    color: #fff;
    font-size: 10px;
    font-weight: 700;
    padding: 2px 6px;
    border-radius: 3px;
  }
  .admin-timer {
    color: #aaa;
  }
  .admin-logout-btn {
    color: #ff6b35;
    background: none;
    border: none;
    cursor: pointer;
    font-size: 12px;
    font-weight: 600;
  }
  .admin-logout-btn:hover {
    text-decoration: underline;
  }
</style>
