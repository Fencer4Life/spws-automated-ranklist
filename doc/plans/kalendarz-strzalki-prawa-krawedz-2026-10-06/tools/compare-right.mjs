// Arrows-to-the-right comparison (6 Oct 2026): node compare-right.mjs <approvedDir> <fixedDir> <outDir>
// Every differing pixel is classed:
//   buttons   — inside ▲ or ▼, before or after the move, widened by 10 px for the
//               disc's shadow (0 2px 7px);
//   elsewhere — anything else: tiles, seams, the jump control, the card, the
//               title, the bar, the drawer. Must be 0.
// The other pages' bars carry no buttons, so any difference there is elsewhere.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'

const require = createRequire(new URL('../../../../frontend/package.json', import.meta.url))
const { chromium } = require('@playwright/test')

const [approvedDir, fixedDir, outDir] = process.argv.slice(2)
fs.mkdirSync(outDir, { recursive: true })
const metaA = JSON.parse(fs.readFileSync(path.join(approvedDir, 'meta.json'), 'utf8'))
const metaF = JSON.parse(fs.readFileSync(path.join(fixedDir, 'meta.json'), 'utf8'))

const browser = await chromium.launch()
const page = await browser.newPage()
const results = {}
for (const name of Object.keys(metaA).sort()) {
  const b64 = (dir) => 'data:image/png;base64,' + fs.readFileSync(path.join(dir, `${name}.png`)).toString('base64')
  const ma = metaA[name], mf = metaF[name]
  const r = await page.evaluate(async ({ a, f, ma, mf }) => {
    const load = (src) => new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.src = src })
    const [ia, iff] = await Promise.all([load(a), load(f)])
    const px = (img) => { const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const x = c.getContext('2d'); x.drawImage(img, 0, 0); return x.getImageData(0, 0, img.width, img.height) }
    const A = px(ia), F = px(iff)
    const out = { size: [A.width, A.height, F.width, F.height], buttons: 0, elsewhere: 0, box: null }
    if (A.width !== F.width || A.height !== F.height) { out.elsewhere = -1; return { out } }
    const dpr = mf.dpr ?? 1
    const PAD = 10
    const zone = (b) => b ? { x0: Math.floor((b.x - PAD) * dpr), y0: Math.floor((b.y - PAD) * dpr), x1: Math.ceil((b.x + b.w + PAD) * dpr), y1: Math.ceil((b.y + b.h + PAD) * dpr) } : null
    const zones = [ma.prev, ma.next, mf.prev, mf.next].map(zone).filter(Boolean)
    const inZone = (x, y) => zones.some((z) => x >= z.x0 && x < z.x1 && y >= z.y0 && y < z.y1)
    const D = new ImageData(F.width, F.height)
    D.data.set(F.data)
    for (let i = 0; i < D.data.length; i += 4) for (let k = 0; k < 3; k++) D.data[i + k] = 255 - (255 - D.data[i + k]) * 0.35
    let bx = [1e9, 1e9, -1, -1]
    for (let y = 0; y < A.height; y++) {
      for (let x = 0; x < A.width; x++) {
        const i = (y * A.width + x) * 4
        if (A.data[i] === F.data[i] && A.data[i + 1] === F.data[i + 1] && A.data[i + 2] === F.data[i + 2] && A.data[i + 3] === F.data[i + 3]) continue
        const cls = inZone(x, y) ? 'buttons' : 'elsewhere'
        out[cls]++
        if (cls === 'elsewhere') bx = [Math.min(bx[0], x / dpr), Math.min(bx[1], y / dpr), Math.max(bx[2], x / dpr), Math.max(bx[3], y / dpr)]
        const [rr, gg, b] = cls === 'buttons' ? [24, 95, 165] : [220, 30, 30]
        D.data[i] = rr; D.data[i + 1] = gg; D.data[i + 2] = b; D.data[i + 3] = 255
      }
    }
    if (out.elsewhere) out.box = bx
    const c = document.createElement('canvas'); c.width = F.width; c.height = F.height
    c.getContext('2d').putImageData(D, 0, 0)
    return { out, diff: c.toDataURL('image/png') }
  }, { a: b64(approvedDir), f: b64(fixedDir), ma, mf })
  if (r.diff) fs.writeFileSync(path.join(outDir, `${name}.diff.png`), Buffer.from(r.diff.split(',')[1], 'base64'))
  const moved = ma.prev && mf.prev ? Math.round((mf.prev.x - ma.prev.x) * 10) / 10 : null
  const flush = mf.prev && mf.vp ? Math.round((mf.vp.x + mf.vp.w - (mf.prev.x + mf.prev.w)) * 10) / 10 : null
  results[name] = { ...r.out, moved, gapToRightEdge: flush }
}
await browser.close()
fs.writeFileSync(path.join(outDir, 'results.json'), JSON.stringify(results, null, 1))
const rows = Object.entries(results)
const bad = rows.filter(([, v]) => v.elsewhere !== 0)
const lines = rows.map(([k, v]) => `${k.padEnd(34)} buttons=${String(v.buttons).padStart(6)} elsewhere=${String(v.elsewhere).padStart(4)} moved=${v.moved ?? '-'} gapRight=${v.gapToRightEdge ?? '-'}${v.box ? ' box=' + v.box.join(',') : ''}`)
fs.writeFileSync(path.join(outDir, 'compare.txt'), lines.join('\n') + `\n\n${rows.length} states; ${rows.filter(([, v]) => v.buttons === 0 && v.elsewhere === 0).length} identical; ${rows.filter(([, v]) => v.buttons > 0 && v.elsewhere === 0).length} differ only at the buttons; ${bad.length} differ elsewhere\n`)
console.log(`${rows.length} states; ${bad.length} differ elsewhere`)
