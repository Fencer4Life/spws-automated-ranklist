// FR-173 picture sheet: the registration form on register.html, before and after the name list.
// LOCAL only: the bundle is a local build, the event and the form's reads are LOCAL's. The name
// list's answers are invented here (no real person's name may reach a committed capture), so the
// list request never reaches a database; every other host is blocked.
//
// usage: node reg.cjs <frontend dir> <repo dir> <dist-ce dir> <out dir> <mode>
//   mode before — the empty form, and the form filled by typing (no list): desktop and phone, PL and EN
//   mode after  — the same two states, which must be identical to before, then the list open and
//                 the form right after a pick (year box focused, grid on the category's decade)
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [REPO, DIST, OUT, MODE] = process.argv.slice(3)
fs.mkdirSync(OUT, { recursive: true })
const BASE = 'http://localhost:5198'
const EVENT = 'PEW5efs-2026-2027'
const TYPES = { '.html': 'text/html', '.js': 'text/javascript', '.css': 'text/css', '.svg': 'image/svg+xml', '.png': 'image/png', '.json': 'application/json', '.woff2': 'font/woff2', '.webp': 'image/webp' }
const SOFT = ['--disable-gpu', '--disable-partial-raster', '--disable-skia-runtime-opts', '--force-color-profile=srgb',
  '--disable-lcd-text', '--font-render-hinting=none', '--force-device-scale-factor=1',
  '--disable-features=LocalNetworkAccessChecks,PrivateNetworkAccessSendPreflights,BlockInsecurePrivateNetworkRequests']
const WIDTHS = { desktop: [1280, 1000], phone: [375, 900] }

// register.html as the repository has it, loading the built bundle instead of the dev entry.
const PAGE = fs.readFileSync(path.join(REPO, 'frontend/register.html'), 'utf8')
  .replace('<script type="module" src="/src/main.ce.ts"></script>', '<script type="module" src="/assets/main.ce.js"></script>')
if (!PAGE.includes('/assets/main.ce.js')) throw new Error('register.html: the dev entry was not found')

// Invented people only. One is already entered, one comes from EVF, one from an earlier entry.
const ROWS = [
  { txt_surname: 'NOWAK', txt_first_name: 'Anna', enum_gender: 'F', txt_country: 'POL', enum_age_category: 'V1', txt_club: 'KS Przykład', txt_source: 'ROSTER', bool_entered: false },
  { txt_surname: 'NOWAK', txt_first_name: 'Jan', enum_gender: 'M', txt_country: 'POL', enum_age_category: 'V3', txt_club: null, txt_source: 'ROSTER', bool_entered: true },
  { txt_surname: 'NOWAKOWSKI', txt_first_name: 'Piotr', enum_gender: 'M', txt_country: 'POL', enum_age_category: 'V2', txt_club: null, txt_source: 'ROSTER', bool_entered: false },
  { txt_surname: 'NOVÁK', txt_first_name: 'Petr', enum_gender: 'M', txt_country: 'CZE', enum_age_category: 'V2', txt_club: null, txt_source: 'EVF', bool_entered: false },
  { txt_surname: 'NOWICKA', txt_first_name: 'Maria', enum_gender: 'F', txt_country: 'GER', enum_age_category: 'V4', txt_club: null, txt_source: 'ENTRY', bool_entered: false },
]

async function newPage(b, width, height) {
  const p = await b.newPage({ viewport: { width, height } })
  p.errs = []
  p.asked = []
  p.on('pageerror', (e) => p.errs.push(e.message))
  await p.route(/^https?:\/\/(?!localhost:5198|127\.0\.0\.1:54321)/, (route) => route.abort())
  await p.route('http://127.0.0.1:54321/rest/v1/rpc/fn_registration_name_suggestions', async (route) => {
    const body = JSON.parse(route.request().postData() || '{}')
    p.asked.push(body.p_typed)
    const rows = /^now/i.test(body.p_typed || '') ? ROWS : []
    return route.fulfill({ status: 200, contentType: 'application/json', body: JSON.stringify(rows) })
  })
  await p.route(`${BASE}/**`, (route) => {
    const u = new URL(route.request().url())
    if (u.pathname === '/register.html') return route.fulfill({ status: 200, contentType: 'text/html', body: PAGE })
    const file = path.join(DIST, decodeURIComponent(u.pathname))
    if (!file.startsWith(DIST) || !fs.existsSync(file) || fs.statSync(file).isDirectory()) return route.fulfill({ status: 404, body: 'not in build' })
    return route.fulfill({ status: 200, contentType: TYPES[path.extname(file)] || 'application/octet-stream', body: fs.readFileSync(file) })
  })
  return p
}

