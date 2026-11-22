// FR-176 — derives the proof variants from the samples (see ods_check.sh):
//   <name>-poison.ods   every formula cell's stored value overwritten with -1
//   roster-x.ods        „x” typed into column G of the first two roster rows
//   <name>-<sheet>.ods  only that sheet visible (hidden sheets are not printed)
const fs = require('node:fs')
const path = require('node:path')
const { unzipSync, zipSync, strFromU8, strToU8 } = require(path.resolve(__dirname, '../../../../frontend/node_modules/fflate'))
const dir = process.argv[2]
const MIME = 'application/vnd.oasis.opendocument.spreadsheet'
function rewrite(src, dst, fn) {
  const z = unzipSync(fs.readFileSync(path.join(dir, src)))
  const parts = Object.fromEntries(Object.entries(z).map(([k, v]) => [k, strFromU8(v)]))
  parts['content.xml'] = fn(parts['content.xml'])
  fs.writeFileSync(path.join(dir, dst), zipSync({
    mimetype: [strToU8(MIME), { level: 0 }],
    'META-INF/manifest.xml': strToU8(parts['META-INF/manifest.xml']),
    'meta.xml': strToU8(parts['meta.xml']),
    'styles.xml': strToU8(parts['styles.xml']),
    'content.xml': strToU8(parts['content.xml']),
  }))
}
const names = fs.readdirSync(dir).filter((f) => f.endsWith('.ods') && !/-(poison|forecast|entries|roster)\.ods$/.test(f) && f !== 'roster-x.ods')
for (const f of names) {
  const base = f.replace('.ods', '')
  rewrite(f, `${base}-poison.ods`, (c) => c.replace(/(table:formula="[^"]*" office:value-type="float" office:value=")[^"]*"/g, '$1-1"'))
  const only = (keep) => (c) => {
    // A hidden sheet is not printed, unless it has a print range: drop it there.
    let i = 0
    return c.replace(/(<table:table table:name="[^"]*" table:style-name=")ta1"( table:print-ranges="[^"]*")?/g,
      (m, p, range) => (i++ === keep ? `${p}ta1"${range ?? ''}` : `${p}ta2"`))
      .replace('</office:automatic-styles>', '<style:style style:name="ta2" style:family="table" style:master-page-name="Report"><style:table-properties table:display="false"/></style:style></office:automatic-styles>')
  }
  rewrite(f, `${base}-forecast.ods`, only(0))
  rewrite(f, `${base}-entries.ods`, only(1))
  rewrite(f, `${base}-roster.ods`, only(2))
}
rewrite('full-pl.ods', 'roster-x.ods', (c) => {
  const i = c.indexOf('table:name="Lista"')
  const head = c.slice(0, i)
  let tail = c.slice(i)
  const bodyStart = tail.indexOf('</table:table-header-rows>')
  let rows = 0
  tail = tail.slice(0, bodyStart) + tail.slice(bodyStart).replace(/<table:table-row [^>]*>.*?<\/table:table-row>/g, (row) => {
    if (rows++ >= 2) return row
    const cells = [...row.matchAll(/<table:table-cell table:style-name="ce\d+"\/>/g)]
    const lastCell = cells[cells.length - 1]
    return row.slice(0, lastCell.index) + lastCell[0].replace('/>', ' office:value-type="string"><text:p>x</text:p></table:table-cell>') + row.slice(lastCell.index + lastCell[0].length)
  })
  return head + tail
})
