// endpaper.space — the living graphics. Dots only, in the app's own
// registers. Each graphic plays once, when it scrolls into view, then
// rests in its finished state. Static from the start under
// prefers-reduced-motion.

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

function onceInView(el, run, threshold = 0.4) {
  if (reduced) { run(true); return; }
  new IntersectionObserver((entries, obs) => {
    if (entries.some((e) => e.isIntersecting)) {
      run(false);
      obs.disconnect();
    }
  }, { threshold }).observe(el);
}

/* --- The dive: the hero's dot swallows the screen ---------------------------- */
/* The ink section's box is raised (margin up, padding down — content
   never moves) until its top edge sits exactly at the hero's dot; its
   seam dot replaces the hero dot pixel-for-pixel. The section is then
   clipped to a circle that starts as that dot and inflates with scroll,
   the ink swallowing the headline and badge on its way to full screen.
   The clip drops entirely once open; scrolling back re-seals the dot. */

const deepSection = document.querySelector('section.deep');
const heroDot = document.querySelector('.hero .mark-dot');
if (deepSection && heroDot && !reduced) {
  let dotDocY = 0, fullScroll = 1, maxR = 0, diveTicking = false;

  function measure() {
    // Undo any previous surgery before measuring fresh.
    deepSection.style.marginTop = '';
    deepSection.style.paddingTop = '';
    heroDot.style.visibility = '';
    deepSection.style.clipPath = 'none';

    const d = heroDot.getBoundingClientRect();
    const s = deepSection.getBoundingClientRect();
    dotDocY = d.top + scrollY + d.height / 2;
    const lift = Math.round(s.top + scrollY - dotDocY);
    const cs = getComputedStyle(deepSection);
    deepSection.style.marginTop = (parseFloat(cs.marginTop) - lift) + 'px';
    deepSection.style.paddingTop = (parseFloat(cs.paddingTop) + lift) + 'px';
    heroDot.style.visibility = 'hidden';     // the seam dot takes its place

    // Fully open when the ink's original top edge reaches the top of the
    // viewport — the dive spans most of a viewport of scrolling, slow to
    // leave the dot, fast at the end.
    fullScroll = Math.max(240, dotDocY + lift - innerHeight * 0.12);
    maxR = Math.hypot(innerWidth / 2, fullScroll - dotDocY + innerHeight);
  }

  function dive() {
    diveTicking = false;
    const p = Math.min(1, Math.max(0, scrollY / fullScroll));
    if (p >= 1) { deepSection.style.clipPath = 'none'; return; }
    const R = 8 + Math.pow(p, 1.7) * maxR;
    deepSection.style.clipPath = `circle(${R}px at 50% 0px)`;
  }

  measure(); dive();
  addEventListener('scroll', () => {
    if (!diveTicking) { diveTicking = true; requestAnimationFrame(dive); }
  }, { passive: true });
  let rz;
  addEventListener('resize', () => { clearTimeout(rz); rz = setTimeout(() => { measure(); dive(); }, 120); });
}

/* --- The deep sea: dot trails sinking into the ink -------------------------- */
/* Particles drift down a slow flow field from the seam, stamping faint
   bone dots as they go; stamps age out, and everything dissipates with
   depth — trails disappearing into the ocean. Runs only while the
   section is on screen. Reduced motion gets one settled, static frame. */

