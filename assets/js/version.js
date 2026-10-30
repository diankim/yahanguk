// 새 버전 알림: 화면 파일(배포)이나 서버(SQL 적용)가 바뀌면 접속 중인 화면 위에 「새로고침」 안내를 띄운다.
// - 화면: version.json(배포마다 값을 올린다)과 주요 파일(index.html·app.js·app.css)의 ETag를 함께 본다.
// - 서버: world_app_version()의 db_version(SQL 마이그레이션 끝에서 올린다).
// 처음 읽은 값을 기준으로, 화면으로 돌아올 때와 보고 있는 동안 5분마다 비교한다(가벼운 HEAD·RPC 한 번씩).
import { rpc, esc, icon, dbVersion } from './core.js';

const FILES = ['version.json', 'index.html', 'assets/js/app.js', 'assets/app.css'];
let base = null, dismissedAt = null, timer = null, checking = false;

async function fingerprint() {
  const parts = await Promise.all(FILES.map(async f => {
    try {
      const r = await fetch(`${f}?vc=${Date.now()}`, { method: f === 'version.json' ? 'GET' : 'HEAD', cache: 'no-store' });
      if (!r.ok) return '';
      if (f === 'version.json') { const j = await r.json().catch(() => null); return `v:${j?.version || ''}`; }
      return r.headers.get('etag') || r.headers.get('last-modified') || '';
    } catch { return null; }
  }));
  let db = null;
  // 처음에는 접속하며 읽은 값을 같이 쓴다(묶음 크기·가방 사전 확인과 같은 요청)
  try { db = base ? (await rpc('world_app_version'))?.db_version || '' : await dbVersion(); } catch { db = null; }
  // 네트워크가 끊겨 읽지 못한 값(null)은 비교에서 뺀다
  return { web: parts, db };
}
const changed = (a, b) => {
  if (!a || !b) return false;
  if (a.db != null && b.db != null && a.db !== b.db) return 'db';
  for (let i = 0; i < a.web.length; i++) if (a.web[i] != null && b.web[i] != null && a.web[i] && b.web[i] && a.web[i] !== b.web[i]) return 'web';
  return false;
};

// 화면 복귀와 창 선택이 겹쳐도 2분 안에는 다시 확인하지 않는다(5분 주기는 그대로)
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
  el.querySelector('[data-reload]').onclick = () => location.reload();
  el.querySelector('[data-later]').onclick = () => { dismissedAt = key; el.remove(); };
  document.body.append(el);
  window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'confirm' }));
}

export function mountVersionCheck() {
  if (timer) return;
  check();
  document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
  window.addEventListener('focus', check);
  timer = setInterval(check, 5 * 60 * 1000);
}
