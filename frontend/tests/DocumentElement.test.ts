// WP.DOC.01–02 — <spws-document>: the calculator and the points table on the
// association's WordPress pages, inside the SPWS bar and drawer.
// ADR-090 amendment 2026-10-03; FR-150.
// Plan: doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §03, §05.
//
// The element draws the bar and the drawer itself and frames the PROD copy of the
// document from the file host ({asset-base}embed/{doc}.html). The maths stays in
// that document (ADR-102); the element only places it. The document reports its
// height by postMessage, and the element believes only the asset base's origin.

import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import { tick } from 'svelte'

vi.mock('../src/lib/admin-auth.svelte', () => import('./helpers/fakeAdminAuth.svelte'))

import DocumentElement from '../src/ce/DocumentElement.svelte'
import { setLocale } from '../src/lib/locale.svelte'
import { setAssetBase } from '../src/lib/assetBase'

const ASSET_BASE = 'https://fencer4life.github.io/spws-automated-ranklist/'
const ASSET_ORIGIN = 'https://fencer4life.github.io'
const HREFS = {
  'href-home': 'https://weteraniszermierki.pl/',
  'href-ranking': '/ranking/',
  'href-calendar': '/znajdz-zawody/',
  'href-calculator': '/kalkulator-punktow/',
  'href-table': '/tabela-punktacji/',
}

const docProps = (doc: string) => ({ doc, 'asset-base': ASSET_BASE, ...HREFS })

const frameOf = (container: HTMLElement) =>
  container.querySelector('iframe.site-doc-frame') as HTMLIFrameElement | null

const titles = (container: HTMLElement) => [
  container.querySelector('header.site-bar .site-title-long')?.textContent?.trim(),
  container.querySelector('header.site-bar .site-title-short')?.textContent?.trim(),
]

beforeEach(() => {
  setLocale('pl')
  setAssetBase('')
  window.history.replaceState(null, '', '/')
})

afterEach(() => {
  setAssetBase('')
  window.history.replaceState(null, '', '/')
})

describe('WP.DOC.01 — the bar, the drawer and a frame of the PROD copy', () => {
  it('the calculator: its titles, the drawer with the calculator marked, and the frame', async () => {
    const { container } = render(DocumentElement, { props: docProps('kalkulator-punktow') })

    const bar = container.querySelector('header.site-bar')
    expect(bar).not.toBeNull()
    expect(bar!.querySelector('button.hamburger-btn')).not.toBeNull()
    expect(bar!.querySelector('a.site-home')?.getAttribute('href')).toBe('https://weteraniszermierki.pl/')
    expect(bar!.querySelector('a.site-home img')?.getAttribute('src')).toBe(`${ASSET_BASE}SPWS-logo.png`)
    expect(bar!.querySelector('.lang-toggle')).not.toBeNull()
    expect(titles(container)).toEqual(['Kalkulator punktów', 'Kalkulator'])

    const current = container.querySelector('.sidebar .nav-item[aria-current="page"]')
    expect(current?.getAttribute('href')).toBe('/kalkulator-punktow/')

    expect(frameOf(container)?.getAttribute('src')).toBe(`${ASSET_BASE}embed/kalkulator-punktow.html?lang=pl`)

    setLocale('en')
    await tick()
    expect(titles(container)).toEqual(['Points calculator', 'Calculator'])
    expect(frameOf(container)?.getAttribute('src')).toBe(`${ASSET_BASE}embed/kalkulator-punktow.html?lang=en`)
  })

  it('the points table: its titles and its frame', async () => {
    const { container } = render(DocumentElement, { props: docProps('tabela-punktacji') })
    expect(titles(container)).toEqual(['Tabela punktacji', 'Tabela'])
    expect(frameOf(container)?.getAttribute('src')).toBe(`${ASSET_BASE}embed/tabela-punktacji.html?lang=pl`)
    setLocale('en')
    await tick()
    expect(titles(container)).toEqual(['Points table', 'Table'])
  })

  it('frames only the two known documents', () => {
    for (const doc of ['../register', 'https://example.com/x', 'kalkulator-punktow.html', '']) {
      const { container, unmount } = render(DocumentElement, { props: docProps(doc) })
      expect(frameOf(container)).toBeNull()
      unmount()
    }
  })

  it('opens no sign-in on ?admin=1 — only /ranking/ carries admin-entry', async () => {
    window.history.replaceState(null, '', '/kalkulator-punktow/?admin=1')
    const { container } = render(DocumentElement, { props: docProps('kalkulator-punktow') })
    await tick()
    expect(container.querySelector('.admin-modal')).toBeNull()
  })

  it('the drawer opens on ☰ only', async () => {
    const { container } = render(DocumentElement, { props: docProps('tabela-punktacji') })
    expect(container.querySelector('.sidebar.open')).toBeNull()
    await fireEvent.click(container.querySelector('header.site-bar .hamburger-btn')!)
    expect(container.querySelector('.sidebar.open')).not.toBeNull()
  })
})

describe('WP.DOC.02 — the frame takes the reported height, from the file host only', () => {
  const report = (frame: HTMLIFrameElement, origin: string, data: unknown) =>
    window.dispatchEvent(new MessageEvent('message', { origin, data, source: frame.contentWindow }))

  it('follows the height the document reports', async () => {
    const { container } = render(DocumentElement, { props: docProps('kalkulator-punktow') })
    const frame = frameOf(container)!
    expect(frame).not.toBeNull()
    report(frame, ASSET_ORIGIN, { type: 'spws-doc-height', height: 1834 })
    await tick()
    expect(frame.style.height).toBe('1834px')
    report(frame, ASSET_ORIGIN, { type: 'spws-doc-height', height: 2210 })
    await tick()
    expect(frame.style.height).toBe('2210px')
  })

  it('ignores a report from any other origin, and a malformed one', async () => {
    const { container } = render(DocumentElement, { props: docProps('tabela-punktacji') })
    const frame = frameOf(container)!
    report(frame, ASSET_ORIGIN, { type: 'spws-doc-height', height: 900 })
    await tick()
    expect(frame.style.height).toBe('900px')

    report(frame, 'https://weteraniszermierki.pl', { type: 'spws-doc-height', height: 5 })
    report(frame, 'https://evil.example', { type: 'spws-doc-height', height: 99999 })
    report(frame, ASSET_ORIGIN, { type: 'spws-doc-height', height: 'tall' })
    report(frame, ASSET_ORIGIN, { type: 'spws-doc-height', height: -1 })
    report(frame, ASSET_ORIGIN, { type: 'other', height: 300 })
    await tick()
    expect(frame.style.height).toBe('900px')
  })
})
