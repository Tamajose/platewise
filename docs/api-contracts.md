# PlateWise API v1

One Supabase Edge Function, platewise, accepts authenticated POST requests. JSON requests use {"version":1,"action":"dashboard","input":{}}. JSON success is {"version":1,"ok":true,"request_id":"uuid","data":{}}. Errors add an error object with code, message and retryable in place of data. JWT identity is checked with Supabase Auth before processing a request. Every write accepts an operation ID or uses an entity ID and is checked against ownership.

Nutrition amounts use kcal, grams and mg. Water uses integer ml, weight kg, height cm, and instants ISO 8601 UTC. An item has an explicit quantity/unit and nullable estimated grams, food reference, protein_g, carbohydrate_g, fat_g, fiber_g and sodium_mg. Each item has range, nutrient source and estimate provenance. Ranges are inclusive, and confirmed meals sum their items. The representative estimate rounds the midpoint once per meal. Dashboard totals sum the representative estimates. A saved meal alone contributes to totals.

Photos are private owner-scoped objects. The object key is <user UUID>/<random UUID>.<jpg|jpeg|png|webp>. An authenticated mobile upload precedes photo analysis. The API checks type, size and ownership before reading. Transcription uses authenticated multipart with fields version, action, language and audio. The audio file stays in memory for the request. No binary is accepted in a JSON request.

## Actions

| Action | Input | Data |
|---|---|---|
| capabilities | Empty object | Live AI and language flags, pilot target version and limits |
| update_profile | height_cm, weight_kg, daily_calorie_target (nullable), water_goal_ml, timezone, preferred_units, preferred_language, target_confirmed | Profile with server timestamps |
| dashboard | Empty object | Profile, local_day, meals with items, water, target-history anchor and changes, photo and deletion status |
| analyze_photo | image_storage_path | Items, total range, midpoint, confidence, assumptions, optional question and model |
| analyze_text | description (2–600 characters), language (en or bn) | Same estimate as analyze_photo |
| transcribe_voice | Multipart version=1, action=transcribe_voice, language and one audio file | transcript, which the client lets users edit before analysis |
| extract_menu | image_storage_path | Up to 18 dish names, nullable portions, nullable printed_kcal and visible calorie evidence |
| compare | Two or three options with unique keys and nullable budget from 1 to 5,000 | Successful estimates with fit, rank and reason, plus separate keyed failures |
| confirm_meal | Draft UUID, source, confidence, items, assumptions, optional photo and model | Confirmed meal and items. A retry with the same ID returns the existing result |
| edit_meal | Confirmation fields plus expected_updated_at | Updated meal or a stale-edit response. Source, photo and original consumed time remain |
| delete_meal | id | removed flag after associated photo cleanup succeeds |
| discard_photo | image_storage_path | Removed from Storage when the photo has no confirmed meal |
| retry_media_cleanup | Empty object | Retry up to 100 pending owner paths |
| meal_image_url | id | signed_url and 90-second expiry |
| nearby | latitude, longitude, radius_km (0.5–25), nullable budget | Seeded meal cards, source, distance, range and fit |
| log_water | id, amount_ml (1–2,000) | Stored water entry |
| edit_water | id, amount_ml, expected_updated_at | Updated water entry or stale edit |
| delete_water | id | removed flag |
| weekly | Empty object | Seven dated rows, coverage, target overlap, averages and nullable nutrients |
| weekly_summary | Empty object | insufficient or generated, with server-approved sentences |
| estimate_energy | age (19–78), eligible=true, plus_5 or minus_161, low/some/regular activity | Resting energy, activity factor, total and eligibility to apply under pilot bounds |
| correction_consent | enabled | Consent status. Withdrawal clears pending contributions |
| share_correction | id, curated food_key, grams, calorie_low, calorie_high | Queued submission confirmation |
| delete_data | Empty object | Deletes photos and application rows and keeps the identity |
| delete_account | Empty object | Deletes photos, application rows and the identity |

A compare photo option has kind=photo, key and image_storage_path. A menu option has kind=menu, key, name, nullable portion and printed_kcal, and language. The server treats a reviewed printed calorie value as menu evidence and labels inferred nutrition when none is supplied. Every selected meal goes through confirmation.

Example errors include SESSION_REQUIRED, INVALID_ESTIMATE, AI_UNAVAILABLE, STORAGE_PENDING, RATE_LIMIT, TARGET_RANGE and STALE_EDIT. The request ID correlates an error without exposing raw provider or database details. Requests are bounded at 48 KiB for JSON, 5 MiB for private images and 2 MiB for M4A, WebM or WAV recording. The app ends recording after 40 seconds. The Flutter image pipeline outputs metadata-free JPEG. Demo repositories use separate local keys.

## Auth and cleanup

The Flutter client uses Supabase Auth directly for anonymous sign-in, verified email linking, password setting, sign-in, sign-out and session refresh. Those calls never enter nutrition prompts. Hosted email confirmation behavior depends on Auth settings and SMTP.

The scheduled cleanup operation accepts a POST with x-platewise-cleanup set to a configured random secret of at least 24 characters. It queues unconfirmed owner photos older than 24 hours, retries up to 100 pending objects, and removes expired cache/rate/tombstone rows.
