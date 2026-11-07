# Road to the stores

The Android app is available from GitHub releases and [trakta.app](https://trakta.app/ladda-ner/). This is what is left before Google Play production and the App Store. Tick items off in pull requests as they are done.

## App

- [ ] Test a real phone switch with documents: Android → Android, Android → iPhone and iPhone → Android, through Google Drive and iCloud Drive.
- [ ] Test on at least one real Android phone and one iPhone, in light and dark mode and with large system text.
- [ ] Screen reader pass (TalkBack and VoiceOver). Known gap: commuting calendar days have no spoken status yet.
- [ ] Release build: the `PRAGMA cipher` check passes on both platforms, and a proxy shows zero network calls.
- [ ] Optional: CSV/PDF export of a year (reseräkning, körjournal) for the employer or Skatteverket.
- [x] Licences screen (Settings → Licences).
- [x] Encrypted backup and restore for switching phones.

## Tax rules

- [ ] Re-check the 2026 rules pack against Skatteverket (`dart run bin/build_rules_pack.dart --year 2026 --check` in `tool/`).
- [ ] Resolve or clearly label the [open questions](tax-rules.md#open-questions).
- [ ] **2027 rules pack before 1 January 2027** ([rules-packs.md](rules-packs.md#yearly-update)).
- [x] Long stays are not supported: the store description and the website FAQ say so.

## Google Play production

- [ ] Closed test with **at least 12 testers for 14 days** (required for new personal developer accounts). Recruit on the website: a Google Group as the tester list and its opt-in link on the download page.
- [ ] Store listing in Swedish and English from [`fastlane/metadata/android/`](../fastlane/metadata/android/) ([store-listing.md](store-listing.md)), plus a feature graphic (1024 × 500).
- [ ] Privacy policy URL: `https://trakta.app/integritet/` (or `/en/privacy/`).
- [ ] Data safety form: no data collected, no data shared, data encrypted.
- [ ] Content rating questionnaire; target audience 18+; category Finance; contains ads: no.
- [ ] Trader status under the EU Digital Services Act (a free app with no income is normally non-trader).
- [ ] Automatic uploads: Play service account and `PLAY_RELEASE_STATUS` ([releasing.md](releasing.md#setup)).
- [ ] Promote to production with a staged rollout.

## Direct downloads and app catalogues

- [ ] Register `app.trakta` with the release key for Android developer verification ([releasing.md](releasing.md#keys)) before the global rollout in 2027.
- [ ] [Obtainium](https://obtainium.imranr.dev/): works as soon as the first release is published; check that it finds `trakta.apk`.
- [ ] [IzzyOnDroid](https://apt.izzysoft.de/fdroid/): request inclusion. It needs a free licence, the APK in GitHub releases and fastlane metadata, all in place. Check their APK size limit; separate APKs per CPU type (`--split-per-abi`) are the fallback.
- [ ] [F-Droid](https://f-droid.org/docs/Inclusion_Policy/): F-Droid builds from source and rejects prebuilt binaries. The `sqlite3` build hook downloads a prebuilt SQLite3MultipleCiphers (checksum-pinned); switch it to `source: source` with the sqlite3mc amalgamation for F-Droid builds, and aim for reproducible builds so F-Droid ships the APK signed with the release key.

## App Store (later)

- [ ] Apple Developer Program as an individual (yearly fee); register the bundle ID `app.trakta`.
- [ ] App Store Connect secrets ([releasing.md](releasing.md#setup)), then a TestFlight public link on the download page.
- [ ] App Privacy: **Data Not Collected**. Export compliance (`ITSAppUsesNonExemptEncryption`).
- [ ] Privacy policy URL, support URL, screenshots for the required iPhone sizes, age rating, trader status.

## Website

- [ ] Check the security headers at [securityheaders.com](https://securityheaders.com) and run Lighthouse on `/` and `/en/`.
- [ ] Test link previews for `/` and `/en/`.
- [ ] Read every page in both languages on a phone.
- [ ] When the app is in a store: set `playStore` / `appStore` in `website/src/site.ts` and use the official badges.

## Legal

- [ ] Check that the name is free to use: search "Trakta" in [PRV](https://www.prv.se/sv/varumarken/sok-varumarken/) and [TMview](https://www.tmdn.org/tmview/).
- [ ] Keep the in-app onboarding consent ("Trakta is not tax advice") and the disclaimer under Settings.
- [ ] Never imply a connection to Skatteverket: no Skatteverket logo, no "official" wording.
- [x] Licence (Apache-2.0) and [trademark policy](../TRADEMARKS.md).
