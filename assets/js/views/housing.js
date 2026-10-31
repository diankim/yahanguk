// 별채(7.2, #/house · #/house/<주인>): 도트 방 구경·꾸미기·곳간·넓히기·대문·방명록·꼬마 동무.
// 서버는 world_housing_*·world_pet_*가 검사하고(겹침·칸·설치 상한·소유·안전지대), 화면은 같은 규칙으로 미리 막아 준다.
// 다시 읽는 때: 화면을 열 때 · 저장·곳간·넓히기·방명록·동무 행동 뒤(실시간 구독·주기 읽기 없음). 방 그림은 동무가 있을 때만 1초 8번 다시 그린다.
import { rpc, act, store, esc, icon, $, $$, toast, guard, ask, openModal, closeModal, nameOf } from '../core.js';
import { loading, errorBox, panel } from './common.js';
import { makeRoom, TW, TH, WALLH } from '../housing/render.js';
import { FUR, WALL, PAPER, GROUND } from '../housing/furniture.js';
import { PETS, drawPet, drawEffect, petImage } from '../housing/petsprite.js';
import { cardName } from './card.js';

const DEFS = { FUR, WALL, PAPER, GROUND };
const GRADE = ['', '범품', '양품', '진품', '명품', '신품'];
const KIND_CAP = [0, 4, 3, 2, 1, 1]; // 한 지붕(혼례 정인과 함께 쓰는 별채)이면 서버가 두 배로 내려 준다(snap.kind_caps)
const kindCap = g => snap?.kind_caps?.[g - 1] ?? KIND_CAP[g];
const GATE = [['open', '활짝 엶', '누구나 구경'], ['friends', '벗에게만', '친구만 구경'], ['closed', '닫음', '나만 구경']];
const FOODS = ['pet_food', 'treat_fish', 'treat_rice', 'treat_honey', 'treat_herb', 'treat_meat'];
const PAL_TABS = [['floor', '바닥'], ['wall', '벽'], ['paper', '벽지'], ['ground', '바닥재']];
const idOf = (kind, k) => (kind === 'paper' ? 'hp_' : kind === 'ground' ? 'hg_' : 'hf_') + k;
const gradeOf = id => (id.startsWith('hp_') ? PAPER[id.slice(3)] : id.startsWith('hg_') ? GROUND[id.slice(3)] : FUR[id.slice(3)] || WALL[id.slice(3)])?.grade || 1;
const furName = id => (id.startsWith('hp_') ? PAPER[id.slice(3)] : id.startsWith('hg_') ? GROUND[id.slice(3)] : FUR[id.slice(3)] || WALL[id.slice(3)])?.name || nameOf(id);

let el = null, ownerArg = null, snap = null, room = null, cv = null, raf = null, lastDraw = 0;
let state = null, orig = null, editing = false, pick = null, sel = null, palTab = 'floor', dirty = false, busy = false;
let pet = null, fx = [];

export async function render(root, sub) {
  el = root; ownerArg = sub || null; editing = false; pick = null; sel = null; dirty = false; pet = null; fx = [];
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('home', 14)} 별채</p><h1>별채</h1></div></div>${loading()}`;
  await reload();
}
export function destroy() { cancelAnimationFrame(raf); raf = null; el = null; cv = null; }

async function reload() {
  if (!el) return;
  try {
    const pre = store.houseSnap; store.houseSnap = null; // 조사원 카드가 막 받아 둔 것이면 다시 묻지 않는다
    snap = pre && pre.owner === ownerArg && Date.now() - pre.at < 10000 ? pre.snap : await rpc('world_housing_snapshot', { p_owner: ownerArg });
    if (!el) return;
    if (!snap.open) return drawClosed();
    resetState(); draw();
  } catch (e) { if (el) el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('home', 14)} 별채</p><h1>별채</h1></div></div>${errorBox(e.message)}`; }
}
function resetState() {
  const cl = o => JSON.parse(JSON.stringify(o || []));
  state = { items: cl(snap.items), wall: cl(snap.wall), paper: snap.paper, ground: snap.ground };
  orig = counts(state); dirty = false; sel = null; pick = null;
  room = makeRoom(snap.size, DEFS);
  setupPet();
}

