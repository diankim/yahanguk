import { rpc, store, esc, icon, fmt, $, $$, toast, nameOf, spOf } from '../core.js';
import { GW_DAILY } from '../rules.js';
import { loading, errorBox, chip } from './common.js';
import { fxChips, fxKeys, bindTips, hideTip, memberLi, showSelected, fightNums, vitHtml, coopBtn, itemListHtml, itemGroups, itemTray, resultBox,
  reloadCharacter, ammoHtml, ammoWarn, settleFight, tickUntil, serverClock, mobileLog, newestFirst, keepLogScroll, logRow, jobName, showResult, soloAidHtml, askPartySize, partyHere } from './fightui.js';
import { clearFightNotes } from '../settings.js';
import { mountMeter } from './meter.js';
import { GW_HEAL } from './item.js';
import { baseOf } from '../hq.js';
import { GAMEDATA as GD } from '../gamedata.js';

const BOSS = {
  gwiheo: { name: '귀허의 주인', arc: '외전 · 요인록', place: '귀허', PHASE: { 1: '두 얼굴', 2: '사슬 넷', 3: '이름 빼앗기', 4: '귀허의 소용돌이' }, last: '소용돌이', mechs: ['chain', 'name', 'vortex'],
    calm: '주인이 숨을 고른다.', tray: '귀허에서 쓸 물품', win: '귀허의 주인을 쓰러뜨렸습니다', lose: '소용돌이에 밀려났습니다', open: '귀허의 주인 앞에 서기',
    desc: '소용돌이 한가운데 빈 왕좌. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'gw',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 귀허 부적이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다. 외전 5장은 이 판으로도 이어집니다.',
    hard: '깊은 귀허 · 라운드마다 마감이 있고 수법이 거셉니다(4명을 권합니다). 모두 귀허 부적을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
  mukjeok: { name: '먹그림자', arc: '외전 · 묵적록', place: '아홉 칸 뜰', PHASE: { 1: '지워지는 칸', 2: '따라 쓰는 붓', 3: '발자국', 4: '가운데 칸' }, last: '가운데 칸', mechs: ['line', 'erase'],
    calm: '그림자가 붓에 먹을 다시 찍는다.', tray: '아홉 칸 뜰에서 쓸 물품', win: '먹그림자를 보냈습니다', lose: '명부가 먹으로 덮였습니다', open: '아홉 칸 명부 앞에 서기',
    desc: '쓰러진 자리의 매듭 안쪽, 아홉 칸으로 나뉜 명부. 가운데 칸의 이름을 지키며 칸을 밟아 기억을 되찾습니다. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'mk',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 봉인 먹줄이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다.',
    hard: '깊은 명부 · 라운드마다 마감이 있고 수법이 거셉니다. 모두 봉인 먹줄을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
};
const PHASE_AT = { 1: '체력 75%까지', 2: '50%까지', 3: '25%까지', 4: '끝까지' };
const COLOR = { 청: 'c-blue', 적: 'c-red', 황: 'c-yellow', 백: 'c-white' };
const KIND = { tell: 'k-tell', warn: 'k-warn', phase: 'k-phase', skill: 'k-skill', atk: 'k-out', hit: 'k-in', fall: 'k-fall', good: 'k-good', bad: 'k-bad', miss: 'k-miss', guard: 'k-guard', boss: 'k-boss', mem: 'k-mem', shadow: 'k-mem k-shadow' };
const GRID = [4, 9, 2, 3, 5, 7, 8, 1, 6];
const CELL = { 4: '왼쪽 위', 9: '위', 2: '오른쪽 위', 3: '왼쪽', 5: '가운데', 7: '오른쪽', 8: '왼쪽 아래', 1: '아래', 6: '오른쪽 아래' };
const MIMIC = { attack: '흉내: 공격', guard: '흉내: 막기', hesit: '머뭇거림' };

let el = null, fid = null, snap = null, timer = null, tick = null, sending = false, target = null, sel = null, shownStatus = '', lobbyBoss = null, moveTo = null, seenLog = 0;
const clock = serverClock();
const bossOf = () => BOSS[snap?.boss] || BOSS[lobbyBoss] || BOSS.gwiheo;
const story = () => snap?.mode === 'story';
const storyRules = () => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo']?.story || {};
const modeName = (md = snap?.mode) => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo']?.modes?.[md] || (md === 'story' ? '이야기판' : '어려움');
const PHASE = new Proxy({}, { get: (_, k) => story() ? (storyRules().phases || [])[k - 1] : bossOf().PHASE[k] });

export async function render(root, sub) {
  lobbyBoss = BOSS[sub] ? sub : null;
  el = root; fid = lobbyBoss ? null : sub || null; snap = null; target = null; sel = null; shownStatus = ''; moveTo = null; seenLog = 0; bindTips(el);
  const b = BOSS[lobbyBoss] || BOSS.gwiheo;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${b.arc}</p><h1>${b.name}</h1></div></div>${loading()}`;
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { el?.classList.remove('mk-live'); clearTimeout(timer); clearInterval(tick); hideTip(); tray.close(); el = null; }
const HEAL_ITEMS = GW_HEAL;
window.addEventListener('yh-battle-item', e => {
  const f = snap?.fight;
  if (!el?.isConnected || f?.status !== 'fight' || !snap?.joined) return;
  e.detail.handled = true;
  const id = e.detail.id || e.detail.item;
  if (!HEAL_ITEMS.includes(baseOf(id))) { toast('귀허의 주인과 싸우는 동안에는 체력 회복품만 쓸 수 있습니다.', 'warn'); return; }
  run({ disabled: false, dataset: {}, id: '' }, () => act({ p_action: 'item', p_target: target || snap.me, p_item: id }));
});

async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.fight?.status, r0 = snap?.fight?.round;
    snap = await rpc('world_gw_snapshot', { p_fight: fid, p_boss: lobbyBoss });
    clock.sync(snap);
    if (snap?.fight?.round !== r0) moveTo = null;
    memToast();
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (prev && prev !== snap?.fight?.status && ended()) await settle();
    draw();
    plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
}
const now = clock.now;
const ended = () => ['won', 'failed'].includes(snap?.fight?.status);
const settle = () => settleFight('world_gw_settle');

function plan() {
  const f = snap?.fight; if (!f || ended() || document.hidden) return;
  let wait;
  if (f.status === 'wait') wait = Math.min(3000, Math.max(400, new Date(f.start_at) - now() + 300));
  else {
    const toEnd = new Date(f.round_ends_at) - now() + 350;
    wait = snap.my_act ? Math.min(2000, Math.max(400, toEnd)) : Math.max(400, story() ? Math.min(5000, toEnd) : toEnd);
  }
  timer = setTimeout(refresh, wait);
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

function countdown() {
  if (!el || !snap?.fight) return;
  const f = snap.fight;
  tickUntil(el, now());
  const b = $('.gw-round-bar span', el);
  if (b && f.round_ends_at) {
    const len = bossOf().mechs.includes(f.mech?.k) ? 10000 : 5000;
    b.style.width = `${Math.max(0, Math.min(100, (new Date(f.round_ends_at) - now()) / len * 100))}%`;
  }
}

const nameOfMember = (s, id) => (s.members || []).find(m => m.id === id)?.name || '';
const ladder = ph => `<ol class="gw-ladder">${[1, 2, 3, 4].map(p => `<li class="${p === ph ? 'now' : p < ph ? 'done' : ''}" title="${PHASE_AT[p]}"><b>${p}</b><span>${p === 4 && !story() ? bossOf().last : PHASE[p]}</span></li>`).join('')}</ol>`;
const tellSize = t => { const n = String(t || '').length; return n > 110 ? 'xxl' : n > 80 ? 'xl' : n > 55 ? 'l' : ''; };

function roundBand(s) {
  const f = s.fight, mech = f.mech || {}, gim = story() ? !!mech.s : bossOf().mechs.includes(mech.k);
  const chosen = (s.members || []).filter(m => !m.out && !m.resting && m.acted).length, alive = (s.members || []).filter(m => !m.out && !m.resting).length;
  const myAct = s.my_act ? actName(s, s.my_act) : null;
  return `<div class="gw-band ${gim ? 'gim' : ''} ${mech.aoe ? 'aoe' : ''}">
    <div class="gw-band-top"><span class="gw-round">${f.round}라운드</span>${gim ? chip('수법', 'bad') : mech.aoe ? chip('기를 모음', 'warn') : ''}${mech.mimic ? chip(mech.stuck ? `${MIMIC[mech.mimic]} · 멈추지 않는 붓` : MIMIC[mech.mimic], mech.mimic === 'hesit' ? 'good' : 'warn') : ''}
      ${story() ? '' : `<span class="gw-band-time">${icon('hourglass', 13)}<b data-until="${esc(f.round_ends_at)}" data-sec="1">…</b></span>`}
      <span class="gw-chosen muted small">고른 사람 ${chosen}/${alive}</span></div>
    ${story() ? `<p class="muted small gw-calm">${alive > 1 ? '모두 고르면 다음 라운드로 넘어갑니다 · 1분 안에 안 고르면 방어' : '고르면 다음 라운드로 넘어갑니다 · 마감 없음'}</p>` : '<div class="bar gw-round-bar"><span></span></div>'}
    <p class="gw-tell ${tellSize(mech.tell)}">${esc(mech.tell || bossOf().calm)}</p>
    ${mech.k === 'chain' ? `<p class="small">내 손목의 사슬 · <b class="${COLOR[mech.mine] || ''}">${esc(mech.mine || '없음')}</b></p>` : ''}
    ${fxKeys(f.bfx).length ? `<div class="chips raid-bfx">${fxChips(f.bfx)}</div>` : ''}
    <p class="gw-mine">${myAct ? `${icon('check', 13)} 이번 라운드: <b>${esc(myAct)}</b>${story() ? '' : ' · 마감 전에는 바꿀 수 있습니다'}` : `${icon('bell', 13)} 아직 고르지 않았습니다${story() && alive === 1 ? '' : ' — 고르지 않으면 방어합니다'}`}</p>
  </div>`;
}
function actName(s, a) {
  const t = a.t ? nameOfMember(s, a.t) : '';
  if (a.a === 'coop') { const sk = (s.skills || []).find(x => x.id === a.s); return `기술 「${sk?.name || ''}」${t ? ` → ${t}` : ''}`; }
  if (a.a === 'item') return `회복품 「${nameOf(a.i)}」${t ? ` → ${t}` : ''}`;
  const mv = a.m ? ` · 「${CELL[a.m]}」 칸으로` : '';
  return (({ attack: '공격', guard: '방어', brace: '버티기', call: `이름 부르기 → ${t}`, chain: `${a.c || ''} 사슬 끊기`, recall: '되찾기' })[a.a] || a.a) + mv;
}

function draw() {
  if (!el) return;
  const s = snap || {};
  if (s.none) return drawLobby(s);
  const f = s.fight, me = (s.members || []).find(m => m.id === s.me) || {};
  const pct = f.max_hp ? Math.max(0, Math.min(100, f.hp / f.max_hp * 100)) : 100;
  const done = ended(), fight = f.status === 'fight';
  if (s.joined || done) clearFightNotes(['gw_invite'], 'fight_id', f.id);
  const cap = s.falls_cap || 10, solo = (s.members || []).length === 1;
  const endState = m => m.out || m.resting ? '쓰러짐' : '끝까지 버팀';
  const top = mobileLog() && !done, restoreLog = keepLogScroll(el, top);
  const B = bossOf(), mk = s.boss === 'mukjeok';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${B.arc} · ${B.place}</p>
      <h1>${B.name} ${chip(modeName(), story() ? 'ok' : 'bad')} <small>${f.status === 'wait' ? '모이는 중' : fight ? `${f.phase}단계 · ${esc(PHASE[f.phase] || '')}` : f.status === 'won' ? '쓰러뜨림' : '물러남'}</small></h1></div>
      <div class="head-actions">${mk && s.board && f.status !== 'wait' ? chip(`빛나는 칸 ${(s.board.lit || []).length}/8 · 이름 획 ${s.board.strokes}/${s.board.max}`, s.board.strokes <= 3 ? 'bad' : 'good') : ''}${f.enrage ? chip(`분노 ${f.enrage}`, 'bad') : ''}${fight ? `<span class="muted small">전체 남은 시간 <span data-until="${esc(f.ends_at)}">…</span></span>` : ''}</div></div>
    ${done ? resultHtml(f, s) : ''}
    <div class="raid-wrap pf-wrap gw-wrap ${mk ? 'mk' : ''} ${fight && s.joined ? 'playing' : ''} ${done ? 'ended' : ''}">
      <section class="panel raid-boss"><div class="panel-body">
        ${f.status === 'wait' ? `<p class="raid-time">${icon('hourglass', 14)} <span data-until="${esc(f.start_at)}">…</span> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지)</p>
            ${f.leader === s.me ? `<button class="btn primary" id="gw-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : !s.joined ? `<button class="btn primary" id="gw-join">${icon('flag', 16)}<span>합류하기${story() ? '' : ` · ${esc(itemName())} 1개`}</span></button>` : `<p class="hint good">${icon('check', 14)} 합류했습니다. 곧 시작합니다.</p>`}` : ''}
        ${f.status === 'wait' ? '' : `<div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(f.hp)} / ${fmt.num(f.max_hp)}</b></div>${ladder(f.phase)}`}
        ${mk && f.status !== 'wait' ? `<div class="mk-duo">${fight ? roundBand(s) : ''}${boardHtml(s, fight && s.joined)}</div>` : fight ? roundBand(s) : ''}
      </div></section>
      ${fight && s.joined ? actHtml(s, me) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${(s.members || []).length}명</h2>${fight && s.joined ? '<small class="muted gw-pick-hint">이름을 누르면 기술·이름 부르기·회복품 대상</small>' : ''}</header><div class="panel-body">
        <ul class="raid-mem pf-mem" id="gw-mem">${(s.members || []).map(m => memberLi(m, { cls: `${fight && s.joined && m.id === (target || s.me) ? 'pick' : ''} ${m.nameless ? 'tgt' : ''}`, me: m.id === s.me, sel: m.id === sel, out: m.out || m.resting, fx: m.fx,
          state: done ? endState(m) : m.out ? `물러남 ${m.out}라운드` : m.resting ? '쉬는 중' : fight ? (m.acted ? '골랐음' : '고르는 중') : '',
          sub: [esc(jobName(m.job)), mk && m.pos ? `「${CELL[m.pos]}」 칸` : '', m.bound ? '<b class="bad">먹에 묶임</b>' : '', m.nameless ? '<b class="bad">이름 잃음</b>' : '', fight && story() && f.mech?.blur === m.id ? '<b class="warn">이름 흐림</b>' : '', fight && story() && f.mech?.s === 'chain1' && f.mech.target === m.id ? '<b class="warn">사슬에 감김</b>' : '', solo ? `쓰러짐 ${Math.min(m.falls || 0, cap)}/${cap}` : '', fight && f.mech?.k === 'vortex' && f.mech.tank === m.id ? '물살이 쏠림' : '', `피해 ${fmt.num(m.dmg)}`].filter(Boolean).join(' · ') })).join('')}</ul>
        <div class="mem-detail" id="gw-memdetail" hidden></div>
${f.status === 'wait' ? '' : '<div class="dm-host" id="gw-meter"></div>'}</div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} ${done ? '전투 기록 · 라운드별로 되짚어 보기' : '전투 기록'}</h2></header><div class="panel-body">
        ${logHtml(s, me, done)}</div></section>
    </div>
    ${tipsHtml(s.tips)}`;
  el.classList.toggle('mk-live', mk && fight && !!s.joined);
  if (!done) restoreLog();
  mountMeter($('#gw-meter', el), (s.members || []).map(m => ({ ...m, me: m.id === s.me })));
  memDetail(s); tray.redraw();
  bind(); countdown();
  const was = shownStatus; shownStatus = f.status;
  if (was && was !== f.status && done) showResult(el);
}

function logHtml(s, me, done) {
  const rows = s.log || [];
  if (!rows.length) return '<ol class="raid-log"><li class="muted">아직 기록이 없습니다.</li></ol>';
  const groups = [];
  for (const l of rows) { if (!groups.length || groups[groups.length - 1].round !== l.round) groups.push({ round: l.round, lines: [] }); groups[groups.length - 1].lines.push(l); }
  const newestTop = !done && mobileLog();
  let out = '';
  for (const g of newestFirst(groups, newestTop)) {
    out += `<li class="gw-rhead">${g.round ? `${g.round}라운드` : '시작'}</li>`;
    for (const l of newestFirst(g.lines, newestTop)) out += logRow(`${KIND[l.kind] || ''}${me.name && String(l.text).startsWith(me.name) ? ' mine' : ''}`, esc(l.text));
  }
  return `<ol class="raid-log gw-log ${done ? 'full' : ''}">${out}</ol>`;
}

function memDetail(s) {
  showSelected(el && $('#gw-memdetail', el), s.members, sel, m => ({
    state: ended() ? (m.out || m.resting ? '쓰러짐' : '끝까지 버팀') : m.out ? `물러남 · ${m.out}라운드` : m.resting ? '쉬는 중' : m.nameless ? '이름 잃음' : s.fight?.status === 'fight' ? '싸우는 중' : '',
    nums: [['기여', `${m.share ?? 0}%`], ...fightNums(m), ['물러남', `${(s.members || []).length === 1 ? Math.min(m.falls || 0, s.falls_cap || 10) : m.falls || 0}번`]],
    fx: m.fx }), () => { sel = null; draw(); });
}
function actHtml(s, me) {
  const f = s.fight, mech = f.mech || {}, a = s.my_act, c = store.character || {};
  const tid = target || s.me, tName = nameOfMember(s, tid) || '나';
  const on = k => a?.a === k ? 'on' : '';
  const hp = me.hp ?? c.health, sp = s.sp ?? c.spiritual_power;
  const skills = s.skills || [], left = Number(s.items_left ?? 0), free = s.items_left == null, off = me.out ? 'disabled' : '';
  const outBox = me.out ? `<div class="raid-out"><b>${icon('hourglass', 14)} 물러나 숨을 고르는 중 · ${me.out}라운드</b><span>물러남이 끝나면 체력 30으로 쉬는 중이 됩니다. 저절로 돌아가지 않으니, 준비되면 행동을 골라 돌아가세요.</span></div>`
    : me.resting ? `<div class="raid-out rest"><b>${icon('check', 14)} 쉬는 중 · 준비되면 행동해서 돌아가세요</b><span>주인이 나를 노리지 않고 수법에서도 빠집니다. <b>공격·방어·버티기·기술·물품</b> 가운데 하나를 고르면 이번 라운드부터 다시 싸웁니다(먼저 <b>방어</b>나 <b>물품</b>이 안전합니다).</span></div>` : '';
  return `<section class="panel raid-act ${a ? '' : 'my-turn'}"><div class="panel-body">
    ${outBox}
    <div class="raid-me">${vitHtml('체력', hp, 'hp', hp < 35)}${vitHtml(spOf()[0], sp, spOf()[1])}${vitHtml('정신', c.mental, 'mp')}${ammoHtml(s.ammo)}${s.solo ? soloAidHtml(s.solo.dmg, s.solo.guard, s.solo.falls) : ''}
      <div class="raid-mine"><span class="rm-txt">대상 <b>${esc(tName)}</b>${a ? ` · 이번 라운드 <b>${esc(actName(s, a))}</b>` : ''}</span><span class="rm-fx">${fxChips(me.fx)}</span></div></div>
    <div class="raid-buttons gw-btns">
      <button class="btn primary ${on('attack')}" data-gw="attack" ${off}>${icon('sword', 16)}<span>공격</span></button>
      <button class="btn ${on('guard')}" data-gw="guard" ${off}>${icon('shield', 16)}<span>방어</span></button>
      <button class="btn ${on('brace')}" data-gw="brace" ${off} title="몸을 낮춰 막기만 합니다. 쏟아지는 물살·소용돌이에 방어보다 강합니다">${icon('down', 16)}<span>버티기</span></button>
      <button class="btn ${on('item')}" id="gw-items" type="button" ${off} title="${free ? '체력 회복품을 마음껏 씁니다' : '체력 회복품을 한 싸움에 두 개까지 씁니다'}(나 또는 고른 동료)">${icon('heart', 16)}<span>물품${free ? '' : ` ${left}`}</span></button>
    </div>
    <div class="raid-coopbox"><div class="coop-grid gw-skills">${skills.map(k => coopBtn({ ...k, on: a?.a === 'coop' && a?.s === k.id,
        why: me.out ? '물러남' : !k.unlocked ? `전투 숙련 ${k.rank}단계` : k.wait ? `${k.wait}라운드 뒤` : sp < k.cost ? `${spOf()[0]} ${k.cost}` : '',
        desc: `${k.desc} (${spOf()[0]} ${k.cost} · ${k.rounds}라운드마다)` }, `data-gw-skill="${esc(k.id)}"`)).join('') || '<p class="muted small">쓸 수 있는 협동 기술이 없습니다.</p>'}</div></div>
    ${mkGim(s, me, a, tName)}${storyGim(s, me, a)}
    ${!me.out && (mech.k === 'name' || mech.k === 'chain') ? `<div class="gw-gim"><span class="gw-gim-h" title="이번 라운드에만 나오는 행동">${icon('bell', 13)}<b>이번만</b></span>
      ${mech.k === 'name' ? `<button class="btn ${on('call')}" data-gw="call">${icon('users', 16)}<span>${esc(tName)}의 이름 부르기</span></button>` : ''}
      ${mech.k === 'chain' ? (mech.colors || []).filter((v, i, x) => x.indexOf(v) === i).map(col => `<button class="btn ${COLOR[col] || ''} ${a?.a === 'chain' && a?.c === col ? 'on' : ''}" data-gw="chain" data-c="${esc(col)}">${esc(col)} 사슬</button>`).join('') : ''}
    </div>` : ''}
  </div></section>`;
}
const tray = itemTray({ title: () => bossOf().tray, bodyId: 'gw-items-body', fill: fillItems });
function fillItems(box) {
  if (!snap?.fight) return;
  const inv = snap.items || {}, free = snap.items_left == null, left = Number(snap.items_left ?? 0), tName = nameOfMember(snap, target || snap.me) || '나';
  const [hp] = itemGroups(HEAL_ITEMS, inv), a = snap.my_act;
  box.innerHTML = `<p class="muted small">체력 회복품만 ${free ? '<b>마음껏</b> 씁니다' : `<b>한 싸움에 두 개까지</b> 씁니다 · 남은 횟수 <b>${left}/2</b>`} · 대상 <b>${esc(tName)}</b>(참가자 이름을 눌러 바꿈). 고르면 이번 라운드의 행동이 됩니다.</p>
    ${free || left ? itemListHtml(hp, inv, a?.a === 'item' ? a.i : '') : '<p class="hint warn">이 싸움에서 쓸 수 있는 회복품을 다 썼습니다.</p>'}`;
  $$('[data-use]', box).forEach(b => b.onclick = () => run(b, () => act({ p_action: 'item', p_target: target || snap.me, p_item: b.dataset.use })));
}

function resultHtml(f, s) {
  const mine = (s.members || []).find(m => m.id === s.me);
  const won = f.status === 'won';
  const B = bossOf(), fail = BOSS_RULES()?.fail || { dur: 10, er: 10, cd: 30 };
  return `<section class="panel raid-result-panel"><div class="panel-body">${resultBox(won, won ? B.win : B.lose, `<p class="small">${f.round}라운드 · ${PHASE[f.phase] || ''}${won ? '' : `까지 · 주인 체력 ${fmt.num(f.hp)} / ${fmt.num(f.max_hp)} 남음`}${mine ? ` · 준 피해 ${fmt.num(mine.dmg)} · 물러난 횟수 ${(s.members || []).length === 1 ? Math.min(mine.falls || 0, s.falls_cap || 10) : mine.falls}` : ''}</p>
    <p class="small">${story() ? (won ? '보상은 알림으로 보냈습니다(처음 보낼 때만 전을 받습니다).' : '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.') : won ? '보상은 알림으로 보냈습니다(처치는 하루 한 번 인정).' : `장착 장비가 ${fail.dur}% 닳고 침식이 ${fail.er} 올랐습니다. ${fail.cd}분 뒤 다시 도전할 수 있습니다.`} 아래 전투 기록에서 라운드마다 무엇이 있었는지 되짚어 볼 수 있습니다.</p>
    <a class="btn small" href="#/gw${s.boss === 'mukjeok' ? '/mukjeok' : ''}">처음으로</a>`)}</div></section>`;
}

const tipsHtml = tips => (tips || []).length ? `<details class="panel fold"><summary class="panel-head"><h2>${icon('help', 16)} 파훼법 <small class="muted">쓰러뜨린 조사원만 봅니다</small></h2></summary>
  <div class="panel-body"><ul class="small">${tips.map(t => `<li>${esc(t)}</li>`).join('')}</ul></div></details>` : '';

function drawLobby(s) {
  const B = bossOf();
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${B.arc} · ${B.place}</p><h1>${B.name}</h1></div></div>
    <section class="panel"><div class="panel-body">
      <p class="desc">${B.desc}</p>
      ${s.invite ? `<button class="btn primary" id="gw-join-inv">${icon('flag', 16)}<span>파티원의 도전에 합류</span></button>` : ''}
      ${s.story ? `<div class="gw-mode"><p class="small">${B.story}</p><p class="small muted">쓰러뜨린 횟수 ${s.story.kills}번</p>
        ${s.story.can_open ? `<button class="btn primary" id="gw-open-story">${icon('sword', 16)}<span>${esc(modeName('story'))}에 서기</span></button>` : `<p class="hint">${icon('pin', 14)} ${esc(s.story.why || '지금은 설 수 없습니다.')}</p>`}</div>` : ''}
      <div class="gw-mode">${s.story ? `<p class="small">${B.hard}</p>` : ''}<p class="small">${esc(itemName())} ${s.charms}개 · 처치 ${s.kills}번</p><p class="small muted">${esc(GW_DAILY)}</p>
      ${s.can_open ? `<button class="btn ${s.story ? '' : 'primary'}" id="gw-open">${icon('sword', 16)}<span>${s.story ? `${esc(modeName('hard'))}에 서기` : B.open}</span></button>`
        : `<p class="hint">${icon('pin', 14)} ${esc(s.why || '지금은 도전할 수 없습니다.')}</p>`}</div>
      <p class="muted small">같은 곳에 파티원이 있으면 60초 동안 모입니다.</p>
      ${s.last ? `<a class="btn small ghost" href="#/gw/${esc(s.last)}">${icon('scroll', 15)}<span>지난 도전 기록 보기</span></a>` : ''}
    </div></section>${tipsHtml(s.tips)}`;
  const o = $('#gw-open', el); if (o) o.onclick = async () => { if (!(await askPartySize(B.ask, await partyHere()))) return; run(o, () => rpc('world_gw_open', s.boss && s.boss !== 'gwiheo' ? { p_boss: s.boss } : {})); };
  const so = $('#gw-open-story', el); if (so) so.onclick = () => run(so, () => rpc('world_gw_open', { p_boss: s.boss, p_mode: 'story' }));
  const j = $('#gw-join-inv', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: s.invite }));
}

