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
