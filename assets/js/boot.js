// 진입점: 저장된 테마를 바로 입히고, 서버가 점검 중이면 게임을 띄우지 않고 점검 페이지로 보낸다.
import { applySavedTheme } from './theme.js';
import { serverState, goMaintenance } from './config.js';

applySavedTheme();
const s = await serverState();
if (s.state === 'maintenance') goMaintenance();
else await import('./app.js');
