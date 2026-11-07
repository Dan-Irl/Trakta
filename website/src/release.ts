// The newest Android release, for the download page. Fetched from the GitHub
// API once per build (never in the visitor's browser: the CSP in
// public/_headers allows no requests to other sites). The release workflow
// triggers a Cloudflare Pages deploy, so the page shows a new version soon
// after it is published.
//
// Never throws: on any failure (no release yet, private repository, network
// error, rate limit, unexpected JSON) it returns null and the page falls back
// to a link to the releases list.
import { site } from './site';

export interface ReleaseInfo {
  /** Version name without the leading v, e.g. "1.0.1". */
  version: string;
  /** When the release was published, ISO 8601 (UTC). */
  publishedAt: string;
  /** Size of trakta.apk in bytes. */
  sizeBytes: number;
}

/** The asset every release attaches; site.apk and /apk point to it. */
const assetName = 'trakta.apk';
const api = `${site.repo.replace('https://github.com/', 'https://api.github.com/repos/')}/releases/latest`;
const timeoutMs = 8000;

let pending: Promise<ReleaseInfo | null> | undefined;

/** The latest release's trakta.apk, or null. Memoised: one request per build. */
export function latestRelease(): Promise<ReleaseInfo | null> {
  pending ??= fetchLatest();
  return pending;
}

async function fetchLatest(): Promise<ReleaseInfo | null> {
  try {
    const headers: Record<string, string> = {
      Accept: 'application/vnd.github+json',
      'User-Agent': 'trakta.app-build',
    };
    // Optional, only to raise the API rate limit (Cloudflare Pages env var).
    // Read at build time; it never reaches the output.
    const token = (globalThis as unknown as { process?: { env?: Record<string, string | undefined> } }).process?.env
      ?.GITHUB_TOKEN;
    if (token) headers.Authorization = `Bearer ${token}`;

    const response = await fetch(api, { headers, signal: AbortSignal.timeout(timeoutMs) });
    if (!response.ok) return fallback(`HTTP ${response.status} from ${api}`);

    const release: unknown = await response.json();
    const info = parse(release);
    if (!info) return fallback(`no ${assetName} in the latest release, or unexpected JSON`);

    console.info(`[release] ${assetName} ${info.version}, published ${info.publishedAt}, ${info.sizeBytes} bytes`);
    return info;
  } catch (error) {
    return fallback(error instanceof Error ? `${error.name}: ${error.message}` : String(error));
  }
}

function parse(release: unknown): ReleaseInfo | null {
  if (typeof release !== 'object' || release === null) return null;
  const { tag_name, published_at, assets } = release as Record<string, unknown>;
  if (typeof tag_name !== 'string' || typeof published_at !== 'string' || !Array.isArray(assets)) return null;
  if (Number.isNaN(Date.parse(published_at))) return null;

  const apk = assets.find(
    (a): a is { name: string; size: number } =>
      typeof a === 'object' && a !== null && (a as Record<string, unknown>).name === assetName,
  );
  if (!apk || typeof apk.size !== 'number' || !(apk.size > 0)) return null;

  return { version: tag_name.replace(/^v/, ''), publishedAt: published_at, sizeBytes: apk.size };
}

function fallback(reason: string): null {
  console.warn(`[release] No release info (${reason}). The download page links to the releases list instead.`);
  return null;
}
