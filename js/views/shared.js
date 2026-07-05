// Shared archive chrome: title + the Days / Week / Months / Years toggle.

const TABS = [
  ['Days', '#archive', 'archive'],
  ['Week', '#archive/week', 'archive/week'],
  ['Months', '#archive/months', 'archive/months'],
  ['Years', '#archive/years', 'archive/years'],
];

export function archiveHead(active) {
  const head = document.createElement('div');
  head.className = 'view-head';
  const title = document.createElement('h1');
  title.className = 'type-display';
  title.textContent = 'Archive';
  const toggle = document.createElement('nav');
  toggle.className = 'type-meta view-toggle';
  for (const [label, href, name] of TABS) {
    const a = document.createElement('a');
    a.href = href;
    a.textContent = label;
    if (name === active) a.classList.add('active');
    toggle.appendChild(a);
  }
  head.append(title, toggle);
  return head;
}

/** Faint mono back control, e.g. "← 2026" or "← Months". */
export function crumb(label, onTap) {
  const btn = document.createElement('button');
  btn.type = 'button';
  btn.className = 'type-meta crumb';
  btn.textContent = `← ${label}`;
  btn.addEventListener('click', onTap);
  return btn;
}
