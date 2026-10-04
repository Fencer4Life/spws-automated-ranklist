<!-- The SPWS bar on the association's WordPress pages (chrome="site").
     ADR-090 amendment 2026-10-03, FR-148; plan
     doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §02–§03.

     One row: ☰, the SPWS logo as the link home, the page's title and the PL/EN
     switch. The bar carries both titles and CSS shows the short one below
     430 px (Q2 = C), so the switch stays in the bar on a phone. Our bundle draws
     it, not the CMS, so the same tag works under any CMS (W5). The app and
     <spws-document> both use it. -->
<header class="site-bar">
  <button class="hamburger-btn" type="button" onclick={onmenu} aria-label="Menu">&#9776;</button>
  <a class="site-home" href={homeHref} aria-label={t('embed_home_label')} title={t('embed_home_label')}>
    <img src={assetUrl('SPWS-logo.png')} alt="SPWS" class="site-logo" />
  </a>
  <h1 class="site-title">
    <span class="site-title-long">{longTitle}</span><span class="site-title-short">{shortTitle}</span>
  </h1>
  <div class="site-actions">
    <LangToggle />
  </div>
</header>

<script lang="ts">
  import LangToggle from './LangToggle.svelte'
  import { t } from '../lib/locale.svelte'
  import { assetUrl } from '../lib/assetBase'

  let {
    homeHref,
    longTitle,
    shortTitle,
    onmenu = () => {},
  }: {
    homeHref: string
    longTitle: string
    shortTitle: string
    onmenu?: () => void
  } = $props()
</script>

<style>
  .site-bar {
    display: flex;
    align-items: center;
    gap: 12px;
    margin-bottom: 8px;
    flex: 0 0 auto;
    min-width: 0;
  }
  .hamburger-btn {
    border: none;
    background: none;
    font-size: 22px;
    cursor: pointer;
    padding: 4px 8px;
    color: #333;
    line-height: 1;
    flex: 0 0 auto;
  }
  .site-home {
    display: inline-flex;
    align-items: center;
    flex: 0 0 auto;
  }
  .site-logo {
    height: 26px;
    width: auto;
    display: block;
  }
  .site-title {
    margin: 0;
    /* The same face as the calendar's embed row, so the pages read as one site. */
    font-size: 28px;
    font-weight: 400;
    line-height: 1.2;
    color: #173f70;
    /* Takes the slack, so the switch sits hard right. */
    flex: 1 1 auto;
    min-width: 0;
    overflow: hidden;
    text-overflow: ellipsis;
    white-space: nowrap;
  }
  .site-title-short {
    display: none;
  }
  .site-actions {
    display: flex;
    align-items: center;
    gap: 8px;
    flex: 0 0 auto;
  }
  @media (max-width: 600px) {
    .site-title {
      font-size: 23px;
    }
    .site-logo {
      height: 22px;
    }
  }
  /* Below 430 px (Q2 = C): the short title, and the width bought back from the
     things around it, so the bar stays one row at 320 px in both languages.
     429.98 rather than a range query, which older iPhones do not read. */
  @media (max-width: 429.98px) {
    .site-bar {
      gap: 6px;
    }
    .hamburger-btn {
      padding: 4px;
    }
    .site-title {
      font-size: 19px;
    }
    .site-title-long {
      display: none;
    }
    .site-title-short {
      display: inline;
    }
    .site-logo {
      height: 19px;
    }
    .site-actions {
      gap: 5px;
    }
  }
  /* The narrowest phones (320 px): a little more room. Every short title then
     keeps at least 20 px to spare (measured: "Calculator" 20.5 px, "Kalendarz"
     21.9 px), so a wider phone font than the test browser's still fits. */
  @media (max-width: 359.98px) {
    .site-title {
      font-size: 18px;
    }
    .site-logo {
      height: 16px;
    }
  }
</style>
