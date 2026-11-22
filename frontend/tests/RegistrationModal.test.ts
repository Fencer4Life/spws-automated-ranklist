// ADR-079 amend — RegistrationModal.svelte: opens the registration form / entry
// list as an in-app modal over the calendar (same overlay/backdrop-close
// interaction pattern as DrilldownModal), instead of navigating to the
// standalone register.html page. Closing (backdrop click or the ×) returns to
// the calendar — no page navigation.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  fetchEventForRegistration: vi.fn(),
  matchRegistrationFencer: vi.fn(),
  createRegistration: vi.fn(),
  fetchEntryList: vi.fn(),
  // FR-175: no ranks, as for an event whose box is not ticked.
  fetchEntryRanks: vi.fn(() => Promise.resolve([])),
  deleteRegistration: vi.fn(),
  // FR-170: a signed-in list also reads each entry's details and the season.
  fetchAdminEntryDetails: vi.fn(async () => []),
  fetchEventSeasonEndYear: vi.fn(async () => 2027),
  updateRegistrationAsAdmin: vi.fn(),
}))
import { fetchEventForRegistration, fetchEntryList } from '../src/lib/api'
import RegistrationModal from '../src/components/RegistrationModal.svelte'

const mockFetchEvent = vi.mocked(fetchEventForRegistration)
const mockFetchEntryList = vi.mocked(fetchEntryList)

beforeEach(() => {
  vi.clearAllMocks()
})

describe('RegistrationModal', () => {
  it('renders nothing when closed', () => {
    const { container } = render(RegistrationModal, { props: { open: false } })
    expect(container.querySelector('.modal-overlay')).toBeNull()
  })

  it('renders the registration form when open with view=form', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const { container, findByText } = render(RegistrationModal, {
      props: { open: true, eventCode: 'PPW4-2025-2026', view: 'form' },
    })
    await findByText(/Nie znaleziono wydarzenia/)
    expect(container.querySelector('.reg-card')).not.toBeNull()
  })

  it('renders the entry list when open with view=list', async () => {
    mockFetchEntryList.mockResolvedValue([])
    const { container } = render(RegistrationModal, {
      props: { open: true, eventId: 5, view: 'list' },
    })
    await waitFor(() => expect(container.querySelector('.el-card')).not.toBeNull())
    expect(mockFetchEntryList).toHaveBeenCalledWith(5)
  })

  it('calls onclose when the backdrop is clicked, not when the content is clicked', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const onclose = vi.fn()
    const { container, findByText } = render(RegistrationModal, {
      props: { open: true, eventCode: 'PPW4-2025-2026', onclose },
    })
    await findByText(/Nie znaleziono wydarzenia/)
    await fireEvent.click(container.querySelector('.reg-card')!)
    expect(onclose).not.toHaveBeenCalled()
    await fireEvent.click(container.querySelector('.modal-overlay')!)
    expect(onclose).toHaveBeenCalled()
  })

  it('forwards onclose to the embedded form so its own close (×) button also closes the modal', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const onclose = vi.fn()
    const { container, findByText } = render(RegistrationModal, {
      props: { open: true, eventCode: 'PPW4-2025-2026', onclose },
    })
    await findByText(/Nie znaleziono wydarzenia/)
    await fireEvent.click(container.querySelector('button.reg-close')!)
    expect(onclose).toHaveBeenCalled()
  })

  // FR-166, ELREM.12 — the modal forwards the administrator setting, the
  // event's name and whether registration is open to the entry list.
  it('hands the administrator setting to the entry list, and nothing by default', async () => {
    const rows = [
      { id_registration: 1, id_event: 5, txt_surname: 'KOWAL', txt_first_name: 'Anna', enum_gender: 'F' as const, arr_weapons: ['EPEE' as const], enum_age_category: 'V1' as const },
    ]
    mockFetchEntryList.mockResolvedValue(rows)
    const plain = render(RegistrationModal, { props: { open: true, eventId: 5, view: 'list' } })
    await waitFor(() => expect(plain.container.querySelector('td.el-name')).not.toBeNull())
    expect(plain.container.querySelector('button.el-remove')).toBeNull()
    plain.unmount()

    const admin = render(RegistrationModal, {
      props: { open: true, eventId: 5, view: 'list', canRemove: true, eventName: 'PEW5 Łomianki', registrationOpen: false },
    })
    await waitFor(() => expect(admin.container.querySelector('button.el-remove')).not.toBeNull())
    await fireEvent.click(admin.container.querySelector('button.el-remove')!)
    const dialog = admin.container.querySelector('[role="alertdialog"]')
    expect(dialog?.textContent).toContain('PEW5 Łomianki')
    expect(dialog?.textContent).toContain('Termin zapisów już minął.')
  })
})
