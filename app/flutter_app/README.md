# Flutter App

Mobile client for the Gondolier rowing project.

## Prerequisites

- Flutter SDK (matching project Dart SDK constraints in `pubspec.yaml`)
- A Supabase project for authentication

## Run Locally

From `app/flutter_app`, run with required runtime config:

```bash
flutter run \
  --dart-define=API_BASE_URL=http://localhost:8080 \
  --dart-define=SUPABASE_URL=https://<project-ref>.supabase.co \
  --dart-define=SUPABASE_ANON_KEY=<anon-key> \
  --dart-define=USE_LOCAL_FEED_FALLBACK=true
```

`API_BASE_URL`, `SUPABASE_URL`, and `SUPABASE_ANON_KEY` are required by `RuntimeConfig`.

## Authentication Flow

- On app startup, Supabase is initialized in `lib/main.dart`.
- `RowingApp` in `lib/app.dart` reads `auth.currentSession` and listens to `onAuthStateChange`.
- If onboarding is complete and a session exists, the user is routed to `MainNavigationHub`.
- Without a session, the user sees `AuthScreen`, which contains:
  - `LoginScreen` using `signInWithPassword`
  - `SignUpScreen` using `signUp`
- Sign-up handles both Supabase outcomes:
  - Immediate session created: user is treated as logged in
  - Email confirmation required: user sees an info message to verify email

## Tests

Run all tests:

```bash
flutter test
```

Static analysis:

```bash
flutter analyze
```
