// Date and metadata formatting — everything the mono register displays.

const MONTHS = ['January', 'February', 'March', 'April', 'May', 'June',
  'July', 'August', 'September', 'October', 'November', 'December'];
const DAYS = ['Sunday', 'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday'];

export function fromKey(key) {
  const [y, m, d] = key.split('-').map(Number);
  return new Date(y, m - 1, d);
}

/** "Tuesday" — bare weekday, used for quote stamps. */
export function weekdayName(date) {
  return DAYS[date.getDay()];
}

/** "Saturday, July 5" — the editorial day heading. */
export function dayHeading(date) {
  return `${DAYS[date.getDay()]}, ${MONTHS[date.getMonth()]} ${date.getDate()}`;
}

/** "JULY 5, 2026" (mono register applies the uppercase). */
export function dayMetaDate(date) {
  return `${MONTHS[date.getMonth()]} ${date.getDate()}, ${date.getFullYear()}`;
}

/** "9:41 AM" */
export function timeOfDay(at) {
  const d = new Date(at);
  let h = d.getHours();
  const mer = h >= 12 ? 'PM' : 'AM';
  h = h % 12 || 12;
  return `${h}:${String(d.getMinutes()).padStart(2, '0')} ${mer}`;
}

/** "JULY 5, 2026 · 3 ENTRIES · 4 MIN" — reading time only where asked for
 *  (Today keeps it; archive meta rows drop it). */
export function dayMetaRow(date, dayEntries, { withMin = true } = {}) {
  const parts = [dayMetaDate(date)];
  if (dayEntries.length) {
    parts.push(`${dayEntries.length} ${dayEntries.length === 1 ? 'entry' : 'entries'}`);
    if (withMin) {
      const words = dayEntries.reduce((n, e) => n + e.text.split(/\s+/).filter(Boolean).length, 0);
      parts.push(`${Math.max(1, Math.round(words / 200))} min`);
    }
  }
  return parts.join(' · ');
}

/** "JUNE 29 – JULY 5" for the Sunday-start week containing `date`. */
export function weekRangeLabel(start, end) {
  const one = (d) => `${MONTHS[d.getMonth()]} ${d.getDate()}`;
  return `${one(start)} – ${one(end)}`;
}

export function monthName(m) {
  return MONTHS[m];
}

export function monthAbbr(m) {
  return MONTHS[m].slice(0, 3);
}
