---
name: new-adr
description: "MANDATORY when authoring, amending or superseding an Architecture Decision Record in this repo (SPWS Automated Ranklist System). Authors the ADR as Markdown per ADR-082, generates its HTML twin with scripts/render_adrs.py, and runs the supersede/amend audit over the existing corpus first so the new decision does not silently contradict a prior one. Triggers on: write an ADR, new ADR, draft an ADR, record this decision, amend ADR-NNN, supersede ADR-NNN, next ADR number, register in Appendix C, 'this is an architectural decision'."
---

# New ADR — audit the corpus, author Markdown, generate the twin

Two things go wrong when an ADR is written without this procedure, and both
have happened here.

**Hand-writing the HTML.** The instinct in this repo is "every deliverable is
HTML". For ADRs that is wrong: **ADR-082** makes the corpus a source→artifact
model — the `.md` is the hand-authored source of truth and the Appendix C link
target, the `.html` is generated and **never hand-edited**. Each HTML embeds a
source SHA-256, and CI's *Validate generated ADR HTML* step
(`.github/workflows/ci.yml:58`) fails on any stale or missing twin. A
hand-written ADR HTML cannot pass.

**Writing the new decision without auditing the old ones.** An ADR that
reverses a prior decision without naming it leaves two contradictory records
and no indication which one binds. Worse, prior ADRs pin *tests*: deleting a
test that is a documented ADR consequence retires the verification of a
decision that still reads as live. This is exactly what nearly happened with
ADR-018 and tests R.23–R.25 during the calendar barrel work — see
`doc/plans/kalendarz-barrel-adr-alignment-2026-08-09.html` for that audit as a
worked example.

## `doc/adr/ADR_TEMPLATE.html` is not an authoring template

It is the **render skeleton** consumed by `scripts/render_adrs.py` — 23 lines of
`@@PLACEHOLDER@@` markers. Do not start an ADR from it and do not edit it
unless you are deliberately changing how every ADR renders. It is listed in
ADR-082 as directly-maintained infrastructure, alongside `doc/adr/assets/adr.css`
and `doc/adr/index.html`.

## Step 1 — audit before you draft

Run the `pre-analysis-check` gate (graphify + LSP), then sweep the corpus for
decisions the new one touches. Grep the ADR bodies for the surfaces you are
changing — component names, CSS classes, column names, config flags, test IDs:

```bash
cd doc/adr && grep -lie '<surface-you-are-changing>' *.md
```

Sort every hit into one of four outcomes, and record the first three in the
intro fields of the new ADR:

| Outcome | Meaning | Where it goes |
| --- | --- | --- |
| **Supersede** | The prior decision is reversed | `**Supersedes:**` — name the **section** if only part dies |
| **Amend** | The prior decision still holds but its detail moves or extends | `**Amends:**` |
| **Relates** | Constrains or is relied upon, unchanged | `**Relates to:**` |
| **Clean** | No impact | Say so in the audit, so nobody re-checks |

Two checks that are easy to skip and expensive to miss:

- **Does the prior ADR pin tests?** Search its body for a test table. If those
  tests are being deleted, the ADR must be amended in the same change.
- **Does the prior ADR record a rejected alternative that you are now
  building?** Reversing a rejection without answering its stated reason reads as
  an oversight. Answer it with evidence in `## Alternatives considered`.

## Step 2 — pick the number

```bash
ls doc/adr/[0-9][0-9][0-9]-*.md | tail -3
```

Take the next integer. **Do not assume the highest number equals the count** —
051 and 054 have no files, so the corpus was 81 records ending at 083 when
ADR-084 was added. If a gap number is cited normatively by another ADR (ADR-077
cites ADR-054), that is a registry defect worth reporting, not a number to
reuse.

Filename must match the renderer's glob `[0-9][0-9][0-9]-*.md` — exactly three
digits, then a kebab-case slug: `084-calendar-quarter-barrel-event-card.md`.

