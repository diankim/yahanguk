// 지도: 세계 지도(확대·축소·이동, 겹침 없는 이름표) · 세부 탐사 · 이동과 원정.
import { store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, toast } from '../core.js';
import { load, panel, chip, danger, loading, errorBox, currentRegion, invalidate, safeZones } from './common.js';

const SUBS = [['world', '세계 지도'], ['travel', '이동·탈것']];
let el, sub = 'world', off = [], selected = null, view = null, mapData = null, mountData = null, partyData = null, zones = new Map();

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'world';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('map', 14)} 세계</p><h1>지도</h1></div></div>
    ${segmented('map-sub', SUBS, sub)}<div id="map-body"></div>`;
  bindSegmented(el, 'map-sub', k => { sub = k; history.replaceState(null, '', `#/map/${k}`); draw(); });
  off.forEach(f => f());
  off = [on('changed', () => draw(true))];
  window.addEventListener('yahang:arrived', onArrive);
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; window.removeEventListener('yahang:arrived', onArrive); window.removeEventListener('resize', onResize); }
function onArrive() { draw(true); }

async function draw(soft = false) {
  const body = $('#map-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try {
    if (sub === 'world') await drawWorld(body, soft);
    else await drawTravel(body);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

/* ── 세계 지도 ───────────────────────────────────────────── */
async function drawWorld(body, soft) {
  [mapData, mountData, partyData, zones] = await Promise.all([
    load('world_map_snapshot', undefined, { maxAge: 30000 }),
    load('world_mount_snapshot', undefined, { maxAge: 60000 }).catch(() => null),
    load('world_party_overview', undefined, { maxAge: 30000 }).catch(() => null),
    safeZones().catch(() => new Map()),
  ]);
  const here = currentRegion(mapData);
  if (!selected || !mapData.regions.some(r => r.region_id === selected)) selected = here?.region_id || mapData.regions[0]?.region_id;
  const keepScroll = soft && $('#region-q', body)?.value;
  body.innerHTML = `
    <div class="map-layout">
      <div class="map-frame" id="map-frame">
        <svg id="map-svg" role="img" aria-label="세계 지도"></svg>
        <div class="map-tools">
          <button class="icon-btn" data-zoom="in" aria-label="확대">${icon('plus')}</button>
          <button class="icon-btn" data-zoom="out" aria-label="축소">${icon('minus')}</button>
          <button class="icon-btn" data-zoom="here" aria-label="현재 위치로">${icon('target')}</button>
          <button class="icon-btn" data-zoom="fit" aria-label="전체 보기">${icon('refresh')}</button>
        </div>
        <div class="map-legend"><span><i class="lg here"></i>현재 위치</span><span><i class="lg near"></i>이동 가능</span><span><i class="lg far"></i>경유 필요</span><span><i class="lg lock"></i>레벨 부족</span><span><i class="lg safe"></i>안전지대</span></div>
      </div>
      <div class="map-side" id="map-detail"></div>
    </div>
    ${panel('지역 목록', `<div class="search"><span>${icon('search', 16)}</span><input id="region-q" placeholder="지역 이름 검색" autocomplete="off" value="${esc(keepScroll || '')}"></div>
      ${segmented('region-filter', [['near', '이동 가능'], ['all', '전체']], 'near')}<ul class="region-list" id="region-list"></ul>`, { ico: 'pin' })}`;
  setupMap(here);
  drawDetail();
  let filter = 'near';
  const list = () => drawList(filter, $('#region-q', body).value.trim());
  $('#region-q', body).oninput = list;
  bindSegmented(body, 'region-filter', k => { filter = k; list(); });
  list();
}

function bounds() {
  const xs = mapData.regions.map(r => r.world_x), ys = mapData.regions.map(r => r.world_y);
  const pad = 40;
  return { x: Math.min(...xs) - pad, y: Math.min(...ys) - pad, w: Math.max(...xs) - Math.min(...xs) + pad * 2, h: Math.max(...ys) - Math.min(...ys) + pad * 2 };
}
// view: 월드 좌표의 보이는 영역 중심(cx, cy)과 배율(k, 화면 px / 월드 단위)
function setupMap(here) {
  const frame = $('#map-frame', el), svg = $('#map-svg', el);
  const b = bounds();
  const fitK = () => Math.min(frame.clientWidth / b.w, frame.clientHeight / b.h);
  if (!view) {
    const k = fitK() * (frame.clientWidth < 520 ? 2.4 : 1.8);
    view = { cx: here?.world_x ?? b.x + b.w / 2, cy: here?.world_y ?? b.y + b.h / 2, k };
  }
  const minK = () => fitK() * 0.9, maxK = () => fitK() * 6;
  const clamp = () => {
    view.k = Math.max(minK(), Math.min(maxK(), view.k));
    view.cx = Math.max(b.x, Math.min(b.x + b.w, view.cx));
    view.cy = Math.max(b.y, Math.min(b.y + b.h, view.cy));
  };
  const zoomAt = (factor, sx, sy) => {
    const W = frame.clientWidth, H = frame.clientHeight;
    const wx = view.cx + (sx - W / 2) / view.k, wy = view.cy + (sy - H / 2) / view.k;
    view.k *= factor; clamp();
    view.cx = wx - (sx - W / 2) / view.k; view.cy = wy - (sy - H / 2) / view.k; clamp();
    paint();
  };
  frame.querySelectorAll('[data-zoom]').forEach(btn => btn.onclick = () => {
    const z = btn.dataset.zoom, W = frame.clientWidth, H = frame.clientHeight;
    if (z === 'in') zoomAt(1.4, W / 2, H / 2);
    else if (z === 'out') zoomAt(1 / 1.4, W / 2, H / 2);
    else if (z === 'fit') { view = { cx: b.x + b.w / 2, cy: b.y + b.h / 2, k: fitK() }; paint(); }
    else { const r = currentRegion(mapData); if (r) { view.cx = r.world_x; view.cy = r.world_y; view.k = Math.max(view.k, fitK() * 2); clamp(); paint(); } }
  });
  frame.addEventListener('wheel', e => { e.preventDefault(); const r = frame.getBoundingClientRect(); zoomAt(e.deltaY < 0 ? 1.15 : 1 / 1.15, e.clientX - r.left, e.clientY - r.top); }, { passive: false });

  // 드래그 이동과 두 손가락 확대
  const pts = new Map(); let pinch = null, moved = 0;
  svg.addEventListener('pointerdown', e => { svg.setPointerCapture(e.pointerId); pts.set(e.pointerId, { x: e.clientX, y: e.clientY }); moved = 0; if (pts.size === 2) pinch = dist(); });
  svg.addEventListener('pointermove', e => {
    const p = pts.get(e.pointerId); if (!p) return;
    const dx = e.clientX - p.x, dy = e.clientY - p.y; p.x = e.clientX; p.y = e.clientY;
    if (pts.size === 2 && pinch) {
      const d = dist(), r = frame.getBoundingClientRect(), [a, c] = [...pts.values()];
      zoomAt(d / pinch, (a.x + c.x) / 2 - r.left, (a.y + c.y) / 2 - r.top); pinch = d;
    } else if (pts.size === 1) {
      moved += Math.abs(dx) + Math.abs(dy);
      view.cx -= dx / view.k; view.cy -= dy / view.k; clamp(); paint();
    }
  });
  const up = e => { pts.delete(e.pointerId); if (pts.size < 2) pinch = null; };
  svg.addEventListener('pointerup', e => {
    const wasTap = moved < 6 && pts.size === 1; up(e);
    if (!wasTap) return;
    const node = document.elementsFromPoint(e.clientX, e.clientY).find(n => n.dataset?.region);
    if (node) select(node.dataset.region, false);
  });
  svg.addEventListener('pointercancel', up);
  function dist() { const [a, c] = [...pts.values()]; return Math.hypot(a.x - c.x, a.y - c.y) || 1; }
  svg.addEventListener('keydown', e => { if (e.key === 'Enter' && e.target.dataset?.region) select(e.target.dataset.region, false); });
  window.removeEventListener('resize', onResize); window.addEventListener('resize', onResize);
  paint();
}
function onResize() { if ($('#map-svg', el)) paint(); }

function paint() {
  const frame = $('#map-frame', el), svg = $('#map-svg', el); if (!frame || !svg) return;
  const W = frame.clientWidth, H = frame.clientHeight;
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`); svg.setAttribute('width', W); svg.setAttribute('height', H);
  const P = r => [(r.world_x - view.cx) * view.k + W / 2, (r.world_y - view.cy) * view.k + H / 2];
  const regions = mapData.regions, byId = new Map(regions.map(r => [r.region_id, r]));
  const here = currentRegion(mapData), dest = store.character?.travel_destination;
  const seen = new Set();
  let edges = '';
  for (const r of regions) for (const f of r.travel_from || []) {
    const o = byId.get(f); if (!o) continue;
    const key = [r.region_id, f].sort().join('|'); if (seen.has(key)) continue; seen.add(key);
    const [x1, y1] = P(r), [x2, y2] = P(o);
    const live = here && (r.region_id === here.region_id || f === here.region_id);
    edges += `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" class="edge ${live ? 'live' : ''}"/>`;
  }
  // 이름표 겹침 제거: 중요한 지역부터 자리를 잡고, 자리가 없으면 이름을 숨긴다(눌러서 확인 가능).
  const fs = W < 520 ? 12 : 13;
  const rank = r => r.region_id === selected ? 0 : r.region_id === here?.region_id ? 1 : r.region_id === dest ? 2 : r.reachable ? 3 : r.level_locked ? 6 : 4;
  const order = [...regions].sort((a, b) => rank(a) - rank(b) || (b.visits || 0) - (a.visits || 0));
  const boxes = regions.map(r => { const [x, y] = P(r); return { x: x - 9, y: y - 9, w: 18, h: 18 }; });
  // 확대 버튼과 범례 영역에는 이름표를 두지 않는다.
  boxes.push({ x: W - 60, y: 0, w: 60, h: 190 }, { x: 0, y: H - (W < 520 ? 50 : 30), w: W, h: 50 });
  const hit = b => b.x < 0 || b.y < 0 || b.x + b.w > W || b.y + b.h > H || boxes.some(o => b.x < o.x + o.w && b.x + b.w > o.x && b.y < o.y + o.h && b.y + b.h > o.y);
  const labels = new Map();
  for (const r of order) {
    const [x, y] = P(r); if (x < -20 || y < -20 || x > W + 20 || y > H + 20) continue;
    const w = [...r.region_name].length * fs * 0.98 + 10, hgt = fs + 8;
    const tries = [[x + 12, y - hgt / 2, 'start'], [x - 12 - w, y - hgt / 2, 'end'], [x - w / 2, y - 14 - hgt, 'middle'], [x - w / 2, y + 14, 'middle']];
    const must = rank(r) <= 1;
    let placed = null;
    for (const [bx, by, anchor] of tries) { const box = { x: bx, y: by, w, h: hgt }; if (!hit(box)) { placed = { box, anchor }; break; } }
    if (!placed && must) placed = { box: { x: tries[0][0], y: tries[0][1], w, h: hgt }, anchor: 'start' };
    if (placed) { boxes.push(placed.box); labels.set(r.region_id, placed); }
  }
  let nodes = '', texts = '';
  for (const r of regions) {
    const [x, y] = P(r); if (x < -30 || y < -30 || x > W + 30 || y > H + 30) continue;
    const cls = r.region_id === here?.region_id ? 'here' : r.level_locked ? 'lock' : r.reachable ? 'near' : 'far';
    const sel = r.region_id === selected ? ' sel' : '', dz = Number(r.danger_level) >= 7 ? ' hot' : '', sz = zones.get(r.region_id)?.is_safe_zone ? ' safe' : '';
    nodes += `<g class="node ${cls}${sel}${dz}${sz}" data-region="${esc(r.region_id)}" tabindex="0" role="button" aria-label="${esc(r.region_name)}">
      <circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="16" class="hitbox" data-region="${esc(r.region_id)}"/>
      ${sz ? `<rect x="${(x - 10).toFixed(1)}" y="${(y - 10).toFixed(1)}" width="20" height="20" rx="5" class="safe-ring"/>` : ''}
      ${r.region_id === dest ? `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="11" class="dest-ring"/>` : ''}
      <circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${sel ? 8 : 6}" class="dot" data-region="${esc(r.region_id)}"/><title>${esc(r.region_name)}</title></g>`;
    const l = labels.get(r.region_id);
    if (l) {
      const tx = l.anchor === 'start' ? l.box.x + 4 : l.anchor === 'end' ? l.box.x + l.box.w - 4 : l.box.x + l.box.w / 2;
      texts += `<text x="${tx.toFixed(1)}" y="${(l.box.y + l.box.h / 2).toFixed(1)}" text-anchor="${l.anchor}" dominant-baseline="central" class="lbl ${cls}${sel}" style="font-size:${fs}px" data-region="${esc(r.region_id)}">${esc(r.region_name)}</text>`;
    }
  }
  svg.innerHTML = `<g class="edges">${edges}</g><g class="labels">${texts}</g><g class="nodes">${nodes}</g>`;
}

function select(id, center) {
  selected = id;
  if (center) { const r = mapData.regions.find(x => x.region_id === id); if (r) { view.cx = r.world_x; view.cy = r.world_y; } }
  paint(); drawDetail();
  if (matchMedia('(max-width: 1099px)').matches) $('#map-detail', el)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' });
}

function travelEstimate(from, to) {
  const m = (mountData?.mounts || []).find(x => x.equipped) || (mountData?.mounts || []).find(x => x.mount_id === store.character?.mount_id);
  const speed = Number(m?.speed_multiplier) || 1;
  const d = Math.hypot(to.world_x - from.world_x, to.world_y - from.world_y);
  const terr = Math.max(Number(from.terrain_cost) || 1, Number(to.terrain_cost) || 1);
  const cross = from.territory_id && to.territory_id && from.territory_id !== to.territory_id ? 1.35 : 1;
  const secs = Math.max(12, Math.min(1800, Math.round((d * 2.2 + Math.abs((to.elevation || 0) - (from.elevation || 0)) * 9 + 15) * terr * cross / speed)));
  return { secs, mount: m };
}

function drawDetail() {
  const box = $('#map-detail', el); if (!box) return;
  const r = mapData.regions.find(x => x.region_id === selected); if (!r) { box.innerHTML = ''; return; }
  const c = store.character, here = currentRegion(mapData);
  const isHere = here?.region_id === r.region_id;
  const traveling = c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date();
  const est = here && !isHere ? travelEstimate(here, r) : null;
  const fare = est?.mount ? (est.mount.fare_free ? '운임 없음' : `노정패 ${est.mount.fare_tokens}개`) : '';
  let reason = '';
  if (isHere) reason = '현재 머무는 지역입니다.';
  else if (traveling) reason = '이미 이동 중입니다. 도착하거나 취소한 뒤 출발할 수 있습니다.';
  else if (r.level_locked) reason = `Lv.${r.min_level} 이상부터 들어갈 수 있습니다.`;
  else if (!r.reachable) reason = '인접한 지역이 아닙니다. 선으로 이어진 지역을 거쳐 이동하세요.';
  const members = (partyData?.members || []).filter(m => m.owner_id !== c.owner_id && m.location === c.location && !m.in_combat && !m.downed);
  const isLeader = partyData?.party?.leader_id === c.owner_id;
  const monsters = (r.monsters || []).slice(0, 3);
  box.innerHTML = `
    <article class="panel region-detail">
      <header class="panel-head"><h2>${esc(r.region_name)}</h2>${isHere ? chip('현재 위치', 'accent') : ''}</header>
      <div class="panel-body">
        <div class="chips">${zones.get(r.region_id)?.is_safe_zone ? chip('안전지대', 'ok') : danger(r.danger_level)}${chip(nameOf(r.region_type))}${chip(`Lv.${r.min_level}+`)}${r.territory_name ? chip(r.territory_name) : ''}</div>
        ${zones.get(r.region_id)?.is_safe_zone ? `<p class="hint ok">${icon('shield', 14)} ${esc(zones.get(r.region_id).shop_name || '상점')} · 거래소${zones.get(r.region_id).has_stable ? ' · 마구간' : ''} · 전투 없음</p>` : ''}
        <p class="desc">${esc(r.description || '')}</p>
        <dl class="kv">
          <div><dt>채집</dt><dd>${(r.gather_nodes || []).length ? esc(r.gather_nodes.map(nameOf).join(', ')) : '없음'}</dd></div>
          <div><dt>요괴</dt><dd>${monsters.length ? monsters.map(m => esc(m.monster_name)).join(', ') : '미확인'}</dd></div>
          <div><dt>지배 세력</dt><dd>${esc(r.faction_control || '없음')}</dd></div>
          ${est ? `<div><dt>예상 이동</dt><dd>약 ${fmt.remain(est.secs * 1000)} · ${esc(fare)}</dd></div>` : ''}
        </dl>
        ${reason ? `<p class="hint">${icon('eye', 14)} ${esc(reason)}</p>` : ''}
        <div class="btn-row">
          <button class="btn primary" id="travel-go" ${reason ? 'disabled' : ''}>${icon('route', 16)}<span>이곳으로 이동</span></button>
          ${isHere ? `<button class="btn" id="go-field">${icon('home', 16)}<span>현장으로</span></button>` : ''}
        </div>
        ${!reason && isLeader && members.length ? `<div class="ride"><p class="muted small">파티원에게 동승을 요청하면 수락 즉시 함께 출발합니다. 운임은 파티장만 1회 부담합니다.</p>
          <div class="btn-row">${members.map(m => `<button class="btn small" data-ride="${esc(m.owner_id)}">${icon('users', 14)}<span>${esc(m.character_name)} 동승 요청</span></button>`).join('')}</div></div>` : ''}
        <p class="muted small">이동 시간은 거리·고도·지형·탈것 속도로 정해지며 표시값은 예상치입니다. 서버가 실제 도착 시각을 정합니다.</p>
      </div>
    </article>`;
  const go = $('#travel-go', box);
  if (go) go.onclick = () => guard(go, async () => { const out = await act('world_travel_region', { p_region_id: r.region_id }); invalidate('world_map_snapshot'); return out; });
  $('#go-field', box)?.addEventListener('click', () => window.yahangGo('home'));
  $$('[data-ride]', box).forEach(b => b.onclick = () => guard(b, () => act('world_travel_party_invite_v2', { p_passenger_id: b.dataset.ride, p_region_id: r.region_id }), { success: '동승 요청을 보냈습니다. 상대가 수락하면 함께 출발합니다.' }));
}

function drawList(filter, q) {
  const ul = $('#region-list', el); if (!ul) return;
  const here = currentRegion(mapData);
  let rows = mapData.regions.filter(r => !q || r.region_name.includes(q));
  if (filter === 'near' && !q) rows = rows.filter(r => r.reachable || r.region_id === here?.region_id);
  rows.sort((a, b) => (b.region_id === here?.region_id) - (a.region_id === here?.region_id) || (b.reachable - a.reachable) || a.min_level - b.min_level);
  ul.innerHTML = rows.length ? rows.map(r => `<li><button data-pick="${esc(r.region_id)}" class="${r.region_id === selected ? 'on' : ''}">
      <span class="rl-name">${esc(r.region_name)}</span>
      <span class="rl-meta">${r.region_id === here?.region_id ? '현재 위치' : r.level_locked ? `Lv.${r.min_level} 필요` : r.reachable ? '이동 가능' : '경유 필요'} · 위험 ${r.danger_level}</span></button></li>`).join('')
    : `<li class="muted small">조건에 맞는 지역이 없습니다.</li>`;
  ul.onclick = e => { const b = e.target.closest('[data-pick]'); if (!b) return; select(b.dataset.pick, true); $$('button', ul).forEach(x => x.classList.toggle('on', x === b)); $('#map-frame', el)?.scrollIntoView({ block: 'nearest', behavior: 'smooth' }); };
}

/* ── 이동 · 탈것 · 동승 ───────────────────────────────── */
async function drawTravel(body) {
  const [status, mounts, ride] = await Promise.all([
    load('world_travel_status'), load('world_mount_snapshot'), load('world_travel_party_snapshot').catch(() => null),
  ]);
  const c = store.character, me = c.owner_id;
  const incoming = (ride?.requests || []).filter(r => r.passenger_id === me && r.status === 'pending');
  const outgoing = (ride?.requests || []).filter(r => r.leader_id === me && r.status === 'pending');
  const owned = (mounts?.mounts || []).filter(m => m.owned), others = (mounts?.mounts || []).filter(m => !m.owned);
  const arrives = status?.travel_arrives_at ? new Date(status.travel_arrives_at).getTime() : 0;
  body.innerHTML = `
    <div class="grid-2">
      ${panel('이동 상태', status?.in_transit ? `
        <div class="notice travel">${icon('route', 18)}<div><b>${esc(nameOf(status.travel_destination))}(으)로 이동 중</b><span data-arrive="${arrives}">${fmt.remain(arrives - Date.now())} 후 도착</span></div></div>
        <button class="btn" id="tr-cancel">${icon('close', 16)}<span>이동 취소 (위약금 5전)</span></button>
        <p class="muted small">동승 중이라도 내 이동은 따로 취소할 수 있습니다.</p>`
        : `<p class="desc">현재 <b>${esc(status?.location || c.location)}</b>에 있습니다. 세계 지도에서 선으로 이어진 지역을 골라 이동하세요.</p>
           <button class="btn primary" id="tr-map">${icon('map', 16)}<span>세계 지도 열기</span></button>`, { ico: 'route' })}
      ${panel('동승 요청', `
        ${incoming.length ? `<ul class="spot-list">${incoming.map(r => `<li><div><b>${esc(nameOf(r.to_region))}</b><small>파티장의 동승 제안 · 운임은 파티장이 냅니다</small></div>
          <div class="btn-row"><button class="btn small primary" data-ride="${esc(r.request_id)}" data-accept="1">수락</button><button class="btn small" data-ride="${esc(r.request_id)}" data-accept="0">거절</button></div></li>`).join('')}</ul>` : ''}
        ${outgoing.length ? `<p class="muted small">보낸 요청 ${outgoing.length}건이 응답을 기다리는 중입니다.</p>` : ''}
        ${!incoming.length && !outgoing.length ? empty('대기 중인 동승 요청이 없습니다.', 'users') : ''}
        <p class="muted small">동승은 같은 파티원끼리만 됩니다. 파티장이 지도에서 목적지를 고르고 요청하면, 수락하는 순간 함께 출발합니다. 전투·원정 중에는 출발할 수 없습니다.</p>`, { ico: 'users' })}
    </div>
    ${panel('내 탈것', `<div class="mount-grid">${owned.map(m => `
      <article class="mount ${m.equipped ? 'on' : ''}">
        <header><b>${esc(m.mount_name)}</b>${chip(m.tier)}</header>
        <p>${esc(m.description || '')}</p>
        <dl class="kv tight"><div><dt>속도</dt><dd>×${m.speed_multiplier}</dd></div><div><dt>정원</dt><dd>${m.passenger_capacity}명</dd></div><div><dt>운임</dt><dd>${m.fare_free ? '없음' : `노정패 ${m.fare_tokens}`}</dd></div></dl>
        ${m.equipped ? chip('사용 중', 'accent') : `<button class="btn small" data-equip="${esc(m.mount_id)}">이 탈것 타기</button>`}
      </article>`).join('')}</div>
      <p class="muted small">노정패 ${fmt.num(mounts?.mount_tokens)}개 · 운임이 있는 탈것은 출발할 때 노정패를 씁니다. 노정패는 이동과 토벌로 얻습니다.</p>`, { ico: 'route' })}
    ${panel('얻을 수 있는 탈것', others.length ? `<ul class="spot-list">${others.map(m => `<li><div><b>${esc(m.mount_name)}</b>
        <small>${m.acquire_method === 'event' ? '특별한 사건으로만 얻을 수 있습니다' : `${esc(m.unlock_region_name || '안전지대')} 마구간 · ${fmt.jeon(m.price)}`} · 속도 ×${m.speed_multiplier} · 정원 ${m.passenger_capacity}</small></div>
        ${m.acquire_method === 'stable' && m.unlock_region ? `<button class="btn small ghost" data-goto="${esc(m.unlock_region)}">지도에서 보기</button>` : ''}</li>`).join('')}</ul>` : empty('모든 탈것을 가지고 있습니다.'), { ico: 'shop' })}`;

  $('#tr-map', body)?.addEventListener('click', () => switchTo('world'));
  const cancel = $('#tr-cancel', body);
  if (cancel) cancel.onclick = () => { if (confirm('이동을 취소할까요? 위약금 5전이 소모됩니다.')) guard(cancel, () => act('world_travel_cancel')); };
  $$('[data-ride]', body).forEach(b => b.onclick = () => guard(b, () => act('world_travel_party_respond_v2', { p_request_id: b.dataset.ride, p_accept: b.dataset.accept === '1' })));
  $$('[data-equip]', body).forEach(b => b.onclick = () => guard(b, () => act('world_mount_equip', { p_mount_id: b.dataset.equip })));
  $$('[data-goto]', body).forEach(b => b.onclick = () => { selected = b.dataset.goto; view = null; switchTo('world'); });
  const span = $('[data-arrive]', body);
  if (span) { const t = setInterval(() => { if (!span.isConnected) return clearInterval(t); span.textContent = `${fmt.remain(Number(span.dataset.arrive) - Date.now())} 후 도착`; }, 1000); }
}
function switchTo(k) { sub = k; history.replaceState(null, '', `#/map/${k}`); render(el, k); }
// 다른 화면(사건 바로가기 등)에서 특정 지역을 골라 지도를 열 때 쓴다.
export function focusRegion(id) { selected = id; view = null; }
