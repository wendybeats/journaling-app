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
const seamDot = document.querySelector('.seam-dot');
const closeDot = document.querySelector('.closing .mark-dot');
if (deepSection && heroDot && seamDot && closeDot && !reduced) {
  let dotDocY = 0, closeDocY = 0, fullScroll = 1, maxR = 0;
  let exitStart = 1e9, exitWin = 1, diveTicking = false;

  function measure() {
    // Undo any previous surgery before measuring fresh.
    deepSection.style.marginTop = '';
    deepSection.style.paddingTop = '';
    deepSection.style.marginBottom = '';
    deepSection.style.paddingBottom = '';
    deepSection.style.zIndex = '';
    seamDot.style.top = '';
    heroDot.style.visibility = '';
    deepSection.style.clipPath = 'none';

    const d = heroDot.getBoundingClientRect();
    const c = closeDot.getBoundingClientRect();
    const s = deepSection.getBoundingClientRect();
    const origTop = s.top + scrollY;
    const origBottom = s.bottom + scrollY;
    dotDocY = d.top + scrollY + d.height / 2;
    closeDocY = c.top + scrollY + c.height / 2;
    // Raise the box to the page top AND drop it past the closing dot
    // (padding compensated both ways, content never moves), so the clip
    // circle can be a full disc at either end — swallowing the hero on
    // the way in, closing into the ending's dot on the way out.
    const cs = getComputedStyle(deepSection);
    const ext = Math.max(0, closeDocY + 40 - origBottom);
    deepSection.style.marginTop = (parseFloat(cs.marginTop) - origTop) + 'px';
    deepSection.style.paddingTop = (parseFloat(cs.paddingTop) + origTop) + 'px';
    deepSection.style.paddingBottom = (parseFloat(cs.paddingBottom) + ext) + 'px';
    deepSection.style.marginBottom = (parseFloat(cs.marginBottom) - ext) + 'px';
    deepSection.style.zIndex = '1';            // the ink covers the ending until it closes
    seamDot.style.top = (dotDocY - 8) + 'px';  // the seam dot takes the hero dot's place
    heroDot.style.visibility = 'hidden';

    // An extreme plunge: the window is deliberately short — the ink
    // fully owns the screen well before the section's own content
    // arrives, so there is never a long ride inside a floating ring.
    fullScroll = Math.max(200, (origTop - innerHeight * 0.12) * 0.62);
    // The circle's center sticks 42% down the viewport once scrolling
    // begins, so the mouth holds its place on screen while the page
    // falls into it — the viewport is fully covered from that point.
    maxR = Math.hypot(innerWidth / 2, innerHeight * 0.62) * 1.06;
    // The reverse dive: begins as the closing dot nears the fold and
    // finishes with the disc landing on it. The surgery above can shift
    // the ending slightly, so the target is re-measured after it — and
    // the landing must arrive before the page runs out of scroll.
    closeDocY = closeDot.getBoundingClientRect().top + scrollY + closeDot.getBoundingClientRect().height / 2;
    exitWin = innerHeight * 0.55;
    const maxScroll = document.documentElement.scrollHeight - innerHeight;
    const exitEnd = Math.min(closeDocY - innerHeight * 0.30, maxScroll - 60);
    exitStart = exitEnd - exitWin;
  }

  function dive() {
    diveTicking = false;
    const stickDoc = scrollY + innerHeight * 0.42;
    if (scrollY > exitStart) {
      // Surfacing: the ink collapses into the ending's dot — the entry,
      // in reverse. Smooth in, decisive landing.
      const q = Math.min(1, (scrollY - exitStart) / exitWin);
      const e = q * q * (3 - 2 * q);                 // smoothstep
      const centerDocY = stickDoc + (closeDocY - stickDoc) * e;
      const R = 8 + (maxR - 8) * (1 - Math.pow(e, 1.15));
      deepSection.style.clipPath = `circle(${R}px at 50% ${centerDocY}px)`;
      return;
    }
    const p = Math.min(1, Math.max(0, scrollY / fullScroll));
    const centerDocY = Math.max(dotDocY, stickDoc);  // on the dot until it would rise past the line
    // Past the plunge the clip stays at full cover (never 'none' — the
    // box now overhangs the ending, and the exit needs the same circle).
    const R = 8 + Math.pow(p, 1.5) * maxR;
    deepSection.style.clipPath = `circle(${R}px at 50% ${centerDocY}px)`;
  }

  measure(); dive();
  // Font loading reflows everything below the headline — re-anchor both
  // ends of the dive once metrics are final.
  if (document.fonts && document.fonts.ready) {
    document.fonts.ready.then(() => { measure(); dive(); });
  }
  addEventListener('load', () => { measure(); dive(); });
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
  const DOT = '#2D2925';                      // between glint and graphic — visible on a
                                              // phone panel, still well inside the dark
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
