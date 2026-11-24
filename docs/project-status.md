# PlateWise project status

The PlateWise prototype has been migrated, step by step, into this repository with a clean architecture for the Flutter app and a layered backend. The [architecture](architecture.md) lists every step. All of them are done.

| Area | State | Verification boundary |
|---|---|---|
| Database | Three migrations with row-level security, seed data and SQL tests | Run in CI against a local Supabase stack. Not run against a hosted project |
| Backend | Edge Function in five layers (handler, application, infra, providers, domain). OpenAI and Groq adapters, with a provider per capability. A test enforces the layering | 33 Deno tests with injected provider responses. No call to a real provider or a deployed function |
| Flutter app | Feature-first clean architecture: meal logging, decide, nearby, today, water, progress, onboarding and profile, settings and accounts. Demo and live implementations of every repository | 386 unit, widget, accessibility and journey tests. Live code is tested against fakes |
| Design | Theme, components, design-system notes, and a [UX and accessibility review](ux-review.md) with an automated audit | Flutter's own guideline checks. No screen reader or device testing |
| Web | Release build served by `tools/run_platewise.py`, with Playwright checks of the full demo | Chromium only |
| Android and iOS | Platform folders and configuration carried over | Not built or run during the migration |

## Open items

- **Hosted setup:** create the Supabase secrets, deploy the `platewise` function and run the app in live mode once. Nothing has exercised that path yet.
- **AI provider choice:** Groq has no default vision model today. Decide the vision provider and model, then run the evaluation tool against it. See [known limitations](known-limitations.md).
- **Design decisions** from the [UX review](ux-review.md), including the Inter font bug.
- **Device checks:** Android build, camera, microphone, location, and a screen reader.
- **Repository housekeeping:** real usernames in `CODEOWNERS`, and the `config.toml` deprecation warning for email sign-up.

For commands, start with the [test report](test-report.md). For deployment, use the [deployment instructions](deployment.md). The [handoff notes](handoff.md) have the demo script.

Mahdeen Mannaf owns product design and UX. Tanvir Mahmud Hossain owns Flutter. Juhan Ahmed owns AI and backend.
