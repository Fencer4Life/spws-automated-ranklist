# Conventions

## Documentation

Follow [documenting.md](documenting.md) and the [documentation standard](../handbook/reference/documentation-standard.html). Human-facing documents and plans are HTML. The handbook owns present behavior; ADRs own rationale; governance owns obligations; evidence owns run artifacts; archive owns superseded narratives.

## Data integrity hard rules

- URLs are admin-managed unless a current formal rule or ADR explicitly assigns another owner.
- Validate URL-to-data identity on every policy-controlled write: compare date, name, weapon, category, city and country; reject mismatches. See ADR-052 and R009.
- When adding a column to `tbl_event`, review and rebuild `vw_calendar` in the same migration when its row contract is affected.
- Preserve the documented participant scope of `seed_tbl_fencer.sql`; never broaden it implicitly.
- Identity decisions, aliases, source priority, draft review and commit behavior must follow the current subsystem contracts in the handbook and formal rules—not an old rebuild phase description.

## Working style

- Check the worktree and active user scope before edits; preserve unrelated changes.
- Use full feature/plan names rather than ambiguous phase shorthand.
- Surface user-facing diagnostics in the UI rather than requiring browser console access.
- Use Telegram, not Discord, for the established operational alerting surface.
- Never read spreadsheet files without explicit authorization for the named file.
- Never run a bare `supabase db reset`; use `./scripts/reset-dev.sh` for LOCAL.
- Never put credentials or secret values in documentation, plans, logs or commits.
