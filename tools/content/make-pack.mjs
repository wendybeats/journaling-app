// Endpaper content engine — weekly pack assembler.
// Runs the app renderer and the card renderer into one dated pack
// directory and writes captions.md (channel-fit words for each asset,
// drawn from the hook library's register).
//
// Usage: node make-pack.mjs [packsRoot]
// Output: <packsRoot>/pack-<YYYY-WW>/{assets, captions.md, THIS-WEEK.md}

import { execFileSync } from 'node:child_process';
import { mkdirSync, writeFileSync, readdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));

function isoWeek(d = new Date()) {
  const date = new Date(Date.UTC(d.getFullYear(), d.getMonth(), d.getDate()));
  const day = date.getUTCDay() || 7;
  date.setUTCDate(date.getUTCDate() + 4 - day);
  const jan1 = new Date(Date.UTC(date.getUTCFullYear(), 0, 1));
  const week = Math.ceil(((date - jan1) / 86400000 + 1) / 7);
  return `${date.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
}

const week = isoWeek();
const root = resolve(process.argv[2] || resolve(here, 'out'));
const pack = resolve(root, `pack-${week}`);
mkdirSync(pack, { recursive: true });

console.log('rendering app views…');
execFileSync('node', [resolve(here, 'render-app.mjs'), pack], { stdio: 'inherit' });
console.log('rendering cards…');
execFileSync('node', [resolve(here, 'render-cards.mjs'), pack], { stdio: 'inherit' });

// Reels are the distribution surface (see hooks.md → Signals): every
// pack carries one quote video, rotating through the attribution-safe
// shortlist by week.
const quotes = JSON.parse(readFileSync(resolve(here, 'cards/quotes.json'), 'utf8'));
const weekNum = Number(week.slice(-2));
const q = quotes[weekNum % quotes.length];
console.log(`rendering quote video… ("${q.text.slice(0, 32)}…" — ${q.by})`);
execFileSync('node', [resolve(here, 'render-quote.mjs'), q.text, pack, 'quote'], { stdio: 'inherit' });

const assets = readdirSync(pack).filter(f => f.endsWith('.png') || f.endsWith('.mp4')).sort();

const captions = `# Captions — pack ${week}

## THIS WEEK'S QUOTE VIDEO (quote-*.mp4) — post as a Reel
Quote: "${q.text}" — ${q.by}
- Light variant carries a morning SAVED time; dark carries evening.
  Post to match.
- Caption (exact strings sit beside the videos in quote-*-caption.txt):
  "Thought of {Weekday}, {Mon} {D}th at {time}" — the time matches the
  variant's SAVED stamp.
- First comment, always: "I wrote this in the Endpaper app"
  (attribution — ${q.by} — can join the first comment)
- Reels are the reach surface; stills below are anchors, carousels,
  and story material.

Voice rules: quiet, direct, complete sentences, no exclamation points,
no hashtag soup (0–2 native tags max where the platform expects them).
One variable per variant set. Hooks from tools/content/hooks.md.

## Year matrix (calendar-year-*, calendar-square-*)
- "Every dot is a day I actually wrote."
- "No streaks. No fire emoji. Just the days, filling in."
- "{Month}, honest version." (month-end cadence)
- Story variant: post the square, top-left, no caption at all — the
  image is the caption.

## Notebook (notebook-*)
- "A record, not a feed."
- "It reads like a book because it's set like one."

## Today page (today-*)
- "Open. Write. Close. That's the whole app."
- "The page is waiting. The cursor is ready. That's the pitch."

## Day page (day-page-*)
- "One day, kept whole."

## Rule cards (rule-*)
Post as-is; the card carries the words. If the platform demands a
caption, repeat the card's sentence verbatim — nothing more.

## Craft rules (every clip)
- Hook lands in the first 1.5 seconds.
- Captions burned in — feeds are watched muted.
- App identity visible at second 0 and at the close.
`;

const note = `# This week — pack ${week}

${assets.length} assets in this pack (app views light+dark, rule cards
feed+story light+dark).

The cycle (docs/endpaper-content-engine.md):
1. Pick 3–5 assets, pair with hooks from hooks.md, post.
2. Mark posted hooks \`live\` in hooks.md.
3. Friday: kill what didn't move (\`dead\`), tag what did (\`winner\`),
   spawn same-family variants for next week's pack.

Wendell-side this week: one 20-minute real-device capture session of the
current build feeds next week's clips (choreography, REC, living type).
`;

writeFileSync(resolve(pack, 'captions.md'), captions);
writeFileSync(resolve(pack, 'THIS-WEEK.md'), note);
console.log(`pack ready: ${pack} (${assets.length} assets + captions + note)`);
