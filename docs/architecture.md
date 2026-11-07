# Architecture

How Trakta is built. For the tax rules the engine applies, see [tax-rules.md](tax-rules.md); for the rules packs, [rules-packs.md](rules-packs.md).

## Repository layout

```
pubspec.yaml               pub workspace root (+ sqlite3mc encryption hook)
.fvmrc                     the exact Flutter version, used by CI and FVM
rules/                     per-income-year rules packs, the only source of tax numbers
  2026.json                all domestic amounts, meal %, mileage rates + 200 foreign rates
  drafts/2025.json         2025 values without foreign rates (see rules-packs.md)
  schema.json              JSON schema for editors; semantic checks run in trakta_core tests
packages/trakta_core/      pure-Dart rules engine (no Flutter, no I/O)
apps/trakta_app/           Flutter app (Riverpod, go_router, Drift)
tool/                      dev script, rules pack builder, rules sync, offline check
design/                    DESIGN.md (visual source of truth) and app icon masters
docs/                      this documentation
fastlane/metadata/         store and app catalogue texts, screenshots and changelogs
website/                   trakta.app (Astro + pnpm, hosted on Cloudflare Pages), see website/README.md
.github/                   CI, release and Scorecard workflows, issue forms, Dependabot
```

## Layers

```
Presentation (screens, widgets)
  → Application (Riverpod providers)
    → trakta_core (entities, rules engine)        pure Dart, no Flutter, Drift or HTTP
    → Data (repositories)
        → Drift / SQLite, encrypted file
        → bundled rules packs
Build tool (developer machine / CI only) → rules packs
```

- **The engine is pure.** `(trip input, rules pack) → result with a reason per line`, no I/O. Pipeline: eligibility → split into local days → full/half day → country per day → meal reduction → nights → compare with employer payment. Each step adds a `Reason` (code, parameters, source link) that the app translates and shows under "Why?".
- **Only user input is stored.** Calculated amounts are recomputed on every change, never stored, so a corrected rules pack fixes every past trip.
- **Money** is integer öre (`Ore` in `trakta_core`); packs hold whole kronor. **Distance** is integer metres, converted to mil only in the engine. **Time** is stored as UTC plus the IANA zone of the place, because day types and countries use local time.
- **Encryption:** the database uses SQLite3MultipleCiphers via the `sqlite3` build hook (root `pubspec.yaml`). A random 256-bit key is created on first launch and kept in Keychain/Keystore (`flutter_secure_storage`); the app asserts that `PRAGMA cipher` works, so it never falls back to an unencrypted file. Documents live in the app's private folder.
- **Offline guarantee:** `tool/bin/check_offline.dart` (in CI) fails if the merged release manifest has the `INTERNET` permission or the app depends on a banned network package (http, dio, Firebase, analytics, crash reporters, ads). Only `tool/` uses `http`.
- **Schema:** version 1, shipped with 1.0.0 and frozen. Every change bumps `schemaVersion`, adds a migration step with Drift's generated migration tests (`dart run drift_dev make-migrations`, see `apps/trakta_app/lib/data/db/database.dart`), and `BackupRepository.open` converts rows from backups of older versions the same way. `checks.yml` dumps the schema and fails if it differs from the committed snapshot in `drift_schemas/`.
- **Backup** (`apps/trakta_app/lib/data/backup/`): a `.trakta` file is an SQLite database encrypted in the standard SQLCipher 4 format (AES-256, an HMAC on every page, PBKDF2-HMAC-SHA512 with 256 000 iterations from the user's password), written by the same SQLite3MultipleCiphers as the app database. Inside are generic tables (`meta`, `records` with each row's SQL values as JSON, `files` with the documents), so the format does not follow the schema. A restore checks everything first (password, format, schema version, every row, every document's SHA-256, document names) and then replaces all data in one transaction. A backup from a newer app is refused. Password minimum 8 characters; it is never stored.
- **Platforms:** Android and iPhone (the iPhone version is not distributed yet). Android's own backup and device-to-device transfer are turned off (`android:allowBackup="false"` and `xml/data_extraction_rules.xml`): the database key lives in the Android Keystore and never moves, so a copied database could not be opened. On iPhone, an encrypted iCloud or computer backup moves the Keychain along, so a device restore keeps working; the Trakta backup works on both.
- **Version and channel:** `lib/app/build_info.dart` holds the app version (a test keeps it equal to `pubspec.yaml`) and the distribution channel the release workflow sets with `--dart-define=TRAKTA_CHANNEL=github|play|apple`. Settings uses them to say where updates come from, since the app cannot check for updates itself.

## Tests

- **Engine:** `dart test` in `packages/trakta_core`. `test/golden_2026_test.dart` holds golden cases named after their Skatteverket source; keep a separate file per income year so a new pack cannot change old results. When Skatteverket publishes a new worked example, add it as a test before touching the engine. Property tests check that amounts are never negative, a reduction never exceeds the day and adding a meal never increases the amount.
- **Rules packs:** every pack loads and validates (fallback exists, amounts positive, redirects resolve).
- **Build tool and offline check:** `dart test` in `tool/`.
- **App:** `flutter test` in `apps/trakta_app` (widgets, l10n completeness, database).
- **Everything at once:** `dart tool/bin/dev.dart` (Windows: `tool\dev.ps1`) runs code generation, analyze, all three test suites and the schema, sync and offline checks, like CI.

## Design

`design/DESIGN.md` defines colours, type, spacing and components. The app applies it centrally in `apps/trakta_app/lib/app/theme.dart` and `tokens.dart`, so screens use stock Material widgets without hardcoded colours or sizes. The end of `DESIGN.md` lists the rules and how to regenerate the app icon.

## Languages

The app is fully bilingual (Swedish and English); the tax rules are the same in both.

- **One set of rules.** The engine in `trakta_core` applies Swedish tax law and Skatteverket's amounts and returns language-neutral reason codes, never text. Only the app translates those codes into words.
- **Choosing the language.** Settings has a language option (same as phone, Svenska or English). With "same as phone", English phones get English and every other language gets Swedish.
- **Swedish terms stay visible.** The tax return, Skatteverket and employers use Swedish terms. The English text keeps the official term next to the translation, for example "Per diem (traktamente)", "Box 2.2 (Tjänsteresor)" and "Germany (Tyskland)". Settings has a glossary of these terms explained in both languages.
- **Formats follow the language.** Swedish shows `1 226,50 kr`, English shows `SEK 1,226.50`. Amounts are accepted in either format.
- **Completeness is tested.** `apps/trakta_app/test/l10n_test.dart` fails if a message, placeholder, reason code or country name is missing in either language.

To add or change text:

1. Edit both `apps/trakta_app/lib/l10n/app_sv.arb` (the template) and `app_en.arb`.
2. Run `flutter gen-l10n` in `apps/trakta_app`.
3. For a new engine reason, add the `ReasonCode` and both texts, then map it in `lib/features/common/reason_text.dart`.
