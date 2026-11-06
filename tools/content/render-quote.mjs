// Endpaper content engine — quote motion cards.
// Types a line onto the page with the app's living-type shrink, holds,
// then the SAVED ack — recorded as video. Story (1080×1920) and feed
// (1080×1350) sizes, light and dark, H.264 for the platforms.
//
// Usage: node render-quote.mjs "The quote." [outDir] [slug] [YYYY-MM-DD] [music] [author]
// author: full name; a known author prefixes the caption with
// "From {last name} - ". Omit for unattributed lines.
// The optional date renders the page (and caption) for a future posting
// day — the 07:05 franchise schedules the night before.
// music: a file in tools/content/music/ (or any path), 'auto' to pick
// one at random from that folder, or 'none'. Defaults to auto. Tracks
// are muxed under the video with a fade-in and a fade-out at the end;
// only use tracks Wendell holds rights to (music/ stays untracked —
// pull it from the GitHub release).
// Requires ffmpeg (auto-resolved from @ffmpeg-installer if present).

import { chromium } from 'playwright';
import { mkdirSync, renameSync, rmSync, readdirSync, existsSync } from 'node:fs';
import { execFileSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';
import { tmpdir } from 'node:os';

const here = dirname(fileURLToPath(import.meta.url));
const text = process.argv[2] || 'Those who commit to nothing are distracted by everything.';
const out = resolve(process.argv[3] || resolve(here, 'out'));
const slug = process.argv[4] || 'quote';
const dateArg = process.argv[5] || '';           // YYYY-MM-DD, optional
const musicArg = process.argv[6] || 'auto';
const author = process.argv[7] || '';
mkdirSync(out, { recursive: true });

// Music bed: one track per render (all four variants share it, so the
// light/dark pair feel like the same post).
const musicDir = resolve(here, 'music');
let music = null;
if (musicArg !== 'none') {
  if (musicArg !== 'auto' && existsSync(resolve(musicDir, musicArg))) music = resolve(musicDir, musicArg);
  else if (musicArg !== 'auto' && existsSync(musicArg)) music = resolve(musicArg);
  else if (existsSync(musicDir)) {
    const tracks = readdirSync(musicDir).filter(f => /\.(mp3|m4a|aac|wav|flac|ogg)$/i.test(f)).sort();
    if (tracks.length) music = resolve(musicDir, tracks[Math.floor(Math.random() * tracks.length)]);
  }
  if (musicArg !== 'auto' && !music) {
    console.error(`music not found: ${musicArg} (looked in ${musicDir} and as a path)`);
    process.exit(1);
  }
}
console.log(music ? `music: ${music.split('/').pop()}` : 'music: none');

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
  const from = author ? `From ${author.trim().split(/\s+/).pop()} - ` : '';
  return `${from}Thought of ${day}, ${mon} ${d}${ord} at ${t}`;
}


