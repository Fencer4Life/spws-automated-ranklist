---
name: add-fencer
description: "MANDATORY when adding a fencer to tbl_fencer in this repo (SPWS Automated Ranklist System) because an administrator supplied their confirmed details — a new entrant who has no results yet, or someone missing from the master list. Writes an idempotent, self-verifying migration rather than an ad-hoc INSERT, and runs the identity checks that stop a duplicate person being created. Triggers on: add a fencer, new fencer, register a fencer manually, fencer is missing from the database, administrator gave me a name and birth year, insert into tbl_fencer, add them with a confirmed birth year, fencer not found in ranking."
---

# Adding a fencer with administrator-confirmed details

A fencer row is durable, referenced by results, and feeds every ranking. Adding one
is not an INSERT — it is a migration, because it must reach LOCAL, CERT and PROD
identically and survive a from-scratch bootstrap.

The worked example this procedure is drawn from is
`supabase/migrations/20260729000001_add_fencers_ciszewska_szumielewicz.sql`
(CISZEWSKA Barbara, SZUMIELEWICZ Paweł), with earlier precedent in
`20260719000001_add_fencer_koszyk_agnieszka.sql` and the master-list batch
`20260714000003_fencer_birth_year_master_list_reconcile.sql`.

## Step 1 — prove they are actually missing, in all three environments

Do this before writing anything. A duplicate person is far more expensive to undo
than a missing one is to add.

```bash
# LOCAL
docker exec supabase_db_SPWSranklist psql -U postgres -d postgres \
  -c "SELECT id_fencer, txt_surname, txt_first_name, int_birth_year, bool_birth_year_estimated, enum_gender
      FROM tbl_fencer WHERE upper(txt_surname) LIKE 'SURNAMEPREFIX%';"

# CERT and PROD — see the cloud-db-ops skill
scripts/cloud-sql.sh prod "SELECT ... LIKE 'SURNAMEPREFIX%';"
```

**Search by prefix, not by exact name.** The point is to catch a misspelling or a
diacritic variant of a row that already exists. `CISZEW%` and `SZUMIEL%` were the
prefixes used in the worked example, and the check is what established those two
were genuinely new rather than typos.

Also check `json_name_aliases` and `tbl_result` — a fencer with results is not a
new entrant, and their absence from a ranking is a different problem with a
different fix (matching, not insertion).

## Step 2 — the collision that must never become a second row

If a fencer with the **same given name and the same birth year** already exists
under a different surname, stop and raise it with the user before writing.

That is the maiden/married-name case, and it is the one way this procedure creates
lasting damage: two rows for one person split her results across two ranking
entries, and merging them afterwards is far more work than asking once.

Where a shared name and year does turn out to be one person, the remedy is an
**alias** or `fn_merge_fencers(p_survivor INT, p_duplicate INT)` — never a second
row.

**Asking is the whole step. A shared birth year is a coincidence, not evidence.**
Polish veteran fencing has many of them, and the answer is usually that they are
simply two people. `CISZEWSKA Barbara (1974)` and `PILARSKA Barbara (1974)` are
**two different fencers** — that was established with the administrator when
CISZEWSKA was added, and it is settled. Do not re-open it, and do not present a
settled identity as though it were still in doubt: naming a real person as a
possible duplicate is not a neutral act.

Record the outcome in the migration header either way. "Checked against
PILARSKA Barbara 1974 — different fencer, confirmed by the administrator" is worth
as much as flagging a genuine duplicate, because it stops the next session
re-litigating it.

## Step 3 — write the migration

Filename `YYYYMMDDNNNNNN_add_fencer_<surname>.sql`. **Date it today.** A backdated
file that sorts before an already-applied migration makes `supabase migration up`
refuse to run locally until it is committed or removed — that is a real cost paid
on 2026-08-17.

