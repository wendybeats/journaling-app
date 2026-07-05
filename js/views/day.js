// A single day's page — where tapping any dot in the archive lands.

import { entriesFor } from '../store.js';
import { fromKey, dayHeading, dayMetaRow, timeOfDay } from '../format.js';
import { crumb } from './shared.js';

export function renderDay(root, key) {
  root.appendChild(crumb('Archive', () => history.back()));

  const date = fromKey(key);
  const dayEntries = entriesFor(key);

  const heading = document.createElement('h1');
  heading.className = 'type-display';
  heading.textContent = dayHeading(date);

  const meta = document.createElement('div');
  meta.className = 'type-meta day-meta';
  meta.textContent = dayMetaRow(date, dayEntries, { withMin: false });

  const rule = document.createElement('hr');
  rule.className = 'day-rule';

  root.append(heading, meta, rule);

  const container = document.createElement('div');
  container.className = 'archive';
  const day = document.createElement('section');
  day.className = 'day';

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

  if (!dayEntries.length) {
    const note = document.createElement('p');
    note.className = 'type-written empty-note';
    note.textContent = 'Nothing written this day.';
    day.appendChild(note);
  }

  container.appendChild(day);
  root.appendChild(container);
  return {};
}
