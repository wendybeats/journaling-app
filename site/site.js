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

/* --- Only Human: the reflections motif drifts through one cycle -------------- */

const motif = document.getElementById('motif');
if (motif) {
  onceInView(motif, (instant) => {
    if (!instant) motif.classList.add('play');
  }, 0.6);
}
