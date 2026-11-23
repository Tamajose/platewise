# UX, accessibility and copy review

Step D3 of the migration. It reviews the finished Flutter app as it behaves in demo mode. Live mode and real devices are not covered; see "Not covered".

## Method

1. **Automated accessibility audit.** `app/test/audit/accessibility_audit_test.dart` renders every screen on a 390 × 844 phone at normal and doubled text size. It also renders the states that need a few taps: the review screen, the food editor, the sample estimate, and the voice and typed entry tabs. For each one it checks:
   - Android (48 dp) and iOS (44 pt) tap-target sizes,
   - that every tap target has a label,
   - text contrast against the background,
   - that nothing overflows its layout.
   Any finding fails the test, so a regression is caught in CI. One extra test confirms the checks do fail on a deliberately tiny button.
2. **Copy read-through.** Every user-visible string in the features and the shared widgets was read for tone, consistency and clarity.
3. **Flow review.** The journeys were walked in code and in the widget tests: first run, logging a meal, comparing meals, nearby search, water, progress, settings, deletion and accounts.

## Result of the audit

| Area | Result |
|---|---|
| Tap targets (Android and iOS) | Pass on 37 screen and state combinations |
| Labels on tap targets | Pass |
| Text contrast | Pass |
| Layout at doubled text size | One fault found and fixed (below). The rest pass |

**Fixed.** The profile form overflowed by 218 px at doubled text size, because the unit and language dropdowns were not allowed to fill their row. They now are. The audit would catch this again.

**Already good, kept as is.**
- Fit and confidence badges use an icon and a word as well as colour.
- The calorie ring and the weekly chart carry text descriptions, and the weekly screen offers a day-by-day list that opens by default when text is large.
- Animations are removed for people who ask the system to reduce motion (the food editor sheet).
- Account fields carry autofill hints.
- Destructive actions ask first and say what is removed.
- Every error says what happened and what to do next, and never exposes raw technical detail.

## Findings that need a decision

These change how the app looks or reads, so they are for the design owner. None blocks the migration.

| # | Finding | Why it matters | Suggested action |
|---|---|---|---|
| 1 | Body text does not render in Inter. See the open issue in `design-system.md` | The design specifies Inter, but most text uses the platform default font | Name Inter on each non-serif style, then re-run the audit, because widths change |
| 2 | The nutrient label is spelled "Fibre". The rest of the copy and the data use "fiber" | One spelling should be used throughout | Pick British or American spelling and apply it to every label |
| 3 | Deleting data opens a sheet titled "Delete your app data?" whose button says "Delete data" | The button and the sheet should use the same words | Use "Delete app data" on both |
| 4 | Today puts "Compare meals" as the primary button and "Log meal" second | This follows the "decide before you eat" idea, but most daily use is logging | Confirm which action should be primary |
| 5 | Loading messages vary: "Opening PlateWise…", "Opening your log…", "Loading your water log…" | Small inconsistency | Choose one pattern, such as "Loading …" |
| 6 | The interface is English only. Bangla appears as an analysis language, not as interface text | The product targets Bangladesh | Decide whether Bangla interface text is in scope, and plan translation and the Noto Sans Bengali fallback |

## Not covered

- **Screen readers** (TalkBack, VoiceOver) and switch control. The audit checks labels exist; it cannot judge reading order or how the announcements sound.
- **Keyboard and focus order** on web.
- **Real devices.** Android and iOS rendering, system font sizes above 2×, dark mode and landscape.
- **Colour-vision simulation.** The design avoids colour-only meaning, but it has not been simulated.
- **Live mode.** Error messages from the real service, and the real email verification flow.
- **Usability testing with people.** This review is a technical audit, not a substitute.

## How to keep it green

Run `flutter test test/audit` after any UI change. A new screen should be added to the `screens` list in the audit test.
