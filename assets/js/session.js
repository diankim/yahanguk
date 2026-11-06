import { db, store, rpc } from './core.js';
import { selfReload } from './config.js';

const NOTE = 'yh-kick-note';
let bchannel = null, timer = null, mounted = null, kicking = false;

let pending = null, release = null;
export function expectLogin() { pending = new Promise(r => { release = r; }); }
export function loginFailed() { release?.(); pending = null; release = null; }
export async function claimSession() {
  try { await rpc('world_session_claim'); } catch {}
  try { await db.auth.signOut({ scope: 'others' }); } catch {}
  release?.(); pending = null; release = null;
}
export function takeKickNote() { try { const v = sessionStorage.getItem(NOTE) || ''; sessionStorage.removeItem(NOTE); return v; } catch { return ''; } }

let lastCheck = 0, blive = false, relistenAt = 0;
async function check(force = false) {
  if (pending) await pending;
  if (kicking || !store.user || document.hidden) return;
  if (!force && Date.now() - lastCheck < 10000) return;
  lastCheck = Date.now();
  try { const r = await rpc('world_session_check'); if (r && r.active === false) kick(); }
  catch (e) {
    if (/로그인이 필요합니다|권한이 없습니다/.test(String(e?.message || e || ''))) kick();
  }
}
async function kick() {
  if (kicking) return; kicking = true;
  stopSessionGuard();
  await logout('다른 기기나 브라우저에서 이 계정으로 로그인해 여기서는 로그아웃되었습니다.');
  kicking = false;
}
export function mountSessionGuard() {
  const uid = store.user?.id; if (!uid || mounted === uid) return;
  stopSessionGuard(); mounted = uid;
  setTimeout(() => listen(uid), 0);
  timer = setInterval(() => { if (!blive || Date.now() - lastCheck > 300000) check(); }, 60000);
  check(true);
}
async function listen(uid) {
  try {
    const t = (await db.auth.getSession()).data.session?.access_token;
    if (!t || mounted !== uid) return;
    await db.realtime.setAuth(t);
  } catch { return; }
  if (mounted !== uid || bchannel) return;
  try {
    const ch = db.channel(`session:${uid}`, { config: { private: true } }).on('broadcast', { event: 'claim' }, () => check(true));
    bchannel = ch;
    ch.subscribe(status => {
      if (bchannel !== ch) return;
      blive = status === 'SUBSCRIBED';
      if (blive || mounted !== uid || !/^(CHANNEL_ERROR|TIMED_OUT|CLOSED)$/.test(status)) return;
      bchannel = null; try { db.removeChannel(ch); } catch {}
      const wait = Math.max(3000, 60000 - (Date.now() - relistenAt));
      relistenAt = Date.now() + wait;
      setTimeout(() => { if (mounted === uid && !bchannel) listen(uid); }, wait);
    });
  } catch {}
}
export function stopSessionGuard() {
  mounted = null; blive = false; clearInterval(timer); timer = null;
  if (bchannel) { try { db.removeChannel(bchannel); } catch {} bchannel = null; }
}
document.addEventListener('visibilitychange', () => { if (!document.hidden && mounted) check(); });
window.addEventListener('focus', () => { if (mounted) check(); });
window.addEventListener('pageshow', () => { if (mounted) check(); });
window.addEventListener('yh-auth-lost', () => { if (mounted) check(true); });

export async function logout(note = '') {
  stopSessionGuard();
  const local = () => {
    try { Object.keys(localStorage).filter(k => /^sb-.*-auth-token/.test(k)).forEach(k => localStorage.removeItem(k)); } catch {}
    if (note) try { sessionStorage.setItem(NOTE, note); } catch {}
    location.replace(location.pathname + '#/home'); selfReload('logout');
  };
  const timer = setTimeout(local, 3000);
  try { await db.auth.signOut({ scope: 'local' }); } catch {}
  clearTimeout(timer); local();
}
