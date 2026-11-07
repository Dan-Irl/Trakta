## What and why

<!-- What does this change, and why? Link the issue. For a tax rule, link the Skatteverket source. -->

## How it is tested

<!-- Which tests fail without this change? Anything tested by hand on a phone? If something cannot be tested well, say so. -->

## Checklist

- [ ] Tests that fail without this change (golden tests named after their Skatteverket source for tax rules)
- [ ] `dart tool/bin/dev.dart check` passes (analyze, all tests, schema snapshot, rules sync, offline check)
- [ ] Every new string is in both `app_sv.arb` and `app_en.arb`
- [ ] No tax numbers in code; no change to stored data without a migration and backup conversion
- [ ] `CHANGELOG.md` (Unreleased) and docs updated if users or contributors would notice
- [ ] Website changes: `pnpm build` passes in `website/`
