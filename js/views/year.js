// Archive → Years: the dense dot field. Tapping a month row lifts that month
// out of the matrix — its dots travel into the compact grid — and from there
// it can break down further into weeks, then days.

import { daysWithEntries } from '../store.js';
import { yearMatrix } from '../dots.js';
import { flipDots } from '../flip.js';
import { archiveHead, crumb } from './shared.js';
import { monthBlock } from './months.js';

export function renderYears(root) {
  root.appendChild(archiveHead('archive/years'));

  const canvas = document.createElement('div');
  canvas.className = 'archive-canvas';

  function showYears() {
    canvas.innerHTML = '';
    const currentYear = new Date().getFullYear();
    const years = new Set([currentYear]);
    for (const key of daysWithEntries()) years.add(Number(key.slice(0, 4)));
    // Newest first; every year with data renders — density is not capped
    for (const year of [...years].sort((a, b) => b - a)) {
      canvas.appendChild(yearMatrix(year, { onMonthTap: focusMonth }));
    }
  }

  function focusMonth(year, month) {
    // The tapped month's dots fly from their matrix row into the month grid
    flipDots(canvas, () => {
      canvas.innerHTML = '';
      const back = crumb(String(year), () => flipDots(canvas, showYears));
      canvas.appendChild(back);
      canvas.appendChild(monthBlock(canvas, year, month));
    });
  }

  showYears();
  root.appendChild(canvas);
  return {};
}
