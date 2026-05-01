// Plan tests: 8.55, 8.56, 8.57, 8.58, 8.59, 8.60, 8.61
// See doc/archive/m8_implementation_plan.md §T8.7.

import { test, expect } from '@playwright/test'

test.describe('Shadow DOM Custom Elements (T8.7)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.ce.html')
  })

  // 8.55 — <spws-ranklist> registered in CustomElementRegistry
  test('spws-ranklist is registered as custom element', async ({ page }) => {
    const defined = await page.evaluate(() =>
      customElements.get('spws-ranklist') !== undefined,
    )
    expect(defined).toBe(true)
  })

  // 8.56 — <spws-calendar> registered in CustomElementRegistry
  test('spws-calendar is registered as custom element', async ({ page }) => {
    const defined = await page.evaluate(() =>
      customElements.get('spws-calendar') !== undefined,
    )
    expect(defined).toBe(true)
  })

  // 8.57 — <spws-ranklist> has non-null shadowRoot
  test('spws-ranklist has shadow root', async ({ page }) => {
    const hasShadow = await page.evaluate(() => {
      const el = document.querySelector('spws-ranklist')
      return el?.shadowRoot !== null && el?.shadowRoot !== undefined
    })
    expect(hasShadow).toBe(true)
  })

  // 8.58 — <spws-calendar> has non-null shadowRoot
  test('spws-calendar has shadow root', async ({ page }) => {
    const hasShadow = await page.evaluate(() => {
      const el = document.querySelector('spws-calendar')
      return el?.shadowRoot !== null && el?.shadowRoot !== undefined
    })
    expect(hasShadow).toBe(true)
  })

  // 8.59 — Host page CSS does not leak into Shadow DOM
  test('host page CSS does not leak into shadow DOM', async ({ page }) => {
    // Add a global style that would affect h2 elements
    await page.evaluate(() => {
      const style = document.createElement('style')
      style.textContent = 'h2 { color: rgb(255, 0, 0) !important; }'
      document.head.appendChild(style)
    })
    // Check that h2 inside shadow DOM is NOT red
    const color = await page.evaluate(() => {
      const el = document.querySelector('spws-ranklist')
      const h2 = el?.shadowRoot?.querySelector('h2')
      if (!h2) return null
      return getComputedStyle(h2).color
    })
    // color should NOT be red (rgb(255, 0, 0))
    if (color !== null) {
      expect(color).not.toBe('rgb(255, 0, 0)')
    }
  })

  // 8.60 — <spws-ranklist demo> renders ranklist table
  test('spws-ranklist demo renders ranklist table', async ({ page }) => {
    const hasTable = await page.evaluate(() => {
      const el = document.querySelector('spws-ranklist')
      const table = el?.shadowRoot?.querySelector('table')
      return table !== null && table !== undefined
    })
    expect(hasTable).toBe(true)
  })

  // 8.61 — <spws-calendar demo> renders calendar view
  test('spws-calendar demo renders calendar view', async ({ page }) => {
    const hasCalendar = await page.evaluate(() => {
      const el = document.querySelector('spws-calendar')
      const root = el?.shadowRoot
      // Calendar should have filter buttons or event cards
      const content = root?.querySelector('.calendar-view') || root?.querySelector('.calendar-filters')
      return content !== null && content !== undefined
    })
    expect(hasCalendar).toBe(true)
  })
})
