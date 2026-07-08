// Archive → Calendar: one continuous experience, zooming from years down to
// a single day. Starts at the year matrices; tapping a month row morphs the
// whole year into a stack of month cards (anchored to the tapped month);
// tapping a month card expands it into weeks; large dots open the day.
// The drill position is remembered for the session, so coming back from a
// day page re-enters at the month the reader was on, not the year view.

import { daysWithEntries } from '../store.js';
import { yearMatrix, monthGridBody, weeksOfMonthBody, monthLabel, daysWrittenIn } from '../dots.js';
import { flipDots, animateHeight } from '../flip.js';
import { archiveHead, crumb } from './shared.js';
import { consentStatus, yearlySignal } from '../reflect.js';
import { showWrapped } from './wrapped.js';

let lastFocus = null; // { year, month } — where the reader last drilled to

/**
 * A raised month card that toggles between its compact grid and its weekly
 * breakdown. `canvas` is the ancestor the FLIP pass scans, so sibling cards
 * glide as the card stretches. `coordinator` keeps one card expanded at a
 * time — expanding a month collapses the previous in the same pass.
 */
function monthBlock(canvas, year, month, coordinator, { startExpanded = false, onExpand } = {}) {
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
  if (startExpanded && coordinator) coordinator.current = api;

  function toggle() {
    flipDots(canvas, () => {
      if (!expanded && coordinator) {
        coordinator.current?.collapseRaw();
        coordinator.current = api;
      } else if (coordinator && coordinator.current === api && expanded) {
        coordinator.current = null;
      }
      setExpandedRaw(!expanded);
      if (expanded) onExpand?.();
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
    lastFocus = null; // zooming out is a deliberate reset
    canvas.innerHTML = '';
    const currentYear = new Date().getFullYear();
    const years = new Set([currentYear]);
    for (const key of daysWithEntries()) years.add(Number(key.slice(0, 4)));
    // Newest first; every year with data renders — density is not capped
    for (const year of [...years].sort((a, b) => b - a)) {
      const block = yearMatrix(year, { onMonthTap: showMonths });
      // The wrapped replays from here (reflections consent required)
      if (consentStatus() === 'yes') {
        const label = block.querySelector('.year-label');
        label.classList.add('year-label-row');
        const replay = document.createElement('button');
        replay.type = 'button';
        replay.className = 'type-meta-small year-wrapped-link';
        replay.textContent = 'Your year →';
        replay.addEventListener('click', (e) => {
          e.stopPropagation();
          showWrapped(yearlySignal(year));
        });
        label.appendChild(replay);
      }
      canvas.appendChild(block);
    }
  }

  /** Build the twelve-card stack for a year; returns the selected card. */
  function buildMonths(year, month, { expandSelected = false } = {}) {
    canvas.innerHTML = '';
    canvas.appendChild(crumb(String(year), () => flipDots(canvas, showYears)));
    const coordinator = { current: null }; // one expanded month at a time
    const stack = document.createElement('div');
    stack.className = 'months-stack';
    let selected = null;
    for (let m = 0; m < 12; m++) {
      const card = monthBlock(canvas, year, m, coordinator, {
        startExpanded: expandSelected && m === month,
        onExpand: () => { lastFocus = { year, month: m }; },
      });
      if (m === month) selected = card;
      stack.appendChild(card);
    }
    canvas.appendChild(stack);
    return selected;
  }

  /** The tapped year's dots fly from matrix rows into twelve month cards,
   *  scrolled so the tapped month is in view. */
  function showMonths(year, month) {
    lastFocus = { year, month };
    flipDots(canvas, () => {
      // Anchoring inside the mutate means the FLIP pass measures post-scroll
      // positions, so dots fly to where they actually land on screen
      buildMonths(year, month)?.scrollIntoView({ block: 'start' });
    });
  }

  if (lastFocus) {
    // Returning (e.g. from a day page): re-enter at the remembered month,
    // expanded to its weeks — near where the reader left off
    const selected = buildMonths(lastFocus.year, lastFocus.month, { expandSelected: true });
    requestAnimationFrame(() => selected?.scrollIntoView({ block: 'start' }));
  } else {
    showYears();
  }

  root.appendChild(canvas);
  return {};
}
