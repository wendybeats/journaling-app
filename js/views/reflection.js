// Reflection surfaces (R1): the consent card, the weekly modal (inverted
// card), and its archived inline form in the Notebook. All copy obeys the
// mirror rule — observations, the user's own words, no advice.

import { fromKey, weekRangeLabel, weekdayName } from '../format.js';
import { consentEligible, pendingWeekly, setConsent, markSeen } from '../reflect.js';

function metaHeader(signal) {
  const start = fromKey(signal.startKey);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  return `Week of ${weekRangeLabel(start, end).split(' – ')[0]} · ${signal.days} days · ${signal.words.toLocaleString()} words`;
}

/** Body copy, hand-templated per the spec: no quote, no claim. */
function composeBody(signal) {
  if (signal.topic && signal.quotes.length >= 2) {
    return {
      body: `“${signal.topic.word}” kept surfacing — ${signal.topic.mentions} times, across ${signal.topic.days} days. Collected, in your words:`,
      quotes: signal.quotes,
      closing: 'Worth sitting with?',
    };
  }
  return {
    body: `No single thread this week — ${signal.days} days of writing, each in its own place. Sometimes a week is just days.`,
    quotes: [],
    closing: null,
  };
}

function reflectionContent(signal, compact = false) {
  const frag = document.createDocumentFragment();

  const meta = document.createElement('div');
  meta.className = 'type-meta';
  meta.textContent = compact ? `Reflection · ${metaHeader(signal)}` : metaHeader(signal);
  frag.appendChild(meta);

  const { body, quotes, closing } = composeBody(signal);
  const p = document.createElement('p');
  p.className = 'reflection-body';
  p.textContent = body;
  frag.appendChild(p);

  for (const q of compact ? quotes.slice(0, 1) : quotes) {
    const block = document.createElement('blockquote');
    const text = document.createElement('p');
    text.textContent = `“${q.text.replace(/[.?!]$/, '')}”`;
    const stamp = document.createElement('footer');
    stamp.className = 'type-meta-small';
    stamp.textContent = weekdayName(fromKey(q.day));
    block.append(text, stamp);
    frag.appendChild(block);
  }

  if (closing && !compact) {
    const c = document.createElement('p');
    c.className = 'reflection-closing';
    c.textContent = closing;
    frag.appendChild(c);
  }

  return frag;
}

/** Full-screen arrival moment. Dismissing archives it (no re-rolls). */
export function showWeeklyModal(signal) {
  if (document.querySelector('.reflection-overlay')) return;

  const overlay = document.createElement('div');
  overlay.className = 'reflection-overlay';
  const card = document.createElement('section');
  card.className = 'reflection-card';

  const close = document.createElement('button');
  close.type = 'button';
  close.className = 'reflection-close';
  close.setAttribute('aria-label', 'Close reflection');
  close.textContent = '×';

  card.append(close, reflectionContent(signal));
  overlay.appendChild(card);

  function dismiss() {
    markSeen(signal);
    document.removeEventListener('keydown', onKey);
    overlay.classList.add('leaving');
    overlay.addEventListener('transitionend', () => overlay.remove(), { once: true });
  }
  function onKey(e) {
    if (e.key === 'Escape') dismiss();
  }
  close.addEventListener('click', dismiss);
  overlay.addEventListener('click', (e) => e.target === overlay && dismiss());
  document.addEventListener('keydown', onKey);

  document.body.appendChild(overlay);
  requestAnimationFrame(() => overlay.classList.add('open'));
}

/** The archived form — rests at the week boundary in the Notebook. */
export function inlineReflection(signal) {
  const card = document.createElement('section');
  card.className = 'reflection-card reflection-inline';
  card.appendChild(reflectionContent(signal, true));
  return card;
}

/** Consent moment — mounted on Today the first time a recap could exist. */
function consentCard(onDecided) {
  const card = document.createElement('section');
  card.className = 'grid-card consent-card';

  const title = document.createElement('h2');
  title.className = 'type-title';
  title.textContent = 'A weekly reflection?';

  const body = document.createElement('p');
  body.className = 'type-written consent-body';
  body.textContent = 'Vellum can read your week back to you — your own words, collected. The writing is sent once, privately, to generate it, then discarded. Nothing is stored anywhere but here.';

  const actions = document.createElement('div');
  actions.className = 'consent-actions type-meta';
  const yes = document.createElement('button');
  yes.type = 'button';
  yes.textContent = 'Yes, reflect';
  const no = document.createElement('button');
  no.type = 'button';
  no.textContent = 'No thanks';

  yes.addEventListener('click', () => { setConsent('yes'); onDecided(true, card); });
  no.addEventListener('click', () => { setConsent('no'); onDecided(false, card); });

  actions.append(yes, no);
  card.append(title, body, actions);
  return card;
}

/** Wire the reflection flow into Today: consent first, then arrivals. */
export function mountReflectionFlow(root) {
  if (consentEligible()) {
    root.appendChild(consentCard((accepted, card) => {
      card.remove();
      if (accepted) {
        const signal = pendingWeekly();
        if (signal) showWeeklyModal(signal);
      }
    }));
    return;
  }
  const signal = pendingWeekly();
  if (signal) setTimeout(() => showWeeklyModal(signal), 600);
}
