import { rpc, act, store, esc, icon, $, $$, toast, ask, openLayer, fmt, nameOf } from '../core.js';
import { loading, errorBox, panel, chip } from './common.js';
import { GPAL, GSPR } from '../housing/garden_art.js';
import { helpQ } from '../tips.js';
import { GARDEN } from '../rules.js';

const TW = 32, TH = 16, DEP = 4;
const DRY = ['#b08654', '#946c40', '#7a5632', '#5e4024', '#c69a64'];
const WET = ['#6e4a2c', '#5a3a22', '#4a2e1a', '#36200f', '#82593a'];
const SIDE = ['#4a3220', '#3a2616', '#2a1a0e'];
const GR = ['#4f7a34', '#5f8c3c', '#46702e', '#6f9e48'];

let el = null, ownerArg = null, snap = null, off = 0, fetchedAt = 0, sel = null, cv = null, timer = null, bgCache = null, busy = false, nextLoad = null;
const sprCache = new Map();

export async function render(root, sub) {
  el = root; ownerArg = sub || null; sel = null; snap = null;
  el.innerHTML = head('뒤뜰 밭') + loading();
  el.addEventListener('click', onClick);
  await reload();
}
export function destroy() { clearInterval(timer); timer = null; clearTimeout(nextLoad); nextLoad = null; el = null; cv = null; }

const head = (title, sub = '', actions = '') => `<div class="view-head"><div><p class="eyebrow">${icon('leaf', 14)} 뒤뜰 밭${sub ? ` · ${esc(sub)}` : ''}</p><h1>${esc(title)}</h1></div><div class="head-actions">${actions}</div></div>`;

async function reload() {
  if (!el) return;
  try {
    const s = await rpc('world_garden_view', { p_owner: ownerArg });
    if (!el) return;
    snap = s; fetchedAt = Date.now(); off = new Date(s.now).getTime() - fetchedAt;
    draw(); planReload();
  } catch (e) { if (el) el.innerHTML = head('뒤뜰 밭') + errorBox(e.message); }
}
const now = () => Date.now() + off;
function planReload() {
  clearTimeout(nextLoad);
  const t0 = now(), ts = [];
  for (const p of snap.plots || []) for (const k of ['ripe_at', 'rot_at']) if (p[k]) ts.push(new Date(p[k]).getTime());
  if (snap.scare?.until) ts.push(new Date(snap.scare.until).getTime());
  if (snap.crow?.next) ts.push(new Date(snap.crow.next).getTime());
  const nxt = ts.filter(t => t > t0).sort((a, b) => a - b)[0];
  const wait = Math.min(nxt ? nxt - t0 + 1500 : 6e5, 6e5);
  nextLoad = setTimeout(() => { if (el && !document.hidden) reload(); else planReload(); }, Math.max(3000, wait));
}

const plotAt = c => (snap.plots || []).find(p => p.cell === c);
function stateOf(p, t = now()) {
  const wu = p.water_until ? new Date(p.water_until).getTime() : 0, base = new Date(snap.now).getTime();
  const grown = Math.min(p.grow_s, Number(p.grown_s) + Math.max(0, (Math.min(t, wu) - base) / 1000) * (wu > base ? 1 : 0));
  const ripe = p.ripe_at && t >= new Date(p.ripe_at).getTime(), rot = p.rot_at && t >= new Date(p.rot_at).getTime();
  const dry = !ripe && (!wu || t >= wu);
  const prog = Math.min(1, grown / p.grow_s);
  return { grown, ripe, rot, dry, prog, left: Math.max(0, (p.grow_s - grown) * 1000), rotLeft: p.rot_at ? new Date(p.rot_at).getTime() - t : 0, waterLeft: wu - t,
    spr: rot ? 'rot' : ripe ? p.item : prog < 0.4 ? 'sprout1' : 'sprout2' };
}

function cells() { const n = snap.size, a = []; for (let y = 0; y < n; y++) for (let x = 0; x < n; x++) a.push(y * 4 + x); return a; }
function geom() {
  const n = snap.size, W = n * TW + 24, H = Math.max(Math.round(W * 0.8), n * TH + 40);
  const cx = Math.floor(W / 2), top = Math.round((H - n * TH) / 2) + 6;
  return { W, H, cx, top, n };
}
const iso = (g, x, y) => [g.cx + (x - y) * TW / 2, g.top + (x + y) * TH / 2];

