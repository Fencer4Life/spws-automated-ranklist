// §12 pixel comparison: node compare.mjs <beforeDir> <afterDir> <outDir>
// For every capture: count the differing pixels in each region class.
//   expected  — the drum outside the focused row (neighbouring rows, ▲ ▼, the
//               pill), and the title box (before ∪ after);
//   midband   — the focused row: must be 0;
//   elsewhere — everything else (card, caret, footer, bar, drawer): must be 0.
// When the header changes height (github.io at 320 px), the page below it is
// compared aligned on the drum, and the header band is reported on its own.
import { createRequire } from 'node:module'
import fs from 'node:fs'
import path from 'node:path'

const require = createRequire(new URL('../../../../frontend/package.json', import.meta.url))
const { chromium } = require('@playwright/test')

const [beforeDir, afterDir, outDir] = process.argv.slice(2)
fs.mkdirSync(outDir, { recursive: true })
const metaB = JSON.parse(fs.readFileSync(path.join(beforeDir, 'meta.json'), 'utf8'))
const metaA = JSON.parse(fs.readFileSync(path.join(afterDir, 'meta.json'), 'utf8'))

const browser = await chromium.launch()
const page = await browser.newPage()
await page.setContent('<canvas id=a></canvas><canvas id=b></canvas><canvas id=d></canvas>')

