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
- [ ] Choose migrations tool (e.g., `golang-migrate`)
- [ ] Add initial migration files

## Auth (Supabase Auth)
- [ ] Decide JWT validation method in Go (JWKS vs shared secret)
- [ ] Add auth middleware in Gin
- [ ] Define user session flow in Flutter (sign up, sign in, sign out, refresh)

## API Contract
- [ ] Define core endpoints: users, workouts, sessions, feed, metrics, files
- [ ] Create OpenAPI/Swagger or shared DTOs
- [ ] Add request/response validation

## Realtime (WebSockets)
- [ ] Pick WebSocket library for Go
- [ ] Define events/channels (live feed, status, notifications)
- [ ] Secure socket handshake with JWT

## Storage (Supabase Storage)
- [ ] Create buckets (avatars, workout-images)
- [ ] Define access policies
- [ ] Add upload/download endpoints and signed URL handling

## Flutter App
- [ ] Set up app flavors/configs (dev/prod)
- [ ] Add Supabase client + auth screens
- [ ] Add networking layer (Dio/Chopper/Retrofit)
- [ ] Add basic navigation shell

## Hosting + CI/CD
- [x] Choose hosting target (Fly.io or Render)
- [ ] Add build/deploy pipelines for Go API
- [ ] Add lint/test workflows for Go + Flutter

## Local Dev
- [ ] Decide local dev approach (hosted Supabase vs local)
- [ ] Add docker-compose if local DB is needed
- [ ] Document setup steps in README_APP.md
