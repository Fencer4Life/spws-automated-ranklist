// FR-176 — derives the proof variants from the samples (see ods_check.sh):
//   <name>-poison.ods   every formula cell's stored value overwritten with -1
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
const names = fs.readdirSync(dir).filter((f) => f.endsWith('.ods') && !/-(poison|forecast|entries)\.ods$/.test(f))
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
}
