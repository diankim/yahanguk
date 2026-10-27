// 진입점: 저장된 테마를 바로 입히고, 서버가 점검 중이면 게임을 띄우지 않고 점검 페이지로 보낸다.
import { applySavedTheme } from './theme.js';
import { serverState, goMaintenance } from './config.js';

applySavedTheme();
// 접속이 오래 걸리면(서버가 바쁘거나 처리량 한도에 걸렸을 때) 「접속 중」 화면에 까닭과 다시 시도 단추를 보인다.
// 게임 화면이 그려지면 .boot가 사라지므로 이 안내도 함께 사라진다.
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
  // 게임 파일(또는 외부 라이브러리)을 받지 못한 경우
  clearTimeout(slow1); clearTimeout(slow2);
  slowNote('게임 파일을 받지 못했습니다. 인터넷 연결을 확인한 뒤 다시 시도해 주세요.');
  console.error(e);
}
