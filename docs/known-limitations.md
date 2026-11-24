# Known limitations

## What has and has not been run

- **Live mode has never been run end to end in this repository.** The Flutter app, the Edge Function and the database each have their own tests, and the Flutter live code is tested against fake HTTP and a fake session. No test has called a deployed function, a hosted Supabase project, or an AI provider. Treat the first hosted run as a verification step, not a formality.
- **Android and iOS builds were not run during the migration.** The web build, the unit and widget tests, and the browser checks were. Platform folders and plugin configuration were carried over unchanged. Camera, microphone, location permissions and TalkBack have not been tried on a device. iOS needs macOS and Xcode.
- **CI did not run on the Flutter migration PRs F10 to B6.** Their checks were run locally instead, and the full set ran again for W1. See the [test report](test-report.md).

## The application

The demo uses fictional data, illustrative estimates, a small matching catalog and local storage. It accepts manually entered Bangla food names, while the interface is English only. Demo editing and confirmation use the same screens and arithmetic as live data. Drafts stay in memory, so unsubmitted edits can be lost on restart. During a network outage live drafts can be edited on the current screen and need a connection to save.

The calorie floor and upper bound are a development and pilot policy. Clinical and product review, local guidance and a device pilot are required before public release. A partly logged day gives limited coverage. Estimates and confidence labels cannot establish nutritional adequacy. No pilot or population impact has been measured.

The [UX review](ux-review.md) lists open design decisions, including that most text does not render in the specified Inter font, and what the automated accessibility audit does not cover (screen readers, keyboard order on web, real devices).

## AI providers

AI features need an authorized provider key and current model availability. Two providers are supported, and each of vision, text and speech can use a different one. See the [deployment instructions](deployment.md).

- **Gemini free tier data use.** Google states that content sent on the Gemini API free tier can be used to improve its products, and the paid tier is handled differently. Meal photos, descriptions and voice notes are personal. Use the free tier with synthetic test data only. Before real people use the app, turn on billing for the Gemini project, or use a provider whose terms you have reviewed, and update the privacy text in Settings to match. Check Google's current terms, because they change.
- **Gemini speech is untried.** Gemini's OpenAI-compatible endpoint has no transcription route, so the function sends the recording to Gemini's own `generateContent` API with an instruction to transcribe it. The request follows Google's documented audio formats (WebM, M4A and WAV are accepted) but has not been called with a real key. Bengali is not listed as supported, so keep Bangla speech off until tested. Recordings are personal data, which makes the free-tier data-use warning above matter more.
- **Gemini defaults are unverified.** The default model (`gemini-3.5-flash-lite`) and the request shape follow Google's documentation and have not been called with a real key. Replies are requested in the prompt, not through a response schema, because support for schemas on the compatible endpoint is unclear, and every reply is validated afterwards. Gemini 2.5 models are being retired or rerouted from 1 December 2026, so keep model names current.
- **Groq has no default vision model.** The one it offered, Llama 4 Scout, was retired from the free and developer plans in July 2026, and the suggested replacements were reported not to accept images. Photo and menu analysis stay unavailable on Groq until a vision model is set with `PLATEWISE_VISION_MODEL`, or another provider is chosen for vision.
- **Groq defaults are unverified.** The default text model (`openai/gpt-oss-120b`) and speech model (`whisper-large-v3-turbo`) were taken from Groq's documentation and have not been called with a real key. Groq enforces response schemas less strictly than OpenAI by default. The backend validates every reply again, and `PLATEWISE_STRUCTURED_OUTPUT` can change the mode.
- **Bangla is untested.** The flags stay off by default. Llama and Whisper models do not officially list Bengali, and no Bengali accuracy has been measured for either provider.
- **The app does not yet read the finer capability flags.** The backend reports `live_vision`, `live_text` and `live_speech`, but the app still shows the photo option when only text and speech are configured. The photo estimate then fails with a clear message.
- **The 150 kcal minimum for planned dishes is a pilot value.** Below it "Plan a dish" returns `BUDGET_TOO_SMALL` and the app shows a neutral note. The number has had no clinical or product review. Comparing and logging still work at any budget.
- Text redaction covers common email, link, name-prefix and phone patterns and cannot identify every personal name. Photos and raw audio sent to a provider follow that provider's privacy controls. Users are asked to say only foods and portions.

## Accounts, data and cleanup

A Supabase project and Auth configuration enable private hosted data and email linking. Email verification, custom SMTP and redirect addresses need to be set up and tried on a hosted project. An anonymous user who switches to another account can lose device access to their old guest session, and merging identities is excluded. Inactive anonymous accounts need a deployment-level retention policy.

Hosted cleanup needs an operator-scheduled job. A discarded draft photo is removed on normal exit when possible, and unfinished uploads become candidates for removal after 24 hours. Raw speech is held in temporary local storage while recording, deleted after the request, and never stored in cloud object storage. Abrupt device termination can leave temporary local data until the operating system clears it.

## Maps and venues

Tile attribution and the optional map tiles follow the public tile service's usage policy. Live restaurant search uses public OpenStreetMap servers and needs an internet connection. Seeded venues are fictional and offer no stock, hours, prices or verified nutrition. Competition API eligibility still needs the official event rulebook.

## Deferred and excluded

An authorized live restaurant feed needs provider access, data rights and a verified adapter. Food corrections are queued for review, and a reviewed process to promote reference values is future work. Health-condition modes, diagnosis, treatment, wearables, payments and clinician integration are outside the project.
