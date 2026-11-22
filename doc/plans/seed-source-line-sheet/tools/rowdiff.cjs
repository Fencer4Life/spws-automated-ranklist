// usage: node rowdiff.cjs <frontend dir> <before.png> <after.png> <from row> <shift>
// Lists the before-rows (from <from row> down) that differ from after-row + shift, in runs,
// with the number of differing pixels and their x-range in each run.
const path = require('path')
const fs = require('fs')
const { chromium } = require(path.join(process.argv[2], 'node_modules/playwright'))
const [A, B, FROM, SHIFT] = [process.argv[3], process.argv[4], Number(process.argv[5]), Number(process.argv[6])]
;(async () => {
  const b = await chromium.launch()
  const p = await b.newPage()
  const runs = await p.evaluate(async ([x, y, from, shift]) => {
    const load = async (s) => {
      const img = await createImageBitmap(await (await fetch('data:image/png;base64,' + s)).blob())
      const c = new OffscreenCanvas(img.width, img.height)
      const g = c.getContext('2d')
      g.drawImage(img, 0, 0)
      return { w: img.width, h: img.height, d: g.getImageData(0, 0, img.width, img.height).data }
    }
    const [i, j] = [await load(x), await load(y)]
    const out = []
    let cur = null
    for (let r = from; r < i.h && r + shift < j.h; r++) {
      let n = 0, x0 = 1e9, x1 = -1
      for (let c = 0; c < i.w; c++) {
        const a = (r * i.w + c) * 4, bb = ((r + shift) * j.w + c) * 4
        if (i.d[a] !== j.d[bb] || i.d[a + 1] !== j.d[bb + 1] || i.d[a + 2] !== j.d[bb + 2]) { n++; x0 = Math.min(x0, c); x1 = Math.max(x1, c) }
      }
      if (n) {
        if (cur && cur.to === r - 1) { cur.to = r; cur.px += n; cur.x0 = Math.min(cur.x0, x0); cur.x1 = Math.max(cur.x1, x1) }
        else { cur = { from: r, to: r, px: n, x0, x1 }; out.push(cur) }
      }
    }
    return { h: [i.h, j.h], out }
  }, [fs.readFileSync(A).toString('base64'), fs.readFileSync(B).toString('base64'), FROM, SHIFT])
  console.log(JSON.stringify(runs))
  await b.close()
})()