function hex(c) { const n = parseInt(c.slice(1), 16); return [n >> 16 & 255, n >> 8 & 255, n & 255]; }
function rng(seed) { let s = seed >>> 0; return () => { s = s + 0x6D2B79F5 >>> 0; let t = s; t = Math.imul(t ^ t >>> 15, t | 1); t ^= t + Math.imul(t ^ t >>> 7, t | 61); return ((t ^ t >>> 14) >>> 0) / 4294967296; }; }

function background(g) {
  const key = `${g.W}x${g.H}`;
  if (bgCache?.key === key) return bgCache.img;
  const c = document.createElement('canvas'); c.width = g.W; c.height = g.H;
  const x = c.getContext('2d'), im = x.createImageData(g.W, g.H), d = im.data, R = rng(7);
  const put = (px, py, col) => { px = Math.round(px); py = Math.round(py); if (px < 0 || py < 0 || px >= g.W || py >= g.H) return; const i = (py * g.W + px) * 4, [r, gg, b] = hex(col); d[i] = r; d[i + 1] = gg; d[i + 2] = b; d[i + 3] = 255; };
  for (let py = 0; py < g.H; py++) for (let px = 0; px < g.W; px++) { const r = R(); put(px, py, r < 0.10 ? GR[1] : r < 0.17 ? GR[2] : r < 0.19 ? GR[3] : GR[0]); }
  for (let k = 0; k < g.W * g.H / 140; k++) { const px = Math.floor(R() * g.W), py = Math.floor(R() * g.H); put(px, py, GR[3]); put(px - 1, py + 1, GR[1]); put(px + 1, py + 1, GR[1]); }
  const tx = g.cx, ty = g.top - 2 * TH, len = 12 * TW / 2, wallH = 34, roof = 10;
  for (let t = 0; t <= len; t++) {
    const px = tx - t, base = ty + t / 2;
    for (let h = 0; h < wallH; h++) {
      let col = h > 3 ? '#c9b08a' : '#5a4632';
      if (h === 4 || h === wallH - 1 || t % 22 === 0) col = '#6b4a2e';
      if (h > 10 && h < 26 && t > 84 && t < 108) col = (t % 4 && h % 4) ? '#e8dcc0' : '#7a5634';
      if (h < 16 && t > 50 && t < 66) col = (t === 51 || t === 65 || h === 15) ? '#5a3c22' : ((t - 51) % 7 ? '#8a5e38' : '#6b4a2e');
      if (h < 3) col = h ? '#7a5634' : '#4a3220';
      put(px, base - h, col);
    }
    for (let r = 0; r < roof; r++) { let col = r < roof - 3 ? '#3a3e48' : '#2a2c34'; if (r === 0 && t % 3 === 0) col = '#1e2026'; if (r === roof - 1) col = '#5a5e6a'; put(px, base - wallH - r, col); }
  }
  for (let t = 0; t <= len; t++) {
    const px = tx + t, base = ty + t / 2;
    for (let h = 0; h < 9; h++) { let col = (Math.floor(t / 4) + Math.floor(h / 3)) % 2 ? '#8a8578' : '#a29c8c'; if (h % 3 === 0) col = '#6a6558'; if (h === 8) col = '#bdb6a4'; put(px, base - h, col); }
  }
  const dx = tx - 58, dy = ty + 29;
  [[4, 7], [14, 12], [24, 17], [34, 22]].forEach(([ox, oy]) => {
    for (let py = -2; py <= 2; py++) for (let px = -4; px <= 4; px++) if (Math.abs(px) / 4.5 + Math.abs(py) / 2.5 <= 1) put(dx + ox + px, dy + oy + py, py < 0 ? '#b4ae9c' : '#8e887a');
  });
  x.putImageData(im, 0, 0);
  bgCache = { key, img: c };
  return c;
}

