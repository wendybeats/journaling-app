// Demo seed — visiting ?seed fills the log with plausible past entries so the
// archive and dot grids can be judged with real density. Dev tool only.

import { dayKey, replaceAll } from './store.js';
import { resetReflections, lastCompletedWeekStart } from './reflect.js';
import { resetReminder } from './views/reminder.js';

// The demo notebook is the pitch: a stranger should recognise their own
// week in it within one screen. So the threads are the ones most people
// actually carry — sleep, attention, the person they live with, money —
// written plainly and without resolution. Words recur on purpose: the
// reflection engine can only surface what repeats.
const SNIPPETS = [
  'Woke at four again with my jaw already clenched. Nothing was wrong. The body just decided it was time to worry.',
  'Third night falling asleep with the phone in my hand. That is not sleep, it is just lying down with the lights off.',
  'Sam said I have been somewhere else all week. I wanted to argue and could not, which is its own answer.',
  'Read the same paragraph four times and gave up. I used to be able to sit with a book for an hour.',
  'Worried about money in a way that has nothing to do with the number actually in the account.',
  'Anxious all morning about a meeting that lasted nine minutes and went fine.',
  'Put the phone in the other room for two hours and got more done than the whole day before it.',
  'Told my therapist I am fine and heard how fast I said it.',
  'Sam made coffee without asking and left it by the laptop. I noticed and did not say anything.',
  'Slept seven hours and woke up steady. One night does not prove anything, but I will take it.',
  'Checked my phone through most of dinner. Nobody said anything, which was worse than if they had.',
  'The thing I am avoiding takes twenty minutes. I have now spent four days not doing twenty minutes.',
  'Snapped at Sam about the dishes. It was never about the dishes.',
  'Enough.',
  'Money is fine this month. I still checked the balance four times.',
  'Focus came back for about ninety minutes this afternoon. I remember this feeling and I want more of it.',
  'Ran into an old coworker and performed being happy for eleven minutes. Exhausting in a way I could not explain after.',
  'Sam asked what I actually want this year and I gave an answer I have given before. It was not true then either.',
  'Left the phone charging in the kitchen overnight. Slept through until six.',
  'A quiet day, nothing to report. I notice that I do not entirely trust quiet days.',
  'Tired in a way that sleep does not fix. Naming it here so it is somewhere other than my chest.',
  'Why do I keep replaying what Sam said on Sunday?',
  'Am I anxious about the work, or about what people will decide about me because of it?',
  'Walked instead of taking the bus. Those twenty minutes were the only ones today that were mine.',
  'Steady today. Not happy exactly — steady. That seems like the thing to protect.',
  'Wrote the worry down and it got maybe ten percent smaller. Apparently that is the whole trick.',
];

// Small deterministic PRNG so the demo data is stable across reloads
function mulberry32(a) {
  return () => {
    a |= 0; a = (a + 0x6D2B79F5) | 0;
    let t = Math.imul(a ^ (a >>> 15), 1 | a);
    t = (t + Math.imul(t ^ (t >>> 7), 61 | t)) ^ t;
    return ((t ^ (t >>> 14)) >>> 0) / 4294967296;
  };
}

export function seedDemoData() {
  const rand = mulberry32(20260705);
  const data = {};
  const today = new Date();
  const start = new Date(today.getFullYear() - 1, 2, 1); // ~16 months back

  for (let d = new Date(start); d <= today; d.setDate(d.getDate() + 1)) {
    if (rand() > 0.62) continue; // imperfect habit — realistic density
    const count = rand() < 0.72 ? 1 : rand() < 0.85 ? 2 : 3;
    const key = dayKey(d);
    data[key] = [];
    for (let i = 0; i < count; i++) {
      const hour = i === 0 ? 6 + Math.floor(rand() * 4) : 12 + Math.floor(rand() * 10);
      const at = new Date(d.getFullYear(), d.getMonth(), d.getDate(), hour, Math.floor(rand() * 60)).getTime();
      // Real entries run a few paragraphs, not one line
      const paras = 2 + Math.floor(rand() * 2);
      const parts = [];
      for (let pIdx = 0; pIdx < paras; pIdx++) {
        parts.push(SNIPPETS[Math.floor(rand() * SNIPPETS.length)]);
      }
      data[key].push({ id: crypto.randomUUID(), at, text: [...new Set(parts)].join('\n\n') });
    }
    data[key].sort((a, b) => a.at - b.at);
  }

  // Guarantee the last completed week exercises the reflection surfaces:
  // at least 5 written days with substantive entries
  const weekStart = lastCompletedWeekStart(today);
  for (const offset of [0, 1, 2, 4, 5]) {
    const d = new Date(weekStart);
    d.setDate(weekStart.getDate() + offset);
    const key = dayKey(d);
    if ((data[key]?.length ?? 0) > 0) continue;
    const at = new Date(d.getFullYear(), d.getMonth(), d.getDate(), 7 + Math.floor(rand() * 3), Math.floor(rand() * 60)).getTime();
    const parts = new Set();
    while (parts.size < 3) parts.add(SNIPPETS[Math.floor(rand() * SNIPPETS.length)]);
    data[key] = [{ id: crypto.randomUUID(), at, text: [...parts].join('\n\n') }];
  }

  // Today is chosen, not rolled. It's the page every first impression and
  // every marketing shot is taken from, and the dice sometimes leave it
  // empty — so it carries two sections that show what the notebook is
  // actually about.
  const tKey = dayKey(today);
  const atToday = (h, m) =>
    new Date(today.getFullYear(), today.getMonth(), today.getDate(), h, m).getTime();
  data[tKey] = [
    { id: crypto.randomUUID(), at: atToday(7, 12),
      text: 'Woke at four again with my jaw already clenched. Nothing was wrong. The body just decided it was time to worry.\n\nThird night falling asleep with the phone in my hand. That is not sleep, it is just lying down with the lights off.' },
    { id: crypto.randomUUID(), at: atToday(9, 40),
      text: 'Sam said I have been somewhere else all week. I wanted to argue and could not, which is its own answer.' },
  ];

  replaceAll(data);
  resetReflections(); // demo starts with the consent moment fresh
  resetReminder();
}
