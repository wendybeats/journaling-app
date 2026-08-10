// Endpaper content engine — quote motion cards.
// Types a line onto the page with the app's living-type shrink, holds,
// then the SAVED ack — recorded as video. Story (1080×1920) and feed
// (1080×1350) sizes, light and dark, H.264 for the platforms.
//
// Usage: node render-quote.mjs "The quote." [outDir] [slug] [YYYY-MM-DD]
// The optional date renders the page (and caption) for a future posting
// day — the 07:05 franchise schedules the night before.
// Requires ffmpeg (auto-resolved from @ffmpeg-installer if present).

import { chromium } from 'playwright';
import { mkdirSync, renameSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const text = process.argv[2] || 'Those who commit to nothing are distracted by everything.';
const out = resolve(process.argv[3] || resolve(here, 'out'));
const slug = process.argv[4] || 'quote';
const dateArg = process.argv[5] || '';           // YYYY-MM-DD, optional
mkdirSync(out, { recursive: true });

let ffmpeg = null;
for (const p of [
  resolve(here, 'node_modules/@ffmpeg-installer/linux-x64/ffmpeg'),
  '/tmp/claude-0/-home-user-journaling-app/d88db19a-3a29-5cbd-8e42-f4e7f24e6265/scratchpad/node_modules/@ffmpeg-installer/linux-x64/ffmpeg',
]) {
  try { execFileSync(p, ['-version'], { stdio: 'ignore' }); ffmpeg = p; break; } catch {}
}

const SIZES = [
  ['story', { width: 1080, height: 1920 }],
  ['feed', { width: 1080, height: 1350 }],
];

// The SAVED stamp and the caption must tell the same time. Mornings for
// light, evenings for dark, with a lived-in minute rather than a fixed one.
function stampFor(theme) {
  if (theme === 'light') {
    const m = 48 + Math.floor(Math.random() * 41);          // 6:48–7:28 AM
    return m < 60 ? `6:${String(m).padStart(2, '0')} AM` : `7:${String(m - 60).padStart(2, '0')} AM`;
  }
  const m = 14 + Math.floor(Math.random() * 46);            // 9:14–9:59 PM
  return `9:${String(m).padStart(2, '0')} PM`;
}

function captionFor(stamp) {
  const now = dateArg ? new Date(dateArg + 'T12:00:00') : new Date();
  const day = now.toLocaleDateString('en-US', { weekday: 'long' });
  const mon = now.toLocaleDateString('en-US', { month: 'short' });
  const d = now.getDate();
  const ord = (d % 10 === 1 && d !== 11) ? 'st' : (d % 10 === 2 && d !== 12) ? 'nd'
            : (d % 10 === 3 && d !== 13) ? 'rd' : 'th';
  const t = stamp.replace(' AM', 'am').replace(' PM', 'pm');
  return `Thought of ${day}, ${mon} ${d}${ord} at ${t}`;
}

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

const stamps = { light: stampFor('light'), dark: stampFor('dark') };

for (const [sizeName, viewport] of SIZES) {
  for (const theme of ['light', 'dark']) {
    const vidDir = resolve(tmpdir(), `quote-vid-${sizeName}-${theme}`);
    rmSync(vidDir, { recursive: true, force: true });
    const ctx = await browser.newContext({
      viewport,
      recordVideo: { dir: vidDir, size: viewport },
    });
    const page = await ctx.newPage();
    const url = 'file://' + resolve(here, 'cards/quote-motion.html')
      + `?text=${encodeURIComponent(text)}&theme=${theme}&at=${encodeURIComponent(stamps[theme])}`
      + (dateArg ? `&date=${dateArg}` : '');
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForFunction(() => window.__done === true, null, { timeout: 60000 });
    const video = page.video();
    await ctx.close();
    const webm = await video.path();
    const name = `${slug}-${sizeName}-${theme}`;
    if (ffmpeg) {
      execFileSync(ffmpeg, [
        '-y', '-hide_banner', '-loglevel', 'error',
        '-i', webm,
        '-c:v', 'libx264', '-crf', '19', '-preset', 'medium',
        '-pix_fmt', 'yuv420p', '-an',
        resolve(out, `${name}.mp4`),
      ]);
      rmSync(vidDir, { recursive: true, force: true });
      console.log(`${name}.mp4`);
    } else {
      renameSync(webm, resolve(out, `${name}.webm`));
      console.log(`${name}.webm (no ffmpeg found — left as webm)`);
    }
  }
}

// Paste-ready words, matching each variant's SAVED stamp exactly.
import('node:fs').then(({ writeFileSync }) => {
  for (const theme of ['light', 'dark']) {
    writeFileSync(resolve(out, `${slug}-${theme}-caption.txt`),
      `Caption:\n${captionFor(stamps[theme])}\n\nFirst comment:\nwritten in my Endpaper journal - find the app endpaper.space\n`);
  }
});

await browser.close();
console.log('quote motion rendered to', out);
