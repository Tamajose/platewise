# PlateWise verification report

24 November 2026, Windows 11. Flutter 3.50.1 / Dart 3.14.0, Deno 2.9.6, Node 24.12.0, Playwright 1.65.1 driving Chrome 157. Verification used synthetic profiles and demo data only.

This report covers the migrated repository. It says what was run, what passed, and what was not run. Read it with the [known limitations](known-limitations.md).

## Summary

| Area | Result |
|---|---|
| Flutter format, analysis and tests | Passed. 386 tests, no analysis issues |
| Flutter web release build | Passed |
| Backend format, lint, type-check and tests | Passed. 33 tests |
| Browser checks of the web demo | Passed in Chrome at 402×870 and 320×700, with no JavaScript errors |
| Accessibility audit | Passed. 37 cases across every screen at normal and doubled text size |
| SQL isolation tests | Not run for this report. They run in CI against a local Supabase stack |
| Android, iOS, live mode, real AI providers | Not run |

## Flutter app

Run from `app`.

| Command | Result |
|---|---|
| `flutter pub get --enforce-lockfile` | Resolved the lockfile unchanged |
| `dart format --output=none --set-exit-if-changed lib test integration_test` | 201 files, none changed |
| `flutter analyze` | No issues |
| `flutter test` | 386 tests passed |
| `flutter build web --release --no-web-resources-cdn` | Built in 113 s |

The tests cover, by layer:

- **Domain:** entities, calorie ranges, nutrient totals, budget fit and ranking, the target policy, dates, the energy formula, and the food entry, profile, account and water rules.
- **Data:** the API client (timeouts, offline, protocol errors, multipart upload), JSON mappers, the demo store, every live and demo repository, and a contract test that reads the SQL migrations and checks the Dart side against them.
- **Presentation:** the controllers and the screens for every feature, including failure and retry paths.
- **Architecture:** a test that scans the Flutter source and fails when a layer imports one it must not. Its own tests show it catches each kind of breach.
- **Accessibility audit** (`test/audit`): every screen, plus the review screen, the food editor and the voice entry, on a 390×844 phone at normal and doubled text size. It checks tap-target size on Android and iOS, labels on tap targets, text contrast and layout overflow. A separate check proves the audit fails on a deliberately tiny button.
- **Demo journey** (`test/app/demo_journey_test.dart`): the real demo composition, driven from the welcome screen through the sample day, logging, comparing, nearby, water, progress, settings, clearing the demo and creating a new profile.

`integration_test/demo_journey_test.dart` runs the app with the real plugins on a device or emulator. It was not run for this report.

Problems found by the tests and fixed during the migration include a ListTile placed inside a coloured box in several screens (a debug-mode assertion in the prototype too), an overflow in the profile form at doubled text size, a duplicate-key assertion when leaving through the entry gate, and an action snack bar that never timed out.

## Backend

Run from the repository root.

| Command | Result |
|---|---|
| `deno fmt --check`, `deno lint`, `deno check` | Passed in CI's configuration. Locally, `fmt --check` also flags three untouched files because of Windows line endings |
| `deno test --allow-env --allow-read --config supabase/functions/deno.json supabase/functions` | 33 tests passed |
| `deno run ... tools/evaluate.ts` | `fixtures_ready`: 6 reference cases, 18 illustrative cases, 0 provider requests |

The 33 tests cover the contracts and safety rules (target range, redaction, ownership of private paths, image metadata removal), ranking and menu sanitising, progress and energy, comparison and nearby with injected sources, account deletion ordering when storage fails, the HTTP handler's refusals, and the AI providers: OpenAI and Groq request shapes, mixed providers, a missing vision model, schema modes, and retry and failure mapping. `architecture_test.ts` enforces the five layers.

All provider tests use injected responses. No request was sent to OpenAI or Groq, and the deployed function was not called.

## Browser checks

The built web app was served by `tools/run_platewise.py` and driven with `tools/web-smoke.cjs` and `tools/browser-input-smoke.cjs`.

- `web-smoke.cjs` walked the whole demo: welcome, sample day, logging a sample photo estimate, comparing the sample menu with a budget, editing a portion, nearby sample menus, water, progress, settings, a 320 px reload, clearing the demo and creating a new profile. It passed with no JavaScript errors and wrote 15 screenshots.
- `browser-input-smoke.cjs` edited a sample transcript and reached the text estimate, then simulated a denied location and confirmed manual area selection remained. It wrote two more screenshots.

## Performance observed

Confirming a meal to an updated Today took 230 ms. A cold navigation to the first new meal on screen took 3,675 ms. The run used a local HTTP server, seeded data, local browser storage and scripted input, so these numbers do not describe live providers, a hosted backend or a real device.

The product's pilot targets (under 15 s from photo to result, under 1 s to refresh the dashboard, under 2 min for a new person's first meal) are not measured here. They need a configured provider and real devices.

## Not run

- **SQL tests** (`supabase/tests/core.sql` and `privacy.sql`) need `supabase start`, which needs Docker. CI runs them in its database job.
- **CI.** The Flutter migration steps F10 to B6 were merged without CI by choice, so this report's local run replaces it for those changes. The first CI run after W1 is the confirmation.
- **Android and iOS builds, devices, camera, microphone, location permissions, TalkBack and VoiceOver.**
- **Live mode:** a hosted Supabase project, the deployed function, email verification, real AI providers, and Bangla.
- **`tools/live_smoke.py` and `tools/auth_smoke.py`,** which need a local or hosted backend.
