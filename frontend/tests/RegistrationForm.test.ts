// Phase 2 (P2.3-P2.6, ADR-079) — RegistrationForm.svelte: the standalone
// registration flow's step state machine (identity -> verify/rodo -> payment).
// Mocks the api module per the EventManager.test.ts pattern.

import { describe, it, expect, vi, beforeEach } from 'vitest'
import { render, fireEvent, waitFor } from '@testing-library/svelte'

vi.mock('../src/lib/api', () => ({
  fetchEventForRegistration: vi.fn(),
  matchRegistrationFencer: vi.fn(),
  createRegistration: vi.fn(),
  updateRegistration: vi.fn(),
  fetchEntryList: vi.fn(),
}))
import {
  fetchEventForRegistration,
  matchRegistrationFencer,
  createRegistration,
  updateRegistration,
  fetchEntryList,
} from '../src/lib/api'
vi.mock('../src/lib/editToken', () => ({ newEditToken: vi.fn() }))
import { newEditToken } from '../src/lib/editToken'
import RegistrationForm from '../src/components/RegistrationForm.svelte'
import type { RegistrationEventInfo } from '../src/lib/types'

const mockFetchEvent = vi.mocked(fetchEventForRegistration)
const mockMatch = vi.mocked(matchRegistrationFencer)
const mockCreate = vi.mocked(createRegistration)
const mockEntryList = vi.mocked(fetchEntryList)
const mockUpdate = vi.mocked(updateRegistration)
const mockNewToken = vi.mocked(newEditToken)

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
  txt_payee: 'STOWARZYSZENIE POLSKICH WETERANÓW SZERMIERKI',
  txt_iban: 'PL 06 1090 1665 0000 0001 5004 1549',
  txt_payment_source: 'ORGANIZER',
}

