<div class="chart" role="img" aria-label={label}>
  {#each items as item}
    <div class="chart-row">
      <span class="chart-label" title={item.label}>{item.label}</span>
      <div class="chart-bar-bg">
        <div
          class="chart-bar"
          style="width: {maxScore > 0 ? (item.value / maxScore) * 100 : 0}%"
          class:domestic={item.type === 'PPW' || item.type === 'MPW'}
          class:international={item.type === 'PEW' || item.type === 'MEW'}
        ></div>
      </div>
      <span class="chart-value">{item.value.toFixed(1)}</span>
    </div>
  {/each}
</div>

<script lang="ts">
  interface ChartItem {
    label: string
    value: number
    type: string
  }

  let { items = [], label = 'Score chart' }: { items?: ChartItem[]; label?: string } = $props()

  let maxScore = $derived(Math.max(...items.map((i) => i.value), 1))
</script>

<style>
  .chart {
    display: flex;
    flex-direction: column;
    gap: 4px;
  }
  .chart-row {
    display: flex;
    align-items: center;
    gap: 8px;
    font-size: 12px;
  }
  .chart-label {
    width: 80px;
    text-align: right;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
    color: #555;
  }
  .chart-bar-bg {
    flex: 1;
    height: 18px;
    background: #f0f0f0;
    border-radius: 3px;
    overflow: hidden;
  }
  .chart-bar {
    height: 100%;
    border-radius: 3px;
    transition: width 0.3s ease;
  }
  .chart-bar.domestic {
    background: #4a90d9;
  }
  .chart-bar.international {
    background: #e8a838;
  }
  .chart-value {
    width: 50px;
    text-align: right;
    font-weight: 600;
    color: #333;
  }
</style>
