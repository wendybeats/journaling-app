// Endpaper content engine — profile kit.
// Renders the avatar (1000×1000) and platform banners (X 1500×500,
// YouTube 2560×1440 with centered safe area), light and dark.
//
// Usage: node render-profile.mjs [outDir]

import { chromium } from 'playwright';
import { mkdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const url = 'file://' + resolve(here, 'profile/profile.html');

const TARGETS = [
  ['avatar', { width: 1000, height: 1000 }],
  ['banner-x', { width: 1500, height: 500 }],
  ['banner-yt', { width: 2560, height: 1440 }],
];

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

for (const scheme of ['light', 'dark']) {
  for (const [mode, viewport] of TARGETS) {
    const ctx = await browser.newContext({ viewport, colorScheme: scheme });
    const page = await ctx.newPage();
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    await page.evaluate((m) => { document.body.dataset.mode = m; }, mode);
    await page.waitForTimeout(60);
    await page.screenshot({ path: `${out}/profile-${mode}-${scheme}.png` });
    await ctx.close();
  }
}

await browser.close();
console.log('rendered profile kit to', out);
