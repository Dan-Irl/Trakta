# Contributing to Trakta

Thanks for helping! Trakta is used by people who keep a year of trips, drives and receipts in it and file their tax return from its numbers. So the bar is: **correct, tested and never losing data.** This guide explains how to get there.

## Ways to help

- **Report a wrong amount or rule.** Use the "Wrong amount or rule" issue form and link the Skatteverket page that shows the right answer. These reports matter most.
- **Report a bug** with the "Bug report" form. The version and where you installed from are under Settings.
- **Suggest a feature**, or pick one from the roadmap: items marked ⬜ in the [README](README.md#features) and issues labelled `good first issue` or `help wanted`.
- **Improve the texts** in Swedish or English, the website or the docs.
- **The yearly rules pack.** Every November–December, Skatteverket publishes next year's amounts; see [docs/rules-packs.md](docs/rules-packs.md#yearly-update).

For anything bigger than a small fix, open an issue first so we can agree on the approach before you spend time on it.

Questions about your own taxes are for Skatteverket, not this repository (see [SUPPORT.md](SUPPORT.md)). Please never post personal data (names, addresses, registration numbers, salary) in issues; they are public.

## Set up

1. Install the Flutter SDK. The exact version is in [`.fvmrc`](.fvmrc); with [FVM](https://fvm.app), `fvm use` picks it up.
2. Clone and run everything once:

   ```sh
   dart tool/bin/dev.dart        # Windows: powershell -ExecutionPolicy Bypass -File tool\dev.ps1
   ```

   This runs `pub get`, the rules sync, code generation (localizations and Drift), `flutter analyze`, the engine, tool and app tests, and the schema, sync and offline checks: the same gate as CI. `dart tool/bin/dev.dart check` skips the setup.
3. Run the app: `cd apps/trakta_app` and `flutter run`.

The website is separate: `pnpm install` and `pnpm build` in `website/` (see [website/README.md](website/README.md)).

Read [docs/architecture.md](docs/architecture.md) for how the code is organised and [docs/tax-rules.md](docs/tax-rules.md) for the rules the engine applies.

## Ground rules

These are not negotiable. CI enforces most of them; review covers the rest. [AGENTS.md](AGENTS.md) has the full list, written for AI coding agents and just as binding for people.

- **Every change has tests that fail without it:** unit tests for logic, golden tests named after their Skatteverket source for tax rules, widget tests for screens and flows. A bug fix starts with a test that reproduces the bug.
- **No tax numbers in code.** Amounts, percentages, thresholds and rates live in `rules/<year>.json`, with a source. Never change an earlier year's golden tests to make a new pack pass.
- **Never break stored data.** Database schema version 1 is frozen: a table change needs a new `schemaVersion`, a migration, `dart run drift_dev make-migrations` and a conversion for older backups, all tested. Never rename an enum value that is stored.
- **Backups stay restorable** from every released version.
- **Both languages, always.** Every string goes in `app_sv.arb` and `app_en.arb`; English keeps the official Swedish term next to the translation.
- **Offline.** No network packages in the app and no `INTERNET` permission. The app only ever opens links to trakta.app.
- **Store only user input.** Calculated amounts are recomputed, never stored. Money is integer öre, distance integer metres, time UTC plus the IANA zone.
- **Design tokens** from `lib/app/`, no hardcoded colours or sizes.
- **Not tax advice.** Keep the disclaimer and never imply a connection to Skatteverket.

## Pull requests

- One topic per pull request, as small as it can be. Explain *why* in the description.
- CI must be green: analyze, all three test suites, the schema snapshot, the rules sync and the offline check. Website changes must pass `pnpm build`.
- Add a line under **Unreleased** in [CHANGELOG.md](CHANGELOG.md) for anything a user would notice, and update the README feature list or the docs when they change.
- If something cannot be tested well, say so in the pull request and propose how to test it.
- Releases are made by the maintainer ([docs/releasing.md](docs/releasing.md)); do not bump the version in a feature pull request.

Using an AI coding agent is fine. You are still responsible for the change, its tests and for having read the diff.

## Licence

By contributing, you agree that your contribution is licensed under the [Apache License 2.0](LICENSE), like the rest of the project (section 5 of the licence). There is no separate contributor agreement. The name and logo stay covered by the [trademark policy](TRADEMARKS.md).

Everyone taking part follows the [code of conduct](CODE_OF_CONDUCT.md).
