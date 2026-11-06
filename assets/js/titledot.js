import { store, on, rpc, midBattle, throttle } from './core.js';

const seenKey = k => `yh-dot-seen:${k}:${store.character?.owner_id || ''}`;
const seen = k => { try { return !!localStorage.getItem(seenKey(k)); } catch { return false; } };
const DOTS = [
  { key: 'titles', sub: 'titles', text: s => (s.newTitles || 0) > 0 && `새 칭호 ${s.newTitles}개` },
  { key: 'growth', sub: 'growth', text: s => Number(s.character?.stat_points || 0) > 0 && `나누지 않은 능력치 ${s.character.stat_points}점` },
  { key: 'skills', sub: 'skills', text: s => (s.skillPending || 0) > 0 && `고를 기술 ${s.skillPending}개` },
  { key: 'faction', sub: 'faction', once: true, text: s => (s.character?.level || 0) >= 5 && !s.character?.major_faction_id && '대세력에 들 수 있습니다' },
];

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
  const live = DOTS.map(d => ({ ...d, label: (!d.once || !seen(d.key)) && d.text(store) || '' }));
  const mark = (sel, label) => document.querySelectorAll(sel).forEach(a => {
    a.classList.toggle('has-dot', !!label);
    if (label) a.setAttribute('data-dot-label', label); else a.removeAttribute('data-dot-label');
  });
  mark('.topnav a[data-view="char"], .tabbar a[data-view="char"]', live.map(d => d.label).filter(Boolean).join(' · '));
  for (const d of live) mark(`[data-seg="char-sub"] [data-key="${d.sub}"]`, d.label);
}
export function dotSeen(sub) {
  const d = DOTS.find(x => x.sub === sub && x.once); if (!d) return;
  try { localStorage.setItem(seenKey(d.key), '1'); } catch {}
  paintTitleDot();
}
export async function markTitlesSeen() {
  try { await rpc('world_title_mark_seen', { p_keys: null }); store.newTitles = 0; paintTitleDot(); } catch {}
}
export function mountTitleDot() {
  refreshTitleDot();
  const soon = throttle(refreshTitleDot, 120000);
  on('character', () => paintTitleDot());
  on('changed', ev => { if (midBattle(ev)) return; if (ev?.name === 'world_skill_choose') { setTimeout(refreshTitleDot, 300); return; } clearTimeout(timer); timer = setTimeout(soon, 1500); });
  window.addEventListener('yh-note', e => { if (/title|cosmetic/.test(e.detail?.kind || '')) setTimeout(refreshTitleDot, 500); if (e.detail?.kind === 'faction_open') paintTitleDot(); });
}
