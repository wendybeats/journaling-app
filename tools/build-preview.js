// Assembles the Vellum prototype into one self-contained HTML file that runs
// from a double-click (file://), no server needed: inline CSS, data-URI fonts,
// concatenated JS, safe-storage shim, and a preview-only seed/clear control.
//
// Usage: node tools/build-preview.js  →  writes preview.html at the repo root

const fs = require('fs');
const path = require('path');

const REPO = path.join(__dirname, '..');
const read = (p) => fs.readFileSync(path.join(REPO, p), 'utf8');
const b64 = (p) => fs.readFileSync(path.join(REPO, p)).toString('base64');

// --- CSS: tokens (fonts swapped for data URIs) + app styles ---
let tokens = read('styles/tokens.css');
for (const f of ['InstrumentSans', 'Newsreader', 'Newsreader-italic', 'FragmentMono']) {
  tokens = tokens.replace(
    `url('../fonts/${f}.woff2')`,
    `url(data:font/woff2;base64,${b64(`fonts/${f}.woff2`)})`,
  );
}
const css = tokens + '\n' + read('styles/app.css');

// --- JS: strip module syntax, concatenate in dependency order ---
const order = [
  'js/store.js', 'js/format.js', 'js/dots.js', 'js/flip.js', 'js/voice.js',
  'js/seed.js', 'js/views/shared.js', 'js/views/today.js', 'js/views/archive.js',
  'js/views/week.js', 'js/views/months.js', 'js/views/year.js', 'js/views/day.js',
  'js/main.js',
];
const js = order
  .map((p) =>
    read(p)
      .replace(/^import .*$\n?/gm, '')
      .replace(/^export /gm, ''),
  )
  .join('\n\n');

// The sandbox may deny localStorage (opaque origin) — fall back to memory.
const shim = `
const storage = (() => {
  try {
    const t = '__vellum_probe__';
    localStorage.setItem(t, t);
    localStorage.removeItem(t);
    return localStorage;
  } catch {
    const m = new Map();
    return {
      getItem: (k) => (m.has(k) ? m.get(k) : null),
      setItem: (k, v) => m.set(k, String(v)),
      removeItem: (k) => m.delete(k),
    };
  }
})();
const storedTheme = storage.getItem('vellum.theme');
if (storedTheme) document.documentElement.dataset.theme = storedTheme;
`;

const seedControl = `
// Preview-only: seed/clear demo data from the footer
const seedBtn = document.getElementById('seed-toggle');
function refreshSeedLabel() {
  seedBtn.textContent = daysWithEntries().length ? 'Clear' : 'Seed demo';
}
seedBtn.addEventListener('click', () => {
  if (daysWithEntries().length) {
    replaceAll({});
    storage.removeItem('vellum.draft.v1');
  } else {
    seedDemoData();
  }
  refreshSeedLabel();
  current = null;
  mount(routeName());
});
refreshSeedLabel();
`;

const script = (shim + js + seedControl).replace(/\blocalStorage\b/g, 'storage');

const html = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="UTF-8">
<title>Vellum</title>
<meta name="viewport" content="width=device-width, initial-scale=1.0, viewport-fit=cover">
<style>
${css}
</style>
</head>
<body>
<div class="shell">
  <header class="chrome">
    <a class="wordmark" href="#today">Vellum</a>
    <nav class="type-meta">
      <a href="#today" data-route="today">Today</a>
      <a href="#archive" data-route="archive">Archive</a>
    </nav>
  </header>
  <main id="view"></main>
  <footer class="type-meta-small">
    <span>Vellum — preview</span>
    <span style="display:flex; gap: var(--space-md);">
      <button id="seed-toggle" type="button"></button>
      <button id="theme-toggle" type="button"></button>
    </span>
  </footer>
</div>
<script>
${script}
</script>
</body>
</html>
`;

const out = path.join(REPO, 'preview.html');
fs.writeFileSync(out, html);
console.log('wrote', out, `${(html.length / 1024).toFixed(0)} KB`);
