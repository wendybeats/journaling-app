// Archive → Months: every month from the current one back through the data,
// as compact grid cards. Tapping a month morphs it — dots traveling — into
// its weekly breakdown, right on the screen. Large dots tap through to days.

import { daysWithEntries } from '../store.js';
import { monthGridBody, weeksOfMonthBody, monthLabel, daysWrittenIn } from '../dots.js';
import { flipDots, animateHeight } from '../flip.js';
import { archiveHead } from './shared.js';

/**
 * A raised month card that toggles between its compact grid and its weekly
 * breakdown. `canvas` is the ancestor the FLIP pass scans, so sibling cards
 * glide as the card stretches. Returns the card element.
 */
export function monthBlock(canvas, year, month, { startExpanded = false } = {}) {
  const card = document.createElement('section');
  card.className = 'grid-card month-block';
  card.dataset.flip = `card-${year}-${month}`;
  let expanded = startExpanded;

  const header = document.createElement('header');
  const label = document.createElement('span');
  label.className = 'type-meta';
  label.textContent = monthLabel(year, month);
  const count = document.createElement('span');
  count.className = 'type-meta-small';
  const written = daysWrittenIn(year, month);
  count.textContent = `${written} ${written === 1 ? 'day' : 'days'} written`;
  header.append(label, count);

  let body = expanded ? weeksOfMonthBody(year, month) : monthGridBody(year, month);
  card.append(header, body);
  card.classList.toggle('expanded', expanded);

  function toggle() {
    expanded = !expanded;
    flipDots(canvas, () => {
      animateHeight(card, () => {
        const next = expanded ? weeksOfMonthBody(year, month) : monthGridBody(year, month);
        body.replaceWith(next);
        body = next;
        card.classList.toggle('expanded', expanded);
      });
    });
  }

  card.addEventListener('click', (e) => {
    // Large filled dots navigate to their day; anywhere else toggles the card
    if (e.target.closest('.dot.tappable')) return;
    toggle();
  });

  return card;
}

export function renderMonths(root) {
  root.appendChild(archiveHead('archive/months'));

  const canvas = document.createElement('div');
  canvas.className = 'months-stack archive-canvas';

  const now = new Date();
  const days = daysWithEntries();
  const oldest = days.length ? days[days.length - 1] : null;
  const first = oldest
    ? { y: Number(oldest.slice(0, 4)), m: Number(oldest.slice(5, 7)) - 1 }
    : { y: now.getFullYear(), m: now.getMonth() };

  let y = now.getFullYear();
  let m = now.getMonth();
  while (y > first.y || (y === first.y && m >= first.m)) {
    canvas.appendChild(monthBlock(canvas, y, m));
    m--;
    if (m < 0) { m = 11; y--; }
  }

  root.appendChild(canvas);
  return {};
}
