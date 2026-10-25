// LAYOUT.02 — Admin → Fencers → Aliases fits a phone (25 Oct 2026, T2 A on the W2 sign-off).
//
// jsdom has no layout engine, so the measurement itself is a real-browser check
// on LOCAL (doc/plans/w2-follow-up-2026-10-25.html § 2: page width 425 px
// at a 375 px viewport before, 375 after, an expanded fencer included). This
// contract pins the CSS that makes it so, and that the desktop rules stay outside
// the media query.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const source = readFileSync(join(__dirname, '../src/components/FencerAliasManager.svelte'), 'utf8')
const style = source.slice(source.indexOf('<style>'), source.indexOf('</style>'))

function mediaBlock(query: string): string {
  const at = style.indexOf(`@media ${query}`)
  if (at < 0) return ''
  let depth = 0
  for (let i = style.indexOf('{', at); i < style.length; i++) {
    if (style[i] === '{') depth++
    if (style[i] === '}' && --depth === 0) return style.slice(at, i + 1)
  }
  return ''
}

describe('LAYOUT.02 admin alias table on a phone', () => {
  const phone = mediaBlock('(max-width: 600px)')

  it('has a phone-only media query', () => {
    expect(phone).not.toBe('')
  })

  it('lets the columns shrink instead of widening the page', () => {
    expect(phone).toMatch(/\.col-meta\s*\{[^}]*width:\s*auto/)
    expect(phone).toMatch(/\.col-count\s*\{[^}]*width:\s*auto/)
    expect(phone).toMatch(/\.alias-table th,\s*\.alias-table td\s*\{[^}]*padding-left:\s*8px;\s*padding-right:\s*8px/)
  })

  it('wraps an expanded alias: the alias on its own line, the buttons below', () => {
    expect(phone).toMatch(/\.alias-row\s*\{[^}]*flex-wrap:\s*wrap/)
    expect(phone).toMatch(/\.alias-string\s*\{[^}]*flex-basis:\s*100%/)
    expect(phone).toMatch(/\.alias-detail-row td\s*\{[^}]*padding-left:\s*14px/)
  })

  it('leaves the desktop rules untouched', () => {
    const desktop = style.replace(phone, '')
    expect(desktop).toMatch(/\.col-count\s*\{\s*text-align:\s*right;\s*width:\s*90px;\s*\}/)
    expect(desktop).toMatch(/\.col-meta\s*\{\s*width:\s*200px;/)
    expect(desktop).toMatch(/\.alias-row\s*\{\s*display:\s*flex;\s*gap:\s*10px;\s*align-items:\s*center;/)
    expect(desktop).not.toMatch(/\.alias-row\s*\{[^}]*flex-wrap/)
  })
})
