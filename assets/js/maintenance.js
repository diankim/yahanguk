// 점검 페이지 동작: 저장된 테마를 적용하고, 30초마다 서버를 확인해 점검이 끝나면 원래 보던 화면으로 돌아간다.
import { applySavedTheme } from './theme.js';
import { serverState } from './config.js';

applySavedTheme();
const msg = document.querySelector('[data-maint-message]'), when = document.querySelector('[data-maint-checked]');
async function check() {
  const s = await serverState();
  if (msg && s.info?.message) msg.textContent = s.info.message;
  if (when) when.textContent = new Date().toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', second: '2-digit', hour12: false });
  if (s.state === 'open') {
    let back = ''; try { back = sessionStorage.getItem('yh-return') || ''; sessionStorage.removeItem('yh-return'); } catch {}
    location.replace('index.html' + back);
  }
}
check();
setInterval(() => { if (!document.hidden) check(); }, 30000);
document.addEventListener('visibilitychange', () => { if (!document.hidden) check(); });
document.querySelector('[data-maint-retry]')?.addEventListener('click', check);
