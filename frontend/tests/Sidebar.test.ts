// Plan tests: 8.27, 8.28, 8.29, 8.30, 8.31, 8.32, 8.35, 8.36
// See doc/archive/m8_implementation_plan.md §T8.4.
// Plan tests 8.84–8.87 — third navigation entry linking to the standalone
// points calculator. See doc/plans/kalkulator-w-menu-ranklisty-2026-08-15.html.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Sidebar from '../src/components/Sidebar.svelte'
import { getLocale } from '../src/lib/locale.svelte'

describe('Sidebar (T8.4)', () => {
  const defaultProps = {
    open: true,
    currentView: 'ranklist' as const,
    isAdmin: false,
    onnavigate: vi.fn(),
    onclose: vi.fn(),
  }

  // 8.27 — Hamburger button opens sidebar (tested here as: open=true renders sidebar)
  it('renders sidebar when open=true', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const sidebar = container.querySelector('.sidebar')
    expect(sidebar).not.toBeNull()
  })

  it('does not render sidebar when open=false', () => {
    const { container } = render(Sidebar, {
      props: { ...defaultProps, open: false },
    })
    const sidebar = container.querySelector('.sidebar')
    // Sidebar element may exist but should not have .open class
    const openSidebar = container.querySelector('.sidebar.open')
    expect(openSidebar).toBeNull()
  })

  // 8.28 — Sidebar shows "SPWS" brand + Ranklista + Kalendarz items
  it('shows SPWS brand and navigation items', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const brand = container.querySelector('.sidebar-brand')
    const logo = brand?.querySelector('img.sidebar-logo') as HTMLImageElement
    expect(logo).not.toBeNull()
    expect(logo.alt).toBe('SPWS')

    const navItems = container.querySelectorAll('.nav-item')
    const texts = Array.from(navItems).map((el) => el.textContent?.trim())
    expect(texts).toContain('Ranking')
    expect(texts).toContain('Kalendarz')
  })

  // 8.29 — Clicking Ranklista → ranklist view, sidebar closes
  it('emits navigate(ranklist) and close when Ranklista clicked', async () => {
    const onnavigate = vi.fn()
    const onclose = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onnavigate, onclose, currentView: 'calendar' },
    })
    const navItems = container.querySelectorAll('.nav-item')
    const ranklistItem = Array.from(navItems).find((el) =>
      el.textContent?.includes('Ranking'),
    )
    expect(ranklistItem).not.toBeUndefined()
    await fireEvent.click(ranklistItem!)
    expect(onnavigate).toHaveBeenCalledWith('ranklist')
    expect(onclose).toHaveBeenCalled()
  })

  // 8.30 — Clicking Kalendarz → calendar view, sidebar closes
  it('emits navigate(calendar) and close when Kalendarz clicked', async () => {
    const onnavigate = vi.fn()
    const onclose = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onnavigate, onclose },
    })
    const navItems = container.querySelectorAll('.nav-item')
    const calendarItem = Array.from(navItems).find((el) =>
      el.textContent?.includes('Kalendarz'),
    )
    expect(calendarItem).not.toBeUndefined()
    await fireEvent.click(calendarItem!)
    expect(onnavigate).toHaveBeenCalledWith('calendar')
    expect(onclose).toHaveBeenCalled()
  })

  // 8.84 — Kolejność pozycji w szufladzie. Asercja jest RÓWNOŚCIĄ, nie zawieraniem:
  // to kolejność jest własnością wartą pilnowania, więc czwarta pozycja (ADR-092)
  // ROZSZERZA tę listę, a nie rozluźnia asercję.
  it('renders the drawer entries in order, the points table fourth', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const texts = Array.from(container.querySelectorAll('.nav-list .nav-item')).map((el) =>
      el.textContent?.trim(),
    )
    expect(texts).toEqual(['Ranking', 'Kalendarz', 'Kalkulator punktów', 'Tabela punktacji'])
  })

  // 8.85 — Kalkulator to odnośnik do samodzielnej strony, nie widok aplikacji
  it('renders the calculator entry as a link that does not navigate the app', async () => {
    const onnavigate = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onnavigate },
    })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Kalkulator'),
    ) as HTMLAnchorElement
    expect(item).not.toBeUndefined()
    expect(item.tagName).toBe('A')
    expect(item.getAttribute('href')).toContain('kalkulator-punktow.html')
    await fireEvent.click(item)
    expect(onnavigate).not.toHaveBeenCalled()
  })

  // 8.86 — Kliknięcie kalkulatora zamyka szufladę
  it('emits close when the calculator entry is clicked', async () => {
    const onclose = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onclose },
    })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Kalkulator'),
    )
    await fireEvent.click(item!)
    expect(onclose).toHaveBeenCalled()
  })

  // 8.87 — Odnośnik niesie język ustawiony w aplikacji
  it('carries the active locale in the calculator link', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Kalkulator'),
    ) as HTMLAnchorElement
    expect(item.getAttribute('href')).toBe(
      `kalkulator-punktow.html?lang=${getLocale()}`,
    )
  })

  // Plan tests 8.90–8.93 — czwarta pozycja prowadząca do Załącznika nr 1
  // (tabela punktacji). ADR-092. Ta sama budowa co pozycja kalkulatora:
  // odnośnik, nie przycisk — strona jest samodzielna, nie widokiem aplikacji.
  // See doc/plans/tabela-punktacji-2026-09-11.html §7.

  // 8.90 — Tabela to odnośnik do samodzielnej strony, nie widok aplikacji
  it('renders the points table entry as a link that does not navigate the app', async () => {
    const onnavigate = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onnavigate },
    })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Tabela punktacji'),
    ) as HTMLAnchorElement
    expect(item).not.toBeUndefined()
    expect(item.tagName).toBe('A')
    await fireEvent.click(item)
    expect(onnavigate).not.toHaveBeenCalled()
  })

  // 8.91 — Odnośnik niesie język ustawiony w aplikacji
  it('carries the active locale in the points table link', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Tabela punktacji'),
    ) as HTMLAnchorElement
    expect(item.getAttribute('href')).toBe(`tabela-punktacji.html?lang=${getLocale()}`)
  })

  // 8.92 — Nowa karta, bez dostępu do okna otwierającego
  it('opens the points table in a new tab with rel=noopener', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Tabela punktacji'),
    ) as HTMLAnchorElement
    expect(item.getAttribute('target')).toBe('_blank')
    expect(item.getAttribute('rel')).toBe('noopener')
  })

  // 8.93 — Kliknięcie tabeli zamyka szufladę
  it('emits close when the points table entry is clicked', async () => {
    const onclose = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onclose },
    })
    const item = Array.from(container.querySelectorAll('.nav-item')).find((el) =>
      el.textContent?.includes('Tabela punktacji'),
    )
    await fireEvent.click(item!)
    expect(onclose).toHaveBeenCalled()
  })

  // 8.31 — Sidebar overlay dims content
  it('renders overlay when sidebar is open', () => {
    const { container } = render(Sidebar, { props: defaultProps })
    const overlay = container.querySelector('.sidebar-overlay')
    expect(overlay).not.toBeNull()
  })

  // 8.32 — Clicking overlay closes sidebar
  it('emits close when overlay clicked', async () => {
    const onclose = vi.fn()
    const { container } = render(Sidebar, {
      props: { ...defaultProps, onclose },
    })
    const overlay = container.querySelector('.sidebar-overlay')
    expect(overlay).not.toBeNull()
    await fireEvent.click(overlay!)
    expect(onclose).toHaveBeenCalled()
  })

  // 8.35 — When admin active, sidebar shows admin section
  it('shows admin section when isAdmin=true', () => {
    const { container } = render(Sidebar, {
      props: { ...defaultProps, isAdmin: true },
    })
    const adminSection = container.querySelector('.admin-section')
    expect(adminSection).not.toBeNull()
    const adminItems = adminSection!.querySelectorAll('.nav-item')
    const texts = Array.from(adminItems).map((el) => el.textContent?.trim())
    expect(texts).toContain('Sezony')
    expect(texts).toContain('Wydarzenia')
    expect(texts).toContain('Szermierze')
  })

  // 8.36 — When admin NOT active, sidebar hides admin section
  it('hides admin section when isAdmin=false', () => {
    const { container } = render(Sidebar, {
      props: { ...defaultProps, isAdmin: false },
    })
    const adminSection = container.querySelector('.admin-section')
    expect(adminSection).toBeNull()
  })
})

