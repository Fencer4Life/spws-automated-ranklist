// LOCAL walk-through of FR-166 (plan §06 step 3). LOCAL only: the Docker Supabase stack at
// 127.0.0.1:54321, the app built from the worktree and served at http://localhost:5199 by route().
// usage: node local-walkthrough.cjs <frontend dir (absolute)> <built app dir> <out dir> <reset-dev.sh path>
// 1. As a visitor, a throwaway entry is made through the real registration form.
// 2. The visitor's entry list shows no „Usuń”.
// 3. Signed in as the LOCAL test administrator (from scripts/reset-dev.sh), the entry list shows
//    „Usuń”; the throwaway entry is found by search, confirmed and removed.
// The caller checks the database afterwards. Nothing outside LOCAL is contacted.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const DIST = process.argv[3]
const OUT = process.argv[4]
const RESET = fs.readFileSync(process.argv[5], 'utf8')
const ADMIN_EMAIL = RESET.match(/^ADMIN_EMAIL="([^"]+)"/m)[1]
const ADMIN_PASSWORD = RESET.match(/^ADMIN_PASSWORD="([^"]+)"/m)[1]
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://localhost:5199'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2' }
const SURNAME = 'ZZWALKUSUN'
const FIRST = 'Ewa'

async function page(b) {
  const p = await b.newPage({ viewport: { width: 1280, height: 1000 } })
  p.on('pageerror', (e) => console.log('PAGE ERROR', e.message))
  await p.route(`${BASE}/**`, (route) => {
    let file = path.join(DIST, decodeURIComponent(new URL(route.request().url()).pathname))
    if (fs.existsSync(file) && fs.statSync(file).isDirectory()) file = path.join(file, 'index.html')
    if (!file.startsWith(DIST) || !fs.existsSync(file)) return route.fulfill({ status: 404, body: 'not in build' })
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
  // Nothing but the build and LOCAL is reachable.
  await p.route(/^https?:\/\/(?!localhost:5199|127\.0\.0\.1:54321)/, (route) => route.abort())
  return p
}

async function toCalendarCard(p) {
  await p.locator('.hamburger-btn').click()
  await p.locator('.nav-item', { hasText: /Znajdź zawody|Competition Finder/ }).first().click()
  await p.locator('.ln.mid').first().waitFor({ timeout: 30000 })
  for (let i = 0; i < 8 && !(await p.locator('.ln.mid').first().innerText()).includes('Łomianki'); i++) {
    await p.locator('.stp.next').first().click()
    await p.waitForTimeout(600)
  }
  await p.locator('.ln.mid button.p', { hasText: 'Łomianki' }).first().evaluate((el) => el.click())
  await p.waitForTimeout(400)
}

;(async () => {
  // The page is answered by route(), so Chromium's local-network-access check
  // does not treat it as a local origin and refuses its requests to the LOCAL
  // database at 127.0.0.1. A test-browser setting only.
  const b = await chromium.launch({
    args: ['--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessSendPreflights,BlockInsecurePrivateNetworkRequests'],
  })

  // 1 — a visitor registers a throwaway entry through the form.
  const v = await page(b)
  await v.goto(`${BASE}/`)
  await toCalendarCard(v)
  await v.locator('.card .registration-link').first().evaluate((el) => el.click())
  const form = v.locator('.reg-card')
  await form.locator('input[name="surname"]').fill(SURNAME)
  await form.locator('input[name="firstName"]').fill(FIRST)
  await form.locator('select[name="gender"]').selectOption('F')
  await form.locator('input[name="birthYear"]').fill('1970')
  await form.locator('input[type="checkbox"][value="EPEE"]').check()
  await form.locator('button.reg-continue').first().click()
  await form.locator('button.reg-id-confirm').click({ timeout: 15000 })
  await form.locator('input.reg-rodo-checkbox').check()
  await form.locator('button.reg-rodo-accept').click()
  await form.locator('.reg-ok').waitFor({ timeout: 15000 })
  console.log('1 registered through the form:', (await form.locator('.reg-ok').innerText()).trim())
  await form.locator('button.reg-close').click().catch(() => {})

  // 2 — the visitor's entry list carries no remove control.
  await v.locator('.card .entry-list-link').first().evaluate((el) => el.click())
  await v.locator('td.el-name', { hasText: SURNAME }).waitFor({ timeout: 15000 })
  console.log('2 visitor sees the entry; remove buttons:', await v.locator('button.el-remove').count())
  await v.screenshot({ path: path.join(OUT, 'local-1-visitor-list.png') })
  await v.close()

  // 3 — the LOCAL administrator removes it.
  const a = await page(b)
  await a.goto(`${BASE}/?admin=1`)
  await a.locator('.admin-input').first().fill(ADMIN_EMAIL)
  await a.locator('.admin-input').nth(1).fill(ADMIN_PASSWORD)
  await a.locator('.admin-submit-btn').click()
  await a.locator('.admin-input').first().waitFor({ state: 'detached', timeout: 15000 })
  console.log('3 signed in as the LOCAL test administrator')
  await toCalendarCard(a)
  await a.locator('.card .entry-list-link').first().evaluate((el) => el.click())
  await a.locator('td.el-name').first().waitFor({ timeout: 15000 })
  const before = await a.locator('.el-metric .el-v').first().innerText()
  await a.locator('input[name="search"]').fill('zzwalk')
  const row = a.locator('tr', { has: a.locator('td.el-name', { hasText: SURNAME }) })
  console.log('3 admin: rows', await a.locator('tbody tr').count(), 'with „Usuń”:', await a.locator('button.el-remove').count(), 'first tile', before.trim())
  await row.locator('button.el-remove').click()
  const dialog = a.locator('[role="alertdialog"]')
  console.log('3 confirmation:', (await dialog.innerText()).replace(/\s+/g, ' ').trim())
  await a.screenshot({ path: path.join(OUT, 'local-2-admin-confirm.png') })
  await a.locator('button.el-remove-confirm').click()
  await a.locator('.el-remove-done').waitFor({ timeout: 15000 })
  console.log('3 done line:', (await a.locator('.el-remove-done').innerText()).trim())
  await a.locator('input[name="search"]').fill('')
  await a.waitForTimeout(300)
  console.log('3 first tile after:', (await a.locator('.el-metric .el-v').first().innerText()).trim(), '; rows with the name:', await a.locator('td.el-name', { hasText: SURNAME }).count())
  await a.screenshot({ path: path.join(OUT, 'local-3-admin-done.png') })
  await a.close()
  await b.close()
})()
