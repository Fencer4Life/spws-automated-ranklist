// FOLD.01–05 — FR-165. Plan: doc/plans/entry-list-tiles-follow-filters-tdd-plan-2026-11-17.html §04.
//
// The entry list's name search compares folded text on both sides, so a
// visitor without Polish keys finds ŻAK by typing "zak". The rule is the one
// python/matcher/fuzzy_match.py fold_diacritics already applies: ł/Ł by hand
// (NFD does not decompose them), then every combining mark stripped. Unlike
// the Python function this one also lower-cases, because its only use is a
// case-insensitive comparison.

import { describe, it, expect } from 'vitest'
import { foldName } from '../src/lib/foldName'

describe('foldName', () => {
  // FOLD.01
  it('folds every Polish letter to its base letter', () => {
    expect(foldName('ą ć ę ł ń ó ś ź ż')).toBe('a c e l n o s z z')
  })

  // FOLD.02
  it('folds upper-case Polish letters and lower-cases the result', () => {
    expect(foldName('ŻAK')).toBe('zak')
    expect(foldName('ŁOŚ')).toBe('los')
    expect(foldName('ĆWIK')).toBe('cwik')
    expect(foldName('ĄĘŃÓŹ')).toBe('aenoz')
  })

  // FOLD.03
  it('leaves plain letters, digits, spaces and hyphens alone apart from case', () => {
    expect(foldName('Kowalski-Nowak Jan 2')).toBe('kowalski-nowak jan 2')
    expect(foldName('')).toBe('')
  })

  // FOLD.04
  it('strips the marks of other accented Latin letters, as the Python fold does', () => {
    expect(foldName('Müller')).toBe('muller')
    expect(foldName('Hervé')).toBe('herve')
    expect(foldName('Čapek')).toBe('capek')
  })

  // FOLD.05
  it('folds text that arrives decomposed the same as the composed letter', () => {
    const decomposed = 'ŻAK' // Z followed by a combining dot above
    expect(decomposed).not.toBe('ŻAK')
    expect(foldName(decomposed)).toBe(foldName('ŻAK'))
  })
})
