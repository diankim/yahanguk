export const idOf = (kind, k) => (kind === 'paper' ? 'hp_' : kind === 'ground' ? 'hg_' : 'hf_') + k;
export const isFurniture = id => /^h[fpg]_/.test(String(id || ''));

export function placedCounts(st) {
  const m = {};
  const add = id => { m[id] = (m[id] || 0) + 1; };
  (st?.items || []).forEach(i => add(idOf('fur', i.k)));
  (st?.wall || []).forEach(w => add(idOf('wall', w.k)));
  if (st?.paper) add(idOf('paper', st.paper));
  if (st?.ground) add(idOf('ground', st.ground));
  (st?.rooms || []).forEach(r => { if (!r.room || !r.open) return; if (r.paper) add(idOf('paper', r.paper)); if (r.ground) add(idOf('ground', r.ground)); });
  return m;
}

export function homeCounts(snap) {
  const placed = snap?.open ? placedCounts(snap) : {}, stored = {};
  for (const [id, n] of Object.entries(snap?.store || {})) if (Number(n) > 0) stored[id] = Number(n);
  return { placed, stored };
}

let mine = null;
export function rememberHome(snap) {
  if (snap) mine = { at: Date.now(), c: homeCounts(snap) };
}
export function forgetHome() { mine = null; }
export async function myHomeCounts(rpc) {
  if (mine && Date.now() - mine.at < 120000) return mine.c;
  const s = await rpc('world_housing_snapshot', { p_owner: null });
  mine = { at: Date.now(), c: homeCounts(s) };
  return mine.c;
}