const sea = document.getElementById('deep-sea');
if (sea) {
  const ctx = sea.getContext('2d');
  const DOT = '#332F2B';                      // hairline-dk — the unfilled-dot register,
                                              // same as the week/matrix dots on the ink
  const LIFE = 22000;                         // stamp lifetime — tails reach the whole band
  const STEP = 7;                             // px of travel between dots — dense, beaded strands
  const BASE_ALPHA = 0.85;                    // solid-register color; fades do the rest
  let W = 0, H = 0, dpr = 1, sprite = null;
  let particles = [], stamps = [], head = 0, CAP = 6000;
  let running = false, raf = 0, last = 0, t = 0;

  function size() {
    const rect = sea.getBoundingClientRect();
    dpr = Math.min(devicePixelRatio || 1, 2);
    W = rect.width; H = rect.height;
    sea.width = Math.round(W * dpr);
    sea.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    // a soft pre-blurred dot, stamped instead of per-arc fills
    sprite = document.createElement('canvas');
    const s = 10 * dpr;
    sprite.width = sprite.height = s;
    const sc = sprite.getContext('2d');
    const g = sc.createRadialGradient(s / 2, s / 2, 0, s / 2, s / 2, s / 2);
    g.addColorStop(0, DOT); g.addColorStop(0.55, DOT); g.addColorStop(1, 'transparent');
    sc.fillStyle = g;
    sc.beginPath(); sc.arc(s / 2, s / 2, s / 2, 0, Math.PI * 2); sc.fill();
    const n = W < 760 ? 14 : 26;
    const now = performance.now();
    particles = Array.from({ length: n }, () => spawn(now));
    // First fill: scatter births across a whole life cycle so the warm
    // start produces strands at every stage, not one synchronized drop.
    for (const p of particles) p.born = now - Math.random() * LIFE;
    stamps = []; head = 0;
  }

  function spawn(now) {
    return {
      x: Math.random() * W,
      y: -20 - Math.random() * 60,
      phase: Math.random() * Math.PI * 2,
      speed: 45 + Math.random() * 33,          // px/s — quick enough to keep pace with a scroll
      trail: 0,
      r: 0.9 + Math.random() * 1.5,            // strands differ in weight
      born: (now ?? 0) + Math.random() * 4500, // staggered starts, never in chorus
    };
  }

  // Man-o-war tentacles: dominantly vertical, swaying at most ~20° —
  // one long S along the strand's depth, one slow breath in time.
  function angle(p) {
    return Math.PI / 2
      + Math.sin(p.y * 0.006 + p.phase) * 0.24
      + Math.sin(t * 0.00035 + p.phase * 1.7) * 0.10
      + Math.sin(p.x * 0.004 - t * 0.0002) * 0.06;
  }

  function step(now) {
    const dt = Math.min(now - last, 50) / 1000;
    last = now; t = now;
    for (const p of particles) {
      if (now < p.born) continue;              // waiting its turn at the surface
      const a = angle(p);
      p.x += Math.cos(a) * p.speed * dt;
      p.y += Math.sin(a) * p.speed * dt;
      p.trail += p.speed * dt;
      if (p.trail > STEP) {
        p.trail = 0;
        stamps[head % CAP] = { x: p.x, y: p.y, r: p.r * (0.88 + Math.random() * 0.24), born: now };
        head++;
      }
      // A strand retires once its trail is fully drawn — before its top
      // erodes free of the surface. Tentacles hang from the top, always;
      // a head that outlived its tail was forming loose mid-screen.
      if (now - p.born > LIFE * 0.8 || p.y > H * 0.96 || p.x < -30 || p.x > W + 30) {
        Object.assign(p, spawn(now));
      }
    }
    ctx.clearRect(0, 0, W, H);
    for (const s of stamps) {
      if (!s) continue;
      const age = (now - s.born) / LIFE;
      if (age >= 1) continue;
      // The strand holds its brightness for most of its life, then lets
      // go quickly — so a tentacle reads as one piece, eroding from the
      // top as its tip extends. Depth does the dissolving; a short
      // fade-in stops new dots from popping.
      const hold = Math.min(1, (1 - age) * 3);
      const arrive = Math.min(1, (now - s.born) / 250);
      const depth = 1 - Math.pow(Math.max(s.y, 0) / H, 1.35);
      ctx.globalAlpha = BASE_ALPHA * hold * arrive * depth;
      const taper = 1 - 0.35 * Math.max(s.y, 0) / H;           // strands thin with depth
      const d = (s.r * 2 + 4) * taper;
      ctx.drawImage(sprite, s.x - d / 2, s.y - d / 2, d, d);
    }
    ctx.globalAlpha = 1;
    if (running) raf = requestAnimationFrame(step);
  }

  function start() {
    if (running) return;
    running = true; last = performance.now();
    raf = requestAnimationFrame(step);
  }
  function stop() { running = false; cancelAnimationFrame(raf); }

  size();
  addEventListener('resize', () => { stop(); size(); settled(); start(); });

  // Fast-forward the sim so full-length tentacles hang on first sight.
  function settled() {
    const now = performance.now();
    for (let i = 0; i < 1600; i++) stepOnce(now - (1599 - i) * 16);
  }
  function stepOnce(fake) {
    const dt = 16 / 1000; t = fake;
    for (const p of particles) {
      if (fake < p.born) continue;
      const a = angle(p);
      p.x += Math.cos(a) * p.speed * dt;
      p.y += Math.sin(a) * p.speed * dt;
      p.trail += p.speed * dt;
      if (p.trail > STEP) { p.trail = 0; stamps[head % CAP] = { x: p.x, y: p.y, r: p.r * (0.88 + Math.random() * 0.24), born: fake }; head++; }
      if (fake - p.born > LIFE * 0.8 || p.y > H * 0.96 || p.x < -30 || p.x > W + 30) {
        Object.assign(p, spawn(fake));
      }
    }
  }

  if (reduced) {
    // One quiet, already-sunk frame; nothing moves.
    settled();
    last = performance.now(); running = false;
    step(performance.now());
  } else {
    settled();
    new IntersectionObserver((entries) => {
      entries.some((e) => e.isIntersecting) ? start() : stop();
    }, { threshold: 0.02 }).observe(sea);
    document.addEventListener('visibilitychange', () => {
      document.hidden ? stop() : start();
    });
  }
}

