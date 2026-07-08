// Demo seed — visiting ?seed fills the log with plausible past entries so the
// archive and dot grids can be judged with real density. Dev tool only.

import { dayKey, replaceAll } from './store.js';
import { resetReflections, lastCompletedWeekStart } from './reflect.js';
import { resetReminder } from './views/reminder.js';

const SNIPPETS = [
  'Woke before the alarm again. There is a particular quality to the hour before anyone needs anything from me — I want to protect it better than I have been.',
  'Long call with the team about the roadmap. I keep noticing how much of my job is just saying the same true thing patiently, in different rooms.',
  'Walked the long way home past the harbor. The water was completely flat and I stood there longer than I meant to.',
  'Reading before bed instead of scrolling, night four. The difference in how mornings feel is not subtle.',
  'The essay is fighting me. I think the problem is that I am trying to sound smart instead of trying to be clear.',
  'Coffee with Dana. She asked what I would build if nobody was watching, and I did not have a fast answer. Sitting with that.',
  'Shipped the thing. Quietly, no announcement. It felt better that way — the work as its own punctuation.',
  'Rain all day. Stayed in and cleaned the studio. There is thinking that only happens while the hands are busy.',
  'I keep circling the same idea in different notebooks. Maybe the repetition is the point — the thought is trying to finish itself.',
  'Bad sleep, short fuse. Noted without judgment, mostly.',
  'The morning pages are getting easier. Less clearing of the throat before the actual sentence arrives.',
  'Dinner with the family. Dad told the story about the boat again and I realized I would miss the retelling more than the story.',
  'Deleted three features from the spec today. Each one hurt for about a minute and then the whole thing got lighter.',
  'A good day, ordinary in every particular. Worth writing down precisely because there is nothing to report.',
  'Ran in the cold. First kilometer was a negotiation, the rest was a gift.',
  'Thinking about restraint as a discipline rather than a preference. What would this look like if it were harder to do less?',
  'The draft finally cracked open around noon. Two hours disappeared. This is the feeling I am always trying to get back to.',
  'Argued my position too hard in the review. The point survived; the tone should have been softer. Tomorrow: repair.',
  'New month. Looking at the grid of days behind me and feeling something between pride and appetite.',
  'Spent the evening with the lights low, doing nothing defensible. Necessary.',
  'The idea from the shower survived contact with paper, which almost never happens.',
  'Slow start, strong finish. The afternoon self keeps rescuing the morning self and neither of them thanks the other.',
  'Called an old friend instead of texting. Forty minutes. Should be a rule, not an exception.',
  'Small vow, recorded here so it counts: no new projects until this one is done being loved.',
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

  replaceAll(data);
  resetReflections(); // demo starts with the consent moment fresh
  resetReminder();
}
