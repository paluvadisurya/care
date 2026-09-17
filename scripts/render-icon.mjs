// Renders the SVG app icon variants to 1024x1024 PNGs with headless Chromium.
// Usage: node scripts/render-icon.mjs
import { chromium } from 'playwright';
import path from 'node:path';
import fs from 'node:fs';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const html = 'file://' + path.join(root, 'design/icon/icon.html');
const outDir = path.join(root, 'Care/Assets.xcassets/AppIcon.appiconset');
const docs = path.join(root, 'docs/icon');
fs.mkdirSync(docs, { recursive: true });

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 3400, height: 1200 }, deviceScaleFactor: 1 });
await page.goto(html);
for (const [id, file] of [['light', 'icon-1024.png'], ['dark', 'icon-1024-dark.png'], ['tinted', 'icon-1024-tinted.png']]) {
  if (id === 'tinted') await page.evaluate(() => { document.documentElement.style.background = 'transparent'; document.body.style.background = 'transparent'; });
  const el = await page.$('#' + id);
  await el.screenshot({ path: path.join(outDir, file), omitBackground: id === 'tinted' });
  fs.copyFileSync(path.join(outDir, file), path.join(docs, file));
  console.log('wrote', file);
}
await browser.close();
