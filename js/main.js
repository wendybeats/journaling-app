// Shell: hash router with the calm cross-fade, nav state, theme toggle.

import { renderToday } from './views/today.js';
import { renderArchive } from './views/archive.js';
import { renderWeek } from './views/week.js';
import { renderMonths } from './views/months.js';
import { renderYears } from './views/year.js';
import { renderDay } from './views/day.js';
import { seedDemoData } from './seed.js';

const MOTION_BASE = 260; // keep in sync with --motion-base

const view = document.getElementById('view');
let current = null; // { name, teardown }

/** Resolve the hash to { name, render }. Unknown hashes land on Today. */
function resolve() {
  const h = location.hash.replace(/^#\/?/, '');
  if (!h || h === 'today') return { name: 'today', render: renderToday };
  if (h === 'archive') return { name: h, render: renderArchive };
  if (h === 'archive/week') return { name: h, render: renderWeek };
  if (h === 'archive/months') return { name: h, render: renderMonths };
  if (h === 'archive/years' || h === 'year') return { name: 'archive/years', render: renderYears };
  const day = h.match(/^archive\/day\/(\d{4}-\d{2}-\d{2})$/);
  if (day) return { name: h, render: (root) => renderDay(root, day[1]) };
  return { name: 'today', render: renderToday };
}

function routeName() {
  return resolve().name;
}

function setNav(name) {
  for (const a of document.querySelectorAll('.chrome nav a')) {
    const active = a.dataset.route === name
      || (a.dataset.route === 'archive' && name.startsWith('archive'));
    a.classList.toggle('active', active);
  }
}

function mount(name) {
  view.innerHTML = '';
  view.classList.remove('leaving');
  view.classList.add('entering');
  view.addEventListener('animationend', () => view.classList.remove('entering'), { once: true });
  const handle = resolve().render(view) ?? {};
  current = { name, teardown: handle.teardown };
  setNav(name);
  window.scrollTo(0, 0);
}

function navigate() {
  const name = routeName();
  if (current?.name === name) return;
  current?.teardown?.();
  if (current) {
    // Today ↔ archive — a calm cross-fade at motion.base
    view.classList.add('leaving');
    setTimeout(() => mount(name), MOTION_BASE);
  } else {
    mount(name);
  }
}

window.addEventListener('hashchange', navigate);
window.addEventListener('beforeunload', () => current?.teardown?.());

// --- Theme toggle (footer chrome) ---

const toggle = document.getElementById('theme-toggle');

function effectiveTheme() {
  const forced = document.documentElement.dataset.theme;
  if (forced) return forced;
  return matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
}

function refreshToggleLabel() {
  toggle.textContent = effectiveTheme() === 'dark' ? 'Light' : 'Dark';
}

toggle.addEventListener('click', () => {
  const next = effectiveTheme() === 'dark' ? 'light' : 'dark';
  document.documentElement.dataset.theme = next;
  localStorage.setItem('vellum.theme', next);
  refreshToggleLabel();
});
refreshToggleLabel();

// --- Boot ---

if (new URLSearchParams(location.search).has('seed')) {
  seedDemoData();
  history.replaceState(null, '', location.pathname + location.hash);
}

navigate();
