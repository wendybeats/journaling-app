// Reflection engine (R1) — a deterministic stand-in for the two-stage
// pipeline in docs/vellum-reflection-spec.md. It only surfaces what the
// entries literally contain: a topic needs >=3 mentions across the week,
// every quote is a verbatim sentence from an entry, and a week below the
// threshold produces silence, not an apology.

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
  'right different actually finally really quite maybe almost enough every another other').split(' '));

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

  return { startKey: dayKey(start), days: writtenDays.length, words, sufficient, topic, quotes };
}

/** The weekly reflection waiting to be shown, or null (no consent /
 *  already seen / insufficient week — silence). */
export function pendingWeekly(now = new Date()) {
  if (consentStatus() !== 'yes') return null;
  const start = lastCompletedWeekStart(now);
  if (state.seen?.[dayKey(start)]) return null;
  const signal = weeklySignal(start);
  return signal.sufficient ? signal : null;
}

/** The consent moment appears only once a recap could actually exist. */
export function consentEligible(now = new Date()) {
  if (consentStatus() !== null) return false;
  return weeklySignal(lastCompletedWeekStart(now)).sufficient;
}

export function markSeen(signal) {
  state.seen = { ...(state.seen ?? {}), [signal.startKey]: true };
  state.archived = { ...(state.archived ?? {}), [signal.startKey]: signal };
  persist();
}

export function removeReflection(startKey) {
  delete state.archived?.[startKey];
  persist();
}

/** Archived reflections, keyed by week-start day key. */
export function archivedReflections() {
  return state.archived ?? {};
}
