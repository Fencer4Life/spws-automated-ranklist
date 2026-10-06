// node export-right.mjs <approvedDir> <fixedDir> <diffDir> <outDir> — JPEG crops (bar, drum,
// card) of the states shown on the arrows-to-the-right sheet: before, after, differences.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'

const require = createRequire(new URL('../../../../frontend/package.json', import.meta.url))
const { chromium } = require('@playwright/test')
const [approvedDir, fixedDir, diffDir, outDir] = process.argv.slice(2)
fs.mkdirSync(outDir, { recursive: true })
const metaA = JSON.parse(fs.readFileSync(path.join(approvedDir, 'meta.json'), 'utf8'))
const metaF = JSON.parse(fs.readFileSync(path.join(fixedDir, 'meta.json'), 'utf8'))

export const SHOWN = [
  'wp-1280-pl-calendar-open', 'wp-1280-en-calendar-later2', 'wp-768-pl-calendar-earlier1',
  'wp-375-pl-calendar-open', 'wp-375-pl-calendar-earlier2', 'wp-375-pl-calendar-drawer',
  'wp-320-en-calendar-open', 'gh-1280-pl-calendar-open', 'gh-414-en-calendar-earlier2', 'gh-360-pl-calendar-open',
  'wp-1280-pl-table-bar',
]

const browser = await chromium.launch()
const page = await browser.newPage()
for (const name of SHOWN) {
  const ma = metaA[name], mf = metaF[name]
  const dpr = mf.dpr ?? 1
  const isBar = name.endsWith('-bar')
  // Down to the top of the card: the bar, the drum and the card's first rows.
  const cssH = isBar ? null : Math.max(ma.vp.y, mf.vp.y) + 246 + 150
  for (const [kind, file] of [['before', path.join(approvedDir, `${name}.png`)], ['after', path.join(fixedDir, `${name}.png`)], ['diff', path.join(diffDir, `${name}.diff.png`)]]) {
    const data = await page.evaluate(async ({ src, h, scale }) => {
      const img = await new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.src = src })
      const H = h ? Math.min(img.height, Math.round(h)) : img.height
      const c = document.createElement('canvas'); c.width = Math.round(img.width * scale); c.height = Math.round(H * scale)
      const g = c.getContext('2d'); g.fillStyle = '#fff'; g.fillRect(0, 0, c.width, c.height)
      g.drawImage(img, 0, 0, img.width, H, 0, 0, c.width, c.height)
      return c.toDataURL('image/jpeg', 0.86)
    }, { src: 'data:image/png;base64,' + fs.readFileSync(file).toString('base64'), h: cssH ? cssH * dpr : null, scale: dpr === 2 ? 0.75 : 1 })
    fs.writeFileSync(path.join(outDir, `${name}.${kind}.jpg`), Buffer.from(data.split(',')[1], 'base64'))
  }
}
await browser.close()
console.log(`exported ${SHOWN.length} states`)
