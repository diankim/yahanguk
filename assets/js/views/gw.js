import { rpc, store, esc, icon, fmt, $, $$, toast, nameOf, spOf } from '../core.js';
import { GW_DAILY, UG_RESULT } from '../rules.js';
import { loading, errorBox, chip } from './common.js';
import { spearRing, spearInner, spearTitle, isSpear } from './fightui.js';
import { forfeitVoteHtml, askForfeit, askForfeitVote, fxChips, fxKeys, bindTips, hideTip, memberLi, showSelected, fightNums, vitHtml, coopBtn, itemListHtml, itemGroups, itemTray, resultBox,
  reloadCharacter, ammoHtml, ammoWarn, settleFight, tickUntil, serverClock, mobileLog, newestFirst, keepLogScroll, logRow, fightCol, fitFight, unfitFight, jobName, showResult, soloAidHtml, askPartySize, partyHere, drawLater } from './fightui.js';
import { clearFightNotes } from '../settings.js';
import { bgroup, bclear } from '../rtb.js';
import { mountMeter } from './meter.js';
import { GW_HEAL } from './item.js';
import { baseOf } from '../hq.js';
import { GAMEDATA as GD } from '../gamedata.js';
import { hexOn, hexBoard, hexGim } from './gw_hex.js';
import { mkugCells, mkugMimic, mkugMemTag, mkugGim, mkugCue } from './gw_mkug.js';

