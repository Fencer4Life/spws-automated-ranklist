// Phase 2 (P2.3-P2.6, ADR-079) — RegistrationForm.svelte: the standalone
// registration flow's step state machine (identity -> verify/rodo -> payment).
// Mocks the api module per the EventManager.test.ts pattern.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  fetchEventForRegistration: vi.fn(),
  matchRegistrationFencer: vi.fn(),
  createRegistration: vi.fn(),
  fetchEntryList: vi.fn(),
}))
import { fetchEventForRegistration, matchRegistrationFencer, createRegistration, fetchEntryList } from '../src/lib/api'
import RegistrationForm from '../src/components/RegistrationForm.svelte'
import type { RegistrationEventInfo } from '../src/lib/types'

const mockFetchEvent = vi.mocked(fetchEventForRegistration)
const mockMatch = vi.mocked(matchRegistrationFencer)
const mockCreate = vi.mocked(createRegistration)
const mockEntryList = vi.mocked(fetchEntryList)

const BASE_EVENT: RegistrationEventInfo = {
  id_event: 3,
  txt_code: 'PPW4-2025-2026',
  txt_name: 'IV Puchar Polski Weteranów',
  txt_season_code: 'SPWS-2025-2026',
  dt_start: '2099-06-01',
  dt_end: '2099-06-02',
  dt_registration_deadline: '2099-05-25',
  arr_weapons: ['EPEE', 'FOIL', 'SABRE'],
  num_entry_fee: 120,
  num_entry_fee_2w: 200,
  num_entry_fee_3w: 260,
  bool_use_spws_registration: true,
  url_registration: null,
}

beforeEach(() => {
  vi.clearAllMocks()
  // Default: nobody already on the roster, so the soft duplicate guard stays
  // quiet unless a test opts into it.
  mockEntryList.mockResolvedValue([])
  Object.assign(navigator, { clipboard: { writeText: vi.fn().mockResolvedValue(undefined) } })
})

async function fillIdentity(container: HTMLElement, overrides: Partial<{ surname: string; firstName: string; birthYear: string }> = {}) {
  const surnameInput = container.querySelector('input[name="surname"]') as HTMLInputElement
  const firstNameInput = container.querySelector('input[name="firstName"]') as HTMLInputElement
  const byInput = container.querySelector('input[name="birthYear"]') as HTMLInputElement
  await fireEvent.input(surnameInput, { target: { value: overrides.surname ?? 'kowalski' } })
  await fireEvent.input(firstNameInput, { target: { value: overrides.firstName ?? 'Jan' } })
  await fireEvent.input(byInput, { target: { value: overrides.birthYear ?? '1970' } })
  // Gender has no default any more — a pre-set 'M' silently recorded every
  // woman who never touched the select, and that value reaches the ranking
  // category, the entry list and the FTL seed.
  const genderSelect = container.querySelector('select[name="gender"]') as HTMLSelectElement
  await fireEvent.change(genderSelect, { target: { value: 'M' } })
  const epeeCheckbox = container.querySelector('input[type="checkbox"][value="EPEE"]') as HTMLInputElement
  await fireEvent.click(epeeCheckbox)
}

describe('RegistrationForm — event resolution + expiry gating (P2.4, D10)', () => {
  it('shows the identity step when the event is open', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    expect(container.querySelector('input[name="surname"]')).not.toBeNull()
  })

  it('shows not-found state when the event code does not resolve', async () => {
    mockFetchEvent.mockResolvedValue(null)
    const { findByText } = render(RegistrationForm, { props: { eventCode: 'NOPE' } })
    await findByText(/Nie znaleziono wydarzenia/)
  })

  it('shows external-registration state when bool_use_spws_registration is false', async () => {
    mockFetchEvent.mockResolvedValue({ ...BASE_EVENT, bool_use_spws_registration: false, url_registration: 'https://example.com/reg' })
    const { findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText(/poza tym systemem/)
  })

  it('shows closed state when past the registration deadline but before dt_end', async () => {
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      dt_registration_deadline: '2020-01-01',
      dt_start: '2020-01-05',
      dt_end: '2099-01-10',
    })
    const { findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText(/Zapisy zamknięte/)
  })

  it('shows expired state when past dt_end', async () => {
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      dt_registration_deadline: '2020-01-01',
      dt_start: '2020-01-05',
      dt_end: '2020-01-10',
    })
    const { findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText(/link wygasł/)
  })
})

