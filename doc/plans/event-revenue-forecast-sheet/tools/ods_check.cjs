// FR-176 — the proof by LibreOffice. Usage: node ods_check.cjs <dir>
// <dir> holds the samples (make_sample.cjs) and what soffice made of them.
// Stored values in the *-poison.ods files were overwritten with -1, so a value
// that comes back right was RECALCULATED by LibreOffice from the formula, which
// proves the formulas and not only their text.
const fs = require('node:fs')
const path = require('node:path')
const XLSX = require(path.resolve(__dirname, '../../../../frontend/node_modules/xlsx'))
const dir = process.argv[2]
const expected = JSON.parse(fs.readFileSync(path.join(dir, 'expected.json'), 'utf8'))
let failures = 0
let checks = 0
function eq(label, got, want) {
  checks++
  const ok = typeof want === 'number' ? typeof got === 'number' && Math.abs(got - want) < 1e-9 : got === want
  if (!ok) { failures++; console.log(`  FAIL ${label}: got ${JSON.stringify(got)}, want ${JSON.stringify(want)}`) }
}
const val = (ws, ref) => (ws[ref] ? ws[ref].v : undefined)

for (const [name, { model, lang }] of Object.entries(expected)) {
  const file = path.join(dir, 'xlsx', `${name}-poison.xlsx`)
  const wb = XLSX.readFile(file)
  const [f, e, r] = wb.SheetNames.map((n) => wb.Sheets[n])
  console.log(`${name}: sheets ${wb.SheetNames.join(' / ')}`)
  for (const ws of [f, e, r]) for (const [k, c] of Object.entries(ws)) if (k[0] !== '!' && c.t === 'e') { failures++; console.log(`  FAIL error cell ${k}: ${c.w}`) }
  const m = model
  const tierRev = m.tiers.reduce((s, t) => s + t.total, 0)
  eq('A7 entries', val(f, 'A7'), m.totals.entries)
  eq('C7 starts', val(f, 'C7'), m.totals.starts)
  eq('E7 revenue', val(f, 'E7'), tierRev)
  m.tiers.forEach((t, i) => {
    eq(`B${11 + i}`, val(f, `B${11 + i}`), t.entries)
    if (t.fee != null) eq(`C${11 + i}`, val(f, `C${11 + i}`), t.fee)
    eq(`D${11 + i}`, val(f, `D${11 + i}`), t.total)
  })
  eq('B14', val(f, 'B14'), m.totals.entries)
  eq('D14', val(f, 'D14'), tierRev)
  m.byWeapon.forEach((w, i) => {
    const r0 = 18 + i
    eq(`B${r0}`, val(f, `B${r0}`), w.F.starts)
    eq(`C${r0}`, val(f, `C${r0}`), w.F.revenue)
    eq(`D${r0}`, val(f, `D${r0}`), w.M.starts)
    eq(`E${r0}`, val(f, `E${r0}`), w.M.revenue)
    eq(`F${r0}`, val(f, `F${r0}`), w.total)
  })
  eq('B21', val(f, 'B21'), m.totals.F.starts)
  eq('C21', val(f, 'C21'), m.totals.F.revenue)
  eq('D21', val(f, 'D21'), m.totals.M.starts)
  eq('E21', val(f, 'E21'), m.totals.M.revenue)
  eq('F21', val(f, 'F21'), m.totals.F.revenue + m.totals.M.revenue)
  m.entries.forEach((en, i) => {
    eq(`entries H${i + 2}`, val(e, `H${i + 2}`), en.weapons.length)
    eq(`entries I${i + 2}`, val(e, `I${i + 2}`), en.fee ?? 0)
    eq(`roster F${i + 3}`, val(r, `F${i + 3}`), en.fee ?? 0)
  })
  const nEntries = Math.max(1, m.entries.length)
  const sumStarts = m.entries.reduce((s, en) => s + en.weapons.length, 0)
  const sumFee = m.entries.reduce((s, en) => s + (en.fee ?? 0), 0)
  eq('entries total H', val(e, `H${nEntries + 2}`), sumStarts)
  eq('entries total I', val(e, `I${nEntries + 2}`), sumFee)
  const tot = 2 + nEntries + 1
  for (const [col, n] of [['C', 1], ['D', 2], ['E', 3]]) eq(`roster ${col}${tot}`, val(r, `${col}${tot}`), m.entries.filter((en) => en.weapons.length === n).length)
  eq(`roster F${tot}`, val(r, `F${tot}`), sumFee)
  eq(`roster paid count`, val(r, `C${tot + 1}`), 0)
  eq(`roster paid sum`, val(r, `F${tot + 1}`), 0)
}

// Typing „x” into column G of two roster rows counts those two entries as paid.
const x = expected['full-pl']
const wb = XLSX.readFile(path.join(dir, 'xlsx', 'roster-x.xlsx'))
const r = wb.Sheets[wb.SheetNames[2]]
const tot = 2 + x.model.entries.length + 1
eq('typed x: paid count', val(r, `C${tot + 1}`), 2)
eq('typed x: paid sum', val(r, `F${tot + 1}`), (x.model.entries[0].fee ?? 0) + (x.model.entries[1].fee ?? 0))

// The printed pages.
function pdf(file) {
  const t = fs.readFileSync(file).toString('latin1')
  const pages = (t.match(/\/Type\s*\/Page[^s]/g) || []).length
  const box = /\/MediaBox\s*\[\s*0\s+0\s+([\d.]+)\s+([\d.]+)\s*\]/.exec(t)
  return { pages, w: Number(box[1]), h: Number(box[2]) }
}
for (const [file, want] of [['big-pl-roster.pdf', 4], ['full-pl-forecast.pdf', 1], ['big-pl-forecast.pdf', 1], ['empty-pl-roster.pdf', 1]]) {
  const p = pdf(path.join(dir, 'pdf', file))
  eq(`${file} pages`, p.pages, want)
  eq(`${file} A4 width pt`, Math.round(p.w), 595)
  eq(`${file} A4 height pt`, Math.round(p.h), 842)
}
console.log(failures ? `\n${failures} of ${checks} checks FAILED` : `\nall ${checks} checks passed`)
process.exit(failures ? 1 : 0)
