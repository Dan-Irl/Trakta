# trakta.app

The website for Trakta, built with [Astro](https://astro.build) and pnpm. Swedish at `/`, English at `/en/`. Static output, hosted on Cloudflare Pages.

```sh
pnpm install
pnpm dev        # http://localhost:4321
pnpm build      # static site in dist/
pnpm preview    # serve dist/ locally
```

## Where things are

| What | Where |
|---|---|
| Domain, repository, APK and releases links, signing certificate fingerprint, contact email, author | `src/site.ts` |
| All copy, both languages | `src/i18n.ts` |
| Design tokens (from `design/DESIGN.md`) | `src/styles/global.css` |
| Home page | `src/components/Home.astro` (download buttons: `DownloadButtons.astro`) |
| Download page | `src/components/Download.astro`, used by `src/pages/ladda-ner.astro` and `src/pages/en/download.astro` |
| Latest release info (build time) | `src/release.ts` |
| Privacy policy / terms | `src/pages/integritet.astro`, `src/pages/villkor.astro`, `src/pages/en/privacy.astro`, `src/pages/en/terms.astro` |
| Security and cache headers (Cloudflare Pages) | `public/_headers` |
| Redirects: `/apk`, `/kallkod`, `/source` (Cloudflare Pages) | `public/_redirects` |
| Deployment | Cloudflare Pages GitHub integration: `main` goes live, pull requests get preview URLs (see [Infrastructure](#infrastructure)) |
| Node version (CI and Cloudflare) | `.node-version` |

## Screenshots

The four app screenshots per language in `src/assets/screenshots/` come from the real app with demo data. After UI changes, regenerate them:

```sh
cd ../apps/trakta_app
flutter test test_screenshots --update-goldens
```

`public/og-image.png` (link previews) and the icons were made from `design/app_icon.png`.

## Downloads

Trakta is distributed as a signed APK on the repository's GitHub releases; Google Play has only a closed test that is not linked from the site, and there is no iPhone version yet (`playStore` / `appStore` in `src/site.ts` stay `null`).

- **Asset name.** Every release attaches the APK as `trakta.apk` (plus `SHA256SUMS.txt` and a build provenance attestation). `https://github.com/Dan-Irl/Trakta/releases/latest/download/trakta.apk` therefore always serves the newest one, and `/apk` on the site redirects there (`public/_redirects`). Keep the asset name, `site.apk` and the redirect in step.
- **Fixed addresses.** The app links to `/kallkod` and `/source` (redirects to the repository) and to `/ladda-ner/` and `/en/download/` (the download pages) for updates, since it has no internet access and cannot check for them itself. Do not move them.
- **Release info at build time.** `src/release.ts` asks the GitHub API for the latest release once per build and shows its version, date and size on the download page. Nothing is fetched in the visitor's browser (the CSP in `public/_headers` stays `'self'`). On any failure (no release yet, private repository, network error, rate limit) it logs a `[release]` warning and returns `null`; the page then shows "First release coming soon" and a link to the releases list, and the build never fails.
- **New release, new build.** Cloudflare Pages only rebuilds by itself for changes in `website/`. The release workflow creates a draft GitHub release; when it is published, `.github/workflows/release-published.yml` calls a Cloudflare Pages deploy hook, so the download page shows the new version within minutes. The hook URL is the `CLOUDFLARE_PAGES_DEPLOY_HOOK` secret in the GitHub `release` environment (created in the Pages project's build settings under "Deploy hooks", for branch `main`). Without it the workflow only warns, and the page catches up at the next website change. Release steps: `docs/releasing.md`.
- **Rate limits.** Unauthenticated API calls are limited to 60 an hour per IP address, and Cloudflare's build machines are shared. To avoid falling back to `null` because of that, set an optional `GITHUB_TOKEN` environment variable in the Pages project (a fine-grained token with read-only access to public repositories is enough). It is only sent to `api.github.com` and never ends up in the output.
- **Signing certificate.** The SHA-256 fingerprint on the download page is `signingCertSha256` in `src/site.ts`. Update it only if the release key ever changes (which would also stop Android from installing updates over existing installs).

## Infrastructure

trakta.app is a Cloudflare Pages project connected to this repository through Cloudflare's GitHub integration (Workers & Pages → Create → Pages → Connect to Git):

| Setting | Value |
|---|---|
| Production branch | `main` |
| Framework preset | Astro |
| Root directory | `website` |
| Build command | `pnpm build` |
| Build output directory | `dist` |
| Environment variables | `PNPM_VERSION` = the version in `packageManager` in `package.json` (now `10.30.1`); optional `GITHUB_TOKEN` (see [Downloads](#downloads)) |
| Build watch paths (Settings → Build) | include `website/*`, so app-only commits do not rebuild the site |
| Preview deployments | on for branches in this repository; do **not** build pull requests from forks (their code would run in the build with the project's environment variables) |
| Custom domain | `trakta.app`; HTTPS is automatic (`.app` only works over HTTPS) |
| Deploy hook | for the release workflow (see [Downloads](#downloads)) |

Keep Cloudflare Web Analytics, Email Address Obfuscation, Rocket Loader and Zaraz **off**. They inject scripts that the privacy policy says the site does not load, and the CSP would block them anyway.

The contact address `hello@trakta.app` (`site.email`) forwards to the maintainer through Cloudflare Email Routing. More setup notes (DNS, email sending, DMARC) are in the root README's going live checklist.
