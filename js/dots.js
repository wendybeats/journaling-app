// The dot is the product's atom. Month grid + year matrix renderers.

import { dayKey, hasEntries } from './store.js';
import { monthName, monthAbbr } from './format.js';

function dot(key, isToday) {
  const el = document.createElement('span');
  el.className = 'dot';
  if (hasEntries(key)) el.classList.add('filled');
  if (isToday) el.classList.add('today');
  return el;
}

/** Month grid card: 7 columns, week-aligned, whole month shown (future = empty). */
export function monthCard(now = new Date()) {
  const y = now.getFullYear();
  const m = now.getMonth();
  const todayKey = dayKey(now);
  const daysInMonth = new Date(y, m + 1, 0).getDate();

  const card = document.createElement('section');
  card.className = 'grid-card';

  const header = document.createElement('header');
  const label = document.createElement('span');
  label.className = 'type-meta';
  label.textContent = monthName(m);
  const count = document.createElement('span');
  count.className = 'type-meta-small';
  let written = 0;
  for (let d = 1; d <= daysInMonth; d++) {
    if (hasEntries(dayKey(new Date(y, m, d)))) written++;
  }
  count.textContent = `${written} ${written === 1 ? 'day' : 'days'} written`;
  header.append(label, count);

  const grid = document.createElement('div');
  grid.className = 'dot-grid';
  const lead = new Date(y, m, 1).getDay(); // Sunday-start
  for (let i = 0; i < lead; i++) {
    grid.appendChild(document.createElement('span'));
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const key = dayKey(new Date(y, m, d));
    const cell = document.createElement('span');
    cell.className = 'dot-cell';
    cell.appendChild(dot(key, key === todayKey));
    grid.appendChild(cell);
  }

  card.append(header, grid);
  return card;
}

/** Year matrix: one row per month, one dot per day. Dense; density is the payoff. */
export function yearMatrix(year, now = new Date()) {
  const todayKey = dayKey(now);
  const block = document.createElement('section');
  block.className = 'year-block';

  const label = document.createElement('div');
  label.className = 'type-meta year-label';
  label.textContent = String(year);
  block.appendChild(label);

  for (let m = 0; m < 12; m++) {
    const row = document.createElement('div');
    row.className = 'year-row';
    const mLabel = document.createElement('span');
    mLabel.className = 'type-meta-small';
    mLabel.textContent = monthAbbr(m).slice(0, 1);
    row.appendChild(mLabel);
    const daysInMonth = new Date(year, m + 1, 0).getDate();
    for (let d = 1; d <= 31; d++) {
      if (d > daysInMonth) {
        row.appendChild(document.createElement('span'));
        continue;
      }
      const key = dayKey(new Date(year, m, d));
      row.appendChild(dot(key, key === todayKey));
    }
    block.appendChild(row);
  }
  return block;
}
