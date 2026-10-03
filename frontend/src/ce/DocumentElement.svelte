<svelte:options customElement={{ tag: 'spws-document' }} />

<svelte:window onmessage={onReport} />

<div class="site-doc">
  <div class="site-doc-head">
    <SiteBar
      homeHref={hrefHome}
      longTitle={titles.long}
      shortTitle={titles.short}
      onmenu={() => { sidebarOpen = true }}
    />
  </div>
  {#if page}
    <iframe
      class="site-doc-frame"
      title={titles.long}
      src={frameSrc}
      style:height={frameHeight ? `${frameHeight}px` : undefined}
      bind:this={frame}
    ></iframe>
  {/if}
</div>

<Sidebar
  open={sidebarOpen}
  currentView={page ?? 'ranklist'}
  {links}
  onclose={() => { sidebarOpen = false }}
/>

<script lang="ts">
  // The calculator and the points table on the association's WordPress pages
  // (ADR-090 amendment 2026-10-03, FR-150; plan
  // doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §03).
  //
  // The element draws the SPWS bar and the drawer — the same SiteBar and Sidebar
  // the ranking and the calendar use — and frames the PROD copy of the document
  // from the file host: {asset-base}embed/{doc}.html. The maths stays in that
  // document, generated from the shared scoring module (ADR-102); this element
  // only places it. Nothing here signs in: ?admin=1 means nothing on these pages.
  //
  // The frame cannot size itself to a cross-origin document, so the document
  // reports its height (build-scoring-pages.mjs adds the report) and the frame
  // takes it — only from the asset base's origin.
  import SiteBar from '../components/SiteBar.svelte'
  import Sidebar from '../components/Sidebar.svelte'
  import { t, getLocale } from '../lib/locale.svelte'
  import { setAssetBase, assetUrl } from '../lib/assetBase'
  import type { SiteLinks, SitePage } from '../lib/types'

  let {
    doc = '',
    'asset-base': assetBase = '',
    'href-home': hrefHome = '',
    'href-ranking': hrefRanking = '',
    'href-calendar': hrefCalendar = '',
    'href-calculator': hrefCalculator = '',
    'href-table': hrefTable = '',
  }: {
    doc?: string
    'asset-base'?: string
    'href-home'?: string
    'href-ranking'?: string
    'href-calendar'?: string
    'href-calculator'?: string
    'href-table'?: string
  } = $props()

  // Synchronously at init, as App does: the bar's logo resolves through it.
  // svelte-ignore state_referenced_locally
  setAssetBase(assetBase)

  // Only these two documents are ever framed; any other value frames nothing.
  const DOCS: Record<string, SitePage> = {
    'kalkulator-punktow': 'calculator',
    'tabela-punktacji': 'table',
  }
  const page = $derived<SitePage | undefined>(Object.hasOwn(DOCS, doc) ? DOCS[doc] : undefined)

  const links: SiteLinks = $derived({
    home: hrefHome, ranking: hrefRanking, calendar: hrefCalendar, calculator: hrefCalculator, table: hrefTable,
  })

  const titles = $derived(
    page === 'calculator'
      ? { long: t('nav_calculator'), short: t('site_title_short_calculator') }
      : page === 'table'
        ? { long: t('nav_points_table'), short: t('site_title_short_table') }
        : { long: '', short: '' },
  )

  // The document follows the bar's PL/EN switch through ?lang=, which both
  // pages already read (it is how the drawer on github.io opens them).
  const frameSrc = $derived(`${assetUrl(`embed/${doc}.html`)}?lang=${getLocale()}`)

  // The origin the document is served from: the asset base's, or this page's
  // own when there is no base (a page served from the file host itself).
  const assetOrigin = $derived.by(() => {
    try {
      return new URL(assetBase || window.location.href).origin
    } catch {
      return ''
    }
  })

  let sidebarOpen = $state(false)
  let frame: HTMLIFrameElement | undefined = $state()
  let frameHeight = $state(0)

  function onReport(e: MessageEvent) {
    if (!assetOrigin || e.origin !== assetOrigin) return
    if (frame && e.source && e.source !== frame.contentWindow) return
    const data = e.data as { type?: unknown; height?: unknown } | null
    if (!data || data.type !== 'spws-doc-height') return
    const h = data.height
    if (typeof h !== 'number' || !Number.isFinite(h) || h <= 0) return
    frameHeight = Math.ceil(h)
  }
</script>

<style>
  :host {
    display: block;
  }
  .site-doc {
    font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
    color: #333;
  }
  /* The bar lines up with the document's own column (its `.wrap`: 28 px of
     gutter, at most 1800 px; 16 px of gutter from 900 px down), so its edges
     meet the cards' edges below it. */
  .site-doc-head {
    width: min(1800px, calc(100% - 28px));
    margin: 0 auto;
    padding-top: 16px;
    box-sizing: border-box;
  }
  /* Full width below the bar: the document centres its own content. Until the
     first report arrives the frame takes most of the screen, so nothing jumps
     to a sliver first. */
  .site-doc-frame {
    display: block;
    width: 100%;
    min-height: 0;
    height: 85vh;
    border: 0;
  }
  @media (max-width: 900px) {
    .site-doc-head {
      width: calc(100% - 16px);
      padding-top: 10px;
    }
  }
</style>