const BOSS = {
  gwiheo: { name: '귀허의 주인', arc: '본편 · 요인록', place: '귀허', PHASE: { 1: '두 얼굴', 2: '사슬 넷', 3: '이름 빼앗기', 4: '귀허의 소용돌이' }, last: '소용돌이', mechs: ['chain', 'name', 'vortex'],
    calm: '주인이 숨을 고른다.', tray: '귀허에서 쓸 물품', win: '귀허의 주인을 쓰러뜨렸습니다', lose: '소용돌이에 밀려났습니다', open: '귀허의 주인 앞에 서기',
    desc: '소용돌이 한가운데 빈 왕좌. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'gw',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 귀허 부적이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다. 「요인록」 5장은 이 판으로도 이어집니다.',
    hard: '깊은 귀허 · 라운드마다 마감이 있고 수법이 거셉니다(4명을 권합니다). 모두 귀허 부적을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
  mukjeok: { name: '먹그림자', arc: '본편 · 묵적록', place: '아홉 칸 뜰', PHASE: { 1: '지워지는 칸', 2: '따라 쓰는 붓', 3: '발자국', 4: '가운데 칸' }, last: '가운데 칸', mechs: ['line', 'erase'],
    calm: '그림자가 붓에 먹을 다시 찍는다.', tray: '아홉 칸 뜰에서 쓸 물품', win: '먹그림자를 보냈습니다', lose: '명부가 먹으로 덮였습니다', open: '아홉 칸 명부 앞에 서기',
    desc: '쓰러진 자리의 매듭 안쪽, 아홉 칸으로 나뉜 명부. 가운데 칸의 이름을 지키며 칸을 밟아 기억을 되찾습니다. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'mk',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 봉인 먹줄이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다.',
    hard: '깊은 명부 · 라운드마다 마감이 있고 수법이 거셉니다. 모두 봉인 먹줄을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
  gapgwi: { name: '값귀', arc: '본편 · 명등기', place: '붉은 사당 골목', PHASE: { 1: '판결 망치', 2: '바가지', 3: '장부 맞추기', 4: '장 닫힘' }, last: '장 닫힘', mechs: [],
    calm: '값귀가 주판알을 딸깍인다.', tray: '붉은 사당에서 쓸 물품', win: '값귀를 쓰러뜨렸습니다', lose: '장부가 물 밑으로 가라앉았습니다', open: '값귀 앞에 서기',
    desc: '좌판 두 줄과 거리 한 줄로 된 붉은 사당 골목 장터. 장터 칸을 옮겨 다니며 머리 위 값(섬)을 다스려야 합니다. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'gg',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 붉은 사당 옻이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다.',
    hard: '깊은 장부 · 라운드마다 마감이 있고, 장부가 꼬일수록 장터가 사나워집니다. 모두 붉은 사당 옻을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
  sealed_lord: { name: '구중 봉주', arc: '무용담', place: '구중 봉연', PHASE: {}, last: '', mechs: [], calm: '봉주가 아홉 겹 봉인 위에서 숨을 고른다.', tray: '쓸 물품', win: '무용담을 끝맺었습니다', lose: '이야기 속에서 쓰러졌습니다', open: '', desc: '', ask: 'ug', story: '', hard: '' },
  baekya: { name: '백야', arc: '본편 · 명등기', place: '맹약 마당', PHASE: { 1: '화살비', 2: '붉은 붓', 3: '물방울과 가루', 4: '흰 밤' }, last: '흰 밤', mechs: [],
    calm: '하얀 형체의 몸 위로 이름 글자가 개미 떼처럼 기어 다닌다.', tray: '맹약 마당에서 쓸 물품', win: '흰 밤을 걷어 냈습니다', lose: '마당이 하얗게 바랬습니다', open: '맹약 마당 일곱 자리에 서기',
    desc: '바깥 등 기둥 일곱 칸과 안쪽 마당 일곱 칸으로 된 둥근 마당. 허공에 멈춘 것들이 숫자를 세니 맵을 보며 싸웁니다. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다.', ask: 'by',
    story: '이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 입장 물품이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다.',
    hard: '깊은 판 · 라운드마다 마감이 있고 수법이 거셉니다. 모두 입장 물품을 하나씩 쓰고, 밀려나면 장비가 닳고 침식이 오릅니다.' },
};
const PHASE_AT = { 1: '체력 75%까지', 2: '50%까지', 3: '25%까지', 4: '끝까지' };
const COLOR = { 청: 'c-blue', 적: 'c-red', 황: 'c-yellow', 백: 'c-white' };
const KIND = { tell: 'k-tell', warn: 'k-warn', phase: 'k-phase', skill: 'k-skill', atk: 'k-out', hit: 'k-in', fall: 'k-fall', good: 'k-good', bad: 'k-bad', info: 'k-tell', voice: 'k-phase', miss: 'k-miss', guard: 'k-guard', boss: 'k-boss', mem: 'k-mem', shadow: 'k-mem k-shadow' };
const GRID = [4, 9, 2, 3, 5, 7, 8, 1, 6];
const CELL = { 4: '왼쪽 위', 9: '위', 2: '오른쪽 위', 3: '왼쪽', 5: '가운데', 7: '오른쪽', 8: '왼쪽 아래', 1: '아래', 6: '오른쪽 아래' };
const MIMIC = { attack: '흉내: 공격', guard: '흉내: 막기', hesit: '머뭇거림' };

let el = null, fid = null, snap = null, timer = null, tick = null, sending = false, target = null, sel = null, shownStatus = '', lobbyBoss = null, moveTo = null, seenLog = 0;
let queued = null, lastRound = null, freshUntil = 0, roundLen = 5000, rtFight = null, rtLive = false, reading = false, readAgain = false;
const picked = new Set();
function roundSeen() {
  const f = snap?.fight; if (!f || f.status !== 'fight') return;
  if (f.round !== lastRound) roundLen = new Date(f.round_ends_at) - now() > 6000 ? 10000 : 5000;
  if (!snap.joined) { lastRound = f.round; return; }
  if (snap.my_act) picked.add(f.round);
  if (lastRound != null && f.round > lastRound) {
    freshUntil = Date.now() + 1600;
    const me = (snap.members || []).find(m => m.id === snap.me), missed = [];
    for (let r = lastRound; r < f.round; r++) if (r > 0 && !picked.has(r)) missed.push(r);
    if (missed.length && me && !me.out && !me.resting && f.mech?.k !== 'rest' && !story()) toast(`${missed.join('·')}라운드는 행동을 고르지 않아 방어로 넘어갔습니다.`, 'warn');
  }
  lastRound = f.round;
}
const clock = serverClock();
const bossOf = () => BOSS[snap?.boss] || BOSS[lobbyBoss] || BOSS.gwiheo;
const story = () => snap?.mode === 'story';
const storyRules = () => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo']?.story || {};
const modeName = (md = snap?.mode) => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo']?.modes?.[md] || (md === 'story' ? '이야기판' : '어려움');
const ult = () => snap?.mode === 'ultimate';
const ugPlace = () => GD.ultimate?.boards?.[snap?.board?.ug?.board]?.place || '';
const PHASE = new Proxy({}, { get: (_, k) => ult() ? (snap?.board?.phases || [])[k - 1] : story() ? (storyRules().phases || [])[k - 1] ?? bossOf().PHASE[k] : bossOf().PHASE[k] });

export async function render(root, sub) {
  lobbyBoss = BOSS[sub] ? sub : null;
  el = root; fid = lobbyBoss ? null : sub || null; snap = null; target = null; sel = null; shownStatus = ''; moveTo = null; seenLog = 0; lastRound = null; picked.clear(); bindTips(el);
  const b = BOSS[lobbyBoss] || BOSS.gwiheo;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${b.arc}</p><h1>${b.name}</h1></div></div>${loading()}`;
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { el?.classList.remove('mk-live'); rtWatch(true); clearTimeout(timer); clearInterval(tick); unfitFight(); hideTip(); tray.close(); el = null; }
const HEAL_ITEMS = GW_HEAL;
window.addEventListener('yh-battle-item', e => {
  const f = snap?.fight;
  if (!el?.isConnected || f?.status !== 'fight' || !snap?.joined) return;
  e.detail.handled = true;
  const id = e.detail.id || e.detail.item;
  if (!HEAL_ITEMS.includes(baseOf(id))) { toast(`${bossOf().name}과(와) 싸우는 동안에는 체력 회복품만 쓸 수 있습니다.`, 'warn'); return; }
  run({ disabled: false, dataset: {}, id: '' }, () => act({ p_action: 'item', p_target: target || snap.me, p_item: id }));
});

function rtWatch(off) {
  const id = !off && el && snap?.fight?.id && !ended() ? snap.fight.id : null;
  if (id === rtFight) return;
  rtFight = id; rtLive = false;
  if (!id) { bclear('gw'); return; }
  bgroup('gw', [`gw:${id}`], 'change', onSignal, live => { const was = rtLive; rtLive = live; if (live && !was && el) refresh(); });
}
function onSignal(p) {
  const f = snap?.fight;
  if (!el || !f || p?.id !== f.id) return;
  if (Number(p.round) < Number(f.round) || (Number(p.round) === Number(f.round) && p.status === f.status)) return;
  refresh();
}
async function refresh() {
  if (!el) return;
  if (reading) { readAgain = true; return; }
  reading = true;
  clearTimeout(timer);
  try {
    const prev = snap?.fight?.status, r0 = snap?.fight?.round;
    snap = await rpc('world_gw_snapshot', { p_fight: fid, p_boss: lobbyBoss });
    clock.sync(snap);
    if (snap?.fight?.round !== r0) moveTo = null;
    roundSeen();
    memToast();
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (prev && prev !== snap?.fight?.status && ended()) await settle();
    draw();
    plan();
    rtWatch();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
  finally { reading = false; if (readAgain) { readAgain = false; refresh(); } }
}
const now = clock.now;
const ended = () => ['won', 'failed'].includes(snap?.fight?.status);
const settle = () => settleFight('world_gw_settle');

function plan() {
  const f = snap?.fight; if (!f || ended() || document.hidden) return;
  let wait;
  if (f.status === 'wait') wait = Math.min(3000, Math.max(400, new Date(f.start_at) - now() + 300));
  else if (rtLive) {
    const toEnd = new Date(f.round_ends_at) - now() + 350, first = (snap.members || []).find(m => !m.out)?.id;
    wait = Math.max(400, toEnd + (snap.joined && first === snap.me ? 0 : snap.joined ? 2500 : 4000));
  } else {
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
    const len = Math.max(roundLen, bossOf().mechs.includes(f.mech?.k) || f.mech?.due ? 10000 : 5000);
    b.style.width = `${Math.max(0, Math.min(100, (new Date(f.round_ends_at) - now()) / len * 100))}%`;
  }
}

const nameOfMember = (s, id) => (s.members || []).find(m => m.id === id)?.name || '';
const ladder = ph => `<ol class="gw-ladder">${[1, 2, 3, 4].map(p => `<li class="${p === ph ? 'now' : p < ph ? 'done' : ''}" title="${PHASE_AT[p]}"><b>${p}</b><span>${p === 4 && !story() && !hexOn(snap) && !ult() ? bossOf().last : PHASE[p]}</span></li>`).join('')}</ol>`;
const tellSize = t => { const n = String(t || '').length; return n > 110 ? 'xxl' : n > 80 ? 'xl' : n > 55 ? 'l' : ''; };

function roundBand(s) {
  const f = s.fight, mech = f.mech || {}, gim = story() ? !!mech.s : bossOf().mechs.includes(mech.k) || !!mech.due;
  const chosen = (s.members || []).filter(m => !m.out && !m.resting && m.acted).length, alive = (s.members || []).filter(m => !m.out && !m.resting).length;
  const myAct = s.my_act ? actName(s, s.my_act) : null;
  const me = (s.members || []).find(m => m.id === s.me), fresh = Date.now() < freshUntil;
  const turn = !s.joined || !me || me.out || mech.k === 'rest' ? '' : s.my_act ? `<span class="gw-turn done">${icon('check', 13)}<span>${esc(myAct)}</span></span>` : '<span class="gw-turn todo">내 행동 고르기</span>';
  return `<div class="gw-band ${gim ? 'gim' : ''} ${mech.aoe ? 'aoe' : ''} ${fresh ? 'fresh' : ''}">
    <div class="gw-band-top"><span class="gw-round"><b>${f.round}</b>라운드</span>${fresh ? chip('새 라운드', 'warn') : ''}${turn}${gim ? chip('수법', 'bad') : mech.aoe ? chip('기를 모음', 'warn') : ''}${mech.mimic ? chip(mech.stuck ? `${MIMIC[mech.mimic]} · 멈추지 않는 붓` : MIMIC[mech.mimic], mech.mimic === 'hesit' ? 'good' : 'warn') : ''}
      ${story() ? '' : `<span class="gw-band-time">${icon('hourglass', 13)}<b data-until="${esc(f.round_ends_at)}" data-sec="1">…</b></span>`}
      <span class="gw-chosen muted small">고른 사람 ${chosen}/${alive}</span></div>
    ${story() ? `<p class="muted small gw-calm">${alive > 1 ? '모두 고르면 다음 라운드로 넘어갑니다 · 1분 안에 안 고르면 방어' : '고르면 다음 라운드로 넘어갑니다 · 마감 없음'}</p>` : '<div class="bar gw-round-bar"><span></span></div>'}
    ${s.board?.ugmk ? mkugCue(s) || `<p class="gw-tell">${esc(bossOf().calm)}</p>` : `<p class="gw-tell ${tellSize(mech.tell)}">${esc(mech.tell || bossOf().calm)}</p>`}
    ${mech.k === 'chain' ? `<p class="small">내 손목의 사슬 · <b class="${COLOR[mech.mine] || ''}">${esc(mech.mine || '없음')}</b></p>` : ''}
    ${fxKeys(f.bfx).length ? `<div class="chips raid-bfx">${fxChips(f.bfx)}</div>` : ''}
    <p class="gw-mine">${myAct ? `${icon('check', 13)} 이번 라운드: <b>${esc(myAct)}</b>${story() ? '' : ' · 마감 전에는 바꿀 수 있습니다'}` : `${icon('bell', 13)} 아직 고르지 않았습니다${story() && alive === 1 ? '' : ' — 고르지 않으면 방어합니다'}`}</p>
  </div>`;
}
function actName(s, a) {
  const t = a.t ? nameOfMember(s, a.t) : '';
  if (a.a === 'coop') { const sk = (s.skills || []).find(x => x.id === a.s); return `기술 「${sk?.name || ''}」${t ? ` → ${t}` : ''}`; }
  if (a.a === 'item') return `회복품 「${nameOf(a.i)}」${t ? ` → ${t}` : ''}`;
  const mv = a.m ? ` · ${s?.boss === 'mukjeok' && CELL[a.m] ? `「${CELL[a.m]}」` : `${a.m}번`} 칸으로` : '';
  return (({ attack: '공격', guard: '방어', brace: '버티기', call: snap?.boss === 'gapgwi' ? `값 매기기 → ${t}` : t && a.t === snap?.me && snap?.boss === 'baekya' ? '제 이름 외기' : `이름 부르기 → ${t}`, light: '등 켜기', sweep: `${a.c || ''}번 칸 걷어 내기`, move: '옮겨 서기', chain: `${a.c || ''} 사슬 끊기`, recall: '되찾기', deal: '흥정' })[a.a] || a.a) + mv;
}

function draw() {
  if (drawLater(draw)) return;
  if (!el) return;
  const s = snap || {};
  if (s.none) return drawLobby(s);
  const f = s.fight, me = (s.members || []).find(m => m.id === s.me) || {};
  const pct = f.max_hp ? Math.max(0, Math.min(100, f.hp / f.max_hp * 100)) : 100;
  const done = ended(), fight = f.status === 'fight';
  if (s.joined || done) clearFightNotes(['gw_invite'], 'fight_id', f.id);
  const cap = s.falls_cap, solo = (s.members || []).length === 1;
  const endState = m => m.out || m.resting ? '쓰러짐' : '끝까지 버팀';
  const top = mobileLog() && !done, restoreLog = keepLogScroll(el, top);
  const B = bossOf(), mk = s.boss === 'mukjeok', gg = s.boss === 'gapgwi', by = s.boss === 'baekya', mapped = mk || gg || by || hexOn(s);
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${ult() ? `${esc(GD.ultimate?.mode_name || '무용담')}${ugPlace() ? ` · ${esc(ugPlace())}` : ''}` : `${B.arc} · ${B.place}`}</p>
      <h1>${ult() ? esc(s.board?.ug?.board_name || B.name) : B.name} ${chip(ult() ? (GD.boss?.gwiheo?.modes?.ultimate || '무용담') : modeName(), story() ? 'ok' : 'bad')} <small>${f.status === 'wait' ? '모이는 중' : fight ? `${f.phase}단계 · ${esc(PHASE[f.phase] || '')}` : f.status === 'won' ? '쓰러뜨림' : '물러남'}</small></h1></div>
      <div class="head-actions">${mk && s.board && f.status !== 'wait' ? chip(`빛나는 칸 ${(s.board.lit || []).length}/8 · 이름 획 ${s.board.strokes}/${s.board.max}`, s.board.strokes <= 3 ? 'bad' : 'good') : ''}${f.enrage ? chip(`분노 ${f.enrage}`, 'bad') : ''}${fight ? `<span class="muted small">전체 남은 시간 <span data-until="${esc(f.ends_at)}">…</span></span>` : ''}${s.joined && (fight || f.status === 'wait') ? `<button class="btn small danger keep-label" id="gw-forfeit">${icon('back', 15)}<span>포기</span></button>` : ''}</div></div>
    ${!done ? forfeitVoteHtml(s.vote) : ''}
    ${done ? resultHtml(f, s) : ''}
    <div class="raid-wrap pf-wrap gw-wrap ${mk ? 'mk' : ''} ${mapped ? 'map' : ''} ${fight && s.joined ? 'playing' : ''} ${done ? 'ended' : ''}">
      ${fightCol('l', `<section class="panel raid-boss"><div class="panel-body">
        ${f.status === 'wait' ? `<p class="raid-time">${icon('hourglass', 14)} <span data-until="${esc(f.start_at)}">…</span> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지)</p>
            ${f.leader === s.me ? `<button class="btn primary" id="gw-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : !s.joined ? `<button class="btn primary" id="gw-join">${icon('flag', 16)}<span>합류하기${story() ? '' : ` · ${esc(itemName())} 1개`}</span></button>` : `<p class="hint good">${icon('check', 14)} 합류했습니다. 곧 시작합니다.</p>`}` : ''}
        ${f.status === 'wait' ? '' : `<div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(f.hp)} / ${fmt.num(f.max_hp)}</b></div>${ladder(f.phase)}`}
        ${ult() && f.status !== 'wait' ? ugBar(s) : ''}
        ${mapped && f.status !== 'wait' ? `<div class="mk-duo">${fight ? roundBand(s) : ''}${mapHtml(s, fight && s.joined)}</div>` : fight ? roundBand(s) : ''}
        ${s.boss === 'sealed_lord' && fight && s.board?.pair ? `<p class="small warn">${icon('chain', 13)} 봉인 사슬에 묶인 두 사람: ${(s.board.pair || []).map(id => esc(nameOfMember(s, id))).join(' · ')}</p>` : ''}
      </div></section>
      ${fight && s.joined ? actHtml(s, me) : ''}`)}
      ${fightCol('r', `<section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${(s.members || []).length}명</h2>${fight && s.joined ? '<small class="muted gw-pick-hint">이름을 누르면 기술·이름 부르기·회복품 대상</small>' : ''}</header><div class="panel-body">
        <ul class="raid-mem pf-mem" id="gw-mem">${(s.members || []).map(m => memberLi(m, { cls: `${fight && s.joined && m.id === (target || s.me) ? 'pick' : ''} ${m.nameless ? 'tgt' : ''}`, me: m.id === s.me, sel: m.id === sel, out: m.out || m.resting, fx: m.fx,
          state: done ? endState(m) : m.out ? `물러남 ${m.out}라운드` : m.resting ? '쉬는 중' : fight ? (m.acted ? '골랐음' : '고르는 중') : '',
          sub: [esc(jobName(m.job)), mk && m.pos ? `「${CELL[m.pos]}」 칸` : '', s.board?.ugmk ? mkugMemTag(s, m) : '', by && m.pos ? `${m.pos}번 칸` : '', hexOn(s) && m.pos ? `${m.pos}번 칸` : '', by && m.fade ? `<b class="warn">바램 ${m.fade}</b>` : '', gg && m.val != null ? `<b>${m.val}섬</b>` : '', gg && m.pos ? `${m.pos}번 칸` : '', m.bound ? '<b class="bad">먹에 묶임</b>' : '', m.nameless ? '<b class="bad">이름 잃음</b>' : '', fight && story() && f.mech?.blur === m.id ? '<b class="warn">이름 흐림</b>' : '', fight && story() && f.mech?.s === 'chain1' && f.mech.target === m.id ? '<b class="warn">사슬에 감김</b>' : '', solo && cap ? `쓰러짐 ${Math.min(m.falls || 0, cap)}/${cap}` : '', fight && f.mech?.k === 'vortex' && f.mech.tank === m.id ? '물살이 쏠림' : '', `피해 ${fmt.num(m.dmg)}`].filter(Boolean).join(' · ') })).join('')}</ul>
        <div class="mem-detail" id="gw-memdetail" hidden></div>
${f.status === 'wait' ? '' : '<div class="dm-host" id="gw-meter"></div>'}</div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} ${done ? '전투 기록 · 라운드별로 되짚어 보기' : '전투 기록'}</h2></header><div class="panel-body">
        ${logHtml(s, me, done)}</div></section>`)}
    </div>
    ${tipsHtml(s.tips)}`;
  el.classList.toggle('mk-live', mapped && fight && !!s.joined);
  mountMeter($('#gw-meter', el), (s.members || []).map(m => ({ ...m, me: m.id === s.me })));
  memDetail(s); tray.redraw();
  if (!done) { fitFight(el); restoreLog(); }
  bind(); countdown();
  const was = shownStatus; shownStatus = f.status;
  if (was && was !== f.status && done) showResult(el);
}

const mapHtml = (s, live) => s.boss === 'mukjeok' ? boardHtml(s, live) : s.boss === 'gapgwi' ? ggHtml(s, live) : s.boss === 'baekya' ? byBoard(s, live) : hexBoard(s, live, moveTo);

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
    nums: [['기여', `${m.share ?? 0}%`], ...fightNums(m), ['물러남', `${(s.members || []).length === 1 && s.falls_cap ? Math.min(m.falls || 0, s.falls_cap) : m.falls || 0}번`]],
    fx: m.fx }), () => { sel = null; draw(); });
}
function actHtml(s, me) {
  const f = s.fight, mech = f.mech || {}, a = s.my_act, c = store.character || {};
  const tid = target || s.me, tName = nameOfMember(s, tid) || '나';
  const on = k => a?.a === k ? 'on' : '';
  const hp = me.hp ?? c.health, sp = s.sp ?? c.spiritual_power;
  const skills = s.skills || [], left = Number(s.items_left ?? 0), free = s.items_left == null, resting = mech.k === 'rest', off = me.out || resting ? 'disabled' : '';
  const outBox = resting ? `<div class="raid-out rest"><b>${icon('hourglass', 14)} 막 사이 · 숨을 고르는 중 · 다음 막이 곧 시작됩니다</b></div>` : me.out ? `<div class="raid-out"><b>${icon('hourglass', 14)} 물러나 숨을 고르는 중 · ${me.out}라운드</b><span>물러남이 끝나면 체력 30으로 쉬는 중이 됩니다. 저절로 돌아가지 않으니, 준비되면 행동을 골라 돌아가세요.</span></div>`
    : me.resting ? `<div class="raid-out rest"><b>${icon('check', 14)} 쉬는 중 · 준비되면 행동해서 돌아가세요</b><span>주인이 나를 노리지 않고 수법에서도 빠집니다. <b>공격·방어·버티기·기술·물품</b> 가운데 하나를 고르면 이번 라운드부터 다시 싸웁니다(먼저 <b>방어</b>나 <b>물품</b>이 안전합니다).</span></div>` : '';
  return `<section class="panel raid-act ${a ? '' : 'my-turn'}"><div class="panel-body">
    ${outBox}
    <div class="raid-me">${vitHtml('체력', hp, 'hp', hp < 35)}${vitHtml(spOf()[0], sp, spOf()[1])}${vitHtml('정신', c.mental, 'mp')}${ammoHtml(s.ammo)}${s.solo ? soloAidHtml(s.solo.dmg, s.solo.guard, s.solo.falls) : ''}
      <div class="raid-mine"><span class="rm-txt">대상 <b>${esc(tName)}</b>${a ? ` · 이번 라운드 <b>${esc(actName(s, a))}</b>` : ''}</span><span class="rm-fx">${fxChips(me.fx)}</span></div></div>
    <div class="raid-buttons gw-btns">
      ${isSpear() ? `<button class="btn primary sp-atk ${on('attack')}" data-gw="attack" ${off} title="${esc(spearTitle(s.spch))}">${spearRing(s.spch, spearInner('공격', s.spch))}</button>`
        : `<button class="btn primary ${on('attack')}" data-gw="attack" ${off}>${icon('sword', 16)}<span>공격</span></button>`}
      <button class="btn ${on('guard')}" data-gw="guard" ${off}>${icon('shield', 16)}<span>방어</span></button>
      <button class="btn ${on('brace')}" data-gw="brace" ${off} title="몸을 낮춰 막기만 합니다.${s.boss === 'gwiheo' && !ult() ? ' 쏟아지는 물살·소용돌이에 방어보다 강합니다' : ''}">${icon('down', 16)}<span>버티기</span></button>
      <button class="btn ${on('item')}" id="gw-items" type="button" ${off} title="${free ? '체력 회복품을 마음껏 씁니다' : `체력 회복품을 한 싸움에 ${ult() ? (GD.boss?.[s.board?.ug?.board || s.boss]?.ultimate?.items ?? 3) : 2}개까지 씁니다`}(나 또는 고른 동료)">${icon('heart', 16)}<span>물품${free ? '' : ` ${left}`}</span></button>
    </div>
    <div class="raid-coopbox"><div class="coop-grid gw-skills">${skills.map(k => coopBtn({ ...k, on: a?.a === 'coop' && a?.s === k.id,
        why: me.out ? '물러남' : resting ? '막 사이' : !k.unlocked ? `전투 숙련 ${k.rank}단계` : k.wait ? `${k.wait}라운드 뒤` : sp < k.cost ? `${spOf()[0]} ${k.cost}` : '',
        desc: `${k.desc} (${spOf()[0]} ${k.cost} · ${k.rounds}라운드마다)` }, `data-gw-skill="${esc(k.id)}"`)).join('') || '<p class="muted small">쓸 수 있는 협동 기술이 없습니다.</p>'}</div></div>
    ${resting ? '' : `${s.board?.ugmk ? mkugGim(s, me, a, moveTo, nameOfMember, n => CELL[n]) : mkGim(s, me, a, tName)}${ggGim(s, me, a)}${byGim(s, me, a)}${hexGim(s, me, a, target, moveTo)}${storyGim(s, me, a)}`}
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
  const cap = ult() ? (GD.boss?.[snap.board?.ug?.board || snap.boss]?.ultimate?.items ?? 3) : 2;
  box.innerHTML = `<p class="muted small">체력 회복품만 ${free ? '<b>마음껏</b> 씁니다' : `<b>한 싸움에 ${cap}개까지</b> 씁니다 · 남은 횟수 <b>${left}/${cap}</b>`} · 대상 <b>${esc(tName)}</b>(참가자 이름을 눌러 바꿈). 고르면 이번 라운드의 행동이 됩니다.</p>
    ${free || left ? itemListHtml(hp, inv, a?.a === 'item' ? a.i : '') : '<p class="hint warn">이 싸움에서 쓸 수 있는 회복품을 다 썼습니다.</p>'}`;
  $$('[data-use]', box).forEach(b => b.onclick = () => run(b, () => act({ p_action: 'item', p_target: target || snap.me, p_item: b.dataset.use })));
}

function resultHtml(f, s) {
  const mine = (s.members || []).find(m => m.id === s.me);
  const won = f.status === 'won';
  const B = bossOf(), fail = BOSS_RULES()?.fail || { dur: 10, er: 10, cd: 30 };
  return `<section class="panel raid-result-panel"><div class="panel-body">${resultBox(won, ult() ? ugTitle(won, s) : won ? B.win : B.lose, `<p class="small">${f.round}라운드 · ${ult() ? esc(s.board?.ug?.act_name || '') : PHASE[f.phase] || ''}${won ? '' : `까지 · 주인 체력 ${fmt.num(f.hp)} / ${fmt.num(f.max_hp)} 남음`}${mine ? ` · 준 피해 ${fmt.num(mine.dmg)} · 물러난 횟수 ${(s.members || []).length === 1 && s.falls_cap ? Math.min(mine.falls || 0, s.falls_cap) : mine.falls || 0}` : ''}</p>
    <p class="small">${ult() ? ugResult(won, s) : story() ? (won ? '보상은 알림으로 보냈습니다(처음 이겼을 때만 전을 받습니다).' : '이야기판은 밀려나도 잃는 것이 없습니다. 숨을 고르고 다시 서세요.') : won ? '보상은 알림으로 보냈습니다(처치는 하루 한 번 인정).' : `장착 장비가 ${fail.dur}% 닳고 침식이 ${fail.er} 올랐습니다. ${fail.cd}분 뒤 다시 도전할 수 있습니다.`} 아래 전투 기록에서 라운드마다 무엇이 있었는지 되짚어 볼 수 있습니다.</p>
    <a class="btn small" href="#/gw${s.boss && s.boss !== 'gwiheo' ? `/${s.boss}` : ''}">처음으로</a>`)}</div></section>`;
}

function ugResult(won, s) {
  const U = GD.ultimate || {}, bd = U.boards?.[s.board?.ug?.board || s.boss] || {}, tk = U.tokens || {};
  return won ? esc(UG_RESULT.won(bd.token_name || '토큰', tk.clear ?? 3, tk.first ?? 10)) : UG_RESULT.lost;
}
function ugTitle(won, s) {
  const bd = GD.ultimate?.boards?.[s.board?.ug?.board || s.boss] || {};
  return esc(won ? UG_RESULT.title(bd.name || '무용담') : UG_RESULT.wiped);
}
const tipsHtml = tips => (tips || []).length ? `<details class="panel fold"><summary class="panel-head"><h2>${icon('help', 16)} 파훼법 <small class="muted">쓰러뜨린 조사원만 봅니다</small></h2></summary>
  <div class="panel-body"><ul class="small">${tips.map(t => `<li>${esc(t)}</li>`).join('')}</ul></div></details>` : '';

function drawLobby(s) {
  const B = bossOf(), ugHere = !!s.ultimate && s.here === false, ugMode = GD.ultimate?.mode_name || '무용담';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${ugHere ? `${esc(ugMode)} · ${esc(store.character?.location || '')}` : `${B.arc} · ${B.place}`}</p><h1>${ugHere ? esc(s.ultimate.name || B.name) : B.name}</h1></div></div>
    <section class="panel"><div class="panel-body">
      <p class="desc">${B.desc}</p>
      ${s.invite ? `<button class="btn primary" id="gw-join-inv">${icon('flag', 16)}<span>파티원의 도전에 합류</span></button>` : ''}
      ${s.story ? `<div class="gw-mode"><p class="small">${B.story}</p><p class="small muted">쓰러뜨린 횟수 ${s.story.kills}번</p>
        ${s.story.can_open ? `<button class="btn primary" id="gw-open-story">${icon('sword', 16)}<span>${esc(modeName('story'))}에 서기</span></button>` : `<p class="hint">${icon('pin', 14)} ${esc(s.story.why || '지금은 설 수 없습니다.')}</p>`}</div>` : ''}
      <div class="gw-mode">${s.story ? `<p class="small">${B.hard}</p>` : ''}<p class="small">${esc(itemName())} ${s.charms}개 · 처치 ${s.kills}번</p><p class="small muted">${esc(GW_DAILY)}</p>
      ${s.can_open ? `<button class="btn ${s.story ? '' : 'primary'}" id="gw-open">${icon('sword', 16)}<span>${s.story ? `${esc(modeName('hard'))}에 서기` : B.open}</span></button>`
        : `<p class="hint">${icon('pin', 14)} ${esc(s.why || '지금은 도전할 수 없습니다.')}</p>`}</div>
      ${s.ultimate ? `<div class="gw-mode gw-ult"><p class="small"><b>${esc(GD.boss?.[s.boss]?.modes?.ultimate || '무용담')}</b> · 객사 이야기꾼이 부풀린 이야기 속 싸움입니다. 둘에서 넷까지만 들어가고, 낌새를 미리 보여 주지 않습니다. 횟수 제한이 없고 져도 잃는 것이 없습니다.</p>
        ${s.ultimate.tip ? `<p class="small warn">${esc(s.ultimate.tip)}</p>` : ''}
        <p class="small muted">${[ugHere ? '' : esc(s.ultimate.name || ''), (s.ultimate.acts || []).length > 1 ? s.ultimate.acts.map((a, i) => `${i + 1}막 ${esc(a)}`).join(' → ') : '', `깬 횟수 ${s.ultimate.kills ?? 0}번`].filter(Boolean).join(' · ')}</p>
        ${s.ultimate.can_open ? `<button class="btn" id="gw-open-ult">${icon('sword', 16)}<span>${esc(GD.boss?.[s.boss]?.modes?.ultimate || '무용담')}에 서기</span></button>` : `<p class="hint">${icon('pin', 14)} ${esc(s.ultimate.why || '지금은 설 수 없습니다.')}</p>`}</div>` : ''}
      <p class="muted small">같은 곳에 파티원이 있으면 60초 동안 모입니다.</p>
      ${s.last ? `<a class="btn small ghost" href="#/gw/${esc(s.last)}">${icon('scroll', 15)}<span>지난 도전 기록 보기</span></a>` : ''}
    </div></section>${tipsHtml(s.tips)}`;
  const o = $('#gw-open', el); if (o) o.onclick = async () => { if (!(await askPartySize(B.ask, await partyHere()))) return; run(o, () => rpc('world_gw_open', s.boss && s.boss !== 'gwiheo' ? { p_boss: s.boss } : {})); };
  const so = $('#gw-open-story', el); if (so) so.onclick = () => run(so, () => rpc('world_gw_open', { p_boss: s.boss, p_mode: 'story' }));
  const uo = $('#gw-open-ult', el); if (uo) uo.onclick = async () => { if (!(await askPartySize('ug', await partyHere()))) return; run(uo, () => rpc('world_gw_open', { p_boss: s.boss || 'gwiheo', p_mode: 'ultimate' })); };
  const j = $('#gw-join-inv', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: s.invite }));
}