function tileImg(wet, seed) {
  const key = `t${wet ? 1 : 0}:${seed}`;
  if (sprCache.has(key)) return sprCache.get(key);
  const c = document.createElement('canvas'); c.width = TW; c.height = TH + DEP; const x = c.getContext('2d'), im = x.createImageData(TW, TH + DEP), d = im.data, R = rng(seed + 11), pal = wet ? WET : DRY;
  const put = (px, py, col) => { const i = (py * TW + px) * 4, [r, g, b] = hex(col); d[i] = r; d[i + 1] = g; d[i + 2] = b; d[i + 3] = 255; };
  for (let py = 0; py < TH; py++) for (let px = 0; px < TW; px++) {
    const ddx = Math.abs(px - (TW - 1) / 2) / (TW / 2), ddy = Math.abs(py - (TH - 1) / 2) / (TH / 2);
    if (ddx + ddy > 1) continue;
    const ph = Math.floor(px / 2 + py) % 4;
    let col = pal[ph];
    if (ph === 0 && R() < 0.18) col = pal[4];
    if ((ph === 1 || ph === 2) && R() < 0.1) col = pal[3];
    if (ddx + ddy > 0.86) col = pal[3];
    put(px, py, col);
  }
  for (let px = 0; px < TW; px++) {
    const ddx = Math.abs(px - (TW - 1) / 2) / (TW / 2), yb = Math.round((TH - 1) / 2 + (1 - ddx) * (TH / 2));
    for (let k = 1; k <= DEP; k++) if (yb + k < TH + DEP) put(px, yb + k, k === DEP ? SIDE[2] : px < TW / 2 ? SIDE[0] : SIDE[1]);
  }
  x.putImageData(im, 0, 0); sprCache.set(key, c); return c;
}
function sprite(k) {
  if (sprCache.has(k)) return sprCache.get(k);
  const rows = GSPR[k]; if (!rows) return null;
  const c = document.createElement('canvas'); c.width = rows[0].length; c.height = rows.length; const x = c.getContext('2d');
  rows.forEach((r, y) => [...r].forEach((ch, i) => { if (ch !== '.') { x.fillStyle = GPAL[ch]; x.fillRect(i, y, 1, 1); } }));
  sprCache.set(k, c); return c;
}

function paint() {
  if (!cv?.isConnected || !snap) return;
  const g = geom(), x = cv.getContext('2d'), t = now();
  if (cv.width !== g.W) { cv.width = g.W; cv.height = g.H; }
  x.imageSmoothingEnabled = false;
  x.drawImage(background(g), 0, 0);
  const order = cells().sort((a, b) => (a % 4 + Math.floor(a / 4)) - (b % 4 + Math.floor(b / 4)) || (a % 4) - (b % 4));
  for (const c of order) {
    const [px, py] = iso(g, c % 4, Math.floor(c / 4)), p = plotAt(c), s = p && stateOf(p, t);
    x.drawImage(tileImg(p ? !s.dry : false, c * 7 + 3), px - TW / 2, py);
    if (sel === c) { x.strokeStyle = '#f6e7a6'; x.lineWidth = 1; x.beginPath(); x.moveTo(px, py + 0.5); x.lineTo(px + TW / 2 - 0.5, py + TH / 2); x.lineTo(px, py + TH - 0.5); x.lineTo(px - TW / 2 + 0.5, py + TH / 2); x.closePath(); x.stroke(); }
  }
  for (const c of order) {
    const [px, py] = iso(g, c % 4, Math.floor(c / 4)), p = plotAt(c), cyy = py + TH / 2;
    if (snap.scare?.cell === c) { const sp = sprite('scarecrow'); x.drawImage(sp, Math.round(px - sp.width / 2), Math.round(cyy + 4 - sp.height)); continue; }
    if (!p) continue;
    const s = stateOf(p, t), sp = sprite(s.spr);
    if (sp) x.drawImage(sp, Math.round(px - sp.width / 2), Math.round(cyy + 4 - sp.height));
    if (s.ripe && !s.rot) {
      const by = Math.round(cyy - 24 - (Math.floor(t / 400) % 2));
      x.fillStyle = '#1a120e'; x.fillRect(px + 5, by - 1, 4, 9); x.fillStyle = '#f6d24a'; x.fillRect(px + 6, by, 2, 5); x.fillRect(px + 6, by + 6, 2, 1);
    }
  }
  if (snap.crow) {
    const c = snap.crow.cell, [px, py] = iso(g, c % 4, Math.floor(c / 4)), sp = sprite('crow'), bob = Math.floor(t / 300) % 3 === 0 ? 1 : 0;
    x.drawImage(sp, Math.round(px - 1), Math.round(py + TH / 2 - 18 - bob));
  }
}