// ─── 아직 별채가 없을 때 ───
function drawClosed() {
  const q = snap.quest || {}, c = store.character || {};
  const store_ = Object.entries(snap.store || {}).filter(([, n]) => n > 0);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('home', 14)} 별채</p><h1>아직 별채가 없습니다</h1></div></div>
    <div class="notice">${icon('help', 18)}<div><b>본부 객사의 「객사 별채」 퀘스트</b><span>주 이야기 4장 「북령의 얼음 인장」을 마치고 Lv15가 되면 본부 객사의 살림꾼 순덕에게서 받을 수 있습니다. 부적목·황지를 채집하고 오방색 방석을 만든 뒤 수리비 1,000전을 치르면 6×6 별채와 기본 세트 「단청 별채」를 받습니다.</span></div></div>
    ${panel('지금 내 상태', `<ul class="hs-req"><li class="${c.level >= 15 ? 'ok' : 'no'}">레벨 15 이상 (지금 Lv.${c.level || 1})</li><li class="${q.step ? 'ok' : ''}">퀘스트 ${q.done ? '마침' : q.step ? `${q.step}장면까지 보고함` : '받지 않음'}</li></ul>
      <p class="muted small">일지 › 보조 퀘스트의 「생활」 칸에서도 볼 수 있습니다.</p>`, { ico: 'scroll' })}
    ${mergePanel()}
    ${store_.length ? panel('곳간에 쌓인 가구', `<p class="muted small">별채를 얻기 전에 받은 가구입니다. 별채를 얻으면 꺼내 놓을 수 있습니다.</p><ul class="hs-list">${store_.map(([id, n]) => `<li>${esc(furName(id))} ×${n}</li>`).join('')}</ul>`, { ico: 'chest' }) : ''}`;
  $$('[data-merge]', el).forEach(b => b.addEventListener('click', () => guard(b, () => mergeAct(b, b.dataset.merge))));
}

// ─── 수 세기·검사(서버 world_housing_save와 같은 규칙) ───
function counts(st) {
  const m = {};
  const add = id => { m[id] = (m[id] || 0) + 1; };
  st.items.forEach(i => add(idOf('fur', i.k))); st.wall.forEach(w => add(idOf('wall', w.k)));
  if (st.paper) add(idOf('paper', st.paper)); if (st.ground) add(idOf('ground', st.ground));
  return m;
}
const haveAll = id => (snap.bag?.[id] || 0) + (snap.store?.[id] || 0) + (orig[id] || 0);
const left = id => haveAll(id) - (counts(state)[id] || 0);
const dimsOf = it => { const f = FUR[it.k]; return (it.r || 0) % 2 ? [f.D, f.W] : [f.W, f.D]; };
function validate(st) {
  const N = snap.size, occ = new Set(), tops = new Set(), surf = new Set();
  for (const it of st.items) {
    const f = FUR[it.k]; if (!f) return '알 수 없는 가구가 있습니다.';
    const [w, d] = dimsOf(it);
    if (it.x < 0 || it.y < 0 || it.x + w > N || it.y + d > N) return '방 밖으로 나갑니다.';
    for (let x = it.x; x < it.x + w; x++) for (let y = it.y; y < it.y + d; y++) {
      const key = `${x},${y}`;
      if (f.layer === 'surface') { if (surf.has(key)) return '한 자리에 소품을 둘 올릴 수 없습니다.'; surf.add(key); }
      else { const kk = `${f.layer === 'rug' ? 'r' : 'f'}${key}`; if (occ.has(kk)) return '다른 가구와 겹칩니다.'; occ.add(kk); if (f.layer !== 'rug' && f.top > 0) tops.add(key); }
    }
  }
  for (const it of st.items) if (FUR[it.k].layer === 'surface' && !tops.has(`${it.x},${it.y}`)) return '소품은 탁자·서안·서가처럼 윗면이 있는 가구 위에만 올릴 수 있습니다.';
  const ws = [];
  for (const w of st.wall) {
    const d = WALL[w.k]; if (!d) return '알 수 없는 장식이 있습니다.';
    if (w.t < 0 || w.t + d.w > N + 1e-9 || w.z < 4 || w.z + d.h > 75) return '벽 밖으로 나갑니다.';
    for (const o of ws) if (o.side === w.side && w.t < o.t + o.w && o.t < w.t + d.w && w.z < o.z + o.h && o.z < w.z + d.h) return '벽 장식이 서로 겹칩니다.';
    ws.push({ side: w.side, t: w.t, z: w.z, w: d.w, h: d.h });
  }
  if (st.items.length + st.wall.length > snap.cap) return `이 별채에는 가구를 ${snap.cap}개까지 놓을 수 있습니다.`;
  const c = counts(st);
  for (const [id, n] of Object.entries(c)) {
    if (id.startsWith('hf_') && n > kindCap(gradeOf(id))) return `${furName(id)}은(는) 한 별채에 ${kindCap(gradeOf(id))}개까지 놓을 수 있습니다.`;
    if (n > haveAll(id)) return `${furName(id)}이(가) 모자랍니다.`;
  }
  return null;
}
function tryChange(fn) {
  const keep = JSON.stringify(state);
  fn();
  const msg = validate(state);
  if (msg) { const k = JSON.parse(keep); state.items = k.items; state.wall = k.wall; state.paper = k.paper; state.ground = k.ground; sel = null; toast(msg, 'error'); return false; }
  dirty = true; return true;
}

// ─── 그리기 ───
function draw() {
  if (!el || !snap) return;
  const me = snap.role === 'owner', can = !!snap.role, edBlock = snap.edit_block;
  const p = snap.pet;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('home', 14)} 별채 · ${snap.size}×${snap.size}</p><h1>${esc(snap.owner_name)}${snap.mate_name ? `·${esc(snap.mate_name)}` : ''}의 별채</h1>
      <p class="muted small">발걸음 오늘 ${snap.visits_today} · 전체 ${snap.visits_total} · 대문 ${esc(GATE.find(g => g[0] === snap.gate)?.[1] || '')}</p></div>
    <div class="head-actions">${can ? `<button class="btn small ${editing ? 'primary' : ''}" id="hs-edit" ${edBlock && !editing ? 'disabled' : ''} title="${esc(edBlock || '가구를 놓고 옮깁니다')}">${icon('hammer', 15)} ${editing ? '꾸미는 중' : '꾸미기'}</button>` : ''}
      ${me ? `<button class="btn small" id="hs-store">${icon('chest', 15)} 곳간</button><button class="btn small" id="hs-pets">${icon('heart', 15)} 동무</button>` : ''}</div></div>
    ${can && edBlock && !editing ? `<p class="muted small hs-why">${esc(edBlock)}</p>` : ''}
    <div class="hs-wrap ${editing ? 'editing' : ''}">
      <div class="hs-stage"><div class="frame-c"><i></i><i></i><i></i><i></i></div><canvas id="hs-cv" aria-label="${esc(snap.owner_name)}의 별채"></canvas>${editing ? toolbar() : ''}</div>
      ${editing ? palette() : ''}
      ${p && !editing ? petBar(p) : ''}
    </div>
    ${me && !editing ? ownerPanel() : ''}
    ${me && !editing ? mergePanel() : ''}
    ${guestbook()}`;
  cv = $('#hs-cv'); fit(); paint(true); loop();
  bind();
}
function fit() {
  if (!cv || !room) return;
  cv.width = room.W; cv.height = room.H;
  const box = cv.parentElement.getBoundingClientRect().width || room.W * 2;
  // 2배 넘게 키울 수 있으면 정수 배율(도트가 고르게), 좁은 화면은 폭에 맞춘다. 높이는 화면의 72%까지.
  const raw = Math.min((box - 4) / room.W, (window.innerHeight * 0.72) / room.H);
  const s = raw >= 2 ? Math.min(4, Math.floor(raw)) : Math.max(1, raw);
  cv.style.width = `${room.W * s}px`; cv.style.height = `${room.H * s}px`;
}
function paint() {
  if (!cv || !room) return;
  const pets = pet ? [{ x: pet.x, y: pet.y, draw: c => drawPetIn(c) }] : [];
  const bg = getComputedStyle(document.body).getPropertyValue('--bg').trim() || '#1b1d24';
  const img = room.render(state, { sel, bad: false, bg: /^#[0-9a-f]{6}$/i.test(bg) ? bg : '#1b1d24', pets });
  const g = cv.getContext('2d'); g.putImageData(img, 0, 0);
  if (pick && hover) ghost(g);
}
let hover = null;
function ghost(g) {
  // 놓을 자리 미리 보기: 칸 테두리만
  if (pick.type === 'fur') {
    const f = FUR[pick.k]; const [w, d] = (pick.r || 0) % 2 ? [f.D, f.W] : [f.W, f.D];
    const q = [room.iso(hover.x, hover.y), room.iso(hover.x + w, hover.y), room.iso(hover.x + w, hover.y + d), room.iso(hover.x, hover.y + d)];
    g.strokeStyle = '#d8b25a'; g.lineWidth = 1; g.setLineDash([2, 2]); g.beginPath(); q.forEach(([x, y], i) => i ? g.lineTo(x, y) : g.moveTo(x, y)); g.closePath(); g.stroke(); g.setLineDash([]);
  }
}
function loop() {
  cancelAnimationFrame(raf);
  const step = t => {
    if (!el || !cv) return;
    raf = requestAnimationFrame(step);
    if (!pet && !fx.length) return;
    if (t - lastDraw < 125 || document.hidden) return;
    lastDraw = t; tickPet(); fx = fx.filter(f => f.until > Date.now()); paint();
  };
  raf = requestAnimationFrame(step);
}
function toolbar() {
  const n = state.items.length + state.wall.length;
  return `<div class="hs-tools"><span class="chip">${n}/${snap.cap}</span>
    <button class="btn small" id="hs-rot" ${sel && FUR[sel.k] || pick?.type === 'fur' ? '' : 'disabled'}>${icon('refresh', 14)} 돌리기</button>
    <button class="btn small" id="hs-take" ${sel ? '' : 'disabled'}>${icon('down', 14)} 거두기</button>
    <button class="btn small" id="hs-undo" ${dirty ? '' : 'disabled'}>되돌리기</button>
    <button class="btn small primary" id="hs-save" ${dirty ? '' : 'disabled'}>저장</button>
    <button class="btn small" id="hs-done">닫기</button></div>
    <p class="muted small hs-hint">${pick ? `「${esc(pick.type === 'wall' ? WALL[pick.k].name : FUR[pick.k].name)}」 · ${pick.type === 'wall' ? '벽을 눌러 거세요' : '바닥 칸을 눌러 놓으세요'}` : sel ? '빈 칸을 누르면 그리로 옮깁니다' : '아래에서 가구를 고르거나, 놓인 가구를 눌러 고르세요'}</p>`;
}
function palette() {
  const list = palTab === 'paper' ? Object.entries(PAPER).map(([k, v]) => ['paper', k, v]) : palTab === 'ground' ? Object.entries(GROUND).map(([k, v]) => ['ground', k, v])
    : palTab === 'wall' ? Object.entries(WALL).map(([k, v]) => ['wall', k, v]) : Object.entries(FUR).map(([k, v]) => ['fur', k, v]);
  const rows = list.map(([type, k, v]) => {
    const id = idOf(type, k), n = left(id), on = (type === 'paper' && state.paper === k) || (type === 'ground' && state.ground === k) || (pick && pick.k === k && pick.type === type);
    if (n <= 0 && !on) return '';
    const pic = type === 'paper' ? `<span class="hs-sw" style="--a:${v.c};--b:${v.l}"></span>` : type === 'ground' ? `<span class="hs-sw" style="--a:${v.a};--b:${v.b}"></span>` : `<img src="${room.thumb(k)}" alt="">`;
    return `<button class="hs-pal-it g${v.grade} ${on ? 'on' : ''}" data-pal="${type}:${esc(k)}" title="${esc(v.name)} · ${GRADE[v.grade]}">${pic}<b>${esc(v.name)}</b><small>${type === 'paper' || type === 'ground' ? (on ? '바름' : `${n}장`) : `남은 ${n}`}</small></button>`;
  }).join('');
  return `<div class="hs-pal"><div class="chips">${PAL_TABS.map(([k, l]) => `<button class="chip-btn ${palTab === k ? 'on' : ''}" data-paltab="${k}">${l}</button>`).join('')}</div>
    <div class="hs-pal-grid">${rows || '<p class="muted small">놓을 수 있는 것이 없습니다. 가구는 상점·제작·토벌·원정·칭호 보상으로 얻습니다.</p>'}</div></div>`;
}
function petBar(p) {
  const me = snap.role === 'owner', today = snap.pet_today || {};
  if (p.out) return `<div class="hs-petbar"><span class="muted small">${esc(`${p.nick || p.name}은(는) ${me ? '나와' : '주인과'} 함께 나가 있습니다.`)}</span></div>`;
  return `<div class="hs-petbar"><img src="${petImage(p.id, p.adult, { scale: 2 })}" alt=""><b>${esc(p.nick || p.name)}</b><span class="muted small">친밀도 ${p.affinity || 0}${p.adult ? ' · 다 자람' : ' / 100이면 자람'}</span>
    <span class="hs-petbtn"><button class="btn small" data-pet="pat" ${!me && today.pat ? 'disabled' : ''}>쓰다듬기</button><button class="btn small" data-pet="play" ${!me && today.play ? 'disabled' : ''}>놀아 주기</button>${me ? '<button class="btn small" data-pet="feed">먹이 주기</button>' : ''}</span></div>`;
}
function ownerPanel() {
  const nx = snap.next;
  return `<div class="grid-2">${panel('대문', `<div class="chips">${GATE.map(([k, l, d]) => `<button class="chip-btn ${snap.gate === k ? 'on' : ''}" data-gate="${k}" title="${esc(d)}">${esc(l)}</button>`).join('')}</div>
      <p class="muted small">닫아 두면 나(와 혼례를 올린 정인)만 들어옵니다. 차단한 사람은 늘 들어오지 못합니다.</p>`, { ico: 'home' })}
    ${panel('넓히기', nx ? `<p>${snap.size}×${snap.size} → <b>${nx.size}×${nx.size}</b> · 놓을 수 있는 가구 ${snap.cap} → ${{ 7: 20, 8: 26, 9: 32 }[nx.size]} · 곳간 +5칸</p>
      <p class="muted small">Lv${nx.level} · ${nx.gil.toLocaleString()}전 · ${Object.entries(nx.items).map(([i, n]) => `${esc(nameOf(i))} ×${n}`).join(' · ')}</p><button class="btn small" id="hs-expand">넓히기</button>`
      : '<p class="muted small">가장 넓은 9×9 별채입니다.</p>', { ico: 'up' })}</div>`;
}
// 한 지붕(7.3): 혼례를 올린 정인과 별채 하나를 함께 쓴다 — 제안·받기·미루기·거두기·각자 별채로
function mergePanel() {
  const m = snap.merge; if (!m) return '';
  let body;
  if (m.shared) {
    const s = m.shared;
    body = `<p><b>${esc(s.home_name)}</b>님의 별채를 <b>${esc(s.mate_name)}</b>님과 함께 씁니다${snap.cap ? ` · 가구 ${snap.cap}개 · 곳간 ${snap.store_cap}칸 · 같은 가구 두 배` : ''}.</p>
      <p class="muted small">${esc(s.mate_name)}님의 별채는 그대로 보관합니다. 각자 별채로 돌아가면 ${esc(s.mate_name)}님이 들여온 가구${s.mate_items ? `(지금 ${s.mate_items}점)` : ''}는 ${esc(s.mate_name)}님의 곳간으로 돌아갑니다. 연리가 끝나도 저절로 돌아갑니다.</p>
      <button class="btn small danger" data-merge="split">각자 별채로 돌아가기</button>`;
  } else if (m.ask_in) {
    const mine = m.ask_in.home_id !== m.partner_id;
    body = `<p><b>${esc(m.ask_in.from_name)}</b>님이 ${mine ? '내 별채' : `${esc(m.ask_in.from_name)}님의 별채`}를 함께 쓰자고 합니다.</p>
      <p class="muted small">받으면 한 별채를 둘이 고치고, 설치할 수 있는 가구와 곳간이 두 사람 몫이 됩니다. ${mine ? '정인' : '내'} 별채는 그대로 보관하고 그 곳간 가구는 함께 쓰는 곳간으로 옮깁니다.</p>
      <div class="btn-row"><button class="btn small primary" data-merge="yes">받기</button><button class="btn small" data-merge="no">미루기</button></div>`;
  } else if (m.ask_out) {
    body = `<p>${esc(m.partner_name)}님의 답을 기다립니다. (24시간 안에 받지 않으면 사라집니다)</p><button class="btn small" data-merge="cancel">제안 거두기</button>`;
  } else if (m.partner_id) {
    body = `<p>혼례를 올린 <b>${esc(m.partner_name)}</b>님과 별채 하나를 함께 쓸 수 있습니다.</p>
      <p class="muted small">고른 별채가 「우리 집」이 되어 둘이 함께 꾸미고, 넓이는 그대로지만 설치할 수 있는 가구·곳간이 두 사람 몫이 됩니다(넓히기는 둘 중 누구나). 다른 별채는 지우지 않고 보관하며, 각자 별채로 돌아가면 들여온 가구는 들여온 사람에게 돌아갑니다.</p>
      <div class="btn-row">${m.my_house ? '<button class="btn small primary" data-merge="mine">내 별채로 합치자고 하기</button>' : ''}${m.partner_house ? `<button class="btn small" data-merge="theirs">${esc(m.partner_name)}님 별채로 합치자고 하기</button>` : ''}</div>
      ${!m.my_house && !m.partner_house ? '<p class="muted small">둘 중 한 사람에게 별채가 있어야 합칠 수 있습니다.</p>' : ''}`;
  } else return '';
  return panel('한 지붕', body, { ico: 'heart' });
}
async function mergeAct(b, k) {
  if (k === 'split' && !(await ask('각자 별채로 돌아갈까요? 정인이 들여온 가구는 정인의 곳간으로 돌아가고, 다시 합치려면 제안부터 다시 해야 합니다.', { title: '한 지붕', ok: '각자 별채로', danger: true }))) return;
  if ((k === 'mine' || k === 'theirs') && !(await ask(`${k === 'mine' ? '내 별채' : '정인의 별채'}를 함께 쓰자고 정인에게 전할까요?`, { title: '한 지붕', ok: '전하기' }))) return;
  const r = k === 'split' ? await rpc('world_housing_split') : k === 'cancel' ? await rpc('world_housing_merge_cancel')
    : k === 'yes' || k === 'no' ? await rpc('world_housing_merge_answer', { p_accept: k === 'yes' }) : await rpc('world_housing_merge_ask', { p_home: k });
  await reload(); return r;
}
function guestbook() {
  const g = snap.guestbook || [], left3 = Math.max(0, 3 - (snap.wrote_today || 0));
  return panel('방명록', `<form class="hs-gb-form" id="hs-gb"><input maxlength="80" name="body" placeholder="한 줄 남기기 (80자 · 오늘 ${left3}개 더)" ${left3 ? '' : 'disabled'} autocomplete="off"><button class="btn small primary" ${left3 ? '' : 'disabled'}>남기기</button></form>
    <ul class="hs-gb">${g.map(x => `<li><div>${cardName(x.writer_id, x.writer)} <small class="muted">${esc(new Date(x.at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit', hour12: false }))}</small>${x.can_delete ? `<button class="linkish small" data-gbdel="${x.id}">지우기</button>` : ''}</div><p>${esc(x.body)}</p></li>`).join('') || '<li class="muted small">아직 남긴 글이 없습니다.</li>'}</ul>
    <p class="muted small">별채마다 최근 20개를 남깁니다.</p>`, { ico: 'letter' });
}

// ─── 누르기 ───
function bind() {
  $('#hs-edit')?.addEventListener('click', () => { if (editing && dirty) return; editing = !editing; pick = null; sel = null; draw(); });
  $('#hs-done')?.addEventListener('click', async () => {
    if (dirty && !(await ask('저장하지 않은 배치가 있습니다. 버리고 닫을까요?', { title: '꾸미기 닫기', ok: '버리고 닫기', danger: true }))) return;
    resetState(); editing = false; draw();
  });
  $('#hs-undo')?.addEventListener('click', () => { resetState(); editing = true; draw(); });
  $('#hs-save')?.addEventListener('click', e => guard(e.currentTarget, save));
  $('#hs-rot')?.addEventListener('click', () => {
    if (pick?.type === 'fur') { pick.r = ((pick.r || 0) + 1) % 4; return paint(); }
    if (sel && FUR[sel.k]) { const s = sel; if (tryChange(() => { s.r = ((s.r || 0) + 1) % 4; })) sel = s; redrawEdit(); }
  });
  $('#hs-take')?.addEventListener('click', () => {
    if (!sel) return;
    const s = sel; tryChange(() => { state.items = state.items.filter(i => i !== s); state.wall = state.wall.filter(w => w !== s); }); sel = null; redrawEdit();
  });
  $$('[data-paltab]', el).forEach(b => b.addEventListener('click', () => { palTab = b.dataset.paltab; redrawEdit(); }));
  $$('[data-pal]', el).forEach(b => b.addEventListener('click', () => {
    const [type, k] = b.dataset.pal.split(':');
    if (type === 'paper' || type === 'ground') { if (state[type] !== k) tryChange(() => { state[type] = k; }); pick = null; return redrawEdit(); }
    pick = pick && pick.k === k && pick.type === type ? null : { type, k, r: 0 }; sel = null; redrawEdit();
  }));
  $$('[data-gate]', el).forEach(b => b.addEventListener('click', () => guard(b, async () => { const r = await rpc('world_housing_gate', { p_gate: b.dataset.gate }); snap.gate = r.gate; draw(); return { content: '대문을 바꿨습니다.' }; })));
  $('#hs-expand')?.addEventListener('click', e => guard(e.currentTarget, async () => {
    const nx = snap.next;
    if (!(await ask(`별채를 ${nx.size}×${nx.size}로 넓힐까요?\n${nx.gil.toLocaleString()}전과 ${Object.entries(nx.items).map(([i, n]) => `${nameOf(i)} ×${n}`).join(', ')}이(가) 들어갑니다.`, { title: '별채 넓히기', ok: '넓히기' }))) return;
    const r = await act('world_housing_expand'); await reload(); return r;
  }));
  $('#hs-store')?.addEventListener('click', openStore);
  $$('[data-merge]', el).forEach(b => b.addEventListener('click', () => guard(b, () => mergeAct(b, b.dataset.merge))));
  $('#hs-pets')?.addEventListener('click', openPets);
  $$('[data-pet]', el).forEach(b => b.addEventListener('click', () => petAct(b, b.dataset.pet)));
  $('#hs-gb')?.addEventListener('submit', e => {
    e.preventDefault(); const f = e.currentTarget, body = f.body.value.trim(); if (!body) return;
    guard(f.querySelector('button'), async () => { snap = await rpc('world_housing_guest_write', { p_owner: snap.owner_id, p_body: body }); resetKeepEdit(); return { content: '방명록에 남겼습니다.' }; });
  });
  $$('[data-gbdel]', el).forEach(b => b.addEventListener('click', () => guard(b, async () => {
    if (!(await ask('이 글을 지울까요?', { title: '방명록', ok: '지우기', danger: true }))) return;
    await rpc('world_housing_guest_delete', { p_id: Number(b.dataset.gbdel) }); snap.guestbook = snap.guestbook.filter(x => String(x.id) !== b.dataset.gbdel); draw(); return { content: '지웠습니다.' };
  })));
  if (cv) {
    cv.addEventListener('click', onCanvas);
    cv.addEventListener('mousemove', e => { if (!pick || pick.type !== 'fur') return; const [gx, gy] = room.toGrid(...bufXY(e)); const h = { x: Math.floor(gx), y: Math.floor(gy) }; if (!hover || h.x !== hover.x || h.y !== hover.y) { hover = h; paint(); } });
    cv.addEventListener('mouseleave', () => { hover = null; paint(); });
  }
}
function resetKeepEdit() { if (!editing) { resetState(); } draw(); }
function redrawEdit() { const y = window.scrollY; draw(); window.scrollTo(0, y); }
const bufXY = e => { const r = cv.getBoundingClientRect(); return [(e.clientX - r.left) * room.W / r.width, (e.clientY - r.top) * room.H / r.height]; };
function wallAt(bx, by) {
  const O = room.O, N = snap.size; let side, t;
  if (bx < O.x) { side = 'L'; t = (O.x - bx) / (TW / 2); } else { side = 'R'; t = (bx - O.x) / (TW / 2); }
  const z = O.y + t * TH / 2 - by;
  return t >= 0 && t <= N && z >= 0 && z <= WALLH ? { side, t, z } : null;
}
function onCanvas(e) {
  const [bx, by] = bufXY(e);
  const [gx, gy] = room.toGrid(bx, by), cx = Math.floor(gx), cy = Math.floor(gy), N = snap.size, onFloor = gx >= 0 && gy >= 0 && gx < N && gy < N;
  if (!editing) {
    if (pet && onFloor && Math.abs(gx - pet.x - .5) < 1 && Math.abs(gy - pet.y - .5) < 1) { fx.push({ key: 'heart', until: Date.now() + 1200 }); paint(); }
    return;
  }
  if (pick?.type === 'wall') {
    const w = wallAt(bx, by); if (!w) return toast('벽을 눌러 거세요.', 'error');
    const d = WALL[pick.k], t = Math.max(0, Math.min(N - d.w, Math.round((w.t - d.w / 2) * 10) / 10)), z = Math.max(4, Math.min(75 - d.h, Math.round(w.z - d.h / 2)));
    const it = { k: pick.k, side: w.side, t, z };
    if (tryChange(() => state.wall.push(it))) { if (left(idOf('wall', pick.k)) <= 0) pick = null; }
    return redrawEdit();
  }
  if (pick?.type === 'fur') {
    if (!onFloor) return;
    const it = { k: pick.k, x: cx, y: cy, r: pick.r || 0 };
    if (tryChange(() => state.items.push(it))) { if (left(idOf('fur', pick.k)) <= 0) pick = null; }
    return redrawEdit();
  }
  const got = room.hit(bx, by);
  if (got && (state.items.includes(got) || state.wall.includes(got))) { sel = got === sel ? null : got; return redrawEdit(); }
  if (sel && state.items.includes(sel) && onFloor) {
    const s = sel; if (tryChange(() => { s.x = cx; s.y = cy; })) sel = s; return redrawEdit();
  }
  if (sel && state.wall.includes(sel)) {
    const w = wallAt(bx, by); if (!w) return;
    const s = sel, d = WALL[s.k];
    if (tryChange(() => { s.side = w.side; s.t = Math.max(0, Math.min(N - d.w, Math.round((w.t - d.w / 2) * 10) / 10)); s.z = Math.max(4, Math.min(75 - d.h, Math.round(w.z - d.h / 2))); })) sel = s;
    return redrawEdit();
  }
  sel = null; redrawEdit();
}
async function save() {
  const body = { items: state.items.map(({ k, x, y, r }) => ({ k, x, y, r: r || 0 })), wall: state.wall.map(({ k, side, t, z }) => ({ k, side, t, z })), paper: state.paper, ground: state.ground };
  snap = await act('world_housing_save', { p_owner: snap.owner_id, p_state: body });
  editing = false; resetState(); draw();
  return { content: '별채를 저장했습니다.' };
}

// ─── 곳간 ───
async function openStore() {
  const drawStore = () => {
    const st = Object.entries(snap.store || {}).filter(([, n]) => n > 0), bag = Object.entries(snap.bag || {}).filter(([, n]) => n > 0);
    const used = st.reduce((a, [, n]) => a + n, 0);
    return `<p class="muted small">거둔 가구가 들어가는 곳입니다. 곳간 ${used}/${snap.store_cap}칸 · 꺼내면 가방으로 갑니다. 넣기·꺼내기는 안전지대에서, 버리기는 어디서나 됩니다. 곳간이 차면 새로 얻은 가구는 가방으로 갑니다.${snap.edit_block ? ` <b class="bad-text">넣기·꺼내기: ${esc(snap.edit_block)}</b>` : ''}</p>
      <h4>곳간</h4><ul class="hs-list">${st.map(([id, n]) => `<li><span>${esc(furName(id))} ×${n} <small class="muted">${GRADE[gradeOf(id)]}</small></span><span><button class="btn small" data-st="take:${id}">꺼내기</button><button class="btn small danger" data-st="discard:${id}">버리기</button></span></li>`).join('') || '<li class="muted small">비어 있습니다.</li>'}</ul>
      <h4>가방의 가구</h4><ul class="hs-list">${bag.map(([id, n]) => `<li><span>${esc(furName(id))} ×${n}</span><span><button class="btn small" data-st="put:${id}">곳간에 넣기</button></span></li>`).join('') || '<li class="muted small">가방에 가구가 없습니다.</li>'}</ul>`;
  };
  const m = openModal({ title: '곳간', body: drawStore() });
  const root = $('#modal');
  root?.addEventListener('click', e => {
    const b = e.target.closest('[data-st]'); if (!b) return;
    const [dir, id] = b.dataset.st.split(':');
    guard(b, async () => {
      if (dir === 'discard' && !(await ask(`${furName(id)} 하나를 버릴까요? 되돌릴 수 없습니다.`, { title: '가구 버리기', ok: '버리기', danger: true }))) return;
      const r = await act('world_housing_store_move', { p_item: id, p_qty: 1, p_dir: dir });
      snap = await rpc('world_housing_snapshot', { p_owner: null }); resetState();
      const body = $('#modal .modal-body') || $('#modal .modal > div:last-child'); if (body) body.innerHTML = drawStore();
      draw(); return r;
    });
  });
  return m;
}

// ─── 꼬마 동무 ───
async function openPets() {
  let ps;
  try { ps = await rpc('world_pet_snapshot'); } catch (e) { return toast(e.message, 'error'); }
  const inv = store.character?.inventory || {};
  const items = Object.entries(inv).filter(([k, n]) => n > 0 && (k.startsWith('pt_') || k.startsWith('pet_egg_')));
  const mine = new Map((ps.mine || []).map(p => [p.id, p])), room_ = ps.room || {};
  const body = `<p class="muted small">꼬마 동무는 능력치 효과가 없습니다. 별채에 한 마리를 두면 방 안을 돌아다니고, 손님도 쓰다듬거나 놀아 줄 수 있습니다. 데리고 다니면 조사원 카드에 함께 보입니다.</p>
    ${room_.pet_id ? `<div class="hs-petnow"><img src="${petImage(room_.pet_id, mine.get(room_.pet_id)?.adult, { scale: 2 })}" alt=""><b>${esc(mine.get(room_.pet_id)?.nick || PETS[room_.pet_id]?.name || '')}</b>
      <button class="btn small" data-walk="${room_.pet_out ? '0' : '1'}">${room_.pet_out ? '별채에 돌려놓기' : '데리고 다니기'}</button><button class="btn small" data-place="">별채에서 내보내기</button></div>` : ''}
    ${items.length ? `<h4>열 수 있는 바구니·알</h4><ul class="hs-list">${items.map(([k, n]) => `<li><span>${esc(nameOf(k))} ×${n}</span><button class="btn small primary" data-adopt="${esc(k)}">열기</button></li>`).join('')}</ul>` : ''}
    <h4>동무 도감 ${mine.size}/${(ps.species || []).length}</h4>
    <div class="pet-codex">${(ps.species || []).map(s => { const m = mine.get(s.id); return `<div class="pet-card g${s.grade} ${m ? '' : 'locked'}">
      <img src="${petImage(s.id, m?.adult, { dark: !m, scale: 3 })}" alt=""><b>${esc(m?.nick || s.name)}</b><small>${GRADE[s.grade]}${m ? ` · 친밀도 ${m.affinity}` : ''}</small>
      ${m ? `<span class="pet-act">${room_.pet_id === s.id ? '<em>별채에 있음</em>' : `<button class="btn small" data-place="${s.id}">별채에 두기</button>`}<button class="linkish small" data-nick="${s.id}">별명</button></span>` : `<small class="muted">${esc(s.how || '')}</small>`}</div>`; }).join('')}</div>`;
  openModal({ title: '꼬마 동무', body, wide: true });
  const root = $('#modal');
  root?.addEventListener('click', async e => {
    const b = e.target.closest('[data-adopt],[data-place],[data-walk],[data-nick]'); if (!b) return;
    if (b.dataset.nick) {
      const id = b.dataset.nick, cur = mine.get(id)?.nick || '';
      openModal({ title: '별명 짓기', body: `<form id="pet-nick" class="hs-gb-form"><input name="nick" maxlength="8" value="${esc(cur)}" placeholder="${esc(PETS[id]?.name || '')}" autocomplete="off"><button class="btn small primary">짓기</button></form><p class="muted small">8자까지 · 한글·영문·숫자 · 비우면 원래 이름으로 돌아갑니다.</p>` });
      $('#pet-nick')?.addEventListener('submit', ev => {
        ev.preventDefault(); const f = ev.currentTarget;
        guard(f.querySelector('button'), async () => { await rpc('world_pet_nickname', { p_pet: id, p_name: f.nick.value }); closeModal(); await reload(); openPets(); return { content: '별명을 지었습니다.' }; });
      });
      return;
    }
    guard(b, async () => {
      let r;
      if (b.dataset.adopt) r = await act('world_pet_adopt', { p_item: b.dataset.adopt });
      else if (b.dataset.walk) r = await rpc('world_pet_walk', { p_out: b.dataset.walk === '1' });
      else r = await rpc('world_pet_place', { p_pet: b.dataset.place || null });
      closeModal(); await reload(); openPets();
      return r?.content ? r : { content: '바꿨습니다.' };
    });
  });
}
async function petAct(btn, kind) {
  if (kind === 'feed') return chooseFood(btn);
  return guard(btn, async () => {
    const r = await rpc('world_pet_act', { p_owner: snap.owner_id, p_act: kind });
    afterPet(r, kind); return { content: kind === 'pat' ? '쓰다듬어 주었습니다.' : '놀아 주었습니다.' };
  });
}
function chooseFood(btn) {
  const inv = store.character?.inventory || {}, likes = PETS[snap.pet?.id]?.likes;
  const have = FOODS.filter(f => (inv[f] || 0) > 0);
  if (!have.length) return toast('가방에 동무 먹이가 없습니다. 안전지대 상점의 동무 주먹밥·별미를 사 오세요.', 'error');
  openModal({ title: '먹이 주기', body: `<p class="muted small">하루 세 번까지 친밀도가 오릅니다. 좋아하는 별미를 주면 더 많이 오릅니다.</p><ul class="hs-list">${have.map(f => `<li><span>${esc(nameOf(f))} ×${inv[f]}${f === likes ? ' <b class="good-text">좋아함</b>' : ''}</span><button class="btn small primary" data-food="${f}">주기</button></li>`).join('')}</ul>` });
  $('#modal')?.addEventListener('click', e => {
    const b = e.target.closest('[data-food]'); if (!b) return;
    guard(b, async () => { const r = await act('world_pet_act', { p_owner: snap.owner_id, p_act: 'feed', p_item: b.dataset.food }); closeModal(); afterPet(r, 'feed'); return { content: r.react === 'star' ? '아주 맛있게 먹었습니다!' : '냠냠 먹었습니다.' }; });
  });
}
function afterPet(r, kind) {
  fx.push({ key: r.react || 'heart', until: Date.now() + 1600 });
  if (pet) { pet.state = kind === 'play' ? 'play' : 'idle'; pet.wait = 12; pet.path = []; }
  if (snap.pet) { snap.pet.affinity = r.affinity; snap.pet.adult = r.adult; }
  if (snap.role !== 'owner') { snap.pet_today = { ...(snap.pet_today || {}), [kind]: true }; }
  if (r.grew) { toast('꼬마 동무가 훌쩍 자랐습니다!', 'ok'); if (pet) pet.adult = true; }
  if (!editing) { const y = window.scrollY; draw(); window.scrollTo(0, y); }
}

// ─── 동무 움직임: 빈 칸을 거닐다 잠자리에서 자고, 그릇·놀잇감에 들른다 ───
function walkable() {
  const N = snap.size, block = new Set(), spots = { bed: [], bowl: [], toy: [], perch: [] };
  for (const it of state.items) {
    const f = FUR[it.k]; if (!f || f.layer !== 'floor') continue;
    const [w, d] = dimsOf(it);
    for (let x = it.x; x < it.x + w; x++) for (let y = it.y; y < it.y + d; y++) {
      if (f.pet === 'bed' || f.pet === 'bowl' || f.pet === 'toy') spots[f.pet].push([x, y]); else block.add(`${x},${y}`);
      if (f.pet === 'perch') spots.perch.push([x, y, f.top || 1]);
    }
  }
  for (const it of state.items) { const f = FUR[it.k]; if (f?.layer === 'rug' && f.pet === 'bed') { const [w, d] = dimsOf(it); for (let x = it.x; x < it.x + w; x++) for (let y = it.y; y < it.y + d; y++) spots.bed.push([x, y]); } }
  return { N, ok: (x, y) => x >= 0 && y >= 0 && x < N && y < N && !block.has(`${x},${y}`), spots };
}
function setupPet() {
  pet = null;
  const p = snap.pet; if (!p || p.out || !PETS[p.id]) return;
  const w = walkable(); const free = [];
  for (let x = 0; x < w.N; x++) for (let y = 0; y < w.N; y++) if (w.ok(x, y)) free.push([x, y]);
  const [x, y] = free[Math.floor(Math.random() * free.length)] || [0, 0];
  pet = { id: p.id, adult: !!p.adult, x, y, path: [], state: 'idle', wait: 10, flip: false, f: 0, z: 0 };
}
function pathTo(w, sx, sy, tx, ty) {
  const key = (x, y) => `${x},${y}`, prev = new Map([[key(sx, sy), null]]), q = [[sx, sy]];
  const goal = (x, y) => x === tx && y === ty;
  while (q.length) {
    const [x, y] = q.shift();
    if (goal(x, y)) { const out = []; let k = key(x, y); while (k && k !== key(sx, sy)) { const [a, b] = k.split(',').map(Number); out.unshift([a, b]); k = prev.get(k); } return out; }
    for (const [dx, dy] of [[1, 0], [-1, 0], [0, 1], [0, -1]]) {
      const nx = x + dx, ny = y + dy, k = key(nx, ny);
      if (prev.has(k) || !(w.ok(nx, ny) || goal(nx, ny))) continue;
      prev.set(k, key(x, y)); q.push([nx, ny]);
    }
  }
  return null;
}
function tickPet() {
  if (!pet) return;
  pet.f++;
  if (pet.path.length) {
    const [tx, ty] = pet.path[0], dx = tx - pet.x, dy = ty - pet.y, sp = 0.14;
    if (Math.abs(dx) + Math.abs(dy) <= sp) { pet.x = tx; pet.y = ty; pet.path.shift(); if (!pet.path.length) { pet.state = pet.next || 'idle'; pet.wait = pet.state === 'sleep' ? 60 : pet.state === 'idle' ? 10 + Math.random() * 30 : 24; } }
    else { pet.x += Math.sign(dx) * Math.min(sp, Math.abs(dx)); pet.y += Math.sign(dy) * Math.min(sp, Math.abs(dy)); pet.flip = (dx - dy) < 0; pet.state = 'walk'; }
    return;
  }
  if (--pet.wait > 0) return;
  const w = walkable(), r = Math.random(), sx = Math.round(pet.x), sy = Math.round(pet.y);
  let target = null, next = 'idle';
  const pickOf = list => list[Math.floor(Math.random() * list.length)];
  if (r < 0.2 && w.spots.bed.length) { target = pickOf(w.spots.bed); next = 'sleep'; }
  else if (r < 0.3 && w.spots.bowl.length) { target = pickOf(w.spots.bowl); next = 'eat'; }
  else if (r < 0.4 && w.spots.toy.length) { target = pickOf(w.spots.toy); next = 'play'; }
  else { const free = []; for (let x = 0; x < w.N; x++) for (let y = 0; y < w.N; y++) if (w.ok(x, y)) free.push([x, y]); target = pickOf(free); }
  const path = target && pathTo(w, sx, sy, target[0], target[1]);
  pet.x = sx; pet.y = sy;
  if (path && path.length) { pet.path = path; pet.next = next; } else { pet.state = next === 'sleep' && target && target[0] === sx && target[1] === sy ? 'sleep' : 'idle'; pet.wait = 20; }
}
function drawPetIn(c) {
  if (!pet) return;
  const [sx, sy] = c.iso(pet.x + .5, pet.y + .5, 0);
  const st = pet.state, blink = st === 'idle' && pet.f % 28 < 2;
  const frame = st === 'sleep' ? 'sleep' : st === 'walk' || st === 'play' ? (pet.f % 4 < 2 ? 'step' : 'idle') : blink ? 'blink' : 'idle';
  const hop = st === 'play' && pet.f % 4 < 2 ? 2 : 0;
  drawPet(c.put, pet.id, pet.adult, frame, sx, sy + 3 - hop, st === 'play' ? pet.f % 8 < 4 : pet.flip);
  const top = sy - 14 - (pet.adult ? 4 : 0);
  if (st === 'sleep' && pet.f % 16 < 10) drawEffect(c.put, 'zz', sx + 6, top);
  if (st === 'eat' && pet.f % 10 < 6) drawEffect(c.put, 'bowl', sx + 8, sy + 2);
  for (const f of fx) drawEffect(c.put, f.key, sx, top - 2 - Math.floor((1600 - (f.until - Date.now())) / 300));
}
window.addEventListener('resize', () => { if (cv && room) { fit(); paint(); } });
