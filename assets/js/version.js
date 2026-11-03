import { rpc, esc, icon, dbVersion } from './core.js';
import { selfReload } from './config.js';

const FILES = ['version.json', 'index.html', 'assets/js/app.js', 'assets/app.css'];
let base = null, dismissedAt = null, timer = null, checking = false;

async function fingerprint() {
  const parts = await Promise.all(FILES.map(async f => {
    try {
      const r = await fetch(`${f}?vc=${Date.now()}`, { method: f === 'version.json' ? 'GET' : 'HEAD', cache: 'no-store' });
      if (!r.ok) return '';
      if (f === 'version.json') { const j = await r.json().catch(() => null); if (j) setNotice(j.notice); return `v:${j?.version || ''}`; }
      return r.headers.get('etag') || r.headers.get('last-modified') || '';
    } catch { return null; }
  }));
  let db = null;
  try { db = base ? (await rpc('world_app_version'))?.db_version || '' : await dbVersion(); } catch { db = null; }
  return { web: parts, db };
}
const changed = (a, b) => {
  if (!a || !b) return false;
  if (a.db != null && b.db != null && a.db !== b.db) return 'db';
  for (let i = 0; i < a.web.length; i++) if (a.web[i] != null && b.web[i] != null && a.web[i] && b.web[i] && a.web[i] !== b.web[i]) return 'web';
  return false;
};

let lastAt = 0;
async function check() {
  if (checking || document.hidden || Date.now() - lastAt < 120000) return;
  checking = true; lastAt = Date.now();
  try {
    const now = await fingerprint();
    if (!base) { base = now; return; }
    const kind = changed(base, now);
    if (kind) {
      const key = JSON.stringify(now);
      if (dismissedAt !== key) show(kind, key);
    }
  } finally { checking = false; }
}

function show(kind, key) {
  if (document.querySelector('.update-pop')) return;
  const el = document.createElement('div');
  el.className = 'update-pop'; el.setAttribute('role', 'alertdialog'); el.setAttribute('aria-label', '새 버전');
  el.innerHTML = `${icon('refresh', 20)}<div><b>야행국이 새로 손질되었습니다</b><span>${esc(kind === 'db' ? '서버 규칙이 바뀌었습니다. 새로고침해야 바뀐 내용이 제대로 적용됩니다.' : '화면이 새로 바뀌었습니다. 새로고침하면 바뀐 내용을 볼 수 있습니다.')}</span></div>
    <div class="note-actions"><button class="btn primary small" data-reload>지금 새로고침</button><a class="btn ghost small" href="#/patch">패치노트</a><button class="btn ghost small" data-later>나중에</button></div>`;
  el.querySelector('[data-reload]').onclick = () => selfReload('update');
  el.querySelector('[data-later]').onclick = () => { dismissedAt = key; el.remove(); };
  document.body.append(el);
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'confirm' }));
}

let noticeText = '', noticeHidden = '';
function setNotice(t) {
  t = typeof t === 'string' ? t.trim() : '';
  if (t === noticeText) return;
  noticeText = t;
  let el = document.querySelector('.deploy-notice');
  if (!t) { el?.remove(); return; }
  if (noticeHidden === t) return;
  if (!el) { el = document.createElement('div'); el.className = 'deploy-notice'; el.setAttribute('role', 'status'); document.body.prepend(el); }
  el.innerHTML = `${icon('bell', 16)}<span>${esc(t)}</span><button class="btn ghost small" type="button" aria-label="닫기">닫기</button>`;
  el.querySelector('button').onclick = () => { noticeHidden = t; el.remove(); };
}
async function readNotice() {
  if (document.hidden) return;
  try { const r = await fetch(`version.json?vc=${Date.now()}`, { cache: 'no-store' }); if (r.ok) setNotice((await r.json())?.notice); } catch { }
}

export function mountVersionCheck() {
  if (timer) return;
  check();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) { check(); readNotice(); } });
  window.addEventListener('focus', check);
  timer = setInterval(check, 5 * 60 * 1000);
  setInterval(readNotice, 2 * 60 * 1000);
}
