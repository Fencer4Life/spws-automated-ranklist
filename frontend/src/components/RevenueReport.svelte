<!-- FR-176 — the event revenue forecast, as the organiser reads it.
     A light document (plan Q1 = A): the same palette, fonts, block order and
     words as the .ods it offers, so page, sheet and print are one design. The
     numbers come from one pure module (lib/revenueReport.ts) that the file
     reads too. Declared fees, never payments. -->
<div class="rr-page">
  <article class="rr-card">
    <div class="rr-bar">
      <LangToggle />
      {#if phase === 'ready'}
        <button type="button" class="rr-download" onclick={download} disabled={downloading}>{t('rev_download')}</button>
      {/if}
    </div>

    {#if phase === 'loading'}
      <p class="rr-message">{t('rev_loading')}</p>
    {:else if phase === 'notfound'}
      <p class="rr-message">{t('reg_event_not_found')}</p>
    {:else if phase === 'inactive'}
      <p class="rr-message" data-testid="rev-inactive">{t('rev_inactive')}</p>
    {:else if model && event}
      <header class="rr-head">
        <h1>{t('rev_title')}</h1>
        <h2>{event.txt_name}</h2>
        <p class="rr-sub">{[dates, event.txt_location ?? ''].filter(Boolean).join(' · ')}</p>
        <p class="rr-asof" data-testid="rev-as-of">{t('rev_as_of', { when: asOf })}</p>
      </header>

      <section class="rr-figures">
        <div class="rr-figure">
          <span class="rr-label">{t('rev_fig_entries')}</span>
          <span class="rr-value" data-testid="rev-fig-entries">{model.totals.entries}</span>
        </div>
        <div class="rr-figure">
          <span class="rr-label">{t('rev_fig_starts')}</span>
          <span class="rr-value" data-testid="rev-fig-starts">{model.totals.starts}</span>
        </div>
        <div class="rr-figure">
          <span class="rr-label">{t('rev_fig_revenue', { cur: model.currency })}</span>
          <span class="rr-value" data-testid="rev-fig-revenue">{money(tierRevenue)}</span>
        </div>
      </section>

      <section>
        <h3>{t('rev_by_tiers')}</h3>
        <div class="rr-scroll">
          <table class="rr-table rr-narrow" data-testid="rev-tiers">
            <thead>
              <tr>
                <th>{t('rev_th_entry')}</th>
                <th class="num">{t('rev_th_people')}</th>
                <th class="num">{t('rev_th_fee')}</th>
                <th class="num">{t('rev_total')}</th>
              </tr>
            </thead>
            <tbody>
              {#each model.tiers as tier (tier.weapons)}
                <tr>
                  <td>{t(`rev_tier_${tier.weapons}`)}</td>
                  <td class="num">{tier.entries}</td>
                  <td class="num">{tier.fee == null ? '' : money(tier.fee)}</td>
                  <td class="num">{money(tier.total)}</td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr>
                <td>{t('rev_total')}</td>
                <td class="num">{model.totals.entries}</td>
                <td></td>
                <td class="num">{money(tierRevenue)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <section>
        <h3>{t('rev_by_weapon')}</h3>
        <div class="rr-scroll">
          <table class="rr-table" data-testid="rev-weapons">
            <thead>
              <tr>
                <th>{t('rev_th_weapon')}</th>
                <th class="num">{t('rev_th_f_starts')}</th>
                <th class="num">{t('rev_th_f_revenue')}</th>
                <th class="num">{t('rev_th_m_starts')}</th>
                <th class="num">{t('rev_th_m_revenue')}</th>
                <th class="num">{t('rev_total')}</th>
              </tr>
            </thead>
            <tbody>
              {#each model.byWeapon as w (w.weapon)}
                <tr>
                  <td>{t(`rev_w_${w.weapon}`)}</td>
                  <td class="num">{w.F.starts}</td>
                  <td class="num">{money(w.F.revenue)}</td>
                  <td class="num">{w.M.starts}</td>
                  <td class="num">{money(w.M.revenue)}</td>
                  <td class="num">{money(w.total)}</td>
                </tr>
              {/each}
            </tbody>
            <tfoot>
              <tr>
                <td>{t('rev_total')}</td>
                <td class="num">{model.totals.F.starts}</td>
                <td class="num">{money(model.totals.F.revenue)}</td>
                <td class="num">{model.totals.M.starts}</td>
                <td class="num">{money(model.totals.M.revenue)}</td>
                <td class="num">{money(model.totals.F.revenue + model.totals.M.revenue)}</td>
              </tr>
            </tfoot>
          </table>
        </div>
      </section>

      <section class="rr-notes">
        <p>{t('rev_note_share')}</p>
        {#if !model.hasFees}
          <p>{t('rev_note_no_fee')}</p>
        {:else}
          {#if model.fallbackEntries.two > 0}
            <p>{t('rev_note_missing', { n: 2, count: model.fallbackEntries.two })}</p>
          {/if}
          {#if model.fallbackEntries.three > 0}
            <p>{t('rev_note_missing', { n: 3, count: model.fallbackEntries.three })}</p>
          {/if}
        {/if}
      </section>

      <section>
        <h3>{t('rev_entries_title')}</h3>
        {#if model.entries.length === 0}
          <p class="rr-empty">{t('rev_no_entries')}</p>
        {:else}
          <div class="rr-scroll">
            <table class="rr-table rr-entries" data-testid="rev-entries">
              <thead>
                <tr>
                  <th class="num">{t('rev_th_no')}</th>
                  <th>{t('rev_th_name')}</th>
                  <th class="mid">{t('rev_th_gender')}</th>
                  <th class="mid">{t('rev_th_cat')}</th>
                  {#each WEAPONS as w (w)}<th class="mid">{t(`rev_w_${w}`)}</th>{/each}
                  <th class="mid">{t('rev_th_weapons')}</th>
                  <th class="num">{t('rev_th_fee')}</th>
                </tr>
              </thead>
              <tbody>
                {#each model.entries as e, i (e.id)}
                  <tr>
                    <td class="num">{i + 1}</td>
                    <td class="name">{e.name}</td>
                    <td class="mid">{t(`rev_g_${e.gender}`)}</td>
                    <td class="mid">{e.category ?? ''}</td>
                    {#each WEAPONS as w (w)}<td class="mid">{e.weapons.includes(w) ? '✓' : ''}</td>{/each}
                    <td class="mid">{e.weapons.length}</td>
                    <td class="num">{e.fee == null ? money(0) : money(e.fee)}</td>
                  </tr>
                {/each}
              </tbody>
            </table>
          </div>
        {/if}
      </section>
      {#if downloadError}
        <p class="rr-error" role="alert">{downloadError}</p>
      {/if}
    {/if}
  </article>
</div>

<script lang="ts">
  import LangToggle from './LangToggle.svelte'
  import { fetchEventForRegistration, fetchRevenueReport } from '../lib/api'
  import { buildRevenueModel, formatMoney, WEAPONS, type RevenueModel } from '../lib/revenueReport'
  import { buildRevenueOds, odsFileName } from '../lib/revenueReportOds'
  import { getLocale, t } from '../lib/locale.svelte'
  import type { RegistrationEventInfo } from '../lib/types'

  let { eventCode, token }: { eventCode: string; token: string } = $props()

  let phase = $state<'loading' | 'notfound' | 'inactive' | 'ready'>('loading')
  let event = $state<RegistrationEventInfo | null>(null)
  let model = $state<RevenueModel | null>(null)
  let downloading = $state(false)
  let downloadError = $state('')

  const lang = $derived<'pl' | 'en'>(getLocale() === 'en' ? 'en' : 'pl')
  const locale = $derived(lang === 'en' ? 'en-GB' : 'pl-PL')
  const tierRevenue = $derived(model ? model.tiers.reduce((s, tier) => s + tier.total, 0) : 0)

  // Event dates are calendar dates: read and shown in UTC so no zone shifts them.
  const dates = $derived.by(() => {
    if (!event?.dt_start) return ''
    const f = new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'UTC' })
    const start = new Date(`${event.dt_start}T00:00:00Z`)
    const end = new Date(`${event.dt_end ?? event.dt_start}T00:00:00Z`)
    return end > start ? f.formatRange(start, end) : f.format(start)
  })

  // The minute of the report, as Warsaw sees it.
  const asOf = $derived.by(() => {
    if (!model) return ''
    const at = new Date(model.generatedAt)
    const day = new Intl.DateTimeFormat(locale, { day: 'numeric', month: 'long', year: 'numeric', timeZone: 'Europe/Warsaw' }).format(at)
    const time = new Intl.DateTimeFormat(locale, { hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Europe/Warsaw' }).format(at)
    return `${day}, ${time}`
  })

  function money(value: number): string {
    if (!model?.hasFees) return '—'
    return `${formatMoney(value, lang)} ${model.currency}`
  }

  $effect(() => {
    const code = eventCode
    const key = token
    let cancelled = false
    phase = 'loading'
    fetchEventForRegistration(code).then(async (ev) => {
      if (cancelled) return
      if (!ev) {
        phase = 'notfound'
        return
      }
      event = ev
      if (!key) {
        phase = 'inactive'
        return
      }
      const raw = await fetchRevenueReport(ev.id_event, key)
      if (cancelled) return
      if (!raw) {
        phase = 'inactive'
        return
      }
      model = buildRevenueModel(raw)
      phase = 'ready'
    })
    return () => {
      cancelled = true
    }
  })

  // The file is of the minute it is downloaded: the report is read again, the
  // page shows that reading, and the file is built from the same model.
  async function download() {
    if (!event) return
    downloading = true
    downloadError = ''
    try {
      const raw = await fetchRevenueReport(event.id_event, token)
      if (!raw) {
        phase = 'inactive'
        return
      }
      model = buildRevenueModel(raw)
      const bytes = buildRevenueOds(
        model,
        { eventName: event.txt_name, eventCode: event.txt_code, dates, place: event.txt_location ?? '', asOf },
        lang,
      )
      const blob = new Blob([bytes as BlobPart], { type: 'application/vnd.oasis.opendocument.spreadsheet' })
      const url = URL.createObjectURL(blob)
      const a = document.createElement('a')
      a.href = url
      a.download = odsFileName(event.txt_code, model.generatedAt, lang)
      document.body.appendChild(a)
      a.click()
      a.remove()
      URL.revokeObjectURL(url)
    } catch (e) {
      downloadError = e instanceof Error ? e.message : String(e)
    } finally {
      downloading = false
    }
  }
</script>

<style>
  .rr-page {
    --rr-accent: #12467e;
    --rr-soft: #dbe7f5;
    --rr-total: #dce2ec;
    --rr-stripe: #f3f6fa;
    --rr-hair: #c9d1dc;
    --rr-ink: #0f1319;
    --rr-secondary: #414b59;
    --rr-notes: #6b7482;
    background: #eef1f5;
    min-height: 100vh;
    padding: 24px 16px;
    box-sizing: border-box;
    color: var(--rr-ink);
    font-family: Arial, 'Liberation Sans', sans-serif;
    font-size: 14px;
    line-height: 1.4;
  }
  .rr-card {
    max-width: 900px;
    margin: 0 auto;
    background: #fff;
    border-radius: 6px;
    box-shadow: 0 1px 4px rgba(15, 19, 25, 0.12);
    padding: 24px 28px 32px;
    box-sizing: border-box;
    min-width: 0;
  }
  .rr-bar {
    display: flex;
    justify-content: flex-end;
    align-items: center;
    gap: 12px;
    flex-wrap: wrap;
  }
  .rr-download {
    background: var(--rr-accent);
    color: #fff;
    border: 0;
    border-radius: 4px;
    padding: 8px 14px;
    font: inherit;
    font-weight: 700;
    cursor: pointer;
  }
  .rr-download:disabled {
    opacity: 0.6;
    cursor: progress;
  }
  .rr-message {
    text-align: center;
    color: var(--rr-secondary);
    margin: 48px 0;
  }
  .rr-head h1 {
    font-family: Georgia, 'Liberation Serif', serif;
    color: var(--rr-accent);
    font-size: 30px;
    margin: 8px 0 4px;
  }
  .rr-head h2 {
    font-size: 19px;
    margin: 0 0 4px;
  }
  .rr-sub {
    color: var(--rr-secondary);
    margin: 0 0 4px;
  }
  .rr-asof {
    color: var(--rr-notes);
    font-style: italic;
    font-size: 13px;
    margin: 0;
    padding-bottom: 8px;
    border-bottom: 1px solid var(--rr-hair);
  }
  .rr-figures {
    display: grid;
    grid-template-columns: repeat(3, minmax(0, 1fr));
    background: var(--rr-soft);
    border: 1px solid var(--rr-hair);
    margin: 18px 0 10px;
  }
  .rr-figure {
    display: flex;
    flex-direction: column;
    align-items: center;
    padding: 10px 6px 12px;
    min-width: 0;
  }
  .rr-label {
    color: var(--rr-secondary);
    font-size: 11px;
    font-weight: 700;
    text-transform: uppercase;
    text-align: center;
  }
  .rr-value {
    font-size: 24px;
    font-weight: 700;
    margin-top: 4px;
    white-space: nowrap;
  }
  h3 {
    color: var(--rr-accent);
    font-size: 16px;
    margin: 22px 0 6px;
    padding-bottom: 3px;
    border-bottom: 2px solid var(--rr-accent);
  }
  .rr-scroll {
    overflow-x: auto;
    -webkit-overflow-scrolling: touch;
  }
  .rr-table {
    border-collapse: collapse;
    width: 100%;
    font-variant-numeric: tabular-nums;
  }
  .rr-narrow {
    width: auto;
    min-width: 60%;
  }
  .rr-table th {
    background: var(--rr-accent);
    color: #fff;
    font-weight: 700;
    text-align: left;
    padding: 6px 8px;
    vertical-align: bottom;
  }
  .rr-table td {
    padding: 5px 8px;
    border-bottom: 1px solid var(--rr-hair);
    white-space: nowrap;
  }
  .rr-table tfoot td {
    background: var(--rr-total);
    font-weight: 700;
    border-top: 2px solid var(--rr-accent);
    border-bottom: 0;
  }
  .rr-entries tbody tr:nth-child(even) td {
    background: var(--rr-stripe);
  }
  .rr-table .num {
    text-align: right;
  }
  .rr-table .mid {
    text-align: center;
  }
  .rr-notes p {
    color: var(--rr-notes);
    font-size: 12px;
    margin: 6px 0 0;
  }
  .rr-empty {
    color: var(--rr-secondary);
  }
  .rr-error {
    color: #a3261b;
    margin-top: 12px;
  }
  @media (max-width: 600px) {
    .rr-card {
      padding: 16px;
    }
    /* A phone's third of the card holds „3 100,00 PLN” only at a smaller size,
       and the currency may go to a second line (I40). */
    .rr-value {
      font-size: 17px;
      white-space: normal;
      text-align: center;
      overflow-wrap: anywhere;
    }
  }
  @media print {
    .rr-page {
      background: #fff;
      padding: 0;
      min-height: 0;
    }
    .rr-card {
      box-shadow: none;
      max-width: none;
      padding: 0;
    }
    .rr-bar {
      display: none;
    }
    @page {
      size: A4;
      margin: 15mm;
    }
  }
</style>
