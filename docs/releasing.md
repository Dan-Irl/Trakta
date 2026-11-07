# Releasing

Users keep a year of trips, drives and receipts in Trakta, so a release must never break their data. Everything below exists to keep a bad build away from them.

## Channels

| Channel | Signed with | Updates | Status |
| --- | --- | --- | --- |
| **GitHub releases** (`trakta.apk`), linked from [trakta.app/ladda-ner](https://trakta.app/ladda-ner/); also Obtainium and IzzyOnDroid | the **release key** (yours) | the user installs the new APK (Obtainium can do it) | public |
| **Google Play** | Google's app signing key (Play App Signing) | Play | internal and closed testing |
| **App Store / TestFlight** | Apple | Apple | not set up yet |

Android only installs an update signed with the same key as the installed app. A GitHub install and a Play install are therefore separate: to switch, the user makes a backup in Trakta, uninstalls, installs the other version and restores the backup. The download page says so.

The **release key certificate** (SHA-256), also shown on the download page and in every release:

```
20:EE:F0:03:4B:0B:29:D6:4E:3A:25:23:B8:9C:7D:27:D6:AD:91:DD:B8:97:B0:AD:EE:DB:A2:11:AA:2F:66:3E
```

## How a release flows

```
tag v1.2.0 on main
  ├─ checks          same gate as every pull request
  ├─ prepare         tag is on main, tag = pubspec version, CHANGELOG has notes, rules pack for this year is bundled
  ├─ android-apk     APK signed with the release key → offline check → certificate check → SHA256SUMS + build provenance
  ├─ android-play    app bundle signed with the upload key → offline check → Play internal testing
  ├─ ios             → TestFlight (skipped until set up)
  └─ github-release  a DRAFT release with trakta.apk, SHA256SUMS.txt and the CHANGELOG notes

you: install the draft's APK on a real phone over the previous version, then publish the draft
  └─ release-published.yml   rebuilds trakta.app, whose download page reads the latest release
```

- **One gate for everything.** Releases call the same `checks.yml` as pull requests, so nothing is published that CI would have rejected.
- **Only reviewed code ships.** `main` only takes pull requests with green CI, only the maintainer can create `v*` tags, and the workflow refuses a tag that is not on `main`.
- **Nothing reaches users by itself.** The GitHub release is a draft, and `releases/latest` (which the website and Obtainium follow) ignores drafts. Play uploads go to the internal testing track. You promote both by hand after trying the build on a phone.
- **The download is verifiable.** The workflow checks that the APK is signed with the release key, publishes its SHA-256 checksum and creates a [build provenance attestation](https://docs.github.com/actions/security-for-github-actions/using-artifact-attestations) that ties `trakta.apk` to this repository and workflow run: `gh attestation verify trakta.apk --repo Dan-Irl/Trakta`.
- **Never mark a release as a pre-release.** `releases/latest` skips pre-releases, so the download link would keep serving the old version. Say "beta" in the notes instead.
- **Secrets live in the `release` environment**, which only `v*` tags can use. No pull request or other workflow can read them.
- **Release builds use no cache**, so nothing written by another run can end up in a published app.

## Releasing a version

1. In a pull request: bump `version:` in `apps/trakta_app/pubspec.yaml` **and** `appVersion` in `apps/trakta_app/lib/app/build_info.dart` (a test checks they match). The name follows semantic versioning (1.0.1 fixes, 1.1.0 features); the build number after `+` always increases, across all channels.
2. In the same pull request: move the user-visible changes in `CHANGELOG.md` from "Unreleased" to `## [x.y.z]` (CI checks the section exists; its text becomes the release notes), and add `fastlane/metadata/android/{sv-SE,en-US}/changelogs/<build number>.txt`.
3. Merge, then tag: `git tag v1.2.0 && git push origin v1.2.0`.
4. When the workflow is green, open the draft release on GitHub, download `trakta.apk` and install it **over the previous version on a real phone with data in it**. Check that the data is still there and try the changed flows.
5. Publish the draft. trakta.app shows the new version a few minutes later.
6. For Play: install from the internal testing track the same way, then promote in Play Console (closed testing, later production with a staged rollout).

If something is wrong before publishing: delete the draft and the tag (`git push origin :refs/tags/v1.2.0`), fix, and release a new build number.

## Setup

Repository **variables** (Settings → Secrets and variables → Actions → Variables):

| Variable | Value | Used by |
| --- | --- | --- |
| `ANDROID_PACKAGE_NAME` | `app.trakta` | both Android jobs (checks the app ID) |
| `ANDROID_RELEASE_CERT_SHA256` | the release key certificate above | APK job (refuses any other key), release notes |
| `PLAY_RELEASE_STATUS` | `completed` once the app has been published in Play Console (default `draft`) | Play job |
| `IOS_BUNDLE_ID`, `APPLE_TEAM_ID` | `app.trakta`, the 10-character team ID | iOS job (skipped while empty) |

**Secrets** in the `release` environment:

| Secret | What it is |
| --- | --- |
| `ANDROID_RELEASE_KEYSTORE_BASE64` | the release keystore, `base64 -w0 trakta-release.jks` |
| `ANDROID_RELEASE_KEYSTORE_PASSWORD`, `ANDROID_RELEASE_KEY_ALIAS`, `ANDROID_RELEASE_KEY_PASSWORD` | its password and alias (`trakta`; PKCS12, so both passwords are the same) |
| `ANDROID_KEYSTORE_BASE64`, `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | the Play **upload** key |
| `PLAY_SERVICE_ACCOUNT_JSON` | Google Cloud service account key with release rights for this app only; without it the bundle is kept as a workflow artifact to upload by hand |
| `CLOUDFLARE_PAGES_DEPLOY_HOOK` | deploy hook URL from Cloudflare Pages (Settings → Builds → Deploy hooks), so publishing a release rebuilds the download page |
| `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`, `APP_STORE_CONNECT_KEY_P8_BASE64` | App Store Connect API key (Admin role, for cloud signing) |

The `release` environment's deployment rule allows only `v*` tags. Repository rulesets protect `main` (pull request and green `CI` required, no force pushes) and `v*` tags (only the maintainer creates them).

### Keys

- **Release key** (direct downloads): RSA 4096, alias `trakta`, valid 50 years. It can never change: every user who installed from GitHub would have to reinstall. Keep the keystore and its password in a password manager and offline; the copy in the secrets is not a backup.
- **Upload key** (Play): only proves uploads to Google. Google holds the app signing key (Play App Signing), and a lost upload key can be reset in Play Console.
- **Android developer verification:** from 2027, Android only installs apps registered to a verified developer on certified phones (Brazil, Indonesia, Singapore and Thailand since 30 September 2026). The Play Console identity is verified and Play builds are registered automatically. Register `app.trakta` **with the release key** too (Play Console → Android developer verification, apps distributed outside Play), or GitHub users will need Android's "advanced flow" to install.
- `android/app/build.gradle.kts` signs release builds with `android/key.properties` (git-ignored, written by the workflow) and falls back to the debug key without it, so local release builds still run.

### Platform notes

- **First Play upload.** The Play API can only update an app that already has a build. Without `PLAY_SERVICE_ACCOUNT_JSON` the job keeps the signed bundle as the run's `android-<version>` artifact and shows the upload certificate's SHA-256 to compare with Play Console.
- **iOS** is not distributed yet. When it is: Apple Developer Program, register the bundle ID `app.trakta`, add the App Store Connect key, set `ITSAppUsesNonExemptEncryption` in `ios/Runner/Info.plist` after reading Apple's export compliance guidance, and use a TestFlight public link. The first build creates `ios/Podfile`; commit it.
- **Website.** Cloudflare Pages builds `main` on every push that changes `website/`, and the release hook rebuilds it on publish (see [website/README.md](../website/README.md)).
- **Build artifacts** (APK, AAB, IPA) are kept for 90 days on each workflow run.
