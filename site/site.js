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

/* --- The deep sea: dot trails sinking into the ink -------------------------- */
/* Particles drift down a slow flow field from the seam, stamping faint
   bone dots as they go; stamps age out, and everything dissipates with
   depth — trails disappearing into the ocean. Runs only while the
   section is on screen. Reduced motion gets one settled, static frame. */

const sea = document.getElementById('deep-sea');
if (sea) {
  const ctx = sea.getContext('2d');
  const DOT = '#EFEDE8';                      // bone-raised, from the token sheet
  const LIFE = 3200;                          // stamp lifetime, ms
  const BASE_ALPHA = 0.12;                    // never brighter than this
  let W = 0, H = 0, dpr = 1, sprite = null;
  let particles = [], stamps = [], head = 0, CAP = 1400;
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
    const n = W < 760 ? 20 : 34;
    particles = Array.from({ length: n }, spawn);
    stamps = []; head = 0;
  }

  function spawn() {
    return {
      x: Math.random() * W,
      y: -20 - Math.random() * 60,
      phase: Math.random() * Math.PI * 2,
      speed: 22 + Math.random() * 26,          // px/s — a slow sink
      trail: 0,
      r: 1.1 + Math.random() * 1.3,
    };
  }

  // Mostly downward, swaying up to ~60° either side — layered sines make
  // neighboring paths curl together into loose, changing threads.
  function angle(p) {
    return Math.PI / 2
      + Math.sin(p.y * 0.005 + t * 0.00030 + p.phase) * 1.0
      + Math.sin(p.x * 0.007 - t * 0.00021) * 0.6;
  }

  function step(now) {
    const dt = Math.min(now - last, 50) / 1000;
    last = now; t = now;
    for (const p of particles) {
      const a = angle(p);
      p.x += Math.cos(a) * p.speed * dt;
      p.y += Math.sin(a) * p.speed * dt;
      p.trail += p.speed * dt;
      if (p.trail > 11) {                      // a dot every ~11px of travel
        p.trail = 0;
        stamps[head % CAP] = { x: p.x, y: p.y, r: p.r, born: now };
        head++;
      }
      if (p.y > H * 0.94 || p.x < -30 || p.x > W + 30) Object.assign(p, spawn());
    }
    ctx.clearRect(0, 0, W, H);
    for (const s of stamps) {
      if (!s) continue;
      const age = (now - s.born) / LIFE;
      if (age >= 1) continue;
      const depth = 1 - Math.pow(Math.max(s.y, 0) / H, 1.35);  // gone by the bottom
      ctx.globalAlpha = BASE_ALPHA * (1 - age) * depth;
      const d = s.r * 2 + 4;
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

  // Fast-forward the sim so the sea is already alive on first sight.
  function settled() {
    const now = performance.now();
    for (let i = 0; i < 360; i++) { last = now - (360 - i) * 16; running = false; stepOnce(now - (359 - i) * 16); }
  }
  function stepOnce(fake) {
    const dt = 16 / 1000; t = fake;
    for (const p of particles) {
      const a = angle(p);
      p.x += Math.cos(a) * p.speed * dt;
      p.y += Math.sin(a) * p.speed * dt;
      p.trail += p.speed * dt;
      if (p.trail > 11) { p.trail = 0; stamps[head % CAP] = { x: p.x, y: p.y, r: p.r, born: fake }; head++; }
      if (p.y > H * 0.94 || p.x < -30 || p.x > W + 30) Object.assign(p, spawn());
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