function cellAt(ev) {
  const r = cv.getBoundingClientRect(), g = geom();
  const mx = (ev.clientX - r.left) * g.W / r.width, my = (ev.clientY - r.top) * g.H / r.height;
  if (snap.crow) {
    const c = snap.crow.cell, [px, py] = iso(g, c % 4, Math.floor(c / 4)), rows = GSPR.crow, ix = Math.floor(mx - Math.round(px - 1)), iy = Math.floor(my - Math.round(py + TH / 2 - 18));
    if (rows[iy]?.[ix] && rows[iy][ix] !== '.') return 'crow';
  }
  for (const c of cells()) { const [px, py] = iso(g, c % 4, Math.floor(c / 4)); if (Math.abs(mx - px) / (TW / 2) + Math.abs(my - (py + TH / 2)) / (TH / 2) <= 1) return c; }
  return null;
}

const leftTxt = ms => fmt.remain(ms);
function stateLine(p) {
  const s = stateOf(p);
  if (s.rot) return `<span class="gd-bad">썩었습니다 · 치워야 다시 심을 수 있습니다</span>`;
  if (s.ripe) return `<span class="gd-ok">다 자랐습니다 · 썩기까지 <b data-gd-left="rot:${p.cell}">${leftTxt(s.rotLeft)}</b></span>`;
  if (s.dry) return `<span class="gd-warn">물이 말라 자라지 않습니다 · 다 자라기까지 ${leftTxt(s.left)}(물을 준 동안)</span>`;
  return `다 자라기까지 <b data-gd-left="grow:${p.cell}">${leftTxt(s.left)}</b> · 물 <span data-gd-left="water:${p.cell}">${leftTxt(s.waterLeft)}</span> 남음`;
}
const tierChip = t => `<span class="chip gd-tier t${t}">${t}단계</span>`;
const cellName = c => `${Math.floor(c / 4) + 1}줄 ${c % 4 + 1}칸`;

function detailHtml() {
  if (sel == null) return `<p class="muted small">밭의 칸을 누르면 그 칸의 작물과 할 일이 보입니다.</p>`;
  const own = snap.own, p = plotAt(sel);
  if (snap.scare?.cell === sel) return `<h3 class="sub-h">${cellName(sel)} · 허수아비</h3><p>까마귀가 내려앉지 않습니다 · 낡아 쓰러지기까지 <b data-gd-left="scare">${leftTxt(new Date(snap.scare.until).getTime() - now())}</b></p>`;
  if (!p) {
    const scareOk = own && !snap.scare && snap.scare_have > 0;
    return `<h3 class="sub-h">${cellName(sel)} · 빈 칸</h3>${own ? `<div class="btn-row"><button class="btn small primary" data-gd="plant">${icon('leaf', 14)} 심기</button>
      <button class="btn small" data-gd="scare" ${scareOk ? '' : 'disabled'} title="${esc(snap.scare ? '허수아비가 이미 서 있습니다' : snap.scare_have ? '' : '가방에 허수아비가 없습니다')}">허수아비 세우기 (가진 ${snap.scare_have || 0})</button></div>` : '<p class="muted small">비어 있는 칸입니다.</p>'}`;
  }
  const s = stateOf(p);
  const fert = p.fert_name ? `${esc(p.fert_name)}` : '없음';
  const btns = own ? `<div class="btn-row">
      ${s.ripe && !s.rot ? `<button class="btn small primary" data-gd="harvest">${icon('bag', 14)} 거두기</button>` : ''}
      ${!s.ripe ? `<button class="btn small ${s.dry ? 'primary' : ''}" data-gd="water">물 주기</button>` : ''}
      ${!s.ripe && !p.fert ? `<button class="btn small" data-gd="fert">비료 주기</button>` : ''}
      <button class="btn small ${s.rot ? 'primary' : 'danger'}" data-gd="clear">${s.rot ? '치우기' : '뽑아 버리기'}</button></div>` : '';
  return `<h3 class="sub-h">${cellName(sel)} · ${esc(p.name)} ${tierChip(p.tier)}</h3>
    <p class="gd-line">${stateLine(p)}</p>
    <div class="bar gd-bar"><i style="width:${Math.round(s.prog * 100)}%"></i></div>
    <dl class="kv"><div><dt>다 자라는 데</dt><dd>${Math.round(p.grow_s / 360) / 10}시간</dd></div>
      <div><dt>비료</dt><dd>${fert}</dd></div>
      ${own ? `<div><dt>거둘 양</dt><dd>${p.yield}개${p.eaten ? ` <small class="muted">(까마귀가 ${p.eaten}개 먹음)</small>` : ''}</dd></div>` : ''}</dl>${btns}`;
}

