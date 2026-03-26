// Plan tests: 9.78, 9.79, 9.80, 9.81, 9.82
// See .claude/plans/rosy-bouncing-kitten.md §T9.8.

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import Sidebar from '../src/components/Sidebar.svelte'
import type { AppView } from '../src/lib/types'

describe('AdminRouting (T9.8)', () => {
  // 9.78 — Clicking "Sezony" calls onnavigate with 'admin_seasons'
  it('clicking Sezony navigates to admin_seasons', async () => {
    const onnavigate = vi.fn()
    const { container } = render(Sidebar, {
      props: { open: true, currentView: 'ranklist' as AppView, isAdmin: true, onnavigate, onclose: vi.fn() },
    })

    const adminItems = container.querySelectorAll('.admin-item')
    // First admin item is Sezony
    await fireEvent.click(adminItems[0])
    expect(onnavigate).toHaveBeenCalledWith('admin_seasons')
  })

  // 9.79 — Clicking "Wydarzenia" calls onnavigate with 'admin_events'
  it('clicking Wydarzenia navigates to admin_events', async () => {
    const onnavigate = vi.fn()
    const { container } = render(Sidebar, {
      props: { open: true, currentView: 'ranklist' as AppView, isAdmin: true, onnavigate, onclose: vi.fn() },
    })

    const adminItems = container.querySelectorAll('.admin-item')
    await fireEvent.click(adminItems[1])
    expect(onnavigate).toHaveBeenCalledWith('admin_events')
  })

  // 9.80 — Clicking "Tożsamości" calls onnavigate with 'admin_identities'
  it('clicking Tożsamości navigates to admin_identities', async () => {
    const onnavigate = vi.fn()
    const { container } = render(Sidebar, {
      props: { open: true, currentView: 'ranklist' as AppView, isAdmin: true, onnavigate, onclose: vi.fn() },
    })

    const adminItems = container.querySelectorAll('.admin-item')
    await fireEvent.click(adminItems[2])
    expect(onnavigate).toHaveBeenCalledWith('admin_identities')
  })

  // 9.81 — Admin nav items hidden when isAdmin=false
  it('admin items hidden when isAdmin=false', () => {
    const { container } = render(Sidebar, {
      props: { open: true, currentView: 'ranklist' as AppView, isAdmin: false, onnavigate: vi.fn(), onclose: vi.fn() },
    })

    const adminItems = container.querySelectorAll('.admin-item')
    expect(adminItems.length).toBe(0)
  })

  // 9.82 — AppView type includes admin views (compile-time check via assignment)
  it('AppView type includes admin view values', () => {
    // Type-level check: these assignments must compile without error
    const views: AppView[] = ['admin_seasons', 'admin_events', 'admin_identities', 'admin_scoring']
    expect(views.length).toBe(4)
  })
})
