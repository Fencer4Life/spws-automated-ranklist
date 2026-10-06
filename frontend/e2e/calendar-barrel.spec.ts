// CB.E1–CB.E5 — the calendar drum in a real browser, against the custom-element
// build WordPress loads. ADR-084 amendment 2026-10-06; FR-153.
// Plan: doc/plans/kalendarz-beben-strzalki-plan-2026-10-06.html §06.
//
// jsdom lays nothing out and projects nothing, so where things are DRAWN — which
// month is above, whether a button covers a tile — can only be measured here.
// Demo mode loads no calendar events, so the calendar request is stubbed with
// page.route, and the date is fixed so the opening month never drifts.

import { test, expect, type Page } from '@playwright/test'

const TODAY = '2026-10-06T10:00:00'

type Ev = [code: string, start: string, city: string]

function row([code, start, city]: Ev, i: number) {
  const season = `SPWS-${code.slice(-9)}`
  return {
    id_event: i + 1, txt_code: code, txt_name: code, id_season: 1, txt_season_code: season,
    id_organizer: null, txt_organizer_name: null, txt_location: city || null, txt_country: null,
    txt_venue_address: null, url_invitation: null, num_entry_fee: null, txt_entry_fee_currency: null,
    dt_start: start, dt_end: start, arr_weapons: ['EPEE', 'FOIL', 'SABRE'], url_event: null,
    enum_status: start < TODAY ? 'COMPLETED' : 'PLANNED', num_tournaments: 1,
    bool_has_international: !/^PPW|^MPW/.test(code), url_registration: null, dt_registration_deadline: null,
    url_event_2: null, url_event_3: null, url_event_4: null, url_event_5: null,
  }
}

/** The live pool around the opening month (PROD, 6 Oct 2026), quiet summer included. */
const POOL: Ev[] = [
  ['PEW8es-2025-2026', '2026-05-02', 'Chania'], ['DMEW-2025-2026', '2026-05-14', ''], ['PEW9efs-2025-2026', '2026-05-30', 'Dublin'],
  ['MPW-2025-2026', '2026-06-20', 'Warszawa'],
  ['PEW0efs-2026-2027', '2026-09-12', 'Samorin'], ['PEW1f-2026-2027', '2026-09-19', 'Buda'], ['PPW1-2026-2027', '2026-09-26', 'Opole'],
  ['MSW-2026-2027', '2026-10-09', 'Tbilisi'], ['PEW2es-2026-2027', '2026-10-31', ''],
  ['PEW3ef-2026-2027', '2026-11-14', 'Budapeszt'], ['PEW4fs-2026-2027', '2026-11-28', ''],
  ['PEW5efs-2026-2027', '2026-12-12', 'Łomianki'],
  ['PEW6efs-2027-2028', '2027-01-09', 'Guildford'], ['PEW7es-2027-2028', '2027-01-23', ''], ['PEW8efs-2027-2028', '2027-01-30', ''],
]

/** Eight events in each month either side of the opening month. */
const CROWDED: Ev[] = [
  ...Array.from({ length: 8 }, (_, i): Ev => [`PEW${i + 1}e-2026-2027`, `2026-09-${String(i + 2).padStart(2, '0')}`, '']),
  ['MSW-2026-2027', '2026-10-09', 'Tbilisi'],
  ...Array.from({ length: 8 }, (_, i): Ev => [`PEW${i + 11}f-2026-2027`, `2026-11-${String(i + 2).padStart(2, '0')}`, '']),
]

async function mountCalendar(page: Page, pool: Ev[], width: number, lang: 'pl' | 'en' = 'pl') {
  await page.clock.setFixedTime(new Date(TODAY))
  await page.route('http://stub.local/**', (route) => {
    const url = route.request().url()
    const body = url.includes('/rest/v1/vw_calendar') ? pool.map(row) : url.includes('/rpc/') ? null : []
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(body) })
  })
  await page.setViewportSize({ width, height: 800 })
  await page.goto('/index.ce.html')
  await page.evaluate(() => {
    document.documentElement.style.margin = '0'
    document.body.style.margin = '0'
    document.body.replaceChildren()
    const el = document.createElement('spws-calendar')
    for (const [k, v] of Object.entries({
      chrome: 'site', 'supabase-prod-url': 'http://stub.local', 'supabase-prod-key': 'stub',
      'href-home': 'https://weteraniszermierki.pl/', 'href-calendar': '/znajdz-zawody/',
    })) el.setAttribute(k, v)
    document.body.appendChild(el)
  })
  await expect(page.locator('spws-calendar .ln.mid .p').first()).toBeVisible()
  if (lang === 'en') await page.locator('spws-calendar .lang-btn[aria-label="English"]').click()
  await page.waitForTimeout(700)
}

