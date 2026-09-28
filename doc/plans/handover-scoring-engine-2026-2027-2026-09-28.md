# Handover — SPWS 2026/2027 scoring engine (28 Sep 2026)

Written at the end of a session that was in **plan mode throughout**: only `doc/plans/` pages and plan files
were written; **nothing is committed or pushed**. The design is complete; the user signed it off page by page.

## 1. Read in this order

All in `/Users/aleks/coding/SPWSranklist/doc/plans/` (the MAIN checkout — use absolute paths if you start in
another worktree):

1. `scoring-engine-2026-2027-implementation-plan-2026-09-28.html` — **the plan**: Step A (board preview), ADR-103
   draft (§3, Status: Proposed), SE27.* acceptance-test IDs, 8 scenario walk-throughs, steps 0–9, coherence gate.
2. `scoring-engine-2026-2027-brainstorm-2026-09-27.html` — **the design, round 10**: every decision Q1–Q11, the
   Polish rule text (15 points, `#rulesPl`, copy button), full ADR/doc/code/test inventory.
3. `tabela-punktacji-propozycja-2026-09-27.html` — **the signed-off table + calculator** (what Step A publishes).
4. `joined-bracket-scoring-engine-analysis-2026-09-27.html` — analysis behind the formula. **Stale on
   calibration** (still recommends 27/15/6 and a piste rule); the design page overrides it.
5. `joined-category-policy-2026-09-27.html` — early rounds; superseded, history only.

These five + this file are **untracked** on branch `claude/docs-search-rag`, which is 67 commits behind
`origin/main` — the wrong base. Copy them into the new work branch; never commit them on `claude/docs-search-rag`.
Session plan files: `~/.claude/plans/cosmic-booping-lemon.md` (latest), `~/.claude/plans/we-are-now-going-harmonic-gadget.md` (history).

## 2. DO FIRST — Step A, today: board preview on PROD

User's words (28 Sep): *"commit and push the Table and the new calculator describing the new scoring engine. I want
to show it to the board TODAY… publish them all the way to PROD now."* The push to `main` for Step A is authorised.

- **Branch:** work on `claude/scoring-engine-2026-2027` cut from `origin/main`. If you start in an app-made
  worktree whose base is not `origin/main`, create the branch from `origin/main` there (the tree is clean).
  Otherwise: `git worktree add ../SPWSranklist-claude-scoring-engine-2026-2027 -b claude/scoring-engine-2026-2027 origin/main`.
- **Copy** the six files above (five HTML pages + this .md) into the branch's `doc/plans/`.
- **Test first (RED):** `frontend/tests/assets.test.ts` gains SE27.PREVIEW.01–03 — the page exists in
  `frontend/public/`; it carries `noindex`; it is self-contained (no `fetch`, no `#spws-env`, no Supabase URL/key,
  no relative link to an unpublished file).
- **Page (GREEN):** copy `tabela-punktacji-propozycja-2026-09-27.html` to
  `frontend/public/tabela-punktacji-projekt-2026-2027.html`. Its ONE relative link (footer, to the analysis page)
  targets an unpublished `doc/plans/` file → make it plain text. Change nothing else. The page computes everything
  in-page (no DB, no network), keeps `noindex`, footer „Projekt — nieprzyjęty”. Not linked from the drawer.
- **Do NOT touch** the live `/tabela-punktacji.html` or `/kalkulator-punktow.html` — they follow the season
  engine via `fn_public_scoring_params` (ADR-102) and keep the September engine until the engine release.
- **Docs:** `doc/handbook/product/product-surfaces.html` (a third, temporary board-preview page; not Załącznik
  nr 1; replaced when ADR-103 lands). ADR-085 §2 dated amendment via skill `new-adr` (ADR-102 open item 2 said to
  revisit §2 "if a third is proposed"); update its Appendix C text. `python scripts/check_docs.py --changed-from origin/main`.
- **Gates:** `scripts/preflight.sh` exits 0 (the ONLY definition of done). Then `scripts/refresh-graph.sh` and
  `python3 tools/docs-search/ingest.py`; commit.
- **Release:** integrate through the registered integration checkout `/Users/aleks/coding/SPWSranklist-integration`
  (was at `f33cee23`, behind `origin/main` `967446ff` — fast-forward first; never `reset --hard` a dirty tree);
  push `integration/main:main` (not `HEAD:main`). Follow CI → Release (gate → build → deploy-pages → deploy-cert →
  deploy-prod) to success with skill `release`. A `frontend/public/` change deploys; no migration is involved.
- **Verify on PROD** in the browser: N = 8 row 53.5/38.0/26.5/17.0/13.5/10.0/6.5/3.0; N = 31 winner 150.8;
  N = 32 winner 128.6 (EVF); N = 64 winner 146.0; 10-fencer example 51.2/52.0/38.9/24.3/41.5/22.1/24.9/15.1/6.8/3.3;
  no horizontal scroll at 375 px. Give the user the live URL. **Then stop.**

## 3. THEN — the engine (not before the user signs off the ADR-103 draft in plan §3)

Plan-mode approval was never given — it was rejected twice, first to add Step A, then to hand over — never on
content. Ask the user to sign off the ADR-103 draft (in HTML, not chat), then run plan steps 1–9 RED → GREEN.
The engine release to `main` needs a **separate** explicit go.

