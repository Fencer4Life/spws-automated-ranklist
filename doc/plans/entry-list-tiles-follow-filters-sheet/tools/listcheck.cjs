// Narrowed states: is everything below the new link the same as before, moved
// down by <shift> px? (plan §10)
// usage: node listcheck.cjs <frontend dir> <before dir> <after dir> <shift> <tolerance 0-255> [out.json]
//
// Compared inside the card only: the 8 px margin around it (which in the modal
// shows the calendar behind the overlay) and the card's own 1 px border are
// left out, and so are the last 24 rows, where a full-screen modal card ends at
// the window edge whatever its content. Walking up from there, a row matches
// when every pixel is within <tolerance> of the after-row <shift> lower, which
// absorbs anti-aliasing redrawn at a new position. Reported: the first
// matching row Y (everything from Y down matches), the number of pixels that
// differ at all in that region, and the largest difference.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [A, B, SHIFT, TOL, OUT] = [process.argv[3], process.argv[4], Number(process.argv[5]), Number(process.argv[6]), process.argv[7]]

;(async () => {
  const b = await chromium.launch()
  const p = await b.newPage()
  const results = []
  for (const name of fs.readdirSync(A).filter((f) => f.endsWith('.png') && !f.includes('1-unfiltered')).sort()) {
    const r = await p.evaluate(async ([x, y, shift, tol]) => {
      const load = async (s) => {
        const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + s)).blob())
        const c = new OffscreenCanvas(img.width, img.height)
        const g = c.getContext('2d')
        g.drawImage(img, 0, 0)
        return { w: img.width, h: img.height, d: g.getImageData(0, 0, img.width, img.height).data }
      }
      const [i, j] = [await load(x), await load(y)]
      const w = i.w
      const xs = 9, xe = w - 9
      const last = Math.min(i.h, j.h - shift) - 24
      let firstMatch = last + 1, anyDiff = 0, maxDiff = 0
      for (let row = last; row >= 0; row--) {
        let rowMax = 0, rowAny = 0
        for (let k = xs; k < xe; k++) {
          const a = (row * w + k) * 4, c = ((row + shift) * w + k) * 4
          const d = Math.max(Math.abs(i.d[a] - j.d[c]), Math.abs(i.d[a + 1] - j.d[c + 1]), Math.abs(i.d[a + 2] - j.d[c + 2]))
          if (d) { rowAny++; if (d > rowMax) rowMax = d }
        }
        if (rowMax > tol) break
        firstMatch = row
        anyDiff += rowAny
        if (rowMax > maxDiff) maxDiff = rowMax
      }
      return { firstMatch, last, anyDiff, maxDiff }
    }, [fs.readFileSync(path.join(A, name)).toString('base64'), fs.readFileSync(path.join(B, name)).toString('base64'), SHIFT, TOL])
    results.push({ name, ...r })
    console.log(name.padEnd(50), `matches from row ${r.firstMatch} to ${r.last}; pixels differing at all ${r.anyDiff}, largest ${r.maxDiff}/255`)
  }
  if (OUT) fs.writeFileSync(OUT, JSON.stringify(results, null, 1))
  await b.close()
})()
