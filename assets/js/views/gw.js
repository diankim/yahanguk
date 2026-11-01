// 외전 최종 보스 「귀허의 주인」: 라운드 전투(보통 5초 · 수법 10초). 판정은 모두 서버(world_gw_*)가 하고,
// 화면은 실시간 구독 없이 world_gw_snapshot을 읽는다. 다시 읽는 때: 라운드 마감 직후 한 번 · 내가 고른 뒤 다른 사람을 기다리는 동안 2초마다 · 모이는 중 3초마다.
// 서버가 라운드를 읽는 순간에 풀어내므로(마감이 지났거나 모두 골랐을 때) 따로 도는 예약 작업이 없다.
// 7.7.4: 행동은 공격·방어·버티기와 협동 기술(늘 펼쳐 둠), 기믹 전용(이름 부르기·사슬 끊기). 물품은 쓰지 않는다.
//        라운드 띠(단계 사다리·이번 라운드의 낌새 문구), 끝난 싸움은 라운드별 기록 전체를 펼쳐 되짚어 본다.
import { rpc, store, emit, esc, icon, fmt, $, $$, toast, nameOf, JOBS, loadCharacter, spOf } from '../core.js';
import { loading, errorBox, chip } from './common.js';

const PHASE = { 1: '두 얼굴', 2: '사슬 넷', 3: '이름 빼앗기', 4: '귀허의 소용돌이' };
const PHASE_AT = { 1: '체력 75%까지', 2: '50%까지', 3: '25%까지', 4: '끝까지' };
const COLOR = { 청: 'c-blue', 적: 'c-red', 황: 'c-yellow', 백: 'c-white' };
// 이로운 기운(서버 world_gw_members.fx 키)·주인에게 걸린 것(bfx 키)
const FX = { ward: '호신', might: '북돋움', crit: '약점 표시', critnext: '급소', evade: '피할 길', shield: '보호막', gward: '진언', taunt: '신장', cover: '대신 막기' };
const BFX = { expose: '봉인 사슬에 묶임', block: '손길 묶임', smoke: '연막' };
const KIND = { tell: 'k-tell', warn: 'k-warn', phase: 'k-phase', skill: 'k-skill', atk: 'k-out', hit: 'k-in', fall: 'k-fall', good: 'k-good', bad: 'k-bad', miss: 'k-miss', guard: 'k-guard', boss: 'k-boss' };

let el = null, fid = null, snap = null, timer = null, tick = null, skew = 0, sending = false, target = null;

