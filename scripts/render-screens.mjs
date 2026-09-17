// Renders every phone frame in design/screens/screens.html to docs/screens/<name>.png at 3x (iPhone 17 Pro class, 402x874 pt).
// Usage: node scripts/render-screens.mjs
import { chromium } from 'playwright';
import path from 'node:path';
import fs from 'node:fs';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const html = 'file://' + path.join(root, 'design/screens/screens.html');
const outDir = path.join(root, 'docs/screens');
fs.mkdirSync(outDir, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1400, height: 1000 }, deviceScaleFactor: 3 });
await page.goto(html);
await page.evaluate(() => document.fonts.ready);
await page.waitForTimeout(300);
for (const el of await page.$$('.phone')) {
  const name = await el.getAttribute('data-name');
  await el.screenshot({ path: path.join(outDir, name + '.png') });
  console.log('wrote', name);
}
await browser.close();
