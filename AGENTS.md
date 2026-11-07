# AGENTS.md

Trakta is an open source (Apache-2.0), offline Flutter app that calculates Swedish per diem (traktamente), business driving (milersättning) and the commuting deduction (reseavdrag), plus its website at trakta.app. `README.md` (features, status) and `docs/` (tax rules, architecture, rules packs, releasing, road to the stores) are the source of truth. Read them before changing behaviour, and keep them up to date when you do. `CONTRIBUTING.md` has the same rules for people.

## Phase: public beta toward the stores

Since 1.0.0 (2026-10-09) people keep real data in Trakta, and since 1.1.0 anyone can install it from GitHub releases (Google Play has a test track). Pure development is over, and every change must be tested and robust before it ships.

- **No untested code ships.** Every change includes tests that fail without it: unit tests for logic, golden tests (named after their Skatteverket source) for tax rules, widget tests for screens and flows. A bug fix starts with a test that reproduces the bug.
- **Never break stored data.** Schema version 1 is frozen. A table change means: bump `schemaVersion`, add the migration step in `database.dart`, run `dart run drift_dev make-migrations` in `apps/trakta_app` (it writes the schema snapshot and generated migration tests), and convert rows from older backups in `BackupRepository.open` with a test that restores one. CI fails on a schema change without a new snapshot. Never rename an enum value that is stored in the database.
- **Backups stay restorable.** Backups from every released version must restore in later versions. Change `BackupFile.format` only together with code that still reads the old format, and test it.
- **Each release bumps the version** in `apps/trakta_app/pubspec.yaml` and `appVersion` in `lib/app/build_info.dart` (semantic version name, build number after `+` always increasing), has a `CHANGELOG.md` section, and is installed over the previous version on a real phone before the draft GitHub release is published (`docs/releasing.md`).
- **Prefer small, reversible changes.** If a change cannot be tested well, say so and propose how to test it instead of shipping it.

## Layout

```
pubspec.yaml                 pub workspace root (trakta_core, trakta_app, tool) + sqlite3mc encryption hook
.fvmrc                       the exact Flutter version (CI and FVM)
LICENSE, NOTICE, TRADEMARKS.md  Apache-2.0; the name and icon are trademarks
CHANGELOG.md                 user-visible changes; a version's section becomes its release notes
docs/                        tax-rules, architecture, rules-packs, releasing, store-listing, launch-checklist
fastlane/metadata/android/   store and app catalogue texts, screenshots, changelogs per build number
rules/<year>.json            rules pack per income year: the only place tax numbers live
rules/drafts/                packs not yet complete (no foreign rates)
rules/schema.json            JSON schema for editors
packages/trakta_core/        pure-Dart rules engine, no Flutter / Drift / I/O
  lib/src/engine/            trip_calculator, trip_timeline, country_resolver, mileage_calculator,
                             commute_calculator, employer_settlement
  lib/src/model/             trip, mileage, commute, enums, CalendarDate, Swedish holidays
  lib/src/rules/             RulesPack loading and validation
  lib/src/explain/reason.dart  ReasonCode + Sources (the "Why?" trail)
  lib/src/money/ore.dart     Ore: integer öre, rounding
  test/                      golden_<year>_test.dart, property and rules pack tests
apps/trakta_app/             Flutter app (Riverpod 3, go_router StatefulShellRoute, Drift)
  assets/rules/              copies of rules/*.json, written by tool/bin/sync_rules.dart
  lib/app/                   app, router, providers, theme + tokens (from design/DESIGN.md), build_info (version, channel)
  lib/data/db/               Drift tables, database, encrypted connection
  lib/data/repositories/     one repository per area (trips, mileage, commute, profile, attachments)
  lib/data/backup/           encrypted .trakta backup file (SQLCipher 4) and restore
  lib/data/calculation/      maps stored rows to engine input; year summary for the overview
  lib/features/<area>/       screens: overview, trips, mileage, commute, settings, onboarding, common
  lib/l10n/                  app_sv.arb (template) and app_en.arb
  drift_schemas/             schema snapshot
  test/                      widget and data tests; test_screenshots/ makes the website screenshots
tool/                        dev script (bin/dev.dart, dev.ps1), build tool (fetches Skatteverket's normalbelopp), rules sync, offline check
design/DESIGN.md             visual source of truth and app icon masters
website/                     Astro 7 + pnpm 10 site, Swedish at /, English at /en/, deployed by Cloudflare Pages' GitHub integration (see website/README.md)
.github/workflows/           checks.yml (the gate), ci.yml (PRs and main, incl. the website build), release.yml (tag vX.Y.Z → APK, Play, draft release),
                             release-published.yml (rebuilds trakta.app), scorecard.yml
.github/actions/setup-app/    shared job setup: Flutter, pub get, codegen; Java + the pinned NDK for Android builds
```

