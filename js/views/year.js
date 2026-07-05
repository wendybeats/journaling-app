// Archive (year matrix) — the zoomed-out dot field. The retention payoff.

import { daysWithEntries } from '../store.js';
import { yearMatrix } from '../dots.js';

export function renderYear(root) {
  const head = document.createElement('div');
  head.className = 'view-head';
  const title = document.createElement('h1');
  title.className = 'type-display';
  title.textContent = 'Archive';
  const toggle = document.createElement('nav');
  toggle.className = 'type-meta view-toggle';
  toggle.innerHTML = `
    <a href="#archive">Days</a>
    <a href="#year" class="active">Years</a>`;
  head.append(title, toggle);
  root.appendChild(head);

  const currentYear = new Date().getFullYear();
  const years = new Set([currentYear]);
  for (const key of daysWithEntries()) years.add(Number(key.slice(0, 4)));

  // Newest first; every year with data renders — density is not capped
  for (const year of [...years].sort((a, b) => b - a)) {
    root.appendChild(yearMatrix(year));
  }

  return {};
}
