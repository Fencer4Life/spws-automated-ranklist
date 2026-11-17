// Pixel comparison of two capture folders, decoded in Chromium (no extra deps).
// usage: node pixdiff.cjs <frontend dir> <dir A> <dir B> [out.json]
// For each PNG in A: size match, and the number of differing pixels.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [A, B, OUT] = [process.argv[3], process.argv[4], process.argv[5]]

;(async () => {
  const b = await chromium.launch()
  const p = await b.newPage()
  const results = []
  for (const name of fs.readdirSync(A).filter((f) => f.endsWith('.png')).sort()) {
    const fb = path.join(B, name)
    if (!fs.existsSync(fb)) { results.push({ name, missing: true }); continue }
    const a64 = fs.readFileSync(path.join(A, name)).toString('base64')
    const b64 = fs.readFileSync(fb).toString('base64')
    const r = await p.evaluate(async ([x, y]) => {
      const load = async (s) => {
        const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + s)).blob())
        const c = new OffscreenCanvas(img.width, img.height)
        const g = c.getContext('2d')
        g.drawImage(img, 0, 0)
        return { w: img.width, h: img.height, d: g.getImageData(0, 0, img.width, img.height).data }
      }
      const [i, j] = [await load(x), await load(y)]
      if (i.w !== j.w || i.h !== j.h) return { size: `${i.w}x${i.h} vs ${j.w}x${j.h}`, diff: null }
      let diff = 0
      let firstRow = -1
      let box = null
      for (let k = 0; k < i.d.length; k += 4) {
        if (i.d[k] !== j.d[k] || i.d[k + 1] !== j.d[k + 1] || i.d[k + 2] !== j.d[k + 2] || i.d[k + 3] !== j.d[k + 3]) {
          diff++
          const px = (k / 4) % i.w
          const py = Math.floor(k / 4 / i.w)
          if (firstRow < 0) firstRow = py
          box = box ? [Math.min(box[0], px), Math.min(box[1], py), Math.max(box[2], px), Math.max(box[3], py)] : [px, py, px, py]
        }
      }
      return { size: `${i.w}x${i.h}`, diff, firstRow, box }
    }, [a64, b64])
    results.push({ name, ...r })
  }
  if (OUT) fs.writeFileSync(OUT, JSON.stringify(results, null, 1))
  const bad = results.filter((r) => r.missing || r.diff !== 0)
  console.log(`compared ${results.length}; identical ${results.length - bad.length}; different ${bad.length}`)
  for (const r of bad) console.log(' ', r.name, r.missing ? 'MISSING' : `${r.size} diff=${r.diff} box=${JSON.stringify(r.box)}`)
  await b.close()
})()
