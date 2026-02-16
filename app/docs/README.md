# App Setup Guide

This guide covers local setup for:
- Flutter mobile app (`app/flutter_app`)
- Go API (`app/api`)
- Database migrations (`app/api/migrations`)

## Prerequisites

- Flutter SDK: <https://flutter.dev/docs/get-started/install>
- Android Studio (Android SDK + emulator): <https://developer.android.com/studio>
- Go (for API and migration commands): <https://go.dev/doc/install>

## Local Dev Mode

Current setup uses hosted Supabase services for local development.

- Database/Auth/Storage: Supabase cloud project
- Database access from local machine: Supabase Session Pooler connection string
- Local Docker Postgres is not used in this setup

## 1. Flutter App (Android)

1. Install Flutter and verify:

```bash
flutter doctor
```

2. Create and start an Android emulator in Android Studio (`Device Manager`).

3. Run the Flutter app from repo root:

```bash
cd app/flutter_app
flutter pub get
flutter run
```

## 2. Go API

Run from repo root:

```bash
make -C app api-run
```

Or if your shell is already in `app/`:

```bash
make api-run
```

Other useful targets:

```bash
make -C app api-test
make -C app api-vet
make -C app api-build
```

Inside `app/`, run these without `-C app`:

```bash
make api-test
make api-vet
make api-build
```

## 3. Database Migrations (golang-migrate)

Migration files live in:

```text
app/api/migrations
```

Current initial migration:
- `000001_initial_schema.up.sql`
- `000001_initial_schema.down.sql`

The Makefile auto-loads `app/api/.env.dev` if it exists.
Or set the URL manually in your current shell:

```bash
export DATABASE_URL='postgresql://<user>:<password>@<host>:5432/<db>'
```

Run migrations from repo root:

```bash
make -C app migrate-up
make -C app migrate-version
make -C app migrate-down
```

If your shell is already in `app/`, use:

```bash
make migrate-up
make migrate-version
make migrate-down
```

Notes:
- `migrate-down` rolls back one migration step (`down 1`).
- You can use `DB_URL` instead of `DATABASE_URL` for make targets.
- `postgresql://...` URLs are normalized to `postgres://...` for `golang-migrate`.
- If your DB password has special characters (`!`, `@`, `#`, etc.), URL-encode them in `DATABASE_URL`.

## Troubleshooting

### No `pubspec.yaml file found`

This means `app/flutter_app` is not initialized as a Flutter project yet:

```bash
cd app/flutter_app
flutter create .
flutter pub get
flutter run
```

### `Set DATABASE_URL or DB_URL before running migrations.`

Export `DATABASE_URL` (or `DB_URL`) in the current shell, then rerun the migration command.

Run inside the `app/` directory:

```bash
make migrate-up
make migrate-version
```

From repo root, use:

```bash
make -C app migrate-up
make -C app migrate-version
```

### `failed to open database ... connect: no route to host`

This usually means your network cannot reach Supabase direct DB over IPv6 (`db.<project-ref>.supabase.co:5432`).

Use the Supabase **Session Pooler** connection string (IPv4-friendly) for local migrations:

1. Supabase Dashboard -> `Settings` -> `Database` -> `Connection string`
2. Choose **Session pooler** and copy the URI
3. Put it into `app/api/.env.dev` as `DATABASE_URL=...`

Then run again:

```bash
make migrate-up
make migrate-version
```

### `Dirty database version 1. Fix and force version.`

If migration `1` is marked dirty, reset migration state and re-apply:

```bash
cd app
set -a
source api/.env.dev
set +a

DB_URL="${DATABASE_URL/postgresql:\/\//postgres://}"

go run -tags postgres github.com/golang-migrate/migrate/v4/cmd/migrate@v4.18.3 \
  -path api/migrations -database "$DB_URL" force 1

make migrate-down
make migrate-up
make migrate-version
```