/* --- The writable page: today's date, and type that settles as you write ---- */
/* Same register as the app (search bar fits 42→17px); here the written
   type starts large and steps down as the entry grows, exactly the
   feeling of the app's living write surface. */

const tryPage = document.getElementById('try-page');
if (tryPage) {
  const day = document.getElementById('page-day');
  const date = document.getElementById('page-date');
  const write = document.getElementById('page-write');
  const hint = document.getElementById('page-hint');

  const now = new Date();
  day.textContent = now.toLocaleDateString('en-US', { weekday: 'long', month: 'long', day: 'numeric' });
  date.textContent = now.toLocaleDateString('en-US', { month: 'long', day: 'numeric', year: 'numeric' });

  const SIZES = [[0, 26], [45, 23], [100, 20], [170, 18], [260, 17]];
  write.addEventListener('input', () => {
    hint.classList.add('gone');
    const len = write.textContent.length;
    let size = SIZES[0][1];
    for (const [at, px] of SIZES) if (len >= at) size = px;
    write.style.fontSize = size + 'px';
  });
  write.addEventListener('focus', () => hint.classList.add('gone'));
  tryPage.addEventListener('click', () => write.focus());
}

/* --- Week register: seven dots, a day fills at a time, once ----------------- */

const week = document.getElementById('week-reg');
if (week) {
  const dots = [...week.children];
  const writtenPattern = [0, 1, 3, 4, 6];   // the honest week: gaps included
  const TODAY = 4;

  onceInView(week, (instant) => {
    writtenPattern.forEach((i, order) => {
      setTimeout(() => {
        dots[i].classList.add('filled');
        if (i === TODAY) dots[i].classList.add('today');
      }, instant ? 0 : 550 * (order + 1));
    });
  });
}

/* --- Month matrix: draws itself once; recurring days echo twice, then rest --- */

const matrix = document.getElementById('matrix');
if (matrix) {
  const DAYS = 35;
  const written = new Set([0, 1, 3, 6, 7, 8, 10, 13, 14, 16, 17, 20, 22, 23, 24, 27, 29, 30, 32, 34]);
  const recurring = [3, 10, 17, 24];   // the thread the reviews would find
  const dots = [];
  for (let i = 0; i < DAYS; i++) {
    const d = document.createElement('div');
    d.className = 'dot';
    if (written.has(i)) d.classList.add('lit');
    matrix.appendChild(d);
    dots.push(d);
  }

  onceInView(matrix, (instant) => {
    dots.forEach((d, i) => {
      setTimeout(() => {
        d.classList.add('on');
        if (i === DAYS - 1 && !instant) {
          setTimeout(() => recurring.forEach((r) => dots[r].classList.add('echo')), 700);
        }
      }, instant ? 0 : 55 * i);
    });
  });
}
