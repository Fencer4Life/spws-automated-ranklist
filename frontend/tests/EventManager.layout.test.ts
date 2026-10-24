// LAYOUT.01 — the admin event list fits a phone (24 Oct 2026).
//
// jsdom has no layout engine, so the measurement itself is a real-browser check
// on LOCAL (doc/plans/ftl-seed-email-removal-2026-10-24.html § 13: page width
// 694 px at a 375 px viewport before, 375 after). This contract pins the CSS
// that makes it so, and that desktop styles stay outside the media query.
import { readFileSync } from 'node:fs'
import { join } from 'node:path'
import { describe, expect, it } from 'vitest'

const source = readFileSync(join(__dirname, '../src/components/EventManager.svelte'), 'utf8')
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

describe('LAYOUT.01 admin event list on a phone', () => {
  const phone = mediaBlock('(max-width: 600px)')

  it('has a phone-only media query', () => {
    expect(phone).not.toBe('')
  })

  it('wraps the header and every row instead of widening the page', () => {
    expect(phone).toMatch(/\.event-header\s*\{[^}]*flex-wrap:\s*wrap/)
    expect(phone).toMatch(/\.event-row\s*\{[^}]*flex-wrap:\s*wrap/)
  })

  it('leaves the desktop rules untouched', () => {
    const desktop = style.replace(phone, '')
    expect(desktop).toMatch(/\.event-row\s*\{\s*display:\s*flex;\s*align-items:\s*center;\s*gap:\s*16px;/)
    expect(desktop).not.toMatch(/\.event-row\s*\{[^}]*flex-wrap/)
  })
})
