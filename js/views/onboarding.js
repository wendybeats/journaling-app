// First launch: the three-screen tutorial (why → what → go) followed by
// the account moment ("Keep your notebook."). Shows exactly once; replay
// lives in the footer. Copy and sequence per docs/vellum-stage2-plan.md.
// Sign-in is mocked in the prototype — buttons record the chosen mode.

import { el, reducedMotion, runSequence } from './sequence.js';

const ONBOARDED_KEY = 'vellum.onboarded.v1';
const ACCOUNT_KEY = 'vellum.account.v1';

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

/** Three literal Vellum dots as the page indicator — the habit metaphor,
 *  taught silently before a word about it is read. */
function progressDots(active) {
  const row = el('div', 'onboard-progress');
  for (let i = 0; i < 3; i++) {
    const dot = el('span', 'dot');
    if (i === active) dot.classList.add('filled');
    row.appendChild(dot);
  }
  return row;
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
    const ACCOUNT_INDEX = 3;

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

    function accountSlide() {
      const slide = el('div');
      const center = el('div', 'recap-center onboard-account');

      center.appendChild(el('h1', 'type-display recap-big', 'Keep your notebook.'));
      center.appendChild(el('p', 'onboard-body',
        'Your writing stays in your private storage — no profile, no analytics, nothing read by anyone but you.'));

      function providerButton(label, mode, primary) {
        const btn = el('button', `account-btn${primary ? ' primary' : ''}`, label);
        btn.type = 'button';
        btn.addEventListener('click', () => { setAccountMode(mode); close(true); });
        return btn;
      }
      const stack = el('div', 'account-stack');
      stack.append(
        providerButton('Continue with Apple', 'apple', true),
        providerButton('Continue with Google', 'google', false),
      );
      center.appendChild(stack);

      const skip = el('button', 'type-meta account-skip', 'Continue without an account →');
      skip.type = 'button';
      skip.addEventListener('click', () => { setAccountMode('local'); close(true); });
      center.appendChild(skip);
      center.appendChild(el('div', 'type-meta-small account-skip-note', 'Saved on this device only'));

      slide.appendChild(center);
      return { slide, run: () => (setControls(null), null) };
    }

    return [
      tutorialSlide(0, 'Attention is a practice.',
        'A few honest lines a day change how the day sits with you. Not therapy, not productivity — just noticing, kept somewhere quiet.'),
      tutorialSlide(1, 'This is Vellum.',
        'Open it, write or speak, close it. Each day you write, a dot fills in. That’s the whole system.',
        { extra: demoGrid() }),
      tutorialSlide(2, 'Go forth.', 'Today’s page is ready.', { cta: 'Begin' }),
      accountSlide,
    ];
  }, {
    onDismiss() {
      markOnboarded();
      // Land on Today, cursor ready
      setTimeout(() => document.querySelector('.writing textarea')?.focus({ preventScroll: true }), 450);
    },
  });
}
