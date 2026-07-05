// The dot is the product's atom. Every renderer here stamps dots with
// `data-flip` date keys so layouts can morph into each other (see flip.js).

import { dayKey, hasEntries } from './store.js';
import { monthName, monthAbbr } from './format.js';

const WEEKDAY_LETTERS = ['S', 'M', 'T', 'W', 'T', 'F', 'S'];

export function dot(key, { today = false, navigable = false } = {}) {
  const el = document.createElement('span');
  el.className = 'dot';
  el.dataset.flip = key;
  const filled = hasEntries(key);
  if (filled) el.classList.add('filled');
  if (today) el.classList.add('today');
  if (navigable && filled) {
    el.classList.add('tappable');
    el.addEventListener('click', (e) => {
      e.stopPropagation();
      location.hash = `#archive/day/${key}`;
    });
  }
  return el;
}

export function daysWrittenIn(year, month) {
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  let written = 0;
  for (let d = 1; d <= daysInMonth; d++) {
    if (hasEntries(dayKey(new Date(year, month, d)))) written++;
  }
  return written;
}

export function monthLabel(year, month) {
  return year === new Date().getFullYear() ? monthName(month) : `${monthName(month)} ${year}`;
}

/** 7-column week-aligned dot grid for a month (the compact register). */
export function monthGridBody(year, month) {
  const todayKey = dayKey();
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const grid = document.createElement('div');
  grid.className = 'dot-grid';
  const lead = new Date(year, month, 1).getDay(); // Sunday-start
  for (let i = 0; i < lead; i++) {
    grid.appendChild(document.createElement('span'));
  }
  for (let d = 1; d <= daysInMonth; d++) {
    const key = dayKey(new Date(year, month, d));
    const cell = document.createElement('span');
    cell.className = 'dot-cell';
    cell.appendChild(dot(key, { today: key === todayKey }));
    grid.appendChild(cell);
  }
  return grid;
}

/** Weekday letter header for large week rows. */
export function weekdayLetters() {
  const row = document.createElement('div');
  row.className = 'weekday-letters type-meta-small';
  for (const l of WEEKDAY_LETTERS) {
    const s = document.createElement('span');
    s.textContent = l;
    row.appendChild(s);
  }
  return row;
}

/** One week as a row of large, tappable dots. `days` holds 7 date keys
 *  (null = day outside the month, rendered blank). */
export function weekRowLarge(days) {
  const todayKey = dayKey();
  const row = document.createElement('div');
  row.className = 'week-row-large';
  for (const key of days) {
    const cell = document.createElement('span');
    cell.className = 'dot-cell';
    if (key) cell.appendChild(dot(key, { today: key === todayKey, navigable: true }));
    row.appendChild(cell);
  }
  return row;
}

/** The weekly breakdown of a month: letters + one large row per week. */
export function weeksOfMonthBody(year, month) {
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const body = document.createElement('div');
  body.className = 'weeks-body';
  body.appendChild(weekdayLetters());
  let week = new Array(new Date(year, month, 1).getDay()).fill(null);
  for (let d = 1; d <= daysInMonth; d++) {
    week.push(dayKey(new Date(year, month, d)));
    if (week.length === 7) {
      body.appendChild(weekRowLarge(week));
      week = [];
    }
  }
  if (week.length) {
    while (week.length < 7) week.push(null);
    body.appendChild(weekRowLarge(week));
  }
  return body;
}

/** The 7 date keys of the Sunday-start week containing `date`. */
export function weekOf(date = new Date()) {
  const start = new Date(date);
  start.setDate(start.getDate() - start.getDay());
  return Array.from({ length: 7 }, (_, i) => {
    const d = new Date(start);
    d.setDate(start.getDate() + i);
    return dayKey(d);
  });
}

/** Year matrix: one row per month, one dot per day. Rows are tappable. */
export function yearMatrix(year, { onMonthTap } = {}) {
  const todayKey = dayKey();
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
      row.appendChild(dot(key, { today: key === todayKey }));
    }
    if (onMonthTap) {
      row.classList.add('tappable-row');
      row.addEventListener('click', () => onMonthTap(year, m));
    }
    block.appendChild(row);
  }
  return block;
}