## Commands

Run from the repository root unless noted. `dart tool/bin/dev.dart` (Windows: `powershell -ExecutionPolicy Bypass -File tool\dev.ps1`) runs everything below except the website.

| Task | Command |
| --- | --- |
| Install | `flutter pub get` |
| Code generation | in `apps/trakta_app`: `flutter gen-l10n` and `dart run build_runner build` |
| Analyze | `flutter analyze` |
| Engine tests | `dart test` in `packages/trakta_core` |
| Tool tests | `dart test` in `tool` |
| App tests | `flutter test` in `apps/trakta_app` |
| Sync rules packs to app assets | `dart run tool/bin/sync_rules.dart` (`--check` in CI) |
| Offline check | `dart run tool/bin/check_offline.dart` |
| Database change (schema bump) | in `apps/trakta_app`: `dart run drift_dev make-migrations` (snapshot, steps and migration tests) |
| Check the schema snapshot | in `apps/trakta_app`: `dart run drift_dev schema dump lib/data/db/database.dart drift_schemas/app/`, then `git status drift_schemas` must be clean |
| Website and store screenshots | in `apps/trakta_app`: `flutter test test_screenshots --update-goldens` |
| Website | in `website`: `pnpm install`, `pnpm build`; dev server with `astro dev --background` (`astro dev stop` / `status` / `logs`) |

Run `flutter` and app commands inside `apps/trakta_app`; `flutter run` from the root fails.

## Rules for changes

- **No tax numbers in code.** Amounts, percentages, thresholds and rates go in `rules/<year>.json`, then run the sync. Every rule cites a Skatteverket source (`Sources` in `reason.dart`, `sources` in the pack).
- **The engine stays pure.** `trakta_core` returns language-neutral `ReasonCode`s, never text. A new reason needs the code, a string in both ARB files and a mapping in `apps/trakta_app/lib/features/common/reason_text.dart`.
- **Golden tests per income year.** Name tests after their source. Never change an earlier year's golden file to make a new pack pass.
- **Both languages, always.** Add every string to `app_sv.arb` and `app_en.arb`; `test/l10n_test.dart` checks parity. English keeps the official Swedish term next to the translation, e.g. "Per diem (traktamente)".
- **Store only user input.** Calculated amounts are recomputed, never stored. Money is integer öre, distance integer metres, time UTC plus the IANA zone.
- **Offline.** No network packages in the app (http, dio, Firebase, analytics, crash reporting, ads), also not transitively (`package_info_plus` pulls in `http`), and no `INTERNET` permission in the release manifest. Only `tool/` may use `http`. `url_launcher` is allowed only to open trakta.app (`WebsitePage` in `website_link.dart`).
- **Database.** Schema version 1 is frozen (see Phase above): every change needs `schemaVersion` + migration + `make-migrations` + backup conversion, all tested. A new table is picked up by backups automatically (`allTables`).
- **Design.** Use the theme and tokens in `lib/app/`; no hardcoded colours or sizes in screens.
- **No payment or tip wording in the app.** The app links only to trakta.app; Buy Me a Coffee lives on the website.
- **Not tax advice.** Keep the onboarding consent and the disclaimer; do not imply any connection to Skatteverket.
- **Releases** go only through a `vX.Y.Z` tag on `main` (`docs/releasing.md`). A check added to CI goes in `checks.yml`, so releases run it too. Pin every GitHub Action to a commit SHA with the version in a comment. Never commit `key.properties`, keystores or API keys; the release key never leaves the `release` environment and the maintainer's backup.
- **Licence and trademark.** Code is Apache-2.0. Do not add dependencies with licences incompatible with it, and keep the name and icon rules in `TRADEMARKS.md`.
- **Before finishing:** the change has tests; `dart tool/bin/dev.dart check` passes (analyze, all three test suites, the schema snapshot, sync and offline checks); for website changes `pnpm build` passes. Add user-visible changes under Unreleased in `CHANGELOG.md`, and update the README feature list and `docs/` when they change.