// PROD deployment step 1 — the Pages copy of the app has no other route back to
// the association's site, so the drawer's mark becomes that route.
// Plan: doc/plans/prod-deployment-wordpress-2026-09-05.html §03.
describe('Sidebar — the way back to the association site', () => {
  it('wraps the SPWS mark in a link home', () => {
    const { container } = render(Sidebar, { props: { open: true, currentView: 'ranklist' } })
    const link = container.querySelector('.sidebar-brand a') as HTMLAnchorElement
    expect(link).not.toBeNull()
    expect(link.getAttribute('href')).toBe('https://weteraniszermierki.pl')
    expect(link.querySelector('img.sidebar-logo')).not.toBeNull()
  })
})

// WP.NAV.01–03 — the drawer on the association's WordPress pages (chrome="site").
// ADR-090 amendment 2026-10-03; FR-148, FR-149.
// Plan: doc/plans/wordpress-ranking-points-table-brainstorm-2026-10-02.html §05.
//
// On a WordPress page every drawer entry is its own page: a same-tab link to the
// address the page body gives, never an in-app view switch and never a new tab.
const SITE_LINKS = {
  home: 'https://weteraniszermierki.pl/',
  ranking: '/ranking/',
  calendar: '/znajdz-zawody/',
  calculator: '/kalkulator-punktow/',
  table: '/tabela-punktacji/',
}

