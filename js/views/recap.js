// Monthly recap — a full-screen five-slide sequence in the dot language:
// arrival circles → the month drawing itself dot by dot with its numbers →
// recurring topics with the user's own sentences → tone + what was hard →
// "Reflect & start anew". Timed slides carry a reverse countdown bar;
// slides with nothing honest to show remove themselves.

import { fromKey, monthName } from '../format.js';
import { monthGridBody } from '../dots.js';
import { markSeen } from '../reflect.js';

const DOT_STAGGER_MS = 60;
const STAT_STAGGER_MS = 180;

function el(tag, cls, text) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (text !== undefined) node.textContent = text;
  return node;
}

function dayStamp(key) {
  const d = fromKey(key);
  return `${monthName(d.getMonth())} ${d.getDate()}`;
}

function reducedMotion() {
  return matchMedia('(prefers-reduced-motion: reduce)').matches;
}

/** The reverse countdown bar: full → empty over `ms`, then onDone. */
function countdownBar(ms, onDone) {
  const bar = el('div', 'recap-bar');
  const fill = el('div', 'recap-bar-fill');
  bar.appendChild(fill);
  let timer = null;
  return {
    el: bar,
    start() {
      void fill.offsetWidth;
      fill.style.transition = `transform ${ms}ms linear`;
      fill.style.transform = 'scaleX(0)';
      timer = setTimeout(onDone, ms);
    },
    cancel() {
      clearTimeout(timer);
    },
  };
}

function quoteNode(q) {
  const block = el('blockquote', 'recap-quote');
  block.appendChild(el('p', null, `“${q.text.replace(/[.?!]$/, '')}”`));
  block.appendChild(el('footer', 'type-meta-small', dayStamp(q.day)));
  return block;
}

