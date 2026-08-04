// Endpaper content engine — App Store screenshots.
// Pass 1 captures the seeded prototype at device ratio (390×844 @3x),
// pass 2 composes each shot through appstore/compose.html — caption up
// top, the screen in a quiet frame — at both required portrait sizes.
//
// Usage: node render-appstore.mjs [outDir]
// Output: <outDir>/appstore-{n}-{slug}-{size}.png

import { chromium } from 'playwright';
import { mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const raw = resolve(tmpdir(), 'endpaper-appstore-raw');
mkdirSync(raw, { recursive: true });

const appURL = 'file://' + root + '/preview.html?seed';
const composeURL = 'file://' + resolve(here, 'appstore/compose.html');
// Preview chrome and ask-cards must not appear in store shots: the footer
// entirely (its "Endpaper — preview" tag included), and any consent-register
// card the seeded state happens to trigger.
const HIDE = 'footer.type-meta-small,.consent-card{display:none!important}';

// The lineup. First three are what search results show.
const SHOTS = [
  { slug: 'open-write-close', view: '#today', scheme: 'light',
    caption: 'Open. Write. Close.' },
  { slug: 'written-in-ink', view: 'DAY', scheme: 'light',
    caption: 'Written in ink. <em>No editing. No deleting.</em>' },
  { slug: 'a-year-you-can-hold', view: '#archive/calendar', scheme: 'light',
    caption: 'A year you can hold.' },
  { slug: 'no-one-reading', view: '#today', scheme: 'dark',
    caption: 'No AI. No account. <em>No one reading.</em>' },
  { slug: 'one-notebook', view: '#archive', scheme: 'dark',
    caption: 'Every day, one notebook.' },
  { slug: 'honest-version', view: '#archive/calendar', scheme: 'dark',
    caption: 'The honest version of your year.' },
];

// App Store Connect takes a single iPhone set now (6.9-inch, auto-scaled
// to older devices). Both accepted pixel sizes are rendered; upload ONE
// set — 1320×2868 first choice, 1290×2796 the fallback.
const SIZES = [
  ['1320x2868', { width: 1320, height: 2868 }],
  ['1290x2796', { width: 1290, height: 2796 }],
];

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

// ---- Pass 1: raw device-ratio captures ----
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
  await page.goto(appURL + '#today');
  await page.addStyleTag({ content: HIDE });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(600);

  const dayKey = await page.evaluate(() => {
    for (const k of Object.keys(localStorage)) {
      if (k.includes('entries')) {
        const days = Object.keys(JSON.parse(localStorage.getItem(k)) || {});
        return days.sort().at(-2) || days.sort().at(-1);
      }
    }
    return null;
  });

  const needed = new Set(
    SHOTS.filter(s => s.scheme === scheme)
         .map(s => s.view === 'DAY' ? `#archive/day/${dayKey}` : s.view)
  );
  for (const hash of needed) {
    await page.evaluate(h => { location.hash = h; }, hash);
    await page.waitForTimeout(700);
    await page.addStyleTag({ content: HIDE });
    const slug = hash.replace(/[#/]/g, '_');
    await page.screenshot({ path: `${raw}/${slug}-${scheme}.png` });
  }
  await ctx.close();
}

// ---- Pass 2: compose ----
for (const [sizeName, viewport] of SIZES) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.goto(composeURL);
  await page.evaluate(() => document.fonts.ready);

  for (const [i, shot] of SHOTS.entries()) {
    const hash = shot.view === 'DAY'
      ? readdirDay(shot.scheme)
      : `${shot.view.replace(/[#/]/g, '_')}-${shot.scheme}.png`;
    const img = readFileSync(resolve(raw, hash));
    await page.evaluate(({ caption, dark, data }) => {
      document.documentElement.classList.toggle('dark', dark);
      document.getElementById('caption').innerHTML = caption;
      document.getElementById('screen').src = 'data:image/png;base64,' + data;
    }, { caption: shot.caption, dark: shot.scheme === 'dark', data: img.toString('base64') });
    await page.waitForTimeout(120);
    await page.screenshot({
      path: `${out}/appstore-${i + 1}-${shot.slug}-${sizeName}.png`,
    });
  }
  await ctx.close();
}

// The day-page raw file has a date key in its name; find it.
function readdirDay(scheme) {
  return readdirSync(raw).find(f => f.startsWith('_archive_day') && f.endsWith(`${scheme}.png`));
}

await browser.close();
console.log(`rendered ${SHOTS.length * SIZES.length} screenshots to`, out);