async function press(page: Page, which: 'prev' | 'next') {
  await page.locator(`spws-calendar .stp.${which}`).click()
  await page.waitForTimeout(700) // the 0.42 s turn and the row fade
}

const midLabel = (page: Page) => page.locator('spws-calendar .ln.mid .sm b').textContent()

type Box = { x: number; y: number; w: number; h: number; what: string }

/** What is drawn and could be covered, each box cut to what is actually visible. */
async function drawn(page: Page) {
  return page.locator('spws-calendar').evaluate((host) => {
    const root = host.shadowRoot!
    const rect = (el: Element) => el.getBoundingClientRect()
    const cut = (r: DOMRect, c: DOMRect) => {
      const x = Math.max(r.left, c.left), y = Math.max(r.top, c.top)
      const w = Math.min(r.right, c.right) - x, h = Math.min(r.bottom, c.bottom) - y
      return w > 0 && h > 0 ? { x, y, w, h } : null
    }
    const vp = rect(root.querySelector('.vp')!)
    const boxes: { x: number; y: number; w: number; h: number; what: string }[] = []
    for (const ln of root.querySelectorAll('.ln.up, .ln.mid, .ln.dn')) {
      const clip = rect(ln.querySelector('.rw')!)
      for (const p of ln.querySelectorAll('.p')) {
        const visible = cut(rect(p), clip)
        const inVp = visible && cut(new DOMRect(visible.x, visible.y, visible.w, visible.h), vp)
        if (inVp) boxes.push({ ...inVp, what: `tile ${p.querySelector('.cdc')?.textContent} (${ln.className})` })
      }
      const seam = ln.querySelector('.sm b')!
      const s = cut(rect(seam), vp)
      if (s && seam.textContent) boxes.push({ ...s, what: `seam "${seam.textContent}"` })
    }
    const jmp = root.querySelector('.jmp')
    if (jmp) { const j = cut(rect(jmp), vp); if (j) boxes.push({ ...j, what: 'jump control' }) }
    const buttons = [...root.querySelectorAll('.stp')].map((b) => {
      const r = rect(b.querySelector('span')!)
      return { x: r.x, y: r.y, w: r.width, h: r.height, what: b.className }
    })
    return { boxes, buttons }
  })
}

const overlaps = (a: Box, b: Box) => a.x < b.x + b.w && b.x < a.x + a.w && a.y < b.y + b.h && b.y < a.y + a.h

test.describe('CB.E1 — the buttons cover nothing', () => {
  for (const width of [320, 375, 1280]) {
    for (const lang of ['pl', 'en'] as const) {
      test(`${width} px, ${lang.toUpperCase()}: at the opening month, with the control above and pinned below`, async ({ page }) => {
        await mountCalendar(page, POOL, width, lang)
        const check = async (state: string) => {
          const { boxes, buttons } = await drawn(page)
          expect(buttons.length, `${state}: both buttons`).toBe(2)
          for (const b of buttons) {
            const hits = boxes.filter((x) => overlaps(b, x)).map((x) => x.what)
            expect(hits, `${state}: ${b.what} covers`).toEqual([])
          }
        }
        await check('opening')
        await press(page, 'next')
        await press(page, 'next')
        await expect(page.locator('spws-calendar .jmp:not(.pinned)')).toHaveCount(1)
        await check('two later, control on the upper seam')
        await press(page, 'prev')
        await press(page, 'prev')
        await press(page, 'prev')
        await press(page, 'prev')
        await expect(page.locator('spws-calendar .jmp.pinned')).toHaveCount(1)
        await check('two earlier, control pinned below')
      })
    }
  }
})

