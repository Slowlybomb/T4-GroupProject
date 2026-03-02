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

## Milestone Checklist

## 1. Baseline and Safety

- [ ] Create a refactor branch (`refactor/flutter-feature-structure`).
- [ ] Capture baseline behavior video/screenshots for onboarding, feed, detail overlay, and stats tab.
- [ ] Add/confirm a smoke test that app boots and renders initial onboarding screen.
- [ ] Define “no behavior regression” rule for this refactor.

## 2. Folder Skeleton and Bootstrap Split

- [ ] Create `lib/app`, `lib/core`, and `lib/features` directory tree.
- [ ] Move app root widget from `main.dart` into `lib/app/app.dart`.
- [ ] Keep `lib/main.dart` as bootstrap-only entrypoint.
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

## Acceptance Criteria

- [ ] `lib/main.dart` contains only bootstrap/setup.
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
- Use local/mock repository implementations only (no backend integration in this phase).
- One-class-per-file rule applies to screens, controllers, repositories, and models.
