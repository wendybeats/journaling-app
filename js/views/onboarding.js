// First launch: the four-screen tutorial, the account moment ("Keep your
// notebook."), then the trial moment ("A week on us.") — Vellum is paid,
// one week free, no freemium. Shows exactly once; replay lives in the
// footer. iCloud/StoreKit are mocked in the prototype — buttons record
// the chosen state. Copy and sequence per docs/vellum-stage2-plan.md.

import { el, reducedMotion, runSequence } from './sequence.js';

const ONBOARDED_KEY = 'vellum.onboarded.v1';
const ACCOUNT_KEY = 'vellum.account.v1';
const TRIAL_KEY = 'vellum.trial.v1';

export function isOnboarded() {
  try {
    return Boolean(localStorage.getItem(ONBOARDED_KEY));
  } catch {
    return true;
  }
}

function markOnboarded() {
  localStorage.setItem(ONBOARDED_KEY, '1');
}

function setAccountMode(mode) {
  localStorage.setItem(ACCOUNT_KEY, mode);
}

const TUTORIAL_PAGES = 4;

/** Literal Vellum dots as the page indicator — the habit metaphor,
 *  taught silently before a word about it is read. */
function progressDots(active) {
  const row = el('div', 'onboard-progress');
  for (let i = 0; i < TUTORIAL_PAGES; i++) {
    const dot = el('span', 'dot');
    if (i === active) dot.classList.add('filled');
    row.appendChild(dot);
  }
  return row;
}

/** The reflections motif — the recap's overlapping circles, small. */
function circlesGlyph() {
  const c = el('div', 'recap-circles onboard-circles');
  c.append(el('div', 'recap-circle-ring'), el('div', 'recap-circle-fill'));
  return c;
}

/** The one animated moment: a month of dots filling in, one by one. */
function demoGrid() {
  const card = el('section', 'grid-card onboard-grid-card');
  const grid = el('div', 'dot-grid');
  const filled = new Set([1, 3, 4, 8, 10, 11, 15, 17, 20, 22, 23, 26]);
  const dots = [];
  for (let i = 0; i < 28; i++) {
    const cell = el('span', 'dot-cell');
    const dot = el('span', 'dot');
    if (filled.has(i)) {
      dot.classList.add('filled', 'recap-pending');
      dots.push(dot);
    }
    cell.appendChild(dot);
    grid.appendChild(cell);
  }
  card.appendChild(grid);
  return { card, dots };
}

export function showOnboarding() {
  runSequence(({ close, setControls, jump }) => {
    const ACCOUNT_INDEX = 4;

    function tutorialSlide(index, title, body, { extra, cta } = {}) {
      return (advance) => {
        const slide = el('div');

        const skip = el('button', 'type-meta-small onboard-skip', 'Skip');
        skip.type = 'button';
        skip.addEventListener('click', () => jump(ACCOUNT_INDEX));
        slide.appendChild(skip);

        const center = el('div', 'recap-center');
        center.appendChild(el('h1', 'type-display recap-big', title));
        center.appendChild(el('p', 'onboard-body', body));
        if (extra) center.appendChild(extra.card ?? extra);
        if (cta) {
          const btn = el('button', 'type-meta recap-continue onboard-begin', cta);
          btn.type = 'button';
          btn.addEventListener('click', advance);
          center.appendChild(btn);
        }
        slide.appendChild(center);
        slide.appendChild(progressDots(index));

        return {
          slide,
          run() {
            setControls({ skip: advance });
            if (extra?.dots) {
              const timers = [];
              if (reducedMotion()) {
                extra.dots.forEach((d) => d.classList.remove('recap-pending'));
              } else {
                extra.dots.forEach((d, i) => {
                  timers.push(setTimeout(() => d.classList.remove('recap-pending'), 700 + i * 180));
                });
              }
              return () => timers.forEach(clearTimeout);
            }
            return null;
          },
        };
      };
    }

    function accountSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center onboard-account');

      center.appendChild(el('h1', 'type-display recap-big', 'Keep your notebook.'));
      center.appendChild(el('p', 'onboard-body',
        'Your writing stays in your private storage — no profile, no analytics, nothing read by anyone but you.'));

      // Path A (decided): recovery through the user's own iCloud — no
      // account system, no server. One button.
      const backup = el('button', 'account-btn primary', 'Back up with iCloud');
      backup.type = 'button';
      backup.addEventListener('click', () => { setAccountMode('icloud'); advance(); });
      const stack = el('div', 'account-stack');
      stack.append(backup);
      center.appendChild(stack);

      const skip = el('button', 'type-meta account-skip', 'Continue without an account →');
      skip.type = 'button';
      skip.addEventListener('click', () => { setAccountMode('local'); advance(); });
      center.appendChild(skip);
      center.appendChild(el('div', 'type-meta-small account-skip-note', 'Saved on this device only'));

      slide.appendChild(center);
      return { slide, run: () => (setControls(null), null) };
    }

    // The trial moment — paid with one free week, no freemium, no skip.
    // Prices are placeholders until the pre-submission pricing pass.
    function trialSlide() {
      const slide = el('div');
      const center = el('div', 'recap-center onboard-account');

      center.appendChild(el('h1', 'type-display recap-big', 'A week on us.'));
      center.appendChild(el('p', 'onboard-body',
        'Every page, every reflection, free for seven days. After that, Vellum is $29.99 a year — about the price of one good paper notebook.'));

      const start = el('button', 'account-btn primary', 'Start my free week');
      start.type = 'button';
      start.addEventListener('click', () => {
        localStorage.setItem(TRIAL_KEY, JSON.stringify({ startedAt: Date.now() }));
        close(true);
      });
      const stack = el('div', 'account-stack');
      stack.append(start);
      center.appendChild(stack);

      center.appendChild(el('div', 'type-meta-small trial-terms',
        '$29.99/year after trial · cancel anytime'));

      const restore = el('button', 'type-meta-small trial-restore', 'Restore purchase');
      restore.type = 'button';
      restore.addEventListener('click', () => {
        localStorage.setItem(TRIAL_KEY, JSON.stringify({ restored: true }));
        close(true);
      });
      center.appendChild(restore);

      slide.appendChild(center);
      return { slide, run: () => (setControls(null), null) };
    }

    return [
      tutorialSlide(0, 'Attention is a practice.',
        'A few honest lines a day change how the day sits with you. Not therapy, not productivity — just noticing, kept somewhere quiet.'),
      tutorialSlide(1, 'This is Vellum.',
        'Open it, write or speak, close it. What you write stays written — no edits, no deletions; the point is to commit. Each day you write, a dot fills in.',
        { extra: demoGrid() }),
      tutorialSlide(2, 'Reflect, if you wish.',
        'Each week, month, and year, Vellum can reflect your writing back to you — the topics and words you returned to most. Optional, always skippable, only ever yours.',
        { extra: circlesGlyph() }),
      tutorialSlide(3, 'Go forth.', 'Today’s page is ready.', { cta: 'Begin' }),
      accountSlide,
      trialSlide,
    ];
  }, {
    onDismiss() {
      markOnboarded();
      // Land on Today, cursor ready
      setTimeout(() => document.querySelector('.writing textarea')?.focus({ preventScroll: true }), 450);
    },
  });
}
