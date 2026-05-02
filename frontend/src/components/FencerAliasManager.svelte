<!--
  Phase 4 (ADR-050) Fencer alias management UI — Option A (Expandable table).
  Layout selected 2026-05-02 from doc/mockups/m11_fencer_aliases.html.

  Per-alias action set: Keep · Transfer · Create new fencer · Discard. Parent
  passes callbacks; this component does no DB I/O directly.
-->

{#if isAdmin}
  <div data-field="alias-manager" class="alias-manager">
    <div class="alias-header">
      <h3>Fencer aliases</h3>
      <div class="alias-counts">
        <span data-field="total-fencers" class="count-badge">
          {fencers.length} fencers
        </span>
        <span data-field="total-aliases" class="count-badge">
          {totalAliases} aliases
        </span>
      </div>
    </div>

    {#if errorMsg}
      <div data-field="alias-error" class="error-banner">{errorMsg}</div>
    {/if}

    <div class="filter-bar">
      <input
        data-field="alias-filter-input"
        type="text"
        bind:value={filterQuery}
        placeholder="Filter by surname / first name…"
      />
      <label>
        <input data-field="aliases-only" type="checkbox" bind:checked={aliasesOnly} />
        aliases only
      </label>
    </div>

    <table data-field="alias-table" class="alias-table">
      <thead>
        <tr>
          <th class="col-fencer">Fencer</th>
          <th class="col-meta">Birth · Country</th>
          <th class="col-count">Aliases</th>
        </tr>
      </thead>
      <tbody>
        {#each filteredFencers as f (f.id_fencer)}
          {@const expanded = expandedId === f.id_fencer}
          <tr
            data-field="fencer-row"
            class="fencer-row"
            class:expanded
            onclick={() => toggle(f.id_fencer)}
          >
            <td class="col-fencer">
              <span class="row-toggle">{expanded ? '▾' : '▸'}</span>
              <span class="fencer-name">{f.txt_surname} {f.txt_first_name}</span>
              <div class="fencer-meta">id_fencer #{f.id_fencer}</div>
            </td>
            <td class="col-meta">
              {fencerMeta(f)}
            </td>
            <td class="col-count">
              <span class="alias-count-badge" class:zero={f.alias_count === 0}>
                {f.alias_count}
              </span>
            </td>
          </tr>
          {#if expanded}
            <tr data-field="alias-detail-row" class="alias-detail-row">
              <td colspan="3">
                <div class="alias-detail">
                  {#each f.json_name_aliases as alias (alias)}
                    <div data-field="alias-row" class="alias-row">
                      <span class="alias-string">{alias}</span>
                      <button
                        data-field="btn-keep"
                        class="alias-btn keep"
                        onclick={() => onkeep(f.id_fencer, alias)}
                      >✓ Keep</button>
                      <button
                        data-field="btn-transfer"
                        class="alias-btn transfer"
                        onclick={() => ontransfer(f.id_fencer, alias)}
                      >↪ Transfer</button>
                      <button
                        data-field="btn-create"
                        class="alias-btn create"
                        onclick={() => oncreate(f.id_fencer, alias)}
                      >+ Create new fencer</button>
                      <button
                        data-field="btn-discard"
                        class="alias-btn discard"
                        onclick={() => ondiscard(f.id_fencer, alias)}
                      >✕ Discard</button>
                    </div>
                  {/each}
                </div>
              </td>
            </tr>
          {/if}
        {/each}
      </tbody>
    </table>
  </div>
{/if}

<script lang="ts">
  import type { FencerWithAliases } from '../lib/types'

  let {
    fencers = [] as FencerWithAliases[],
    isAdmin = false,
    errorMsg = null as string | null,
    onkeep = (_id: number, _alias: string) => {},
    ontransfer = (_id: number, _alias: string) => {},
    oncreate = (_id: number, _alias: string) => {},
    ondiscard = (_id: number, _alias: string) => {},
  }: {
    fencers?: FencerWithAliases[]
    isAdmin?: boolean
    errorMsg?: string | null
    onkeep?: (id: number, alias: string) => void
    ontransfer?: (id: number, alias: string) => void
    oncreate?: (id: number, alias: string) => void
    ondiscard?: (id: number, alias: string) => void
  } = $props()

  let filterQuery = $state('')
  let aliasesOnly = $state(true)
  let expandedId: number | null = $state(null)

  const totalAliases = $derived(
    fencers.reduce((acc, f) => acc + (f.alias_count ?? 0), 0)
  )

  const filteredFencers = $derived.by(() => {
    const q = filterQuery.trim().toLowerCase()
    return fencers
      .filter((f) => !aliasesOnly || (f.alias_count ?? 0) > 0)
      .filter((f) => {
        if (!q) return true
        const hay = `${f.txt_surname} ${f.txt_first_name}`.toLowerCase()
        return hay.includes(q)
      })
  })

  function toggle(id: number) {
    expandedId = expandedId === id ? null : id
  }

  function fencerMeta(f: FencerWithAliases): string {
    // The view doesn't expose birth_year / nationality directly; parent
    // can extend the row shape later. Placeholder for now.
    return f.ts_last_alias_added
      ? `last alias: ${f.ts_last_alias_added.slice(0, 10)}`
      : '—'
  }
</script>

<style>
  .alias-manager { padding: 14px; }
  .alias-header { display: flex; justify-content: space-between; align-items: center; margin-bottom: 8px; }
  .alias-header h3 { font-size: 16px; color: #222; }
  .alias-counts { display: flex; gap: 8px; }
  .count-badge { display: inline-block; padding: 1px 8px; border-radius: 11px; background: #ffeac4; color: #b07d2b; font-weight: 600; font-size: 12px; }
  .error-banner { background: #fee; color: #b04040; border: 1px solid #f5c0c0; border-radius: 4px; padding: 6px 10px; margin: 6px 0; }

  .filter-bar { display: flex; gap: 8px; align-items: center; margin: 8px 0; padding: 6px 0; border-bottom: 1px solid #eee; }
  .filter-bar input[type=text] { flex: 1; padding: 4px 8px; border: 1px solid #ccc; border-radius: 4px; font-size: 13px; }
  .filter-bar label { display: flex; gap: 4px; align-items: center; color: #555; font-size: 12px; }

  .alias-table { width: 100%; border-collapse: collapse; font-size: 13px; }
  .alias-table th { background: #f5f7fa; text-align: left; padding: 8px 14px; font-size: 11px; color: #666; text-transform: uppercase; letter-spacing: 0.5px; border-bottom: 1px solid #ddd; }
  .alias-table td { padding: 10px 14px; border-bottom: 1px solid #eee; vertical-align: top; }
  .col-count { text-align: right; width: 90px; }
  .col-meta { width: 200px; color: #888; font-size: 12px; }
  .fencer-row { cursor: pointer; }
  .fencer-row:hover { background: #fafbfc; }
  .fencer-row.expanded { background: #fbfcfd; border-bottom: 1px solid #ddd; }
  .row-toggle { display: inline-block; width: 14px; color: #4a90d9; font-weight: 700; padding-right: 6px; }
  .fencer-name { font-weight: 600; color: #222; }
  .fencer-meta { font-size: 11px; color: #888; }
  .alias-count-badge { display: inline-block; min-width: 22px; padding: 1px 8px; border-radius: 11px; background: #ffeac4; color: #b07d2b; font-weight: 600; text-align: center; }
  .alias-count-badge.zero { background: #f0f0f0; color: #aaa; }

  .alias-detail-row td { background: #fbfcfd; padding: 6px 14px 12px 36px; }
  .alias-detail { display: flex; flex-direction: column; gap: 6px; }
  .alias-row { display: flex; gap: 10px; align-items: center; padding: 5px 0; border-bottom: 1px dashed #eee; }
  .alias-row:last-child { border-bottom: none; }
  .alias-string { flex: 1; padding: 4px 8px; background: #fff7d8; border: 1px solid #f0d88a; border-radius: 4px; color: #6a4a0a; font-family: 'Menlo', monospace; font-size: 12px; }

  .alias-btn { padding: 4px 9px; border: 1px solid #ccc; border-radius: 4px; background: #fff; font-size: 11px; font-weight: 600; cursor: pointer; }
  .alias-btn.keep { color: #1a7f37; border-color: #b4dfbf; background: #f5fbf6; }
  .alias-btn.transfer { color: #2a6faa; }
  .alias-btn.create { color: #1a7f37; }
  .alias-btn.discard { color: #b04040; border-color: #e8c0c0; background: #fff8f8; }
  .alias-btn:hover { filter: brightness(0.95); }
</style>