export function showMonthlyRecap(signal, { onDone } = {}) {
  if (document.querySelector('.recap-overlay')) return;

  const overlay = el('div', 'recap-overlay');
  const stage = el('div', 'recap-stage');
  overlay.appendChild(stage);

  let cleanup = null;

  function close(seen) {
    cleanup?.();
    document.removeEventListener('keydown', onKey);
    document.body.style.overflow = '';
    overlay.classList.add('leaving');
    overlay.addEventListener('transitionend', () => overlay.remove(), { once: true });
    setTimeout(() => overlay.remove(), 400);
    if (seen) markSeen(signal);
    onDone?.();
  }
  function onKey(e) {
    if (e.key === 'Escape') close(true);
  }

  // --- Slide 1: arrival ---
  function introSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center');
    const circles = el('div', 'recap-circles');
    circles.append(el('div', 'recap-circle-ring'), el('div', 'recap-circle-fill'));
    center.append(circles, el('h2', 'type-title', 'Reflections – Your month'));
    slide.appendChild(center);

    const skip = el('button', 'type-meta-small recap-skip', 'Not interested');
    skip.type = 'button';
    skip.addEventListener('click', () => close(true));

    const bar = countdownBar(3000, advance);
    slide.append(bar.el, skip);
    return { slide, run: () => (bar.start(), () => bar.cancel()) };
  }

  // --- Slide 2: the month, drawn dot by dot, then its numbers ---
  function statsSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center recap-stats');

    const title = el('h2', 'type-title recap-reveal', `${monthName(signal.month)} ${signal.year}`);
    const grid = monthGridBody(signal.year, signal.month);
    grid.classList.add('recap-grid');

    const stats = [
      [String(signal.days), signal.days === 1 ? 'day written' : 'days written'],
      [signal.words.toLocaleString(), 'words'],
      [String(signal.longestRun), `${signal.longestRun === 1 ? 'day' : 'days'} longest run`],
    ].map(([num, label]) => {
      const row = el('div', 'recap-stat recap-reveal');
      row.append(el('span', 'recap-stat-number', num), el('span', 'type-meta', label));
      return row;
    });

    center.append(title, grid, ...stats);
    slide.appendChild(center);
    const bar = countdownBar(5000, advance);
    slide.appendChild(bar.el);

    return {
      slide,
      run() {
        const timers = [];
        const dots = [...slide.querySelectorAll('.dot.filled')];
        for (const d of dots) d.classList.add('recap-pending');
        const reveals = [title, ...stats];

        if (reducedMotion()) {
          dots.forEach((d) => d.classList.remove('recap-pending'));
          reveals.forEach((r) => r.classList.add('on'));
          bar.start();
        } else {
          dots.forEach((d, i) => {
            timers.push(setTimeout(() => d.classList.remove('recap-pending'), 200 + i * DOT_STAGGER_MS));
          });
          const afterDots = 300 + dots.length * DOT_STAGGER_MS;
          reveals.forEach((r, i) => {
            timers.push(setTimeout(() => r.classList.add('on'), afterDots + i * STAT_STAGGER_MS));
          });
          timers.push(setTimeout(() => bar.start(), afterDots + reveals.length * STAT_STAGGER_MS));
        }
        return () => { timers.forEach(clearTimeout); bar.cancel(); };
      },
    };
  }

  // --- Slide 3: recurring topics, one at a time ---
  function topicsSlide(advance) {
    const slide = el('div', 'recap-slide');
    const holder = el('div', 'recap-center recap-topic-holder');
    slide.appendChild(holder);
    const barHolder = el('div', 'recap-bar-holder');
    slide.appendChild(barHolder);

    return {
      slide,
      run() {
        const timers = [];
        let bar = null;

        function showTopic(i) {
          if (i >= signal.topics.length) { advance(); return; }
          const topic = signal.topics[i];
          holder.innerHTML = '';
          barHolder.innerHTML = '';

          holder.appendChild(el('div', 'type-meta-small', `Recurring · ${i + 1} of ${signal.topics.length}`));
          holder.appendChild(el('div', 'recap-topic-word', `“${topic.word}”`));
          holder.appendChild(el('div', 'type-meta', `${topic.days} days`));

          const quotes = topic.quotes.map(quoteNode);
          for (const q of quotes) {
            q.classList.add('recap-reveal');
            holder.appendChild(q);
          }

          const enterMs = reducedMotion() ? 0 : 350;
          quotes.forEach((q, qi) => {
            timers.push(setTimeout(() => q.classList.add('on'), enterMs + qi * 250));
          });
          const settled = enterMs + quotes.length * 250;
          timers.push(setTimeout(() => {
            bar = countdownBar(3000, () => showTopic(i + 1));
            barHolder.appendChild(bar.el);
            bar.start();
          }, settled));
        }

        showTopic(0);
        return () => { timers.forEach(clearTimeout); bar?.cancel(); };
      },
    };
  }

  // --- Slide 4: tone + what seemed difficult ---
  function toneSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center');

    if (signal.tone) {
      center.appendChild(el('div', 'type-meta-small', 'Tone'));
      center.appendChild(el('p', 'recap-tone',
        `Your word was “${signal.tone.word}” — it appeared ${signal.tone.count} times.`));
    }

    const reveals = [];
    if (signal.difficult.length) {
      const label = el('div', 'type-meta-small recap-difficult-label recap-reveal', 'What seemed difficult');
      center.appendChild(label);
      reveals.push(label);
      for (const q of signal.difficult.slice(0, 2)) {
        const node = quoteNode(q);
        node.classList.add('recap-reveal');
        center.appendChild(node);
        reveals.push(node);
      }
    }

    slide.appendChild(center);
    const bar = countdownBar(3000, advance);
    slide.appendChild(bar.el);

    return {
      slide,
      run() {
        const timers = [];
        const enterMs = reducedMotion() ? 0 : 500;
        reveals.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), enterMs + i * 250)));
        timers.push(setTimeout(() => bar.start(), enterMs + reveals.length * 250));
        return () => { timers.forEach(clearTimeout); bar.cancel(); };
      },
    };
  }

  // --- Slide 5: reflect & start anew ---
  function outroSlide() {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center');
    const next = (signal.month + 1) % 12;
    center.appendChild(el('div', 'type-meta', `${monthName(signal.month)} → ${monthName(next)}`));
    center.appendChild(el('h1', 'type-display recap-big', 'Reflect & start anew'));
    slide.appendChild(center);

    const cta = el('button', 'type-meta recap-continue', 'Continue');
    cta.type = 'button';
    cta.addEventListener('click', () => close(true));
    slide.appendChild(cta);
    return { slide, run: () => null };
  }

  // Assemble — slides with nothing honest to show remove themselves
  const builders = [introSlide, statsSlide];
  if (signal.topics.length) builders.push(topicsSlide);
  if (signal.tone || signal.difficult.length) builders.push(toneSlide);
  builders.push(outroSlide);

  let idx = -1;
  function advance() {
    show(idx + 1);
  }
  function show(i) {
    if (i >= builders.length) { close(true); return; }
    cleanup?.();
    cleanup = null;
    const prev = stage.firstElementChild;
    const { slide, run } = builders[i](advance);
    slide.classList.add('enter');
    stage.appendChild(slide);
    void slide.offsetWidth;
    slide.classList.remove('enter');
    if (prev) {
      prev.classList.add('exit');
      setTimeout(() => prev.remove(), 400);
    }
    idx = i;
    cleanup = run() ?? null;
  }

  document.addEventListener('keydown', onKey);
  document.body.appendChild(overlay);
  document.body.style.overflow = 'hidden';
  requestAnimationFrame(() => overlay.classList.add('open'));
  show(0);
}
