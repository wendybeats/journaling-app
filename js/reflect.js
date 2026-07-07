// Reflection engine (R1+R2) — a deterministic stand-in for the two-stage
// pipeline in docs/vellum-reflection-spec.md. It only surfaces what the
// entries literally contain: topics need repeated mentions, every quote is
// a verbatim sentence, tone words must be the user's own, difficulty needs
// explicit textual evidence, and thin periods get silence (weekly) or the
// honest quiet variant (monthly) — never a reach.

import { dayKey, entriesFor, hasEntries } from './store.js';

const STATE_KEY = 'vellum.reflection.v1';

function load() {
  try {
    return JSON.parse(localStorage.getItem(STATE_KEY)) ?? {};
  } catch {
    return {};
  }
}

let state = load();

function persist() {
  localStorage.setItem(STATE_KEY, JSON.stringify(state));
}

export function consentStatus() {
  return state.consent ?? null;
}

export function setConsent(value) {
  state.consent = value;
  persist();
}

export function resetReflections() {
  state = {};
  persist();
}

/** Sunday that starts the last fully completed week. */
export function lastCompletedWeekStart(now = new Date()) {
  const d = new Date(now);
  d.setHours(0, 0, 0, 0);
  d.setDate(d.getDate() - d.getDay() - 7);
  return d;
}

function weekDayKeys(start) {
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    return dayKey(d);
  });
}

// Words that can never be a "topic" — function words plus journal furniture
const STOPWORDS = new Set(('the a an and or but if then than that this these those i me my mine we our you your it its ' +
  'is are was were be been being am do does did doing have has had having not no yes of in on at by for with about into ' +
  'over under again more most other some such only own same so too very just there here when where why how what which who ' +
  'whom will would can could should may might must shall out up down off before after above below between through during ' +
  'each few both all any nor as from to because while until once now today yesterday tomorrow day days week thing things ' +
  'time way one two three still even also around never always keep kept feel felt like really them they he she his her ' +
  'him hers itself myself something anything nothing everything went going gone got get ' +
  // generic descriptors — true but never a thread worth mirroring
  'long short good great bad better best hard easy small little big first last much many made make come came back ' +
  'right different actually finally really quite maybe almost enough every another other instead though although ' +
  'however anyway anymore toward towards besides without within').split(' '));

