// PROD deployment step 1 — asset paths outside the site root.
// Plan: doc/plans/prod-deployment-wordpress-2026-09-05.html §05, §06 step 7.
//
// The organizer marks and the header mark are loaded as bare file names
// ('SPWS-logo.png'). They resolve on GitHub Pages because the app sits at the
// origin root; embedded at https://weteraniszermierki.pl/znajdz-zawody/ the
// browser resolves them against that path and they 404.
//
// A module-level base mirrors how initClient is already handled here: set once
// at element creation from a static attribute, read anywhere in the tree,
// without drilling a prop through CalendarView -> CalendarBarrel -> EventCard.

import { describe, it, expect, beforeEach } from 'vitest'
import { setAssetBase, assetUrl } from '../src/lib/assetBase'

describe('assetUrl', () => {
  beforeEach(() => { setAssetBase('') })

  // The Pages app passes no asset-base at all, and must keep emitting the
  // exact bare names it emits today.
  it('returns the bare name unchanged when no base is set', () => {
    expect(assetUrl('SPWS-logo.png')).toBe('SPWS-logo.png')
  })

  it('prefixes the base when one is set', () => {
    setAssetBase('https://spws.github.io/ranklist/')
    expect(assetUrl('SPWS-logo.png')).toBe('https://spws.github.io/ranklist/SPWS-logo.png')
  })

  // WordPress is hand-edited: a base pasted without its trailing slash must not
  // silently produce 'ranklistSPWS-logo.png'.
  it('tolerates a base with no trailing slash', () => {
    setAssetBase('https://spws.github.io/ranklist')
    expect(assetUrl('SPWS-logo.png')).toBe('https://spws.github.io/ranklist/SPWS-logo.png')
  })

  it('does not double the separator when the base ends in one', () => {
    setAssetBase('https://spws.github.io/ranklist/')
    expect(assetUrl('EVF-logo.png')).toBe('https://spws.github.io/ranklist/EVF-logo.png')
  })

  // Defensive: an already-absolute asset must not be rewritten onto the base.
  it('leaves an absolute URL alone', () => {
    setAssetBase('https://spws.github.io/ranklist/')
    expect(assetUrl('https://example.org/x.png')).toBe('https://example.org/x.png')
  })

  it('leaves a root-relative path alone', () => {
    setAssetBase('https://spws.github.io/ranklist/')
    expect(assetUrl('/x.png')).toBe('/x.png')
  })
})
