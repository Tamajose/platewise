# Design system

PlateWise uses Material 3, Inter, Noto Sans Bengali fallback, and a warm canvas. The Today page gives the calorie range a single dark panel, followed by logging actions, water and the daily log. Decide shows the budget beside the options. Progress pairs intake with historical targets and includes a readable date list.

| Token | Hex | Use |
|---|---|---|
| Canvas | #F5F2E9 | Page, shell, sticky review action |
| Surface | #FFFDF8 | Form controls and result cards |
| Ink | #203329 | Headings and body |
| Muted ink | #4E6155 | Secondary and disclaimer |
| Forest | #285B44 | Primary button, active states |
| Deep green | #163A2C | Logo and daily estimate |
| Sage | #E7EDD9 | Tinted panels, tags |
| Lime | #E0EE9C | Remaining estimate and progress ring on dark green |
| Hydration | #E8F3F6 / #23586D | Water panel and labels |
| Caution | #FFF2D9 / #714508 | Uncertainty and retryable errors |
| Destructive | #9D302B | Erase actions on light surface |
| Line | #E0DCCF | Card separation and chart grid |

Use 4/8 px spacing increments, 20 px page insets, 16–22 px cards and 13 px buttons. Major screen headings use 34 px and body copy uses 14–16 px defaults. Tabular digits apply to the daily estimate. Controls keep native focus behavior and at least 48 px target intent. Text scales with the system. The review form scrolls above the keyboard, and Progress offers the day-by-day list at larger font sizes.

Confidence, ranking, errors and budget fit have text labels. A chart has a semantic description and date-level details. Main action transitions are short. The chart redraw uses zero duration and the editor respects reduced-motion preferences.

Required components are implemented under app/lib/core/widgets and their feature folders. PrimaryButton and SecondaryButton share labels and touch targets. MetricCard and CalorieSummary summarize records. MealListItem and FoodEstimateEditor support management. ConfidenceBadge, BudgetFitBadge, RankedMealCard and WaterQuickAdd express feature state. EmptyState, ErrorState, LoadingState, DisclaimerNotice and ConfirmationSheet are shared.

Reference review on 22 November used Oura's Today and Trends hierarchy, Material 3 documentation, and Flutter guidance on 48 px targets and text contrast. PlateWise uses its own palette, foods, layout and imagery. [Oura app](https://support.ouraring.com/hc/en-us/articles/360058599753-How-to-Use-the-Oura-App) · [Oura Trends](https://support.ouraring.com/hc/en-us/articles/360055983614-Using-Trends) · [Material 3](https://m3.material.io/) · [Flutter accessibility](https://docs.flutter.dev/ui/accessibility-and-internationalization/accessibility)

## Text contrast checks

| Foreground on background | WCAG contrast |
|---|---|
| Ink on canvas | 11.97:1 |
| Ink on surface | 13.18:1 |
| Muted on canvas | 5.93:1 |
| Muted on surface | 6.53:1 |
| Forest on sage | 6.56:1 |
| White button on forest | 7.86:1 |
| White on deep green | 12.53:1 |
| Lime on deep green | 10.07:1 |
| Hydration ink on tint | 6.91:1 |
| Alert text on amber | 7.41:1 |
| Destructive on white | 7.26:1 |
| Destructive on surface | 7.14:1 |

These ratios are computed from the token values in `plate_theme.dart` and checked by `test/core/theme/plate_theme_test.dart`, which fails if any pair drops below 4.5:1.

Disabled controls use Material 3 disabled-state styling. The border and grid tokens serve nontext separation. System focus, enabled and disabled button states were inspected in the Flutter web demo and widget tests.


## Open issue: body text does not render in Inter

`plateTheme()` sets `fontFamily: 'Inter'` on `ThemeData`, then replaces most text styles with `textTheme.copyWith(...)` using styles that carry no family. Those replacements discard Inter, so body, title and small headline text fall back to the platform default font. Only the DM Serif Text headings, which name their family explicitly, and any untouched styles keep a bundled font. This was found while migrating the theme and is carried over unchanged. The fix is to name `Inter` on each non-serif style, which changes the look of most text, so it needs a design decision before it is made.
