// t()/tIn() fill every occurrence of a placeholder, not only the first (I38):
// FR-176's missing-tier note names its number of weapons twice.
import { describe, it, expect } from 'vitest'
import { tIn } from '../src/lib/locale.svelte'

describe('I38 — a placeholder used twice is filled twice', () => {
  it('rev_note_missing names the weapons twice', () => {
    expect(tIn('pl', 'rev_note_missing', { n: 2, count: 5 }))
      .toBe('Brak ceny za 2 bronie w ustawieniach wydarzenia: przyjęto 2 × opłata za 1 broń (zgłoszeń: 5).')
    expect(tIn('en', 'rev_note_missing', { n: 3, count: 1 }))
      .toBe('No price for 3 weapons in the event settings: taken as 3 × the 1-weapon fee (entries: 1).')
  })
})
