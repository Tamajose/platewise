# PlateWise

AI decision support for what to eat, before you eat. Compare portions and calorie ranges, review an estimate, and confirm the meal to add it to a private log.

## Platforms

| Platform | Role |
|---|---|
| Android | Primary mobile target. |
| Web | Packaged demo and test target. |

iOS is not a supported target. The Flutter project keeps its iOS folder, but building for it needs macOS and Xcode and has not been verified.

## Run the demo

Use Flutter 3.50.1 stable and Dart 3.14.0. The demo runs without accounts or external API credentials. Start from the app folder.

    cd app
    flutter pub get --enforce-lockfile

**Web**

    flutter run -d chrome --web-port 3000 --dart-define=PLATEWISE_MODE=demo

**Android.** Start an emulator or connect a device with USB debugging, find its ID, then run the app on it.

    flutter devices
    flutter run -d <device-id> --dart-define=PLATEWISE_MODE=demo

To build release packages:

    flutter build web --release --no-web-resources-cdn
    flutter build apk --release

Release APK signing is covered in the [deployment instructions](docs/deployment.md).

**Web demo.** Build the web app, then serve it with the included launcher, which opens PlateWise in your browser. The launcher needs only Python.

    cd app
    flutter build web --release --no-web-resources-cdn
    cd ..
    python tools/run_platewise.py

To share a built demo, zip the contents of `app/build/web` with `tools/run_platewise.py` beside `index.html`. Extract it, open a terminal in that folder and run `python run_platewise.py`.

Choose **Explore a sample day** for labeled sample history or **Set up my profile** for an empty log. Demo text estimation uses a small, documented lookup. The sample photo, menu and transcript each have their own labeled entry point. Added demo entries live on the device or in the browser profile.

Open **Nearby** and choose **Use my location** to search live OpenStreetMap listings. You can filter by restaurant or cuisine and open directions for any result. On the web, location permission requires HTTPS or localhost. Nearby search needs an internet connection and works in both app modes. Demo mode keeps an optional offline **Sample menus** view.

## Run the live application

Start the Supabase development stack from the repository root.

    supabase start
    supabase db reset
    supabase functions serve platewise --env-file supabase/functions/.env.local

Use a private local copy of supabase/functions/.env.example for the optional AI settings: it chooses OpenAI or Groq, and the model for photos, text and speech. Supply only the Supabase URL and publishable key to Flutter. On web, the local stack is reached at localhost. An Android emulator reaches the host machine at 10.0.2.2 instead, and a physical Android device needs the computer's network address. Use HTTPS for a hosted project. See [deployment instructions](docs/deployment.md) for flags, SMTP, Android signing, cleanup, limits, and rollback.

- [Architecture](docs/architecture.md) and [API v1](docs/api-contracts.md)
- [Requirements traceability](docs/requirements-traceability.md) and [decisions](docs/decisions.md)
- [Design system](docs/design-system.md), [UX and accessibility review](docs/ux-review.md) and [credits](docs/credits.md)
- [Test report](docs/test-report.md), [known limitations](docs/known-limitations.md), and [handoff](docs/handoff.md)
- [Project status](docs/project-status.md) and [evaluation](docs/evaluation.md)

## Checks

The Flutter app, the Edge Function and the database each run their checks in CI. The [handoff notes](docs/handoff.md) list the commands, including the accessibility audit and the Playwright browser checks of the web demo.

## Ownership

Mahdeen Mannaf owns product design and UX. Tanvir Mahmud Hossain owns Flutter. Juhan Ahmed owns AI and backend.
