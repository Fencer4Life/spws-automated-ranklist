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
})
