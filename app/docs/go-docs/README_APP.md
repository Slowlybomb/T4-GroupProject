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

## Implemented Endpoints (Current Backend Source of Truth)

Flutter integration should use currently implemented Go routes:

- `GET /health` (public)
- `GET /api/v1/health` (public)
- `GET /api/v1/activities` (auth required)
  - supports `scope=following|global|friends` (default: `following`)
- `POST /api/v1/activities` (auth required)
- `GET /api/v1/activities/:id` (auth required)
- `PATCH /api/v1/activities/:id/like` (auth required)
- `PUT /api/v1/follows/:user_id` (auth required)
- `DELETE /api/v1/follows/:user_id` (auth required)
- `GET /api/v1/follows/suggestions` (auth required)
- `GET /api/v1/metrics/summary` (auth required, requires `from` and `to` RFC3339 query params)
- `POST /api/v1/files/upload-url` (auth required)
- `POST /api/v1/files/download-url` (auth required)
- `GET /api/v1/ws` (auth required)

OpenAPI note:
- `app/api/openapi.yaml` now includes the current feed-related source-of-truth routes
  (`/activities`, `/follows`, `/metrics/summary`) used by Flutter.

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

## Realtime WebSocket Notes

- Realtime endpoint: `GET /api/v1/ws` (JWT required via `Authorization: Bearer <access_token>` on handshake).
- Supported channels:
  - `feed` (event: `activity.created`)
  - `status` (events: `ws.connected`, `subscription.updated`, `status.heartbeat`, `error`)
  - `notifications` (event: `notifications.placeholder`)
- Client subscribe format:

```json
{"action":"subscribe","channels":["feed","status"]}
```

- Server event envelope format:

```json
{"channel":"feed","type":"activity.created","timestamp":"2026-02-27T17:00:00Z","payload":{}}
```

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

## One-Off Import: Rowing Assets to Activities

Use this script to import the 4 rowing CSV asset sessions as real activities
for a user account via authenticated API calls (no direct SQL):

```bash
API_BASE_URL=https://t4-groupproject.onrender.com \
SUPABASE_URL=https://jbctntbyagqowvfegren.supabase.co \
SUPABASE_ANON_KEY=eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImpiY3RudGJ5YWdxb3d2ZmVncmVuIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njk1MTA0NTMsImV4cCI6MjA4NTA4NjQ1M30.q9RFd9ltQtgK5gS5BrgGpnsMr1rz9ObYhqRP_0ajMGg \
IMPORT_EMAIL=slyusar.gleb.ua@gmail.com \
IMPORT_PASSWORD=123456 \
EXPECTED_UID=c7dd9047-bbac-4d28-a3eb-a877326892ab \
python3 app/scripts/import_rowing_sessions.py
```

Dry-run mode (parses assets and derives payloads only, no network requests):

```bash
python3 app/scripts/import_rowing_sessions.py --dry-run
```
