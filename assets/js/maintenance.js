// 점검 페이지 동작: 저장된 테마를 적용하고, 30초마다 서버를 확인해 점검이 끝나면 원래 보던 화면으로 돌아간다.
// 안내 문구·예상 종료·작업 목록은 maintenance.json(message·until·notes)에서 읽는다.
import { applySavedTheme } from './theme.js';
import { serverState } from './config.js';

applySavedTheme();
const EVERY = 30000;
const q = s => document.querySelector(s);
const msg = q('[data-maint-message]'), when = q('[data-maint-checked]'), next = q('[data-maint-next]'), until = q('[data-maint-until]');
const state = q('[data-maint-state]'), stateText = q('[data-maint-state-text]'), title = q('[data-maint-title]'), notes = q('[data-maint-notes]'), retry = q('[data-maint-retry]');
const DEFAULT_MSG = msg?.textContent || '';
const clock = d => d.toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
let nextAt = 0, busy = false;
const LOADED = Date.now();

function show(s) {
  const info = s.info || {};
  const off = s.state === 'offline';
  state?.classList.toggle('offline', off);
  state?.classList.toggle('open', s.state === 'open');
  if (stateText) stateText.textContent = off ? '연결 안 됨' : s.state === 'open' ? '열림' : '점검 중';
  if (title) title.textContent = off ? '서버에 연결할 수 없습니다' : s.state === 'open' ? '점검이 끝났습니다' : '서버 점검 중입니다';
  if (msg) msg.textContent = off ? '인터넷 연결을 확인해 주세요. 연결되면 자동으로 다시 확인합니다.' : (info.message || DEFAULT_MSG);
  if (until) {
    const t = info.until ? new Date(info.until) : null;
    until.textContent = t && !isNaN(t) ? t.toLocaleString('ko-KR', { month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false, timeZone: 'Asia/Seoul' }) + ' 무렵' : '끝나는 대로 열립니다';
  }
  if (notes) {
    const list = Array.isArray(info.notes) ? info.notes.filter(x => typeof x === 'string' && x.trim()) : [];
    notes.hidden = !list.length;
    const ul = notes.querySelector('ul'); if (ul) ul.replaceChildren(...list.map(t => Object.assign(document.createElement('li'), { textContent: t })));
  }
}

async function check() {
  if (busy) return;
  busy = true; if (retry) { retry.disabled = true; retry.textContent = '확인하는 중…'; }
  try {
    const s = await serverState();
    show(s);
    if (when) when.textContent = clock(new Date());
    if (s.state === 'open') {
      let back = ''; try { back = sessionStorage.getItem('yh-return') || ''; sessionStorage.removeItem('yh-return'); } catch {}
      setTimeout(() => location.replace('index.html' + back), 600);
      return;
    }
    // 점검 중 배포가 바뀌면(서버 주소 변경 등) 이 화면이 읽어 둔 옛 설정으로만 확인하게 되므로, 5분마다 페이지를 새로 읽는다
    if (Date.now() - LOADED > 5 * 60000 && !document.querySelector('.help-ov')) { location.reload(); return; }  // 도움말 창을 보는 동안은 미룬다
  } finally {
    busy = false; nextAt = Date.now() + EVERY;
    if (retry) { retry.disabled = false; retry.textContent = '지금 다시 확인'; }
  }
}
// 다음 확인까지 남은 시간
setInterval(() => {
  if (!next || !nextAt) return;
  const left = Math.max(0, Math.ceil((nextAt - Date.now()) / 1000));
  next.textContent = busy ? '확인 중' : `${left}초 뒤`;
  if (left <= 0 && !document.hidden) check();
}, 1000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
window.addEventListener('online', check);
retry?.addEventListener('click', check);
check();

// 도움말은 페이지를 넘기지 않고 겹친 창(iframe)으로 연다 — 대기 화면 배경음악(컷씬 곡)이 끊기지 않게.
// help.html?embed=1 안의 「대기 화면으로」는 이 창을 닫는다(yh-help-close).
let helpOv = null;
function closeHelp() { if (!helpOv) return; helpOv.remove(); helpOv = null; document.documentElement.style.overflow = ''; }
function openHelp() {
  if (helpOv) return;
  if (!document.getElementById('help-ov-style')) document.head.append(Object.assign(document.createElement('style'), { id: 'help-ov-style', textContent: `
.help-ov { position: fixed; inset: 0; z-index: 2147483000; display: grid; grid-template-rows: auto 1fr; background: var(--bg, #0e0c10); }
.help-ov-bar { display: flex; justify-content: flex-end; padding: max(8px, env(safe-area-inset-top)) max(12px, env(safe-area-inset-right)) 8px 12px; border-bottom: 1px solid var(--line, #333); }
.help-ov-bar button { min-height: 36px; padding: 0 14px; border-radius: var(--r-sm, 8px); border: 1px solid var(--line, #444); background: var(--surface, #1a171d); color: var(--text, #eee); font: inherit; cursor: pointer; }
.help-ov iframe { width: 100%; height: 100%; border: 0; background: var(--bg, #0e0c10); }` }));
  helpOv = document.createElement('div'); helpOv.className = 'help-ov'; helpOv.setAttribute('role', 'dialog'); helpOv.setAttribute('aria-label', '도움말');
  helpOv.innerHTML = '<div class="help-ov-bar"><button type="button">대기 화면으로 돌아가기</button></div><iframe src="help.html?embed=1" title="도움말"></iframe>';
  helpOv.querySelector('button').onclick = closeHelp;
  document.body.append(helpOv); document.documentElement.style.overflow = 'hidden';
}
document.addEventListener('click', e => {
  const a = e.target.closest?.('a[href="help.html"]');
  if (!a || e.ctrlKey || e.metaKey || e.shiftKey) return;
  e.preventDefault(); openHelp();
}, true);
window.addEventListener('message', e => { if (e.origin === location.origin && e.data === 'yh-help-close') closeHelp(); });
document.addEventListener('keydown', e => { if (e.key === 'Escape') closeHelp(); });