## 4. Decisions (details: design page §1)

- **Engine per type per season** (on `tbl_scoring_type_config`): PPW, MPW, PPS, MPS → new
  `SPWS_PLACE_MEDAL_V1_2026_2027`; PEW, MEW, MSW, PSW → `EVF_CLASSIC_V1_2025_2026`.
- **New formula**, one released strategy, three ranges by whole-bracket N:
  N ≤ 3 → N − p + 1; 4–31 → log₂N + 3.5 × (fencers strictly below) + medal (13/7/3 × ∛K when m ≤ 3 and K > m);
  N ≥ 32 → `fn_score_evf_classic_v1_2025_2026` with the season's EVF settings, no category medal.
  × type multiplier. All numbers are engine constants; only multipliers are settings. No "joining always pays"
  promise (31 → 32 costs 3.5–44.9 points; stated in §8).
- **Delete** `SPWS_FIELD_SCALED_V1_2026_2027` permanently (0 revisions, 0 results on CERT/PROD).
  `fn_backfill_scoring_engines` names it and is re-called from `supabase/seed_post_backfill.sql` → replace it.
- **Ties:** competition ranking (1, 2, 3, 3, 5); a tied fencer is not "z gorszym wynikiem".
- **Storage:** `tbl_result` gains K (`int_category_count`), m (`int_category_place`), `num_field_pts`,
  `num_below_pts`, `num_medal_bonus`, `enum_score_method` (TABLE / PLACE_MEDAL / EVF_CLASSIC). "Not used" = **−1**
  (CHECK ≥ 0 or −1; K/m ≥ 1 or −1), never NULL, never NaN. Backfill history with −1.
- **Joined-bracket modules**, isolated, named, paired 1:1 with engines in `python/pipeline/joined_brackets/`:
  `PER_CATEGORY_RENUMBER` (today's `_rerank_places`, `python/pipeline/plugins/ingest.py` L557, moved unchanged)
  ↔ EVF classic; `JOINED_BRACKET_CATEGORY_PLACE` ↔ new engine (keeps joined place and N, writes K and m;
  PZSz: K = N, m = place). No second dropdown.
- **Ranking entry** only via a PPW/MPW start in the ranking's window (ranked season + carried previous season in
  rolling mode), any weapon (Q9b = A). Per-season `entry_types: ["PPW","MPW"]` in `json_ranking_rules`. This
  CHANGES `fn_ranking_full_*`, which today admits anyone with any scored result.
- **Labels:** „Za liczebność”, „Zawodnicy poniżej w stawce”, „Premia medalowa”; −1 shown as „nie dotyczy”.
- **Public pages (engine release):** annex 64 × 64 (1–3 flat, 4–31 SPWS, 32–64 EVF), medal table K = 1–31,
  calculator any N ≤ 300 with „Stawka łączona” (also shows/hides the medal card); toggle compares SPWS vs EVF classic.

## 5. Verified facts (27–28 Sep)

- CERT and PROD: SPWS-2026-2027 unlocked, 32 events, 0 tournaments, 0 results, assigned field-scaled.
- PROD 2026/27 multipliers: PPW 1.0, MPW 1.2, PEW 1.0, MEW 1.3, MSW 1.4, PSW 1.1, PPS 1.1, MPS 1.3; min field 1
  (domestic, PZSz) / 5 (EVF). No PPS/MPS results stored on PROD yet.
- `PEW1f` (19 Sep) and `PPW1` (26 Sep) not ingested. **Hold PPW1 and all 2026/27 PROD promotion until the engine
  is deployed.** Daily `evf-sync.yml` (06:00 UTC) may lock CERT via PEW1f → recover with one
  `fn_revise_and_rescore_season` on CERT, only on the user's go with a board reference.
- pgTAP total 1141; next ADR **103**; ADR-102 is still **Draft**; next FR **FR-137**; test prefix `SE27` unused.
- Postgres sorts `'NaN'` above all numbers and `to_json` gives `"NaN"` → reason for the −1 marker.
- Ranking already attributes carried results by the ranked season's category (`fn_ranking_full_*` L363/L483).
- Release chain: push `main` → CI → Release (`workflow_run`): gate (`scripts/release-gate.sh`, docs-only skips) →
  build → deploy-pages → deploy-cert → deploy-prod.

## 6. How this user works

- Every human-facing deliverable, question and plan is an **.html page in `doc/plans/`** (Editorial design).
  Handover/agent files like this one may be .md. Chat stays short: a link plus the essentials, no inline tables.
- **One question at a time, written in the HTML** with options and a recommendation. Never use AskUserQuestion.
- Working docs in English; Polish only for what reaches fencers. Never „stoi”; no verdicts. Say „z gorszym
  wynikiem”, never „pokonani”.
- **Verify before claiming** — wrong claims and missing HTML have made this user angry. Graphify and the
  docs-search MCP first; read SQL bodies in the migrations.
- `scripts/preflight.sh` exit 0 is done. Push `main` only from the integration checkout. Never a bare
  `supabase db reset` (use `./scripts/reset-dev.sh`). Never read spreadsheets without per-file permission.
