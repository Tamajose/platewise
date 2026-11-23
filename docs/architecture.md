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
  core/                 # config, failure types, networking client, shared utilities
  features/<feature>/
    domain/             # entities, repository interfaces, use cases (pure Dart)
    data/               # DTOs, mappers, data sources, repository implementations
    presentation/       # screens, widgets, Riverpod controllers
```

**Dependency rule.** `presentation` depends on `domain`. `data` depends on `domain`. `domain` depends on neither, and imports no Flutter, Supabase or platform packages. An architecture test enforces this.

**State management.** Riverpod. Screen state lives in `Notifier` and `AsyncNotifier` controllers that call use cases. Widgets render state and forward user actions.

**Demo and live modes.** Demo and live behaviour are two implementations of the same repository interfaces. `main.dart` is the composition root and selects one at startup through `ProviderScope` overrides.

**Errors.** The domain defines a `Failure` type. Data sources translate transport and provider errors into failures, and the presentation layer maps failures to messages.

## Backend

The Edge Function stays thin: handler, then validation, then pure domain logic, then provider adapters behind interfaces. Contracts are versioned (API v1).

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
| F1 | Flutter | App scaffold |
| D1 | Design | Theme, tokens, fonts and design-system docs |
| D2 | Design | Shared component library |
| F2 | Flutter | Domain core |
| F3 | Flutter | Data core and composition root |
| F4 | Flutter | Meal logging (the reference slice) |
| F5–F12 | Flutter | Decide, nearby, today, water, weekly, onboarding, settings, auth |
| D3 | Design | Web assets and UX pass |
| W1 | Shared | Final docs, web demo launcher, Playwright browser checks and verification |
