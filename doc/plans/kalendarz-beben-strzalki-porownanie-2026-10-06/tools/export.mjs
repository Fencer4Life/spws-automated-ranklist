// node export.mjs <shotsRoot> <outDir> — JPEG crops (bar, drum, card, footer) of the
// states shown on the §12 sheet: before, after, and after with the differences marked.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'

const require = createRequire(new URL('../../../../frontend/package.json', import.meta.url))
const { chromium } = require('@playwright/test')
const [root, outDir] = process.argv.slice(2)
fs.mkdirSync(outDir, { recursive: true })
const meta = JSON.parse(fs.readFileSync(path.join(root, 'after', 'meta.json'), 'utf8'))
const metaB = JSON.parse(fs.readFileSync(path.join(root, 'before', 'meta.json'), 'utf8'))

export const SHOWN = [
  ...['open', 'later1', 'later2', 'earlier1', 'earlier2', 'drawer'].map((s) => `wp-375-pl-calendar-${s}`),
  ...['open', 'later2', 'earlier2', 'drawer'].map((s) => `wp-320-en-calendar-${s}`),
  'wp-1280-pl-calendar-open', 'wp-1280-en-calendar-later2',
  'gh-320-pl-calendar-open', 'gh-320-en-calendar-open', 'gh-375-pl-calendar-open', 'gh-414-en-calendar-earlier2',
  'wp-320-pl-ranking-bar', 'wp-375-en-calculator-bar', 'wp-1280-pl-table-bar',
]

const browser = await chromium.launch()
const page = await browser.newPage()
for (const name of SHOWN) {
  const dpr = name.startsWith('wp-1280') ? 1 : 2
  const isBar = name.endsWith('-bar')
  const m = meta[name], mb = metaB[name]
  // Down to just under the footer: the drum's bottom + the card + the footer.
  const cssH = isBar ? null : Math.max(mb.vp.y, m.vp.y) + 246 + 330
  for (const [kind, file] of [['before', path.join(root, 'before', `${name}.png`)], ['after', path.join(root, 'after', `${name}.png`)], ['diff', path.join(root, 'diff', `${name}.diff.png`)]]) {
    const data = await page.evaluate(async ({ src, h, scale }) => {
      const img = await new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.src = src })
      const H = h ? Math.min(img.height, Math.round(h)) : img.height
      const c = document.createElement('canvas'); c.width = Math.round(img.width * scale); c.height = Math.round(H * scale)
      const g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height)
      g.drawImage(img, 0, 0, img.width, H, 0, 0, c.width, c.height)
      return c.toDataURL('image/jpeg', 0.84)
    }, { src: 'data:image/png;base64,' + fs.readFileSync(file).toString('base64'), h: cssH ? cssH * dpr : null, scale: dpr === 2 ? 0.75 : 1 })
    fs.writeFileSync(path.join(outDir, `${name}.${kind}.jpg`), Buffer.from(data.split(',')[1], 'base64'))
  }
}
await browser.close()
console.log(`exported ${SHOWN.length} states`)