test.describe('CB.E2 — earlier months above, later below, on screen', () => {
  test('the month drawn above the focus is the previous one; below, the next', async ({ page }) => {
    await mountCalendar(page, POOL, 375)
    const rows = await page.locator('spws-calendar').evaluate((host) => {
      const root = host.shadowRoot!
      const at = (sel: string) => {
        const ln = root.querySelector(sel)!
        const r = ln.getBoundingClientRect()
        return { y: r.top + r.height / 2, label: ln.querySelector('.sm b')!.textContent }
      }
      return { up: at('.ln.up'), mid: at('.ln.mid'), dn: at('.ln.dn') }
    })
    expect(rows.mid.label).toBe('Październik 2026')
    expect(rows.up.label).toBe('Wrzesień 2026')
    expect(rows.dn.label).toBe('Listopad 2026')
    expect(rows.up.y).toBeLessThan(rows.mid.y)
    expect(rows.mid.y).toBeLessThan(rows.dn.y)
  })
})

test.describe('CB.E3 — ▼ then ▲ returns', () => {
  test('to the same month, and ▲ then ▼ too, across the quiet summer', async ({ page }) => {
    await mountCalendar(page, POOL, 375)
    expect(await midLabel(page)).toBe('Październik 2026')
    await press(page, 'next')
    expect(await midLabel(page)).toBe('Listopad 2026')
    await press(page, 'prev')
    expect(await midLabel(page)).toBe('Październik 2026')
    await press(page, 'prev')
    await press(page, 'prev') // July and August are empty: the drum skips them
    expect(await midLabel(page)).toBe('Czerwiec 2026')
    await press(page, 'next')
    expect(await midLabel(page)).toBe('Wrzesień 2026')
  })
})

test.describe('CB.E4 — a crowded neighbouring month stops before the buttons', () => {
  // A 288 px drum is github.io at 320 px; 300 px is WordPress at 320 px.
  for (const drum of [288, 300]) {
    test(`eight events above and below, on a ${drum} px drum`, async ({ page }) => {
      await mountCalendar(page, CROWDED, drum + 20) // the page's 10 px padding each side
      const vpWidth = await page.locator('spws-calendar .vp').evaluate((el) => el.getBoundingClientRect().width)
      expect(vpWidth).toBe(drum)
      const { boxes, buttons } = await drawn(page)
      expect(buttons.length).toBe(2)
      const neighbours = boxes.filter((b) => b.what.startsWith('tile') && !b.what.includes('mid'))
      expect(neighbours.length, 'the crowded months are drawn').toBeGreaterThan(6)
      for (const b of buttons) {
        const hitBoxLeft = b.x - 3 // the 30 px disc sits in a 36 px hit box
        for (const tile of neighbours) {
          if (tile.y + tile.h <= b.y || b.y + b.h <= tile.y) continue
          expect(tile.x + tile.w, `${tile.what} beside ${b.what}`).toBeLessThanOrEqual(hitBoxLeft)
        }
      }
    })
  }
})

test.describe('CB.E5 — ▲ and ▼ sit at the drum’s right edge at every width', () => {
  // The user's rule (6 Oct 2026): the buttons align to the drum's RIGHT side.
  // The mock's 300 px cap kept them by the tiles on a wide drum, so from 375 px
  // up they stood off the right edge, and on a computer they read as centred.
  for (const width of [320, 375, 414, 768, 1280]) {
    test(`${width} px`, async ({ page }) => {
      await mountCalendar(page, POOL, width)
      const { vpRight, rights } = await page.locator('spws-calendar').evaluate((host) => {
        const root = host.shadowRoot!
        return {
          vpRight: root.querySelector('.vp')!.getBoundingClientRect().right,
          rights: [...root.querySelectorAll('.stp')].map((b) => b.getBoundingClientRect().right),
        }
      })
      expect(rights.length, 'both buttons are drawn').toBe(2)
      for (const right of rights) expect(Math.abs(vpRight - right), `right edge ${right} vs drum ${vpRight}`).toBeLessThanOrEqual(0.5)
    })
  }
})
