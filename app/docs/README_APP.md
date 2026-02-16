# App Local Setup Notes

This file records the current app local development setup.
For full step-by-step commands, see `app/docs/README.md`.

## Current Local Dev Approach

- Use hosted Supabase (cloud) for database, auth, and storage.
- Use Supabase Session Pooler connection string for local migrations.
- No local Postgres container is required right now.

## Migration Quick Check

From repo root:

```bash
make -C app migrate-version
```

From `app/` directory:

```bash
make migrate-version
```
