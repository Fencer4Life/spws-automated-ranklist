// UX.LANG (doc/mockups/ranklist-controls-ux-2026-10-01.html, approved A):
// the language switch keeps its flags, drawn as the calendar's round
// CountryFlag images instead of emoji — Windows renders emoji flags as the
// letters "GB" and "PL".

import { describe, it, expect, beforeEach } from 'vitest'
import { render, fireEvent } from '@testing-library/svelte'
import LangToggle from '../src/components/LangToggle.svelte'
import { setLocale, getLocale } from '../src/lib/locale.svelte'

const buttons = (c: HTMLElement) => Array.from(c.querySelectorAll<HTMLButtonElement>('.lang-toggle button'))

describe('LangToggle', () => {
  beforeEach(() => {
    setLocale('pl')
  })

  it('UX.LANG.01 — two round flag images, English then Polski; no emoji flags', () => {
    const { container } = render(LangToggle)
    const btns = buttons(container)
    expect(btns.map((b) => b.getAttribute('aria-label'))).toEqual(['English', 'Polski'])
    expect(btns.every((b) => b.querySelector('.flag svg') !== null)).toBe(true)
    expect(container.textContent).not.toMatch(/🇬🇧|🇵🇱/u)
  })

  it('UX.LANG.02 — the active language is pressed, and a flag switches the language', async () => {
    const { container } = render(LangToggle)
    const [en, pl] = buttons(container)
    expect(pl.getAttribute('aria-pressed')).toBe('true')
    expect(en.getAttribute('aria-pressed')).toBe('false')
    await fireEvent.click(en)
    expect(getLocale()).toBe('en')
    expect(en.getAttribute('aria-pressed')).toBe('true')
    expect(pl.getAttribute('aria-pressed')).toBe('false')
  })
})
