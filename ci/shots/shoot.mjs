// Takes Play Store screenshots of the real app UI (Flutter web build, demo data, server mocked).
import { chromium } from 'playwright';
import fs from 'node:fs';

const BASE = 'http://127.0.0.1:8080/index.html';
const OUT = 'shots';
fs.mkdirSync(OUT, { recursive: true });

const learn = { info: {
  title: 'LDL cholesterol',
  what: 'LDL is the "bad" cholesterol. It measures how much cholesterol is carried by low-density lipoproteins in your blood.',
  why: 'Doctors check it to understand your risk of heart disease and stroke.',
  high: 'Diet high in saturated fat, genetics, low activity, weight gain, or some medicines.',
  low: '',
  tip: 'Diet, exercise, and sometimes medicine can lower LDL. Ask your doctor what goal is right for you.',
} };
const status = { status: { plan: 'free', plan_until: 0, plan_source: '', used: 1, free_limit: 3, free_left: 2, account: null, google_client_id: 'demo' } };

const shots = [
  ['intro', 390, 844], ['lang', 390, 844], ['home', 390, 844], ['result', 390, 3400],
  ['learn', 390, 844], ['listen', 390, 844], ['share', 390, 844], ['history', 390, 844], ['profile', 390, 844], ['plans', 390, 844],
];

const browser = await chromium.launch();
for (const [name, w, h] of shots) {
  const ctx = await browser.newContext({ viewport: { width: w, height: h }, deviceScaleFactor: 3, locale: 'en-US' });
  await ctx.route('**/api.php', async route => {
    const req = route.request();
    const cors = { 'access-control-allow-origin': '*', 'access-control-allow-headers': '*', 'access-control-allow-methods': 'POST, OPTIONS' };
    if (req.method() === 'OPTIONS') return route.fulfill({ status: 204, headers: cors });
    let body = {};
    try { body = JSON.parse(req.postData() || '{}'); } catch {}
    if (body.action === 'learn') await new Promise(r => setTimeout(r, 300));
    const data = body.action === 'learn' ? learn : status;
    return route.fulfill({ status: 200, headers: { ...cors, 'content-type': 'application/json' }, body: JSON.stringify(data) });
  });
  const page = await ctx.newPage();
  page.on('console', m => { if (m.type() === 'error') console.log(name, 'console:', m.text()); });
  page.on('pageerror', e => console.log(name, 'pageerror:', e.message));
  await page.goto(`${BASE}?shot=${name}`);
  await page.waitForSelector('flutter-view, flt-glass-pane', { timeout: 60000 });
  await page.waitForTimeout(name === 'learn' || name === 'plans' || name === 'share' ? 6000 : 4500);
  await page.screenshot({ path: `${OUT}/${name}.png` });
  console.log('saved', name);
  await ctx.close();
}
await browser.close();
