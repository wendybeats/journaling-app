// Endpaper content engine — App Store screenshots, v3.
//
// Lockups, not captioned screenshots: each canvas is a composition in
// the reflections-deck grammar — one statement per screen, three
// registers (mono frames, sans states, serif speaks), the layout
// changing shape shot to shot, and the dot punctuating exactly twice
// across the set. The product appears as an element (a card face, a
// cropped device, a fanned deck) rather than as a rectangle with a
// headline over it.
//
// Usage: node render-appstore-v3.mjs [outDir] [sizesCsv]
//   sizesCsv: e.g. "1284x2778" for one size (default: all three)

import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const root = resolve(here, '../..');
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const raw = resolve(tmpdir(), 'endpaper-appstore-raw-v3');
mkdirSync(raw, { recursive: true });

const appURL = 'file://' + root + '/preview.html?seed';
const composeURL = 'file://' + resolve(here, 'appstore/compose-v3.html');
const HIDE = 'footer.type-meta-small,.consent-card{display:none!important}';

// The lineup. First three face App Store search, so the value claim,
// the mechanism, and the proof lead. Themes alternate so no two
// neighbours share a ground.
const SHOTS = [
  {
    slug: 'reads-you-back', variant: 'opener', scheme: 'light',
    stmt: 'The journal that reads you back.',
    sub: 'write today · hear it back on sunday',
    device: 'today', dot: true,
  },
  {
    slug: 'you-write-it-reads', variant: 'split', scheme: 'dark',
    ghost: 'You write.', ink: 'It reads you back.',
    splitFoot: 'your own words · every week · no ai',
  },
  {
    slug: 'kept-surfacing', variant: 'card', scheme: 'light',
    stmt: 'Your week, in your own words.',
    card: {
      kicker: 'Kept surfacing', big: '“the boat”', bigSize: '13vw',
      meta: '6 times · across 4 days',
      quote: 'The boat again. I keep going back to it like a question I haven’t answered.',
      quoteSize: '4.4vw',
    },
    foot: 'every sunday · drawn from what you wrote',
  },
  {
    slug: 'next-session', variant: 'question', scheme: 'light',
    kicker: 'for the ones in therapy', chip: true,
    stmt: 'Know what to bring to your next session.', stmtSmall: true,
    card: {
      kicker: 'You asked yourself',
      quote: 'Am I actually tired of the work, or just the commute?',
      quoteSize: '6.6vw',
    },
    dot: true,
  },
  {
    slug: 'your-week-handed-back', variant: 'fan', scheme: 'dark',
    stmt: 'Your week, handed back.',
    fan: [
      { kicker: 'You wrote this large', big: 'Enough.', bigSize: '11vw', meta: 'Tuesday · 11:04 PM' },
      { kicker: 'Your longest sitting', big: '22:41', bigSize: '12vw', meta: '512 words' },
      { kicker: 'Reflections — your week', big: 'Evening writer.', bigSize: '9vw', meta: '4 of 5 nights · after 9 pm' },
    ],
    foot: 'five moments · one week · your words',
  },
  {
    slug: 'sealed-at-midnight', variant: 'closer', scheme: 'dark',
    stmt: 'Sealed at midnight. Yours for good.', stmtSmall: true,
    sub: 'no ai · no account · no one reading',
    device: 'today',
  },
];

const ALL_SIZES = [
  ['1320x2868', { width: 1320, height: 2868 }],
  ['1290x2796', { width: 1290, height: 2796 }],
  ['1284x2778', { width: 1284, height: 2778 }],
];
const wanted = (process.argv[3] || '').split(',').filter(Boolean);
const SIZES = wanted.length ? ALL_SIZES.filter(([n]) => wanted.includes(n)) : ALL_SIZES;

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

