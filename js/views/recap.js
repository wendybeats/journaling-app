// Monthly recap — a full-screen slide sequence in the dot language:
// arrival circles → the month drawing itself dot by dot with its numbers →
// recurring ideas → your word → challenges → "Reflect & start anew".
// Chapter slides open with an intertitle that fades in and out before the
// content begins. Timed slides carry a reverse countdown bar; tap advances
// early, tap-and-hold pauses time; slides with nothing honest to show
// remove themselves.

import { fromKey, monthName } from '../format.js';
import { monthGridBody } from '../dots.js';
import { markSeen } from '../reflect.js';

const DOT_STAGGER_MS = 60;
const STAT_STAGGER_MS = 180;
const INTRO_MS = 4500;
const STATS_MS = 6500;
const TOPIC_MS = 4500;
const TONE_MS = 4500;
const INTERTITLE_IN_MS = 400;
const INTERTITLE_HOLD_MS = 1200;
const HOLD_MS = 250; // press longer than this = hold (pause), shorter = tap (skip)

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

/** The reverse countdown bar: full → empty over `ms`, then onDone.
 *  Pausable — a held finger stops time, release resumes what's left. */
function countdownBar(ms, onDone) {
  const bar = el('div', 'recap-bar');
  const fill = el('div', 'recap-bar-fill');
  bar.appendChild(fill);
  let timer = null;
  let startedAt = 0;
  let remaining = ms;
  let running = false;

  function start() {
    if (running || remaining <= 0) return;
    running = true;
    startedAt = performance.now();
    timer = setTimeout(onDone, remaining);
    // Next frame, so a just-frozen transform commits before re-animating
    requestAnimationFrame(() => {
      if (!running) return;
      fill.style.transition = `transform ${remaining}ms linear`;
      fill.style.transform = 'scaleX(0)';
    });
  }
  function pause() {
    if (!running) return;
    running = false;
    clearTimeout(timer);
    remaining -= performance.now() - startedAt;
    // Freeze in scaleX() form: a matrix() start can't interpolate to the
    // singular scaleX(0) target, so the resume would jump instead of glide
    const m = getComputedStyle(fill).transform;
    const sx = m.startsWith('matrix(') ? parseFloat(m.slice(7)) : 1;
    fill.style.transition = 'none';
    fill.style.transform = `scaleX(${sx})`;
  }
  return {
    el: bar,
    start,
    pause,
    resume: start,
    cancel() { running = false; clearTimeout(timer); },
  };
}

function quoteNode(q) {
  const block = el('blockquote', 'recap-quote');
  block.appendChild(el('p', null, `“${q.text.replace(/[.?!]$/, '')}”`));
  block.appendChild(el('footer', 'type-meta-small', dayStamp(q.day)));
  return block;
}

/** A large title that fades in, holds, fades out — then the slide's real
 *  content begins. Returns a cancel function; onDone fires exactly once. */
function intertitle(slide, text, onDone) {
  const t = el('div', 'recap-intertitle type-display', text);
  slide.appendChild(t);
  const timers = [];
  let done = false;
  function finish() {
    if (done) return;
    done = true;
    timers.forEach(clearTimeout);
    t.remove();
    onDone();
  }
  if (reducedMotion()) {
    finish();
    return () => {};
  }
  requestAnimationFrame(() => t.classList.add('on'));
  timers.push(setTimeout(() => t.classList.remove('on'), INTERTITLE_IN_MS + INTERTITLE_HOLD_MS));
  timers.push(setTimeout(finish, INTERTITLE_IN_MS * 2 + INTERTITLE_HOLD_MS));
  return () => { timers.forEach(clearTimeout); t.remove(); done = true; };
}

