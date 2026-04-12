// Plan tests: 9.95, 9.96, 9.97, 9.98, 9.99
// ADR-035: Fencers View with Tabs

import { describe, it, expect, vi } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import FencerView from '../src/components/FencerView.svelte'
import type { MatchCandidate, FencerListItem } from '../src/lib/types'

const MOCK_CANDIDATES: MatchCandidate[] = [
  {
    id_match: 1, id_result: 10, txt_scraped_name: 'NOWAK Adam',
    id_fencer: 101, txt_fencer_name: 'NOWAK Adam', num_confidence: 78,
    enum_status: 'PENDING', txt_admin_note: null,
    txt_tournament_code: 'PP1-V1-M-FOIL', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
  {
    id_match: 2, id_result: 11, txt_scraped_name: 'AUTO Person',
    id_fencer: 102, txt_fencer_name: 'AUTO Person', num_confidence: 97,
    enum_status: 'AUTO_MATCHED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
  {
    id_match: 3, id_result: 12, txt_scraped_name: 'DONE Already',
    id_fencer: 103, txt_fencer_name: 'DONE Already', num_confidence: 100,
    enum_status: 'APPROVED', txt_admin_note: null,
    txt_tournament_code: 'PP1-V2-M-EPEE', enum_type: 'PPW',
    enum_tournament_gender: 'M', enum_fencer_gender: 'M',
  },
]

const MOCK_FENCERS: FencerListItem[] = [
  { id_fencer: 101, txt_surname: 'NOWAK', txt_first_name: 'Adam', int_birth_year: 1975, txt_club: null, enum_gender: 'M', bool_birth_year_estimated: true, txt_nationality: 'PL' },
  { id_fencer: 102, txt_surname: 'KOWALSKI', txt_first_name: 'Jan', int_birth_year: 1970, txt_club: 'WKS', enum_gender: 'M', bool_birth_year_estimated: false, txt_nationality: 'PL' },
  { id_fencer: 103, txt_surname: 'ZIELINSKA', txt_first_name: 'Anna', int_birth_year: null, txt_club: null, enum_gender: 'F', bool_birth_year_estimated: false, txt_nationality: 'PL' },
]

describe('FencerView (ADR-035)', () => {
  const defaultProps = {
    candidates: MOCK_CANDIDATES,
    fencers: MOCK_FENCERS,
    isAdmin: true,
    onapprove: vi.fn(),
    onassign: vi.fn(),
    oncreatenew: vi.fn(),
    ondismiss: vi.fn(),
    onundismiss: vi.fn(),
    onupdategender: vi.fn(),
    onupdatebirthyear: vi.fn(),
    onfetchhistory: vi.fn().mockResolvedValue([]),
  }

  // 9.95 — Renders tab bar + fencer count in header
  it('renders tab bar and fencer count in header', () => {
    const { container } = render(FencerView, { props: defaultProps })
    const view = container.querySelector('[data-field="fencer-view"]')
    expect(view).not.toBeNull()
    const tabBar = container.querySelector('[data-field="tab-bar"]')
    expect(tabBar).not.toBeNull()
    const count = container.querySelector('[data-field="fencer-count"]')
    expect(count).not.toBeNull()
    expect(count!.textContent).toContain('3')
  })

  // 9.96 — Default active tab is Identities
  it('default active tab is Identities', () => {
    const { container } = render(FencerView, { props: defaultProps })
    const identitiesTab = container.querySelector('[data-field="tab-identities"]')
    expect(identitiesTab).not.toBeNull()
    expect(identitiesTab!.classList.contains('active')).toBe(true)
    // IdentityManager content should be rendered
    const queue = container.querySelector('[data-field="identity-queue"]')
    expect(queue).not.toBeNull()
  })

  // 9.97 — Clicking Birth year review tab switches content
  it('clicking Birth year review tab switches content', async () => {
    const { container } = render(FencerView, { props: defaultProps })
    const byTab = container.querySelector('[data-field="tab-birth-year"]')!
    await fireEvent.click(byTab)
    expect(byTab.classList.contains('active')).toBe(true)
    const review = container.querySelector('[data-field="birth-year-review"]')
    expect(review).not.toBeNull()
    // IdentityManager tab should be hidden (CSS display:none), not removed from DOM
    const identitiesTab = container.querySelector('[data-field="tab-identities"]')
    expect(identitiesTab!.classList.contains('active')).toBe(false)
  })

  // 9.98 — Identities tab badge shows actionable count
  it('tab badge shows actionable candidate count', () => {
    const { container } = render(FencerView, { props: defaultProps })
    const badge = container.querySelector('[data-field="tab-badge-identities"]')
    expect(badge).not.toBeNull()
    // 2 actionable: 1 PENDING + 1 AUTO_MATCHED (APPROVED is not actionable)
    expect(badge!.textContent?.trim()).toBe('2')
  })

  // 9.99 — Birth year tab badge shows unconfirmed count
  it('tab badge shows unconfirmed birth year count', () => {
    const { container } = render(FencerView, { props: defaultProps })
    const badge = container.querySelector('[data-field="tab-badge-birth-year"]')
    expect(badge).not.toBeNull()
    // 2 unconfirmed: NOWAK (estimated) + ZIELINSKA (missing)
    expect(badge!.textContent?.trim()).toBe('2')
  })
})
