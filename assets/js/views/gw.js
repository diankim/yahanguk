// 외전 최종 보스 「귀허의 주인」: 라운드 전투(보통 5초 · 수법 10초). 판정은 모두 서버(world_gw_*)가 하고,
// 화면은 실시간 구독 없이 world_gw_snapshot을 읽는다. 다시 읽는 때: 라운드 마감 직후 한 번 · 내가 고른 뒤 다른 사람을 기다리는 동안 2초마다 · 모이는 중 3초마다.
// 서버가 라운드를 읽는 순간에 풀어내므로(마감이 지났거나 모두 골랐을 때) 따로 도는 예약 작업이 없다.
import { rpc, store, emit, esc, icon, fmt, $, $$, toast, nameOf, JOBS, loadCharacter } from '../core.js';
import { loading, errorBox, chip } from './common.js';

const ITEMS = ['tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve'];
const PHASE = { 1: '두 얼굴', 2: '사슬 넷', 3: '이름 빼앗기', 4: '귀허의 소용돌이' };
const MECH = { face: null, chain: '흰 사슬이 조여 온다', name: '이름이 물에 녹는다', vortex: '귀허의 소용돌이', normal: null };
const COLOR = { 청: 'c-blue', 적: 'c-red', 황: 'c-yellow', 백: 'c-white' };

let el = null, fid = null, snap = null, timer = null, tick = null, skew = 0, sending = false, target = null, picked = null;