```sql
INSERT INTO tbl_fencer (
    txt_surname, txt_first_name, int_birth_year,
    bool_birth_year_estimated, enum_gender, txt_nationality
)
SELECT 'SURNAME', 'First', 1974, FALSE, 'F', 'PL'
WHERE NOT EXISTS (
    SELECT 1 FROM tbl_fencer
     WHERE upper(txt_surname)    = 'SURNAME'
       AND upper(txt_first_name) = 'FIRST'
       AND int_birth_year        = 1974
);
```

Non-negotiable properties:

- **`bool_birth_year_estimated = FALSE`** — administrator-supplied means confirmed.
  This is the same representation `fn_update_fencer_birth_year(..., p_estimated =>
  FALSE)` writes, and a confirmed BY is sacrosanct downstream: ADR-079 §3 quarantines
  any self-declared value that disagrees with it instead of overwriting. Writing
  FALSE for a year you are not sure of is the expensive mistake here. The column
  defaults to FALSE, so state it explicitly rather than relying on the default.
- **Idempotent, birth-year-qualified `NOT EXISTS`.** A from-scratch bootstrap runs
  migrations *before* `[db.seed]` loads (`supabase/config.toml`), so the file must
  work against an empty table and an already-populated one. Birth-year qualification
  matters because same-surname-same-given-name pairs already exist in this data
  (KRAWCZYK Paweł, MŁYNEK Janusz).
- **Never store the V-category.** It is derived by
  `fn_age_category(p_birth_year INT, p_season_end_year INT)`. Cross-check it in the
  header as a sanity note; do not add a column for it.
- **Only the year.** There is no birth-date column.

## Step 4 — the self-verifying block

End the migration with a `DO` block that re-reads what it just wrote and `RAISE
EXCEPTION`s if anything is off — row missing, birth year not marked confirmed,
gender wrong, or the derived V-cat not what the header claimed.

This is the closest thing this change gets to a test, and it is stronger than a
pgTAP assertion would be: it runs **in every environment at apply time**, not only
on LOCAL. A data migration whose assertion only runs locally proves nothing about
PROD.

Model it on the worked example's `FOR r IN SELECT * FROM (VALUES ...)` loop, which
handles one fencer or several with the same code.

## Step 5 — what does NOT need doing

- **No recompute.** A brand-new fencer has no `tbl_result` rows, so no result can
  move between rankings. `trg_fencer_change_enqueue` is `AFTER UPDATE` only and does
  not fire for an INSERT (verified 2026-08-17).
- **No audit entry.** `trg_audit_fencer` is `AFTER DELETE OR UPDATE`, so the insert
  itself is not audited — the migration file is the record. Say so in the header
  rather than letting a reader assume the audit log covers it.
- `trg_trim_fencer_names` (BEFORE INSERT) normalises whitespace for you.

## Step 6 — gender, stated as the guess it is

With no competition record to cross-check against, gender comes from the given
name. That is a real inference, not a fact — write it as such in the header.
`enum_gender` is nullable and correctable via
`fn_update_fencer_gender(p_fencer_id INT, p_gender enum_gender_type)` (ADR-033).

## Step 7 — apply and deploy

Run `postgrestools check` on the file (the `plpgsql-check` skill), then apply to
LOCAL and confirm the verification block's `RAISE NOTICE` output.

Then the normal path: commit → CI → `deploy-cert` → `deploy-prod` (manual approval).

If the fencer is needed on PROD **before** the next release — the usual reason this
comes up at all — the row may be applied directly to CERT and PROD first, and the
migration then formalises it. That is exactly what the worked example did. It only
works because the file is idempotent: the release workflow re-applies it later and
must be a no-op. Say in the header that this was done, so the next reader knows why
the migration appears to have no effect.

## Header content is the deliverable

Every migration cited here carries a header longer than its SQL, and that is
correct. Record: who supplied the details and when; which environments were checked
and with what prefixes; the V-cat cross-check; the basis for gender; any same-name
collision found *or* explicitly ruled out; whether the rows were already applied to
CERT/PROD; and why no recompute is needed. The SQL is three lines and obvious. The
reasoning is what a future session cannot reconstruct.
