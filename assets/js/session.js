// 한 계정은 한 곳에서만: 새로 로그인한 브라우저가 현재 접속이 되고, 다른 브라우저는 알아채는 대로 스스로 로그아웃한다.
// 알아채는 때: 접속 기록이 바뀌는 순간(실시간), 화면·창으로 돌아올 때, 그리고 화면을 보고 있는 동안 10초마다(실시간이 끊겨도 늦지 않게).
import { db, store, rpc } from './core.js';

const NOTE = 'yh-kick-note';
let channel = null, timer = null, mounted = null, kicking = false;

// 로그인 버튼을 누르기 직전에 부른다: 로그인이 끝나 현재 접속으로 정해질 때까지 확인을 미룬다(방금 로그인한 쪽이 스스로 밀려나지 않게).
let pending = null, release = null;
export function expectLogin() { pending = new Promise(r => { release = r; }); }
export function loginFailed() { release?.(); pending = null; release = null; }
// 로그인 직후 부른다: 이 브라우저를 현재 접속으로 정하고, 다른 곳의 로그인(갱신 토큰)을 끊는다.
export async function claimSession() {
  try { await rpc('world_session_claim'); } catch {}
  try { await db.auth.signOut({ scope: 'others' }); } catch {}
  release?.(); pending = null; release = null;
}
export function takeKickNote() { try { const v = sessionStorage.getItem(NOTE) || ''; sessionStorage.removeItem(NOTE); return v; } catch { return ''; } }

async function check() {
  if (pending) await pending;
  if (kicking || !store.user || document.hidden) return;
  try { const r = await rpc('world_session_check'); if (r && r.active === false) kick(); } catch {}
}
async function kick() {
  if (kicking) return; kicking = true;
  try { sessionStorage.setItem(NOTE, '다른 기기나 브라우저에서 이 계정으로 로그인해 여기서는 로그아웃되었습니다.'); } catch {}
  stopSessionGuard();
  await logout();
  kicking = false;
}
export function mountSessionGuard() {
  const uid = store.user?.id; if (!uid || mounted === uid) return;
  stopSessionGuard(); mounted = uid;
  try {
    channel = db.channel('yh-session').on('postgres_changes', { event: '*', schema: 'public', table: 'world_active_sessions', filter: `owner_id=eq.${uid}` }, () => check()).subscribe();
  } catch {}
  timer = setInterval(check, 10000);
  check();
}
export function stopSessionGuard() {
  mounted = null; clearInterval(timer); timer = null;
  if (channel) { try { db.removeChannel(channel); } catch {} channel = null; }
}
document.addEventListener('visibilitychange', () => { if (!document.hidden && mounted) check(); });
window.addEventListener('focus', () => { if (mounted) check(); });
window.addEventListener('pageshow', () => { if (mounted) check(); });

// 로그아웃: 서버에 알리되 응답이 늦거나 막혀도 3초 안에 이 기기의 로그인을 지우고 로그인 화면으로 간다.
export async function logout() {
  stopSessionGuard();
  const local = () => {
    try { Object.keys(localStorage).filter(k => /^sb-.*-auth-token/.test(k)).forEach(k => localStorage.removeItem(k)); } catch {}
    location.replace(location.pathname + '#/home'); location.reload();
  };
  const timer = setTimeout(local, 3000);
  try { await db.auth.signOut({ scope: 'local' }); clearTimeout(timer); }
  catch { clearTimeout(timer); local(); }
}
