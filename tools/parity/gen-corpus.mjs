// Generates the shared parity corpus — a deterministic year of demo
// writing, structurally identical to the iOS DebugSeed generator (same
// SplitMix64, same pools, same schedule) but anchored to a FIXED date so
// the fixture never drifts. Both engines read the resulting corpus.json;
// neither regenerates it.
//
//   node tools/parity/gen-corpus.mjs   → writes tools/parity/corpus.json

import { writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

const ANCHOR = { y: 2026, m: 7, d: 24 };   // "today" for the fixture, forever

const MASK = (1n << 64n) - 1n;
class RNG {
  constructor(seed) { this.s = BigInt(seed) & MASK; }
  next() {
    this.s = (this.s + 0x9E3779B97F4A7C15n) & MASK;
    let z = this.s;
    z = ((z ^ (z >> 30n)) * 0xBF58476D1CE4E5B9n) & MASK;
    z = ((z ^ (z >> 27n)) * 0x94D049BB133111EBn) & MASK;
    return z ^ (z >> 31n);
  }
  int(lo, hi) { return lo + Number(this.next() % BigInt(hi - lo + 1)); }
  chance(p) { return Number(this.next() % 10000n) / 10000 < p; }
}

const pools = [
  [ // work
    'Long day at the studio and the project is still fighting me.',
    "Shipped the draft I'd been circling for a week. Lighter already.",
    'Meetings ate the morning. The afternoon was mine and I wasted it.',
    'The project turned a corner today. Small corner, but a corner.',
    'Said no to a thing I would have said yes to a year ago.',
  ],
  [ // running / body
    'Ran the long loop before breakfast. Legs heavy, head clear.',
    'Skipped the run. Regretted it by ten.',
    "The run was terrible and I'm glad I went.",
    'New shoes, same hill. The hill is undefeated.',
    'Slept badly and felt it all day. Short fuse.',
  ],
  [ // the boat
    'Spent an hour on the boat after dinner. The hull needs more work than I thought.',
    'Ordered the paint for the boat. Committing to the color felt bigger than it is.',
    "The boat again. I keep going back to it like a question I haven't answered.",
    'Sanded the hull until my arms gave out. Good tired.',
  ],
  [ // family / people
    'Called Mom. She told the story about the lake house again and I let her.',
    "Dinner with June. We talked about moving and didn't decide anything.",
    'The kids were loud and the house felt full in the good way.',
    'Old friend in town. Three hours felt like twenty minutes.',
  ],
  [ // noticing
    'The light on the kitchen wall at six was worth writing down. So here it is.',
    'Rain all day. The kind that makes the house feel like a boat.',
    'First cold morning. Summer left without saying anything.',
    'Nothing happened today, which is its own kind of thing to notice.',
    "Read on the porch until the light went. Didn't check my phone once.",
  ],
  [ // inner weather
    'Tired, but the honest kind of tired that comes from doing the thing.',
    'Anxious about the fall. Wrote it down to make it smaller.',
    'Caught myself hurrying for no reason. Slowed down on purpose.',
    'Grateful, mostly. Trying not to inspect it too hard.',
  ],
];
const closers = ['More tomorrow.', "That's all for now.", 'Worth remembering.', "We'll see.", 'Enough for today.'];

function sessionText(rng) {
  const paragraphCount = rng.chance(0.55) ? 1 : rng.int(2, 3);
  const paragraphs = [];
  for (let p = 0; p < paragraphCount; p++) {
    const sentenceCount = rng.int(1, 4);
    let pool = [...pools[rng.int(0, pools.length - 1)]];
    const lines = [];
    for (let s = 0; s < sentenceCount; s++) {
      if (!pool.length) pool = [...pools[rng.int(0, pools.length - 1)]];
      const i = rng.int(0, pool.length - 1);
      lines.push(pool.splice(i, 1)[0]);
    }
    paragraphs.push(lines.join(' '));
  }
  if (rng.chance(0.25)) paragraphs[paragraphs.length - 1] += ' ' + closers[rng.int(0, closers.length - 1)];
  return paragraphs.join('\n\n');
}

function key(date) {
  return `${date.getFullYear()}-${String(date.getMonth() + 1).padStart(2, '0')}-${String(date.getDate()).padStart(2, '0')}`;
}

const rng = new RNG(0x5EED0F0E11);
const anchor = new Date(ANCHOR.y, ANCHOR.m - 1, ANCHOR.d);
const byDay = {};
let dryStretch = 0;

for (let back = 365; back >= 0; back--) {
  const day = new Date(anchor);
  day.setDate(anchor.getDate() - back);

  if (dryStretch > 0) { dryStretch--; continue; }
  if (rng.chance(0.03)) { dryStretch = rng.int(2, 6); continue; }
  if (rng.chance(0.12)) continue;
  if (back === 0) continue;   // the fixture's "today" stays blank, like the app's

  const sessions = rng.int(4, 7);
  let minuteOfDay = rng.int(6 * 60, 8 * 60);
  const texts = [];
  for (let s = 0; s < sessions; s++) {
    if (minuteOfDay >= 23 * 60) break;
    texts.push({ minuteOfDay, text: sessionText(rng) });
    minuteOfDay += rng.int(45, 210);
  }
  if (texts.length) byDay[key(day)] = texts;
}

const out = { anchor: key(anchor), byDay };
const here = dirname(fileURLToPath(import.meta.url));
writeFileSync(join(here, 'corpus.json'), JSON.stringify(out, null, 1));
const days = Object.keys(byDay).length;
const sessions = Object.values(byDay).reduce((n, t) => n + t.length, 0);
console.log(`corpus.json: ${days} written days, ${sessions} sessions`);