function tokenize(text) {
  return (text.toLowerCase().match(/[a-z']+/g) ?? [])
    .map((w) => w.replace(/'.*$/, ''))
    .filter((w) => w.length >= 4 && !STOPWORDS.has(w));
}

/** Light stem so "mornings" and "morning" count as one thread. */
function stem(word) {
  return word.endsWith('s') && !word.endsWith('ss') ? word.slice(0, -1) : word;
}

function sentences(text) {
  return text.split(/(?<=[.?!])\s+|\n+/).map((s) => s.trim()).filter(Boolean);
}

/**
 * Stage 1 over one week. Returns the signal object the recap is composed
 * from; `sufficient: false` means the week stays silent.
 */
export function weeklySignal(start) {
  const keys = weekDayKeys(start);
  const writtenDays = keys.filter(hasEntries);
  const all = writtenDays.flatMap((k) => entriesFor(k).map((e) => ({ ...e, day: k })));
  const words = all.reduce((n, e) => n + e.text.split(/\s+/).filter(Boolean).length, 0);
  const sufficient = writtenDays.length >= 3 && words >= 300;

  // Candidate topics: a stem needs >=3 mentions, spread over >=2 days;
  // >=3 distinct days wins outright
  const counts = new Map(); // stem -> { count, days:Set, display }
  for (const entry of all) {
    for (const raw of tokenize(entry.text)) {
      const s = stem(raw);
      const c = counts.get(s) ?? { count: 0, days: new Set(), display: raw };
      c.count++;
      c.days.add(entry.day);
      counts.set(s, c);
    }
  }
  const candidates = [...counts.entries()]
    .filter(([, c]) => c.days.size >= 3 || (c.count >= 3 && c.days.size >= 2))
    .sort((a, b) => b[1].days.size - a[1].days.size || b[1].count - a[1].count);

  let topic = null;
  let quotes = [];
  if (candidates.length) {
    const [s, c] = candidates[0];
    topic = c.display;
    // One verbatim sentence per day the topic appears, oldest first, max 3.
    // Never quote the same sentence twice — repetition across days is the
    // observation, not the evidence.
    const seenDays = new Set();
    const seenText = new Set();
    for (const entry of all) {
      if (seenDays.has(entry.day) || seenDays.size >= 3) continue;
      const hit = sentences(entry.text).find(
        (line) => tokenize(line).map(stem).includes(s) && !seenText.has(line),
      );
      if (hit) {
        quotes.push({ text: hit, day: entry.day });
        seenDays.add(entry.day);
        seenText.add(hit);
      }
    }
    topic = { word: topic, mentions: c.count, days: c.days.size };
  }

  const startKey = dayKey(start);
  return { kind: 'weekly', id: `w-${startKey}`, startKey, days: writtenDays.length, words, sufficient, topic, quotes };
}

// Tone vocabulary — the tone section may only use the user's own recurring
// words, drawn from this feeling-adjacent list
const TONE_WORDS = ('tired calm quiet quietly slow slowly heavy light lighter easy easier hard harder soft softer ' +
  'angry sad happy grateful anxious restless hopeful proud lonely warm cold dark bright gentle rough steady ' +
  'frustrated content peaceful uneasy raw tender flat full empty').split(' ');

// Difficulty markers — explicit textual evidence only, never sentiment inference
const DIFFICULT_RE = /fighting|struggl|difficult|too hard|bad sleep|short fuse|hurt|exhaust|worried|worry|afraid|fear|couldn't|can't stop|falling behind/i;

/** Stage 1 over one calendar month. Always returns a signal — an
 *  insufficient month arrives as the quiet variant, not silence. */
export function monthlySignal(year, month) {
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const keys = Array.from({ length: daysInMonth }, (_, i) => dayKey(new Date(year, month, i + 1)));
  const writtenDays = keys.filter(hasEntries);
  const all = writtenDays.flatMap((k) => entriesFor(k).map((e) => ({ ...e, day: k })));
  const words = all.reduce((n, e) => n + e.text.split(/\s+/).filter(Boolean).length, 0);
  const sufficient = writtenDays.length >= 8;

  // Longest run of consecutive written days
  let longestRun = 0;
  let run = 0;
  for (const k of keys) {
    run = hasEntries(k) ? run + 1 : 0;
    longestRun = Math.max(longestRun, run);
  }

  // Tone: the user's own recurring feeling-word (>=3 occurrences)
  let tone = null;
  const corpus = all.map((e) => e.text.toLowerCase()).join(' ');
  for (const w of TONE_WORDS) {
    const count = (corpus.match(new RegExp(`\\b${w}\\b`, 'g')) ?? []).length;
    if (count >= 3 && (!tone || count > tone.count)) tone = { word: w, count };
  }

  // Recurring topics: monthly bar is higher — >=4 mentions across >=3 days.
  // The tone word belongs to the tone section, not the topic list.
  const counts = new Map();
  for (const entry of all) {
    for (const raw of tokenize(entry.text)) {
      const st = stem(raw);
      const c = counts.get(st) ?? { count: 0, days: new Set(), display: raw };
      c.count++;
      c.days.add(entry.day);
      counts.set(st, c);
    }
  }
  const ranked = [...counts.entries()]
    .filter(([st, c]) => c.count >= 4 && c.days.size >= 3 && st !== (tone && stem(tone.word)))
    .sort((a, b) => b[1].days.size - a[1].days.size || b[1].count - a[1].count)
    .slice(0, 8)
    .map(([st, c]) => ({ stem: st, word: c.display, mentions: c.count, days: c.days.size }));

  // Two verbatim example quotes per topic — distinct sentences (never
  // reused across topics), distinct days where possible
  const usedText = new Set();
  for (const topic of ranked) {
    topic.quotes = [];
    const usedDays = new Set();
    for (const entry of all) {
      if (topic.quotes.length >= 2) break;
      if (usedDays.has(entry.day)) continue;
      const hit = sentences(entry.text).find(
        (line) => tokenize(line).map(stem).includes(topic.stem) && !usedText.has(line),
      );
      if (hit) {
        topic.quotes.push({ text: hit, day: entry.day });
        usedDays.add(entry.day);
        usedText.add(hit);
      }
    }
    // Second pass: a same-day second sentence beats showing only one
    if (topic.quotes.length < 2) {
      for (const entry of all) {
        if (topic.quotes.length >= 2) break;
        for (const line of sentences(entry.text)) {
          if (topic.quotes.length >= 2) break;
          if (tokenize(line).map(stem).includes(topic.stem) && !usedText.has(line)) {
            topic.quotes.push({ text: line, day: entry.day });
            usedText.add(line);
          }
        }
      }
    }
  }

  // Topics that can show two examples come first
  const topics = ranked
    .sort((a, b) => (b.quotes.length >= 2) - (a.quotes.length >= 2)
      || b.days - a.days || b.mentions - a.mentions)
    .slice(0, 3);

  // Difficulty: explicit markers, quoted; up to two distinct sentences
  const difficult = [];
  const seenText = new Set();
  for (const entry of all) {
    if (difficult.length >= 2) break;
    const hit = sentences(entry.text).find((line) => DIFFICULT_RE.test(line) && !seenText.has(line));
    if (hit) {
      difficult.push({ text: hit, day: entry.day });
      seenText.add(hit);
    }
  }

  return {
    kind: 'monthly', id: `m-${year}-${String(month + 1).padStart(2, '0')}`,
    year, month, days: writtenDays.length, words, longestRun, sufficient,
    topics, tone, difficult,
  };
}

/** The previous month's recap, or null (no consent / already seen). */
export function pendingMonthly(now = new Date()) {
  if (consentStatus() !== 'yes') return null;
  const prev = new Date(now.getFullYear(), now.getMonth() - 1, 1);
  const signal = monthlySignal(prev.getFullYear(), prev.getMonth());
  if (state.seen?.[signal.id]) return null;
  if (signal.days === 0) return null; // a month with no writing at all stays silent
  return signal;
}

/** The weekly reflection waiting to be shown, or null (no consent /
 *  already seen / insufficient week — silence). */
export function pendingWeekly(now = new Date()) {
  if (consentStatus() !== 'yes') return null;
  const start = lastCompletedWeekStart(now);
  const signal = weeklySignal(start);
  if (state.seen?.[signal.id]) return null;
  return signal.sufficient ? signal : null;
}

/** The consent moment appears only once a recap could actually exist. */
export function consentEligible(now = new Date()) {
  if (consentStatus() !== null) return false;
  return weeklySignal(lastCompletedWeekStart(now)).sufficient;
}

export function markSeen(signal) {
  state.seen = { ...(state.seen ?? {}), [signal.id]: true };
  state.archived = { ...(state.archived ?? {}), [signal.id]: signal };
  persist();
}

export function removeReflection(id) {
  delete state.archived?.[id];
  persist();
}

/** Archived reflections, keyed by signal id. */
export function archivedReflections() {
  return state.archived ?? {};
}