export async function render(root, sub) {
  el = root; fid = sub || null; snap = null; target = null;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 외전 · 요인록</p><h1>귀허의 주인</h1></div></div>${loading()}`;
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); el = null; }

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
  const bar = $('.gw-round-bar span', el);
  if (bar && f.round_ends_at) {
    const len = f.mech?.k && MECH[f.mech.k] ? 10000 : 5000;
    bar.style.width = `${Math.max(0, Math.min(100, (new Date(f.round_ends_at) - now()) / len * 100))}%`;
  }
}

function draw() {
  if (!el) return;
  const s = snap || {};
  if (s.none) return drawLobby(s);
  const f = s.fight, me = (s.members || []).find(m => m.id === s.me) || {};
  const pct = f.max_hp ? Math.max(0, Math.min(100, f.hp / f.max_hp * 100)) : 100;
  const oldLog = $('.raid-log', el), atBottom = !oldLog || oldLog.scrollHeight - oldLog.scrollTop - oldLog.clientHeight < 24, oldTop = oldLog?.scrollTop || 0;
  const mech = f.mech || {}, warn = MECH[mech.k];
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 외전 · 요인록 · 귀허</p>
      <h1>귀허의 주인 <small>${f.status === 'wait' ? '모이는 중' : f.status === 'fight' ? `${f.phase}단계 · ${esc(PHASE[f.phase] || '')}` : f.status === 'won' ? '쓰러뜨림' : '물러남'}</small></h1></div>
      <div class="head-actions">${f.enrage ? chip(`분노 ${f.enrage}`, 'bad') : ''}</div></div>
    <div class="raid-grid">
      <section class="panel raid-boss"><div class="panel-body">
        ${f.status === 'wait' ? `<p class="raid-time">${icon('hourglass', 14)} <span data-until="${esc(f.start_at)}">…</span> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지)</p>
            ${f.leader === s.me ? `<button class="btn primary" id="gw-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : !s.joined ? `<button class="btn primary" id="gw-join">${icon('flag', 16)}<span>합류하기 · 귀허 부적 1개</span></button>` : `<p class="hint good">${icon('check', 14)} 합류했습니다. 곧 시작합니다.</p>`}`
          : f.status === 'fight' ? `<p class="raid-time">${icon('hourglass', 14)} ${f.round}라운드 · 마감 <b data-until="${esc(f.round_ends_at)}" data-sec="1">…</b> · 전체 남은 시간 <span data-until="${esc(f.ends_at)}">…</span></p>
            <div class="bar gw-round-bar"><span></span></div>` : ''}
        ${f.status === 'wait' ? '' : `<div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(f.hp)} / ${fmt.num(f.max_hp)}</b></div>`}
        ${f.status === 'fight' && mech.k === 'face' ? `<p class="hint">${icon('mask', 14)} ${mech.face === 'human' ? '사람의 얼굴' : '요괴의 얼굴'}을 들고 있다</p>` : ''}
        ${f.status === 'fight' && warn ? `<p class="hint warn">${icon('flame', 14)} <b>${esc(warn)}</b>${mech.k === 'vortex' ? ` · ${esc((s.members || []).find(m => m.id === mech.tank)?.name || '')}이(가) 버텨야 한다 · 몰아칠 힘 ${fmt.num(mech.need)}` : ''}${mech.k === 'name' ? ` · ${esc((s.members || []).find(m => m.id === mech.target)?.name || '')}` : ''}</p>` : ''}
        ${ended() ? resultHtml(f, s) : ''}
      </div></section>
      ${f.status === 'fight' && s.joined ? actHtml(s, me) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${(s.members || []).length}명</h2></header><div class="panel-body">
        <ul class="raid-mem">${(s.members || []).map(m => `<li class="${m.id === s.me ? 'me' : ''} ${m.id === target ? 'tgt' : ''} ${m.out ? 'out' : ''}">
          <button type="button" class="mem-pick" data-pick="${esc(m.id)}" ${f.status === 'fight' && s.joined ? '' : 'disabled'}><b>${esc(m.name)}</b><small>Lv${m.level} · ${esc(JOBS[m.job]?.name || nameOf(m.job))}${m.out ? ` · 물러남 ${m.out}라운드` : m.acted ? ' · 골랐음' : ''}${m.nameless ? ' · 이름 잃음' : ''}</small></button>
          <div class="bar ${m.hp < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, m.hp))}%"></span></div>
          <small class="mem-num">체력 ${m.hp} · 준 피해 ${fmt.num(m.dmg)}${m.heal ? ` · 회복 ${fmt.num(m.heal)}` : ''}</small></li>`).join('')}</ul></div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2></header><div class="panel-body">
        <ol class="raid-log">${(s.log || []).map(l => `<li class="k-${esc(l.kind)}"><time>${l.round}</time><span>${esc(l.text)}</span></li>`).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
      ${tipsHtml(s.tips)}
    </div>`;
  const log = $('.raid-log', el); if (log) log.scrollTop = atBottom ? log.scrollHeight : oldTop;
  bind(); countdown();
}

function actHtml(s, me) {
  const f = s.fight, mech = f.mech || {}, a = s.my_act;
  if (me.out) return `<section class="panel raid-act"><div class="panel-body"><p class="hint warn">${icon('hourglass', 14)} 물러나 있습니다 · ${me.out}라운드 뒤 체력 30으로 돌아옵니다.</p></div></section>`;
  const items = ITEMS.filter(k => Number(s.items?.[k]) > 0);
  const tName = (s.members || []).find(m => m.id === (target || s.me))?.name || '나';
  const on = k => a?.a === k ? 'on' : '';
  return `<section class="panel raid-act"><header class="panel-head"><h2>${icon('sword', 16)} 이번 라운드</h2><small class="muted">${a ? '골랐습니다 · 마감 전에는 바꿀 수 있습니다' : '고르지 않으면 방어합니다'}</small></header><div class="panel-body">
    <div class="raid-buttons">
      <button class="btn primary ${on('attack')}" data-gw="attack">${icon('sword', 16)}<span>공격</span></button>
      <button class="btn ${on('guard')}" data-gw="guard">${icon('shield', 16)}<span>방어</span></button>
      ${items.length ? `<select id="gw-item" aria-label="쓸 물품">${items.map(k => `<option value="${esc(k)}" ${k === picked ? 'selected' : ''}>${esc(nameOf(k))} ×${s.items[k]}</option>`).join('')}</select><button class="btn ${on('item')}" data-gw="item">${icon('heart', 16)}<span>${esc(tName)}에게 쓰기</span></button>` : ''}
      ${mech.k === 'name' ? `<button class="btn ${on('purify')}" data-gw="purify" ${Number(s.items?.ward_talisman) > 0 ? '' : 'disabled'}>${icon('spark', 16)}<span>${esc(tName)}에게 정화 부적 (${s.items?.ward_talisman || 0})</span></button>` : ''}
    </div>
    ${mech.k === 'chain' ? `<p class="small">손목의 사슬 · <b class="${COLOR[mech.mine] || ''}">${esc(mech.mine || '없음')}</b></p>
      <div class="raid-buttons">${(mech.colors || []).filter((v, i, x) => x.indexOf(v) === i).map(c => `<button class="btn ${COLOR[c] || ''} ${a?.a === 'chain' && a?.c === c ? 'on' : ''}" data-gw="chain" data-c="${esc(c)}">${esc(c)} 사슬 끊기</button>`).join('')}</div>` : ''}
    <p class="muted small">대상은 이름을 눌러 고릅니다(물품·정화 부적).</p>
  </div></section>`;
}

function resultHtml(f, s) {
  const mine = (s.members || []).find(m => m.id === s.me);
  return `<div class="raid-result ${f.status === 'won' ? 'ok' : 'bad'}"><b>${f.status === 'won' ? '귀허의 주인을 쓰러뜨렸습니다' : '소용돌이에 밀려났습니다'}</b>
    <p class="small">${mine ? `준 피해 ${fmt.num(mine.dmg)} · 물러난 횟수 ${mine.falls}` : ''}${f.status === 'won' ? ' · 보상은 알림으로 보냈습니다(처치는 하루 한 번 인정).' : ' · 장착 장비가 10% 닳고 침식이 10 올랐습니다. 30분 뒤 다시 도전할 수 있습니다.'}</p>
    <a class="btn small" href="#/gw">처음으로</a></div>`;
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
    </div></section>${tipsHtml(s.tips)}`;
  const o = $('#gw-open', el); if (o) o.onclick = () => run(o, () => rpc('world_gw_open'));
  const j = $('#gw-join-inv', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: s.invite }));
}

function bind() {
  const f = snap?.fight; if (!f) return;
  const sel = $('#gw-item', el); if (sel) sel.onchange = () => { picked = sel.value; };
  const b = $('#gw-begin', el); if (b) b.onclick = () => run(b, () => rpc('world_gw_begin', { p_fight: f.id }));
  const j = $('#gw-join', el); if (j) j.onclick = () => run(j, () => rpc('world_gw_join', { p_fight: f.id }));
  $$('[data-pick]', el).forEach(x => x.onclick = () => { target = x.dataset.pick; draw(); });
  $$('[data-gw]', el).forEach(x => x.onclick = () => {
    const a = x.dataset.gw, args = { p_fight: f.id, p_action: a, p_target: null, p_item: null };
    if (a === 'item') { args.p_item = $('#gw-item', el)?.value; args.p_target = target || snap.me; }
    if (a === 'purify') args.p_target = target || snap.me;
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
    else if (btn.dataset.gw === 'item' || btn.id === 'gw-open' || btn.id?.startsWith('gw-join')) { try { await loadCharacter(); } catch {} }
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