function bind() {
  const f = snap?.fight; if (!f) return;
  const b = $('#gw-begin', el); if (b) b.onclick = async () => { if (!(await askPartySize(bossOf().ask, (snap?.members || []).length || 1, true))) return; run(b, () => rpc('world_gw_begin', { p_fight: f.id })); };
  const j = $('#gw-join', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: f.id }));
  $$('[data-pick]', el).forEach(x => x.onclick = () => { const id = x.dataset.pick; sel = sel === id ? null : id; if (f.status === 'fight' && snap.joined) target = id; draw(); });
  const ib = $('#gw-items', el); if (ib) ib.onclick = tray.open;
  $$('[data-gw-skill]', el).forEach(x => x.onclick = () => {
    let tgt = target || snap.me;
    if ((snap.skills || []).find(k => k.id === x.dataset.gwSkill)?.target === 'ally' && tgt === snap.me) {
      const ms = (snap.members || []).filter(m => m.id !== snap.me), ally = ms.find(m => !m.out && !m.resting) || ms.find(m => !m.out);
      if (!ally) { toast('이 기술을 받을 동료가 없습니다.', 'warn'); return; }
      tgt = ally.id;
    }
    run(x, () => act({ p_action: 'coop', p_target: tgt, p_item: x.dataset.gwSkill }));
  });
  $$('[data-gw]', el).forEach(x => x.onclick = () => {
    const a = x.dataset.gw, args = { p_action: a, p_target: null, p_item: null };
    if (a === 'call') args.p_target = x.dataset.t || target || snap.me;
    if (a === 'chain') args.p_item = x.dataset.c;
    if (a === 'attack') ammoWarn(snap?.ammo);
    run(x, () => act(args));
  });
  $$('[data-mk-step]', el).forEach(x => x.onclick = () => step(Number(x.dataset.mkStep)));
}

