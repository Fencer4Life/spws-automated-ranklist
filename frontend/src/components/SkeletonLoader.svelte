<div class="skeleton-wrapper">
  {#each Array(rows) as _}
    <div class="skeleton-row"></div>
  {/each}
</div>

<script lang="ts">
  let { rows = 8 }: { rows?: number } = $props()
</script>

<style>
  .skeleton-wrapper {
    display: flex;
    flex-direction: column;
    gap: 8px;
    padding: 16px 0;
  }
  .skeleton-row {
    height: 32px;
    background: linear-gradient(90deg, #e0e0e0 25%, #f0f0f0 50%, #e0e0e0 75%);
    background-size: 200% 100%;
    border-radius: 4px;
    animation: shimmer 1.5s infinite;
  }
  @keyframes shimmer {
    0% { background-position: 200% 0; }
    100% { background-position: -200% 0; }
  }
</style>
