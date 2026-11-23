# Architecture

This page describes the target architecture for the migrated repository. The detailed backend, data-flow, nutrition and AI sections from the original prototype are reintroduced as their code lands, and completed in the final wrap-up step.

## Repository layout

| Path | Owner | Contents |
|---|---|---|
| `app/` | Flutter | The Flutter application for web, Android and iOS |
| `supabase/` | AI and backend | PostgreSQL migrations, RLS, SQL tests and the `platewise` Edge Function |
| `tools/`, `testdata/` | AI and backend | Evaluation, metrics and smoke-test scripts, and fixtures |
| `docs/` | Shared | Architecture, decisions, contracts, deployment and status |

The Dart models, Deno schemas and SQL migrations share one API contract. A contract change touches all three.

## Flutter app: feature-first clean architecture

```
app/lib/
  main.dart             # composition root: picks demo or live, sets provider overrides
  app/                  # application shell: MaterialApp, go_router configuration
  core/
    domain/             # entities, Failure and repository interfaces shared by two or more features
    data/               # API client, auth session, demo store, JSON mappers, session and overview repositories
    presentation/       # shared providers (overview, capabilities) and failure messages
    theme/, widgets/    # design system (owned by Design)
    config/             # build-time configuration
  features/<feature>/
    domain/             # entities, repository and service interfaces, use cases (pure Dart)
    data/               # DTOs, mappers, data sources, repository implementations, providers
    presentation/       # screens, widgets, Riverpod controllers and their providers
```

### Rules

**1. Dependency rule.** `presentation` depends on `domain`. `data` depends on `domain`. `domain` depends on neither, and imports no Flutter, Supabase or platform packages. Features never import each other, and `core/` never imports a feature. Only `main.dart` and `app/` may import several features. `core/data` and `core/presentation` follow the same layer rules as a feature's `data/` and `presentation/`. The one exception to "presentation depends only on domain" is that presentation may import `data/` files named `*_providers.dart`, because rule 3 puts repository providers there. Domain may import only pure Dart (`dart:async`, `dart:collection`, `dart:math`, `dart:typed_data`) and the packages `collection`, `meta` and `timezone`. The architecture test in `app/test/architecture/` enforces these rules, and its own tests show that it catches each kind of violation.

**2. Shared entities.** A type starts in the `domain/` of the feature that owns it. It moves to `core/domain/` only when a second feature needs it.

**3. Providers.** `domain/` contains no Riverpod. Repository providers live in `data/` and throw by default. `main.dart` overrides them with the live or demo implementation. Controllers and their providers live in `presentation/`. Demo and live behaviour are two implementations of the same interfaces.

**4. App-level concerns.** The session (bootstrap, capabilities, demo or live mode), the overview snapshot, photo storage, the photo picker and the review screen's arguments live in `core/`, not in a feature. Every feature depends on them, and `core/` may not depend on a feature, so putting them in a feature would force the others to import it. Accounts belong to the auth feature.

**5. Use cases.** A use case exists only for real, testable logic: ranking and budget fit, weekly aggregation, distance, energy estimation and validation. A controller calls a repository directly for plain reads and writes. This is a deliberate, pragmatic deviation from strict clean architecture, so a use case that only forwards one repository call is not added.

**6. Routing.** `go_router` is configured in `app/`. Routes reference screens only. `app/` is the one layer allowed to import every feature's presentation.

**7. Platform services.** Camera, microphone and location sit behind an interface in the feature's `domain/`. The implementation lives in that feature's `data/`, and tests use fakes.

**8. State.** Riverpod. Screen state lives in `Notifier` and `AsyncNotifier` controllers. Widgets render state and forward user actions.

**9. Errors.** The domain defines `Failure` types. Data sources translate transport and provider errors into failures. The presentation layer maps failures to messages.

### Where the domain types live

Placement follows rule 2: a type is shared only when more than one feature uses it.

| Location | Types and rules |
|---|---|
| `core/domain/` | `CalorieRange`, `Nutrient` and `nutrientTotals`, `FoodItem`, `MealDraft`, `SavedMeal`, `MealSource`, `Confidence`, `Profile`, the target policy, `Overview`, `DayLog`, `WaterEntry`, `TargetSnapshot`, `BudgetFit`, `distanceKm`, date helpers, and `Failure` |
| `features/comparison/domain/` | `compareFit`, `fitReason`, `MenuOption`, `DecisionOption`, `RankedMeal`, `DecisionResult` |
| `features/nearby/domain/` | `NearbyMeal` |
| `features/weekly/domain/` | `WeeklyReport`, `WeeklySummary` |
| `features/settings/domain/` | `calculateEnergy`, `EnergyEstimate`, `Correction` |
| `features/auth/domain/` | `AccountInfo` |
| `core/domain/` (photos) | `PhotoPicker`, `PhotoSource` and `MediaStorage`, used by meal logging and menu scanning |
| `features/meal_logging/domain/` | `MealLogRepository`, `VoiceRecorder`, `SpeechTranscriber`, and the food entry rules (`buildFood`, `canLogMeal`, limits) |
| `core/presentation/` | `failureMessage`, which turns a `Failure` into text for people; `ReviewArgs` and `Routes`, so every feature can open the review screen without importing meal logging |

