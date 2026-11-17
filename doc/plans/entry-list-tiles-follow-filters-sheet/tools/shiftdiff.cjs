// Shift-aware comparison for the narrowed states (plan §10).
// usage: node shiftdiff.cjs <frontend dir> <before dir> <after dir> <shift px> [out.json]
//
// For each pair it reports:
//   top     — how many rows from the top are identical in place (the title row
//             and anything above the first change);
//   bottom  — the first before-row Y from which everything below is identical
//             to after shifted down by <shift> px (the list and the legend);
//   middle  — the before-rows between the two, where the agreed changes live.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [A, B, SHIFT, OUT] = [process.argv[3], process.argv[4], Number(process.argv[5]), process.argv[6]]

;(async () => {
  const b = await chromium.launch()
  const p = await b.newPage()
  const results = []
  for (const name of fs.readdirSync(A).filter((f) => f.endsWith('.png')).sort()) {
    const a64 = fs.readFileSync(path.join(A, name)).toString('base64')
    const b64 = fs.readFileSync(path.join(B, name)).toString('base64')
    const r = await p.evaluate(async ([x, y, shift]) => {
      const load = async (s) => {
        const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + s)).blob())
        const c = new OffscreenCanvas(img.width, img.height)
        const g = c.getContext('2d')
        g.drawImage(img, 0, 0)
        return { w: img.width, h: img.height, d: new Uint32Array(g.getImageData(0, 0, img.width, img.height).data.buffer) }
      }
      const [i, j] = [await load(x), await load(y)]
      if (i.w !== j.w) return { error: 'width differs' }
      const w = i.w
      const rowEq = (ra, rb) => {
        for (let k = 0; k < w; k++) if (i.d[ra * w + k] !== j.d[rb * w + k]) return false
        return true
      }
      let top = 0
      while (top < Math.min(i.h, j.h) && rowEq(top, top)) top++
      // Walk up from the bottom of the shorter range, comparing before-row y
      // with after-row y + shift.
      const lastBefore = Math.min(i.h, j.h - shift) - 1
      let row = lastBefore
      while (row >= 0 && rowEq(row, row + shift)) row--
      const bottom = row + 1
      return { size: `${i.w}x${i.h} -> ${j.w}x${j.h}`, top, bottom, lastBefore, identicalBelow: lastBefore - bottom + 1 }
    }, [a64, b64, SHIFT])
    results.push({ name, ...r })
  }
  if (OUT) fs.writeFileSync(OUT, JSON.stringify(results, null, 1))
  for (const r of results) console.log(r.name.padEnd(48), r.error || `top ${r.top} rows identical; from before-row ${r.bottom} down: ${r.identicalBelow} rows identical shifted by ${SHIFT}`)
  await b.close()
})()