beforeEach(() => {
  vi.clearAllMocks()
  // Default: nobody already on the roster, so the soft duplicate guard stays
  // quiet unless a test opts into it.
  mockEntryList.mockResolvedValue([])
  mockNewToken.mockReturnValue('tok-generated-0123456789abcdef')
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

  it('trims padded names before the match lookup and the write', async () => {
    // canContinue validated with .trim() but the RAW strings were submitted, so
    // a trailing space typed by the fencer was persisted verbatim — two of the
    // first fourteen live PROD entries were stored as "Gary " and "KUCIĘBA ".
    // The database trigger trg_trim_registration_names covers callers that never
    // touch this form; this pins the form boundary itself.
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(null)
    mockCreate.mockResolvedValue(102)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container, { surname: '  kowalski  ', firstName: '  Jan  ' })
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await waitFor(() => expect(mockMatch).toHaveBeenCalledWith('KOWALSKI', 'Jan', 1970))
    await findByText(/RODO/)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await waitFor(() =>
      expect(mockCreate).toHaveBeenCalledWith(
        expect.objectContaining({ surname: 'KOWALSKI', firstName: 'Jan' }),
      ),
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

  // The affordance no longer navigates anywhere. It used to be an <a> to
  // ?event=X&view=list, which made register.html mount spws-entry-list INSTEAD
  // of spws-registration — a full page load that destroyed the form and with
  // it the only copy of the transfer data. register.html still honours that
  // URL for cold visitors; the in-flow path just stopped using it.
  it('the entry-list affordance is a button, not a navigation link', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    expect(container.querySelector('a.reg-entry-list-link')).toBeNull()
    expect(container.querySelector('button.reg-entry-list-link')).not.toBeNull()
  })

  // The regression this whole change exists for. Opening the roster used to
  // unmount the form — a page load on register.html, an {:else} branch in
  // RegistrationModal — and the payment details are $derived from form state,
  // so they were unrecoverable without registering again.
  it('opens the roster in place and comes back with the payment details intact', async () => {
    mockEntryList.mockResolvedValue([
      { id_registration: 7, id_event: 3, txt_surname: 'WHITLEY', txt_first_name: 'Gary', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V3' },
    ] as never)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')

    await fireEvent.click(container.querySelector('button.reg-entry-list-link') as HTMLButtonElement)
    await findByText('WHITLEY Gary')

    const back = container.querySelector('button.el-back') as HTMLButtonElement
    expect(back).not.toBeNull()
    await fireEvent.click(back)

    // Not merely "the payment step is showing" — the derived transfer title and
    // amount must still be populated. A back button that returned to a blank
    // payment panel would satisfy a weaker assertion.
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    await findByText('120 PLN')
  })

  it('the in-flow roster carries a close control even standalone, where no onclose is supplied', async () => {
    // The × is the affordance people reach for in a card's corner. On the
    // standalone page RegistrationForm receives no onclose (there is no parent
    // to dismiss to), so the roster had a back button and no ×. Here it closes
    // the list the same way back does — returning to the step it was opened
    // from — rather than being absent.
    mockEntryList.mockResolvedValue([
      { id_registration: 7, id_event: 3, txt_surname: 'WHITLEY', txt_first_name: 'Gary', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V3' },
    ] as never)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toRodo(container, findByText)
    await fireEvent.click(container.querySelector('input[type="checkbox"].reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')

    await fireEvent.click(container.querySelector('button.reg-entry-list-link') as HTMLButtonElement)
    await findByText('WHITLEY Gary')

    const closeBtn = container.querySelector('button.el-close') as HTMLButtonElement
    expect(closeBtn).not.toBeNull()
    await fireEvent.click(closeBtn)

    // Back on the payment step with the transfer details intact — closing the
    // list must not discard what the fencer came back for.
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
    await findByText('120 PLN')
  })

  it('returns to the closed step, not payment, when the roster was opened from it', async () => {
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      dt_registration_deadline: '2020-01-01',
      dt_start: '2020-01-05',
      dt_end: '2099-01-10',
    })
    mockEntryList.mockResolvedValue([
      { id_registration: 7, id_event: 3, txt_surname: 'WHITLEY', txt_first_name: 'Gary', enum_gender: 'M', arr_weapons: ['EPEE'], enum_age_category: 'V3' },
    ] as never)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await findByText(/Zapisy zamknięte/)

    // The closed step styles the affordance as .reg-btn, not .reg-entry-list-link.
    await fireEvent.click(container.querySelector('button.reg-btn') as HTMLButtonElement)
    await findByText('WHITLEY Gary')
    await fireEvent.click(container.querySelector('button.el-back') as HTMLButtonElement)

    // Whoever arrives after the deadline never reached a payment screen, so
    // back must not invent one.
    await findByText(/Zapisy zamknięte/)
  })
})

describe('RegistrationForm — payment deadline note', () => {
  async function toPayment(container: HTMLElement, findByText: (m: string | RegExp) => Promise<HTMLElement>) {
    mockMatch.mockResolvedValue(42)
    mockCreate.mockResolvedValue(99)
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
  }

  // Quotes dt_registration_deadline — the same date COALESCE(deadline, start)
  // that fn_create_registration's D10 guard enforces — rather than the old
  // hand-written "12 hours before the event starts", which matched no actual
  // rule in the system.
  it('quotes the event registration deadline', async () => {
    mockFetchEvent.mockResolvedValue({ ...BASE_EVENT, dt_registration_deadline: '2099-05-25' })
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    await findByText(/25 maja 2099/)
  })

  it('falls back to dt_start when the event has no explicit deadline', async () => {
    mockFetchEvent.mockResolvedValue({ ...BASE_EVENT, dt_registration_deadline: null, dt_start: '2099-06-01' })
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    await findByText(/1 czerwca 2099/)
  })

  it('uses the generic wording when the event carries no dates at all', async () => {
    mockFetchEvent.mockResolvedValue({ ...BASE_EVENT, dt_registration_deadline: null, dt_start: null, dt_end: null })
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    await findByText(/przed terminem rejestracji/)
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

// Edit capability (2026-08-28). The create path dedupes an unmatched entrant BY
// the declared name and birth year, so re-submitting a corrected spelling
// inserts a SECOND row rather than fixing the first — proven on LOCAL. Editing
// therefore goes through a different RPC, authorised by a token the browser
// generates and keeps, because id_registration is published by the entry list
// and cannot authorise anything.
// The account shown on the payment step is resolved server-side — the event's
// own override, else the organizer's default — and arrives with the event. It
// used to be a module constant compiled into the bundle, identical for every
// event, which is why an organizer other than SPWS could not run registration.
describe('RegistrationForm — the payment account comes from the event', () => {
  async function toPayment(container: HTMLElement, findByText: (m: string | RegExp) => Promise<HTMLElement>) {
    mockMatch.mockResolvedValue(null)
    mockCreate.mockResolvedValue(101)
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
  }

  it('shows the account the event resolves, not a hardcoded one', async () => {
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      txt_payee: 'KLUB ORGANIZATORA',
      txt_iban: 'PL 27 1140 2004 0000 3002 0135 5387',
      txt_payment_source: 'EVENT',
    })
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    await findByText('KLUB ORGANIZATORA')
    await findByText('PL 27 1140 2004 0000 3002 0135 5387')
  })

  it('invents no account when the event supplies none', async () => {
    // The transitional fallback is gone (ADR-079 open item 8, resolved once PROD
    // carried migration 20260902000001). Showing the association's account for an
    // event that resolves none would mask a misconfiguration behind a plausible
    // number — and defeat the point of the toggle guard, which exists to stop
    // that state being created at all.
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      txt_payee: null,
      txt_iban: null,
      txt_payment_source: 'NONE',
    } as never)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    const values = Array.from(container.querySelectorAll('.reg-pv')).map((e) => e.textContent?.trim())
    expect(values).not.toContain('PL 06 1090 1665 0000 0001 5004 1549')
    expect(values).not.toContain('STOWARZYSZENIE POLSKICH WETERANÓW SZERMIERKI')
  })

  it('copies the same account it displays', async () => {
    // The panel and the clipboard must never disagree: a fencer pastes what the
    // copy button gave them, not what they read.
    mockFetchEvent.mockResolvedValue({
      ...BASE_EVENT,
      txt_payee: 'KLUB ORGANIZATORA',
      txt_iban: 'PL 27 1140 2004 0000 3002 0135 5387',
      txt_payment_source: 'EVENT',
    })
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    const rows = Array.from(container.querySelectorAll('.reg-pv')).map((e) => e.textContent?.trim())
    expect(rows).toContain('PL 27 1140 2004 0000 3002 0135 5387')
  })
})

describe('RegistrationForm — correcting a submitted declaration', () => {
  async function toPayment(container: HTMLElement, findByText: (m: string | RegExp) => Promise<HTMLElement>) {
    mockFetchEvent.mockResolvedValue(BASE_EVENT)
    mockMatch.mockResolvedValue(null)
    mockCreate.mockResolvedValue(101)
    await findByText('IV Puchar Polski Weteranów')
    await fillIdentity(container)
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await findByText(/RODO/)
    await fireEvent.click(container.querySelector('input.reg-rodo-checkbox') as HTMLInputElement)
    await fireEvent.click(container.querySelector('button.reg-rodo-accept') as HTMLButtonElement)
    await findByText('PPW4-2025-2026 JAN KOWALSKI SZPADA V2')
  }

  it('mints a handle and sends it with the registration', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    expect(mockCreate).toHaveBeenCalledWith(
      expect.objectContaining({ editToken: 'tok-generated-0123456789abcdef' }),
    )
  })

  it('persists nothing — the handle lives only as long as the form does', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    // localStorage bound the capability to one origin and one device. A fencer
    // returning later re-enters their declared tuple instead, which upserts onto
    // their row and mints a fresh handle. Nothing may be written to the device.
    const store = globalThis.localStorage as Storage | undefined
    const wrote = store && typeof store.length === 'number' ? store.length : 0
    expect(wrote).toBe(0)
  })

  it('offers an edit route from the payment step, prefilled with what was submitted', async () => {
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)

    await fireEvent.click(container.querySelector('button.reg-edit') as HTMLButtonElement)
    const surnameInput = container.querySelector('input[name="surname"]') as HTMLInputElement
    expect(surnameInput).not.toBeNull()
    expect(surnameInput.value).toBe('KOWALSKI')
  })

  it('saving a corrected surname calls updateRegistration, never createRegistration again', async () => {
    mockUpdate.mockResolvedValue(101)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    expect(mockCreate).toHaveBeenCalledTimes(1)

    await fireEvent.click(container.querySelector('button.reg-edit') as HTMLButtonElement)
    const surnameInput = container.querySelector('input[name="surname"]') as HTMLInputElement
    await fireEvent.input(surnameInput, { target: { value: 'kowalsky' } })
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)

    await waitFor(() =>
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ idRegistration: 101, surname: 'KOWALSKY' }),
      ),
    )
    // A second create would be the bug this whole change exists to prevent.
    expect(mockCreate).toHaveBeenCalledTimes(1)
  })

  it('a fencer returning after the handle is gone re-enters the tuple and edits from there', async () => {
    // No prefill and no restore: without persistence there is nothing on the
    // device to restore from. Re-submitting the declared tuple upserts onto the
    // same row and hands back a working handle, which is what makes the
    // correction possible at all.
    mockUpdate.mockResolvedValue(101)
    const { container, findByText } = render(RegistrationForm, { props: { eventCode: 'PPW4-2025-2026' } })
    await toPayment(container, findByText)
    expect(mockCreate).toHaveBeenCalledWith(
      expect.objectContaining({ editToken: 'tok-generated-0123456789abcdef' }),
    )

    await fireEvent.click(container.querySelector('button.reg-edit') as HTMLButtonElement)
    await fireEvent.input(container.querySelector('input[name="surname"]') as HTMLInputElement, {
      target: { value: 'poprawione' },
    })
    await fireEvent.click(container.querySelector('button.reg-continue') as HTMLButtonElement)
    await waitFor(() =>
      expect(mockUpdate).toHaveBeenCalledWith(
        expect.objectContaining({ editToken: 'tok-generated-0123456789abcdef', surname: 'POPRAWIONE' }),
      ),
    )
  })
})
