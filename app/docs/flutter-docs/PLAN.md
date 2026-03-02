# Flutter Code Structure Plan (Feature-First + Provider + Navigator)

## Summary

Current state is a single large file: `app/flutter_app/lib/main.dart` (~1263 lines, onboarding + feed + stats mixed together).  
Goal is to split into clear modules without over-engineering, keep existing behavior, keep Navigator, and standardize growth with Provider.

## Target Structure

```text
lib/
  main.dart
  app/
    app.dart
    routes.dart
    providers.dart
    theme.dart
    shell/
      main_navigation_shell.dart
  core/
    constants/
      app_colors.dart
      app_spacing.dart
    widgets/
      app_scaffold.dart
    utils/
      formatters.dart
  features/
    onboarding/
      presentation/
        screens/
          onboarding_flow_screen.dart
          splash_screen.dart
          auth_screen.dart
          gender_screen.dart
          age_picker_screen.dart
          weight_picker_screen.dart
        widgets/
          dynamic_scale_picker.dart
          login_clipper.dart
      state/
        onboarding_controller.dart
      domain/
        onboarding_profile.dart
    feed/
      presentation/
        screens/
          feed_screen.dart
          post_detail_screen.dart
        widgets/
          main_header.dart
          weekly_summary_card.dart
          activity_post_card.dart
          who_to_follow_section.dart
          follow_card.dart
          orange_line_painter.dart
      state/
        feed_controller.dart
      domain/
        post.dart
      data/
        feed_repository.dart
        local_feed_repository.dart
    stats/
      presentation/
        screens/
          user_stats_screen.dart
        widgets/
          stat_item.dart
      state/
        stats_controller.dart
      domain/
        user_stats.dart
```

## Dependency Rules (Decision Complete)

- `app/` wires app entry, routes, providers, and shell.
- `features/*/presentation` can depend on that feature’s `state` and `domain`.
- `features/*/state` can depend on that feature’s `domain` and `data`.
- `features/*/domain` has no Flutter/UI dependencies.
- `core/` is shared and must not import from `features/`.
- No cross-feature UI imports; shared UI goes to `core/widgets` only if reused by 2+ features.

## Class Relocation Map

- `RowingApp` -> `app/app.dart`
- `OnboardingCarousel` -> `features/onboarding/presentation/screens/onboarding_flow_screen.dart`
- `SplashScreen`, `AuthScreen`, `GenderScreen`, `AgePickerScreen`, `WeightPickerScreen` -> onboarding `presentation/screens/*`
- `DynamicScalePicker`, `LoginClipper` -> onboarding `presentation/widgets/*`
- `MainNavigationHub` -> `app/shell/main_navigation_shell.dart`
- `FeedScreen`, `PostDetailScreen` -> feed `presentation/screens/*`
- `MainHeader`, `WeeklySummaryCard`, `ActivityPostCard`, `WhoToFollowSection`, `FollowCard`, `OrangeLinePainter` -> feed `presentation/widgets/*`
- `UserStatsScreen`, `StatItem` -> stats `presentation/*`

## Public Interfaces / Types To Add

- `app/routes.dart`: centralized route names (`/onboarding`, `/home`) + route builder map.
- `app/providers.dart`: `MultiProvider` root registration.
- `features/feed/data/feed_repository.dart`: abstract repository contract.
- `features/feed/data/local_feed_repository.dart`: initial local/mock implementation.
- `features/feed/state/feed_controller.dart`: `ChangeNotifier` for feed list + selected post.
- `features/onboarding/state/onboarding_controller.dart`: temporary onboarding state aggregation.
- Domain models:
  - `Post`
  - `UserStats`
  - `OnboardingProfile`

## Migration Phases

1. Create folder skeleton and move only app bootstrap (`main.dart`, `app/app.dart`, `app/theme.dart`).
2. Extract `MainNavigationHub` into `app/shell/`.
3. Extract onboarding flow and all onboarding screens/widgets.
4. Extract feed screens/widgets.
5. Extract stats screen/widgets.
6. Introduce `FeedRepository` + mock local data source.
7. Introduce `FeedController` with Provider and replace ad-hoc local selection logic.
8. Introduce `OnboardingController` to store onboarding selections before navigation to home.
9. Clean imports, remove dead code, enforce one class-per-file for screens and controllers.

## Testing Plan

- Unit tests:
  - `FeedController` loads posts, selects post, clears selection.
  - `OnboardingController` stores/updates profile steps correctly.
  - `LocalFeedRepository` returns expected post list.
- Widget tests:
  - Onboarding flow next/back and finish navigates to home shell.
  - Feed tap opens post detail overlay and close hides it.
  - Bottom nav switches tabs and closes detail overlay.
- Smoke test:
  - App starts, onboarding renders, main shell reachable, no runtime exceptions.

## Acceptance Criteria

- `main.dart` is minimal bootstrap only.
- No feature UI classes remain in `main.dart`.
- Onboarding/feed/stats behavior remains unchanged from current app.
- Route and provider setup are centralized under `app/`.
- New features can be added under `features/<name>/` without touching unrelated features.

## Assumptions and Defaults Chosen

- Keep `provider` (already in dependencies).
- Keep Navigator (no `go_router` migration now).
- Use balanced architecture: strict where useful, avoid boilerplate-heavy clean architecture everywhere.
- Start with local/mock repositories; backend integration can be added later behind repository interfaces.
- Prefer incremental refactor to avoid large risky rewrite.
