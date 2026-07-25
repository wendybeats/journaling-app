// Runs the JS reflection engine (js/reflect.js — the reference
// implementation) over the shared corpus and writes expected.json: the
// signals the Swift engine must reproduce. Part of the launch-plan
// checklist item "Swift engine agrees with the JS engine on the seed
// corpus."
//
//   node tools/parity/run-js.mjs   → writes tools/parity/expected.json

import { readFileSync, writeFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { fileURLToPath } from 'node:url';

// The browser modules expect localStorage; a throwaway in-memory stand-in
// keeps them oblivious.
const mem = new Map();
globalThis.localStorage = {
  getItem: (k) => (mem.has(k) ? mem.get(k) : null),
  setItem: (k, v) => mem.set(k, String(v)),
  removeItem: (k) => mem.delete(k),
};

const here = dirname(fileURLToPath(import.meta.url));
const store = await import('../../js/store.js');
const reflect = await import('../../js/reflect.js');

const corpus = JSON.parse(readFileSync(join(here, 'corpus.json'), 'utf8'));
const [ay, am, ad] = corpus.anchor.split('-').map(Number);
const now = new Date(ay, am - 1, ad, 12, 0);

// corpus.json → the store's entry shape (one entry per session, in order)
const entries = {};
for (const [key, sessions] of Object.entries(corpus.byDay)) {
  const [y, m, d] = key.split('-').map(Number);
  entries[key] = sessions.map((s, i) => {
    const at = new Date(y, m - 1, d, 0, s.minuteOfDay).getTime();
    return { id: `${key}-${i}`, at, lastAt: at, text: s.text };
  });
}
store.replaceAll(entries);

function normQuote(q) {
  return { text: q.text, day: q.day };
}

// --- Weekly: the last completed week and the three before it ---
const weekly = [];
const firstStart = reflect.lastCompletedWeekStart(now);
for (let k = 0; k < 4; k++) {
  const start = new Date(firstStart);
  start.setDate(firstStart.getDate() - 7 * k);
  const s = reflect.weeklySignal(start);
  weekly.push({
    id: s.id, startKey: s.startKey, days: s.days, words: s.words, sufficient: s.sufficient,
    topic: s.topic ? { word: s.topic.word, mentions: s.topic.mentions, days: s.topic.days } : null,
    quotes: s.quotes.map(normQuote),
  });
}

// --- Monthly: every month the corpus touches ---
const monthly = [];
for (let y = 2025; y <= 2026; y++) {
  for (let m0 = 0; m0 < 12; m0++) {
    if (y === 2025 && m0 < 6) continue;       // corpus starts 2025-07
    if (y === 2026 && m0 > 6) continue;       // corpus ends 2026-07
    const s = reflect.monthlySignal(y, m0);
    monthly.push({
      id: s.id, year: y, month: m0 + 1,
      days: s.days, words: s.words, longestRun: s.longestRun, sufficient: s.sufficient,
      tone: s.tone ? { word: s.tone.word, count: s.tone.count } : null,
      topics: s.topics.map((t) => ({
        stem: t.stem, word: t.word, mentions: t.mentions, days: t.days,
        quotes: t.quotes.map(normQuote),
      })),
      difficult: s.difficult.map(normQuote),
    });
  }
}

// --- Yearly ---
const yearly = [2025, 2026].map((y) => {
  const s = reflect.yearlySignal(y, now);
  return {
    id: s.id, year: y, days: s.days, words: s.words, entries: s.entries,
    longestRun: s.longestRun, sufficient: s.sufficient,
    topics: s.topics.map((t) => ({ stem: t.stem, word: t.word, mentions: t.mentions, days: t.days })),
    // JS spreads the topic into the reveal; Swift nests it — normalize flat.
    reveal: s.reveal ? { stem: s.reveal.stem, first: normQuote(s.reveal.first) } : null,
  };
});

const out = { anchor: corpus.anchor, weekly, monthly, yearly };
writeFileSync(join(here, 'expected.json'), JSON.stringify(out, null, 1));
console.log('expected.json written:');
console.log('  weekly:', weekly.map((w) => `${w.id} days=${w.days} topic=${w.topic?.word ?? '—'}`).join(' | '));
console.log('  monthly sufficient:', monthly.filter((m) => m.sufficient).length, 'of', monthly.length);
console.log('  yearly:', yearly.map((y) => `${y.id} days=${y.days} topics=${y.topics.length} reveal=${y.reveal?.stem ?? '—'}`).join(' | '));