function listHtml() {
  const ps = (snap.plots || []).slice().sort((a, b) => a.cell - b.cell);
  if (!ps.length) return '<p class="muted small">심은 작물이 없습니다.</p>';
  return `<ul class="gd-list">${ps.map(p => { const s = stateOf(p);
    return `<li data-gd-cell="${p.cell}" class="${sel === p.cell ? 'on' : ''}"><b>${esc(p.name)}</b>${tierChip(p.tier)}<small>${s.rot ? '<span class="gd-bad">썩음</span>' : s.ripe ? '<span class="gd-ok">거둘 때</span>' : s.dry ? `<span class="gd-warn">물 마름</span> · 남은 ${leftTxt(s.left)}` : `남은 <span data-gd-left="grow:${p.cell}">${leftTxt(s.left)}</span>`}</small></li>`; }).join('')}</ul>`;
}

function draw() {
  if (!el || !snap) return;
  const own = snap.own, ps = snap.plots || [];
  const anyRipe = ps.some(p => { const s = stateOf(p); return s.ripe && !s.rot; }), anyDry = ps.some(p => stateOf(p).dry);
  const actions = `<a class="btn small" href="#/house${ownerArg ? '/' + esc(ownerArg) : ''}">${icon('home', 15)} 별채로</a>
    ${own ? `<button class="btn small ${anyDry ? 'primary' : ''}" data-gd="waterAll" ${ps.length ? '' : 'disabled'}>모두 물 주기</button>
    <button class="btn small ${anyRipe ? 'primary' : ''}" data-gd="harvestAll" ${anyRipe ? '' : 'disabled'}>모두 거두기</button>
    ${snap.next ? `<button class="btn small" data-gd="expand">넓히기</button>` : ''}` : ''}${helpQ(GARDEN.help, '뒤뜰 밭')}`;
  el.innerHTML = head(`${snap.owner_name}의 뒤뜰 밭`, `${snap.size}×${snap.size}`, actions) + `
    ${snap.crow ? `<div class="notice gd-crow">${icon('bell', 16)}<span>까마귀가 ${cellName(snap.crow.cell)} 작물을 쪼아 먹고 있습니다. 쫓지 않으면 ${GARDEN.crowEvery(snap.rules)}마다 한 입씩 더 먹습니다.</span><button class="btn small primary" data-gd="shoo">쫓기</button></div>` : ''}
    <div class="gd-wrap"><div class="hs-stage gd-stage"><div class="frame-c"><i></i><i></i><i></i><i></i></div><div class="gd-cvbox"><canvas id="gd-cv" aria-label="뒤뜰 밭"></canvas><div class="gd-tags" aria-hidden="true"></div></div></div>
    <div class="gd-side">${panel('고른 칸', `<div id="gd-detail">${detailHtml()}</div>`, { ico: 'leaf' })}${panel('작물', `<div id="gd-list">${listHtml()}</div>`, { ico: 'scroll' })}</div></div>`;
  cv = $('#gd-cv', el);
  const g = geom(); cv.width = g.W; cv.height = g.H; bgCache = null;
  cv.addEventListener('click', ev => { const c = cellAt(ev); if (c === 'crow') return run('shoo'); if (c == null) return; sel = sel === c ? null : c; paintSide(); paint(); });
  paint(); tags();
  clearInterval(timer); timer = setInterval(tick, 500);
}
function tags() {
  const box = $('.gd-tags', el); if (!box) return;
  const g = geom(), t = now();
  box.innerHTML = (snap.plots || []).filter(p => snap.scare?.cell !== p.cell && !stateOf(p, t).rot).map(p => {
    const [px, py] = iso(g, p.cell % 4, Math.floor(p.cell / 4));
    return `<span class="gd-tag t${p.tier}${sel === p.cell ? ' on' : ''}" style="left:${((px + 10) / g.W * 100).toFixed(2)}%;top:${((py + TH / 2 + 3) / g.H * 100).toFixed(2)}%">${p.tier}</span>`;
  }).join('');
}
function paintSide() { const d = $('#gd-detail', el), l = $('#gd-list', el); if (d) d.innerHTML = detailHtml(); if (l) l.innerHTML = listHtml(); tags(); }
let lastSec = 0;
function tick() {
  if (!el || !cv?.isConnected) return;
  paint();
  const sec = Math.floor(Date.now() / 1000); if (sec === lastSec) return; lastSec = sec;
  for (const n of $$('[data-gd-left]', el)) {
    const [k, c] = n.dataset.gdLeft.split(':'), p = c != null ? plotAt(Number(c)) : null;
    if (k === 'scare' && snap.scare) { n.textContent = leftTxt(new Date(snap.scare.until).getTime() - now()); continue; }
    if (!p) continue; const s = stateOf(p);
    n.textContent = leftTxt(k === 'rot' ? s.rotLeft : k === 'water' ? s.waterLeft : s.left);
  }
}

