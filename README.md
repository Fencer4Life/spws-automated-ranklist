# SPWS Automated Ranklist System

SPWS automates competition results, identity resolution, scoring and public rankings for the Polish Veterans Fencing Association (Stowarzyszenie Polskich Weteranów Szermierki). It combines a Svelte frontend, Python ingestion and operations tooling, PostgreSQL/Supabase domain logic, and GitHub Actions automation across LOCAL, CERT and PROD.

## Start here

- [Developer handbook](doc/handbook/index.html) — business domain, product, current architecture, subsystems and operations
- [Documentation map](doc/handbook/documentation-map.html) — top-down ownership map from implementation areas to canonical pages
- [Architecture Decision Records](doc/adr/index.html) — rationale for durable choices
- [Requirements and governance](doc/governance/index.html) — specification, traceability and formal rules
- [Repository documentation gateway](doc/index.html) — evidence and historical material in addition to current docs

## Live surfaces

- [CERT](https://fencer4life.github.io/spws-automated-ranklist/)
- [Admin UI](https://fencer4life.github.io/spws-automated-ranklist/?admin=1)

## Local development

Prerequisites and exact commands are maintained in the [local development guide](doc/handbook/operations/local-development.html). The safe starting loop is:

```bash
supabase start
./scripts/reset-dev.sh
source .venv/bin/activate
python -m pytest python/tests/ -v
cd frontend && npm test && npm run check
```

Never run a bare `supabase db reset`; the repository wrapper preserves required LOCAL behavior.

## Documentation changes

Human-facing project documentation is HTML. Follow the [documentation standard](doc/handbook/reference/documentation-standard.html) and run:

```bash
python scripts/check_docs.py
python scripts/render_adrs.py --check
python scripts/render_docs.py --check
```

The handbook describes how the system works now. ADRs explain why, governance records what must be true, evidence records particular runs, and the archive preserves superseded narratives.

## License

Public repository.
