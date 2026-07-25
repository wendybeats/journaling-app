// endpaper.space — the living graphics. Dots only, in the app's own
// registers: the week filling day by day, the month matrix drawing itself,
// recurring days echoing. Everything degrades to a static filled state
// under prefers-reduced-motion.

const reduced = matchMedia('(prefers-reduced-motion: reduce)').matches;

/* --- Week register: seven dots, a day fills at a time ---------------------- */

const week = document.getElementById('week-reg');
if (week) {
  const dots = [...week.children];
  const writtenPattern = [0, 1, 3, 4, 6];   // the honest week: gaps included
  const TODAY = 4;

  if (reduced) {
    writtenPattern.forEach((i) => dots[i].classList.add('filled'));
    dots[TODAY].classList.add('today');
  } else {
    let step = 0;
    setInterval(() => {
      const phase = step % (writtenPattern.length + 3);   // pause between loops
      if (phase === 0) {
        dots.forEach((d) => d.classList.remove('filled', 'today'));
      } else if (phase <= writtenPattern.length) {
        const i = writtenPattern[phase - 1];
        dots[i].classList.add('filled');
        if (i === TODAY) dots[i].classList.add('today');
      }
      step++;
    }, 750);
  }
}

/* --- Month matrix: draws itself on scroll; recurring days echo -------------- */

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

  const reveal = () => {
    dots.forEach((d, i) => {
      setTimeout(() => {
        d.classList.add('on');
        if (i === DAYS - 1) {
          setTimeout(() => recurring.forEach((r) => dots[r].classList.add('echo')), 700);
        }
      }, reduced ? 0 : 55 * i);
    });
  };

  if (reduced) {
    reveal();
  } else {
    new IntersectionObserver((entries, obs) => {
      if (entries.some((e) => e.isIntersecting)) {
        reveal();
        obs.disconnect();
      }
    }, { threshold: 0.4 }).observe(matrix);
  }
}
