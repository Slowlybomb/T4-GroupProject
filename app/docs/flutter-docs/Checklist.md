# Team Checklist: Flutter Architecture Refactor (Feature-First, Provider, Navigator)

## Summary

Refactor the current monolithic Flutter codebase (`lib/main.dart`) into a scalable feature-first structure without changing user-visible behavior.  
Success means: same onboarding/feed/stats behavior, cleaner boundaries, centralized app wiring, and passing tests.

## Public Interfaces / Types To Add or Change

- [ ] Add `AppRoutes` constants in `lib/app/routes.dart` for `/onboarding` and `/home`.
- [ ] Add `createAppProviders()` in `lib/app/providers.dart` returning root providers.
- [ ] Add `FeedRepository` interface in `lib/features/feed/data/feed_repository.dart`.
- [ ] Add `LocalFeedRepository` implementation in `lib/features/feed/data/local_feed_repository.dart`.
- [ ] Add `FeedController` (`ChangeNotifier`) with APIs: `loadPosts()`, `selectPost(Post post)`, `clearSelectedPost()`.
- [ ] Add `OnboardingController` (`ChangeNotifier`) with APIs: `setGender(...)`, `setAge(...)`, `setWeight(...)`, `buildProfile()`.
- [ ] Add domain models: `Post`, `UserStats`, `OnboardingProfile`.

### Server Connection Interfaces Added (2026-03-02)

- [x] Add `RuntimeConfig` in `lib/core/config/runtime_config.dart` using `API_BASE_URL`, `SUPABASE_URL`, `SUPABASE_ANON_KEY`.
- [x] Add `AuthTokenProvider` (`SupabaseAuthTokenProvider`) in `lib/core/network/auth_token_provider.dart`.
- [x] Add `ApiClient` (Dio wrapper) in `lib/core/network/api_client.dart`.
- [x] Add `AuthInterceptor` in `lib/core/network/auth_interceptor.dart` with public health-route bypass.
- [x] Add `ApiError` mapper in `lib/core/network/api_error.dart`.
- [x] Add `ActivityDto` and `CreateActivityRequestDto` in `lib/data/models/`.
- [x] Add `ActivityApiRepository` contract in `lib/data/repositories/activity_api_repository.dart`.
- [x] Add `DioActivityApiRepository` implementation in `lib/data/repositories/dio_activity_api_repository.dart`.
- [x] Update `FeedRepository` to use `ActivityApiRepository` with optional local fallback.
- [x] Add `AppDependencies` wiring in `lib/core/locator.dart`.

## Milestone Checklist

## 1. Baseline and Safety

- [ ] Create a refactor branch (`refactor/flutter-feature-structure`).
- [ ] Capture baseline behavior video/screenshots for onboarding, feed, detail overlay, and stats tab.
- [ ] Add/confirm a smoke test that app boots and renders initial onboarding screen.
- [ ] Define “no behavior regression” rule for this refactor.

## 2. Folder Skeleton and Bootstrap Split

- [ ] Create `lib/app`, `lib/core`, and `lib/features` directory tree.
- [ ] Move app root widget from `main.dart` into `lib/app/app.dart`.
- [x] Keep `lib/main.dart` as bootstrap-only entrypoint.
- [ ] Extract theme to `lib/app/theme.dart`.
- [ ] Ensure app still runs with identical startup route.

## 3. App Shell and Navigation Extraction

- [ ] Move `MainNavigationHub` into `lib/app/shell/main_navigation_shell.dart`.
- [ ] Create `lib/app/routes.dart` and centralize route declarations/builders.
- [ ] Keep Navigator flow (no `go_router` migration in this phase).
- [ ] Ensure tab switching still resets feed detail overlay exactly as before.

## 4. Onboarding Feature Module

- [ ] Move onboarding screens into `lib/features/onboarding/presentation/screens/`.
- [ ] Move onboarding-specific widgets (`DynamicScalePicker`, `LoginClipper`) into `presentation/widgets/`.
- [ ] Keep page-flow logic behavior unchanged during initial move.
- [ ] Introduce `OnboardingController` and wire it via Provider.
- [ ] Use `OnboardingProfile` domain model to collect onboarding output.

