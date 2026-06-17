# ADR-075: Staging report — a fifth Context channel + per-plugin fragments + terminal formatter

**Status:** Accepted (implemented 2026-06-16, NEW pipeline build). Design in
[ingestion_pipeline_NEW_design.md](../ingestion_pipeline_NEW_design.md) §4.1 / §4.1a / §5.2a.
**Implemented** — see [development_history](../development_history.md).
**Date:** 2026-06-16
**Relates to:** ADR-073 (plugin/rule-engine contract — adds the `report` channel + per-kind emit),
ADR-074 (no-halt / no-draft — this restores the lost staging artifact *without* reintroducing drafts),
ADR-058/061 (verdict `.md` target router — reuses `md_writer.write_for_event`), ADR-050 (the OLD
draft-then-review pipeline whose `.md`/`.diff.md` this replaces).

## Context

ADR-074 removed the draft tables and the human review gate (auto-commit, faults resolved inline). A
side-effect was the loss of the OLD pipeline's two **human-review files** per event —
`doc/staging/<EVENT>.md` (the full ingestion summary) and `<EVENT>.diff.md` (the 3-way Source/CERT/New
diff). The PPW3 from-URL debug run showed the cost: the NEW pipeline silently dropped markerless
fencers and let a minority-gender épée pool through with **no surfaced report**. Operators still need
to *audit* a committed run — they just must not be a *gate* in front of it.

The staging file aggregates information produced *throughout* ingestion (stage-0 reconciliation, fuzzy
matching, pool-round detection, count validation, commit results). The design question was where that
information should come from.

## Decision

Add a **fifth forward channel** to `Context`: `report` — an append log of `ReportFragment(plugin, kind,
section, payload)`, peer to `data` / `trace` / `warnings` / `faults`. `ctx.add_report(section,
**payload)` (and the `BasePlugin.report` convenience) tag each fragment with the active plugin's name
and kind; like `fault()`/`warn()` it is a forward signal, **not** a DAG key, so it bypasses
write-discipline and is callable by **every plugin kind**.

**Every plugin serializes its own contribution as it runs** (Source → parsed bracket; Gates → their
checks; Transforms → structure; Mutators → identity/commit). **One terminal `StagingFormatter`**
(Mutator, `effects={"docs"}`) shapes the accumulated fragments into the files from `STAGING_TEMPLATE`
(an ordered `(heading, renderer)` spec — the "template"; no Jinja dependency in the repo). It is the
only plugin that touches the filesystem. The `.md` is rendered from the template; the `.diff.md` reuses
`three_way_diff` verbatim, fed from the `IDENTITY` matches + `db.fetch_cert_rows_for_event`.

`StagingFormatter` lives at the tail of the `POST_COMMIT` flow but renders only at **event scope**: the
CLI fires ONE event-level `POST_COMMIT` after the bracket loop (`ingest_cli._fire_staging_report`),
seeding `_bracket_reports` (every bracket's `report`) and schedule-level skips. `applies()` is True only
when `_bracket_reports` is present, so the per-bracket POST_COMMIT the `PostCommit` reactor fires SKIPs
it. One UTC stamp per run names both files — `doc/staging/<EVENT>.<YYYYMMDD-HHMMSSZ>.md` / `.diff.md` —
so reruns of the same event are comparable.

This layer is **informational / post-commit** (consistent with ADR-074): no drafts, no blocking gate.
The operator reviews the `.md`, fixes via the alias UI / a master-data edit, and re-runs — self-healing
(ADR-072) re-derives the affected events.

## Alternatives considered

- **(A) A single terminal plugin that reconstructs the report from the legacy `_legacy` pctx.**
  Rejected: brittle and couples the report to plugin *side-effects* — any contribution not happening to
  land on the pctx is invisible, and the report is reverse-engineered rather than declared. The user
  explicitly chose distributed emission.
- **(B, chosen) Distributed fragment emission + a terminal shaper.** Each plugin owns its slice (it
  knows best what it did); the report is a first-class, self-describing output; new plugins extend it by
  emitting a fragment. Mirrors how the OLD pipeline already accumulated state across stages and shaped
  it at the end, but as a declared channel.
- **A blocking curation gate (re-introduce drafts).** Rejected: reverses ADR-074. The files are
  informational; the pipeline already committed its best automatic state.
- **A Jinja template file.** Rejected: no Jinja dependency in the repo; an ordered Python
  `(heading, renderer)` spec is the lighter "template" and keeps rendering testable per-section.

## Consequences

- The NEW pipeline regains per-event audit visibility lost with the draft gate, with no human in the
  critical path.
- Every plugin gains a one-line emit; the contract (`Context`/`BasePlugin`) carries the capability, so
  the report stays self-contained and extensible.
- `POST_COMMIT` now ends `ParticipantCount → Notify → StagingFormatter`; the per-bracket reactor fire
  SKIPs the formatter (event-scope gate), so only the CLI's event-level fire renders.
- `md_writer.write_for_event` and `three_way_diff.write_diff` gain an optional, backward-compatible
  `timestamp` param; existing callers are unaffected.
- Timestamped filenames accumulate in `doc/staging/`; pruning old runs is left to the operator.
- During the bridge, `ResolveFencers` writes identity data to both the legacy pctx (parity bridge) and
  the report channel; the report channel is the file's source of truth.

## Tests (implemented — design §10, RED first)

N11.1 `Context.report` + `add_report` tagging + write-discipline bypass · N11.2 `BasePlugin.report`
forwards name+kind · N11.3 every plugin emits its fragment during a real flow · N11.4
`StagingFormatter.applies` gates on `_bracket_reports` · N11.5 renders the `.md` template in order +
schedule skips surface · N11.6 writes the `.diff.md` via `three_way_diff` · N11.7 the CLI fires exactly
one event-scoped POST_COMMIT seeded with all bracket reports; timestamped filenames share a stem.
