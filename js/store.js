// Entry storage — plain text, day-keyed, timestamped (the v2-ready corpus shape).
// localStorage stands in for SwiftData in the prototype.

const ENTRIES_KEY = 'vellum.entries.v1';
const DRAFT_KEY = 'vellum.draft.v1';

function load() {
  try {
    return JSON.parse(localStorage.getItem(ENTRIES_KEY)) ?? {};
  } catch {
    return {};
  }
}

let entries = load();

function persist() {
  localStorage.setItem(ENTRIES_KEY, JSON.stringify(entries));
}

/** Local-timezone day key, e.g. "2026-07-05". */
export function dayKey(date = new Date()) {
  const y = date.getFullYear();
  const m = String(date.getMonth() + 1).padStart(2, '0');
  const d = String(date.getDate()).padStart(2, '0');
  return `${y}-${m}-${d}`;
}

export function entriesFor(key) {
  return entries[key] ?? [];
}

export function addEntry(text, at = Date.now()) {
  const key = dayKey(new Date(at));
  const entry = { id: crypto.randomUUID(), at, text };
  entries[key] = [...entriesFor(key), entry].sort((a, b) => a.at - b.at);
  persist();
  return entry;
}

/** All day keys that have entries, newest first. */
export function daysWithEntries() {
  return Object.keys(entries).filter((k) => entries[k].length).sort().reverse();
}

export function hasEntries(key) {
  return (entries[key]?.length ?? 0) > 0;
}

export function replaceAll(data) {
  entries = data;
  persist();
}

// --- Draft (uncommitted writing survives reloads) ---

export function saveDraft(text) {
  if (text) {
    localStorage.setItem(DRAFT_KEY, JSON.stringify({ day: dayKey(), text }));
  } else {
    localStorage.removeItem(DRAFT_KEY);
  }
}

export function loadDraft() {
  try {
    const draft = JSON.parse(localStorage.getItem(DRAFT_KEY));
    // A draft from a previous day commits to that day rather than lingering
    if (draft && draft.day !== dayKey()) {
      const [y, m, d] = draft.day.split('-').map(Number);
      addEntry(draft.text.trim(), new Date(y, m - 1, d, 23, 59).getTime());
      localStorage.removeItem(DRAFT_KEY);
      return '';
    }
    return draft?.text ?? '';
  } catch {
    return '';
  }
}
