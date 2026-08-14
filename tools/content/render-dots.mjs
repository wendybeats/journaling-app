// Endpaper content engine — dot-matrix motion pieces (the moat format).
// Records a cards/dots-*.html animation as H.264 video, light and dark,
// story size (1080×1920 — the Reel surface).
//
// Usage: node render-dots.mjs [card] [outDir] [slug] [durSeconds]
//   card: file in cards/ (default dots-mind.html)
//   durSeconds: passed to the card as ?dur= (voiceover cuts run longer)

import { chromium } from 'playwright';
import { mkdirSync, renameSync, rmSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const card = process.argv[2] || 'dots-mind.html';
const out = resolve(process.argv[3] || resolve(here, 'out'));
const slug = process.argv[4] || card.replace(/\.html$/, '');
const dur = process.argv[5] || '';
mkdirSync(out, { recursive: true });

let ffmpeg = null;
for (const p of [
  resolve(here, 'node_modules/@ffmpeg-installer/linux-x64/ffmpeg'),
  '/tmp/claude-0/-home-user-journaling-app/d88db19a-3a29-5cbd-8e42-f4e7f24e6265/scratchpad/node_modules/@ffmpeg-installer/linux-x64/ffmpeg',
]) {
  try { execFileSync(p, ['-version'], { stdio: 'ignore' }); ffmpeg = p; break; } catch {}
}

const viewport = { width: 1080, height: 1920 };
const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

for (const theme of ['light', 'dark']) {
  const vidDir = resolve(tmpdir(), `dots-vid-${theme}`);
  rmSync(vidDir, { recursive: true, force: true });
  const ctx = await browser.newContext({ viewport, recordVideo: { dir: vidDir, size: viewport } });
  const page = await ctx.newPage();
  await page.goto('file://' + resolve(here, 'cards', card) + `?theme=${theme}` + (dur ? `&dur=${dur}` : ''));
  await page.evaluate(() => document.fonts.ready);
  await page.waitForFunction(() => window.__done === true, null, { timeout: 60000 });
  const video = page.video();
  await ctx.close();
  const webm = await video.path();
  const name = `${slug}-story-${theme}`;
  if (ffmpeg) {
    execFileSync(ffmpeg, [
      '-y', '-hide_banner', '-loglevel', 'error',
      '-ss', '0.3',
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

await browser.close();
console.log('dot motion rendered to', out);