export async function render(root, sub) {
  el = root; fid = sub || null; snap = null; target = null;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 외전 · 요인록</p><h1>귀허의 주인</h1></div></div>${loading()}`;
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); el = null; }
// 귀허의 주인과 싸우는 동안에는 물품을 쓰지 않는다(7.7.4) — 퀵슬롯·가방에서 눌러도 알리기만
window.addEventListener('yh-battle-item', e => {
  const f = snap?.fight;
  if (!el?.isConnected || f?.status !== 'fight' || !snap?.joined) return;
  e.detail.handled = true;
  toast('귀허의 주인과 싸우는 동안에는 물품을 쓸 수 없습니다. 기술과 버티기로 대처하세요.', 'warn');
});

async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.fight?.status;
    snap = await rpc('world_gw_snapshot', { p_fight: fid });
    if (snap?.now) skew = new Date(snap.now).getTime() - Date.now();
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (prev && prev !== snap?.fight?.status && ended()) await settle();
    draw();
    plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
}
const now = () => Date.now() + skew;
const ended = () => ['won', 'failed'].includes(snap?.fight?.status);
async function settle() { try { await loadCharacter(); } catch {} emit('changed', { name: 'world_gw_settle' }); }

// 다음에 읽을 때를 정한다(화면이 열려 있을 때만)
function plan() {
  const f = snap?.fight; if (!f || ended() || document.hidden) return;
  let wait;
  if (f.status === 'wait') wait = Math.min(3000, Math.max(400, new Date(f.start_at) - now() + 300));
  else {
    const toEnd = new Date(f.round_ends_at) - now() + 350;
    wait = snap.my_act ? Math.min(2000, Math.max(400, toEnd)) : Math.max(400, toEnd);
  }
  timer = setTimeout(refresh, wait);
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

function countdown() {
  if (!el || !snap?.fight) return;
  const f = snap.fight;
  $$('[data-until]', el).forEach(x => {
    const ms = new Date(x.dataset.until) - now();
    x.textContent = ms > 0 ? (x.dataset.sec ? `${Math.ceil(ms / 1000)}초` : fmt.remain(ms)) : '곧';
  });
  const b = $('.gw-round-bar span', el);
  if (b && f.round_ends_at) {
    const len = ['chain', 'name', 'vortex'].includes(f.mech?.k) ? 10000 : 5000;
    b.style.width = `${Math.max(0, Math.min(100, (new Date(f.round_ends_at) - now()) / len * 100))}%`;
  }
}

const nameOfMember = (s, id) => (s.members || []).find(m => m.id === id)?.name || '';
// 단계 사다리: 지금 단계 강조, 지난 단계는 흐리게
// 7.7.4: 한 줄로 납작하게(「1 두 얼굴」), 언제까지인지는 title
const ladder = ph => `<ol class="gw-ladder">${[1, 2, 3, 4].map(p => `<li class="${p === ph ? 'now' : p < ph ? 'done' : ''}" title="${PHASE_AT[p]}"><b>${p}</b><span>${p === 4 ? '소용돌이' : PHASE[p]}</span></li>`).join('')}</ol>`;
// 낌새 문구가 길면 글자를 조금씩 줄여 띠가 너무 커지지 않게(7.7.4) — 아래 행동 칸이 밀려 내려가지 않도록
const tellSize = t => { const n = String(t || '').length; return n > 110 ? 'xxl' : n > 80 ? 'xl' : n > 55 ? 'l' : ''; };

// 이번 라운드 띠: 라운드·마감·내 행동·낌새 문구
function roundBand(s) {
  const f = s.fight, mech = f.mech || {}, gim = ['chain', 'name', 'vortex'].includes(mech.k);
  const chosen = (s.members || []).filter(m => !m.out && m.acted).length, alive = (s.members || []).filter(m => !m.out).length;
  const myAct = s.my_act ? actName(s, s.my_act) : null;
  return `<div class="gw-band ${gim ? 'gim' : ''} ${mech.aoe ? 'aoe' : ''}">
    <div class="gw-band-top"><span class="gw-round">${f.round}라운드</span>${gim ? chip('수법', 'bad') : mech.aoe ? chip('기를 모음', 'warn') : ''}
      <span class="gw-band-time">${icon('hourglass', 13)}<b data-until="${esc(f.round_ends_at)}" data-sec="1">…</b></span>
      <span class="gw-chosen muted small">고른 사람 ${chosen}/${alive}</span></div>
    <div class="bar gw-round-bar"><span></span></div>
    <p class="gw-tell ${tellSize(mech.tell)}">${esc(mech.tell || '주인이 숨을 고른다.')}</p>
    ${mech.k === 'chain' ? `<p class="small">내 손목의 사슬 · <b class="${COLOR[mech.mine] || ''}">${esc(mech.mine || '없음')}</b></p>` : ''}
    ${f.bfx?.length ? `<div class="chips">${f.bfx.filter(k => BFX[k]).map(k => chip(BFX[k], 'ok')).join('')}</div>` : ''}
    <p class="gw-mine">${myAct ? `${icon('check', 13)} 이번 라운드: <b>${esc(myAct)}</b> · 마감 전에는 바꿀 수 있습니다` : `${icon('bell', 13)} 아직 고르지 않았습니다 — 고르지 않으면 방어합니다`}</p>
  </div>`;
}
function actName(s, a) {
  const t = a.t ? nameOfMember(s, a.t) : '';
  if (a.a === 'coop') { const sk = (s.skills || []).find(x => x.id === a.s); return `기술 「${sk?.name || ''}」${t ? ` → ${t}` : ''}`; }
  return ({ attack: '공격', guard: '방어', brace: '버티기', call: `이름 부르기 → ${t}`, chain: `${a.c || ''} 사슬 끊기` })[a.a] || a.a;
}

function draw() {
  if (!el) return;
  const s = snap || {};
  if (s.none) return drawLobby(s);
  const f = s.fight, me = (s.members || []).find(m => m.id === s.me) || {};
  const pct = f.max_hp ? Math.max(0, Math.min(100, f.hp / f.max_hp * 100)) : 100;
  const done = ended(), fight = f.status === 'fight';
  const oldLog = $('.raid-log', el), atBottom = !oldLog || oldLog.scrollHeight - oldLog.scrollTop - oldLog.clientHeight < 24, oldTop = oldLog?.scrollTop || 0;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 외전 · 요인록 · 귀허</p>
      <h1>귀허의 주인 <small>${f.status === 'wait' ? '모이는 중' : fight ? `${f.phase}단계 · ${esc(PHASE[f.phase] || '')}` : f.status === 'won' ? '쓰러뜨림' : '물러남'}</small></h1></div>
      <div class="head-actions">${f.enrage ? chip(`분노 ${f.enrage}`, 'bad') : ''}${fight ? `<span class="muted small">전체 남은 시간 <span data-until="${esc(f.ends_at)}">…</span></span>` : ''}</div></div>
    ${done ? resultHtml(f, s) : ''}
    <div class="raid-wrap pf-wrap gw-wrap ${fight && s.joined ? 'playing' : ''} ${done ? 'ended' : ''}">
      <section class="panel raid-boss"><div class="panel-body">
        ${f.status === 'wait' ? `<p class="raid-time">${icon('hourglass', 14)} <span data-until="${esc(f.start_at)}">…</span> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지)</p>
            ${f.leader === s.me ? `<button class="btn primary" id="gw-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : !s.joined ? `<button class="btn primary" id="gw-join">${icon('flag', 16)}<span>합류하기 · 귀허 부적 1개</span></button>` : `<p class="hint good">${icon('check', 14)} 합류했습니다. 곧 시작합니다.</p>`}` : ''}
        ${f.status === 'wait' ? '' : `<div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(f.hp)} / ${fmt.num(f.max_hp)}</b></div>${ladder(f.phase)}`}
        ${fight ? roundBand(s) : ''}
      </div></section>
      ${fight && s.joined ? actHtml(s, me) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${(s.members || []).length}명</h2>${fight && s.joined ? '<small class="muted gw-pick-hint">이름을 누르면 기술·이름 부르기 대상</small>' : ''}</header><div class="panel-body">
        <ul class="raid-mem pf-mem">${(s.members || []).map(m => `<li class="${m.id === s.me ? 'me' : ''} ${m.id === (target || s.me) && fight ? 'pick' : ''} ${m.out ? 'out' : ''} ${m.nameless ? 'tgt' : ''}">
          <button type="button" class="mem-pick" data-pick="${esc(m.id)}" ${fight && s.joined ? '' : 'disabled'} title="${esc(`${m.name} · Lv${m.level} ${JOBS[m.job]?.name || nameOf(m.job)}`)}"><span class="mem-top"><b>${esc(m.name)}</b><small class="mem-job">${esc(JOBS[m.job]?.name || nameOf(m.job))}</small><small class="mem-hp">${m.hp}</small></span>
          <span class="bar ${m.hp < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, m.hp))}%"></span></span>
          <small class="mem-sub">${[m.out ? `물러남 ${m.out}라운드` : fight ? (m.acted ? '골랐음' : '고르는 중') : '', m.nameless ? '이름 잃음' : '', fight && f.mech?.k === 'vortex' && f.mech.tank === m.id ? '물살이 쏠림' : ''].filter(Boolean).join(' · ') || '&nbsp;'}</small>
          <small class="mem-sub">준 피해 ${fmt.num(m.dmg)}${m.heal ? ` · 회복 ${fmt.num(m.heal)}` : ''}${done && m.falls ? ` · 물러남 ${m.falls}번` : ''}</small>
          ${(m.fx || []).filter(k => FX[k]).length ? `<span class="gw-fx">${(m.fx || []).filter(k => FX[k]).map(k => `<i>${FX[k]}</i>`).join('')}</span>` : ''}</button></li>`).join('')}</ul>
</div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} ${done ? '전투 기록 · 라운드별로 되짚어 보기' : '전투 기록'}</h2></header><div class="panel-body">
        ${logHtml(s, me, done)}</div></section>
    </div>
    ${tipsHtml(s.tips)}`;
  const log = $('.raid-log', el); if (log && !done) log.scrollTop = atBottom ? log.scrollHeight : oldTop;
  bind(); countdown();
}

// 기록: 라운드마다 머리줄을 달고, 갈래(낌새·수법·기술·준 피해·받은 피해·물러남)마다 색을 다르게
function logHtml(s, me, done) {
  const rows = s.log || [];
  if (!rows.length) return '<ol class="raid-log"><li class="muted">아직 기록이 없습니다.</li></ol>';
  let last = null, out = '';
  for (const l of rows) {
    if (l.round !== last) { last = l.round; out += `<li class="gw-rhead">${l.round ? `${l.round}라운드` : '시작'}</li>`; }
    out += `<li class="${KIND[l.kind] || ''}${me.name && String(l.text).startsWith(me.name) ? ' mine' : ''}"><span>${esc(l.text)}</span></li>`;
  }
  return `<ol class="raid-log gw-log ${done ? 'full' : ''}">${out}</ol>`;
}

// 체력·정신·영력: 글자 높이의 게이지 안에 숫자(7.7.4)
const gauge = (label, v, kind) => `<div class="gw-vit"><span>${esc(label)}</span><div class="bar gw-gauge ${kind}"><span style="width:${Math.max(0, Math.min(100, Number(v) || 0))}%"></span><b>${fmt.num(v ?? 0)}</b></div></div>`;
function actHtml(s, me) {
  const f = s.fight, mech = f.mech || {}, a = s.my_act, c = store.character || {};
  if (me.out) return `<section class="panel raid-act"><div class="panel-body"><p class="hint warn">${icon('hourglass', 14)} 물러나 있습니다 · ${me.out}라운드 뒤 체력 30으로 돌아옵니다. 의무관의 「야전 소생」이면 바로 돌아옵니다.</p></div></section>`;
  const tid = target || s.me, tName = nameOfMember(s, tid) || '나';
  const on = k => a?.a === k ? 'on' : '';
  const hp = me.hp ?? c.health, sp = s.sp ?? c.spiritual_power;
  const skills = s.skills || [];
  const ready = skills.filter(k => k.unlocked && !k.wait && sp >= k.cost).length;
  return `<section class="panel raid-act ${a ? '' : 'my-turn'}"><header class="panel-head"><h2>${icon('sword', 16)} 이번 라운드의 행동</h2><small class="muted">대상: <b>${esc(tName)}</b></small></header><div class="panel-body">
    <div class="gw-vits">${gauge('체력', hp, 'hp')}${gauge('정신', c.mental, 'mp')}${gauge(spOf()[0], sp, spOf()[1])}</div>
    <div class="raid-buttons pf-btns gw-btns">
      <button class="btn primary ${on('attack')}" data-gw="attack">${icon('sword', 16)}<span>공격</span></button>
      <button class="btn ${on('guard')}" data-gw="guard">${icon('shield', 16)}<span>방어</span></button>
      <button class="btn ${on('brace')}" data-gw="brace" title="몸을 낮춰 막기만 합니다. 쏟아지는 물살·소용돌이에 방어보다 강합니다">${icon('down', 16)}<span>버티기</span></button>
    </div>
    ${skills.length ? `<p class="gw-skills-h">${icon('spark', 13)} 협동 기술 <small class="muted">쓸 수 있는 것 ${ready}</small></p>` : ''}
    <div class="gw-skills">${skills.map(k => {
        const why = !k.unlocked ? `전투 숙련 ${k.rank}단계` : k.wait ? `${k.wait}라운드 뒤` : sp < k.cost ? `영력 ${k.cost} 필요` : '';
        return `<button class="gw-skill ${a?.a === 'coop' && a?.s === k.id ? 'on' : ''}" data-gw-skill="${esc(k.id)}" ${why ? 'disabled' : ''} title="${esc(`${k.desc} (영력 ${k.cost} · ${k.rounds}라운드마다)`)}">
          <span class="gw-skill-top"><b>${esc(k.name)}</b><small>${why ? `<em>${esc(why)}</em>` : `${k.target === 'ally' ? `→ ${esc(tName)}` : k.target === 'all' ? '모두' : k.target === 'boss' ? '주인' : '나'} · 영력 ${k.cost}`}</small></span>
          <small class="gw-skill-desc">${esc(k.desc)}</small></button>`; }).join('') || '<p class="muted small">쓸 수 있는 협동 기술이 없습니다.</p>'}</div>
    ${mech.k === 'name' || mech.k === 'chain' ? `<div class="gw-gim"><p class="small"><b>${icon('bell', 13)} 이번 라운드만의 행동</b></p>
      ${mech.k === 'name' ? `<button class="btn ${on('call')}" data-gw="call">${icon('users', 16)}<span>${esc(tName)}의 이름 부르기</span></button>` : ''}
      ${mech.k === 'chain' ? `<div class="raid-buttons">${(mech.colors || []).filter((v, i, x) => x.indexOf(v) === i).map(col => `<button class="btn ${COLOR[col] || ''} ${a?.a === 'chain' && a?.c === col ? 'on' : ''}" data-gw="chain" data-c="${esc(col)}">${esc(col)} 사슬 끊기</button>`).join('')}</div>` : ''}
    </div>` : ''}
  </div></section>`;
}

function resultHtml(f, s) {
  const mine = (s.members || []).find(m => m.id === s.me);
  const won = f.status === 'won';
  return `<section class="panel raid-result-panel"><div class="panel-body"><div class="raid-result ${won ? 'ok' : 'bad'}"><b>${won ? '귀허의 주인을 쓰러뜨렸습니다' : '소용돌이에 밀려났습니다'}</b>
    <p class="small">${f.round}라운드 · ${PHASE[f.phase] || ''}${won ? '' : `까지 · 주인 체력 ${fmt.num(f.hp)} / ${fmt.num(f.max_hp)} 남음`}${mine ? ` · 준 피해 ${fmt.num(mine.dmg)} · 물러난 횟수 ${mine.falls}` : ''}</p>
    <p class="small">${won ? '보상은 알림으로 보냈습니다(처치는 하루 한 번 인정).' : '장착 장비가 10% 닳고 침식이 10 올랐습니다. 30분 뒤 다시 도전할 수 있습니다.'} 아래 전투 기록에서 라운드마다 무엇이 있었는지 되짚어 볼 수 있습니다.</p>
    <a class="btn small" href="#/gw">처음으로</a></div></div></section>`;
}

const tipsHtml = tips => (tips || []).length ? `<details class="panel fold"><summary class="panel-head"><h2>${icon('help', 16)} 파훼법 <small class="muted">쓰러뜨린 조사원만 봅니다</small></h2></summary>
  <div class="panel-body"><ul class="small">${tips.map(t => `<li>${esc(t)}</li>`).join('')}</ul></div></details>` : '';

function drawLobby(s) {
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 외전 · 요인록 · 귀허</p><h1>귀허의 주인</h1></div></div>
    <section class="panel"><div class="panel-body">
      <p class="desc">소용돌이 한가운데 빈 왕좌. 혼자 또는 같은 곳의 파티원 4명까지 함께 섭니다(4명을 권합니다). 모두 귀허 부적을 하나씩 씁니다.</p>
      <p class="small">귀허 부적 ${s.charms}개 · 처치 ${s.kills}번</p>
      ${s.invite ? `<button class="btn primary" id="gw-join-inv">${icon('flag', 16)}<span>파티원의 도전에 합류</span></button>` : ''}
      ${s.can_open ? `<button class="btn primary" id="gw-open">${icon('sword', 16)}<span>귀허의 주인 앞에 서기</span></button><p class="muted small">같은 곳에 파티원이 있으면 60초 동안 모입니다.</p>`
        : `<p class="hint">${icon('pin', 14)} ${esc(s.why || '지금은 도전할 수 없습니다.')}</p>`}
      ${s.last ? `<a class="btn small ghost" href="#/gw/${esc(s.last)}">${icon('scroll', 15)}<span>지난 도전 기록 보기</span></a>` : ''}
    </div></section>${tipsHtml(s.tips)}`;
  const o = $('#gw-open', el); if (o) o.onclick = () => run(o, () => rpc('world_gw_open'));
  const j = $('#gw-join-inv', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: s.invite }));
}

