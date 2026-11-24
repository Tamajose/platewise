# Product and engineering decisions

| Topic | Resolution |
|---|---|
| Authority | The pasted implementation brief sets scope and resolves conflicts. PlateWise SRS §§4–7 specify behavior. Idea Document §§3, 5 and 9 supply product intent. |
| Menu extraction | FR-20 labels menu extraction Final. The SRS delivery table puts it Later. Build it in Sprint 2 per the brief. |
| Nutrients | Item-level protein, carbohydrate, fat, fibre and sodium carry provenance and nullable values. A weekly subtotal states item coverage and is available if at least one item supplies that nutrient. |
| Sessions | Sprint 1 uses Supabase anonymous identity and per-user RLS. Sprint 3 links an email and password to the same user ID and handles existing-account conflicts explicitly. |
| Energy estimation | FR-4 moves into Sprint 3. An adult can opt into a reviewed TDEE estimate. Applying any target is an explicit separate action. |
| BMI and ranking | Show calculated BMI as profile context. Ranking uses the estimated range, confidence and selected meal budget. The CDC describes BMI as a screening measure. The project has no evidence base for adjusting a meal score with BMI. This is a documented safety deviation from FR-17/22. |
| Safety policy | Pilot target range is 1,200–5,000 kcal. These configurable bounds are product safeguards, not individualized medical advice. BMI remains a screening measure and does not set calorie needs. Targets outside the range are rejected with guidance to keep logging without a target and consult a qualified healthcare professional, especially when a target below 1,200 kcal seems necessary. Low-confidence photo estimates are not returned; ask for a clearer photo, a meal/portion description, or manual entry, and consult a qualified healthcare professional when uncertain nutrition values affect a health decision. NICE recommends specialist support for low-energy diets of 800–1,200 kcal. NIDDK describes the minimum in its own calculator. The project still needs clinical/product review before a public release. Adults who indicate that ordinary target-setting may be unsuitable can skip the target and still log. |
| Locale | The interface is English. Manual text can contain Bangla. Live Bangla analysis and speech require explicit operator enablement after checking the configured models with speakers. Typed/manual review remains available. |
| Menu data | Synthetic venues, approximate demo coordinates and illustrative portions. A provider interface is provided for future authorized feeds. Health-condition modes, wearables, diagnosis, treatment, payments and clinician integration are excluded. |
| Data boundaries | Photos use private owner-scoped Storage. Speech audio is processed in memory and is never persisted by PlateWise. A short cache is per-user. The only outbound food data goes to the configured analysis provider. |
| Historical days | UTC instants belong to days in the currently selected IANA timezone. Targets are stored with their local effective date and remain historical. A timezone change may shift events across displayed dates. |
| Delivery | Android is the primary mobile target. Web is a packaged demo and test target. iOS requires macOS/Xcode verification. Competition API eligibility remains unverified without an official rulebook. |

Sources at the end of each related section in [architecture.md](architecture.md).

## Repository migration decisions

| Topic | Resolution |
|---|---|
| History | The repository starts fresh. The original prototype's commit history is not carried over. |
| Layout | One monorepo: `app/` (Flutter), `supabase/` (database and Edge Function), `tools/`, `testdata/` and `docs/`. The Dart models, Deno schemas and SQL migrations share one contract. |
| Workflow | One branch and one pull request per migration step, each leaving `main` green. CODEOWNERS routes review by role. |
| State management and DI | Keep Riverpod (`flutter_riverpod`). Screen state moves to `Notifier` and `AsyncNotifier` controllers. |
| Routing | Keep `go_router`. |
| Flutter architecture | Feature-first clean architecture. Each feature has `domain`, `data` and `presentation` layers. See [architecture.md](architecture.md). |
| AI tooling | `.agents/skills/ui-design` is kept for now. The UI may be overhauled later. |