async function onClick(e) {
  const li = e.target.closest?.('[data-gd-cell]');
  if (li) { sel = Number(li.dataset.gdCell); paintSide(); paint(); return; }
  const b = e.target.closest?.('[data-gd]'); if (!b || !el?.contains(b) || b.disabled) return;
  const k = b.dataset.gd;
  if (k === 'plant') return pickCrop();
  if (k === 'fert') return pickFert();
  if (k === 'expand') return expand();
  if (k === 'clear') { const p = plotAt(sel), s = p && stateOf(p); if (!s?.rot && !(await ask(`${p.name}을(를) 뽑아 버립니다. 아무것도 돌려받지 못합니다.`, { title: '뽑아 버리기', ok: '뽑기', danger: true }))) return; return run('clear', sel); }
  if (k === 'waterAll') return run('water');
  if (k === 'harvestAll') return run('harvest');
  if (k === 'water' || k === 'harvest' || k === 'scare') return run(k, sel);
  if (k === 'shoo') return run('shoo');
}

async function run(a, cell = null, item = null) {
  if (busy) return; busy = true;
  try {
    const r = await act('world_garden_act', { p_act: a, p_cell: cell, p_item: item, p_owner: ownerArg });
    if (r?.content) toast(r.content, 'ok');
    await reload();
  } catch (e) { toast(e.message, 'error'); } finally { busy = false; }
}

function pickCrop() {
  const crops = snap.crops || [], r = snap.rules || {};
  const tiers = [...new Set(crops.map(c => c.tier))];
  const body = tiers.map(t => `<h3 class="sub-h">${t}단계 작물 <small class="muted">${GARDEN.growLine(r, t)}</small></h3><ul class="gd-pick">${crops.filter(c => c.tier === t).map(c => `
    <li><b>${esc(c.name)}</b>${tierChip(t)}<small>${c.hours}시간 · ${r.yield?.[0]}~${r.yield?.[1]}개 · 가진 ${c.have}</small><button class="btn small ${c.have ? 'primary' : ''}" data-crop="${esc(c.id)}" ${c.have ? '' : 'disabled'}>심기</button></li>`).join('')}</ul>`).join('');
  const L = openLayer({ title: `${cellName(sel)}에 심기`, body: `<p class="muted small">${esc(GARDEN.plantTip)}</p>${body}` });
  L.addEventListener('click', e => { const b = e.target.closest('[data-crop]'); if (!b) return; L.close(); run('plant', sel, b.dataset.crop); });
}
function pickFert() {
  const p = plotAt(sel), r = snap.rules || {}, need = r.fert_n?.[p.tier] || 1;
  const rows = (snap.ferts || []).map(f => `<li><b>${esc(f.name)}</b><small>${esc(GARDEN.fertFx(f))} · ${need}개 · 가진 ${f.have}</small><button class="btn small ${f.have >= need ? 'primary' : ''}" data-fert="${esc(f.id)}" ${f.have >= need ? '' : 'disabled'}>주기</button></li>`).join('');
  const L = openLayer({ title: `${p.name}에 비료 주기`, body: `<p class="muted small">${esc(GARDEN.fertTip(p.tier, need))}</p><ul class="gd-pick">${rows}</ul>` });
  L.addEventListener('click', e => { const b = e.target.closest('[data-fert]'); if (!b) return; L.close(); run('fert', sel, b.dataset.fert); });
}
async function expand() {
  const n = snap.next; if (!n) return;
  const mats = Object.entries(n.items || {}).map(([k, v]) => `${n.names?.[k] || nameOf(k)} ${v}`).join(' · ');
  if (!(await ask(`밭을 ${n.size}×${n.size}로 넓힙니다.\n${fmt.jeon(n.gil)} · ${mats}\n재료는 가방을 먼저 쓰고 모자라면 창고에서 꺼냅니다. 안전지대에서만 넓힐 수 있습니다.`, { title: '밭 넓히기', ok: '넓히기' }))) return;
  run('expand');
}
