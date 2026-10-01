<button type="button" class="ods-btn" {title} aria-label={title} onclick={() => onclick?.()}>
  <svg viewBox="0 0 20 20" aria-hidden="true" focusable="false">
    <path d="M10 3v9m0 0-3.6-3.6M10 12l3.6-3.6M4 13.5V16h12v-2.5" />
  </svg>
  <span class="ods-label">ODS</span>
</button>

<script lang="ts">
  // The ODS spreadsheet download, shared by the ranklist's filter bar and the
  // score drilldown (UX proposal A). It sits right after the Ranking | PPW
  // switch because the file it downloads is the view on screen. The caller
  // supplies the tooltip, which is also the accessible name.
  let {
    title = '',
    onclick,
  }: {
    title?: string
    onclick?: () => void
  } = $props()
</script>

<style>
  .ods-btn {
    display: inline-flex;
    flex: none;
    align-items: center;
    gap: 6px;
    height: 38px;
    padding: 0 13px;
    border: 1px solid #c7ced8;
    border-radius: 10px;
    background: #fff;
    color: #24364b;
    font-family: inherit;
    font-size: 13px;
    font-weight: 700;
    letter-spacing: 0.04em;
    cursor: pointer;
  }
  .ods-btn:hover {
    background: #f1f4f8;
    border-color: #aeb8c6;
  }
  .ods-btn:focus-visible {
    outline: 2px solid #12467e;
    outline-offset: 2px;
  }
  svg {
    width: 17px;
    height: 17px;
    fill: none;
    stroke: currentColor;
    stroke-width: 1.9;
    stroke-linecap: round;
    stroke-linejoin: round;
  }

  @media (max-width: 600px) {
    .ods-btn {
      height: 44px;
      padding: 0 11px;
      gap: 4px;
      font-size: 12px;
    }
  }
</style>
