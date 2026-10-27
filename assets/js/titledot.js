// 새 칭호 빨간 점: 아직 확인하지 않은 칭호(world_character_titles.seen_at 없음)가 있으면 캐릭터 탭과 칭호 칸에 점을 찍는다.
// 칭호 화면을 열면 서버에 확인 처리(world_title_mark_seen)해 다른 기기에서도 점이 사라진다.
import { db, store, on, rpc, midBattle, throttle } from './core.js';

let timer = null;
export async function refreshTitleDot() {
  if (!store.character) return;
  try {
    const { count, error } = await db.from('world_character_titles').select('title_key', { count: 'exact', head: true }).is('seen_at', null);
    if (error) return;
    store.newTitles = count || 0;
  } catch { return; }
  paintTitleDot();
}
export function paintTitleDot() {
  const n = store.newTitles || 0;
  document.querySelectorAll('.topnav a[data-view="char"], .tabbar a[data-view="char"], [data-seg="char-sub"] [data-key="titles"]').forEach(a => {
    a.classList.toggle('has-dot', n > 0);
    if (n > 0) a.setAttribute('data-dot-label', `새 칭호 ${n}개`); else a.removeAttribute('data-dot-label');
  });
}
export async function markTitlesSeen() {
  try { await rpc('world_title_mark_seen', { p_keys: null }); store.newTitles = 0; paintTitleDot(); } catch {}
}
export function mountTitleDot() {
  refreshTitleDot();
  // 칭호는 행동 끝에 서버가 판정하므로, 행동 뒤에 잠시 기다렸다가 한 번 센다.
  const soon = throttle(refreshTitleDot, 20000); // 20초에 한 번까지, 전투 턴 중은 빼고
  on('changed', ev => { if (midBattle(ev)) return; clearTimeout(timer); timer = setTimeout(soon, 1500); });
}