describe('WP.NAV.01 — the drawer leads to the four public pages in the same tab', () => {
  const siteProps = {
    open: true,
    currentView: 'calendar' as const,
    isAdmin: false,
    links: SITE_LINKS,
    onnavigate: vi.fn(),
    onclose: vi.fn(),
  }

  it('renders four same-tab links in order, the current page marked', () => {
    const { container } = render(Sidebar, { props: siteProps })
    const items = Array.from(container.querySelectorAll('.nav-list .nav-item')) as HTMLAnchorElement[]
    expect(items.map((a) => a.tagName)).toEqual(['A', 'A', 'A', 'A'])
    expect(items.map((a) => a.getAttribute('href'))).toEqual([
      '/ranking/', '/znajdz-zawody/', '/kalkulator-punktow/', '/tabela-punktacji/',
    ])
    expect(items.map((a) => a.textContent?.trim())).toEqual([
      'Ranking', 'Kalendarz', 'Kalkulator punktów', 'Tabela punktacji',
    ])
    for (const a of items) expect(a.hasAttribute('target')).toBe(false)
    expect(items[1].classList.contains('active')).toBe(true)
    expect(items[1].getAttribute('aria-current')).toBe('page')
  })

  it('marks a document page as current', () => {
    const { container } = render(Sidebar, { props: { ...siteProps, currentView: 'calculator' as const } })
    const items = Array.from(container.querySelectorAll('.nav-list .nav-item'))
    expect(items[2].getAttribute('aria-current')).toBe('page')
    expect(items.filter((a) => a.getAttribute('aria-current') === 'page').length).toBe(1)
  })

  it('the logo leads to the address the page gives', () => {
    const { container } = render(Sidebar, { props: siteProps })
    const link = container.querySelector('.sidebar-brand a') as HTMLAnchorElement
    expect(link.getAttribute('href')).toBe('https://weteraniszermierki.pl/')
  })

  it('a choice closes the drawer and does not switch an in-app view', async () => {
    const onnavigate = vi.fn()
    const onclose = vi.fn()
    const { container } = render(Sidebar, { props: { ...siteProps, onnavigate, onclose } })
    const ranking = container.querySelector('.nav-list .nav-item') as HTMLAnchorElement
    // jsdom does not navigate; a same-tab link is followed by the browser.
    ranking.addEventListener('click', (e) => e.preventDefault())
    await fireEvent.click(ranking)
    expect(onclose).toHaveBeenCalled()
    expect(onnavigate).not.toHaveBeenCalled()
  })
})

describe('WP.NAV.02 — the drawer closes on Esc, in every mode', () => {
  it('closes on Escape while open, and ignores it while closed', async () => {
    for (const links of [undefined, SITE_LINKS]) {
      const onclose = vi.fn()
      const open = render(Sidebar, {
        props: { open: true, currentView: 'ranklist' as const, links, onnavigate: vi.fn(), onclose },
      })
      await fireEvent.keyDown(window, { key: 'Escape' })
      expect(onclose).toHaveBeenCalledTimes(1)
      open.unmount()

      const closedClose = vi.fn()
      const closed = render(Sidebar, {
        props: { open: false, currentView: 'ranklist' as const, links, onnavigate: vi.fn(), onclose: closedClose },
      })
      await fireEvent.keyDown(window, { key: 'Escape' })
      expect(closedClose).not.toHaveBeenCalled()
      closed.unmount()
    }
  })
})

// A guard: W2 says there is never a sign-in entry in the drawer. Today no mode
// has one, so this passes before the change; it is proven by mutation (adding
// such an entry turns it red), and it keeps the rule once chrome="site" lands.
describe('WP.NAV.03 — no sign-in entry in the drawer, in any mode (guard)', () => {
  const SIGN_IN = /zaloguj|logowanie|sign\s*in|log\s*in/i
  for (const links of [undefined, SITE_LINKS]) {
    for (const isAdmin of [false, true]) {
      it(`${links ? 'WordPress' : 'github.io'} drawer, ${isAdmin ? 'signed in' : 'signed out'}`, () => {
        const { container } = render(Sidebar, {
          props: { open: true, currentView: 'ranklist' as const, isAdmin, links, onnavigate: vi.fn(), onclose: vi.fn() },
        })
        expect(container.textContent ?? '').not.toMatch(SIGN_IN)
      })
    }
  }
})
