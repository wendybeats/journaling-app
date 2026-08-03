// Endpaper content engine — rule cards.
// Renders cards/rule.html once per rule in cards/rules.json, at feed
// (1080×1350) and story (1080×1920) sizes, light and dark.
//
// Usage: node render-cards.mjs [outDir]

import { chromium } from 'playwright';
import { mkdirSync, readFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { dirname, resolve } from 'node:path';

const here = dirname(fileURLToPath(import.meta.url));
const out = resolve(process.argv[2] || resolve(here, 'out'));
mkdirSync(out, { recursive: true });

const rules = JSON.parse(readFileSync(resolve(here, 'cards/rules.json'), 'utf8'));
const url = 'file://' + resolve(here, 'cards/rule.html');

const SIZES = [
  ['feed', { width: 1080, height: 1350 }],
  ['story', { width: 1080, height: 1920 }],
];

const browser = await chromium.launch({ executablePath: '/opt/pw-browsers/chromium' });

for (const scheme of ['light', 'dark']) {
  for (const [sizeName, viewport] of SIZES) {
    const ctx = await browser.newContext({ viewport, colorScheme: scheme });
    const page = await ctx.newPage();
    await page.goto(url);
    await page.evaluate(() => document.fonts.ready);
    for (const rule of rules) {
      await page.evaluate(({ html, size }) => {
        const el = document.getElementById('rule');
        el.innerHTML = html;
        el.style.fontSize = size + 'px';
      }, rule);
      await page.waitForTimeout(60);
      await page.screenshot({ path: `${out}/rule-${rule.id}-${sizeName}-${scheme}.png` });
    }
    await ctx.close();
  }
}

await browser.close();
console.log(`rendered ${rules.length * 4} cards to`, out);
