// Plan tests: 8.27, 8.28, 8.29, 8.30, 8.31, 8.32, 8.35, 8.36
// See doc/archive/m8_implementation_plan.md §T8.4.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Sidebar from '../src/components/Sidebar.svelte'

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
