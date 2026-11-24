# Handoff and demo

## Ownership

| Owner | Working area |
|---|---|
| Mahdeen Mannaf | Design, UX, accessibility and the demo narrative |
| Tanvir Mahmud Hossain | Flutter app, routing, and platform builds |
| Juhan Ahmed | SQL, Auth and Storage boundaries, AI providers, evaluation and deployment |

Start with [project status](project-status.md) and the [requirements traceability](requirements-traceability.md). Read the [architecture](architecture.md) before adding code: it explains the Flutter layers, the backend layers and the rules a test enforces. Use the [API contracts](api-contracts.md) before changing a shared field, because a contract change touches the Dart models, the Deno schemas and the SQL migrations together. Regenerate the sample SQL when the catalog changes.

## Before handing off a change

Run these from the repository root. They are the same checks CI runs.

    cd app
    flutter pub get --enforce-lockfile
    dart format --output=none --set-exit-if-changed lib test integration_test
    flutter analyze
    flutter test
    cd ..
    deno fmt --check --config supabase/functions/deno.json supabase/functions tools/evaluate.ts tools/metrics.ts
    deno lint --config supabase/functions/deno.json supabase/functions tools/evaluate.ts tools/metrics.ts
    deno test --allow-env --allow-read --config supabase/functions/deno.json supabase/functions

SQL isolation tests run in the database job of CI, or locally against `supabase start`. After a UI change also run the accessibility audit (`flutter test test/audit`) and, for a release candidate, the browser checks below.

## Run the demo

Build the web app and serve it with the launcher, which opens your browser.

    cd app
    flutter build web --release --no-web-resources-cdn
    cd ..
    python tools/run_platewise.py

## Browser checks

These drive the built web app in Chromium, as a person would, at a phone-sized window and again at 320 px wide.

    cd tools
    npm ci
    python run_platewise.py --no-browser --port 8011

In a second terminal, in `tools`:

    $env:CHROMIUM_PATH = 'C:\Program Files\Google\Chrome\Application\chrome.exe'
    $env:PLATEWISE_WEB_URL = 'http://127.0.0.1:8011'
    node web-smoke.cjs
    node browser-input-smoke.cjs

`web-smoke.cjs` walks the whole demo and writes screenshots and `browser-result.json` to `testdata/browser-evidence` (ignored by git). `browser-input-smoke.cjs` checks editing a transcript and a denied location. Set `CHROMIUM_PATH` to any Chrome or Chromium, or run `npx playwright install chromium` and leave it unset.

## Demo script

1. Open PlateWise and select **Explore a sample day**. Point out the remaining estimate, the daily range and the **Demo mode** badge.
2. Open **Decide** and **Review sample menu**. It lists vegetable khichuri, a chicken tikka rice bowl and chicken biryani. Check the portions and compare the selected dishes. Read the range and the fit reason. A fit applies to those portions only.
3. Choose an option. Change its quantity in the review item's editor, then confirm. Return to Today to show the updated estimate.
4. Open **Log meal**, select **Voice** and **Use sample transcript**. Edit the text before estimating. The photo picker and live AI controls need live services, and the demo's sample controls say where their data comes from.
5. Open **Nearby** and choose **Use my location**, or select an area and choose **Search this area**. Filter the listings by restaurant or cuisine and open directions. For an offline demo, open **Sample menus** and review a meal from the fictional catalog.
6. Add 250 ml on Today and use **Undo**, or open the water log and edit an amount.
7. Open **Progress**. Show the historical target bars, the days with no log, and the nutrient denominators. The demo recap uses the visible numbers.
8. Open Settings. Explain private live photos, the deletion controls and the general nutrition scope.

## Recorded fallback

For a credential-free fallback, record the demo from the running web build. Serve it as above, then run `web-smoke.cjs` with `PLATEWISE_RECORD=1` and a dedicated `PLATEWISE_EVIDENCE_DIR`. The recording is saved as `platewise-demo.webm`. Playwright records video through its own FFmpeg build, so install it first with `npx playwright install ffmpeg`. Keep personal profiles, commercial provider credentials and private meal photos out of any recording.