const BOSS_RULES = () => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo'];
const itemName = () => BOSS_RULES()?.item_name || '귀허 부적';
function act(args) {
  const out = { p_fight: snap.fight.id, p_target: null, p_item: null, ...args };
  if (snap.boss === 'mukjeok' && moveTo) out.p_move = moveTo;
  return rpc('world_gw_act', out);
}
function step(cell) {
  const s = snap, b = s?.board; if (!b || s.fight?.status !== 'fight' || !s.joined) return;
  const here = b.my_pos;
  if (cell === here || cell === moveTo) moveTo = null;
  else if ((b.moves || []).includes(cell)) moveTo = cell;
  else { toast(b.moves?.length ? '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.' : '먹에 발이 묶여 이번 라운드에는 칸을 옮길 수 없습니다.', 'warn'); return; }
  const a = s.my_act;
  if (a?.a) {
    const again = { p_action: a.a, p_target: a.t || null, p_item: a.s || a.i || a.c || null };
    if (a.a === 'recall' && (moveTo || here) && ((b.lit || []).includes(moveTo || here) || (moveTo || here) === 5)) again.p_action = 'guard';
    run({ disabled: false, dataset: {}, id: '' }, () => act(again));
  } else draw();
}
function boardHtml(s, live) {
  const b = s.board || {}, mech = s.fight.mech || {}, lit = new Set(b.lit || []), ink = new Set(b.ink || []), mark = mech.s === 'mark';
  const cells = new Set(mech.k === 'line' || ['drop', 'pool'].includes(mech.s) ? mech.cells || [] : []), marked = new Set(mark ? mech.cells || [] : []);
  const moves = new Set(live ? b.moves || [] : []), here = b.my_pos, dest = live ? moveTo : null;
  const who = {}; for (const m of s.members || []) if (m.pos) (who[m.pos] = who[m.pos] || []).push(m);
  const ticks = Array.from({ length: b.max || 9 }, (_, i) => `<i class="${i < b.strokes ? 'on' : ''}"></i>`).join('');
  return `<div class="mk-wrap"><div class="mk-board ${mech.k === 'erase' || mech.s === 'keep' ? 'erase' : ''}" role="grid" aria-label="아홉 칸 명부">${GRID.map(n => {
    const center = n === 5, st = center ? 'center' : lit.has(n) ? 'lit' : 'blank';
    const cls = ['mk-cell', st, ink.has(n) ? 'ink' : '', cells.has(n) ? 'mk-line' : '', marked.has(n) ? 'mk-mark' : '', moves.has(n) ? 'mk-step' : '', n === dest ? 'dest' : '', n === here ? 'here' : ''].filter(Boolean).join(' ');
    const ppl = (who[n] || []).slice(0, 4).map(m => `<span class="mk-who ${m.id === s.me ? 'me' : ''} ${m.out || m.resting ? 'out' : ''}" title="${esc(m.name)}">${esc(String(m.name || '').slice(0, 1))}</span>`).join('');
    const tag = center ? `<span class="mk-strokes" title="이름 획 ${b.strokes}/${b.max}">${ticks}</span>` : `<small>${st === 'lit' ? '빛남' : '빈칸'}${ink.has(n) ? (story() ? ' · 웅덩이' : ' · 먹 자국') : ''}${marked.has(n) ? ' · 점' : ''}</small>`;
    const label = `${CELL[n]} 칸${center ? ' · 이름' : st === 'lit' ? ' · 빛남' : ' · 빈칸'}${cells.has(n) ? (story() ? ' · 먹이 떨어짐' : ' · 먹줄') : ''}${marked.has(n) ? ' · 지우려는 칸(서 있으면 막음)' : ''}${moves.has(n) ? ' · 눌러서 옮겨 서기' : ''}`;
    return `<button type="button" class="${cls}" ${moves.has(n) || (live && n === here) ? `data-mk-step="${n}"` : 'disabled'} aria-label="${esc(label)}" title="${esc(label)}">${tag}<span class="mk-ppl">${ppl}</span>${n === dest ? '<b class="mk-arrow">→</b>' : ''}</button>`;
  }).join('')}</div>
  <p class="mk-hint muted small">${live ? (moveTo ? `「${CELL[moveTo]}」 칸으로 옮겨 섭니다${s.my_act ? '' : ' — 행동을 고르면 함께 옮깁니다'} · 내 칸을 누르면 취소` : (b.moves || []).length ? '테 두른 이웃 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)' : '먹에 발이 묶여 이번 라운드에는 옮길 수 없습니다') : `기억 조각 ${b.mem || 0}/6`}</p></div>`;
}
function mkGim(s, me, a, tName) {
  if (s.boss !== 'mukjeok' || me.out) return '';
  const b = s.board || {}, mech = s.fight.mech || {}, dest = moveTo || b.my_pos, blank = dest && dest !== 5 && !(b.lit || []).includes(dest);
  const erase = mech.k === 'erase', solo = (s.members || []).length === 1;
  const keeper = (s.members || []).find(m => m.pos === 5 && !m.out && m.id !== s.me);
  const callT = solo ? s.me : target && target !== s.me ? target : keeper?.id;
  if (!blank && !erase) return '';
  return `<div class="gw-gim"><span class="gw-gim-h" title="이번 라운드에만 나오는 행동">${icon('bell', 13)}<b>이번만</b></span>
    ${blank ? `<button class="btn ${a?.a === 'recall' ? 'on' : ''}" data-gw="recall" title="지워진 빈칸에 서서 기억을 되찾습니다(공격 대신). 그 칸이 다시 빛나고 이름 획이 하나 돌아옵니다">${icon('scroll', 16)}<span>되찾기 · 「${CELL[dest]}」 칸</span></button>` : ''}
    ${erase && callT ? `<button class="btn ${a?.a === 'call' ? 'on' : ''}" data-gw="call" data-t="${esc(callT)}">${icon('users', 16)}<span>${solo ? '제 이름 부르기' : `${esc(nameOfMember(s, callT))}의 이름 부르기`}</span></button>` : ''}
    ${erase && !callT ? '<p class="small muted">가운데 칸에 선 동료를 눌러 이름을 불러 주세요.</p>' : ''}
  </div>`;
}
function storyGim(s, me, a) {
  if (!story() || s.boss === 'mukjeok' || me.out) return '';
  const mech = s.fight.mech || {}, chain = mech.s === 'chain1', blur = mech.blur;
  if (!chain && !blur) return '';
  return `<div class="gw-gim"><span class="gw-gim-h" title="이번 라운드에만 나오는 행동">${icon('bell', 13)}<b>이번만</b></span>
    ${chain ? `<button class="btn ${a?.a === 'chain' ? 'on' : ''}" data-gw="chain" data-c="">${icon('close', 16)}<span>${esc(nameOfMember(s, mech.target))}의 사슬 끊기</span></button>` : ''}
    ${blur ? `<button class="btn ${a?.a === 'call' ? 'on' : ''}" data-gw="call" data-t="${esc(blur)}">${icon('users', 16)}<span>${blur === s.me ? '제 이름 부르기' : `${esc(nameOfMember(s, blur))}의 이름 부르기`}</span></button>` : ''}
  </div>`;
}
function memToast() {
  const rows = snap?.log || [], last = rows.length ? rows[rows.length - 1].id : 0;
  if (!seenLog) { seenLog = last; return; }
  if (['won', 'failed'].includes(snap?.fight?.status)) { seenLog = last; return; }
  const fresh = rows.filter(l => l.id > seenLog && (l.kind === 'mem' || l.kind === 'shadow'));
  seenLog = Math.max(seenLog, last);
  if (!fresh.length) return;
  toast(fresh.map(l => l.text).join(' / '), 'mem', 7000);
}

async function run(btn, fn) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.fight?.status, round0 = snap?.fight?.round;
    const out = await fn();
    if (out) { snap = out; clock.sync(out); memToast(); }
    if (snap?.fight?.round !== round0) moveTo = null;
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (ended() && prev !== snap.fight.status) await settle();
    else if (btn.dataset.gwSkill || btn.dataset.use || btn.id === 'gw-open' || btn.id?.startsWith('gw-join')) await reloadCharacter();
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