function bind() {
  const f = snap?.fight; if (!f) return;
  const b = $('#gw-begin', el); if (b) b.onclick = () => run(b, () => rpc('world_gw_begin', { p_fight: f.id }));
  const j = $('#gw-join', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: f.id }));
  $$('[data-pick]', el).forEach(x => x.onclick = () => { target = x.dataset.pick; draw(); });
  $$('[data-gw-skill]', el).forEach(x => x.onclick = () => {
    run(x, () => rpc('world_gw_act', { p_fight: f.id, p_action: 'coop', p_target: target || snap.me, p_item: x.dataset.gwSkill }));
  });
  $$('[data-gw]', el).forEach(x => x.onclick = () => {
    const a = x.dataset.gw, args = { p_fight: f.id, p_action: a, p_target: null, p_item: null };
    if (a === 'call') args.p_target = target || snap.me;
    if (a === 'chain') args.p_item = x.dataset.c;
    run(x, () => rpc('world_gw_act', args));
  });
}

async function run(btn, fn) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.fight?.status;
    const out = await fn();
    if (out) { snap = out; if (out.now) skew = new Date(out.now).getTime() - Date.now(); }
    if (snap?.fight?.id && fid !== snap.fight.id) { fid = snap.fight.id; history.replaceState(null, '', `#/gw/${fid}`); }
    if (ended() && prev !== snap.fight.status) await settle();
    else if (btn.dataset.gwSkill || btn.id === 'gw-open' || btn.id?.startsWith('gw-join')) { try { await loadCharacter(); } catch {} }
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
