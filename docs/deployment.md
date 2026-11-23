# Deployment and rollback

## Local setup

Use Flutter 3.50.1, Dart 3.14.0, Deno 2.9.6, Supabase CLI 2.76.15, Docker, JDK 21 and Android SDK Platform 36. The tested Android toolchain selection uses Gradle 9.5, Android Gradle Plugin 9.3.1, Platform 35 for plugins, Build Tools 36.0.0 and NDK 28.2.13676358. Check the environment with flutter doctor and install the matching Android SDK/NDK before building. Supabase local PostgreSQL is version 17. Allow disk space for Docker images and Android tools.

Run supabase start and supabase db reset at the root. Versioned migrations run in order. The reset applies supabase/seed.sql. Its source is app/assets/data/seeded_menus.json. Regenerate the seed with python3 tools/generate_seed.py after editing the catalog. For a reused dev DB apply the pending migrations without a destructive reset when keeping data matters.

Copy the Edge environment example in the local workspace. Set only the values needed for the desired functionality. Supply them to supabase functions serve platewise --env-file supabase/functions/.env.local. Use the URL and publishable key shown by supabase status for the Flutter build. Flutter can run without an AI key in live mode for data and manual entry.

    cd app
    flutter pub get --enforce-lockfile
    flutter run -d chrome --web-port 3000 \
      --dart-define=PLATEWISE_MODE=live \
      --dart-define=PLATEWISE_LOCAL_DEV=true \
      --dart-define=SUPABASE_URL=http://127.0.0.1:54321 \
      --dart-define="SUPABASE_PUBLISHABLE_KEY=replace_with_local_publishable_key"

Copy app/config/live.example.json to app/config/live.local.json to use flutter run --dart-define-from-file=config/live.local.json. The local copy is excluded from source control. Local development origins belong in PLATEWISE_ALLOWED_ORIGINS. Using an Android emulator, replace 127.0.0.1 with 10.0.2.2 and use a debug build. A Flutter web build can be served using python3 -m http.server 3000 --directory app/build/web.

## Environment inventory

| Variable | Where | Meaning |
|---|---|---|
| PLATEWISE_MODE | Flutter define | demo or live. Default demo |
| SUPABASE_URL | Flutter define and runtime | Project HTTPS URL, or explicit local host in development |
| SUPABASE_PUBLISHABLE_KEY | Flutter define | Public project key. Never use the service-role key here |
| PLATEWISE_LOCAL_DEV | Flutter define | Explicit loopback and emulator HTTP support |
| PLATEWISE_OSM_TILES | Flutter define | Optional interactive OSM standard tiles. Default schematic map |
| SUPABASE_ANON_KEY or SUPABASE_PUBLISHABLE_KEY | Edge runtime | Used with the user's verified JWT to apply RLS |
| SUPABASE_SERVICE_ROLE_KEY | Edge runtime secret | Supabase-injected key for privileged owner-scoped writes and deletion |
| OPENAI_API_KEY | Edge runtime secret | Project key for the enabled OpenAI adapter |
| PLATEWISE_AI_PROVIDER | Edge runtime | openai by default. Alternate vendors need their adapter implementation |
| PLATEWISE_VISION_MODEL, PLATEWISE_TEXT_MODEL | Edge runtime | gpt-4.1-mini defaults |
| PLATEWISE_SPEECH_MODEL | Edge runtime | gpt-4o-mini-transcribe default |
| PLATEWISE_BANGLA_TEXT_ENABLED, PLATEWISE_BANGLA_SPEECH_ENABLED | Edge runtime | Opt-in after language testing with selected models |
| PLATEWISE_ALLOWED_ORIGINS | Edge runtime | Exact Flutter web origins, comma-separated |
| PLATEWISE_CLEANUP_SECRET | Edge runtime secret and scheduler secret | Random string of at least 24 characters |
| PLATEWISE_EVAL_LIVE, PLATEWISE_EVAL_URL, PLATEWISE_EVAL_PUBLISHABLE_KEY, PLATEWISE_EVAL_ACCESS_TOKEN | Evaluation runner only | Opt-in and short-lived synthetic test credentials |

## Hosted

1. Pick the Supabase project and region and enable anonymous sign-in. Set abuse controls suitable for the audience. Configure verified-email linking, custom SMTP, the Auth site URL and approved redirect origins. Verify with a dedicated test account. If the confirmation link opens a browser, return to PlateWise and check verification before setting a password.
2. Link the CLI to your project and run supabase db push for versioned migrations. Apply supabase/seed.sql to a pilot project when you want fictional venues.
3. Set provider values through the dashboard or supabase secrets set --env-file with a private file. Estimate external spend, set the provider limits, and review supported models, retention and competition eligibility. Deploy with supabase functions deploy platewise --no-verify-jwt. This matches the config that leaves JWT validation to the handler's Auth call.
4. Verify user A/B isolation, invalid JWT, missing model fallback, hosted media deletion, email verification and upgrade in the pilot. Enable the cleanup scheduler using an HTTPS POST to the Edge endpoint and the x-platewise-cleanup secret header. Use a vault-backed secret and check the job's response. An hourly run bounds abandoned-photo retention under normal operation.
5. Set live publishable defines when building the app. Production clients use HTTPS. Review approved data retention, storage backups and legal notices before inviting users.

## Android and iOS

Run flutter build apk --release --target-platform android-arm64 from app for a demo APK. The packaged ARM64 release-mode APK uses demo signing. The default Gradle config supports demo signing. For distribution, create a private release keystore, copy android/key.properties.example to android/key.properties and configure the release signing values, then build with flutter build appbundle --release. Store the keystore and password outside the repo. Install a demo APK on an Android handset with adb install or the device's package installer and verify capture, denied permissions, microphone, location and account lifecycle on-device.

On macOS use current Xcode with the Flutter SDK and configure the Runner signing team and unique bundle identity. Run flutter build ios --release --no-codesign to check compilation, then archive with your signing setup. iOS build and device behavior remain unverified here.

## Rollback and retention

Keep an archive of each app build, schema revision and Edge bundle. To revert an Edge-only bug, deploy the previous API-compatible version with the same required secrets. For database changes, use a forward repair migration after assessing existing writes. A destructive restore may roll back user writes and requires a separately planned recovery. Keep a compatible app version during rollout and verify Auth, read and write behavior before switching traffic.

Deletion removes current application data and private objects. Database backups, any object backup copies and provider-side logs follow their own schedules and must be covered by the deployment's policy. [OpenAI data controls](https://platform.openai.com/docs/guides/your-data) · [Supabase backups](https://supabase.com/docs/guides/platform/backups) · [OSM tile policy](https://operations.osmfoundation.org/policies/tiles/)

For a full local HTTP smoke run, set PLATEWISE_BACKEND_PUBLISHABLE_KEY and run python3 tools/live_smoke.py against an isolated Supabase project. PLATEWISE_TEST_STORAGE=1 runs the additional data/account deletion checks when Storage is available. This smoke runner expects a backend without provider credentials, to test the explicit unconfigured-model response. It creates synthetic disposable guest users.

The delivery archives are named PlateWise-source.zip, PlateWise-web-demo.zip, PlateWise-UI-evidence.zip, PlateWise-demo.mp4 and PlateWise-Android-arm64.apk. Extract the web archive and serve the platewise-web-demo directory with an HTTP server. The source archive contains setup, migrations and the complete audit.
