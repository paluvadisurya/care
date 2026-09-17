// Composes the README hero from three rendered screens, so the banner always matches the screens below it.
// Usage: node scripts/render-hero.mjs
import { chromium } from 'playwright';
import path from 'node:path';
import fs from 'node:fs';

const root = path.resolve(new URL('..', import.meta.url).pathname);
const shots = ['02-person-srivalli', '01-today', '07-insight-night'];

const frames = shots.map((name, i) => {
  const data = fs.readFileSync(path.join(root, 'docs/screens', name + '.png')).toString('base64');
  const lift = i === 1 ? -22 : 0;
  const tilt = i === 0 ? -3.5 : i === 2 ? 3.5 : 0;
  const z = i === 1 ? 3 : 1;
  return `<img src="data:image/png;base64,${data}"
            style="transform:translateY(${lift}px) rotate(${tilt}deg);z-index:${z}">`;
}).join('');

const html = `<!doctype html><meta charset="utf-8"><style>
  *{margin:0;box-sizing:border-box}
  body{width:1440px;height:900px;display:flex;align-items:center;justify-content:center;gap:30px;
       background:radial-gradient(120% 130% at 20% 0%,#EAF2FF 0%,#F6EEFF 42%,#FFF3EA 100%);
       overflow:hidden;padding:0 44px}
  img{width:368px;border-radius:40px;position:relative;
      box-shadow:0 34px 70px rgba(26,22,44,.22), 0 4px 12px rgba(26,22,44,.1),
                 0 0 0 1px rgba(255,255,255,.7) inset}
</style><body>${frames}</body>`;

const file = path.join(root, 'design/screens/hero.html');
fs.writeFileSync(file, html);

const browser = await chromium.launch();
const page = await browser.newPage({ viewport: { width: 1440, height: 900 }, deviceScaleFactor: 2 });
await page.goto('file://' + file);
await page.waitForTimeout(300);
await page.screenshot({ path: path.join(root, 'docs/hero.png') });
await browser.close();
console.log('wrote docs/hero.png');