// ---- Pass 1: device-ratio captures of the real app ----
for (const scheme of ['light', 'dark']) {
  const ctx = await browser.newContext({
    viewport: { width: 390, height: 844 }, deviceScaleFactor: 3, colorScheme: scheme,
  });
  const page = await ctx.newPage();
  await page.addInitScript(() => {
    localStorage.setItem('endpaper.onboarded.v1', '1');
    localStorage.setItem('endpaper.trial.v1', JSON.stringify({ startedAt: Date.now() }));
  });
  await page.goto(appURL + '#today');
  await page.addStyleTag({ content: HIDE });
  await page.evaluate(() => document.fonts.ready);
  await page.waitForTimeout(700);
  await page.screenshot({ path: `${raw}/today-${scheme}.png` });
  await ctx.close();
}

const screens = {
  'today-light': readFileSync(`${raw}/today-light.png`).toString('base64'),
  'today-dark': readFileSync(`${raw}/today-dark.png`).toString('base64'),
};

// ---- Pass 2: compose ----
for (const [sizeName, viewport] of SIZES) {
  const ctx = await browser.newContext({ viewport, deviceScaleFactor: 1 });
  const page = await ctx.newPage();
  await page.goto(composeURL);
  await page.evaluate(() => document.fonts.ready);

  for (const [i, shot] of SHOTS.entries()) {
    const data = shot.device ? screens[`${shot.device}-${shot.scheme}`] : '';
    await page.evaluate(({ shot, data }) => {
      const $ = id => document.getElementById(id);
      const show = (el, on) => el.classList.toggle('hide', !on);
      const set = (el, text) => { el.textContent = text || ''; show(el, !!text); };

      document.documentElement.classList.toggle('dark', shot.scheme === 'dark');
      document.body.className = `v-${shot.variant}`;

      // registers
      set($('kicker'), shot.kicker);
      $('kicker').classList.toggle('chip', !!shot.chip);
      set($('stmt'), shot.stmt);
      $('stmt').classList.toggle('sm', !!shot.stmtSmall);
      set($('sub'), shot.sub);
      show($('head'), !!(shot.kicker || shot.stmt || shot.sub));
      set($('foot'), shot.foot);

      // 2 — the split
      show($('wrap'), shot.variant === 'split');
      set($('ghostLine'), shot.ghost);
      $('ghostLine').classList.add('ghost');
      set($('inkLine'), shot.ink);
      set($('splitFoot'), shot.splitFoot);

      // 3 / 4 — a single card face
      show($('cardwrap'), !!shot.card);
      if (shot.card) {
        const c = shot.card;
        set($('cardKicker'), c.kicker);
        set($('cardBig'), c.big);
        if (c.bigSize) $('cardBig').style.fontSize = c.bigSize;
        set($('cardMeta'), c.meta);
        set($('cardQuote'), c.quote);
        if (c.quoteSize) $('cardQuote').style.fontSize = c.quoteSize;
      }

      // 5 — the fanned deck
      show($('fan'), !!shot.fan);
      if (shot.fan) {
        $('fan').innerHTML = shot.fan.map(c => `
          <div class="card">
            <div class="grab"></div>
            <div class="kicker">${c.kicker}</div>
            <div class="said" style="font-size:${c.bigSize};margin-top:4vw">${c.big}</div>
            <div class="meta" style="margin-top:3.5vw">${c.meta}</div>
            <div class="pager"><i></i><i class="on"></i><i></i><i></i><i></i></div>
          </div>`).join('');
      }

      // the dot, and the device
      show($('dot'), !!shot.dot);
      show($('scene'), !!data);
      if (data) $('screen').src = 'data:image/png;base64,' + data;
    }, { shot, data });

    await page.waitForTimeout(200);
    await page.screenshot({ path: `${out}/appstore-v3-${i + 1}-${shot.slug}-${sizeName}.png` });
  }
  await ctx.close();
}

await browser.close();
console.log(`rendered ${SHOTS.length * SIZES.length} v3 screenshots to`, out);
