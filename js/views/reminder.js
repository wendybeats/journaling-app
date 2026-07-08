// The reminder pre-prompt — the in-system card that precedes any system
// permission dialog (docs/vellum-stage2-plan.md §3.1). Offered once the
// user has written on two distinct days; a no is remembered and never
// re-asked. Local notifications are iOS work — the prototype records the
// decision only.

import { daysWithEntries } from '../store.js';
import { consentEligible } from '../reflect.js';

const KEY = 'vellum.reminder.v1';

function decision() {
  try {
    return localStorage.getItem(KEY);
  } catch {
    return 'no';
  }
}

export function resetReminder() {
  localStorage.removeItem(KEY);
}

function el(tag, className, text) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  if (text !== undefined) node.textContent = text;
  return node;
}

/** Mounted on Today, after the reflection flow — one quiet card at a time,
 *  so it waits until the consent moment has been decided. */
export function mountReminderPrompt(root) {
  if (decision() !== null) return;
  if (daysWithEntries().length < 2) return; // they haven't felt the value yet
  if (consentEligible()) return; // the consent card has this visit

  const card = el('section', 'grid-card consent-card');
  card.appendChild(el('h2', 'type-title', 'A morning nudge?'));
  card.appendChild(el('p', 'type-written consent-body',
    'Want a nudge each morning? One line, once a day. Never a streak, never a guilt trip.'));

  const actions = el('div', 'consent-actions type-meta');
  const yes = el('button', null, 'Yes, 8:00 AM');
  yes.type = 'button';
  const no = el('button', null, 'No thanks');
  no.type = 'button';

  yes.addEventListener('click', () => {
    localStorage.setItem(KEY, 'yes');
    card.remove();
  });
  no.addEventListener('click', () => {
    localStorage.setItem(KEY, 'no');
    card.remove();
  });

  actions.append(yes, no);
  card.appendChild(actions);
  root.appendChild(card);
}
