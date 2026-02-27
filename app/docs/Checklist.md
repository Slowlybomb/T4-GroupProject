# Project Setup Checklist

## Repo + Tooling

- [x] Confirm repo structure: `app/` (Flutter) and `app/api/` (Go backend)
- [x] Add root `README` with local dev steps
- [x] Add root `Makefile` or task runner for build/run/test

## Environment Config

- [x] Create `.env.example` for Go API
- [x] Create `.env.example` or config template for Flutter
- [x] Define required vars: Supabase URL, anon key, service role key (server only), DB URL, JWT secret/JWKS

## Database (Supabase Postgres)

- [x] Create Supabase project
- [x] Define schema: users, workouts, sessions, metrics, social/feeds
- [x] Choose migrations tool: `golang-migrate`
- [x] Add initial migration files

## Auth (Supabase Auth)

- [x] Decide JWT validation method in Go (JWKS vs shared secret)
- [x] Add auth middleware in Gin
- [x] Define user session flow in Flutter (sign up, sign in, sign out, refresh)
  - Sign up: call `supabase.auth.signUp(email, password)`; if email confirmation is enabled, prompt user to verify email before first login.
  - Sign in: call `supabase.auth.signInWithPassword(...)`; on success route to the authenticated app shell.
  - Session on app launch: call `supabase.auth.getSession()`; if no valid session exists, send user to auth screens.
  - Refresh token: rely on Supabase auto-refresh and `onAuthStateChange`; always read the latest access token before protected API calls.
  - Sign out: call `supabase.auth.signOut()`; clear in-memory user/app state and return to auth screens.
  - Go API usage: send `Authorization: Bearer <access_token>`; backend derives `user_id` from JWT `sub` only.

## API Contract

- [x] Define core endpoints: users, workouts, sessions, feed, metrics, files
- [x] Create OpenAPI/Swagger or shared DTOs
- [x] Add request/response validation

## Realtime (WebSockets)

- [x] Pick WebSocket library for Go
- [ ] Define events/channels (live feed, status, notifications)
- [ ] Secure socket handshake with JWT

## Storage (Supabase Storage)

- [x] Create buckets (avatars, workout-images)
- [x] Define access policies
- [x] Add upload/download endpoints and signed URL handling

## Flutter App

- [ ] Set up app flavors/configs (dev/prod)
- [ ] Add Supabase client + auth screens
- [ ] Add networking layer (Dio/Chopper/Retrofit)
- [ ] Add basic navigation shell

## Hosting + CI/CD

- [x] Choose hosting target (Fly.io or Render)
- [x] Add build/deploy pipelines for Go API
- [x] Add lint/test workflows for Go + Flutter

## Local Dev

- [x] Decide local dev approach (hosted Supabase with Session Pooler)
- [x] Add docker-compose if local DB is needed (N/A: local DB not used in current setup)
- [x] Document setup steps in `app/docs/README_APP.md`
