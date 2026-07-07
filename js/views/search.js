// Search — a large blank screen over the app. One oversized input whose type
// starts huge and shrinks to fit as the query grows; results read like the
// log, grouped by day, and tap through to the day page.

import { daysWithEntries, entriesFor } from '../store.js';
import { fromKey, dayHeading, timeOfDay } from '../format.js';

const TYPE_MAX = 42;
const TYPE_MIN = 17;

export function openSearch() {
  if (document.querySelector('.search-overlay')) return;

  const overlay = document.createElement('div');
  overlay.className = 'search-overlay';
  const inner = document.createElement('div');
  inner.className = 'search-inner';

  const top = document.createElement('div');
  top.className = 'search-top';
  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'search-close';
  close.setAttribute('aria-label', 'Close search');
  close.textContent = '×';
  top.appendChild(close);

  const input = document.createElement('input');
  input.className = 'search-input';
  input.type = 'text';
  input.placeholder = 'Search your log';
  input.setAttribute('aria-label', 'Search your log');

  const results = document.createElement('div');
  results.className = 'search-results archive';

  function destroy() {
    document.removeEventListener('keydown', onKey);
    document.body.style.overflow = '';
    overlay.remove();
  }
  function onKey(e) {
    if (e.key === 'Escape') destroy();
  }
  close.addEventListener('click', destroy);
  document.addEventListener('keydown', onKey);

  // --- Type fitting: start very large, shrink to keep the query on the bar ---
  const meter = document.createElement('canvas').getContext('2d');
  function fit() {
    const width = input.clientWidth - 2;
    let size = TYPE_MAX;
    for (; size > TYPE_MIN; size--) {
      meter.font = `400 ${size}px Newsreader, Georgia, serif`;
      if (meter.measureText(input.value).width <= width) break;
    }
    input.style.fontSize = `${size}px`;
  }

  // --- Matching: case-insensitive keyword over the whole log ---
  function markedText(text, q) {
    const p = document.createElement('p');
    const lower = text.toLowerCase();
    let i = 0;
    for (let hit = lower.indexOf(q); hit !== -1; hit = lower.indexOf(q, i)) {
      p.appendChild(document.createTextNode(text.slice(i, hit)));
      const mark = document.createElement('mark');
      mark.textContent = text.slice(hit, hit + q.length);
      p.appendChild(mark);
      i = hit + q.length;
    }
    p.appendChild(document.createTextNode(text.slice(i)));
    return p;
  }

  function run() {
    const q = input.value.trim().toLowerCase();
    results.innerHTML = '';
    if (!q) return;

    let dayCount = 0;
    let entryCount = 0;
    const frag = document.createDocumentFragment();

    for (const key of daysWithEntries()) {
      const hits = entriesFor(key).filter((e) => e.text.toLowerCase().includes(q));
      if (!hits.length) continue;
      dayCount++;
      entryCount += hits.length;

      const day = document.createElement('section');
      day.className = 'day search-day';
      const heading = document.createElement('h2');
      heading.className = 'type-title';
      heading.textContent = dayHeading(fromKey(key));
      const rule = document.createElement('hr');
      rule.className = 'day-rule';
      day.append(heading, rule);

      for (const entry of hits) {
        const el = document.createElement('article');
        el.className = 'entry type-written search-hit';
        const time = document.createElement('time');
        time.className = 'type-meta-small';
        time.textContent = timeOfDay(entry.at);
        el.appendChild(time);
        el.appendChild(markedText(entry.text.replace(/\n{2,}/g, '  '), q));
        el.addEventListener('click', () => {
          destroy();
          location.hash = `#archive/day/${key}`;
        });
        day.appendChild(el);
      }
      frag.appendChild(day);
    }

    const summary = document.createElement('div');
    summary.className = 'type-meta search-summary';
    summary.textContent = entryCount
      ? `${entryCount} ${entryCount === 1 ? 'entry' : 'entries'} · ${dayCount} ${dayCount === 1 ? 'day' : 'days'}`
      : 'nothing found';
    results.append(summary, frag);
  }

  let debounce = null;
  input.addEventListener('input', () => {
    fit();
    clearTimeout(debounce);
    debounce = setTimeout(run, 160);
  });

  inner.append(top, input, results);
  overlay.appendChild(inner);
  document.body.appendChild(overlay);
  document.body.style.overflow = 'hidden';
  fit();
  requestAnimationFrame(() => input.focus());
}
