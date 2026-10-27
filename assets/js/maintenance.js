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
    until.textContent = t && !isNaN(t) ? t.toLocaleString('ko-KR', { month: 'long', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }) + ' 무렵' : '끝나는 대로 열립니다';
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
