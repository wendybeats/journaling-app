// Archive → Week: weeks as single rows of large dots, current week first,
// stacking back through the data. Filled dots tap through to that day.

import { hasEntries, daysWithEntries } from '../store.js';
import { fromKey, weekRangeLabel } from '../format.js';
import { weekOf, weekdayLetters, weekRowLarge } from '../dots.js';
import { archiveHead } from './shared.js';

function weekStrip(days) {
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

  strip.append(header, weekRowLarge(days));
  return strip;
}

export function renderWeek(root) {
  root.appendChild(archiveHead('archive/week'));

  const stack = document.createElement('div');
  stack.className = 'weeks-stack';
  stack.appendChild(weekdayLetters());

  const all = daysWithEntries();
  const oldest = all.length ? fromKey(all[all.length - 1]) : new Date();

  // Current week first, stacking back to the week of the earliest entry
  const cursor = new Date();
  cursor.setDate(cursor.getDate() - cursor.getDay()); // Sunday of this week
  while (true) {
    stack.appendChild(weekStrip(weekOf(cursor)));
    if (cursor <= oldest) break;
    cursor.setDate(cursor.getDate() - 7);
  }

  root.appendChild(stack);
  return {};
}
