# App Local Setup Notes

## Links to services

["Supabase" Database](https://supabase.com/dashboard/project/jbctntbyagqowvfegren)

["Render" Hosting Platform](https://link-url-here.org)

This file records the current app local development setup.
For full step-by-step commands, see `app/docs/README.md`.

## Current Local Dev Approach

- Use hosted Supabase (cloud) for database, auth, and storage.
- Use Supabase Session Pooler connection string for local migrations.
- No local Postgres container is required right now.

## Go API Env Snapshot (`app/api/.env.dev`)

Required:
- `DATABASE_URL` (or `DB_URL`)
- `SUPABASE_JWKS_URL`

Optional:
- `SUPABASE_URL` (used to derive JWT issuer if `JWT_ISSUER` is not set)
- `SUPABASE_SERVICE_ROLE_KEY` (required for `/api/v1/files/upload-url` and `/api/v1/files/download-url`)
- `JWT_ISSUER`
- `JWT_AUDIENCE` (default: `authenticated`)
- `PORT` (default: `8080`)

## API Quick Check

From repo root:

```bash
make -C app api-run
```

Build + start binary:

```bash
make -C app api-build
make -C app api-start
```

Built binary path: `app/api/bin/server`.

## Migration Quick Check

From repo root:

```bash
make -C app migrate-version
```

From `app/` directory:

```bash
make migrate-version
```

## Storage Policy Notes (Supabase Storage)

- Buckets `avatars` and `workout-images` are private (`public = false`).
- Object keys must start with the authenticated user UUID: `<user_uuid>/...`.
- Example keys:
  - `avatars/<user_uuid>/profile.jpg`
  - `workout-images/<user_uuid>/<activity_uuid>/img-1.jpg`
- Backend signed upload/download endpoints must validate the `<user_uuid>/` prefix because service-role operations bypass RLS.
- Signed URL API endpoints:
  - `POST /api/v1/files/upload-url`
  - `POST /api/v1/files/download-url`

## Testing Quick Check

From repo root:

```bash
# Go API tests (main.go + helpers)
cd app/api
go test ./...
go vet ./...
go build ./cmd/server

# Flutter checks
cd ../flutter_app
flutter pub get
flutter analyze
flutter test
```