const results = {}
for (const name of Object.keys(metaB).sort()) {
  const b64 = (dir) => 'data:image/png;base64,' + fs.readFileSync(path.join(dir, `${name}.png`)).toString('base64')
  const dpr = name.startsWith('wp-1280') ? 1 : 2
  const r = await page.evaluate(async ({ a, b, mb, ma, dpr, isBar, isDrawer }) => {
    const load = (src) => new Promise((ok) => { const i = new Image(); i.onload = () => ok(i); i.src = src })
    const [ia, ib] = await Promise.all([load(a), load(b)])
    const px = (img) => { const c = document.createElement('canvas'); c.width = img.width; c.height = img.height; const x = c.getContext('2d'); x.drawImage(img, 0, 0); return x.getImageData(0, 0, img.width, img.height) }
    const A = px(ia), B = px(ib)
    const out = { size: [A.width, A.height, B.width, B.height], expected: 0, title: 0, midband: 0, elsewhere: 0, header: 0, reflow: 0, shift: 0, boxes: {} }
    if (isBar) {
      if (A.width !== B.width || A.height !== B.height) { out.elsewhere = -1; return out }
    }
    const S = (v) => Math.round(v * dpr)
    const box = (r) => r ? { x0: S(r.x), y0: S(r.y), x1: S(r.x + r.w), y1: S(r.y + r.h) } : null
    const inside = (bx, x, y) => bx && x >= bx.x0 && x < bx.x1 && y >= bx.y0 && y < bx.y1
    // Shift: when the drum moved vertically, align the page under the header on it.
    const shift = (!isBar && mb.vp && ma.vp) ? S(ma.vp.y - mb.vp.y) : 0
    out.shift = shift / dpr
    // Allowed regions round OUTWARD (an anti-aliased edge row belongs to them);
    // the focused row rounds as it is, so its band is never widened.
    const outward = (r) => r ? { x0: Math.floor(r.x * dpr), y0: Math.floor(r.y * dpr), x1: Math.ceil((r.x + r.w) * dpr), y1: Math.ceil((r.y + r.h) * dpr) } : null
    const vpB = outward(mb.vp), midB = box(mb.mid)
    const headerEnd = shift ? S(mb.vp.y) - S(6) : -1 // the before image's header band, gap included
    const titles = [outward(mb.title), outward(ma.title)]
    const W = Math.min(A.width, B.width), H = Math.min(A.height, B.height - Math.max(0, shift))
    const D = new ImageData(B.width, B.height)
    D.data.set(B.data)
    for (let i = 0; i < D.data.length; i += 4) { D.data[i] = 255 - (255 - D.data[i]) * 0.35; D.data[i + 1] = 255 - (255 - D.data[i + 1]) * 0.35; D.data[i + 2] = 255 - (255 - D.data[i + 2]) * 0.35 }
    for (let y = 0; y < H; y++) {
      if (y + shift < 0) continue
      for (let x = 0; x < W; x++) {
        // The open drawer is position: fixed (260 px wide): it does not move with
        // the page, so it is compared where it is, not aligned on the drum —
        // its shadow (2 px + 8 px blur) included.
        const fixedPanel = shift && isDrawer && x < S(260)
        const shadowStrip = shift && isDrawer && x >= S(260) && x < S(270)
        const inHeader = (shift && y < headerEnd) || fixedPanel || shadowStrip
        const yb = inHeader ? y : y          // before row
        const ya = inHeader ? y : y + shift  // after row aligned on the drum
        if (ya >= B.height) continue
        const ia_ = (yb * A.width + x) * 4, ib_ = (ya * B.width + x) * 4
        if (A.data[ia_] === B.data[ib_] && A.data[ia_ + 1] === B.data[ib_ + 1] && A.data[ia_ + 2] === B.data[ib_ + 2] && A.data[ia_ + 3] === B.data[ib_ + 3]) continue
        let cls
        if (isBar) cls = 'elsewhere'
        else if (fixedPanel) cls = 'elsewhere'
        else if (shadowStrip) cls = 'reflow' // translucent shadow over a page that moved up
        else if (inHeader) cls = titles.some((t) => inside(t, x, y)) ? 'title' : 'header'
        else if (titles.some((t) => inside(t, x, ya)) || titles.some((t) => inside(t, x, yb))) cls = 'title'
        else if (inside(midB, x, yb)) cls = 'midband'
        else if (inside(vpB, x, yb)) cls = 'expected'
        else cls = 'elsewhere'
        out[cls]++
        const bb = out.boxes[cls] ?? (out.boxes[cls] = [1e9, 1e9, -1, -1])
        bb[0] = Math.min(bb[0], x / dpr); bb[1] = Math.min(bb[1], ya / dpr); bb[2] = Math.max(bb[2], x / dpr); bb[3] = Math.max(bb[3], ya / dpr)
        const k = (ya * B.width + x) * 4
        const col = cls === 'expected' || cls === 'title' ? [30, 110, 230] : cls === 'header' || cls === 'reflow' ? [240, 150, 0] : [230, 20, 20]
        D.data[k] = col[0]; D.data[k + 1] = col[1]; D.data[k + 2] = col[2]; D.data[k + 3] = 255
      }
    }
    const c = document.createElement('canvas'); c.width = B.width; c.height = B.height
    c.getContext('2d').putImageData(D, 0, 0)
    out.diff = c.toDataURL('image/png')
    return out
  }, { a: b64(beforeDir), b: b64(afterDir), mb: metaB[name], ma: metaA[name] ?? {}, dpr, isBar: name.endsWith('-bar'), isDrawer: name.endsWith('-drawer') })
  fs.writeFileSync(path.join(outDir, `${name}.diff.png`), Buffer.from(r.diff.split(',')[1], 'base64'))
  delete r.diff
  results[name] = r
  const bad = r.midband || r.elsewhere
  console.log(`${bad ? 'CHECK' : 'ok   '} ${name}: expected ${r.expected}, title ${r.title}, header ${r.header}, reflow ${r.reflow}, midband ${r.midband}, elsewhere ${r.elsewhere}${r.shift ? `, shift ${r.shift}px` : ''}${r.boxes.elsewhere ? ` | elsewhere in ${r.boxes.elsewhere.map((v) => v.toFixed(0)).join(',')}` : ''}${r.boxes.midband ? ` | midband in ${r.boxes.midband.map((v) => v.toFixed(0)).join(',')}` : ''}`)
}
fs.writeFileSync(path.join(outDir, 'results.json'), JSON.stringify(results, null, 1))
await browser.close()
