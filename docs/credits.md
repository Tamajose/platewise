# Credits and license inventory

Mahdeen Mannaf owns product design and UX. Tanvir Mahmud Hossain owns Flutter development. Juhan Ahmed owns AI and backend.

The welcome and example-meal photograph was generated for PlateWise with OpenAI image generation. It is illustrative. The app icon was drawn for PlateWise. The bundled DM Serif Text, Inter, and Noto Sans Bengali fonts include their upstream SIL Open Font License texts in app/assets/fonts. [DM Serif Text](https://github.com/google/fonts/tree/main/ofl/dmseriftext) · [Inter](https://github.com/google/fonts/tree/main/ofl/inter) · [Noto Sans Bengali](https://github.com/google/fonts/tree/main/ofl/notosansbengali)

The seeded out-of-home menus and approximate coordinates are original, fictional fixtures. Six evaluation cases cite a small number of kcal facts from the Food Composition Table for Bangladesh, ISBN 978984337522-3. The full table and provider imagery are absent from the distribution. [FAO-hosted tables](https://www.fao.org/fileadmin/templates/food_composition/documents/FCT_10_2_14_final_version.pdf)

The map uses flutter_map v8 with locally rendered geographic pins and an original schematic default. Optional tiles use OpenStreetMap contributors' map data under ODbL and the public tile service's separate use policy. Keep visible attribution and link to copyright if enabling tiles. fl_chart supplies charts under the package's license. [OSM attribution](https://www.openstreetmap.org/copyright) · [Tile usage policy](https://operations.osmfoundation.org/policies/tiles/) · [flutter_map](https://pub.dev/packages/flutter_map) · [fl_chart](https://pub.dev/packages/fl_chart)

Live deployments can use OpenAI GPT-4.1 mini and GPT-4o mini Transcribe through the server, subject to the provider terms. The backend imports Zod 4.6.7 and supabase-js 2.119.2 under MIT, with integrity data in the Deno lock. No provider weights or keys are bundled. Browser validation uses Playwright 1.65.1 under Apache-2.0 and Chromium. [OpenAI platform](https://platform.openai.com/docs/) · [Zod](https://www.npmjs.com/package/zod) · [Supabase JS](https://www.npmjs.com/package/@supabase/supabase-js) · [Playwright](https://github.com/microsoft/playwright)

## Selected Flutter packages

Flutter SDK 3.50.1 uses BSD-3-Clause. The table uses resolved package versions. Labels identify families when a notice applies to a package with multiple contributors. See each package's exact LICENSE and the Flutter application's generated notices.

| Package | Version | Notice |
|---|---|---|
| [flutter](https://pub.dev/packages/flutter) | 0.0.0 | Flutter SDK |
| [flutter_riverpod](https://pub.dev/packages/flutter_riverpod) | 3.5.0 | MIT family · see notice |
| [go_router](https://pub.dev/packages/go_router) | 18.1.4 | BSD-3-Clause |
| [material_ui](https://pub.dev/packages/material_ui) | 1.11.1 | BSD-3-Clause |
| [supabase_flutter](https://pub.dev/packages/supabase_flutter) | 2.18.3 | MIT family · see notice |
| [image_picker](https://pub.dev/packages/image_picker) | 1.2.4 | Apache-2.0 |
| [image](https://pub.dev/packages/image) | 4.13.1 | Apache-2.0 |
| [record](https://pub.dev/packages/record) | 7.2.0 | BSD-3-Clause |
| [geolocator](https://pub.dev/packages/geolocator) | 14.1.2 | MIT family · see notice |
| [flutter_map](https://pub.dev/packages/flutter_map) | 8.3.2 | BSD-3-Clause |
| [latlong2](https://pub.dev/packages/latlong2) | 0.10.1 | Apache-2.0 |
| [fl_chart](https://pub.dev/packages/fl_chart) | 1.3.1 | MIT family · see notice |
| [timezone](https://pub.dev/packages/timezone) | 0.11.2 | BSD family · see notice |
| [intl](https://pub.dev/packages/intl) | 0.20.3 | BSD-3-Clause |
| [uuid](https://pub.dev/packages/uuid) | 4.6.0 | MIT family · see notice |
| [shared_preferences](https://pub.dev/packages/shared_preferences) | 2.5.6 | BSD-3-Clause |
| [path_provider](https://pub.dev/packages/path_provider) | 2.1.6 | BSD-3-Clause |
| [http](https://pub.dev/packages/http) | 1.6.0 | BSD-3-Clause |
| [cross_file](https://pub.dev/packages/cross_file) | 0.3.5+5 | BSD-3-Clause |
| [url_launcher](https://pub.dev/packages/url_launcher) | 6.3.3 | BSD-3-Clause |
| [http_parser](https://pub.dev/packages/http_parser) | 4.1.2 | BSD-3-Clause |
| [flutter_lints](https://pub.dev/packages/flutter_lints) | 6.0.0 | BSD-3-Clause |

The [resolved dependency inventory](dependency-inventory.tsv) records direct and transitive packages. The Flutter build includes the SDK-generated notices bundle.