function bind() {
  const f = snap?.fight; if (!f) return;
  const b = $('#gw-begin', el); if (b) b.onclick = async () => { if (!story() && !(await askPartySize(ult() ? 'ug' : bossOf().ask, (snap?.members || []).length || 1, true))) return; run(b, () => rpc('world_gw_begin', { p_fight: f.id })); };
  const j = $('#gw-join', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: f.id }));
  const fb = $('#gw-forfeit', el);
  if (fb) fb.onclick = async () => { if (await askForfeit(`${bossOf().name} 싸움`, (snap.members || []).length <= 1, snap.vote)) run(fb, () => rpc('world_gw_forfeit', { p_fight: f.id })); };
  askVote(f);
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
    if (a === 'chain' || a === 'sweep') args.p_item = x.dataset.c;
    if (a === 'attack') ammoWarn(snap?.ammo);
    run(x, () => act(args));
  });
  $$('[data-mk-step]', el).forEach(x => x.onclick = () => step(Number(x.dataset.mkStep)));
}

const BOSS_RULES = () => GD.boss?.[snap?.boss || lobbyBoss || 'gwiheo'];
const itemName = () => BOSS_RULES()?.item_name || '귀허 부적';
async function act(args) {
  const out = { p_fight: snap.fight.id, p_target: null, p_item: null, ...args }, r = snap.fight.round;
  if ((['mukjeok', 'baekya', 'gapgwi'].includes(snap.boss) || hexOn(snap)) && moveTo) out.p_move = moveTo;
  const res = await rpc('world_gw_act', out);
  picked.add(r);
  return res;
}
function step(cell) {
  const s = snap, b = s?.board; if (!b || s.fight?.status !== 'fight' || !s.joined) return;
  const here = b.my_pos;
  if (cell === here || cell === moveTo) moveTo = null;
  else if ((b.moves || []).includes(cell)) moveTo = cell;
  else { toast(s.boss === 'baekya' ? '바로 옆 칸으로만 옮겨 설 수 있습니다.' : s.boss === 'gapgwi' ? '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.' : b.moves?.length ? '바로 옆(가로·세로) 칸으로만 옮겨 설 수 있습니다.' : '먹에 발이 묶여 이번 라운드에는 칸을 옮길 수 없습니다.', 'warn'); return; }
  const a = s.my_act;
  if (a?.a) {
    const again = { p_action: a.a, p_target: a.t || null, p_item: a.s || a.i || a.c || null };
    if (a.a === 'recall' && !b.ugmk && (moveTo || here) && ((b.lit || []).includes(moveTo || here) || (moveTo || here) === 5)) again.p_action = 'guard';
    run({ disabled: false, dataset: {}, id: '' }, () => act(again));
  } else draw();
}
function boardHtml(s, live) {
  const b = s.board || {}, mech = s.fight.mech || {}, lit = new Set(b.lit || []), ink = new Set(b.ink || []), mark = mech.s === 'mark';
  const cells = new Set(mech.k === 'line' || ['drop', 'pool'].includes(mech.s) ? mech.cells || [] : []), marked = new Set(mark ? mech.cells || [] : []);
  const moves = new Set(live ? b.moves || [] : []), here = b.my_pos, dest = live ? moveTo : null;
  const who = {}; for (const m of s.members || []) if (m.pos) (who[m.pos] = who[m.pos] || []).push(m);
  const ug = b.ugmk ? mkugCells(s) : null, rw = b.ug?.wm?.k === 'rewrite' ? b.ug.wm : null;
  if (rw && ug) {
    (rw.cells || []).forEach((c, i) => { const o = (ug[c] = ug[c] || { cls: new Set(), tags: [], tips: [] }); o.cls.add('wm-cell'); o.tags.push(`<b class="ug-t wm-n">${i + 1}</b>`); });
    if (rw.due) { const o = (ug[5] = ug[5] || { cls: new Set(), tags: [], tips: [] }); o.cls.add('ug-due'); o.tags.push('<b class="ug-t ug-erase due">名!</b>'); }
  }
  const ticks = Array.from({ length: b.max || 9 }, (_, i) => `<i class="${i < b.strokes ? 'on' : ''}"></i>`).join('');
  return `<div class="mk-wrap"><div class="mk-board ${mech.k === 'erase' || mech.s === 'keep' ? 'erase' : ''}" role="grid" aria-label="아홉 칸 명부">${GRID.map(n => {
    const center = n === 5, st = center ? 'center' : lit.has(n) ? 'lit' : 'blank';
    const cls = ['mk-cell', st, ink.has(n) ? 'ink' : '', cells.has(n) ? 'mk-line' : '', marked.has(n) ? 'mk-mark' : '', moves.has(n) ? 'mk-step' : '', n === dest ? 'dest' : '', n === here ? 'here' : '', ...(ug?.[n]?.cls || [])].filter(Boolean).join(' ');
    const ppl = (who[n] || []).slice(0, 4).map(m => { const mi = ug && mkugMimic(s, m.id); return `<span class="mk-who ${m.id === s.me ? 'me' : ''} ${m.out || m.resting ? 'out' : ''} ${mi ? `ug-mim${mi.due ? ' due' : ''}` : ''}" title="${esc(m.name)}${mi ? ` · 흉내 ${mi.n}` : ''}">${esc(String(m.name || '').slice(0, 1))}${mi ? `<i>${mi.n}</i>` : ''}</span>`; }).join('');
    const tag = center ? `<span class="mk-strokes" title="이름 획 ${b.strokes}/${b.max}">${ticks}</span>` : `<small>${st === 'lit' ? '빛남' : '빈칸'}${ink.has(n) ? (story() ? ' · 웅덩이' : ' · 먹 자국') : ''}${marked.has(n) ? ' · 점' : ''}</small>`;
    const label = `${CELL[n]} 칸${center ? ' · 이름' : st === 'lit' ? ' · 빛남' : ' · 빈칸'}${cells.has(n) ? (story() ? ' · 먹이 떨어짐' : ' · 먹줄') : ''}${marked.has(n) ? ' · 지우려는 칸(서 있으면 막음)' : ''}${ug?.[n] ? ` · ${ug[n].tips.join(' · ')}` : ''}${moves.has(n) ? ' · 눌러서 옮겨 서기' : ''}`;
    return `<button type="button" class="${cls}" ${moves.has(n) || (live && n === here) ? `data-mk-step="${n}"` : 'disabled'} aria-label="${esc(label)}" title="${esc(label)}">${ug?.[n]?.tags.length ? `<span class="ug-tags">${center ? tag : ''}${ug[n].tags.join('')}</span>` : tag}<span class="mk-ppl">${ppl}</span>${n === dest ? '<b class="mk-arrow">→</b>' : ''}</button>`;
  }).join('')}</div>
  <p class="mk-hint muted small">${b.ugmk ? `${b.ug?.wm ? `<b class="wm-name">「${esc(b.ug.wm.name || '')}」</b> · ` : ''}수법을 놓친 사람은 「기가 꺾임」${live ? ' · 테 두른 이웃 칸을 누르면 옮겨 섭니다' : ''}` : live ? (moveTo ? `「${CELL[moveTo]}」 칸으로 옮겨 섭니다${s.my_act ? '' : ' — 행동을 고르면 함께 옮깁니다'} · 내 칸을 누르면 취소` : (b.moves || []).length ? '테 두른 이웃 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)' : '먹에 발이 묶여 이번 라운드에는 옮길 수 없습니다') : `기억 조각 ${b.mem || 0}/6`}</p></div>`;
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
const ACT_NAME = { attack: '공격', guard: '방어', brace: '버티기', item: '물품', coop: '기술', deal: '흥정' };
function ggXY(c) { const r = Math.floor((c - 1) / 5), k = (c - 1) % 5; return [8 + k * 62 + 30, 22 + r * 66 + 32]; }
function ggHtml(s, live) {
  const b = s.board || {}, hz = b.hz || [], closed = new Set(b.closed || []), tags = b.tags || {}, moves = new Set(live ? b.moves || [] : []), here = b.my_pos, dest = live ? moveTo : null;
  const due = h => Number(h.left) <= 0, num = h => due(h) ? '!' : String(h.left);
  const who = {}; for (const m of s.members || []) if (m.pos && !m.out) (who[m.pos] = who[m.pos] || []).push(m);
  const colHz = {}; for (const h of hz) if (h.k === 'judge' || h.k === 'close') colHz[h.col] = h;
  const led = hz.find(h => h.k === 'ledger'), ledSet = new Set(led?.cells || []), cw = b.ug?.wm?.k === 'close' ? b.ug.wm : null, stallT = new Map((cw?.stalls || []).map(x => [Number(x.c), x.t]));
  let g = '';
  for (let c = 1; c <= 15; c++) {
    const r = Math.floor((c - 1) / 5), k = (c - 1) % 5, x = 8 + k * 62, y = 22 + r * 66, col = k + 1, stall = r !== 1;
    const jh = colHz[col], cls = ['gg-cell', stall ? 'stall' : 'street', closed.has(col) ? 'closed' : '', jh?.k === 'judge' ? (due(jh) ? 'judge due' : 'judge') : '', jh?.k === 'close' ? 'closing' : '',
      ledSet.has(c) || stallT.has(c) ? 'ledger' : '', moves.has(c) ? 'mk-step' : '', c === here ? 'here' : '', c === dest ? 'dest' : ''].filter(Boolean).join(' ');
    g += `<rect class="${cls}" x="${x}" y="${y}" width="58" height="62" rx="6" ${moves.has(c) || (live && c === here) ? `data-mk-step="${c}"` : ''}><title>${c}번 칸${stall ? ` · 좌판 값표 ${tags[c] ?? '?'}섬` : ' · 거리'}</title></rect>`;
    if (stall) g += `<text class="gg-tag ${ledSet.has(c) || stallT.has(c) ? 'led' : ''} ${hz.some(h => h.k === 'tagm' && Number(h.c) === c) ? 'hot' : ''}" x="${x + 52}" y="${y + 14}">${tags[c] ?? ''}섬</text>`;
  }
  for (const [col, h] of Object.entries(colHz)) g += `<text class="gg-coltag ${h.k} ${due(h) ? 'due' : ''}" x="${8 + (col - 1) * 62 + 29}" y="14">${h.k === 'judge' ? `망치 ${num(h)}${h.sh ? ' ↔' : ''}` : `닫힘 ${num(h)}`}</text>`;
  if (led) for (const c of led.cells) { const [x, y] = ggXY(c); g += `<text class="gg-ledtag ${due(led) ? 'due' : ''}" x="${x - 27}" y="${y - 18}">합${led.t}·${num(led)}</text>`; }
  for (const [c, t] of stallT) { const [x, y] = ggXY(c); g += `<text class="gg-ledtag wm ${cw.due ? 'due' : ''}" x="${x - 27}" y="${y - 18}">합${t}·${cw.due ? '!' : cw.end}</text>`; }
  for (const h of hz) {
    if (h.k === 'basket') { const [x, y] = ggXY(Number(h.c)); g += `<g class="gg-basket ${due(h) ? 'due' : ''}"><circle cx="${x}" cy="${y - 14}" r="13"/><text x="${x}" y="${y - 9}">${num(h)}</text></g>`; }
    if (h.k === 'tether' && h.cells?.length === 2) { const [x1, y1] = ggXY(h.cells[0]), [x2, y2] = ggXY(h.cells[1]); g += `<g class="gg-tether ${due(h) ? 'due' : ''}"><line x1="${x1}" y1="${y1}" x2="${x2}" y2="${y2}"/><text x="${(x1 + x2) / 2}" y="${(y1 + y2) / 2 - 6}">줄 ${num(h)}</text></g>`; }
  }
  for (const [c, ms] of Object.entries(who)) {
    const [x, y] = ggXY(Number(c));
    ms.slice(0, 4).forEach((m, i) => {
      const dx = ms.length > 1 ? (i % 2 ? 12 : -12) : 0, dy = ms.length > 2 ? (i > 1 ? 14 : -2) : 6;
      g += `<g class="gg-tok ${m.id === s.me ? 'me' : ''}"><circle cx="${x + dx}" cy="${y + dy}" r="12"/><text x="${x + dx}" y="${y + dy + 4}">${esc(String(m.name || '').slice(0, 1))}</text><text class="v" x="${x + dx}" y="${y + dy + 24}">${m.val ?? ''}섬</text><title>${esc(m.name)} · ${m.val ?? '?'}섬</title></g>`;
    });
  }
  g += `<rect class="gg-scale" x="320" y="88" width="54" height="62" rx="6"/><text class="gg-scale-t" x="347" y="123">값귀</text>`;
  const bg = hz.find(h => h.k === 'bargain'), mine = b.mine, cap = b.bargain?.cap, mul = b.bargain && mine != null && cap == null ? (b.bargain.base + b.bargain.k * mine) : null;
  return `<div class="gg-wrap"><svg class="gg-map" viewBox="0 0 380 230" role="img" aria-label="붉은 사당 골목 장터">${g}</svg>
    <p class="mk-hint muted small">${cw ? `<b class="wm-name">「${esc(cw.name || '')}」</b> · ` : ''}${mine != null ? `내 값 <b>${mine}섬</b>` : ''}${bg ? ` · <span class="gg-hot ${due(bg) ? 'due' : ''}">바가지 ${num(bg)}</span>${mul != null ? ` (지금 맞으면 ×${mul.toFixed(2)})` : ''}${cap != null ? ` (${cap}섬을 넘으면 맞음)` : ''}` : ''}${led ? ` · 장부 합 <b>${led.t}</b> · 지금 <b>${led.sum ?? 0}</b>` : ''}${closed.size ? ` · 닫힌 줄 ${closed.size}/${b.close_max || 4}` : ''}</p>
    ${live ? `<p class="mk-hint muted small">${moveTo ? `${moveTo}번 칸으로 옮겨 섭니다 · 내 칸을 누르면 취소` : '점선 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)'}</p>` : ''}</div>`;
}
function ggGim(s, me, a) {
  if (s.boss !== 'gapgwi' || me.out) return '';
  const b = s.board || {}, t = target && target !== s.me ? target : null, tm = (s.members || []).find(m => m.id === t), at = moveTo || b.my_pos;
  const near = tm && tm.pos && at && Math.abs(Math.floor((tm.pos - 1) / 5) - Math.floor((at - 1) / 5)) + Math.abs((tm.pos - 1) % 5 - (at - 1) % 5) <= 1;
  const down = b.mine != null ? Math.max(0, b.mine + (b.haggle ?? -4)) : null, up = tm ? Math.min(b.max ?? 9, (tm.val ?? 0) + (b.price ?? 3)) : null;
  return `<div class="gw-gim gg-gim"><span class="gw-gim-h" title="값을 바꾸는 행동">${icon('bell', 13)}<b>값</b></span>
    <button class="btn ${a?.a === 'deal' ? 'on' : ''}" data-gw="deal" title="값귀에게 흥정을 걸어 내 값을 ${-(b.haggle ?? -4)}섬 깎습니다(공격 대신)">${icon('coin', 16)}<span>흥정${down != null ? ` · ${b.mine}→${down}섬` : ''}</span></button>
    <button class="btn ${a?.a === 'call' ? 'on' : ''}" data-gw="call" ${t ? `data-t="${esc(t)}"` : 'disabled'} title="${t ? (near ? `${esc(tm.name)}의 값을 ${b.price ?? 3}섬 올려 줍니다(바로 옆 칸일 때만)` : '바로 옆 칸에 선 동료만 값을 매겨 줄 수 있습니다') : '값을 매겨 줄 동료의 이름을 누르세요'}">${icon('users', 16)}<span>값 매기기${t ? ` · ${esc(tm.name)} ${tm.val ?? '?'}→${up}섬` : ''}</span></button>
  </div>`;
}
function weakLine(s, w) {
  const ids = Object.keys(w || {}).filter(id => w[id]?.n);
  if (!ids.length) return '';
  const nm = id => id === s.me ? '나' : ((s.members || []).find(m => m.id === id)?.name || '');
  return `<p class="small">${ids.map(id => { const x = w[id]; return `<b class="${x.strong || id === s.me ? 'bad' : ''}" data-tip="${esc(`수법을 놓친 사람에게만 붙고, 놓칠 때마다 한 겹 쌓여 ${x.strong ? '' : '세 겹이면 더 큰 약화로 바뀝니다. '}겹마다 몇 라운드 뒤 하나씩 풀립니다. 주는 피해 ×${Number(x.deal).toFixed(2)} · 받는 피해 ×${Number(x.take).toFixed(2)} · 다음 풀림까지 ${x.left}라운드`)}">${esc(nm(id))} 「${esc(x.name)}」 ${x.n}겹</b>`; }).join(' · ')}</p>`;
}
function ugBar(s) {
  const u = s.board?.ug || {}, acts = Array.isArray(u.acts) ? u.acts : Array.from({ length: Number(u.acts) || 0 }, (_, i) => i + 1 === u.act ? u.act_name || '' : GD.boss?.[u.board || s.boss]?.ultimate?.acts?.[i]?.name || ''), cut = u.next_cut;
  return `<div class="gw-ug"><div class="chips">${acts.map((n, i) => chip(`${i + 1}막 ${n}`, i + 1 === u.act ? 'bad' : i + 1 < u.act ? 'ok' : '')).join('')}</div>
    <p class="small">${u.rest ? `<b>막 사이 · 숨 고르는 중</b> · ${u.rest}라운드` : `<b>${esc(u.act_name || '')}</b> · ${u.act_round ?? 0}라운드 · 이 막 전멸까지 <b class="${(u.wipe_left ?? 99) <= 4 ? 'bad' : ''}">${u.wipe_left ?? '?'}라운드</b>${cut ? ` · 체력 ${cut.pct}%까지 ${cut.left}라운드` : ''}${u.wm ? ` · <b class="bad wm-name">「${esc(u.wm.name || '')}」</b>` : ''}`}</p>${weakLine(s, u.weak)}</div>`;
}
const BY_HZ = { arrow: '화살', big: '굵은 화살', gust: '꺼져 가는 등', brush: '붉은 붓', stack: '물방울', spread: '흰 가루', tower: '기둥', clock: '모래시계', num: '차례 화살', sdrop: '물방울', flick: '흔들리는 등' };
function bySector(c) { return ((c - 1) % 7) + 1; }
function byNb(c) { return c <= 7 ? [((c + 5) % 7) + 1, (c % 7) + 1, c + 7] : [((c - 7 + 5) % 7) + 8, ((c - 7) % 7) + 8, c - 7]; }
function byCellAt(c, side = 0) {
  const da = 2 * Math.PI / 7, r = c <= 7 ? 137 : 76, m = -Math.PI / 2 + (bySector(c) - 1) * da + side * (c <= 7 ? 0.2 : 0.3);
  return [180 + r * Math.cos(m), 180 + r * Math.sin(m)];
}
function bySectorPath(k, r0, r1) {
  const da = 2 * Math.PI / 7, a = -Math.PI / 2 - da / 2 + (k - 1) * da, b = a + da, P = (r, t) => `${(180 + r * Math.cos(t)).toFixed(1)},${(180 + r * Math.sin(t)).toFixed(1)}`;
  return `M${P(r1, a)}A${r1},${r1} 0 0 1 ${P(r1, b)}L${P(r0, b)}A${r0},${r0} 0 0 0 ${P(r0, a)}Z`;
}
function byBoard(s, live) {
  const b = s.board || {}, lamps = new Set(b.lamps || []), moves = new Set(live ? b.moves || [] : []), here = b.my_pos, dest = live ? moveTo : null;
  const who = {}, hz = b.hz || [], fade = b.fade || {};
  for (const m of s.members || []) if (m.pos && !m.out) (who[m.pos] = who[m.pos] || []).push(m);
  const due = h => !h.frozen && Number(h.left) <= 0, num = h => h.frozen ? '멈춤' : due(h) ? '!' : String(h.left);
  const cellFill = new Map();
  for (const h of hz) if (h.k === 'brush') for (const c of h.cells || []) cellFill.set(c, due(h) ? 'by-brush due' : 'by-brush');
  let cells = '';
  for (let k = 1; k <= 7; k++) for (const [c, r0, r1] of [[k, 110, 165], [k + 7, 42, 110]]) {
    const cls = ['by-cell', c <= 7 ? 'outer' : 'inner', lamps.has(bySector(c)) ? 'lit' : 'pale', moves.has(c) ? 'mk-step' : '', c === dest ? 'dest' : '', c === here ? 'here' : '', cellFill.get(c) || ''].filter(Boolean).join(' ');
    const label = `${c}번 칸 · ${c <= 7 ? `등 기둥 ${lamps.has(c) ? '켜짐' : '꺼짐'}` : '마당'}${moves.has(c) ? ' · 눌러서 옮겨 서기' : ''}`;
    cells += `<path class="${cls}" d="${bySectorPath(k, r0, r1)}" ${moves.has(c) || (live && c === here) ? `data-mk-step="${c}"` : ''}><title>${esc(label)}</title></path>`;
  }
  let lampDots = '';
  for (let k = 1; k <= 7; k++) {
    const m = -Math.PI / 2 + (k - 1) * 2 * Math.PI / 7, x = 180 + 158 * Math.cos(m), y = 180 + 158 * Math.sin(m);
    const fl = hz.find(h => (h.k === 'flick' || h.k === 'gust') && Number(h.s) === k);
    lampDots += `<circle class="by-lamp ${lamps.has(k) ? 'on' : ''} ${fl ? 'flick' : ''}" cx="${x.toFixed(1)}" cy="${y.toFixed(1)}" r="6"/>`;
    if (fl?.k === 'gust') { const lx = 180 + 176 * Math.cos(m), ly = 180 + 176 * Math.sin(m); lampDots += `<text class="by-gust ${due(fl) ? 'due' : ''}" x="${lx.toFixed(0)}" y="${(ly + 4).toFixed(0)}">${num(fl)}</text>`; }
  }
  let marks = '';
  for (const h of hz) {
    if (h.k === 'big') { const [x, y] = byCellAt(Number(h.c)); marks += `<g class="by-big ${due(h) ? 'due' : ''}"><circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="54"/><text x="${x.toFixed(0)}" y="${(y - 30).toFixed(0)}">굵은 화살 ${num(h)}</text></g>`; continue; }
    if (h.k === 'brush') { const [x, y] = byCellAt(Number(h.s)); marks += `<text class="by-tag red" x="${x.toFixed(0)}" y="${(y - 18).toFixed(0)}">붓 ${num(h)}</text>`; continue; }
    if (['arrow', 'sdrop', 'tower'].includes(h.k)) {
      const [x, y] = byCellAt(Number(h.c), who[h.c] ? -1 : 0);
      if (h.k === 'tower') marks += `<g class="by-tower ${due(h) ? 'due' : ''}"><rect x="${(x - 13).toFixed(0)}" y="${(y - 20).toFixed(0)}" width="26" height="30" rx="4"/><text x="${x.toFixed(0)}" y="${(y + 1).toFixed(0)}">${Number(h.need) > 1 ? `${h.need}명` : '1명'}</text><text class="sm" x="${x.toFixed(0)}" y="${(y + 22).toFixed(0)}">${num(h)}</text></g>`;
      else marks += `<g class="by-hz ${h.k} ${due(h) ? 'due' : ''} ${h.frozen ? 'frozen' : ''}"><circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="17"/><text x="${x.toFixed(0)}" y="${(y + 7).toFixed(0)}">${num(h)}</text></g>`;
      continue;
    }
    const tm = (s.members || []).find(m => m.id === h.t); if (!tm?.pos) continue;
    const [x, y] = byCellAt(tm.pos);
    if (h.k === 'stack') marks += `<g class="by-ring stack ${due(h) ? 'due' : ''}"><circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="44"/><text x="${x.toFixed(0)}" y="${(y - 48).toFixed(0)}">물방울 ${num(h)}${h.sw ? ' ⇄' : ''}</text></g>`;
    if (h.k === 'spread' || h.k === 'num') marks += `<g class="by-ring spread ${due(h) ? 'due' : ''}"><circle cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="44"/><text x="${x.toFixed(0)}" y="${(y + 58).toFixed(0)}">${h.k === 'num' ? `${h.i}번 화살 ` : '흰 가루 '}${num(h)}${h.sw ? ' ⇄' : ''}</text></g>`;
    if (h.k === 'clock') marks += `<g class="by-clock ${due(h) ? 'due' : ''}"><text x="${(x + 22).toFixed(0)}" y="${(y - 14).toFixed(0)}">⧗${num(h)}</text></g>`;
  }
  let tokens = '';
  for (const [c, ms] of Object.entries(who)) {
    const busy = hz.some(h => ['arrow', 'sdrop', 'tower'].includes(h.k) && Number(h.c) === Number(c)), [x, y] = byCellAt(Number(c), busy ? 1 : 0);
    ms.slice(0, 4).forEach((m, i) => {
      const dx = (i % 2 ? 9 : -9) * (ms.length > 1 ? 1 : 0), dy = (i > 1 ? 10 : -4) * (ms.length > 1 ? 1 : 0), f = Number(fade[m.id] || 0);
      tokens += `<g class="by-tok ${m.id === s.me ? 'me' : ''} ${f ? `fade${Math.min(3, f)}` : ''}"><circle cx="${(x + dx).toFixed(0)}" cy="${(y + dy).toFixed(0)}" r="12"/><text x="${(x + dx).toFixed(0)}" y="${(y + dy + 5).toFixed(0)}">${esc(String(m.name || '').slice(0, 1))}</text><title>${esc(m.name)}${f ? ` · 바램 ${f}` : ''}</title></g>`;
    });
  }
  if (dest) { const [x, y] = byCellAt(dest); tokens += `<circle class="by-destmark" cx="${x.toFixed(0)}" cy="${y.toFixed(0)}" r="16"/>`; }
  const wn = b.wn, myFade = Number(fade[s.me] || 0), dj = b.ug?.wm?.k === 'dongji' ? b.ug.wm : null;
  if (dj) for (const x of dj.mine || []) {
    const m = -Math.PI / 2 + (Number(x.c) - 1) * 2 * Math.PI / 7, lx = 180 + 176 * Math.cos(m), ly = 180 + 176 * Math.sin(m);
    lampDots += `<g class="wm-n ${x.n <= dj.lit ? 'done' : ''}"><circle cx="${lx.toFixed(0)}" cy="${ly.toFixed(0)}" r="12"/><text x="${lx.toFixed(0)}" y="${(ly + 5).toFixed(0)}">${x.n}</text></g>`;
  }
  return `<div class="by-wrap"><svg class="by-map" viewBox="-14 -14 388 388" role="img" aria-label="맹약 마당">${cells}${lampDots}<circle class="by-core" cx="180" cy="180" r="40"/><text class="by-core-t" x="180" y="185">백야</text>${marks}${tokens}</svg>
    <p class="mk-hint muted small">${dj ? `<b class="wm-name">「${esc(dj.name || '')}」</b> · 등 ${dj.lit}/7 · ${dj.left}라운드 남음 · ` : ''}${wn ? `<b>흰 밤</b> · 등 ${wn.lit}/${wn.need}${wn.left != null ? ` · ${wn.left > 0 ? `${wn.left}라운드 남음` : '이번 라운드 끝'}` : ''}` : `켜진 등 ${lamps.size}/7 · 주는 피해 ×${Number(b.dmg_mul || 1).toFixed(2)} · 받는 피해 ×${Number(b.hurt_mul || 1).toFixed(2)}`}${myFade ? ` · <b class="warn">내 바램 ${myFade}/${b.fade_stun || 3}</b>` : ''}${b.stunned ? ' · <b class="bad">이번 라운드 꼼짝 못 함</b>' : ''}</p>
    ${live ? `<p class="mk-hint muted small">${moveTo ? `${moveTo}번 칸으로 옮겨 섭니다 · 내 칸을 누르면 취소` : '점선 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)'}</p>` : ''}</div>`;
}
function bySweepCell(s) {
  const b = s.board || {}, at = moveTo || b.my_pos; if (!at) return null;
  const near = new Set([at, ...byNb(at)]);
  const cand = (b.hz || []).filter(h => (h.k === 'arrow' || h.k === 'big') && near.has(Number(h.c))).sort((x, y) => (x.frozen ? 99 : x.left) - (y.frozen ? 99 : y.left));
  return cand.length ? Number(cand[0].c) : null;
}
function byGim(s, me, a) {
  if (s.boss !== 'baekya' || me.out) return '';
  const b = s.board || {}, at = moveTo || b.my_pos, canLight = at && at <= 7, sw = bySweepCell(s);
  const gust = (b.hz || []).find(h => h.k === 'gust' && Number(h.s) === at), lit = (b.lamps || []).includes(at);
  return `<div class="gw-gim by-gim"><span class="gw-gim-h" title="맹약 마당에서 늘 쓰는 행동">${icon('bell', 13)}<b>마당</b></span>
    <button class="btn ${a?.a === 'light' ? 'on' : ''}" data-gw="light" ${canLight ? '' : 'disabled'} title="${!canLight ? '등 기둥 칸(바깥 고리)에 서야 합니다' : !lit ? `${at}번 칸의 꺼진 등을 다시 켭니다` : gust ? `흔들리는 ${at}번 등을 감쌉니다${story() ? ' — 흔들림이 다하는 라운드(!)에 눌러야 지켜집니다' : ''}` : `${at}번 등은 켜져 있습니다`}">${icon('spark', 16)}<span>등 켜기${canLight ? ` · ${at}번 칸` : ''}</span></button>
    <button class="btn ${a?.a === 'sweep' ? 'on' : ''}" data-gw="sweep" data-c="${sw || ''}" ${sw ? '' : 'disabled'} title="${sw ? `${sw}번 칸 화살을 걷어 냅니다${story() ? ' — 떨어지는 라운드(!)에만 잡히고, 그 전에 누르면 헛손질입니다' : ''}` : '내 칸이나 바로 옆 칸에 멈춘 화살이 있어야 합니다'}">${icon('close', 16)}<span>걷어 내기${sw ? ` · ${sw}번 칸` : ''}</span></button>
  </div>`;
}
function storyGim(s, me, a) {
  if (!story() || s.boss !== 'gwiheo' || me.out) return '';
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

let votedFor = null;
function askVote(f) {
  const v = snap?.vote;
  if (!v || v.mine || votedFor === v.until || !snap.joined) return;
  votedFor = v.until;
  askForfeitVote(`${bossOf().name} 싸움`, v).then(agree => run({ disabled: false, dataset: {}, id: '' }, () => rpc('world_gw_forfeit_vote', { p_fight: f.id, p_agree: !!agree })));
}

async function run(btn, fn) {
  if (sending) { queued = () => run(btn, fn); return; }
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.fight?.status, round0 = snap?.fight?.round;
    const out = await fn();
    if (out) { snap = out; clock.sync(out); roundSeen(); memToast(); }
    if (snap?.fight?.round !== round0) moveTo = null;
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (ended() && prev !== snap.fight.status) await settle();
    else if (btn.dataset.gwSkill || btn.dataset.use || btn.id === 'gw-open' || btn.id?.startsWith('gw-join')) await reloadCharacter();
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; if (queued) { const q = queued; queued = null; q(); } }
}
