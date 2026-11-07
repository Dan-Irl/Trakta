// @ts-check
import { defineConfig } from 'astro/config';
import sitemap from '@astrojs/sitemap';

import { site } from './src/site.ts';

// Swedish at /, English at /en/. Static output, deployed to Cloudflare Pages.
export default defineConfig({
  site: site.url,
  trailingSlash: 'ignore',
  i18n: {
    defaultLocale: 'sv',
    locales: ['sv', 'en'],
    routing: { prefixDefaultLocale: false },
  },
  integrations: [
    sitemap({
      i18n: { defaultLocale: 'sv', locales: { sv: 'sv-SE', en: 'en' } },
    }),
  ],
});