## Step 3 — author the Markdown

The renderer splits the file at the **first `## ` heading**: everything above is
the *intro* (rendered as the facts card + source note), everything from it down
is the *body* (rendered with a generated table of contents).

```markdown
# ADR-084: Calendar Quarter Barrel + Single Event Card

**Status:** Draft (proposed 2026-08-09; awaiting sign-off)
**Date:** 2026-08-09
**Supersedes:** [ADR-015](015-m8-ui-design-decisions.md) §2 (...). §§1, 3–9 are untouched.
**Amends:** [ADR-018](018-rolling-score.md) (...), [ADR-017](017-season-configurable-evf-toggle.md) (...)
**Relates to:** [ADR-007](007-shadow-dom-deferred.md) (...)
**Source:** `path/to/plan-or-migration-or-script`

## Context
## Decision
### 1 · First sub-decision
## Alternatives considered
## Consequences
```

Mechanical requirements, all enforced by the renderer:

- **Title line** must match `^#\s+ADR[- ]?(\d+)\s*[:—-]\s*(.+)$`.
- **Recognised intro fields** are exactly `Status`, `Date`, `Source`, `Scope`,
  `Decision`, `Supersedes`, `Amends`, `Resolved`. Anything else is prose, not a
  field. `Relates to:` is conventional prose and renders fine.
- **`Status` must contain one of** `accepted`, `implemented`, `proposed`,
  `deferred`, `superseded` — the registry colours the row by substring match, so
  a status like `Draft` alone renders uncoloured. Write
  `Draft (proposed <date>; awaiting sign-off)`.
- **Cross-links are relative `.md` paths** — `[ADR-015](015-m8-ui-design-decisions.md)`.
  The renderer rewrites them to `.html` in the twin.

House conventions for the body, from the existing corpus:

- `## Context` states the problem and the **evidence**, with counts and
  `file:line` citations. Verify every line number before citing it; an ADR is
  normative and a wrong pointer misleads for months.
- `## Decision` uses `### N · Subsection` for multi-part decisions.
- `## Alternatives considered` is a numbered list where each entry says *why
  rejected*, not just what it was.
- `## Consequences` names new/deleted files, test impact, and defects found but
  deliberately **not** fixed.
- Add `## Open items` for decisions genuinely deferred, with a recommendation
  each. Do not let an open item masquerade as decided.

## Step 4 — generate and validate the twin

```bash
python3 scripts/render_adrs.py && python3 scripts/render_adrs.py --check
```

**Expect churn in two files you did not write, and stage them:**

- The **previous** ADR's HTML gains a `next` pager link to yours.
- `doc/adr/index.html` gains your row and updated counts.

Both are correct generated output. Verify that is *all* that changed before
staging — a diff touching prior ADR prose means something is wrong:

```bash
git diff --stat doc/adr/
```

## Step 5 — register and close the gate

- **Specification Appendix C** — *Architecture Decision Registry*. The new ADR
  needs an entry; **amended ADRs need their existing entries updated too**, since
  the registry carries a status and summary per record.
- **RTM check** for any requirement the decision touches. Requirement wording
  often survives while the test IDs it cites move.
- **Handbook pages** per `doc/handbook/documentation-map.html` — identify the
  owning current page and update it in present tense. Archive superseded prose;
  do not append implementation history to a current page.
- `python3 scripts/check_docs.py` clean, then `./scripts/refresh-graph.sh`
  before the commit.

## Sign-off is the user's call

An ADR recording a decision the user has not made is a draft, not a record.
Status it `Draft (proposed <date>; awaiting sign-off)` and say plainly which
items still need a decision. Do not mark an ADR `Accepted` on your own
initiative, and do not let a recommendation in an open item read as a
resolution — the calendar work has a documented instance of exactly that drift,
where a mock's convenient default was later mistaken for a settled choice.
