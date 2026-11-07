# Rules packs

Every tax number lives in `rules/<year>.json`. The app bundles copies in `apps/trakta_app/assets/rules/`. After editing a pack, run `dart run tool/bin/sync_rules.dart`.

Each pack has `incomeYear`, `packVersion`, the domestic amounts, day-type times, meal percentages, mileage and commuting rates, `foreignRates` (redirects already resolved), `foreignFallback`, and `foreignRatesSource` / `foreignRatesTakenOn` so every result can be traced to the data it used. If the app has no pack for a trip's year, it still records the trip but asks the user to update the app instead of guessing with last year's amounts.

Foreign rates come from Skatteverket's open data API (`skatteverket.entryscape.net/rowstore/dataset/70ccea31-b64c-4bf5-84c7-673f04f32505`) through the build tool. This is the only code in the repository that talks to the network, and it never ships in the app. The tool pages through the API, resolves redirect rows (case-insensitively), validates the rows and prints a diff against the previous year for review:

```powershell
cd tool
dart run bin/build_rules_pack.dart --year 2026 --check   # verify the reviewed pack against the API
dart run bin/build_rules_pack.dart --year 2025           # create rules/2025.json from rules/drafts/2025.json
```

## Yearly update

Every year, when Skatteverket publishes the next year's general advice (normally November–December):

- [ ] Read the new SKV A on normalbelopp and any new SKV A on increased living costs.
- [ ] Check the domestic amounts and meal reductions on the Traktamente page.
- [ ] Check the mileage and commuting rates and the commuting threshold.
- [ ] Run the build tool for the new year and review the printed diff against last year.
- [ ] Fill in the domestic, meal, mileage and commuting values, set `packVersion`, add the source URLs, and sync.
- [ ] Add `golden_<year>_test.dart`; keep old years' tests unchanged.
- [ ] Ship an app update before 1 January.
- [ ] Mid-year: watch for corrections and for rules that start on a date (like the 2026-07-01 plug-in hybrid change) and ship them with a bumped `packVersion`. Never regenerate a past year's pack unless Skatteverket changed it.
