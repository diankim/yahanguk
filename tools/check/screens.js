const { chromium, devices } = require('playwright');
const fs = require('fs');
const path = require('path');

const label = process.argv[2] || 'run';
const base = (process.argv[3] || process.env.YH_BASE || 'https://yahanguk.pages.dev/').replace(/\/?$/, '/');
const outRoot = process.env.YH_SHOTS || path.join(process.cwd(), 'shots');
const out = path.join(outRoot, label);
const id = process.env.YH_TEST_ID, pw = process.env.YH_TEST_PW;
const VIEWS = (process.env.YH_VIEWS || 'home,map,char,bag,log,house,people,help,settings,patch').split(',').map(s => s.trim()).filter(Boolean);
const LAYOUTS = [['desktop', { viewport: { width: 1440, height: 900 } }], ['mobile', { ...devices['iPhone 13'] }]];

async function run(name, opts, browser) {
  const ctx = await browser.newContext(opts);
  const page = await ctx.newPage();
  const log = { console: [], pageerror: [], failed: [], rpc: [], http: [] };
  page.on('console', m => { if (m.type() === 'error' || m.type() === 'warning') log.console.push({ type: m.type(), text: m.text().slice(0, 300) }); });
  page.on('pageerror', e => log.pageerror.push(String(e.message || e).slice(0, 300)));
  page.on('requestfailed', r => log.failed.push({ url: r.url().replace(/\?.*$/, ''), why: r.failure()?.errorText }));
  page.on('response', async r => {
    const u = r.url();
    const m = u.match(/\/rest\/v1\/rpc\/([a-z_0-9]+)/);
    if (m) {
      const rec = { fn: m[1], status: r.status() };
      if (r.status() >= 400) { try { rec.body = (await r.text()).slice(0, 300); } catch {} }
      log.rpc.push(rec);
    } else if (r.status() >= 400 && !/\/auth\/v1\/token/.test(u)) log.http.push({ url: u.replace(/\?.*$/, ''), status: r.status() });
  });
  await page.goto(base, { waitUntil: 'networkidle', timeout: 60000 });
  await page.fill('#auth-form input[name=uid]', id);
  await page.fill('#auth-form input[name=password]', pw);
  await Promise.all([page.waitForLoadState('networkidle').catch(() => {}), page.click('#auth-form [type=submit]')]);
  await page.waitForFunction(() => !document.querySelector('#auth-form'), null, { timeout: 30000 }).catch(() => log.pageerror.push('login: 로그인 화면이 사라지지 않음'));
  await page.waitForTimeout(2500);
  const shots = [];
  for (const v of VIEWS) {
    await page.evaluate(h => { location.hash = h; }, `#/${v}`);
    await page.waitForLoadState('networkidle').catch(() => {});
    await page.waitForTimeout(1800);
    const file = path.join(out, `${name}-${v}.png`);
    await page.screenshot({ path: file, fullPage: true });
    const overflow = await page.evaluate(() => document.documentElement.scrollWidth - window.innerWidth);
    shots.push({ view: v, file: path.basename(file), overflow_x: overflow > 1 ? overflow : 0 });
  }
  await ctx.close();
  return { layout: name, shots, ...log };
}

(async () => {
  if (!id || !pw) { console.error('YH_TEST_ID·YH_TEST_PW 환경 변수가 없습니다(값은 저장소·로그에 남기지 않음).'); process.exit(2); }
  fs.mkdirSync(out, { recursive: true });
  const browser = await chromium.launch();
  const report = { label, base, at: new Date().toISOString(), views: VIEWS, layouts: [] };
  for (const [name, opts] of LAYOUTS) report.layouts.push(await run(name, opts, browser));
  await browser.close();
  fs.writeFileSync(path.join(out, 'report.json'), JSON.stringify(report, null, 2));
  for (const l of report.layouts) {
    const bad = l.rpc.filter(r => r.status >= 400);
    console.log(`[${l.layout}] 화면 ${l.shots.length} · 콘솔 ${l.console.length} · 페이지 오류 ${l.pageerror.length} · 요청 실패 ${l.failed.length} · HTTP 오류 ${l.http.length} · RPC ${l.rpc.length}건 중 오류 ${bad.length} · 가로 넘침 ${l.shots.filter(s => s.overflow_x).map(s => s.view).join(',') || '없음'}`);
  }
  console.log(out);
})().catch(e => { console.error(String(e.message || e).replace(pw || '\u0000', '***')); process.exit(1); });
