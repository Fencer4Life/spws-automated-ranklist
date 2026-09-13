<div class="ftl">
  <header class="ftl-top">
    <h2>{t('ftl_title')}</h2>
    <div class="ftl-lang">
      <button
        type="button"
        class:on={getLocale() === 'pl'}
        data-field="ftl-lang-pl"
        aria-label={t('ftl_lang_pl')}
        title={t('ftl_lang_pl')}
        onclick={() => setLocale('pl')}>🇵🇱</button
      >
      <button
        type="button"
        class:on={getLocale() === 'en'}
        data-field="ftl-lang-en"
        aria-label={t('ftl_lang_en')}
        title={t('ftl_lang_en')}
        onclick={() => setLocale('en')}>🇬🇧</button
      >
    </div>
  </header>

  {#if events.length > 1}
    <p class="ftl-picklead">{t('ftl_pick')}</p>
    <div class="ftl-cards">
      {#each events as ev (ev.id_event)}
        <button
          type="button"
          class="ftl-card"
          class:on={ev.id_event === selectedId}
          data-field="ftl-event-card"
          onclick={() => onselect?.(ev.id_event)}
        >
          <span class="cd">{ev.txt_code}</span>
          <span class="cn">{ev.txt_name}</span>
          <span class="cm"
            >{ev.txt_location} · {formatDate(ev.dt_start)} · {t('ftl_pick_meta', {
              n: ev.int_registrations,
            })}</span
          >
        </button>
      {/each}
    </div>
  {/if}

  {#if selected}
    <p class="ftl-event" data-field="ftl-event-line">
      {selected.txt_name}
      <span class="loc">{(selected.txt_location ?? '').toUpperCase()}</span>
      <span class="code">{selected.txt_code}</span>
    </p>
  {/if}

  {#if notFound}
    <p class="ftl-empty">{t('ftl_event_not_found')}</p>
  {:else if loading}
    <p class="ftl-empty">{t('ftl_loading')}</p>
  {:else if events.length === 0}
    <!-- No events at all. This is also what a missing or revoked token looks
         like, because the refusal happens in Postgres and returns no rows — so
         the line has to be true in both cases and give nothing away in either.
         "Nobody has entered yet" would be an active falsehood for a stale link. -->
    <p class="ftl-empty" data-field="ftl-no-events">{t('ftl_no_events')}</p>
  {:else if files.length === 0}
    <p class="ftl-empty">{t('ftl_empty')}</p>
  {:else}
    <p class="ftl-intro">{t('ftl_intro')}</p>

    <div class="ftl-actions">
      <button
        type="button"
        class="ftl-all"
        data-field="ftl-download-all"
        disabled={busy}
        onclick={downloadAll}
      >
        {busy ? t('ftl_preparing') : t('ftl_download_all')}
      </button>
      <span class="ftl-meta">
        {t('ftl_file_count', { count: files.length })}
        {#if takenAt}· {t('ftl_archive_taken_at')}: {takenAt}{/if}
      </span>
    </div>

    {#each groups as group (group.weapon)}
      <div class="ftl-acc" class:open={open[group.weapon]} data-field="ftl-weapon-group">
        <button
          type="button"
          class="ftl-acc-head"
          data-field="ftl-weapon-head"
          aria-expanded={open[group.weapon] ? 'true' : 'false'}
          onclick={() => (open[group.weapon] = !open[group.weapon])}
        >
          <span class="chev" aria-hidden="true">▶</span>
          <span class="w">{t(`ftl_w_${group.weapon}`)}</span>
          <span class="sum">{group.summary}</span>
          <span class="nf">{t('ftl_file_count', { count: group.files.length })}</span>
        </button>
        {#if open[group.weapon]}
          <div class="ftl-acc-body">
            <div class="ftl-table-wrap">
              <table class="ftl-table">
                <thead>
                  <tr>
                    <th>{t('ftl_col_file')}</th>
                    <th>{t('ftl_col_contents')}</th>
                    <th class="ftl-num">{t('ftl_col_fencers')}</th>
                    <th>{t('ftl_col_purpose')}</th>
                    <th></th>
                  </tr>
                </thead>
                <tbody>
                  {#each group.files as file (file.filename)}
                    <tr>
                      <td class="ftl-file">
                        <code data-field="ftl-filename">{file.filename}</code>
                        <span class="ftl-intitle" data-field="ftl-title">{file.title}</span>
                      </td>
                      <td data-field="ftl-kind">{kindLabel(file.kind)}</td>
                      <td class="ftl-num" data-field="ftl-count">{file.count}</td>
                      <td
                        data-field="ftl-purpose"
                        class:warn={file.importAs === 'PICKLIST'}
                      >
                        {purposeLabel(file.importAs)}
                      </td>
                      <td>
                        <button
                          type="button"
                          class="ftl-one"
                          data-field="ftl-download-one"
                          disabled={busy}
                          onclick={() => downloadOne(file.filename)}
                        >
                          {t('ftl_download_one')}
                        </button>
                      </td>
                    </tr>
                  {/each}
                </tbody>
              </table>
            </div>
          </div>
        {/if}
      </div>
    {/each}

    <section class="ftl-howto">
      <h3>{t('ftl_howto_title')}</h3>
      <p class="ftl-lead">{t('ftl_howto_lead')}</p>
      <ol class="ftl-steps">
        {#each STEP_NUMBERS as n (n)}
          <li data-field="ftl-step">
            <h4>{t(`ftl_step${n}_h`)}</h4>
            <p>{t(`ftl_step${n}_b`)}</p>
            {#if n === 8}
              <p class="ftl-contact">{contact || t('ftl_contact_fallback')}</p>
            {/if}
          </li>
        {/each}
      </ol>
    </section>
  {/if}
</div>

<script lang="ts">
  // The organizer-facing half of the FTL export. It holds no data access of its
  // own: the custom element fetches and this renders, which keeps it testable
  // against a fixed entry list and keeps the generation logic in
  // lib/ftlSeedExport.ts where the Python twin can be compared to it line for
  // line.
  //
  // Design of record: doc/plans/ftl-export-page-2026-09-12.html.
  import { t, getLocale, setLocale } from '../lib/locale.svelte'
  import { downloadBytes, downloadText } from '../lib/download'
  import { buildZip } from '../lib/zip'
  import { buildArchiveEntries } from '../lib/exportArchive'
  import {
    buildEventSeedFiles,
    WEAPON_ORDER,
    type ExportEntryRow,
    type RosterRow,
    type SeedFile,
  } from '../lib/ftlSeedExport'
  import type { FtlExportEvent } from '../lib/types'

  const STEP_NUMBERS = [1, 2, 3, 4, 5, 6, 7, 8]

  let {
    events = [],
    selectedId = null,
    entries = [],
    rosters = {},
    loading = false,
    notFound = false,
    takenAt = '',
    contact = '',
    onselect,
    onrefresh,
  }: {
    events?: FtlExportEvent[]
    selectedId?: number | null
    entries?: ExportEntryRow[]
    rosters?: Record<string, RosterRow[]>
    loading?: boolean
    notFound?: boolean
    takenAt?: string
    contact?: string
    onselect?: (id: number) => void
    onrefresh?: () => Promise<{ entries: ExportEntryRow[]; rosters: Record<string, RosterRow[]> }>
  } = $props()

  let open = $state<Record<string, boolean>>({})
  let busy = $state(false)

  const selected = $derived(events.find((e) => e.id_event === selectedId) ?? null)
  const eventCode = $derived(selected?.txt_code ?? '')

  // Derived for RENDERING only. The download paths rebuild from a fresh read —
  // see downloadAll. DateFichierXML stays empty, matching the Python exporter
  // and the validated reference files: stamping the generation moment would make
  // two downloads of an unchanged entry list differ, and the organizer's first
  // question on the morning of the event is "is this the same file I already
  // imported?".
  const files = $derived<SeedFile[]>(
    entries.length > 0 && eventCode ? buildEventSeedFiles(entries, eventCode, '', rosters) : [],
  )

  // One collapsed section per weapon. Twenty-eight flat rows put the instruction
  // below the fold, and the instruction is the part nobody has read yet.
  const groups = $derived(
    WEAPON_ORDER.map((weapon) => {
      const own = files.filter((f) => f.weapon === weapon)
      const de = own.filter((f) => f.kind === 'DE').length
      const roster = own.find((f) => f.kind === 'ROSTER')
      return {
        weapon,
        files: own,
        summary: t('ftl_sum_line', { de, r: roster ? roster.count : 0 }),
      }
    }).filter((g) => g.files.length > 0),
  )

  function formatDate(iso: string | null): string {
    if (!iso) return ''
    const [y, m, d] = iso.split('-')
    return `${d}.${m}.${y}`
  }

  function kindLabel(kind: string): string {
    if (kind === 'MIXALL') return t('ftl_kind_mixall')
    if (kind === 'ROSTER') return t('ftl_kind_roster')
    return t('ftl_kind_de')
  }

  function purposeLabel(importAs: string): string {
    return importAs === 'PICKLIST' ? t('ftl_import_picklist') : t('ftl_import_competition')
  }

  /**
   * Re-read the entry list, then build. This is the difference between a file
   * that is current and a file that merely looks current: a page opened at 08:00
   * and used at 10:00 would otherwise hand over the 08:00 list with nothing on
   * screen to say so. One call, ~30 ms for a full event.
   */
  async function freshFiles(): Promise<SeedFile[]> {
    if (!onrefresh) return files
    const latest = await onrefresh()
    return buildEventSeedFiles(latest.entries, eventCode, '', latest.rosters)
  }

  async function withBusy(work: () => Promise<void>): Promise<void> {
    busy = true
    try {
      await work()
    } finally {
      busy = false
    }
  }

  function downloadOne(filename: string): void {
    void withBusy(async () => {
      const current = await freshFiles()
      const file = current.find((f) => f.filename === filename)
      if (file) downloadText(file.filename, file.xml)
    })
  }

  function downloadAll(): void {
    void withBusy(async () => {
      const current = await freshFiles()
      if (current.length === 0) return
      const zip = buildZip(
        buildArchiveEntries(current, {
          eventCode,
          eventName: selected?.txt_name ?? '',
          eventLocation: selected?.txt_location ?? '',
          takenAt,
        }),
      )
      downloadBytes(`${eventCode}_FTL.zip`, zip, 'application/zip')
    })
  }
</script>

<style>
  /* The public-embed palette shared with RegistrationForm and EntryList: a dark
     card on the page's dark shell. Matching them matters more than looking new —
     an organizer arriving from the entry list should see the same site. */
  .ftl {
    max-width: 900px;
    margin: 0 auto;
    background: #16213e;
    border: 1px solid #0f3460;
    border-radius: 12px;
    padding: 22px;
    color: #e0e0e0;
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  }

  .ftl-top {
    display: flex;
    justify-content: space-between;
    align-items: flex-start;
    gap: 14px;
    flex-wrap: wrap;
  }

  .ftl-top h2 {
    margin: 0;
    font-size: 1.25rem;
    font-weight: 600;
    color: #fff;
  }

  .ftl-lang {
    display: inline-flex;
    border: 1px solid #1a4a8a;
    border-radius: 6px;
    overflow: hidden;
    flex: none;
  }

  .ftl-lang button {
    padding: 5px 10px;
    border: 0;
    background: #0d1b2a;
    font-size: 17px;
    line-height: 1;
    cursor: pointer;
    color: #7fd8ff;
  }

  .ftl-lang button + button {
    border-left: 1px solid #1a4a8a;
  }

  .ftl-lang button.on {
    background: #1a4a8a;
  }

  .ftl-picklead {
    margin: 16px 0 8px;
    color: #7fbadc;
    font-size: 0.85rem;
  }

  .ftl-cards {
    display: flex;
    gap: 10px;
    flex-wrap: wrap;
    margin-bottom: 18px;
  }

  .ftl-card {
    flex: 1 1 230px;
    text-align: left;
    background: #0d1b2a;
    border: 1px solid #1a3a63;
    border-radius: 10px;
    padding: 11px 13px;
    cursor: pointer;
    font-family: inherit;
    color: #c3cede;
  }

  .ftl-card:hover {
    border-color: #1a4a8a;
  }

  .ftl-card.on {
    border-color: #00d4ff;
    background: #102a44;
    box-shadow: inset 0 0 0 1px #00d4ff;
  }

  .ftl-card .cd {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.76rem;
    color: #8894a8;
  }

  .ftl-card .cn {
    display: block;
    color: #fff;
    font-weight: 600;
    font-size: 0.92rem;
    margin: 3px 0 4px;
    line-height: 1.3;
  }

  .ftl-card .cm {
    font-size: 0.8rem;
    color: #7fbadc;
  }

  .ftl-event {
    margin: 2px 0 16px;
    color: #7fbadc;
    font-size: 1.02rem;
  }

  .ftl-event .loc {
    color: #fff;
    font-weight: 600;
    letter-spacing: 0.04em;
  }

  .ftl-event .code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.82em;
    color: #8894a8;
    margin-left: 8px;
  }

  .ftl-intro {
    margin: 0 0 16px;
    line-height: 1.55;
    color: #c3cede;
  }

  .ftl-empty {
    margin: 16px 0 0;
    color: #8894a8;
    line-height: 1.55;
  }

  .ftl-actions {
    display: flex;
    align-items: baseline;
    gap: 12px;
    margin-bottom: 16px;
    flex-wrap: wrap;
  }

  .ftl-all {
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #7fd8ff;
    border-radius: 8px;
    padding: 10px 18px;
    font-size: 0.95rem;
    font-weight: 600;
    cursor: pointer;
  }

  .ftl-all:hover:not(:disabled) {
    border-color: #00d4ff;
    color: #00d4ff;
  }

  .ftl-all:disabled,
  .ftl-one:disabled {
    opacity: 0.55;
    cursor: default;
  }

  .ftl-meta {
    color: #8894a8;
    font-size: 0.9rem;
  }

  /* Accordion */
  .ftl-acc {
    border: 1px solid #1a3a63;
    border-radius: 10px;
    overflow: hidden;
    margin-bottom: 10px;
  }

  .ftl-acc-head {
    width: 100%;
    display: flex;
    align-items: center;
    gap: 12px;
    background: #0d1b2a;
    border: 0;
    padding: 12px 14px;
    cursor: pointer;
    text-align: left;
    font-family: inherit;
    color: #e0e0e0;
  }

  .ftl-acc-head:hover {
    background: #102a44;
  }

  .ftl-acc-head .chev {
    color: #7fd8ff;
    font-size: 0.8rem;
    width: 12px;
    flex: none;
    transition: transform 0.15s;
  }

  .ftl-acc.open .ftl-acc-head .chev {
    transform: rotate(90deg);
  }

  .ftl-acc-head .w {
    font-weight: 700;
    letter-spacing: 0.05em;
    color: #fff;
    font-size: 0.95rem;
    flex: none;
    min-width: 74px;
  }

  .ftl-acc-head .sum {
    color: #7fbadc;
    font-size: 0.85rem;
  }

  .ftl-acc-head .nf {
    margin-left: auto;
    color: #8894a8;
    font-size: 0.82rem;
    white-space: nowrap;
    flex: none;
  }

  .ftl-acc-body {
    border-top: 1px solid #1a3a63;
  }

  /* Wide content scrolls inside its own box: five columns, and the venue laptop
     may be 1024px wide. */
  .ftl-table-wrap {
    overflow-x: auto;
  }

  .ftl-table {
    border-collapse: collapse;
    width: 100%;
    font-size: 0.9rem;
  }

  .ftl-table th,
  .ftl-table td {
    text-align: left;
    padding: 8px 10px;
    border-bottom: 1px solid #16273f;
    vertical-align: top;
  }

  .ftl-table th {
    font-weight: 600;
    color: #7fbadc;
    border-bottom: 1px solid #1a4a8a;
    white-space: nowrap;
  }

  .ftl-num {
    text-align: right;
  }

  .ftl-file code {
    font-family: ui-monospace, SFMono-Regular, Menlo, monospace;
    font-size: 0.82rem;
    color: #e0e0e0;
    display: block;
    word-break: break-all;
  }

  .ftl-intitle {
    display: block;
    color: #8894a8;
    font-size: 0.82rem;
    margin-top: 3px;
  }

  .warn {
    color: #f0b967;
  }

  .ftl-one {
    background: transparent;
    border: 1px solid #1a4a8a;
    color: #7fd8ff;
    border-radius: 6px;
    padding: 5px 12px;
    font-size: 0.85rem;
    cursor: pointer;
    white-space: nowrap;
  }

  .ftl-one:hover:not(:disabled) {
    border-color: #00d4ff;
    color: #00d4ff;
  }

  /* The instruction */
  .ftl-howto {
    margin-top: 26px;
    border-top: 1px solid #1a4a8a;
    padding-top: 18px;
  }

  .ftl-howto h3 {
    margin: 0 0 4px;
    font-size: 1.08rem;
    color: #fff;
    font-weight: 600;
  }

  .ftl-lead {
    margin: 0 0 16px;
    color: #8894a8;
    font-size: 0.86rem;
    line-height: 1.5;
  }

  .ftl-steps {
    margin: 0;
    padding: 0;
    list-style: none;
    counter-reset: s;
  }

  .ftl-steps li {
    counter-increment: s;
    position: relative;
    padding: 0 0 16px 44px;
    margin-bottom: 14px;
    border-bottom: 1px solid #16273f;
  }

  .ftl-steps li:last-child {
    border-bottom: 0;
    margin-bottom: 0;
  }

  .ftl-steps li::before {
    content: counter(s);
    position: absolute;
    left: 0;
    top: 0;
    width: 29px;
    height: 29px;
    border-radius: 50%;
    background: #0d1b2a;
    border: 1px solid #1a4a8a;
    color: #7fd8ff;
    font-weight: 700;
    font-size: 0.9rem;
    display: flex;
    align-items: center;
    justify-content: center;
  }

  .ftl-steps h4 {
    margin: 4px 0 5px;
    font-size: 0.96rem;
    color: #fff;
    font-weight: 600;
  }

  .ftl-steps p {
    margin: 0;
    line-height: 1.6;
    font-size: 0.9rem;
    color: #c3cede;
  }

  .ftl-contact {
    margin-top: 6px !important;
    color: #7fd8ff !important;
  }

  @media (max-width: 640px) {
    .ftl {
      padding: 16px;
    }

    .ftl-table {
      font-size: 0.82rem;
    }
  }
</style>
