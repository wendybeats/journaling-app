// Endpaper content engine — product-render harness.
// Drives the web prototype (pixel-identical to the app) headlessly and
// captures the shareable views as finished stills: 9:16 phone frames in
// light and dark, plus a square clip of the year dot matrix.
//
// Usage: node render-app.mjs [outDir]
// Output: <outDir>/{view}-{scheme}.png

import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const url = 'file://' + root + '/preview.html?seed';

// Preview-only chrome that must not appear in marketing captures.
const HIDE = 'footer.type-meta-small{display:none!important}';  // hide the whole preview footer (label + controls)

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

for (const scheme of ['light', 'dark']) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 },
    deviceScaleFactor: 3,
    colorScheme: scheme,
  });
  const page = await ctx.newPage();
  await page.addInitScript(() => {
    localStorage.setItem('endpaper.onboarded.v1', '1');
    localStorage.setItem('endpaper.trial.v1', JSON.stringify({ startedAt: Date.now() }));
  });

  await page.goto(url + '#today');
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(700);

  // The preview keeps state in an in-memory shim, so the pre-set
  // onboarded flag doesn't take — and the onboarding overlay would sit
  // on top of every captured view. Walk it by its controls (Today stays
  // mounted behind, so drive by buttons, not by page text) until the
  // overlay is gone.
  for (let step = 0; step < 10; step++) {
    const clicked = await page.evaluate(() => {
      const advance = /^(skip|continue without an account|start my free week|continue|next|begin|got it|start writing)\b/i;
      const btn = [...document.querySelectorAll('button, a, [role="button"]')].find(b => {
        const t = (b.textContent || '').trim();
        return advance.test(t) && !/restore/i.test(t) && b.offsetParent !== null;
      });
      if (btn) { btn.click(); return true; }
      return false;
    });
    if (!clicked) break;
    await page.waitForTimeout(500);
  }
  await page.evaluate(() => { location.hash = '#today'; });
  await page.addStyleTag({ content: HIDE });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(600);

  // A written day for the day-page shot: newest seeded day.
  // The newest-but-one written day, read off the rendered Notebook so we
  // don't depend on where the prototype keeps its store.
  const dayKey = await page.evaluate(() => {
    location.hash = '#archive';
    return null;
  });

  const views = [
    ['today', '#today'],
    ['notebook', '#archive'],
    ['calendar-year', '#archive/calendar'],
  ];

  for (const [name, hash] of views) {
    await page.evaluate(h => { location.hash = h; }, hash);
    await page.waitForTimeout(700);                 // cross-fade settles
    await page.addStyleTag({ content: HIDE });
    await page.screenshot({ path: `${out}/${name}-${scheme}.png` });
  }

  // Square clip of the year matrix — the month-end dots format.
  await page.evaluate(() => { location.hash = '#archive/calendar'; });
  await page.waitForTimeout(700);
  const block = page.locator('main, body').first();
  const box = await block.boundingBox();
  if (box) {
    const side = 390;
    await page.screenshot({
      path: `${out}/calendar-square-${scheme}.png`,
      clip: { x: 0, y: 120, width: side, height: side },
    });
  }

  await ctx.close();
}

await browser.close();
console.log('rendered to', out);
