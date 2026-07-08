// Yearly wrapped — the retention payoff as a slide sequence: the year
// matrix drawing itself dot by dot, the big numbers, the top five topics,
// the most-discussed reveal with its first-ever mention, and "See you on
// the page" with a save-as-image of the dots (dots and counts only — the
// writing never leaves). Built on the shared sequence machinery.

import { fromKey, monthName } from '../format.js';
import { yearMatrix } from '../dots.js';
import { el, reducedMotion, countdownBar, intertitle, quoteNode, runSequence } from './sequence.js';

const MATRIX_DOT_STAGGER_MS = 14;
const MATRIX_MS = 6000;
const STATS_MS = 6000;
const TOPICS_MS = 6000;
const REVEAL_MS = 7000;

function fullStamp(key) {
  const d = fromKey(key);
  return `${monthName(d.getMonth())} ${d.getDate()}, ${d.getFullYear()}`;
}

/** Share image: the dot matrix + counts, monochrome, 1080×1350. Dots and
 *  numbers only — never text content. */
function shareImage(signal, dark) {
  const W = 1080;
  const H = 1350;
  const canvas = document.createElement('canvas');
  canvas.width = W;
  canvas.height = H;
  const ctx = canvas.getContext('2d');

  const bg = dark ? '#161514' : '#E8E6E1';
  const ink = dark ? '#E8E6E1' : '#1A1A1A';
  const faint = dark ? '#6B6862' : '#C9C6BF';
  const meta = dark ? '#6B6862' : '#A9A6A0';

  ctx.fillStyle = bg;
  ctx.fillRect(0, 0, W, H);

  // Matrix: 12 rows × 31 columns
  const left = 120;
  const top = 260;
  const cell = (W - left * 2) / 30;
  const rowGap = 46;
  const now = new Date();
  for (let m = 0; m < 12; m++) {
    const daysInMonth = new Date(signal.year, m + 1, 0).getDate();
    for (let d = 1; d <= daysInMonth; d++) {
      const date = new Date(signal.year, m, d);
      if (date > now) continue;
      const key = `${signal.year}-${String(m + 1).padStart(2, '0')}-${String(d).padStart(2, '0')}`;
      const written = signal.writtenKeys.has(key);
      ctx.fillStyle = written ? ink : faint;
      ctx.beginPath();
      ctx.arc(left + (d - 1) * cell, top + m * rowGap, written ? 9 : 6, 0, Math.PI * 2);
      ctx.fill();
    }
  }

  ctx.fillStyle = meta;
  ctx.font = '400 34px "Fragment Mono", monospace';
  ctx.textAlign = 'center';
  ctx.fillText(`V E L L U M   ·   ${signal.year}`, W / 2, 150);

  ctx.fillStyle = ink;
  ctx.font = '500 84px "Instrument Sans", sans-serif';
  ctx.fillText(String(signal.days), W / 2 - 300, 1080);
  ctx.fillText(signal.words.toLocaleString(), W / 2, 1080);
  ctx.fillText(String(signal.longestRun), W / 2 + 300, 1080);
  ctx.fillStyle = meta;
  ctx.font = '400 26px "Fragment Mono", monospace';
  ctx.fillText('DAYS', W / 2 - 300, 1130);
  ctx.fillText('WORDS', W / 2, 1130);
  ctx.fillText('LONGEST RUN', W / 2 + 300, 1130);

  return canvas.toDataURL('image/png');
}

