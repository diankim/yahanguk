// 파티 현장 토벌(7.1 → 7.7.3 속도순 차례): 라운드마다 빠른 사람부터 차례로, 내 차례에 고른 행동이 바로 풀린다(서버 world_pfight_*).
// 실시간 구독 없이 world_pfight_snapshot을 읽는다(plan 참고). 차례를 30초 비우면 서버가 방어로 넘긴다(초는 세어 보이지 않음).
import { rpc, emit, esc, icon, fmt, $, $$, toast, nameOf, loadCharacter, store, spOf, openLayer } from '../core.js';
import { loading, errorBox, chip, itemDesc, load } from './common.js';
import { bindTips, hideTip, memberLi, showMemDetail, vitHtml, itemListHtml, SP_ITEMS } from './fightui.js';
import { INTENT, SKILL, JOB, trayList, weakNote } from './battle.js';
import { mountMeter } from './meter.js';

const ACT = { attack: '공격', skill: '기술', guard: '방어', item: '물품', flee: '달아나기' };
const OUT = { won: '이김', down: '쓰러짐', fled: '달아남', gone: '빠짐', done: '끝' };

let seenLog = -1, seenFid = null; // 탄·기력·영력 부족 알림(7.5.9): 처음 그릴 때의 지난 기록은 건너뛰고 새로 붙은 내 줄만 본다
let el = null, fid = null, snap = null, timer = null, tick = null, skew = 0, sending = false, sel = null, itemLayer = null;

export async function render(root, sub) {
  el = root; fid = sub || null; snap = null; sel = null; bindTips(el);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${loading()}`;
  if (!fid) { try { fid = await rpc('world_pfight_mine'); } catch {} }
  if (!fid) { el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${errorBox('지금 든 파티 토벌이 없습니다.')}<a class="btn" href="#/home">현장으로</a>`; return; }
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); hideTip(); itemLayer?.close?.(); itemLayer = null; el = null; }
// 퀵슬롯·가방에서 누른 물품은 이 라운드의 「물품」 행동으로 고른다(7.7.2b, core.js battleItemRoute)
window.addEventListener('yh-battle-item', e => {
  if (!el?.isConnected || !fid || snap?.status !== 'fight' || !snap?.me) return;
  e.detail.handled = true;
  if (!snap.my_turn) { toast('아직 내 차례가 아닙니다. 차례가 오면 물품을 쓸 수 있습니다.', 'warn'); return; }
  const id = e.detail.id;
  if (!trayList({ [id]: 1 }).some(([k]) => k === id)) { toast('싸우는 동안에는 이 물품을 쓸 수 없습니다. 회복약·정화 부적·영력약만 「물품」으로 고릅니다.', 'warn'); return; }
  run({ disabled: false, dataset: {}, id: '' }, () => rpc('world_pfight_act', { p_fight: fid, p_action: 'item', p_item: id }));
});

const now = () => Date.now() + skew;
const ended = () => ['won', 'lost', 'fled', 'cancelled'].includes(snap?.status);
async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.status, prevRound = snap?.round, prevTurn = snap?.turn_id;
    snap = await rpc('world_pfight_snapshot', { p_fight: fid });
    if (snap?.now) skew = new Date(snap.now).getTime() - Date.now();
    if ((prev && prev !== snap.status && ended()) || (prevRound && prevRound !== snap.round) || (prevTurn && prevTurn !== snap.turn_id)) await settle();
    draw(); plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
}
async function settle() { try { await loadCharacter(); } catch {} emit('changed', { name: 'world_pfight_act' }); }