describe('RegistrationForm — identity step (P2.3)', () => {
  it('uppercases the surname as it is typed', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    const surnameInput = container.querySelector('input[name="surname"]') as HTMLInputElement
    await fireEvent.input(surnameInput, { target: { value: 'kowalski' } })
    expect(surnameInput.value).toBe('KOWALSKI')
  })

  it('computes the V-cat live from birth year and season end year', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    const byInput = container.querySelector('input[name="birthYear"]') as HTMLInputElement
    await fireEvent.input(byInput, { target: { value: '1971' } }) // 2026-1971=55 -> V2
    await findByText('V2')
  })

  it('computes the fee from the number of selected weapons using the event tiers', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    const epee = container.querySelector('input[type="checkbox"][value="EPEE"]') as HTMLInputElement
    const foil = container.querySelector('input[type="checkbox"][value="FOIL"]') as HTMLInputElement
    await fireEvent.click(epee)
    await findByText('120 PLN')
    await fireEvent.click(foil)
    await findByText('200 PLN')
  })

  it('disables Continue until surname/firstName/birthYear/weapon are all filled', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    const continueBtn = container.querySelector('button.reg-continue') as HTMLButtonElement
    expect(continueBtn.disabled).toBe(true)
    await fillIdentity(container)
    expect(continueBtn.disabled).toBe(false)
  })
})

describe('RegistrationForm — routing after identity (P2.4, ADR-079 §2)', () => {
  it('routes to RODO on an exact match (Path A)', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(42)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    expect(mockMatch).toHaveBeenCalledWith('KOWALSKI', 'Jan', 1970)
  })

  // Supersedes "routes to the email-verify coming-soon panel on no match".
  // That panel was a dead end: no registration was ever written, so every
  // newcomer — and everyone whose stored birth year was only an ingestion
  // estimate — was refused outright. A miss now continues to RODO and is
  // written with id_fencer NULL. tbl_registration carries the full declaration
  // on its own, vw_registration_entry_list does not join tbl_fencer, and the
  // FTL seed exporter already handles unranked registrants — so the fencer
  // reaches the roster and the organizer's seed file without tbl_fencer ever
  // being written (ADR-079 §1 read-only invariant intact; the real fencer row
  // is created at result ingestion, §3).
  it('routes an unmatched fencer to RODO and warns that they are new', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(null)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    await findByText(/nie znaleźliśmy cię/i)
  })

  it('writes the unmatched registration with a null fencer id', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(null)
    mockCreate.mockResolvedValue(101)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await waitFor(() =>
      expect(mockCreate).toHaveBeenCalledWith(expect.objectContaining({ fencerId: null, birthYear: 1970 })),
    )
  })

  it('warns when someone with the same name is already on the entry list', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(null)
    mockEntryList.mockResolvedValue([
      {
        id_registration: 7,
        id_event: 3,
        txt_surname: 'KOWALSKI',
        txt_first_name: 'Jan',
        enum_gender: 'M',
        arr_weapons: ['EPEE'],
        enum_age_category: 'V1',
      },
    ] as never)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/jest już zawodnik/i)
  })

  it('keeps Continue disabled until a gender is chosen', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    const surnameInput = container.querySelector('input[name="surname"]') as HTMLInputElement
    const firstNameInput = container.querySelector('input[name="firstName"]') as HTMLInputElement
    const byInput = container.querySelector('input[name="birthYear"]') as HTMLInputElement
    await fireEvent.input(surnameInput, { target: { value: 'nowak' } })
    await fireEvent.input(firstNameInput, { target: { value: 'Anna' } })
    await fireEvent.input(byInput, { target: { value: '1975' } })
    await fireEvent.click(container.querySelector('input[type="checkbox"][value="EPEE"]') as HTMLInputElement)
    expect((container.querySelector('button.reg-continue') as HTMLButtonElement).disabled).toBe(true)
    await fireEvent.change(container.querySelector('select[name="gender"]') as HTMLSelectElement, {
      target: { value: 'F' },
    })
    expect((container.querySelector('button.reg-continue') as HTMLButtonElement).disabled).toBe(false)
  })
})