## 5. Feed Feature Module

- [ ] Move feed screens into `lib/features/feed/presentation/screens/`.
- [ ] Move feed UI components into `lib/features/feed/presentation/widgets/`.
- [ ] Add `Post` domain model and replace hardcoded view-only state where needed.
- [ ] Add `FeedRepository` contract and `LocalFeedRepository` mock/local implementation.
- [ ] Add `FeedController` and migrate post selection/detail visibility logic to controller-driven state.

## 6. Stats Feature Module

- [ ] Move stats screen and `StatItem` into `lib/features/stats/presentation/`.
- [ ] Add `UserStats` domain model and connect current display data through typed model.
- [ ] Add `StatsController` only if state is non-trivial; otherwise keep local state and document decision.

## 7. Shared Core and Dependency Hygiene

- [ ] Move reusable constants into `lib/core/constants/`.
- [ ] Move truly reusable widgets into `lib/core/widgets/` (only if used in 2+ features).
- [ ] Enforce dependency rule: `core` must not import from `features`.
- [ ] Enforce no cross-feature UI imports.
- [ ] Run import cleanup and remove dead code from `main.dart`.

## 8. Testing and Quality Gate

- [ ] Unit test `FeedController`: load/select/clear behaviors.
- [ ] Unit test `OnboardingController`: step updates and profile build.
- [ ] Unit test `LocalFeedRepository`: returns expected post list.
- [ ] Widget test onboarding next/back and finish navigation.
- [ ] Widget test feed post tap opens detail and close hides it.
- [ ] Widget test bottom nav tab switch closes detail overlay.
- [ ] Run `flutter analyze` and ensure no new warnings introduced by refactor.
- [ ] Run full test suite and require green before merge.

## 9. Documentation and Team Handoff

- [ ] Add `lib/README.md` describing folder conventions and dependency rules.
- [ ] Add “How to add a new feature” section with required files and naming.
- [ ] Update project docs with new architecture diagram and state flow notes.
- [ ] Add PR checklist item: “Any new code follows feature-first structure”.

## 10. Server Connection Ownership Slice (Activities Core)

- [x] Lock backend source-of-truth endpoints to implemented Go routes (`/api/v1/activities*`) and document OpenAPI mismatch.
- [x] Initialize Supabase in app bootstrap and validate required `--dart-define` config at startup.
- [x] Add token injection via auth-aware Dio interceptor for protected endpoints.
- [x] Implement activities API calls: list/create/get/like.
- [x] Add typed API DTO parsing with nullable handling and UI-model adapter mapping.
- [x] Add fallback behavior toggle (`USE_LOCAL_FEED_FALLBACK`) for demo/offline mode.
- [x] Add backend-connection tests for interceptor behavior, DTO parsing, and repository error mapping.
- [x] Run Flutter tests for this slice and keep them green.

## Acceptance Criteria

- [x] `lib/main.dart` contains only bootstrap/setup.
- [ ] No onboarding/feed/stats UI classes remain in `main.dart`.
- [ ] Existing behavior is unchanged for onboarding, feed detail overlay, and stats navigation.
- [ ] Route and provider setup are centralized under `lib/app/`.
- [ ] New feature scaffolding can be added without touching unrelated feature folders.

## Test Scenarios (Explicit)

- [ ] Fresh launch opens onboarding first screen.
- [ ] Onboarding next/back works and finish enters home shell.
- [ ] Feed list renders and post tap opens detail overlay.
- [ ] Closing detail returns to feed state.
- [ ] Switching tab from feed to stats closes any open detail.
- [ ] Returning to feed preserves expected feed UI state.

## Assumptions and Defaults

- Keep `provider` as the state management solution for now.
- Keep Navigator-based routing in this refactor.
- Prioritize incremental moves over big-bang rewrites.
- Activities core now supports backend integration via Dio + Supabase access tokens.
- File upload/download and WebSocket integration are deferred to phase 2.
- Keep `USE_LOCAL_FEED_FALLBACK` for optional local/demo feed fallback.
- One-class-per-file rule applies to screens, controllers, repositories, and models.