export function showWrapped(signal, { onDone } = {}) {
  runSequence(({ close, setControls }) => {
    // --- Slide 1: the year draws itself ---
    function matrixSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const title = el('h2', 'type-title recap-reveal', String(signal.year));
      const matrix = yearMatrix(signal.year);
      matrix.classList.add('wrapped-matrix');
      matrix.querySelector('.year-label').remove(); // the slide title carries the year
      center.append(title, matrix);
      slide.appendChild(center);
      const bar = countdownBar(MATRIX_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          const timers = [];
          const dots = [...matrix.querySelectorAll('.dot.filled')];
          for (const d of dots) d.classList.add('recap-pending');
          if (reducedMotion()) {
            dots.forEach((d) => d.classList.remove('recap-pending'));
            title.classList.add('on');
            bar.start();
          } else {
            dots.forEach((d, i) => {
              timers.push(setTimeout(() => d.classList.remove('recap-pending'), 300 + i * MATRIX_DOT_STAGGER_MS));
            });
            const afterDots = 400 + dots.length * MATRIX_DOT_STAGGER_MS;
            timers.push(setTimeout(() => title.classList.add('on'), afterDots));
            timers.push(setTimeout(() => bar.start(), afterDots + 300));
          }
          return () => { timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 2: the numbers ---
    function statsSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const stats = [
        [String(signal.days), 'days written'],
        [signal.words.toLocaleString(), 'words'],
        [String(signal.longestRun), 'longest run'],
      ].map(([num, label]) => {
        const col = el('div', 'recap-stat recap-reveal wrapped-stat');
        col.append(el('span', 'recap-stat-number', num), el('span', 'type-meta-small', label));
        return col;
      });
      center.append(...stats);
      slide.appendChild(center);
      const bar = countdownBar(STATS_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          const timers = [];
          stats.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), 200 + i * 350)));
          timers.push(setTimeout(() => bar.start(), 200 + stats.length * 350));
          return () => { timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 3: top five topics ---
    function topicsSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const rows = signal.topics.map((t, i) => {
        const row = el('div', 'wrapped-topic recap-reveal');
        row.append(
          el('span', 'type-meta-small wrapped-topic-rank', String(i + 1)),
          el('span', 'wrapped-topic-word', `“${t.word}”`),
          el('span', 'type-meta-small', `${t.days} days`),
        );
        return row;
      });
      center.append(...rows);
      slide.appendChild(center);
      const bar = countdownBar(TOPICS_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          const timers = [];
          let started = false;
          function startContent() {
            if (started) return;
            started = true;
            rows.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), 50 + i * 300)));
            timers.push(setTimeout(() => bar.start(), 50 + rows.length * 300));
            setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          }
          const cancelInter = intertitle(slide, 'Five threads', startContent);
          setControls({ skip: () => { cancelInter(); startContent(); } });
          return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 4: the reveal ---
    function revealSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const word = el('div', 'recap-topic-word wrapped-reveal-word recap-reveal', `“${signal.reveal.word}”`);
      const count = el('div', 'type-meta recap-reveal', `${signal.reveal.days} days · ${signal.reveal.mentions} mentions`);
      const started = el('div', 'type-meta-small recap-reveal wrapped-reveal-started',
        `It started on ${fullStamp(signal.reveal.first.day)}`);
      const quote = quoteNode(signal.reveal.first.text, '');
      quote.classList.add('recap-reveal');
      quote.querySelector('footer').remove();
      center.append(word, count, started, quote);
      slide.appendChild(center);
      const bar = countdownBar(REVEAL_MS, advance);
      slide.appendChild(bar.el);

      const reveals = [word, count, started, quote];
      return {
        slide,
        run() {
          const timers = [];
          let began = false;
          function startContent() {
            if (began) return;
            began = true;
            reveals.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), 50 + i * 400)));
            timers.push(setTimeout(() => bar.start(), 50 + reveals.length * 400));
            setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          }
          const cancelInter = intertitle(slide, 'Most discussed', startContent);
          setControls({ skip: () => { cancelInter(); startContent(); } });
          return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 5: see you on the page ---
    function outroSlide() {
      const slide = el('div');
      const center = el('div', 'recap-center');
      center.appendChild(el('div', 'type-meta', String(signal.year)));
      center.appendChild(el('h1', 'type-display recap-big', 'See you on the page.'));

      const save = el('button', 'type-meta-small wrapped-save', 'Save your year');
      save.type = 'button';
      save.addEventListener('click', () => {
        const dark = matchMedia('(prefers-color-scheme: dark)').matches
          && document.documentElement.dataset.theme !== 'light'
          || document.documentElement.dataset.theme === 'dark';
        const a = document.createElement('a');
        a.href = shareImage(signal, dark);
        a.download = `vellum-${signal.year}.png`;
        a.click();
      });
      center.appendChild(save);
      slide.appendChild(center);

      const cta = el('button', 'type-meta recap-continue', 'Continue');
      cta.type = 'button';
      cta.addEventListener('click', () => close(true));
      slide.appendChild(cta);
      return { slide, run: () => (setControls(null), null) };
    }

    // Thin years: matrix + counts only, one honest shape
    const builders = [matrixSlide, statsSlide];
    if (signal.topics.length) builders.push(topicsSlide);
    if (signal.reveal) builders.push(revealSlide);
    builders.push(outroSlide);
    return builders;
  }, {
    onDismiss() {
      onDone?.();
    },
  });
}
