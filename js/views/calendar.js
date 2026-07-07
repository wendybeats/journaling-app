// Archive → Calendar: one continuous experience, zooming from years down to
// a single day. Starts at the year matrices; tapping a month row morphs the
// whole year into a stack of month cards (anchored to the tapped month);
// tapping a month card expands it into weeks; large dots open the day.

import { daysWithEntries } from '../store.js';
import { yearMatrix, monthGridBody, weeksOfMonthBody, monthLabel, daysWrittenIn } from '../dots.js';
import { flipDots, animateHeight } from '../flip.js';
import { archiveHead, crumb } from './shared.js';

/**
 * A raised month card that toggles between its compact grid and its weekly
 * breakdown. `canvas` is the ancestor the FLIP pass scans, so sibling cards
 * glide as the card stretches. `coordinator` keeps one card expanded at a
 * time — expanding a month collapses the previous in the same pass.
 */
function monthBlock(canvas, year, month, coordinator = null) {
  const card = document.createElement('section');
  card.className = 'grid-card month-block';
  card.dataset.flip = `card-${year}-${month}`;
  let expanded = false;

  const header = document.createElement('header');
  const label = document.createElement('span');
  label.className = 'type-meta';
  label.textContent = monthLabel(year, month);
  const count = document.createElement('span');
  count.className = 'type-meta-small';
  const written = daysWrittenIn(year, month);
  count.textContent = `${written} ${written === 1 ? 'day' : 'days'} written`;
  header.append(label, count);

  let body = monthGridBody(year, month);
  card.append(header, body);

  // Swap the body without a FLIP pass — callers wrap this in one
  function setExpandedRaw(next) {
    if (expanded === next) return;
    expanded = next;
    animateHeight(card, () => {
      const nextBody = expanded ? weeksOfMonthBody(year, month) : monthGridBody(year, month);
      body.replaceWith(nextBody);
      body = nextBody;
      card.classList.toggle('expanded', expanded);
    });
  }

  const api = { collapseRaw: () => setExpandedRaw(false) };

  function toggle() {
    flipDots(canvas, () => {
      if (!expanded && coordinator) {
        coordinator.current?.collapseRaw();
        coordinator.current = api;
      } else if (coordinator && coordinator.current === api && expanded) {
        coordinator.current = null;
      }
      setExpandedRaw(!expanded);
    });
  }

  card.addEventListener('click', (e) => {
    // Large filled dots navigate to their day; anywhere else toggles the card
    if (e.target.closest('.dot.tappable')) return;
    toggle();
  });

  return card;
}

export function renderCalendar(root) {
  root.appendChild(archiveHead('archive/calendar'));

  const canvas = document.createElement('div');
  canvas.className = 'archive-canvas';

  function showYears() {
    canvas.innerHTML = '';
    const currentYear = new Date().getFullYear();
    const years = new Set([currentYear]);
    for (const key of daysWithEntries()) years.add(Number(key.slice(0, 4)));
    // Newest first; every year with data renders — density is not capped
    for (const year of [...years].sort((a, b) => b - a)) {
      canvas.appendChild(yearMatrix(year, { onMonthTap: showMonths }));
    }
  }

  /** The tapped year's dots fly from matrix rows into twelve month cards,
   *  scrolled so the tapped month is in view. */
  function showMonths(year, month) {
    flipDots(canvas, () => {
      canvas.innerHTML = '';
      canvas.appendChild(crumb(String(year), () => flipDots(canvas, showYears)));
      const coordinator = { current: null }; // one expanded month at a time
      const stack = document.createElement('div');
      stack.className = 'months-stack';
      let selected = null;
      for (let m = 0; m < 12; m++) {
        const card = monthBlock(canvas, year, m, coordinator);
        if (m === month) selected = card;
        stack.appendChild(card);
      }
      canvas.appendChild(stack);
      // Anchor the selected month inside the mutate, so the FLIP pass
      // measures post-scroll positions and dots fly to where they land
      selected?.scrollIntoView({ block: 'start' });
    });
  }

  showYears();
  root.appendChild(canvas);
  return {};
}
