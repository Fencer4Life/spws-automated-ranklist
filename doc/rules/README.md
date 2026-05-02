# SPWS Rebuild Rules Registry

Active rebuild rules — the canonical "what should the pipeline do" reference.
Each rule is one short statement plus the trigger condition, the implementation
location (file:line), test IDs that prove it, edge cases, and the originating ADR.

For the active rebuild plan see
`/Users/aleks/.claude/plans/now-we-have-a-precious-wren.md` (master) plus the
phase subplans at [../plans/rebuild/](../plans/rebuild/).

## Build

```bash
brew install pandoc          # one-time
make -C doc/rules            # builds rules.html + R*.html
```

The markdown sources are the source of truth — HTML is for browsing.

## Rules inventory

| ID | Topic | ADRs | Phase to populate impl |
|---|---|---|---|
| [R001](R001.md) | Combined-pool split | 024, 047, 049, 050 | 3 |
| [R002](R002.md) | Joint-pool flag | 049, 050 | 3 |
| [R003](R003.md) | Age category by birth year | 010 | 0 (single SQL impl) |
| [R004](R004.md) | Cross-gender scoring | 034 | reused |
| [R005](R005.md) | EVF POL-only filter | 038 | 3 |
| [R005b](R005b.md) | EVF/FIE V0 prohibition | new (R005 child) | 3 |
| [R006](R006.md) | Identity match: auto-create domestic | 003, 050 | 3 |
| [R007](R007.md) | Rolling-score 366-day cap | 018, 054 | 7 |
| [R008](R008.md) | Carry-over FK linkage | 042, 045, 054 | 7 |
| [R009](R009.md) | URL→data validation | 052 | 3 |
| [R011](R011.md) | Source priority by organizer (EVF backup-only) | 053 | 3 |
| [R012](R012.md) | Engarde multilingual handling | 050 | 1 |

## Rule file format

Each `RNNN.md` carries the same eight sections so the registry stays scannable:

```markdown
# RNNN: <Topic>

## Statement
<one-paragraph rule>

## Why
<motivation — what breaks without this rule>

## Trigger
<when this rule kicks in — at parse time, at commit, at scoring, etc.>

## Implementation
<file:line refs; "TBD — Phase N" until that phase populates the slot>

## Tests
<plan test IDs across pgTAP / pytest / vitest; "TBD — Phase N" until then>

## Edge cases
<known traps>

## Change log
- YYYY-MM-DD: short note

## Originating ADR
- ADR-NNN
```

## Lifecycle

- **Phase 0** seeds R001-R012 with statements + ADR refs only. Implementation/Tests
  rows say `TBD — Phase N` per the table above.
- **Phases 1, 3, 4, 7** populate the Implementation and Tests rows as the
  corresponding code/tests land.
- **Phase 6** finalizes the registry and decides what (if anything) lives on
  post-rebuild — most rules become reference material; some get inlined back
  into the spec.
