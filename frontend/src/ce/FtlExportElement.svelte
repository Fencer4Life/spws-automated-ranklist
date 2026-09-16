<svelte:options customElement="spws-ftl-export" />

<FtlExport
  {events}
  {selectedId}
  {entries}
  {rosters}
  {loading}
  {notFound}
  {takenAt}
  {contact}
  onselect={select}
  onrefresh={refresh}
/>

<script lang="ts">
  // The FTL seed export, as a custom element for the public WordPress page
  // (ADR-090, plan §1). It owns everything the component deliberately does not:
  // the capability token, the event list, which event is selected, and the
  // re-read that happens before every download.
  //
  // ACCESS. The link is /pliki-zasilajace-xml-ftl/?k=<uuid>. The token is read here and
  // passed to each RPC, but it is CHECKED in Postgres — the bundle is public, so
  // a check in this file would be decoration. No token means the functions
  // return nothing and the page renders its empty state; a stale link looks
  // empty rather than broken.
  //
  // LANGUAGE. This is the first embed to carry one. Organizers of EVF-circuit
  // events may not read Polish, so `lang` sets the initial value and the flags
  // in the component override it. Polish remains the default.
  import FtlExport from '../components/FtlExport.svelte'
  import {
    initClient,
    fetchFtlExportEvents,
    fetchFtlExportEntries,
    fetchFtlRoster,
  } from '../lib/api'
  import { setLocale, type Locale } from '../lib/locale.svelte'
  import { setAssetBase } from '../lib/assetBase'
  import type { ExportEntryRow, RosterRow } from '../lib/ftlSeedExport'
  import type { FtlExportEvent } from '../lib/types'

  let {
    'supabase-cert-url': supabaseCertUrl = '',
    'supabase-cert-key': supabaseCertKey = '',
    'supabase-prod-url': supabaseProdUrl = '',
    'supabase-prod-key': supabaseProdKey = '',
    event = '',
    token = '',
    lang = '',
    contact = '',
    'asset-base': assetBase = '',
    demo = false,
  }: {
    'supabase-cert-url'?: string
    'supabase-cert-key'?: string
    'supabase-prod-url'?: string
    'supabase-prod-key'?: string
    event?: string
    token?: string
    lang?: string
    contact?: string
    'asset-base'?: string
    demo?: boolean
  } = $props()

  let events = $state<FtlExportEvent[]>([])
  let selectedId = $state<number | null>(null)
  let entries = $state<ExportEntryRow[]>([])
  let rosters = $state<Record<string, RosterRow[]>>({})
  let loading = $state(false)
  let notFound = $state(false)
  let takenAt = $state('')

  // The attribute wins when the host page sets one; otherwise ?k= from the URL,
  // which is how the link is actually shared.
  const accessToken = $derived(
    token || (typeof location !== 'undefined' ? new URLSearchParams(location.search).get('k') : '') || '',
  )

  // Where the embed's own images live. The bundle is served from GitHub Pages
  // but the element is mounted on a WordPress page at /pliki-zasilajace-xml-ftl/,
  // so a bare 'SPWS-logo.png' resolves against weteraniszermierki.pl and 404s.
  // The published page has passed this attribute since 2026-09-13; until
  // 2026-09-16 the element did not declare it and the value was discarded,
  // which is why the mark could not be added before now (ADR-090 §7).
  //
  // Set synchronously at module init for the same reason initClient is: the
  // value arrives once as a static attribute. Empty leaves paths untouched,
  // which is correct for register.html on the Pages origin root.
  // svelte-ignore state_referenced_locally
  setAssetBase(assetBase)

  // initClient runs synchronously at module init rather than in an $effect, for
  // the same reason RegistrationElement does it — see that file's comment.
  if (!demo) {
    const url = supabaseCertUrl || supabaseProdUrl
    const key = supabaseCertKey || supabaseProdKey
    if (url && key) initClient(url, key)
  }

  // Only 'en' switches away from the default. Anything else — an empty
  // attribute, "pl", or a language we have no keys for — is left on Polish
  // rather than falling through to key names on screen.
  $effect(() => {
    const normalised = lang.trim().toLowerCase().slice(0, 2)
    if (normalised === 'en' || normalised === 'pl') setLocale(normalised as Locale)
  })

  function stamp(): string {
    return new Date().toLocaleString('sv-SE').slice(0, 16)
  }

  /** Entries plus one roster per weapon that actually has entrants. */
  async function readEvent(
    idEvent: number,
  ): Promise<{ entries: ExportEntryRow[]; rosters: Record<string, RosterRow[]> }> {
    const rows = await fetchFtlExportEntries(idEvent, accessToken)
    const weapons = [...new Set(rows.map((r) => r.enum_weapon))]
    const pairs = await Promise.all(
      weapons.map(async (w) => [w, await fetchFtlRoster(idEvent, w, accessToken)] as const),
    )
    return { entries: rows, rosters: Object.fromEntries(pairs) }
  }

  async function load(idEvent: number): Promise<void> {
    loading = true
    try {
      const read = await readEvent(idEvent)
      entries = read.entries
      rosters = read.rosters
      takenAt = stamp()
    } finally {
      loading = false
    }
  }

  function select(idEvent: number): void {
    selectedId = idEvent
    void load(idEvent)
  }

  /**
   * Re-read before building. The component calls this on every download so the
   * files are made from the entry list as it stands at that moment rather than
   * as it stood when the page was opened.
   */
  async function refresh(): Promise<{
    entries: ExportEntryRow[]
    rosters: Record<string, RosterRow[]>
  }> {
    if (selectedId == null) return { entries, rosters }
    const read = await readEvent(selectedId)
    entries = read.entries
    rosters = read.rosters
    takenAt = stamp()
    return read
  }

  $effect(() => {
    if (demo || !accessToken) return
    loading = true
    notFound = false
    fetchFtlExportEvents(accessToken)
      .then(async (list) => {
        // Soonest first. fn_ftl_export_events already orders by date, but
        // "soonest" is the intent and belongs in the code rather than resting on
        // a remote ORDER BY surviving the round trip.
        events = [...list].sort((a, b) => (a.dt_start ?? '9999').localeCompare(b.dt_start ?? '9999'))
        // A named event still wins, so a per-event link keeps working; it just
        // no longer traps the reader on that event.
        const named = event ? events.find((e) => e.txt_code === event) : undefined
        const chosen = named ?? events[0]
        if (!chosen) {
          notFound = event !== ''
          return
        }
        selectedId = chosen.id_event
        await load(chosen.id_event)
      })
      .catch(() => {
        notFound = true
      })
      .finally(() => {
        loading = false
      })
  })
</script>
