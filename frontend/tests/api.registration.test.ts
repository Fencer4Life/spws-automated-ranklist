// FR-122/FR-123/FR-124 — Phase 2 registration API client (ADR-079).
// Wires the already-shipped RPCs/view: fn_match_registration_fencer (exact-only
// form-side router — Path A vs email-verify; ADR-079 §2 impl note),
// fn_create_registration (sole public write path), vw_registration_entry_list
// (public roster, no BY/club). Mirrors tests/api.test.ts's mock-client style.

import { describe, it, expect, vi, beforeEach } from 'vitest'

const { mockRpc, mockFrom } = vi.hoisted(() => ({
  mockRpc: vi.fn(),
  mockFrom: vi.fn(),
}))

vi.mock('@supabase/supabase-js', () => ({
  createClient: vi.fn(() => ({ rpc: mockRpc, from: mockFrom })),
}))

import {
  initClient,
  matchRegistrationFencer,
  createRegistration,
  fetchEntryList,
  fetchEventForRegistration,
} from '../src/lib/api'

beforeEach(() => {
  vi.clearAllMocks()
  initClient('http://localhost:54321', 'test-key')
})

describe('matchRegistrationFencer (FR-124, exact-only form-side router)', () => {
  it('calls fn_match_registration_fencer with the exact tuple and returns the fencer id', async () => {
    mockRpc.mockResolvedValue({ data: 42, error: null })
    const id = await matchRegistrationFencer('KOWALSKI', 'Jan', 1970)
    expect(mockRpc).toHaveBeenCalledWith('fn_match_registration_fencer', {
      p_surname: 'KOWALSKI',
      p_first_name: 'Jan',
      p_birth_year: 1970,
    })
    expect(id).toBe(42)
  })

  it('returns null on no exact match (→ caller routes to email-verify path)', async () => {
    mockRpc.mockResolvedValue({ data: null, error: null })
    expect(await matchRegistrationFencer('NOWAK', 'Anna', 1999)).toBeNull()
  })

  it('throws on RPC error', async () => {
    mockRpc.mockResolvedValue({ data: null, error: { message: 'boom' } })
    await expect(matchRegistrationFencer('X', 'Y', 1980)).rejects.toThrow()
  })
})

describe('createRegistration (FR-122, sole public write path)', () => {
  it('calls fn_create_registration with mapped params and returns the new id', async () => {
    mockRpc.mockResolvedValue({ data: 7, error: null })
    const id = await createRegistration({
      eventId: 3,
      surname: 'KOWALSKI',
      firstName: 'Jan',
      gender: 'M',
      birthYear: 1970,
      weapons: ['EPEE', 'SABRE'],
    })
    expect(mockRpc).toHaveBeenCalledWith('fn_create_registration', {
      p_event: 3,
      p_surname: 'KOWALSKI',
      p_first_name: 'Jan',
      p_gender: 'M',
      p_birth_year: 1970,
      p_weapons: ['EPEE', 'SABRE'],
      p_id_fencer: null,
      p_email_hash: null,
      p_consent_version: null,
    })
    expect(id).toBe(7)
  })

  it('forwards an optional matched fencer id and email hash', async () => {
    mockRpc.mockResolvedValue({ data: 8, error: null })
    await createRegistration({
      eventId: 3,
      surname: 'KOWALSKI',
      firstName: 'Jan',
      gender: 'M',
      birthYear: 1970,
      weapons: ['EPEE'],
      fencerId: 42,
      emailHash: 'abc123',
    })
    expect(mockRpc).toHaveBeenCalledWith(
      'fn_create_registration',
      expect.objectContaining({ p_id_fencer: 42, p_email_hash: 'abc123' }),
    )
  })

  it('forwards consentVersion (D5 — RODO-accept write timing) as p_consent_version', async () => {
    mockRpc.mockResolvedValue({ data: 9, error: null })
    await createRegistration({
      eventId: 3,
      surname: 'KOWALSKI',
      firstName: 'Jan',
      gender: 'M',
      birthYear: 1970,
      weapons: ['EPEE'],
      fencerId: 42,
      consentVersion: 'v1.0',
    })
    expect(mockRpc).toHaveBeenCalledWith(
      'fn_create_registration',
      expect.objectContaining({ p_consent_version: 'v1.0' }),
    )
  })

  it('throws on RPC error', async () => {
    mockRpc.mockResolvedValue({ data: null, error: { message: 'denied' } })
    await expect(
      createRegistration({ eventId: 1, surname: 'A', firstName: 'B', gender: 'F', birthYear: 1980, weapons: ['FOIL'] }),
    ).rejects.toThrow()
  })
})

describe('fetchEntryList (FR-123, public roster)', () => {
  it('queries vw_registration_entry_list filtered by event', async () => {
    const rows = [
      { id_registration: 1, id_event: 3, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', enum_gender: 'M', arr_weapons: ['EPEE'] },
    ]
    const order = vi.fn().mockResolvedValue({ data: rows, error: null })
    const eq = vi.fn().mockReturnValue({ order })
    const select = vi.fn().mockReturnValue({ eq })
    mockFrom.mockReturnValue({ select })

    const result = await fetchEntryList(3)
    expect(mockFrom).toHaveBeenCalledWith('vw_registration_entry_list')
    expect(eq).toHaveBeenCalledWith('id_event', 3)
    expect(result).toEqual(rows)
  })

  it('throws on query error', async () => {
    const order = vi.fn().mockResolvedValue({ data: null, error: { message: 'nope' } })
    mockFrom.mockReturnValue({ select: vi.fn().mockReturnValue({ eq: vi.fn().mockReturnValue({ order }) }) })
    await expect(fetchEntryList(3)).rejects.toThrow()
  })
})

describe('fetchEventForRegistration (P2.2, D7 — standalone page resolves the event by code)', () => {
  it('queries vw_calendar by txt_code and returns the single row', async () => {
    const row = {
      id_event: 3,
      txt_code: 'PPW4-2025-2026',
      txt_name: 'IV Puchar Polski Weteranów',
      txt_season_code: 'SPWS-2025-2026',
      dt_start: '2026-06-01',
      dt_end: '2026-06-02',
      dt_registration_deadline: '2026-05-25',
      arr_weapons: ['EPEE', 'SABRE'],
      num_entry_fee: 120,
      num_entry_fee_2w: 200,
      num_entry_fee_3w: 260,
      bool_use_spws_registration: true,
      url_registration: null,
    }
    const single = vi.fn().mockResolvedValue({ data: row, error: null })
    const eq = vi.fn().mockReturnValue({ single })
    const select = vi.fn().mockReturnValue({ eq })
    mockFrom.mockReturnValue({ select })

    const result = await fetchEventForRegistration('PPW4-2025-2026')
    expect(mockFrom).toHaveBeenCalledWith('vw_calendar')
    expect(eq).toHaveBeenCalledWith('txt_code', 'PPW4-2025-2026')
    expect(result).toEqual(row)
  })

  it('returns null when the code does not resolve', async () => {
    const single = vi.fn().mockResolvedValue({ data: null, error: { message: 'not found' } })
    mockFrom.mockReturnValue({ select: vi.fn().mockReturnValue({ eq: vi.fn().mockReturnValue({ single }) }) })
    expect(await fetchEventForRegistration('NOPE')).toBeNull()
  })
})
