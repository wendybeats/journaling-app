// Monthly recap — a full-screen slide sequence in the dot language:
// arrival circles → the month drawing itself dot by dot with its numbers →
// recurring ideas → your word → challenges → "Reflect & start anew".
// Chapter slides open with a huge decorative intertitle. Built on the
// shared sequence machinery (sequence.js); slides with nothing honest to
// show remove themselves.

import { fromKey, monthName } from '../format.js';
import { monthGridBody } from '../dots.js';
import { markSeen } from '../reflect.js';
import { el, reducedMotion, countdownBar, intertitle, quoteNode, runSequence } from './sequence.js';

const DOT_STAGGER_MS = 60;
const STAT_STAGGER_MS = 180;
const INTRO_MS = 4500;
const STATS_MS = 6000;
const TOPIC_MS = 4500;
const TONE_MS = 4500;

function dayStamp(key) {
  const d = fromKey(key);
  return `${monthName(d.getMonth())} ${d.getDate()}`;
}

export function showMonthlyRecap(signal, { onDone } = {}) {
  runSequence(({ close, setControls }) => {
    // --- Slide 1: arrival ---
    function introSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const circles = el('div', 'recap-circles');
      circles.append(el('div', 'recap-circle-ring'), el('div', 'recap-circle-fill'));
      center.append(circles, el('h2', 'type-title', 'Reflections – Your month'));
      slide.appendChild(center);

      const skip = el('button', 'type-meta-small recap-skip', 'Not interested');
      skip.type = 'button';
      skip.addEventListener('click', () => close(true));

      const bar = countdownBar(INTRO_MS, advance);
      slide.append(bar.el, skip);
      return {
        slide,
        run() {
          bar.start();
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          return () => bar.cancel();
        },
      };
    }

    // --- Slide 2: the month, drawn dot by dot, then its numbers ---
    function statsSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center recap-stats');

      const title = el('h2', 'type-title recap-reveal', `${monthName(signal.month)} ${signal.year}`);
      const grid = monthGridBody(signal.year, signal.month);
      grid.classList.add('recap-grid');

      const stats = [
        [String(signal.days), 'days written'],
        [signal.words.toLocaleString(), 'words'],
        [String(signal.longestRun), 'longest run'],
      ].map(([num, label]) => {
        const col = el('div', 'recap-stat recap-reveal');
        col.append(el('span', 'recap-stat-number', num), el('span', 'type-meta-small', label));
        return col;
      });
      const statsRow = el('div', 'recap-stats-row');
      statsRow.append(...stats);

      center.append(title, grid, statsRow);
      slide.appendChild(center);
      const bar = countdownBar(STATS_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          const timers = [];
          const dots = [...slide.querySelectorAll('.dot.filled')];
          for (const d of dots) d.classList.add('recap-pending');
          const reveals = [title, ...stats];

          if (reducedMotion()) {
            dots.forEach((d) => d.classList.remove('recap-pending'));
            reveals.forEach((r) => r.classList.add('on'));
            bar.start();
          } else {
            dots.forEach((d, i) => {
              timers.push(setTimeout(() => d.classList.remove('recap-pending'), 200 + i * DOT_STAGGER_MS));
            });
            const afterDots = 300 + dots.length * DOT_STAGGER_MS;
            reveals.forEach((r, i) => {
              timers.push(setTimeout(() => r.classList.add('on'), afterDots + i * STAT_STAGGER_MS));
            });
            timers.push(setTimeout(() => bar.start(), afterDots + reveals.length * STAT_STAGGER_MS));
          }
          return () => { timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 3: recurring ideas, one topic at a time ---
    function topicsSlide(advance) {
      const slide = el('div');
      const holder = el('div', 'recap-center recap-topic-holder');
      slide.appendChild(holder);
      const barHolder = el('div', 'recap-bar-holder');
      slide.appendChild(barHolder);

      return {
        slide,
        run() {
          const timers = [];
          let bar = null;
          holder.style.visibility = 'hidden';

          let started = false;
          function startContent() {
            if (started) return;
            started = true;
            holder.style.visibility = '';
            showTopic(0);
          }
          const cancelInter = intertitle(slide, 'Recurring ideas', startContent);
          setControls({ skip: () => { cancelInter(); startContent(); } });

          function showTopic(i) {
            if (i >= signal.topics.length) { advance(); return; }
            timers.forEach(clearTimeout);
            timers.length = 0;
            bar?.cancel();
            const topic = signal.topics[i];
            holder.innerHTML = '';
            barHolder.innerHTML = '';
            setControls({
              skip: () => showTopic(i + 1),
              pause: () => bar?.pause(),
              resume: () => bar?.resume(),
            });

            holder.appendChild(el('div', 'type-meta-small', `Recurring · ${i + 1} of ${signal.topics.length}`));
            holder.appendChild(el('div', 'recap-topic-word', `“${topic.word}”`));
            holder.appendChild(el('div', 'type-meta', `${topic.days} days`));

            const quotes = topic.quotes.map((q) => quoteNode(q.text, dayStamp(q.day)));
            for (const q of quotes) {
              q.classList.add('recap-reveal');
              holder.appendChild(q);
            }

            const enterMs = reducedMotion() ? 0 : 350;
            quotes.forEach((q, qi) => {
              timers.push(setTimeout(() => q.classList.add('on'), enterMs + qi * 250));
            });
            const settled = enterMs + quotes.length * 250;
            timers.push(setTimeout(() => {
              bar = countdownBar(TOPIC_MS, () => showTopic(i + 1));
              barHolder.appendChild(bar.el);
              bar.start();
            }, settled));
          }

          return () => { cancelInter(); timers.forEach(clearTimeout); bar?.cancel(); };
        },
      };
    }

    // --- Slide 4: your word (tone) ---
    function toneSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const sentence = el('p', 'recap-tone recap-reveal',
        `Your word was “${signal.tone.word}” — it appeared ${signal.tone.count} times.`);
      center.appendChild(sentence);
      slide.appendChild(center);
      const bar = countdownBar(TONE_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          const timers = [];
          let started = false;
          function startContent() {
            if (started) return;
            started = true;
            timers.push(setTimeout(() => sentence.classList.add('on'), 50));
            timers.push(setTimeout(() => bar.start(), 450));
            setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          }
          const cancelInter = intertitle(slide, 'Your Word', startContent);
          setControls({ skip: () => { cancelInter(); startContent(); } });
          return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 5: challenges (what seemed difficult) ---
    function challengesSlide(advance) {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const reveals = [];
      const label = el('div', 'type-meta-small recap-reveal', 'What seemed difficult');
      center.appendChild(label);
      reveals.push(label);
      for (const q of signal.difficult.slice(0, 2)) {
        const node = quoteNode(q.text, dayStamp(q.day));
        node.classList.add('recap-reveal');
        center.appendChild(node);
        reveals.push(node);
      }
      slide.appendChild(center);
      const bar = countdownBar(TONE_MS, advance);
      slide.appendChild(bar.el);

      return {
        slide,
        run() {
          const timers = [];
          let started = false;
          function startContent() {
            if (started) return;
            started = true;
            reveals.forEach((r, i) => timers.push(setTimeout(() => r.classList.add('on'), 50 + i * 250)));
            timers.push(setTimeout(() => bar.start(), 50 + reveals.length * 250));
            setControls({ skip: advance, pause: bar.pause, resume: bar.resume });
          }
          const cancelInter = intertitle(slide, 'Challenges', startContent);
          setControls({ skip: () => { cancelInter(); startContent(); } });
          return () => { cancelInter(); timers.forEach(clearTimeout); bar.cancel(); };
        },
      };
    }

    // --- Slide 6: reflect & start anew ---
    function outroSlide() {
      const slide = el('div');
      const center = el('div', 'recap-center');
      const next = (signal.month + 1) % 12;
      center.appendChild(el('div', 'type-meta', `${monthName(signal.month)} → ${monthName(next)}`));
      center.appendChild(el('h1', 'type-display recap-big', 'Reflect & start anew'));
      slide.appendChild(center);

      const cta = el('button', 'type-meta recap-continue', 'Continue');
      cta.type = 'button';
      cta.addEventListener('click', () => close(true));
      slide.appendChild(cta);
      return { slide, run: () => (setControls(null), null) };
    }

    // Slides with nothing honest to show remove themselves
    const builders = [introSlide, statsSlide];
    if (signal.topics.length) builders.push(topicsSlide);
    if (signal.tone) builders.push(toneSlide);
    if (signal.difficult.length) builders.push(challengesSlide);
    builders.push(outroSlide);
    return builders;
  }, {
    onDismiss(seen) {
      if (seen) markSeen(signal);
      onDone?.();
    },
  });
}