describe('RegistrationForm — RODO gate + payment (P2.5/P2.6)', () => {
  async function toRodo(container: HTMLElement, findByText: (m: string | RegExp) => Promise<HTMLElement>) {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(42)
    mockCreate.mockResolvedValue(99)
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
  }

  it('accept without ticking the checkbox does not submit and flags the checkbox invalid', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    const acceptBtn = container.querySelector('button.reg-rodo-accept') as HTMLButtonElement
    const checkbox = container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement
    expect(checkbox.classList.contains('reg-invalid')).toBe(false)
    await fireEvent.click(acceptBtn)
    expect(mockCreate).not.toHaveBeenCalled()
    expect(checkbox.classList.contains('reg-invalid')).toBe(true)
  })

  it('ticking the checkbox clears the invalid flag, then accept writes with consentVersion v1.0', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    const acceptBtn = container.querySelector('button.reg-rodo-accept') as HTMLButtonElement
    const checkbox = container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement
    await fireEvent.click(acceptBtn)
    expect(checkbox.classList.contains('reg-invalid')).toBe(true)
    await fireEvent.click(checkbox)
    expect(checkbox.classList.contains('reg-invalid')).toBe(false)
    await fireEvent.click(acceptBtn)
    await waitFor(() => expect(mockCreate).toHaveBeenCalled())
    expect(mockCreate).toHaveBeenCalledWith(
      expect.objectContaining({
        eventId: 3,
        surname: 'KOWALSKI',
        firstName: 'Jan',
        birthYear: 1970,
        fencerId: 42,
        consentVersion: 'v1.0',
      }),
    )
  })

  it('shows the payment screen with computed title + amount after RODO accept', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    await findByText('120 PLN')
  })

  it('the entry-list link on the payment screen points at ?event=<code>&view=list', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    const link = container.querySelector('a.reg-entry-list-link') as HTMLAnchorElement
    expect(link.getAttribute('href')).toBe('?event=PPW4-2025-2026&view=list')
  })

  // Modal-embed (calendar in-app modal) — the payment screen's entry-list
  // affordance becomes a button calling onviewlist instead of navigating,
  // when the form is hosted inside RegistrationModal rather than the
  // standalone register.html page.
  it('the entry-list affordance calls onviewlist instead of navigating when provided', async () => {
    const onviewlist = vi.fn()
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026', onviewlist } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    expect(container.querySelector('a.reg-entry-list-link')).toBeNull()
    const btn = container.querySelector('button.reg-entry-list-link') as HTMLButtonElement
    expect(btn).not.toBeNull()
    await fireEvent.click(btn)
    expect(onviewlist).toHaveBeenCalled()
  })
})

describe('RegistrationForm — write failure and back navigation', () => {
  async function toRodo(container: HTMLElement, findByText: (m: string | RegExp) => Promise<HTMLElement>) {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(42)
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
  }

  // fn_create_registration RAISEs once the D10 window guard trips, and the
  // network can fail outright. Before this, the rejected promise left the
  // fencer pressing a button that did nothing at all.
  it('surfaces an error instead of failing silently when the write rejects', async () => {
    mockCreate.mockRejectedValue(new Error('Registration window closed for event 3'))
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText(/nie udało się zapisać/i)
    // and the fencer is still on the consent step, not stranded
    expect(container.querySelector('button.reg-rodo-accept')).not.toBeNull()
  })

  it('goes back to the identity step so a mistyped birth year can be corrected', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('button.reg-back') as HTMLButtonElement)
    const byInput = await waitFor(() => {
      const el = container.querySelector('input[name="birthYear"]') as HTMLInputElement
      expect(el).not.toBeNull()
      return el
    })
    // the earlier answers survive the round trip
    expect(byInput.value).toBe('1970')
    expect((container.querySelector('input[name="surname"]') as HTMLInputElement).value).toBe('KOWALSKI')
  })
})

describe('RegistrationForm — modal-embed close affordance', () => {
  it('renders no close button by default (standalone page has nowhere to close to)', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    expect(container.querySelector('button.reg-close')).toBeNull()
  })

  it('renders a close button and calls onclose when provided (modal-embed)', async () => {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    const onclose = vi.fn()
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026', onclose } })
    await findByText('IV Puchar Polski Weteranów')
    const closeBtn = container.querySelector('button.reg-close') as HTMLButtonElement
    expect(closeBtn).not.toBeNull()
    await fireEvent.click(closeBtn)
    expect(onclose).toHaveBeenCalled()
  })
})
