// Reflection surfaces (R1+R2): the consent card, the arrival modals
// (weekly reflection + monthly recap, both the reserved inverted card),
// and the condensed archived cards resting in the Notebook. All copy obeys
// the mirror rule — observations, the user's own words, no advice.

import { fromKey, weekRangeLabel, weekdayName, monthName } from '../format.js';
import { consentEligible, pendingWeekly, pendingMonthly, setConsent, markSeen } from '../reflect.js';

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

function quoteBlock(q, compactStamp = false) {
  const block = document.createElement('blockquote');
  block.appendChild(el('p', null, `“${q.text.replace(/[.?!]$/, '')}”`));
  block.appendChild(el('footer', 'type-meta-small', compactStamp ? q.day : weekdayName(fromKey(q.day))));
  return block;
}

// --- Labels -----------------------------------------------------------------

function weekLabel(signal) {
  const start = fromKey(signal.startKey);
  const end = new Date(start);
  end.setDate(start.getDate() + 6);
  return `Week of ${weekRangeLabel(start, end).split(' – ')[0]}`;
}

export function inlineLabel(signal) {
  return signal.kind === 'weekly'
    ? `Reflection · ${weekLabel(signal)}`
    : `Recap · ${monthName(signal.month)} ${signal.year}`;
}

// --- Content ------------------------------------------------------------------

function weeklyContent(signal) {
  const frag = document.createDocumentFragment();
  frag.appendChild(el('div', 'type-meta', `${weekLabel(signal)} · ${signal.days} days · ${signal.words.toLocaleString()} words`));

  if (signal.topic && signal.quotes.length >= 2) {
    frag.appendChild(el('p', 'reflection-body',
      `“${signal.topic.word}” kept surfacing — ${signal.topic.mentions} times, across ${signal.topic.days} days. Collected, in your words:`));
    for (const q of signal.quotes) frag.appendChild(quoteBlock(q));
    frag.appendChild(el('p', 'reflection-closing', 'Worth sitting with?'));
  } else {
    frag.appendChild(el('p', 'reflection-body',
      `No single thread this week — ${signal.days} days of writing, each in its own place. Sometimes a week is just days.`));
  }
  return frag;
}

function monthlyContent(signal) {
  const frag = document.createDocumentFragment();
  frag.appendChild(el('div', 'type-meta',
    `${monthName(signal.month)} ${signal.year} · ${signal.days} ${signal.days === 1 ? 'day' : 'days'} · ${signal.words.toLocaleString()} words`));

  if (!signal.sufficient) {
    frag.appendChild(el('p', 'reflection-body', 'A quieter month on the page. The dots know the rest.'));
  } else {
    if (signal.topics.length) {
      frag.appendChild(el('div', 'type-meta-small reflection-label', 'Recurring'));
      const list = el('div', 'reflection-topics');
      for (const t of signal.topics) {
        const row = el('div', 'reflection-topic');
        row.appendChild(el('span', 'reflection-topic-word', `“${t.word}”`));
        row.appendChild(el('span', 'type-meta-small', `${t.days} days`));
        list.appendChild(row);
      }
      frag.appendChild(list);
      if (signal.topQuote) frag.appendChild(quoteBlock(signal.topQuote));
    }

    if (signal.tone) {
      frag.appendChild(el('div', 'type-meta-small reflection-label', 'Tone'));
      frag.appendChild(el('p', 'reflection-body',
        `Your word was “${signal.tone.word}” — it appeared ${signal.tone.count} times.`));
    }

    if (signal.difficult.length) {
      frag.appendChild(el('div', 'type-meta-small reflection-label', 'What seemed difficult'));
      for (const q of signal.difficult) frag.appendChild(quoteBlock(q));
    }

    if (!signal.topics.length && !signal.tone && !signal.difficult.length) {
      frag.appendChild(el('p', 'reflection-body',
        'No single thread this month — the days each kept to themselves. The numbers below are the honest summary.'));
    }
  }

  frag.appendChild(el('div', 'type-meta-small reflection-footer', `Longest run · ${signal.longestRun} ${signal.longestRun === 1 ? 'day' : 'days'}`));
  return frag;
}

// --- Modal ---------------------------------------------------------------------

/** Arrival + re-view moment. Dismissing archives it (idempotent, no re-rolls). */
export function showReflectionModal(signal) {
  if (document.querySelector('.reflection-overlay')) return;

  const overlay = el('div', 'reflection-overlay');
  const card = el('section', 'reflection-card');

  const close = el('button', 'reflection-close', '×');
  close.type = 'button';
  close.setAttribute('aria-label', 'Close reflection');

  card.append(close, signal.kind === 'weekly' ? weeklyContent(signal) : monthlyContent(signal));
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

/** Condensed archived form — one quiet on-color line at the period
 *  boundary; tapping reopens the full card. */
export function inlineReflection(signal) {
  const card = el('section', 'reflection-inline type-meta', inlineLabel(signal));
  card.setAttribute('role', 'button');
  card.addEventListener('click', () => showReflectionModal(signal));
  return card;
}

// --- Consent ----------------------------------------------------------------------

function consentCard(onDecided) {
  const card = el('section', 'grid-card consent-card');

  card.appendChild(el('div', 'type-meta', 'Reflections'));
  card.appendChild(el('h2', 'type-title consent-title', 'Your week'));
  card.appendChild(el('p', 'type-written consent-body',
    'Where is your mind? See what your words say about you this week.'));
  card.appendChild(el('div', 'type-meta-small consent-privacy', 'Always private, for your eyes only'));

  const actions = el('div', 'consent-actions type-meta');
  const yes = el('button', null, 'Yes, reflect');
  yes.type = 'button';
  const no = el('button', null, 'No thanks');
  no.type = 'button';

  yes.addEventListener('click', () => { setConsent('yes'); onDecided(true, card); });
  no.addEventListener('click', () => { setConsent('no'); onDecided(false, card); });

  actions.append(yes, no);
  card.appendChild(actions);
  return card;
}

/** Wire the reflection flow into Today: consent first; afterwards one
 *  arrival per visit — monthly wins, weekly follows on the next open. */
export function mountReflectionFlow(root) {
  if (consentEligible()) {
    root.appendChild(consentCard((accepted, card) => {
      card.remove();
      if (accepted) {
        // The consent moment pitched "your week" — deliver that first
        const signal = pendingWeekly() ?? pendingMonthly();
        if (signal) showReflectionModal(signal);
      }
    }));
    return;
  }
  const signal = pendingMonthly() ?? pendingWeekly();
  if (signal) setTimeout(() => showReflectionModal(signal), 600);
}