/// Time of the first frame on which the first letter is painted: the
/// first luma change in the centre band (where only the typed word lives)
/// once the band sits on the page background. Null if nothing is found.
function firstLetterTime(webm, theme) {
  if (!ffmpeg) return null;
  let log = '';
  try {
    execFileSync(ffmpeg, [
      '-hide_banner', '-loglevel', 'info', '-t', '4', '-i', webm,
      '-vf', 'crop=iw:ih*0.2:0:ih*0.4,signalstats,metadata=print:file=-',
      '-f', 'null', '-',
    ], { stdio: ['ignore', 'pipe', 'pipe'], maxBuffer: 64 * 1024 * 1024 });
  } catch (e) { log = String(e.stdout || '') + String(e.stderr || ''); }
  const frames = [];
  let t = null;
  for (const line of log.split('\n')) {
    const mt = line.match(/pts_time:([\d.]+)/);
    if (mt) t = parseFloat(mt[1]);
    const my = line.match(/lavfi\.signalstats\.YAVG=([\d.]+)/);
    if (my && t !== null) frames.push({ t, y: parseFloat(my[1]) });
  }
  if (frames.length < 3) return null;
  const bg = theme === 'dark' ? 21 : 230;      // char / bone, as luma
  for (let i = 1; i < frames.length; i++) {
    const prev = frames[i - 1], cur = frames[i];
    if (Math.abs(prev.y - bg) <= 8 && Math.abs(cur.y - prev.y) > 0.3) return cur.t;
  }
  return null;
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
    const recordingStartedAt = Date.now();   // recordVideo begins with the page
    const url = 'file://' + resolve(here, 'cards/quote-motion.html')
      + `?text=${encodeURIComponent(text)}&theme=${theme}&at=${encodeURIComponent(stamps[theme])}`
      + (dateArg ? `&date=${dateArg}` : '');
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    await page.waitForFunction(() => window.__done === true, null, { timeout: 60000 });
    const firstLetterAt = await page.evaluate(() => window.__firstLetterAt || 0);
    const stampTrim = firstLetterAt ? Math.max(0, (firstLetterAt - recordingStartedAt) / 1000) : 0.4;
    const video = page.video();
    await ctx.close();
    const webm = await video.path();
    const name = `${slug}-${sizeName}-${theme}`;
    if (ffmpeg) {
      const mp4 = resolve(out, `${name}.mp4`);
      // Trim to the first painted letter, FOUND IN THE VIDEO ITSELF: the
      // wall-clock stamp drifts against the recording's timeline (2026-11-06:
      // a three-letter first frame), so scan the centre band's luma for the
      // first change after the page background is up. Stamp is the fallback.
      const trim = firstLetterTime(webm, theme) ?? stampTrim;
      execFileSync(ffmpeg, [
        '-y', '-hide_banner', '-loglevel', 'error',
        // Trim the page-load frames so frame one already shows the huge
        // first letter.
        '-ss', trim.toFixed(3),
        '-i', webm,
        '-c:v', 'libx264', '-crf', '19', '-preset', 'medium',
        '-pix_fmt', 'yuv420p', '-an',
        mp4,
      ]);
      if (music) {
        // Second pass: lay the track under the finished cut. The webm has
        // no duration header, so probe the encoded mp4 for the fade-out.
        let dur = 0;
        try { execFileSync(ffmpeg, ['-i', mp4], { stdio: 'pipe' }); }
        catch (e) {
          const m = String(e.stderr).match(/Duration: (\d+):(\d+):([\d.]+)/);
          if (m) dur = (+m[1]) * 3600 + (+m[2]) * 60 + (+m[3]);
        }
        const muxed = resolve(out, `${name}.muxed.mp4`);
        const fade = dur > 4
          ? `afade=t=in:st=0:d=1.2,afade=t=out:st=${(dur - 2.2).toFixed(2)}:d=2.2`
          : 'afade=t=in:st=0:d=0.5';
        execFileSync(ffmpeg, [
          '-y', '-hide_banner', '-loglevel', 'error',
          '-i', mp4, '-i', music,
          '-map', '0:v', '-map', '1:a',
          '-c:v', 'copy', '-c:a', 'aac', '-b:a', '192k',
          ...(dur ? ['-t', String(dur)] : ['-shortest']),
          '-af', fade,
          muxed,
        ]);
        renameSync(muxed, mp4);
      }
      rmSync(vidDir, { recursive: true, force: true });
      console.log(`${name}.mp4${music ? ' (+music)' : ''}`);
    } else {
      renameSync(webm, resolve(out, `${name}.webm`));
      console.log(`${name}.webm (no ffmpeg found — left as webm)`);
    }
  }
}

// Paste-ready words, matching each variant's SAVED stamp exactly.
// Bare text only — line 1 is the caption, line 3 the first comment.
import('node:fs').then(({ writeFileSync }) => {
  for (const theme of ['light', 'dark']) {
    writeFileSync(resolve(out, `${slug}-${theme}-caption.txt`),
      `${captionFor(stamps[theme])}\n\nI wrote this in the Endpaper app\n`);
  }
});

await browser.close();
console.log('quote motion rendered to', out);
