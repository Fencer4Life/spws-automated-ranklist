// Standalone entry list (register.html?view=list). The custom element renders
// the roster on its own, with no registration form around it — so unlike the
// modal it had no close affordance and, unlike the in-flow roster, no back
// button either. That left a visitor who followed the shared roster link with
// no route to the registration form at all.
//
// Closing the list here means returning to the registration form for the same
// event, which is the only thing there is to go back to on this page.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  initClient: vi.fn(),
  fetchEventForRegistration: vi.fn(),
  fetchEntryList: vi.fn(),
}))
import { fetchEventForRegistration, fetchEntryList } from '../src/lib/api'
import EntryListElement from '../src/ce/EntryListElement.svelte'

const mockEvent = vi.mocked(fetchEventForRegistration)
const mockRows = vi.mocked(fetchEntryList)

beforeEach(() => {
  vi.clearAllMocks()
  mockEvent.mockResolvedValue({ id_event: 3, txt_code: 'PPW1-2026-2027' } as never)
  mockRows.mockResolvedValue([
    {
      id_registration: 1, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Jan',
      enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V2',
    },
  ] as never)
})

describe('EntryListElement — standalone roster', () => {
  it('offers a close affordance that returns to the registration form for the same event', async () => {
    const assign = vi.fn()
    // jsdom forbids assigning location.href outright, so the component routes
    // through a seam we can observe rather than calling it directly.
    vi.stubGlobal('location', { ...window.location, assign, search: '?event=PPW1-2026-2027&view=list' })

    const { container, findByText } = render(EntryListElement, {
      props: { event: 'PPW1-2026-2027', demo: false },
    })
    await findByText('KOWALSKI Jan')

    const closeBtn = container.querySelector('button.el-close') as HTMLButtonElement
    expect(closeBtn).not.toBeNull()
    await fireEvent.click(closeBtn)

    expect(assign).toHaveBeenCalledWith('?event=PPW1-2026-2027')
    vi.unstubAllGlobals()
  })
})
