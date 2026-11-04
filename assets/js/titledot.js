import { store, on, rpc, midBattle, throttle } from './core.js';

let timer = null;
export async function refreshTitleDot() {
  if (!store.character) return;
  try {
    const d = await rpc('world_dot_counts');
    store.newTitles = Number(d?.titles) || 0;
    store.skillPending = Number(d?.skills) || 0;
  } catch { return; }
  paintTitleDot();
}
export function paintTitleDot() {
  const n = store.newTitles || 0, pts = Number(store.character?.stat_points || 0), sk = store.skillPending || 0;
  const label = [n > 0 ? `새 칭호 ${n}개` : '', pts > 0 ? `나누지 않은 능력치 ${pts}점` : '', sk > 0 ? `고를 기술 ${sk}개` : ''].filter(Boolean).join(' · ');
  const mark = (sel, on, text) => document.querySelectorAll(sel).forEach(a => {
    a.classList.toggle('has-dot', on);
    if (on) a.setAttribute('data-dot-label', text); else a.removeAttribute('data-dot-label');
  });
  mark('.topnav a[data-view="char"], .tabbar a[data-view="char"]', n > 0 || pts > 0 || sk > 0, label);
  mark('[data-seg="char-sub"] [data-key="skills"]', sk > 0, `고를 기술 ${sk}개`);
  mark('[data-seg="char-sub"] [data-key="titles"]', n > 0, `새 칭호 ${n}개`);
  mark('[data-seg="char-sub"] [data-key="growth"]', pts > 0, `나누지 않은 능력치 ${pts}점`);
}
export async function markTitlesSeen() {
  try { await rpc('world_title_mark_seen', { p_keys: null }); store.newTitles = 0; paintTitleDot(); } catch {}
}
export function mountTitleDot() {
  refreshTitleDot();
  const soon = throttle(refreshTitleDot, 120000);
  on('character', () => paintTitleDot());
  on('changed', ev => { if (midBattle(ev)) return; if (ev?.name === 'world_skill_choose') { setTimeout(refreshTitleDot, 300); return; } clearTimeout(timer); timer = setTimeout(soon, 1500); });
  window.addEventListener('yh-note', e => { if (/title|cosmetic/.test(e.detail?.kind || '')) setTimeout(refreshTitleDot, 500); });
}
