# ADR-023: Email Ingestion via Google Apps Script + Supabase Storage

**Status:** Accepted
**Date:** 2026-04-05 (Go-to-PROD)

## Context

Domestic PPW/MPW tournament results arrive as FencingTime Live XML files, typically emailed as `.zip` archives to `spws.weterani@gmail.com` by the tournament organizer. The system needs an automated path from email attachment to the ingestion pipeline, with an admin upload form as backup.

Key constraints:
- Email is the primary delivery mechanism (organizer workflow)
- The ingestion pipeline runs in GitHub Actions (Python)
- Supabase free tier provides 1 GB file storage
- Files must be archived for audit trail / re-import capability
- Storage should be space-efficient (compressed archives)

## Decision

Use **Google Apps Script (GAS)** to poll the Gmail inbox and **Supabase Storage** as the staging/archive layer.

### Flow

```
Email (.zip) → Gmail → GAS (polls every 5 min)
  → uploads original .zip to Supabase Storage: xml-inbox/staging/{timestamp}_{filename}.zip
  → triggers GitHub Actions ingest.yml via workflow_dispatch API
  → ingest.yml downloads .zip → decompresses in memory → processes each XML
  → on success: moves .zip to archive/{season}/{event}.zip, deletes staging files
  → compresses previous event's unzipped XMLs (only latest event kept unzipped)
```

### Archive Strategy

- Email arrives compressed (`.zip`) — GAS uploads the original `.zip` to `staging/`
- Pipeline decompresses in memory for processing, never writes extracted XMLs to Storage
- On success: `.zip` moved to `archive/{season}/{event}.zip`
- Only the most recent event's XMLs are kept unzipped in `current/` for quick re-inspection
- Previous events' unzipped XMLs (if any in `current/`) are deleted when a new event arrives
- Staging is cleaned after every successful run

### Storage Budget

- Compressed zips average ~30–50 KB per event (17 XMLs)
- Full season (~8 events) = ~400 KB compressed
- 100 seasons = ~40 MB — well within the 1 GB free tier limit

### GAS Script Configuration (Script Properties)

- `SUPABASE_URL` — project URL
- `SUPABASE_SERVICE_ROLE_KEY` — for Storage uploads (bypasses RLS on bucket)
- `GITHUB_PAT` — personal access token for workflow_dispatch
- `GITHUB_REPO` — `owner/SPWSranklist`

### Supabase Storage Setup

- Bucket: `xml-inbox` (private, not public)
- Folders: `staging/` (incoming .zips), `archive/{season}/` (post-import .zips), `current/` (latest event unzipped XMLs)
- RLS: service_role can read/write; authenticated (admin) can read archive

## Alternatives Considered

1. **Gmail API from GitHub Actions** — A scheduled cron job uses Python `google-auth` + Gmail API to poll the inbox directly. Avoids GAS dependency but requires OAuth2 refresh token management in GitHub Secrets, which is fragile (tokens expire, need manual rotation).

2. **GAS → GitHub repo push** — GAS commits XML files to an `inbox/` directory via GitHub API. Git history serves as archive. But binary files bloat the repo, `git clone` slows down over time, and mixing data with code is poor separation.

3. **Admin upload form only** — No email automation; admin downloads attachment manually and uploads via the web UI. Simplest but defeats the automation goal and adds manual steps every tournament.

4. **SFTP / cloud folder sync** — Operator drops files in a shared folder. Requires SFTP server setup, operator training, and a polling mechanism. More infrastructure than GAS.

## Consequences

- Email delivery (the organizer's existing workflow) triggers ingestion automatically
- Admin upload form remains as a backup for edge cases (email not received, manual re-import)
- GAS is outside the main repo — stored as `scripts/gas_email_ingestion.js` for reference but deployed separately
- GAS needs `SUPABASE_SERVICE_ROLE_KEY` (a privileged credential) — stored in Script Properties, not in code
- Storage costs are negligible (~40 MB per 100 seasons vs. 1 GB limit)
- Archive `.zip` files enable re-import without digging through email
- `PROCESSED` Gmail label prevents double-processing of the same email
