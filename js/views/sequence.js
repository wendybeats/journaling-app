// Shared machinery for full-screen slide sequences (monthly recap, yearly
// wrapped): the overlay/stage, tap-to-skip and hold-to-pause, the reverse
// countdown bar, and the huge decorative intertitles.

export const HOLD_MS = 250; // press longer than this = hold (pause), shorter = tap (skip)
const INTERTITLE_IN_MS = 400;
const INTERTITLE_HOLD_MS = 1200;

export function el(tag, cls, text) {
  const node = document.createElement(tag);
  if (cls) node.className = cls;
  if (text !== undefined) node.textContent = text;
  return node;
}

export function reducedMotion() {
  return matchMedia('(prefers-reduced-motion: reduce)').matches;
}

export function quoteNode(text, stamp) {
  const block = el('blockquote', 'recap-quote');
  block.appendChild(el('p', null, `“${text.replace(/[.?!]$/, '')}”`));
  block.appendChild(el('footer', 'type-meta-small', stamp));
  return block;
}

/** The reverse countdown bar: full → empty over `ms`, then onDone.
 *  Pausable — a held finger stops time, release resumes what's left. */
export function countdownBar(ms, onDone) {
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

// Size an intertitle so the text fills the stage width minus 40px per side
const titleMeter = document.createElement('canvas').getContext('2d');
function fitTitleSize(text, maxWidth) {
  titleMeter.font = 'italic 400 100px Newsreader, Georgia, serif';
  const w = titleMeter.measureText(text).width;
  return Math.max(24, Math.floor((100 * maxWidth) / w));
}

/** A huge decorative title that fades in, holds, fades out — then the
 *  slide's real content begins. Returns a cancel; onDone fires once. */
export function intertitle(slide, text, onDone) {
  const t = el('div', 'recap-intertitle', text);
  slide.appendChild(t);
  t.style.fontSize = `${fitTitleSize(text, Math.min(slide.clientWidth || 430, 430) - 80)}px`;
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

/**
 * Run a slide sequence. `makeBuilders(api)` returns an array of builder
 * functions `(advance) => ({ slide, run })`; `api` exposes `close(seen)`
 * and `setControls({skip, pause, resume})` to the builders. Tap skips,
 * tap-and-hold pauses, Escape closes as seen.
 */
export function runSequence(makeBuilders, { onDismiss } = {}) {
  if (document.querySelector('.recap-overlay')) return;

  const overlay = el('div', 'recap-overlay');
  const stage = el('div', 'recap-stage');
  overlay.appendChild(stage);

  let cleanup = null;
  let controls = null;
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
    onDismiss?.(seen);
  }
  function onKey(e) {
    if (e.key === 'Escape') close(true);
  }

  const builders = makeBuilders({ close, setControls, jump: (i) => show(i) });

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
    slide.classList.add('recap-slide', 'enter');
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