async function still(p) {
  await p.evaluate(() => {
    const root = document.querySelector('spws-registration').shadowRoot
    const s = document.createElement('style')
    s.textContent = '*,*::before,*::after{transition:none!important;animation:none!important;caret-color:transparent!important}'
    root.appendChild(s)
  })
}

async function openForm(b, width, height, lang) {
  const p = await newPage(b, width, height)
  await p.goto(`${BASE}/register.html?event=${EVENT}`)
  await p.locator('input[name="surname"]').waitFor({ timeout: 30000 })
  await still(p)
  if (lang === 'en') { await p.locator('.lang-btn[aria-label="English"]').first().click(); await p.waitForTimeout(500) }
  await p.waitForTimeout(400)
  return p
}

async function shot(p, name, width, height) {
  await p.mouse.move(width - 2, height - 2)
  await p.waitForTimeout(400)
  await p.screenshot({ path: path.join(OUT, name), fullPage: true })
}

async function typed(p) {
  await p.locator('input[name="surname"]').fill('ZZTYPED')
  await p.locator('input[name="firstName"]').fill('Ewa')
  await p.locator('select[name="gender"]').selectOption('F')
  await p.locator('input[name="birthYear"]').fill('1970')
  await p.locator('input[type="checkbox"][value="EPEE"]').check()
  await p.locator('.reg-stepline').first().click()
  await p.waitForTimeout(500)
}

;(async () => {
  const b = await chromium.launch({ args: SOFT })
  const report = []
  for (const [w, [width, height]] of Object.entries(WIDTHS)) {
    for (const lang of ['pl', 'en']) {
      const tag = `${w}__${lang}`
      let p = await openForm(b, width, height, lang)
      await shot(p, `1-empty__${tag}.png`, width, height)
      await typed(p)
      await shot(p, `2-typed__${tag}.png`, width, height)
      const facts = { tag, surnameAutocomplete: await p.locator('input[name="surname"]').getAttribute('autocomplete'), askedWhileTyping: [...p.asked], errors: p.errs }
      await p.close()

      if (MODE === 'after') {
        p = await openForm(b, width, height, lang)
        await p.locator('input[name="surname"]').pressSequentially('NOW', { delay: 30 })
        await p.locator('[role="option"]').first().waitFor({ timeout: 5000 })
        await p.waitForTimeout(300)
        await shot(p, `3-list__${tag}.png`, width, height)
        facts.rows = await p.locator('[role="option"]').allInnerTexts()
        await p.locator('[role="option"]').first().click()
        await p.waitForTimeout(500)
        await shot(p, `4-picked__${tag}.png`, width, height)
        facts.afterPick = {
          surname: await p.locator('input[name="surname"]').inputValue(),
          firstName: await p.locator('input[name="firstName"]').inputValue(),
          gender: await p.locator('select[name="gender"]').inputValue(),
          birthYear: await p.locator('input[name="birthYear"]').inputValue(),
          club: await p.locator('input[placeholder]').last().inputValue(),
          decade: (await p.locator('.reg-yeargrid-decade').innerText()).trim(),
          focus: await p.evaluate(() => document.querySelector('spws-registration').shadowRoot.activeElement?.getAttribute('name')),
          weaponsTicked: await p.locator('input[type="checkbox"]:checked').count(),
        }
        facts.errors = facts.errors.concat(p.errs)
        await p.close()
      }
      report.push(facts)
    }
  }
  fs.writeFileSync(path.join(OUT, `report.json`), JSON.stringify(report, null, 2))
  console.log(JSON.stringify(report, null, 1).slice(0, 4000))
  await b.close()
})()