export function showMonthlyRecap(signal, { onDone } = {}) {
  if (document.querySelector('.recap-overlay')) return;

  const overlay = el('div', 'recap-overlay');
  const stage = el('div', 'recap-stage');
  overlay.appendChild(stage);

  let cleanup = null;
  let controls = null; // { skip, pause, resume } for the current slide
  function setControls(c) {
    controls = c;
  }

  // Tap advances; a held press pauses time until release
  let holdTimer = null;
  let holding = false;
  overlay.addEventListener('pointerdown', (e) => {
    if (e.target.closest('button')) return;
    e.preventDefault();
    holding = false;
    holdTimer = setTimeout(() => { holding = true; controls?.pause?.(); }, HOLD_MS);
  });
  overlay.addEventListener('pointerup', (e) => {
    clearTimeout(holdTimer);
    if (holding) {
      holding = false;
      controls?.resume?.();
    } else if (!e.target.closest('button')) {
      controls?.skip?.();
    }
  });
  overlay.addEventListener('pointercancel', () => {
    clearTimeout(holdTimer);
    if (holding) { holding = false; controls?.resume?.(); }
  });

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

    const bar = countdownBar(INTRO_MS, advance);
    slide.append(bar.el, skip);
    return {
      slide,
      run() {
        bar.start();
        setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
        return () => bar.cancel();
      },
    };
  }

  // --- Slide 2: the month, drawn dot by dot, then its numbers ---
  function statsSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center recap-stats');

    const title = el('h2', 'type-title recap-reveal', `${monthName(signal.month)} ${signal.year}`);
    const grid = monthGridBody(signal.year, signal.month);
    grid.classList.add('recap-grid');

    const stats = [
      [String(signal.days), 'days written'],
      [signal.words.toLocaleString(), 'words'],
      [String(signal.longestRun), 'longest run'],
    ].map(([num, label]) => {
      const col = el('div', 'recap-stat recap-reveal');
      col.append(el('span', 'recap-stat-number', num), el('span', 'type-meta-small', label));
      return col;
    });
    const statsRow = el('div', 'recap-stats-row');
    statsRow.append(...stats);

    center.append(title, grid, statsRow);
    slide.appendChild(center);
    const bar = countdownBar(STATS_MS, advance);
    slide.appendChild(bar.el);

    return {
      slide,
      run() {
        setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
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
        holder.style.visibility = 'hidden';

        let started = false;
        function startContent() {
          if (started) return;
          started = true;
          holder.style.visibility = '';
          showTopic(0);
        }
        const cancelInter = intertitle(slide, 'Recurring ideas', startContent);
        setControls({ skip: () => { cancelInter(); startContent(); } });

        function showTopic(i) {
          if (i >= signal.topics.length) { advance(); return; }
          timers.forEach(clearTimeout);
          timers.length = 0;
          bar?.cancel();
          const topic = signal.topics[i];
          holder.innerHTML = '';
          barHolder.innerHTML = '';
          setControls({
            skip: () => showTopic(i + 1),
            pause: () => bar?.pause(),
            resume: () => bar?.resume(),
          });

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
            bar = countdownBar(TOPIC_MS, () => showTopic(i + 1));
            barHolder.appendChild(bar.el);
            bar.start();
          }, settled));
        }

        return () => { cancelInter(); timers.forEach(clearTimeout); bar?.cancel(); };
      },
    };
  }

  // --- Slide 4: your word (tone) ---
  function toneSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center');
    const sentence = el('p', 'recap-tone recap-reveal',
      `Your word was \u201c${signal.tone.word}\u201d \u2014 it appeared ${signal.tone.count} times.`);
    center.appendChild(sentence);
    slide.appendChild(center);
    const bar = countdownBar(TONE_MS, advance);
    slide.appendChild(bar.el);

    return {
      slide,
      run() {
        const timers = [];
        let started = false;
        function startContent() {
          if (started) return;
          started = true;
          timers.push(setTimeout(() => sentence.classList.add('on'), 50));
          timers.push(setTimeout(() => bar.start(), 450));
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
        }
        const cancelInter = intertitle(slide, 'Your Word', startContent);
        setControls({ skip: () => { cancelInter(); startContent(); } });
        return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
      },
    };
  }

  // --- Slide 5: challenges (what seemed difficult) ---
  function challengesSlide(advance) {
    const slide = el('div', 'recap-slide');
    const center = el('div', 'recap-center');
    const reveals = [];
    const label = el('div', 'type-meta-small recap-reveal', 'What seemed difficult');
    center.appendChild(label);
    reveals.push(label);
    for (const q of signal.difficult.slice(0, 2)) {
      const node = quoteNode(q);
      node.classList.add('recap-reveal');
      center.appendChild(node);
      reveals.push(node);
    }
    slide.appendChild(center);
    const bar = countdownBar(TONE_MS, advance);
    slide.appendChild(bar.el);

    return {
      slide,
      run() {
        const timers = [];
        let started = false;
        function startContent() {
          if (started) return;
          started = true;
          reveals.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), 50 + i * 250)));
          timers.push(setTimeout(() => bar.start(), 50 + reveals.length * 250));
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
        }
        const cancelInter = intertitle(slide, 'Challenges', startContent);
        setControls({ skip: () => { cancelInter(); startContent(); } });
        return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
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
    return { slide, run: () => (setControls(null), null) };
  }

  // Assemble — slides with nothing honest to show remove themselves
  const builders = [introSlide, statsSlide];
  if (signal.topics.length) builders.push(topicsSlide);
  if (signal.tone) builders.push(toneSlide);
  if (signal.difficult.length) builders.push(challengesSlide);
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
