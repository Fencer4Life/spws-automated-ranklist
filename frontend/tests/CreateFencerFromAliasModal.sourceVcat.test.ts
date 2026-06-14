// Plan-test-ID 5.18.5 — modal prefers SOURCE V-cat over destination V-cat,
// renders the source-bracket URL when supplied.
//
// Bug history (2026-05-03 GP3 triage): the modal pre-filled BY from
// `latest_category_hint` (stage-7 destination V-cat). For wrong-match
// rows that stage 7 misroutes to a different V-cat, the destination is
// wrong — the BY suggestion misled the operator. Fix: a new
// `sourceCategoryHint` prop, preferred over `categoryHint` when set.

import { describe, it, expect, vi } from 'vitest'
import { render } from '@testing-library/svelte'
import CreateFencerFromAliasModal from '../src/components/CreateFencerFromAliasModal.svelte'

describe('CreateFencerFromAliasModal — source V-cat (5.18.5)', () => {
  const baseProps = {
    open: true,
    alias: 'POJMAŃSKA Katarzyna',
    fromFencerId: 278,
    categoryHint: 'V0' as string | null,            // misroute destination
    sourceCategoryHint: 'V2' as string | null,      // actual source bracket
    seasonEndYear: 2024 as number | null,
    sourceBracketUrl: 'https://www.fencingtimelive.com/events/results/ABC' as string | null,
    onconfirm: vi.fn(),
    onclose: vi.fn(),
  }

  // 5.18.5.1 — when sourceCategoryHint is set, BY pre-fills from SOURCE,
  // not from categoryHint (destination).
  it('pre-fills BY from sourceCategoryHint (V2 → 1969), ignoring destination V0', () => {
    const { container } = render(CreateFencerFromAliasModal, { props: baseProps })
    const by = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    // V2 + season-end 2024 → suggested 1969 (midpoint anchor 55)
    expect(by.value).toBe('1969')
    // NOT 1989 (V0 midpoint estimate)
    expect(by.value).not.toBe('1989')
  })

  // 5.18.5.2 — falls back to categoryHint (destination) when source is null
  it('falls back to categoryHint when sourceCategoryHint is null (joint-pool with no source V-cat)', () => {
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, sourceCategoryHint: null, categoryHint: 'V1' },
    })
    const by = container.querySelector('[data-field="birth-year-input"]') as HTMLInputElement
    // V1 + 2024 → 1979 (midpoint anchor 45)
    expect(by.value).toBe('1979')
  })

  // 5.18.5.3 — renders a clickable link to sourceBracketUrl so the operator
  // can verify the V-cat on FTL before confirming
  it('renders a link to sourceBracketUrl', () => {
    const { container } = render(CreateFencerFromAliasModal, { props: baseProps })
    const link = container.querySelector(
      '[data-field="source-bracket-link"]',
    ) as HTMLAnchorElement | null
    expect(link).not.toBeNull()
    expect(link!.href).toBe(baseProps.sourceBracketUrl!)
    expect(link!.target).toBe('_blank')
  })

  // 5.18.5.4 — no link section when sourceBracketUrl is null
  it('omits the link section when sourceBracketUrl is null', () => {
    const { container } = render(CreateFencerFromAliasModal, {
      props: { ...baseProps, sourceBracketUrl: null },
    })
    expect(container.querySelector('[data-field="source-bracket-link"]')).toBeNull()
  })

  // 5.18.5.5 — hint shows source V-cat range, not destination
  it('hint text shows source V-cat range (V2: 1965–1974), not destination V0', () => {
    const { container } = render(CreateFencerFromAliasModal, { props: baseProps })
    const hint = container.querySelector('[data-field="by-hint"]') as HTMLElement
    expect(hint.textContent).toContain('1974')
    expect(hint.textContent).toContain('1965')
    expect(hint.textContent).toContain('V2')
    expect(hint.textContent).not.toContain('V0')
  })
})
