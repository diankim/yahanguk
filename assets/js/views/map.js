// 지도: 세계 지도(확대·축소·이동, 겹침 없는 이름표) · 세부 탐사 · 이동과 원정.
import { store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, toast } from '../core.js';
import { load, panel, chip, danger, loading, errorBox, currentRegion, invalidate, safeZones } from './common.js';
import { buildCells, centroid, factionColor, FACTION_COLORS } from '../geo.js';

const SUBS = [['world', '세계 지도'], ['travel', '이동·탈것']];
let el, sub = 'world', off = [], selected = null, view = null, mapData = null, mountData = null, partyData = null, zones = new Map();

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'world';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('map', 14)} 세계</p><h1>지도</h1></div></div>
    ${segmented('map-sub', SUBS, sub)}<div id="map-body"></div>`;
  bindSegmented(el, 'map-sub', k => { sub = k; history.replaceState(null, '', `#/map/${k}`); draw(); });
  off.forEach(f => f());
  off = [on('changed', () => draw(true)), on('env', () => draw(true))];
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
        <div class="map-peek" id="map-peek" hidden></div>
        <div class="map-legend"><span><i class="lg here"></i>현재 위치</span><span><i class="lg safe"></i>안전지대</span><span><i class="lg lock"></i>레벨 부족</span><span><i class="lg route"></i>경로</span></div>
      </div>
      <div class="map-side" id="map-detail"></div>
    </div>
    <details class="panel fold"><summary class="panel-head"><h2>${icon('pin', 16)}지역 찾기</h2></summary><div class="panel-body"><div class="search"><span>${icon('search', 16)}</span><input id="region-q" placeholder="지역 이름 검색" autocomplete="off" value="${esc(keepScroll || '')}"></div>
      ${segmented('region-filter', [['near', '이웃 지역'], ['all', '전체']], 'near')}<ul class="region-list" id="region-list"></ul></div></details>
    ${factionLegend()}`;
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
  const pts = new Map(); let pinch = null, moved = 0, gesture = false;
  svg.addEventListener('pointerdown', e => { svg.setPointerCapture(e.pointerId); pts.set(e.pointerId, { x: e.clientX, y: e.clientY }); if (pts.size === 1) { moved = 0; gesture = false; } if (pts.size >= 2) { pinch = dist(); gesture = true; } });
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
    // 두 손가락 확대가 끝날 때 마지막 손가락을 떼는 것은 누르기로 치지 않는다.
    const wasTap = moved < 6 && pts.size === 1 && !gesture; up(e);
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

// 땅 모양은 좌표가 바뀌지 않는 한 한 번만 계산한다.
let geom = null, geomKey = '';
function geometry() {
  const key = mapData.regions.map(r => `${r.region_id}:${r.world_x},${r.world_y}`).join('|');
  if (key !== geomKey) { geom = buildCells(mapData.regions); geomKey = key; }
  return geom;
}
function factionOf(id) { return zones.get(id)?.control_faction_id ?? null; }

// 지금 위치에서 목적지까지 이어진 길(경과 지역 목록). 레벨이 모자란 지역은 지나가지 않는다.
export function routeTo(target) {
  const here = currentRegion(mapData); if (!here || !mapData) return null;
  const byId = new Map(mapData.regions.map(r => [r.region_id, r]));
  const dist = new Map([[here.region_id, 0]]), prev = new Map(), todo = new Set(mapData.regions.map(r => r.region_id));
  while (todo.size) {
    let u = null, best = Infinity;
    for (const id of todo) { const d = dist.get(id) ?? Infinity; if (d < best) { best = d; u = id; } }
    if (u == null || best === Infinity) break;
    todo.delete(u);
    if (u === target) break;
    const a = byId.get(u);
    for (const v of a.travel_from || []) {
      const b = byId.get(v); if (!b || !todo.has(v) || (b.level_locked && v !== target)) continue;
      const nd = best + Math.hypot(a.world_x - b.world_x, a.world_y - b.world_y);
      if (nd < (dist.get(v) ?? Infinity)) { dist.set(v, nd); prev.set(v, u); }
    }
  }
  if (!dist.has(target)) return null;
  const path = [target];
  while (path[0] !== here.region_id) path.unshift(prev.get(path[0]));
  return path.map(id => byId.get(id));
}

function paint() {
  const frame = $('#map-frame', el), svg = $('#map-svg', el); if (!frame || !svg) return;
  const W = frame.clientWidth, H = frame.clientHeight;
  svg.setAttribute('viewBox', `0 0 ${W} ${H}`); svg.setAttribute('width', W); svg.setAttribute('height', H);
  const X = x => (x - view.cx) * view.k + W / 2, Y = y => (y - view.cy) * view.k + H / 2;
  const P = r => [X(r.world_x), Y(r.world_y)];
  const pathOf = poly => 'M' + poly.map(([x, y]) => `${X(x).toFixed(1)},${Y(y).toFixed(1)}`).join('L') + 'Z';
  const regions = mapData.regions, byId = new Map(regions.map(r => [r.region_id, r]));
  const here = currentRegion(mapData), dest = store.character?.travel_destination;
  const g = geometry(), b = bounds(), fitK = Math.min(W / b.w, H / b.h), zoom = view.k / fitK;

  // ① 땅: 세력 색으로 칠한다
  let land = '', hatch = '';
  for (const r of regions) {
    const poly = g.cells.get(r.region_id); if (!poly?.length) continue;
    const cls = r.region_id === here?.region_id ? ' here' : r.region_id === selected ? ' sel' : '';
    land += `<path d="${pathOf(poly)}" class="cell${cls}" style="--fc:${factionColor(factionOf(r.region_id))}" data-region="${esc(r.region_id)}"/>`;
    if (r.level_locked) hatch += `<path d="${pathOf(poly)}" class="cell-lock" data-region="${esc(r.region_id)}"/>`;
  }
  // ② 경계: 같은 세력 안은 옅은 선, 세력이 바뀌면 국경, 이웃이 없으면 해안선
  let inner = '', border = '', coast = '';
  for (const e of g.edges) {
    const d = `M${X(e.p[0]).toFixed(1)},${Y(e.p[1]).toFixed(1)}L${X(e.q[0]).toFixed(1)},${Y(e.q[1]).toFixed(1)}`;
    if (!e.b) coast += d; else if (factionOf(e.a) !== factionOf(e.b)) border += d; else inner += d;
  }
  // ③ 길
  const seen = new Set(); let roads = '';
  for (const r of regions) for (const f of r.travel_from || []) {
    const o = byId.get(f); if (!o) continue;
    const key = [r.region_id, f].sort().join('|'); if (seen.has(key)) continue; seen.add(key);
    const [x1, y1] = P(r), [x2, y2] = P(o);
    roads += `<line x1="${x1.toFixed(1)}" y1="${y1.toFixed(1)}" x2="${x2.toFixed(1)}" y2="${y2.toFixed(1)}" class="road"/>`;
  }
  // ④ 고른 곳까지의 경로
  let route = '';
  const rt = selected && here && selected !== here.region_id ? routeTo(selected) : null;
  if (rt && rt.length > 1) route = `<polyline class="route-line" points="${rt.map(r => P(r).map(v => v.toFixed(1)).join(',')).join(' ')}"/>`;
  // ⑤ 영역(세력령) 이름: 멀리서 볼 때 크게
  const terr = new Map();
  for (const r of regions) {
    const t = r.territory_id || 'none', c = centroid(g.cells.get(r.region_id) || [[r.world_x, r.world_y]]);
    const o = terr.get(t) || { name: r.territory_name || '', x: 0, y: 0, n: 0 }; o.x += c[0]; o.y += c[1]; o.n++; terr.set(t, o);
  }
  const tOpacity = zoom < 1.5 ? 0.95 : zoom < 2.4 ? 0.45 : 0.18;
  let tnames = '';
  const wx = store.env?.territories || {};
  for (const [tid, t] of terr) {
    if (!t.name) continue;
    const fs = Math.max(13, Math.min(22, 15 * Math.sqrt(zoom)));
    tnames += `<text x="${X(t.x / t.n).toFixed(1)}" y="${Y(t.y / t.n).toFixed(1)}" class="terr-name" style="opacity:${tOpacity};font-size:${fs}px" text-anchor="middle" dominant-baseline="central">${esc(t.name)}</text>`;
    // 영역마다 지금 날씨
    if (wx[tid]) tnames += `<text x="${X(t.x / t.n).toFixed(1)}" y="${(Y(t.y / t.n) + fs * 0.95).toFixed(1)}" class="terr-weather w-${esc(wx[tid].key)}" style="opacity:${tOpacity};font-size:${Math.max(11, fs * 0.6)}px" text-anchor="middle" dominant-baseline="central">${esc(wx[tid].name)}</text>`;
  }
  // ⑥ 지역 표식과 이름표(겹치지 않게; 멀리서는 중요한 곳만)
  const fs = W < 520 ? 12 : 13;
  const rank = r => r.region_id === selected ? 0 : r.region_id === here?.region_id ? 1 : r.region_id === dest ? 2 : r.reachable ? 3 : r.level_locked ? 6 : 4;
  const order = [...regions].sort((a, c) => rank(a) - rank(c) || (c.visits || 0) - (a.visits || 0));
  const boxes = regions.map(r => { const [x, y] = P(r); return { x: x - 8, y: y - 8, w: 16, h: 16 }; });
  boxes.push({ x: W - 60, y: 0, w: 60, h: 190 }, { x: 0, y: H - (W < 520 ? 50 : 30), w: W, h: 50 });
  const hit = bx => bx.x < 0 || bx.y < 0 || bx.x + bx.w > W || bx.y + bx.h > H || boxes.some(o => bx.x < o.x + o.w && bx.x + bx.w > o.x && bx.y < o.y + o.h && bx.y + bx.h > o.y);
  const labels = new Map();
  for (const r of order) {
    const must = rank(r) <= 2;
    if (zoom < 1.35 && !must) continue;
    const [x, y] = P(r); if (x < -20 || y < -20 || x > W + 20 || y > H + 20) continue;
    const w = [...r.region_name].length * fs * 0.98 + 10, hgt = fs + 8;
    const tries = [[x + 11, y - hgt / 2, 'start'], [x - 11 - w, y - hgt / 2, 'end'], [x - w / 2, y - 12 - hgt, 'middle'], [x - w / 2, y + 12, 'middle']];
    let placed = null;
    for (const [bx, by, anchor] of tries) { const box = { x: bx, y: by, w, h: hgt }; if (!hit(box)) { placed = { box, anchor }; break; } }
    if (!placed && must) placed = { box: { x: tries[0][0], y: tries[0][1], w, h: hgt }, anchor: 'start' };
    if (placed) { boxes.push(placed.box); labels.set(r.region_id, placed); }
  }
  let nodes = '', texts = '';
  for (const r of regions) {
    const [x, y] = P(r); if (x < -30 || y < -30 || x > W + 30 || y > H + 30) continue;
    const cls = r.region_id === here?.region_id ? 'here' : r.level_locked ? 'lock' : r.reachable ? 'near' : 'far';
    const sel = r.region_id === selected ? ' sel' : '', safe = zones.get(r.region_id)?.is_safe_zone;
    nodes += `<g class="node ${cls}${sel}${safe ? ' safe' : ''}" data-region="${esc(r.region_id)}" tabindex="0" role="button" aria-label="${esc(r.region_name)}">
      <circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="15" class="hitbox" data-region="${esc(r.region_id)}"/>
      ${r.region_id === dest ? `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="11" class="dest-ring"/>` : ''}
      ${safe ? `<rect x="${(x - 6).toFixed(1)}" y="${(y - 6).toFixed(1)}" width="12" height="12" rx="2" transform="rotate(45 ${x.toFixed(1)} ${y.toFixed(1)})" class="dot" data-region="${esc(r.region_id)}"/>`
             : `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="${sel ? 6.5 : 5}" class="dot" data-region="${esc(r.region_id)}"/>`}
      ${r.region_id === here?.region_id ? `<circle cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="13" class="here-ring"/>` : ''}
      <title>${esc(r.region_name)}</title></g>`;
    const l = labels.get(r.region_id);
    if (l) {
      const tx = l.anchor === 'start' ? l.box.x + 4 : l.anchor === 'end' ? l.box.x + l.box.w - 4 : l.box.x + l.box.w / 2;
      texts += `<text x="${tx.toFixed(1)}" y="${(l.box.y + l.box.h / 2).toFixed(1)}" text-anchor="${l.anchor}" dominant-baseline="central" class="lbl ${cls}${sel}" style="font-size:${fs}px" data-region="${esc(r.region_id)}">${esc(r.region_name)}</text>`;
    }
  }
  svg.innerHTML = `<defs>
      <pattern id="sea-wave" width="28" height="14" patternUnits="userSpaceOnUse"><path d="M0 7q7-5 14 0t14 0" class="sea-line"/></pattern>
      <pattern id="lock-hatch" width="7" height="7" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="7" class="hatch-line"/></pattern>
    </defs>
    <rect width="${W}" height="${H}" class="sea"/><rect width="${W}" height="${H}" fill="url(#sea-wave)"/>
    <g class="land">${land}</g><g>${hatch}</g>
    <path d="${inner}" class="b-inner"/><path d="${coast}" class="b-coast"/><path d="${border}" class="b-border"/>
    <g class="roads">${roads}</g>${route}
    <g class="terr">${tnames}</g><g class="labels">${texts}</g><g class="nodes">${nodes}</g>`;
}

function select(id, center) {
  selected = id;
  if (center) { const r = mapData.regions.find(x => x.region_id === id); if (r) { view.cx = r.world_x; view.cy = r.world_y; } }
  paint(); drawDetail();
  // 좁은 화면에서는 저절로 스크롤하지 않는다. 대신 지도 위 띠에 예상 시간과 출발 단추를 바로 보여 준다.
  const peek = $('#map-peek', el), r = mapData.regions.find(x => x.region_id === id);
  if (peek && r && matchMedia('(max-width: 1099px)').matches) {
    const go = $('#travel-go', el), field = $('#go-field', el);
    const line = $('#map-detail .route-box b', el)?.textContent?.trim() || $('#map-detail .hint:not(.ok)', el)?.textContent?.trim() || '';
    peek.hidden = false;
    peek.innerHTML = `<div class="peek-txt"><b>${esc(r.region_name)}</b>${line ? `<small>${esc(line)}</small>` : ''}</div>
      <div class="peek-act"><button class="btn small ghost" type="button" data-peek="more">자세히</button>
        ${field ? `<button class="btn small primary" type="button" data-peek="field">${icon('home', 14)}<span>현장</span></button>`
          : go ? `<button class="btn small primary" type="button" data-peek="go" ${go.disabled ? 'disabled' : ''}>${icon('route', 14)}<span>출발</span></button>` : ''}</div>`;
    peek.onclick = e => {
      const b = e.target.closest('[data-peek]'); if (!b) return;
      if (b.dataset.peek === 'more') $('#map-detail', el)?.scrollIntoView({ block: 'start', behavior: 'smooth' });
      if (b.dataset.peek === 'go') $('#travel-go', el)?.click();
      if (b.dataset.peek === 'field') $('#go-field', el)?.click();
    };
  }
}

function hopSeconds(from, to, speed) {
  const d = Math.hypot(to.world_x - from.world_x, to.world_y - from.world_y);
  const terr = Math.max(Number(from.terrain_cost) || 1, Number(to.terrain_cost) || 1);
  const cross = from.territory_id && to.territory_id && from.territory_id !== to.territory_id ? 1.2 : 1;
  return Math.max(12, Math.round((d * 1.4 + Math.abs((to.elevation || 0) - (from.elevation || 0)) * 6 + 12) * terr * cross / speed));
}
// 표시용 예상치. 실제 도착 시각과 운임은 서버가 정한다.
function routeEstimate(route) {
  const m = (mountData?.mounts || []).find(x => x.equipped) || (mountData?.mounts || []).find(x => x.mount_id === store.character?.mount_id);
  const speed = Number(m?.speed_multiplier) || 1;
  let secs = 0;
  for (let i = 1; i < route.length; i++) secs += hopSeconds(route[i - 1], route[i], speed);
  if (route.length > 2) secs = Math.round(secs * 0.9);
  return { secs, mount: m, hops: route.length - 1 };
}

function factionLegend() {
  const seen = new Map();
  for (const r of mapData.regions) { const f = factionOf(r.region_id); if (!seen.has(f)) seen.set(f, r.faction_control || '무주 금역'); }
  return `<div class="faction-legend">${[...seen].map(([f, n]) => `<span><i style="background:${factionColor(f)}"></i>${esc(n)}</span>`).join('')}</div>`;
}

function drawDetail() {
  const box = $('#map-detail', el); if (!box) return;
  const r = mapData.regions.find(x => x.region_id === selected); if (!r) { box.innerHTML = ''; return; }
  const c = store.character, here = currentRegion(mapData);
  const isHere = here?.region_id === r.region_id;
  const traveling = c.travel_arrives_at && new Date(c.travel_arrives_at) > new Date();
  const route = !isHere ? routeTo(r.region_id) : null;
  const est = route ? routeEstimate(route) : null;
  const zone = zones.get(r.region_id);
  let reason = '';
  if (isHere) reason = '';
  else if (traveling) reason = '이미 이동 중입니다. 도착하거나 취소한 뒤 출발할 수 있습니다.';
  else if (r.level_locked) reason = `Lv.${r.min_level} 이상부터 들어갈 수 있습니다.`;
  else if (!route) reason = '지금 갈 수 있는 길이 없습니다. 레벨이 모자란 지역이 길을 막고 있습니다.';
  const members = (partyData?.members || []).filter(m => m.owner_id !== c.owner_id && m.location === c.location && !m.in_combat && !m.downed);
  const isLeader = partyData?.party?.leader_id === c.owner_id;
  const monsters = (r.monsters || []).slice(0, 4);
  box.innerHTML = `
    <article class="panel region-detail" style="--fc:${factionColor(factionOf(r.region_id))}">
      <header class="panel-head"><h2>${esc(r.region_name)}</h2>${isHere ? chip('현재 위치', 'accent') : ''}</header>
      <div class="panel-body">
        <p class="terr-line"><i></i>${esc(r.territory_name || '')} · ${esc(r.faction_control || '무주 금역')}</p>
        <div class="chips">${zone?.is_safe_zone ? chip('안전지대', 'ok') : danger(r.danger_level)}${chip(nameOf(r.region_type))}${chip(`Lv.${r.min_level}+`)}</div>
        ${zone?.is_safe_zone ? `<p class="hint ok">${icon('shield', 14)} ${esc(zone.shop_name || '상점')} · 거래소${zone.has_stable ? ' · 마구간' : ''} · 전투 없음</p>` : ''}
        <p class="desc">${esc(r.description || '')}</p>
        ${!zone?.is_safe_zone ? `<dl class="kv"><div><dt>요괴</dt><dd>${monsters.length ? monsters.map(m => esc(m.monster_name)).join(', ') : '미확인'}</dd></div></dl>` : ''}
        ${route && route.length > 1 ? `<div class="route-box"><b>${icon('route', 14)} 경로 ${est.hops}구간 · 약 ${fmt.remain(est.secs * 1000)}</b>
          <ol class="route-steps">${route.map((x, i) => `<li class="${i === 0 ? 'from' : i === route.length - 1 ? 'to' : ''}">${esc(x.region_name)}</li>`).join('')}</ol>
          <p class="muted small">여러 구간을 한 번에 이어 갑니다. 중간 지역에서는 멈추지 않고 마지막 도착만 알립니다. 준비금 ${fmt.jeon(5 * est.hops)}${est.mount && !est.mount.fare_free ? ` · 노정패 ${est.mount.fare_tokens}개` : ''}</p></div>` : ''}
        ${reason ? `<p class="hint">${icon('eye', 14)} ${esc(reason)}</p>` : ''}
        <div class="btn-row">
          ${isHere ? `<button class="btn primary" id="go-field">${icon('home', 16)}<span>현장으로</span></button>`
                   : `<button class="btn primary" id="travel-go" ${reason ? 'disabled' : ''}>${icon('route', 16)}<span>${route && route.length > 2 ? '경로 따라 출발' : '이곳으로 출발'}</span></button>`}
        </div>
        ${!reason && !isHere && route?.length === 2 && isLeader && members.length ? `<div class="ride"><p class="muted small">이웃 지역으로 갈 때는 파티원에게 동승을 요청할 수 있습니다. 운임은 파티장만 1회 부담합니다.</p>
          <div class="btn-row">${members.map(m => `<button class="btn small" data-ride="${esc(m.owner_id)}">${icon('users', 14)}<span>${esc(m.character_name)} 동승 요청</span></button>`).join('')}</div></div>` : ''}
      </div>
    </article>`;
  const go = $('#travel-go', box);
  if (go) go.onclick = () => guard(go, async () => { const out = await act('world_travel_route', { p_region_id: r.region_id }); invalidate('world_map_snapshot'); return out; });
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
      <span class="rl-meta">${r.region_id === here?.region_id ? '현재 위치' : r.level_locked ? `Lv.${r.min_level} 필요` : r.reachable ? '이웃' : esc(r.territory_name || '')} · 위험 ${r.danger_level}</span></button></li>`).join('')
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
        <div class="notice travel">${icon('route', 18)}<div><b>${esc(nameOf(status.travel_destination) + '(으)로')} 이동 중</b><span data-arrive="${arrives}">${fmt.remain(arrives - Date.now())} 후 도착</span></div></div>
        <button class="btn" id="tr-cancel">${icon('close', 16)}<span>이동 취소 (위약금 5전)</span></button>
        <p class="muted small">동승 중이라도 내 이동은 따로 취소할 수 있습니다.</p>`
        : `<p class="desc">현재 <b>${esc(status?.location || c.location)}</b>에 있습니다. 세계 지도에서 아무 지역이나 고르면 길을 따라 한 번에 이동합니다.</p>
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
