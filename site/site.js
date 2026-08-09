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
    // The sea rides the band, not the box: anchor the canvas at the dot
    // (where the ink begins) so strands live behind the section's content
    // and the animation keeps running while that band is on screen.
    const seaEl = document.getElementById('deep-sea');
    if (seaEl) seaEl.style.top = (dotDocY - 8) + 'px';

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

  // While the ink owns the screen, the browser chrome follows it in —
  // Safari's status-bar scrim samples the page's theme/background, and
  // a bone scrim over the deep reads as a light leak.
  const themeMeta = document.querySelector('meta[name="theme-color"]');
  let immersed = null;
  function setImmersed(on) {
    if (on === immersed) return;
    immersed = on;
    if (themeMeta) themeMeta.setAttribute('content', on ? '#1A1A1A' : '#E8E6E1');
    document.documentElement.style.backgroundColor = on ? '#1A1A1A' : '';
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
      setImmersed(q < 0.3);
      return;
    }
    const p = Math.min(1, Math.max(0, scrollY / fullScroll));
    const centerDocY = Math.max(dotDocY, stickDoc);  // on the dot until it would rise past the line
    // Past the plunge the clip stays at full cover (never 'none' — the
    // box now overhangs the ending, and the exit needs the same circle).
    const R = 8 + Math.pow(p, 1.5) * maxR;
    deepSection.style.clipPath = `circle(${R}px at 50% ${centerDocY}px)`;
    setImmersed(p >= 0.9);
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
  let rz, diveW = innerWidth;
  addEventListener('resize', () => {
    clearTimeout(rz);
    rz = setTimeout(() => {
      if (Math.abs(innerWidth - diveW) < 2) { dive(); return; }  // URL-bar twitch, not a resize
      diveW = innerWidth;
      measure(); dive();
    }, 120);
  });
}

/* --- The deep sea: dot strands, tied to the scroll --------------------------- */
/* No clock, no idle work: each strand is a closed-form swaying path in a
   lane, and the scroll position decides how far down it has traveled
   (with per-strand parallax). Dots fade in near the surface, ramp along
   the tail, thin and dissolve with depth — so strands never pop in at a
   line. Redraws only while scrolling; costs nothing at rest. */

const sea = document.getElementById('deep-sea');
if (sea) {
  const ctx = sea.getContext('2d');
  const DOT = '#332F2B';                     // hairline-dk — the unfilled-dot register
  const BASE_ALPHA = 0.85;
  const STEP = 8;                            // px between dots along a strand
  const TAIL = 88;                           // dots per strand — long tentacles
  let W = 0, H = 0, dpr = 1, sprite = null, strands = [];

  function size() {
    const rect = sea.getBoundingClientRect();
    dpr = Math.min(devicePixelRatio || 1, 2);
    W = rect.width; H = rect.height;
    sea.width = Math.round(W * dpr);
    sea.height = Math.round(H * dpr);
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    sprite = document.createElement('canvas');
    const sp = 10 * dpr;
    sprite.width = sprite.height = sp;
    const sc = sprite.getContext('2d');
    const g = sc.createRadialGradient(sp / 2, sp / 2, 0, sp / 2, sp / 2, sp / 2);
    g.addColorStop(0, DOT); g.addColorStop(0.55, DOT); g.addColorStop(1, 'transparent');
    sc.fillStyle = g;
    sc.beginPath(); sc.arc(sp / 2, sp / 2, sp / 2, 0, Math.PI * 2); sc.fill();
    const n = W < 760 ? 12 : 30;
    strands = Array.from({ length: n }, (_, i) => ({
      x0: (i + 0.15 + Math.random() * 0.7) * (W / n),  // jittered lanes
      phase: Math.random() * Math.PI * 2,
      rate: 0.24 + Math.random() * 0.22,               // scroll parallax factor
      base: Math.random() * (H + 600),
      cycle: H + 400 + Math.random() * 500,            // staggered rebirths
      r: 0.9 + Math.random() * 1.5,
      jit: Array.from({ length: TAIL }, () => 0.86 + Math.random() * 0.28),
    }));
    draw();
  }

  // A tentacle's sway, in closed form — no integration, any depth cheap.
  function xAt(st, s) {
    return st.x0 + Math.sin(s * 0.006 + st.phase) * 34
                 + Math.sin(s * 0.0115 + st.phase * 1.7) * 20;
  }

  function draw() {
    ctx.clearRect(0, 0, W, H);
    for (const st of strands) {
      let head = (st.base + scrollY * st.rate) % st.cycle;
      if (head < 0) head += st.cycle;
      for (let k = 0; k < TAIL; k++) {
        const s = head - k * STEP;
        if (s < 0 || s > H) continue;
        const tail = 1 - (k / TAIL) * 0.72;            // ramp with a floor — tails stay present
        const surface = Math.min(1, s / 120);          // fade in below the surface
        const depth = Math.max(0, 1 - Math.pow(s / H, 2) * 0.92);
        ctx.globalAlpha = BASE_ALPHA * tail * surface * depth;
        const d = (st.r * 2 + 4) * (1 - 0.35 * s / H) * st.jit[k];
        ctx.drawImage(sprite, xAt(st, s) - d / 2, s - d / 2, d, d);
      }
    }
    ctx.globalAlpha = 1;
  }

  let seaTick = false;
  size();
  if (!reduced) {
    addEventListener('scroll', () => {
      if (!seaTick) { seaTick = true; requestAnimationFrame(() => { seaTick = false; draw(); }); }
    }, { passive: true });
  }
  let seaRz, seaW = innerWidth;
  addEventListener('resize', () => {
    clearTimeout(seaRz);
    seaRz = setTimeout(() => {
      // iOS fires resize for URL-bar height changes ~every flick; only a
      // real width change (rotation, window resize) reshuffles the sea.
      if (Math.abs(innerWidth - seaW) < 2) { draw(); return; }
      seaW = innerWidth;
      size();
    }, 140);
  });
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
