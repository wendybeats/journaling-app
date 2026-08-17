// Endpaper content engine — hardware device mockups on transparent
// canvas (appstore/device.html). Outputs angled + flat, app-screen +
// blank-white variants, ready to composite anywhere.
//
// Usage: node render-device.mjs [outDir]

import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const appURL = 'file://' + root + '/preview.html?seed';
const deviceURL = 'file://' + resolve(here, 'appstore/device.html');
const HIDE = 'footer.type-meta-small,.consent-card{display:none!important}';

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

// Capture the app screen (today, light)
const cap = resolve(tmpdir(), 'device-raw.png');
{
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, colorScheme: 'light',
  });
  const page = await ctx.newPage();
  await page.addInitScript(() => {
    localStorage.setItem('endpaper.onboarded.v1', '1');
    localStorage.setItem('endpaper.trial.v1', JSON.stringify({ startedAt: Date.now() }));
  });
  await page.goto(appURL + '#today');
  await page.addStyleTag({ content: HIDE });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(600);
  await page.screenshot({ path: cap });
  await ctx.close();
}

const data = readFileSync(cap).toString('base64');
const variants = [
  ['angled-app', ''],
  ['angled-blank', '?blank'],
  ['flat-app', '?flat'],
  ['flat-blank', '?blank&flat'],
];

for (const [name, qs] of variants) {
  const ctx = await browser.newContext({
    viewport: { width: 1400, height: 1900 }, deviceScaleFactor: 2,
  });
  const page = await ctx.newPage();
  await page.goto(deviceURL + qs);
  await page.evaluate((d) => {
    document.getElementById('shot').src = 'data:image/png;base64,' + d;
  }, data);
  await page.waitForTimeout(250);
  await page.screenshot({ path: `${out}/device-${name}.png`, omitBackground: true });
  await ctx.close();
}

await browser.close();
console.log('device mockups rendered to', out);
