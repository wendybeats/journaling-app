// Endpaper content engine — App Store screenshots, v2 (value-first set).
// Same two-pass shape as render-appstore.mjs, composed through
// appstore/compose-v2.html: sans headline, kicker chip, device bleeding
// off the bottom, accent dot. Shot 2 is the reflection-card graphic.
//
// Usage: node render-appstore-v2.mjs [outDir] [sizesCsv]
//   sizesCsv: e.g. "1284x2778" to render one size (default: all three)

import { chromium } from 'playwright';
import { mkdirSync, readFileSync, readdirSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const raw = resolve(tmpdir(), 'endpaper-appstore-raw-v2');
mkdirSync(raw, { recursive: true });

const appURL = 'file://' + root + '/preview.html?seed';
const composeURL = 'file://' + resolve(here, 'appstore/compose-v2.html');
const HIDE = 'footer.type-meta-small,.consent-card{display:none!important}';

// The lineup — value first, then mechanism, then the use cases the
// value serves, then practice and trust. First three face search.
const SHOTS = [
  { slug: 'gets-to-know-you', view: '#today', scheme: 'light',
    headline: 'The journal that gets to know you.',
    kicker: '', sub: '', accent: 'right' },
  { slug: 'reads-you-back', view: null, scheme: 'light',
    headline: 'You write. It reads you back.',
    kicker: '', sub: 'your own words · every week · no AI',
    accent: '', reflection: true },
  { slug: 'next-session', view: 'DAY', scheme: 'light',
    headline: 'Know what to bring to your next session.',
    kicker: 'for the ones in therapy', sub: '', accent: 'left' },
  { slug: 'untangle-then-act', view: '#archive', scheme: 'dark',
    headline: 'Untangle it. Then act.',
    kicker: 'for founders & overthinkers', sub: '', accent: 'right' },
  { slug: 'one-honest-line', view: '#archive/calendar', scheme: 'light',
    headline: 'One honest line a day.',
    kicker: '', sub: 'each day, a dot fills in', accent: '' },
  { slug: 'sealed-at-midnight', view: '#today', scheme: 'dark',
    headline: 'Sealed at midnight. Yours for good.',
    kicker: '', sub: 'no AI · no account · no one reading', accent: 'left' },
];

const ALL_SIZES = [
  ['1320x2868', { width: 1320, height: 2868 }],
  ['1290x2796', { width: 1290, height: 2796 }],
  ['1284x2778', { width: 1284, height: 2778 }],
];
const wanted = (process.argv[3] || '').split(',').filter(Boolean);
const SIZES = wanted.length ? ALL_SIZES.filter(([n]) => wanted.includes(n)) : ALL_SIZES;

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
    SHOTS.filter(s => s.scheme === scheme && s.view)
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
    let data = '';
    if (shot.view) {
      const file = shot.view === 'DAY'
        ? readdirSync(raw).find(f => f.startsWith('_archive_day') && f.endsWith(`${shot.scheme}.png`))
        : `${shot.view.replace(/[#/]/g, '_')}-${shot.scheme}.png`;
      data = readFileSync(resolve(raw, file)).toString('base64');
    }
    await page.evaluate(({ shot, data }) => {
      document.documentElement.classList.toggle('dark', shot.scheme === 'dark');
      document.body.className = [
        shot.accent ? `accent-${shot.accent}` : '',
        shot.reflection ? 'show-reflection no-device' : '',
      ].join(' ').trim();
      document.getElementById('kicker').textContent = shot.kicker || '';
      document.getElementById('headline').textContent = shot.headline;
      document.getElementById('sub').textContent = shot.sub || '';
      if (data) document.getElementById('screen').src = 'data:image/png;base64,' + data;
    }, { shot, data });
    await page.waitForTimeout(120);
    await page.screenshot({ path: `${out}/appstore-v2-${i + 1}-${shot.slug}-${sizeName}.png` });
  }
  await ctx.close();
}

await browser.close();
console.log(`rendered ${SHOTS.length * SIZES.length} v2 screenshots to`, out);
