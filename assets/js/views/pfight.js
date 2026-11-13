import { rpc, esc, icon, fmt, $, $$, toast, store, spOf } from '../core.js';
import { loading, errorBox, chip } from './common.js';
import { bindTips, hideTip, memberLi, showSelected, fightNums, vitHtml, itemSectionsHtml, itemTray, resultBox, settleFight, tickUntil, serverClock,
  mobileLog, newestFirst, keepLogScroll, logRow, jobName } from './fightui.js';
import { INTENT, SKILL, trayList, weakNote } from './battle.js';
import { mountMeter } from './meter.js';
import { clearFightNotes } from '../settings.js';

const OUT = { won: '이김', down: '쓰러짐', fled: '달아남', gone: '빠짐', done: '끝' };
const trayIds = () => trayList({}, Infinity).map(([k]) => k);

let seenLog = -1, seenFid = null;
let el = null, fid = null, snap = null, timer = null, tick = null, sending = false, sel = null;
const clock = serverClock();

export async function render(root, sub) {
  el = root; fid = sub || null; snap = null; sel = null; bindTips(el);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${loading()}`;
  if (!fid) { try { fid = await rpc('world_pfight_mine'); } catch {} }
  if (!fid) { el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${errorBox('지금 든 파티 토벌이 없습니다.')}<a class="btn" href="#/home">현장으로</a>`; return; }
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); hideTip(); tray.close(); el = null; }
window.addEventListener('yh-battle-item', e => {
  if (!el?.isConnected || !fid || snap?.status !== 'fight' || !snap?.me) return;
  e.detail.handled = true;
  if (!snap.my_turn) { toast('아직 내 차례가 아닙니다. 차례가 오면 물품을 쓸 수 있습니다.', 'warn'); return; }
  const id = e.detail.id;
  if (!trayList({ [id]: 1 }).some(([k]) => k === id)) { toast('싸우는 동안에는 이 물품을 쓸 수 없습니다. 회복약·정화 부적·영력약만 「물품」으로 고릅니다.', 'warn'); return; }
  run({ disabled: false, dataset: {}, id: '' }, () => rpc('world_pfight_act', { p_fight: fid, p_action: 'item', p_item: id }));
});

const now = clock.now;
const ended = () => ['won', 'lost', 'fled', 'cancelled'].includes(snap?.status);
async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.status, prevRound = snap?.round, prevTurn = snap?.turn_id;
    snap = await rpc('world_pfight_snapshot', { p_fight: fid });
    clock.sync(snap);
    if ((prev && prev !== snap.status && ended()) || (prevRound && prevRound !== snap.round) || (prevTurn && prevTurn !== snap.turn_id)) await settle();
    draw(); plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
}
const settle = () => settleFight('world_pfight_act');

