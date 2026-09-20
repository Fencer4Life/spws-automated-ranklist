// SS26.UIHIST (design step 7, ADR-101) — scenario E of
// doc/plans/admin-public-ranking-ui-2026-09-20.html §09: a FULL-publication
// season shows the Ranking/PPW switch and defaults to Ranking; a PPW_ONLY
// season forces PPW and hides the switch; returning to a FULL season
// restores the switch and that season's own configured default.

import { test, expect } from '@playwright/test'

test.describe('Ranking/PPW publication boundary (SS26.UIHIST)', () => {
  test.beforeEach(async ({ page }) => {
    await page.goto('/index.ce.html')
  })

  function toggleGroup(page: import('@playwright/test').Page) {
    return page.evaluate(() => {
      const el = document.querySelector('spws-ranklist')
      const group = el?.shadowRoot?.querySelector('.toggle-group')
      const active = el?.shadowRoot?.querySelector('.filter-bar .toggle-btn.active')
      return {
        visible: group !== null && group !== undefined,
        activeLabel: active?.textContent ?? null,
        headerText: el?.shadowRoot?.querySelector('thead')?.textContent?.trim() ?? null,
      }
    })
  }

  async function selectSeason(page: import('@playwright/test').Page, value: string) {
    await page.evaluate((v) => {
      const el = document.querySelector('spws-ranklist')
      const select = el?.shadowRoot?.querySelector('.season-select') as HTMLSelectElement
      select.value = v
      select.dispatchEvent(new Event('change', { bubbles: true }))
    }, value)
  }

  test('FULL season (2024/25) shows the switch, defaulting to Ranking', async ({ page }) => {
    const state = await toggleGroup(page)
    expect(state.visible).toBe(true)
    expect(state.activeLabel).toBe('Ranking')
    expect(state.headerText).toContain('SPWS')
    expect(state.headerText).toContain('EVF+')
  })

  test('PPW_ONLY season (2023/24) hides the switch and forces PPW', async ({ page }) => {
    await selectSeason(page, '1')
    const state = await toggleGroup(page)
    expect(state.visible).toBe(false)
    expect(state.headerText).not.toContain('EVF+')
    expect(state.headerText).toContain('Punkty')
  })

  test('returning to a FULL season restores the switch and Ranking default', async ({ page }) => {
    await selectSeason(page, '1')
    await selectSeason(page, '2')
    const state = await toggleGroup(page)
    expect(state.visible).toBe(true)
    expect(state.activeLabel).toBe('Ranking')
    expect(state.headerText).toContain('SPWS')
    expect(state.headerText).toContain('EVF+')
  })

  test('the PPW/Ranking switch toggles columns within a FULL season', async ({ page }) => {
    await page.evaluate(() => {
      const el = document.querySelector('spws-ranklist')
      const buttons = [...(el?.shadowRoot?.querySelectorAll('.filter-bar .toggle-btn') ?? [])]
      ;(buttons.find((b) => b.textContent === 'PPW') as HTMLButtonElement)?.click()
    })
    const ppwState = await toggleGroup(page)
    expect(ppwState.activeLabel).toBe('PPW')
    expect(ppwState.headerText).not.toContain('EVF+')
    expect(ppwState.headerText).toContain('Punkty')
  })
})
