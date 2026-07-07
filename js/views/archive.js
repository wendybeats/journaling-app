// Archive → Log: reverse-chronological reading view of day pages.

import { daysWithEntries, entriesFor } from '../store.js';
import { fromKey, dayHeading, dayMetaRow, timeOfDay } from '../format.js';
import { archiveHead } from './shared.js';
import { archivedReflections } from '../reflect.js';
import { inlineReflection } from './reflection.js';

export function renderArchive(root) {
  root.appendChild(archiveHead('archive'));

  const days = daysWithEntries();
  if (!days.length) {
    const note = document.createElement('p');
    note.className = 'type-written empty-note';
    note.textContent = 'Nothing here yet. The archive builds itself, one day at a time.';
    root.appendChild(note);
    return {};
  }

  const container = document.createElement('div');
  container.className = 'archive';

  // Archived reflections rest at their period boundary: above the last day
  // of the period they mirror (list is newest-first)
  const reflections = Object.values(archivedReflections())
    .map((signal) => {
      const end = signal.kind === 'weekly'
        ? (() => { const e = fromKey(signal.startKey); e.setDate(e.getDate() + 6); return e; })()
        : new Date(signal.year, signal.month + 1, 0);
      const y = end.getFullYear();
      const m = String(end.getMonth() + 1).padStart(2, '0');
      const d = String(end.getDate()).padStart(2, '0');
      return { signal, endKey: `${y}-${m}-${d}` };
    })
    .sort((a, b) => (a.endKey < b.endKey ? 1 : -1));
  let refIdx = 0;

  for (const key of days) {
    while (refIdx < reflections.length && reflections[refIdx].endKey >= key) {
      container.appendChild(inlineReflection(reflections[refIdx].signal));
      refIdx++;
    }
    const date = fromKey(key);
    const dayEntries = entriesFor(key);

    const day = document.createElement('section');
    day.className = 'day';

    const heading = document.createElement('h2');
    heading.className = 'type-title';
    heading.textContent = dayHeading(date);

    const meta = document.createElement('div');
    meta.className = 'type-meta day-meta';
    meta.textContent = dayMetaRow(date, dayEntries, { withMin: false });

    const rule = document.createElement('hr');
    rule.className = 'day-rule';

    day.append(heading, meta, rule);

    dayEntries.forEach((entry, i) => {
      const el = document.createElement('article');
      el.className = 'entry type-written';
      if (i === 0) el.classList.add('dropcap');
      const time = document.createElement('time');
      time.className = 'type-meta-small';
      time.textContent = timeOfDay(entry.at);
      el.appendChild(time);
      for (const para of entry.text.split(/\n{2,}/)) {
        const p = document.createElement('p');
        p.textContent = para;
        el.appendChild(p);
      }
      day.appendChild(el);
    });

    container.appendChild(day);
  }

  root.appendChild(container);
  return {};
}