function plan() {
  if (!snap || ended() || document.hidden || !el) return;
  const wait = snap.status === 'gather' ? Math.min(3000, Math.max(400, new Date(snap.gather_ends) - now() + 300)) : snap.my_turn ? 10000 : 2000;
  timer = setTimeout(refresh, wait);
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

function countdown() {
  if (!el || !snap) return;
  tickUntil(el, now(), true);
}

function stateOf(m) {
  const s = snap, order = (s.order || []), curIdx = order.indexOf(s.turn_id), oi = order.indexOf(m.id);
  return m.out ? (OUT[m.out] || m.out) : s.status !== 'fight' ? '' : m.id === s.turn_id ? '차례' : oi >= 0 && oi < curIdx ? '행동함' : '기다림';
}
function memDetail() {
  showSelected(el && $('#pf-memdetail', el), (snap?.members || []).map(m => ({ ...m, hp: m.health })), sel, m => ({
    state: stateOf(m) || '', nums: [['정신', m.mental], ['영력·기력', m.sp], ['속도', m.spd ?? '-'], ...fightNums(m)] }),
    () => { sel = null; draw(); });
}

function draw() {
  if (!el || !snap) return;
  const s = snap, b = s.battle || {}, me = s.me, c = store.character || {};
  if (me || ended()) clearFightNotes(['pfight_invite'], 'fight_id', fid);
  const lg = s.log || [];
  if (seenFid !== fid) { seenFid = fid; seenLog = lg.length; }
  else if (lg.length > seenLog) { const mine = `${c.character_name} · `; if (lg.slice(seenLog).some(l => l.startsWith(mine))) weakNote((s.members || []).find(m => m.id === c.owner_id)?.weak); seenLog = lg.length; }
  const pct = s.max_hp ? Math.max(0, Math.min(100, s.hp / s.max_hp * 100)) : 100;
  const intent = b.gimmick ? [b.gimmick.name, b.gimmick.burst ? '모은 기운이 터지려 한다.' : b.gimmick.tell, b.gimmick.burst ? 3 : 2] : (INTENT[s.intent] || INTENT.strike);
  const members = s.members || [], byId = Object.fromEntries(members.map(m => [m.id, m]));
  const tgt = byId[s.target_id], cur = byId[s.turn_id];
  const fight = s.status === 'fight', playing = fight && me && !me.out;
  const top = mobileLog(), restoreLog = keepLogScroll(el, top);
  const head = s.status === 'gather' ? '동료를 기다리는 중' : fight ? `${s.round}라운드` : s.status === 'won' ? '쓰러뜨림' : s.status === 'cancelled' ? '혼자 싸우기로' : '싸움이 끝남';
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
        ${s.can_join ? `<button class="btn primary" id="pf-join" data-here="함께 싸우기">${icon('flag', 16)}<span>합류하기 · 탐색력 1</span></button>` : ''}
        <div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(s.hp)} / ${fmt.num(s.max_hp)}</b></div>
        ${fight ? `<div class="pf-turn ${s.my_turn ? 'mine' : ''}">${s.my_turn ? `${icon('sword', 15)}<b>내 차례입니다</b><span>행동을 고르면 바로 풀립니다</span>` : `${icon('hourglass', 15)}<b>${esc(cur?.name || '…')}의 차례</b><span>고르기를 기다리는 중</span>`}</div>${turnLine}
          <div class="intent lvl-${intent[2]}">${icon(intent[2] >= 2 ? 'flame' : 'eye', 18)}<div><b>다음 행동 · ${esc(intent[0])}</b><span>${esc(intent[1])}${tgt ? ` · 노리는 사람: <b>${esc(tgt.name)}</b>${s.mon_done ? '(이번 라운드에 침)' : '(그 차례 뒤에 반격)'}` : ''}</span></div></div>` : ''}
        ${ended() ? resultHtml(s) : ''}
      </div></section>
      ${playing ? actHtml(s, b, c) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${members.length}명</h2></header><div class="panel-body">
        <ul class="raid-mem pf-mem" id="pf-mem">${members.map(m => { const oi = order.indexOf(m.id);
          return memberLi({ ...m, hp: m.health }, { me: m.id === c.owner_id, turn: m.id === s.turn_id, tgt: m.id === s.target_id && fight, sel: m.id === sel, out: !!m.out,
            pre: oi >= 0 && fight ? `<i class="pf-no">${oi + 1}</i>` : '', state: stateOf(m), title: `${m.name} · ${jobName(m.job)}${m.spd != null ? ` · 속도 ${m.spd}` : ''}`,
            sub: `${esc(jobName(m.job))}${m.id === s.target_id && fight ? ' · <b class="bad">노림받음</b>' : ''}` }); }).join('')}</ul>
        <div class="mem-detail" id="pf-memdetail" hidden></div>
        <div class="dm-host" id="pf-meter"></div>
        <p class="muted small">빠른 사람(민첩 + 감각÷2)부터 차례로 움직입니다. 요괴는 라운드마다 이목이 높은 이를 더 자주 노리고, 그 사람의 차례 바로 뒤에 반격합니다(그 차례에 방어하면 막습니다). 30초 동안 고르지 않으면 방어로 넘어갑니다. 합류한 사람마다 요괴 체력이 늘고, 이기면 각자 전리품을 굴리고 경험치를 한 사람마다 10% 더 받습니다(세 명까지).</p></div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2></header><div class="panel-body">
        <ol class="raid-log">${newestFirst(lg, top).map(l => logRow(`no-time${/^—/.test(l) ? ' k-round' : ''}${l.startsWith(`${c.character_name} · `) ? ' mine' : ''}`, esc(l))).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
    </div>`;
  restoreLog();
  if (s.status !== 'gather') mountMeter($('#pf-meter', el), members.map(m => ({ ...m, me: m.id === c.owner_id })));
  memDetail(); tray.redraw();
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
const tray = itemTray({ title: '토벌에서 쓸 물품', bodyId: 'pf-items-body', fill: fillItems });
function fillItems(box) {
  const inv = store.character?.inventory || {};
  box.innerHTML = `<p class="muted small">${snap?.my_turn ? '물품을 고르면 내 차례의 행동이 됩니다.' : '내 차례가 오면 쓸 수 있습니다.'}</p>
    ${itemSectionsHtml(trayIds(), inv, '체력·정신 회복·치료')}`;
  $$('[data-use]', box).forEach(x => { x.disabled = !snap?.my_turn; x.onclick = () => { tray.close(); run(x, () => rpc('world_pfight_act', { p_fight: fid, p_action: 'item', p_item: x.dataset.use })); }; });
}

function resultHtml(s) {
  const ok = s.status === 'won';
  return resultBox(ok, ok ? `${esc((s.monster || '요괴') + "을(를)")} 함께 쓰러뜨렸습니다` : s.status === 'cancelled' ? '합류한 동료가 없어 혼자 싸웁니다' : '싸움이 끝났습니다',
    `<p class="small">${ok ? '보상은 각자 받았습니다(기록에 적힘).' : ''}</p>${s.bijang ? `<a class="btn small primary" href="#/bijang/${esc(s.bijang)}">${icon('chest', 14)}<span>비장고로</span></a> ` : ''}<a class="btn small" href="#/home">현장으로</a>`);
}

function bind() {
  const b = $('#pf-begin', el); if (b) b.onclick = () => run(b, () => rpc('world_pfight_begin', { p_fight: fid }));
  const j = $('#pf-join', el); if (j) j.onclick = () => run(j, async () => { await rpc('world_pfight_join', { p_fight: fid }); return rpc('world_pfight_snapshot', { p_fight: fid }); });
  $$('[data-pf]', el).forEach(x => x.onclick = () => run(x, () => rpc('world_pfight_act', { p_fight: fid, p_action: x.dataset.pf, p_item: null })));
  const ib = $('#pf-items', el); if (ib) ib.onclick = tray.open;
  $$('[data-pick]', el).forEach(x => x.onclick = () => { const id = x.dataset.pick; sel = sel === id ? null : id; draw(); });
}

async function run(btn, fn) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.status, prevRound = snap?.round, prevTurn = snap?.turn_id;
    const out = await fn();
    if (out) { snap = out; clock.sync(out); }
    if ((ended() && prev !== snap.status) || prevRound !== snap.round || prevTurn !== snap.turn_id || btn.id === 'pf-join') await settle();
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
