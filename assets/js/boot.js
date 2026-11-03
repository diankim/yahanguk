import { applySavedTheme } from './theme.js';
import { serverState, goMaintenance } from './config.js';

applySavedTheme();
function slowNote(text) {
  const boot = document.querySelector('#app .boot'); if (!boot) return;
  let n = boot.querySelector('.boot-note');
  if (!n) {
    n = document.createElement('div'); n.className = 'boot-note';
    n.innerHTML = '<p></p><button class="btn small" type="button">다시 시도</button>';
    n.querySelector('button').onclick = () => location.reload();
    boot.append(n);
  }
  n.querySelector('p').textContent = text;
}
const slow1 = setTimeout(() => slowNote('서버 응답이 늦어지고 있습니다. 잠시만 기다려 주세요.'), 8000);
const slow2 = setTimeout(() => slowNote('서버가 몹시 바쁩니다(무료 서버의 처리량 한도에 걸렸을 수 있습니다). 계속 기다리면 이어서 들어가고, 몇 분 뒤 다시 시도해도 됩니다.'), 25000);
window.addEventListener('yh-booted', () => { clearTimeout(slow1); clearTimeout(slow2); }, { once: true });
try {
  const s = await serverState();
  if (s.state === 'maintenance') goMaintenance();
  else await import('./app.js');
} catch (e) {
  clearTimeout(slow1); clearTimeout(slow2);
  slowNote('게임 파일을 받지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.');
  console.error(e);
}
