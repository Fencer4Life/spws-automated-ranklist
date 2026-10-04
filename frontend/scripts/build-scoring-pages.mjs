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
import { mkdir, readFile, writeFile } from 'node:fs/promises'
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

// Each published artefact: the doc/tools/ source that carries the markers,
// every destination that must stay byte-identical to it, and its embed copy.
//
// THE EMBED COPIES (ADR-090 amendment 2026-10-03, FR-150)
// -----------------------------------------------------------------------------
// <spws-document> frames frontend/public/embed/<page>.html on the association's
// WordPress pages, under the SPWS bar, and release.yml fills it with the PROD
// pair. It is the same page with three things removed and one added: the blocks
// between SPWS-EMBED:OMIT markers go (the TEST ribbon and its style, the page's
// own language bar and its banner — the SPWS bar does those jobs there), and a
// script that reports the page's height to the frame is added before </body>.
// In markup the markers are HTML comments; inside <style> they are CSS comments,
// because an HTML comment is not a comment there. The scoring module block is
// untouched, so the maths is the same bytes (ADR-102), and --check guards these
// copies like every other.
const ARTEFACTS = [
  {
    source: 'doc/tools/kalkulator-punktow-za-wynik-spws.v2.html',
    copies: [
      'frontend/public/kalkulator-punktow.html',
      'doc/tools/WP-kalkulator-punktow-za-wynik-spws.html',
    ],
    embed: 'frontend/public/embed/kalkulator-punktow.html',
  },
  {
    source: 'doc/tools/Tabela-punktacji-SPWS_2026-2027.html',
    copies: ['frontend/public/tabela-punktacji.html'],
    embed: 'frontend/public/embed/tabela-punktacji.html',
  },
]

const OMIT_BLOCK =
  /[ \t]*(?:<!-- SPWS-EMBED:OMIT:BEGIN -->[\s\S]*?<!-- SPWS-EMBED:OMIT:END -->|\/\* SPWS-EMBED:OMIT:BEGIN \*\/[\s\S]*?\/\* SPWS-EMBED:OMIT:END \*\/)\n?/g

// What the framed page tells the framing element. The frame cannot see into
// the page, so the page says how tall it is, and again whenever that changes
// (fonts, the season's parameters arriving, a folded tool opening). And a link
// to the rules, followed inside the frame, would open the annex there, under a
// bar that names the calculator — so the page asks the element to open the
// site's annex page instead (WP.DOC.04). The element believes only the asset
// base's origin and opens only addresses its own page gives; nothing here is
// sensitive, so any parent may hear it.
const FRAME_BRIDGE = `  <!-- SPWS-EMBED: the bridge to the framing <spws-document>: the height
       report and the request to open the annex (ADR-090 amendment 2026-10-03,
       FR-150). Added by the generator. -->
  <script>
    (function () {
      if (window.parent === window) return;
      var last = 0;
      function report() {
        var h = Math.ceil(document.documentElement.getBoundingClientRect().height);
        if (h > 0 && h !== last) {
          last = h;
          window.parent.postMessage({ type: 'spws-doc-height', height: h }, '*');
        }
      }
      if ('ResizeObserver' in window) {
        var ro = new ResizeObserver(report);
        ro.observe(document.documentElement);
        ro.observe(document.body);
      }
      window.addEventListener('load', report);
      report();
      document.addEventListener('click', function (e) {
        var a = e.target && e.target.closest ? e.target.closest('a.annex-link') : null;
        if (!a) return;
        e.preventDefault();
        window.parent.postMessage({ type: 'spws-doc-nav', page: 'table' }, '*');
      });
    })();
  </script>
`

function toEmbed(html, source, embedPath) {
  const omitted = html.match(OMIT_BLOCK) ?? []
  // The ribbon's style, the ribbon, and the language bar with the banner:
  // fewer means a marker was lost.
  if (omitted.length < 3) {
    throw new Error(`${source}: expected at least 3 SPWS-EMBED:OMIT blocks, found ${omitted.length}.`)
  }
  let out = html.replace(OMIT_BLOCK, '')
  if (out.includes('SPWS-EMBED:OMIT')) {
    throw new Error(`${source}: an unpaired SPWS-EMBED:OMIT marker.`)
  }
  if (out.split('<body>').length !== 2 || out.split('</body>').length !== 2) {
    throw new Error(`${source}: expected exactly one <body> and one </body>.`)
  }
  const banner =
    `<!-- ${embedPath}: GENERATED from ${source} by frontend/scripts/build-scoring-pages.mjs.\n` +
    '     DO NOT EDIT. The copy <spws-document> frames on WordPress: no ribbon, no\n' +
    '     language bar, no banner, and a height report. -->\n'
  out = out.replace('<body>\n', `<body>\n${banner}`)
  return out.replace('</body>', `${FRAME_BRIDGE}</body>`)
}

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
    // esbuild names the source in a comment relative to its working directory.
    // Pinned to the repository root, the bundle is the same bytes whether this
    // runs from the root (as preflight does) or from frontend/.
    absWorkingDir: ROOT,
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
    const expected = artefact.copies.map((copy) => [copy, next])
    expected.push([artefact.embed, toEmbed(next, artefact.source, artefact.embed)])
    for (const [copy, content] of expected) {
      const copyPath = resolve(ROOT, copy)
      let existing = null
      try {
        existing = await readFile(copyPath, 'utf8')
      } catch {
        /* a missing copy is stale by definition */
      }
      if (existing !== content) {
        stale.push(copy)
        if (!check) {
          await mkdir(dirname(copyPath), { recursive: true })
          await writeFile(copyPath, content, 'utf8')
        }
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
