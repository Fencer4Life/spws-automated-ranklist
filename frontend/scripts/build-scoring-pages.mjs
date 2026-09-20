#!/usr/bin/env node
// =============================================================================
// Generate the shared scoring formula into the published static pages.
// =============================================================================
// doc/plans/versioned-season-scoring-and-pzsz-ranking-design.html §08, step 8.
//
// WHY A GENERATOR RATHER THAN AN IMPORT
// -----------------------------------------------------------------------------
// The two published pages live in frontend/public/, which Vite copies verbatim
// without processing, and they are served as plain static files from GitHub
// Pages. They cannot `import` a TypeScript module. Making them Vite entry points
// would move them out of public/ and change their published paths, which §08
// forbids: "Preserve both published URLs".
//
// A second option — emitting one .js beside them and having each page import it
// — would work, but it turns the WordPress calculator into TWO files that must
// be uploaded together, and that page exists precisely to be hand-carried as a
// single file. So the formula is GENERATED INTO each page between markers, and
// this script is the only thing allowed to write between them.
//
// WHAT THIS GUARANTEES
// -----------------------------------------------------------------------------
// frontend/src/lib/scoring.ts stays the one source of truth. The pages carry a
// build artefact of it, never a hand-maintained copy, and `--check` fails if any
// page has drifted — the same contract scripts/render_docs.py --check provides
// for the generated HTML twins.
//
// THE THREE-WAY IDENTITY IS PRESERVED
// -----------------------------------------------------------------------------
// frontend/tests/assets.test.ts asserts published === source for the calculator
// AND wordpress === source. This script writes the doc/tools/ source, then
// copies it byte-for-byte to its published and WordPress destinations, so that
// assertion keeps holding rather than needing to be relaxed.
//
// Usage:
//   node scripts/build-scoring-pages.mjs            # write
//   node scripts/build-scoring-pages.mjs --check    # fail if any file would change
// =============================================================================

import { build } from 'esbuild'
import { readFile, writeFile } from 'node:fs/promises'
import { dirname, resolve } from 'node:path'
import { fileURLToPath } from 'node:url'

// ../.. because this script lives in frontend/scripts/ so that `import
// { build } from 'esbuild'` resolves against frontend/node_modules.
const ROOT = resolve(dirname(fileURLToPath(import.meta.url)), '../..')
const SOURCE_MODULE = resolve(ROOT, 'frontend/src/lib/scoring.ts')

const BEGIN = '/* === SPWS-SCORING-MODULE:BEGIN'
// Both markers include their comment delimiters. An END without the opening
// '/*' leaves a dangling '=== ... */' in the page, which parses as code and
// throws SyntaxError at load — invisible to every unit test, fatal in the browser.
const END = '/* === SPWS-SCORING-MODULE:END === */'

// Each published artefact: the doc/tools/ source that carries the markers, and
// every destination that must stay byte-identical to it.
const ARTEFACTS = [
  {
    source: 'doc/tools/kalkulator-punktow-za-wynik-spws.v2.html',
    copies: [
      'frontend/public/kalkulator-punktow.html',
      'doc/tools/WP-kalkulator-punktow-za-wynik-spws.html',
    ],
  },
  {
    source: 'doc/tools/Tabela-punktacji-SPWS_2026-2027.html',
    copies: ['frontend/public/tabela-punktacji.html'],
  },
]

/** Bundle scoring.ts to a plain browser script exposing globalThis.SPWSScoring. */
async function bundleModule() {
  const result = await build({
    entryPoints: [SOURCE_MODULE],
    bundle: true,
    format: 'iife',
    globalName: 'SPWSScoring',
    target: 'es2020',
    platform: 'browser',
    write: false,
    legalComments: 'none',
  })
  return result.outputFiles[0].text.trimEnd()
}

function replaceBetweenMarkers(html, bundle, relPath) {
  const begin = html.indexOf(BEGIN)
  const end = html.indexOf(END)
  if (begin === -1 || end === -1) {
    throw new Error(
      `${relPath}: missing SPWS-SCORING-MODULE markers. ` +
        'The generated block must be delimited before this script can maintain it.',
    )
  }
  if (end < begin) {
    throw new Error(`${relPath}: SPWS-SCORING-MODULE markers are inverted.`)
  }
  const header =
    `${BEGIN} — generated from frontend/src/lib/scoring.ts by\n` +
    '   frontend/scripts/build-scoring-pages.mjs. DO NOT EDIT BY HAND: run that script.\n' +
    '   The formula has one source of truth; this is a build artefact of it. === */\n'
  return html.slice(0, begin) + header + bundle + '\n' + html.slice(end)
}

async function main() {
  const check = process.argv.includes('--check')
  const bundle = await bundleModule()
  const stale = []

  for (const artefact of ARTEFACTS) {
    const sourcePath = resolve(ROOT, artefact.source)
    const current = await readFile(sourcePath, 'utf8')
    const next = replaceBetweenMarkers(current, bundle, artefact.source)

    if (next !== current) {
      stale.push(artefact.source)
      if (!check) await writeFile(sourcePath, next, 'utf8')
    }
    for (const copy of artefact.copies) {
      const copyPath = resolve(ROOT, copy)
      let existing = null
      try {
        existing = await readFile(copyPath, 'utf8')
      } catch {
        /* a missing copy is stale by definition */
      }
      if (existing !== next) {
        stale.push(copy)
        if (!check) await writeFile(copyPath, next, 'utf8')
      }
    }
  }

  if (check) {
    if (stale.length) {
      console.error('FAIL: the published pages are stale against frontend/src/lib/scoring.ts:')
      for (const f of stale) console.error(`  ${f}`)
      console.error('\nRun: node scripts/build-scoring-pages.mjs')
      process.exit(1)
    }
    console.log(`  PASS: published pages match scoring.ts (${ARTEFACTS.length} artefacts)`)
    return
  }

  if (stale.length) {
    console.log('Updated:')
    for (const f of stale) console.log(`  ${f}`)
  } else {
    console.log('Already up to date.')
  }
}

main().catch((error) => {
  console.error(error.message)
  process.exit(1)
})