// 다시 읽기(7.7.3 속도순 차례): 모이는 중 3초 · 남의 차례 2초(앞 사람이 고르면 바로 내 차례가 보이게) · 내 차례 10초(비운 차례 넘김 등만)
function plan() {
  if (!snap || ended() || document.hidden || !el) return;
  const wait = snap.status === 'gather' ? Math.min(3000, Math.max(400, new Date(snap.gather_ends) - now() + 300)) : snap.my_turn ? 10000 : 2000;
  timer = setTimeout(refresh, wait);
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

function countdown() {
  if (!el || !snap) return;
  $$('[data-until]', el).forEach(x => { const ms = new Date(x.dataset.until) - now(); x.textContent = ms > 0 ? `${Math.ceil(ms / 1000)}초` : '곧'; });
}

// 참가자 상황(쓰러짐·달아남 / 차례·행동함·기다림)
function stateOf(m) {
  const s = snap, order = (s.order || []), curIdx = order.indexOf(s.turn_id), oi = order.indexOf(m.id);
  return m.out ? (OUT[m.out] || m.out) : s.status !== 'fight' ? '' : m.id === s.turn_id ? '차례' : oi >= 0 && oi < curIdx ? '행동함' : '기다림';
}
function memDetail() {
  const m = (snap?.members || []).find(x => x.id === sel);
  showMemDetail(el && $('#pf-memdetail', el), m && { ...m, hp: m.health }, m && {
    state: stateOf(m) || '', nums: [['정신', m.mental], ['영력·기력', m.sp], ['속도', m.spd ?? '-'], ['준 피해', fmt.num(m.dmg || 0)], ['받은 피해', fmt.num(m.taken || 0)], ['회복', fmt.num(m.heal || 0)]] },
    () => { sel = null; draw(); });
}

function draw() {
  if (!el || !snap) return;
  const s = snap, b = s.battle || {}, me = s.me, c = store.character || {};
  const lg = s.log || [];
  if (seenFid !== fid) { seenFid = fid; seenLog = lg.length; }
  else if (lg.length > seenLog) { const mine = `${c.character_name} · `; weakNote(lg.slice(seenLog).filter(l => l.startsWith(mine))); seenLog = lg.length; }
  const pct = s.max_hp ? Math.max(0, Math.min(100, s.hp / s.max_hp * 100)) : 100;
  const intent = b.gimmick ? [b.gimmick.name, b.gimmick.burst ? '모은 기운이 터지려 한다.' : b.gimmick.tell, b.gimmick.burst ? 3 : 2] : (INTENT[s.intent] || INTENT.strike);
  const members = s.members || [], byId = Object.fromEntries(members.map(m => [m.id, m]));
  const tgt = byId[s.target_id], cur = byId[s.turn_id];
  const fight = s.status === 'fight', playing = fight && me && !me.out;
  // 7.7.7g(사용자 요청): 휴대폰(640px 아래)은 최근 기록이 맨 위 — 봉연 토벌과 같게
  const top = window.matchMedia('(max-width: 640px)').matches;
  const oldLog = $('.raid-log', el), atBottom = !oldLog || (top ? oldLog.scrollTop < 24 : oldLog.scrollHeight - oldLog.scrollTop - oldLog.clientHeight < 24), oldTop = oldLog?.scrollTop || 0;
  const head = s.status === 'gather' ? '동료를 기다리는 중' : fight ? `${s.round}라운드` : s.status === 'won' ? '쓰러뜨림' : s.status === 'cancelled' ? '혼자 싸우기로' : '싸움이 끝남';
  // 차례 줄: 순서대로 이름, 요괴는 노린 사람 뒤에(이번 라운드에 이미 쳤으면 흐리게)
  const order = (s.order || []).filter(id => byId[id]);
  const curIdx = order.indexOf(s.turn_id);
  const turnLine = fight ? `<ol class="pf-order">${order.map((id, i) => {
      const m = byId[id], st = m.out ? 'out' : id === s.turn_id ? 'now' : i < curIdx ? 'done' : '';
      return `<li class="${st} ${id === c.owner_id ? 'me' : ''}">${esc(m.name)}</li>${id === s.target_id ? `<li class="foe ${s.mon_done ? 'done' : ''}">${icon('flame', 12)}요괴</li>` : ''}`; }).join('')}</ol>` : '';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌 · Lv.${s.level}</p><h1>${esc(s.monster || '요괴')} <small>${esc(head)}</small></h1></div>
      <div class="head-actions">${s.rank && s.rank !== 'normal' ? chip(s.rank === 'guardian' ? '우두머리' : '정예', s.rank === 'guardian' ? 'bad' : 'warn') : ''}</div></div>
    <div class="raid-wrap pf-wrap ${playing ? 'playing' : ''}">
      <section class="panel raid-boss"><div class="panel-body">
        ${s.status === 'gather' ? `<p class="raid-time">${icon('hourglass', 14)} <b data-until="${esc(s.gather_ends)}">…</b> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지 · 탐색력 1)</p>
            ${s.leader_id === c.owner_id ? `<button class="btn primary" id="pf-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : ''}` : ''}
        ${s.can_join ? `<button class="btn primary" id="pf-join">${icon('flag', 16)}<span>합류하기 · 탐색력 1</span></button>` : ''}
        <div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(s.hp)} / ${fmt.num(s.max_hp)}</b></div>
        ${fight ? `<div class="pf-turn ${s.my_turn ? 'mine' : ''}">${s.my_turn ? `${icon('sword', 15)}<b>내 차례입니다</b><span>행동을 고르면 바로 풀립니다</span>` : `${icon('hourglass', 15)}<b>${esc(cur?.name || '…')}의 차례</b><span>고르기를 기다리는 중</span>`}</div>${turnLine}
          <div class="intent lvl-${intent[2]}">${icon(intent[2] >= 2 ? 'flame' : 'eye', 18)}<div><b>다음 행동 · ${esc(intent[0])}</b><span>${esc(intent[1])}${tgt ? ` · 노리는 사람: <b>${esc(tgt.name)}</b>${s.mon_done ? '(이번 라운드에 침)' : '(그 차례 뒤에 반격)'}` : ''}</span></div></div>` : ''}
        ${ended() ? resultHtml(s) : ''}
      </div></section>
      ${playing ? actHtml(s, b, c) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${members.length}명</h2></header><div class="panel-body">
        <ul class="raid-mem pf-mem" id="pf-mem">${members.map(m => { const oi = order.indexOf(m.id);
          return memberLi({ ...m, hp: m.health }, { me: m.id === c.owner_id, turn: m.id === s.turn_id, tgt: m.id === s.target_id && fight, sel: m.id === sel, out: !!m.out,
            pre: oi >= 0 && fight ? `<i class="pf-no">${oi + 1}</i>` : '', state: stateOf(m), title: `${m.name} · ${JOB[m.job] || nameOf(m.job)}${m.spd != null ? ` · 속도 ${m.spd}` : ''}`,
            sub: `${esc(JOB[m.job] || nameOf(m.job))}${m.id === s.target_id && fight ? ' · <b class="bad">노림받음</b>' : ''}` }); }).join('')}</ul>
        <div class="mem-detail" id="pf-memdetail" hidden></div>
        <div class="dm-host" id="pf-meter"></div>
        <p class="muted small">빠른 사람(민첩 + 감각÷2)부터 차례로 움직입니다. 요괴는 라운드마다 이목이 높은 이를 더 자주 노리고, 그 사람의 차례 바로 뒤에 반격합니다(그 차례에 방어하면 막습니다). 30초 동안 고르지 않으면 방어로 넘어갑니다. 합류한 사람마다 요괴 체력이 늘고, 이기면 각자 전리품을 굴리고 경험치를 한 사람마다 10% 더 받습니다(세 명까지).</p></div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2></header><div class="panel-body">
        <ol class="raid-log">${(top ? [...lg].reverse() : lg).map(l => `<li class="no-time${/^—/.test(l) ? ' k-round' : ''}${l.startsWith(`${c.character_name} · `) ? ' mine' : ''}"><span>${esc(l)}</span></li>`).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
    </div>`;
  const log = $('.raid-log', el); if (log) log.scrollTop = atBottom ? (top ? 0 : log.scrollHeight) : oldTop;
  if (s.status !== 'gather') mountMeter($('#pf-meter', el), members.map(m => ({ ...m, me: m.id === c.owner_id })));
  memDetail(); if (itemLayer?.isConnected) fillItems();
  bind(); countdown();
}

function actHtml(s, b, c) {
  const a = s.me?.action, on = k => a === k ? 'on' : '';
  const skill = SKILL[c.job_key] || ['기술', ''];
  const ready = Number(b.pfx?.skill_ready || 0), wait = Math.max(0, ready - (Number(b.turn || 0) + 1));
  const medUsed = c.job_key === 'medic' && !!b.pfx?.med_used;
  const off = s.my_turn ? '' : 'disabled';
  return `<section class="panel raid-act ${s.my_turn ? 'my-turn' : ''}"><header class="panel-head"><h2>${icon('sword', 16)} ${s.my_turn ? '내 차례' : '내 행동'}</h2><small class="muted">${s.my_turn ? '고르면 바로 풀립니다' : '차례가 오면 단추가 켜집니다'}</small></header><div class="panel-body">
    <div class="raid-me">${vitHtml('체력', c.health, 'hp', c.health < 35)}${vitHtml(spOf()[0], c.spiritual_power, spOf()[1])}${vitHtml('정신', c.mental, 'mp')}</div>
    <div class="raid-buttons pf-btns">
      <button class="btn primary ${on('attack')}" data-pf="attack" ${off}>${icon('sword', 16)}<span>공격</span></button>
      <button class="btn ${on('skill')}" data-pf="skill" ${medUsed || wait || off ? 'disabled' : ''}>${icon('spark', 16)}<span>${esc(skill[0])}${medUsed ? ' (씀)' : wait ? ` (${wait}차례 뒤)` : ''}</span></button>
      <button class="btn ${on('guard')}" data-pf="guard" ${off}>${icon('shield', 16)}<span>방어</span></button>
      <button class="btn ${on('item')}" id="pf-items" type="button" ${off}>${icon('heart', 16)}<span>물품</span></button>
      <button class="btn ghost ${on('flee')}" data-pf="flee" ${off}>${icon('back', 16)}<span>달아나기</span></button>
    </div>
    <p class="muted small">${esc(skill[0])}: ${esc(skill[1])} 달아나면 이 싸움에서 빠집니다.</p>
  </div></section>`;
}
// 물품 창(봉연과 같은 겹쳐 뜨는 창): 전투에 쓸 수 있는 물품(battle.js trayList)을 체력·정신 / 영력으로 나눠 이름·회복 수치만
function openItems() {
  if (itemLayer?.isConnected) return;
  itemLayer = openLayer({ title: '토벌에서 쓸 물품', body: '<div id="pf-items-body"></div>' });
  fillItems();
  if (!itemDesc('tonic')) load('world_inventory_snapshot').then(fillItems).catch(() => {});
}
function fillItems() {
  const box = itemLayer && $('#pf-items-body', itemLayer); if (!box) return;
  const inv = store.character?.inventory || {}, ids = trayList(inv).map(([k]) => k);
  const sp = ids.filter(k => SP_ITEMS.has(k.replace(/_hq$/, ''))), hp = ids.filter(k => !sp.includes(k));
  box.innerHTML = `<p class="muted small">${snap?.my_turn ? '물품을 고르면 내 차례의 행동이 됩니다.' : '내 차례가 오면 쓸 수 있습니다.'}</p>
    <h3 class="raid-item-h">체력·정신 회복·치료</h3>${itemListHtml(hp, inv)}<h3 class="raid-item-h">${esc(spOf()[0])} 회복</h3>${itemListHtml(sp, inv)}`;
  $$('[data-use]', box).forEach(x => { x.disabled = !snap?.my_turn; x.onclick = () => { itemLayer?.close?.(); itemLayer = null; run(x, () => rpc('world_pfight_act', { p_fight: fid, p_action: 'item', p_item: x.dataset.use })); }; });
}

function resultHtml(s) {
  const ok = s.status === 'won';
  return `<div class="raid-result ${ok ? 'ok' : 'bad'}"><b>${ok ? `${esc(s.monster)}을(를) 함께 쓰러뜨렸습니다` : s.status === 'cancelled' ? '합류한 동료가 없어 혼자 싸웁니다' : '싸움이 끝났습니다'}</b>
    <p class="small">${ok ? '보상은 각자 받았습니다(기록에 적힘).' : ''}</p><a class="btn small" href="#/home">현장으로</a></div>`;
}

function bind() {
  const b = $('#pf-begin', el); if (b) b.onclick = () => run(b, () => rpc('world_pfight_begin', { p_fight: fid }));
  const j = $('#pf-join', el); if (j) j.onclick = () => run(j, async () => { await rpc('world_pfight_join', { p_fight: fid }); return rpc('world_pfight_snapshot', { p_fight: fid }); });
  $$('[data-pf]', el).forEach(x => x.onclick = () => run(x, () => rpc('world_pfight_act', { p_fight: fid, p_action: x.dataset.pf, p_item: null })));
  const ib = $('#pf-items', el); if (ib) ib.onclick = openItems;
  // 참가자를 누르면 자세히(다시 누르면 닫힘)
  $$('[data-pick]', el).forEach(x => x.onclick = () => { const id = x.dataset.pick; sel = sel === id ? null : id; draw(); });
}

async function run(btn, fn) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.status, prevRound = snap?.round, prevTurn = snap?.turn_id;
    const out = await fn();
    if (out) { snap = out; if (out.now) skew = new Date(out.now).getTime() - Date.now(); }
    if ((ended() && prev !== snap.status) || prevRound !== snap.round || prevTurn !== snap.turn_id || btn.id === 'pf-join') await settle();
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