`core/domain/` also holds the `SessionRepository` and `OverviewRepository` interfaces and the `Capabilities` type.

Entities carry no JSON. Converting to and from the API's wire format is a data-layer job, done by mappers. The wire names that mappers need, such as `Nutrient.key`, stay on the entity. `Overview.today` still reads the system clock, so tests set `localDay` instead.

### Data core

| Piece | Role |
|---|---|
| `ApiClient` | Calls the versioned API with the session token. Every outcome is data or a `Failure`, including timeouts, offline and protocol errors. |
| `AuthSession` | The session as data sources see it: user ID, opening an anonymous session, a fresh token. `SupabaseAuthSession` is the live implementation. |
| `DemoStore` | One `Overview` kept in local preferences. Every feature's demo repository reads and changes it, so changes in one feature show in the others. Updates are serialized. |
| Mappers | JSON to entities and back for the shared types, in `core/data/mappers/`. Each feature adds its own mappers in its `data/`. |
| `composeOverrides` | In `app/composition.dart`. Chooses demo or live and returns the provider overrides. Each feature's step adds its repository here. `main.dart` only starts the app with them. |

`test/core/data/contract_test.dart` reads the SQL migrations and checks the Dart side against them: nutrient keys, food units, meal sources, confidence levels, profile and meal columns, and the target bounds.

## Backend

The target is a thin handler (the application layer) that validates a request, calls pure domain logic, and reaches infrastructure through interfaces:

- **Domain:** pure logic such as ranking, progress, redaction and contracts, with no network or database access.
- **Infrastructure:** the Supabase client, RPC calls, storage and caching.
- **Providers:** the AI adapters behind interfaces.

The migrated code does not yet follow this. For example, `decision.ts` imports `http.ts`, and `http.ts` mixes client creation, RPC calls, caching and image handling. Step B6 restructures it, with the existing tests as the safety net and an import-scanning test to enforce the layering. Contracts are versioned (API v1).

## Migration plan

Each step is one branch and one pull request.

| Step | Area | Contents |
|---|---|---|
| P0 | Shared | Repository foundation |
| B1 | Backend | Database: migrations, seed and SQL tests |
| B2 | Backend | Contracts, AI providers, HTTP, privacy and progress modules |
| B3 | Backend | Decision logic and audio handling |
| B4 | Backend | Edge Function handler, integration tests and environment example |
| B5 | Backend | Evaluation and API smoke tooling, seed generator, fixtures, and the API, evaluation and deployment docs |
| F1 | Flutter | App scaffold: platform folders, web shell and icons, dependencies, strict analysis, placeholder app, CI job, architecture rules, menu seed asset |
| D1 | Design | Theme, tokens, fonts and design-system docs |
| D2 | Design | Shared component library: `plate_widgets.dart` split into files by family, number formatting helper, widget tests. `ConfidenceBadge` is deferred to F2/F4 because it depends on the `Confidence` domain type |
| F2 | Flutter | Domain layer: shared entities in `core/domain`, feature-owned entities and logic in each feature's `domain/`, the `Failure` type, the architecture test, and domain tests. JSON conversion is left out of entities on purpose |
| F3 | Flutter | Data core: API client, auth session, demo store, JSON mappers for the shared entities, session and overview repositories (demo and live), the testable composition root, and a contract test against the SQL migrations |
| F4 | Flutter | Meal logging (the reference slice): capture by photo, text or voice, review and edit, save. Adds the photo picker and media storage to the core, `ConfidenceBadge`, the router, and a temporary start screen for trying it |
| F5–F12 | Flutter | Decide, nearby, today, water, weekly, onboarding, settings, auth |
| D3 | Design | UX, accessibility and copy review of the finished app (the web shell and icons arrive in F1) |
| B6 | Backend | Restructure the Edge Function into domain, infrastructure, providers and handler layers, with an import-scanning test |
| W1 | Shared | Final docs, web demo launcher, Playwright browser checks and verification |
