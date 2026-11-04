import { rpc, esc, icon, nameOf, toast, openLayer, closeLayers, closeModal } from './core.js';

export const SRC_KINDS = [['gather', '채집'], ['sites', '조사'], ['monsters', '요괴'], ['fish', '낚시']];
const oneCache = new Map(), allCache = new Map();
const cached = (m, fn, id) => { if (!m.has(id)) m.set(id, rpc(fn, { p_item: id }).catch(e => { m.delete(id); throw e; })); return m.get(id); };
export const itemSources = id => cached(oneCache, 'world_item_sources', id);
export const itemSourcesAll = id => cached(allCache, 'world_item_sources_all', id);

export const regionBtn = (r, withIcon = false) => `<button type="button" class="q-link src-go" data-src-go="${esc(r)}" title="지도에서 보기">${withIcon ? icon('map', 12) : ''}<span>${esc(nameOf(r))}</span></button>`;
export const moreBtn = (n, attrs) => n > 0 ? `<button type="button" class="q-link src-more" ${attrs}>외 ${n}곳</button>` : '';
export const sourcesMore = (id, n) => moreBtn(n, `data-src-more="${esc(id)}"`);
export const regionsMore = (title, names, shown) => moreBtn(names.length - shown, `data-region-list="${esc(JSON.stringify({ t: title, r: names }))}"`);
export const sourcePlaces = s => [...new Set(SRC_KINDS.flatMap(([k]) => s?.[k] || []))];
export const sourceTotal = s => Math.max(sourcePlaces(s).length, ...SRC_KINDS.map(([k]) => Number(s?.[`${k}_n`]) || 0));

export async function goRegion(name) {
  const { focusRegion } = await import('./views/map.js');
  closeLayers(); closeModal(); focusRegion(name); window.yahangGo('map', 'world');
}

export function openRegionList(title, sections) {
  const body = sections.filter(x => (x.names || []).length).map(x => `${x.label ? `<h3 class="sub-h">${esc(x.label)} <small class="muted">${x.names.length}곳 · 낮은 레벨부터</small></h3>` : ''}
    <div class="src-all">${x.names.map(r => regionBtn(r)).join('')}</div>`).join('') || '<p class="muted">-</p>';
  openLayer({ title, body: `<p class="muted small">지역 이름을 누르면 지도에서 짚어 줍니다.</p>${body}` });
}

export async function openAllSources(id) {
  let s;
  try { s = await itemSourcesAll(id) || {}; } catch (e) { toast(e.message, 'error'); return; }
  openRegionList(`${nameOf(id)} · 얻는 곳`, SRC_KINDS.map(([k, label]) => ({ label, names: s[k] || [] })));
}

document.addEventListener('click', e => {
  const go = e.target.closest?.('[data-src-go]'), more = e.target.closest?.('[data-src-more]'), list = e.target.closest?.('[data-region-list]');
  if (!go && !more && !list) return;
  e.preventDefault(); e.stopPropagation();
  if (go) goRegion(go.dataset.srcGo);
  else if (more) openAllSources(more.dataset.srcMore);
  else { let v; try { v = JSON.parse(list.dataset.regionList); } catch { return; } openRegionList(v.t, [{ label: '', names: v.r || [] }]); }
});
