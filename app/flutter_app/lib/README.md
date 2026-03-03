# Flutter App Architecture

## Folder Conventions
- `app/`: app entry wiring only (routes, theme, providers, shell).
- `core/`: shared infrastructure and reusable UI/constants.
- `data/`: backend-facing DTOs and infrastructure repositories.
- `features/<feature>/`: feature-owned domain, data adapters, controllers, and UI.

## Dependency Rules
- `core` must not import anything from `features`.
- Feature UI must not import UI from other features.
- Cross-feature reusable widgets belong in `core/widgets`.
- App-level composition belongs in `app/` (not inside features).

## State and Routing
- `provider` is the app state mechanism.
- `Navigator`/`MaterialApp` routing is used (no `go_router` in this phase).
- Root providers are created in `app/providers.dart`.
- Route constants/builders are centralized in `app/routes.dart`.

## How To Add A New Feature
1. Create `lib/features/<feature>/domain/models` for feature entities.
2. Add `lib/features/<feature>/data` for feature repository contracts/adapters.
3. Add `lib/features/<feature>/controller` for `ChangeNotifier` state.
4. Add `lib/features/<feature>/view` and `widgets` for presentation.
5. Register required providers in `app/providers.dart`.
6. Add unit tests for controllers/repositories and widget tests for feature flows.

## Stats Controller Decision
- `StatsController` is intentionally not added yet.
- Current stats/account state is simple and local to `UserStatsScreen`.
- Add `StatsController` only when stats interactions become non-trivial.
