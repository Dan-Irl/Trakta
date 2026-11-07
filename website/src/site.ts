// Everything about the site that is not copy: domain, contact, the source code
// and where the Android app is downloaded. Trakta is distributed as a signed APK
// on GitHub releases for now; the store links stay null until the app is
// published there (the Google Play closed test is not linked publicly).
const repo = 'https://github.com/Dan-Irl/Trakta';

export const site = {
  /** Production domain (Cloudflare Pages custom domain). */
  url: 'https://trakta.app',
  name: 'Trakta',
  author: 'Dan Johansson',
  linkedIn: 'https://www.linkedin.com/in/dan-johansson-370bb41a1',
  /** Where questions and privacy requests go (Cloudflare Email Routing). */
  email: 'hello@trakta.app',
  /** Buy Me a Coffee page. A plain link: the site loads no third-party scripts. */
  support: 'https://buymeacoffee.com/danjohansson',
  /** The source code. /kallkod and /source redirect here (public/_redirects); the app links to them. */
  repo,
  /** SPDX identifier, as the app shows it. In running text the site writes "Apache License 2.0". */
  licence: 'Apache-2.0',
  /**
   * Always the newest signed APK: every release attaches it as `trakta.apk`.
   * /apk redirects here (public/_redirects). Keep the two in step.
   */
  apk: `${repo}/releases/latest/download/trakta.apk`,
  releases: `${repo}/releases`,
  /** SHA-256 fingerprint of the certificate the GitHub APK is signed with. */
  signingCertSha256: '20:EE:F0:03:4B:0B:29:D6:4E:3A:25:23:B8:9C:7D:27:D6:AD:91:DD:B8:97:B0:AD:EE:DB:A2:11:AA:2F:66:3E',
  /** The name Trakta and the icon are not covered by the licence but by this policy. */
  trademarks: `${repo}/blob/main/TRADEMARKS.md`,
  /** Open source app that installs and updates apps from GitHub releases. */
  obtainium: 'https://obtainium.imranr.dev/',
  playStore: null as string | null,
  appStore: null as string | null,
  /** Shown on the legal pages; update when the text changes. */
  legalUpdated: '2026-11-07',
} as const;
