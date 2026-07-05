// Archive → Week: the current week as a single row of large dots.
// Filled dots tap through to that day's writing.

import { hasEntries } from '../store.js';
import { fromKey, weekRangeLabel } from '../format.js';
import { weekOf, weekdayLetters, weekRowLarge } from '../dots.js';
import { archiveHead } from './shared.js';

export function renderWeek(root) {
  root.appendChild(archiveHead('archive/week'));

  const days = weekOf();
  const strip = document.createElement('section');
  strip.className = 'week-strip';

  const header = document.createElement('header');
  const range = document.createElement('span');
  range.className = 'type-meta';
  range.textContent = weekRangeLabel(fromKey(days[0]), fromKey(days[6]));
  const count = document.createElement('span');
  count.className = 'type-meta-small';
  const written = days.filter(hasEntries).length;
  count.textContent = `${written} ${written === 1 ? 'day' : 'days'} written`;
  header.append(range, count);

  strip.append(header, weekdayLetters(), weekRowLarge(days));
  root.appendChild(strip);
  return {};
}
