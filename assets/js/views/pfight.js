// 파티 현장 토벌(7.1): 라운드 10초. 참가자마다 행동 하나를 고르면(안 고르면 방어) 서버(world_pfight_*)가 한 번에 푼다.
// 실시간 구독 없이 world_pfight_snapshot을 읽는다. 다시 읽는 때: 라운드 마감 직후 한 번 · 내가 고른 뒤 다른 사람을 기다리는 동안 2초마다 · 모이는 중 3초마다.
import { rpc, emit, esc, icon, fmt, $, $$, toast, nameOf, loadCharacter, store, bar, spOf } from '../core.js';
import { loading, errorBox, chip } from './common.js';
import { INTENT, SKILL, JOB, ITEMS } from './battle.js';

const ACT = { attack: '공격', skill: '기술', guard: '방어', item: '물품', flee: '달아나기' };
const OUT = { won: '이김', down: '쓰러짐', fled: '달아남', gone: '빠짐', done: '끝' };

let el = null, fid = null, snap = null, timer = null, tick = null, skew = 0, sending = false, tray = false;

export async function render(root, sub) {
  el = root; fid = sub || null; snap = null; tray = false;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${loading()}`;
  if (!fid) { try { fid = await rpc('world_pfight_mine'); } catch {} }
  if (!fid) { el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌</p><h1>함께 싸우기</h1></div></div>${errorBox('지금 든 파티 토벌이 없습니다.')}<a class="btn" href="#/home">현장으로</a>`; return; }
  clearInterval(tick); tick = setInterval(countdown, 250);
  await refresh();
}
export function destroy() { clearTimeout(timer); clearInterval(tick); el = null; }

const now = () => Date.now() + skew;
const ended = () => ['won', 'lost', 'fled', 'cancelled'].includes(snap?.status);
async function refresh() {
  if (!el) return;
  clearTimeout(timer);
  try {
    const prev = snap?.status, prevRound = snap?.round;
    snap = await rpc('world_pfight_snapshot', { p_fight: fid });
    if (snap?.now) skew = new Date(snap.now).getTime() - Date.now();
    if ((prev && prev !== snap.status && ended()) || (prevRound && prevRound !== snap.round)) await settle();
    draw(); plan();
  } catch (e) { if (el) el.innerHTML = errorBox(e.message); }
}
async function settle() { try { await loadCharacter(); } catch {} emit('changed', { name: 'world_pfight_act' }); }

function plan() {
  if (!snap || ended() || document.hidden || !el) return;
  let wait;
  if (snap.status === 'gather') wait = Math.min(3000, Math.max(400, new Date(snap.gather_ends) - now() + 300));
  else { const toEnd = new Date(snap.round_ends) - now() + 350; wait = snap.me?.action ? Math.min(2000, Math.max(400, toEnd)) : Math.max(400, toEnd); }
  timer = setTimeout(refresh, wait);
}
document.addEventListener('visibilitychange', () => { if (el && !document.hidden) refresh(); });

function countdown() {
  if (!el || !snap) return;
  $$('[data-until]', el).forEach(x => { const ms = new Date(x.dataset.until) - now(); x.textContent = ms > 0 ? `${Math.ceil(ms / 1000)}초` : '곧'; });
  const b = $('.gw-round-bar span', el);
  if (b && snap.round_ends) b.style.width = `${Math.max(0, Math.min(100, (new Date(snap.round_ends) - now()) / 10000 * 100))}%`;
}

function draw() {
  if (!el || !snap) return;
  const s = snap, b = s.battle || {}, me = s.me, c = store.character || {};
  const pct = s.max_hp ? Math.max(0, Math.min(100, s.hp / s.max_hp * 100)) : 100;
  const intent = b.gimmick ? [b.gimmick.name, b.gimmick.burst ? '모은 기운이 터지려 한다.' : b.gimmick.tell, b.gimmick.burst ? 3 : 2] : (INTENT[s.intent] || INTENT.strike);
  const tgt = (s.members || []).find(m => m.id === s.target_id);
  const oldLog = $('.raid-log', el), atBottom = !oldLog || oldLog.scrollHeight - oldLog.scrollTop - oldLog.clientHeight < 24, oldTop = oldLog?.scrollTop || 0;
  const head = s.status === 'gather' ? '동료를 기다리는 중' : s.status === 'fight' ? `${s.round}라운드` : s.status === 'won' ? '쓰러뜨림' : s.status === 'cancelled' ? '혼자 싸우기로' : '싸움이 끝남';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('users', 14)} 파티 토벌 · Lv.${s.level}</p><h1>${esc(s.monster || '요괴')} <small>${esc(head)}</small></h1></div>
      <div class="head-actions">${s.rank && s.rank !== 'normal' ? chip(s.rank === 'guardian' ? '우두머리' : '정예', s.rank === 'guardian' ? 'bad' : 'warn') : ''}</div></div>
    <div class="raid-grid">
      <section class="panel raid-boss"><div class="panel-body">
        ${s.status === 'gather' ? `<p class="raid-time">${icon('hourglass', 14)} <b data-until="${esc(s.gather_ends)}">…</b> 뒤 시작 · 같은 곳의 파티원이 합류할 수 있습니다(4명까지 · 탐색력 1)</p>
            ${s.leader_id === c.owner_id ? `<button class="btn primary" id="pf-begin">${icon('sword', 16)}<span>지금 시작하기</span></button>` : ''}` : ''}
        ${s.can_join ? `<button class="btn primary" id="pf-join">${icon('flag', 16)}<span>합류하기 · 탐색력 1</span></button>` : ''}
        ${s.status === 'fight' ? `<p class="raid-time">${icon('hourglass', 14)} 마감 <b data-until="${esc(s.round_ends)}">…</b> · 고르지 않으면 방어합니다</p><div class="bar gw-round-bar"><span></span></div>` : ''}
        <div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(s.hp)} / ${fmt.num(s.max_hp)}</b></div>
        ${s.status === 'fight' ? `<div class="intent lvl-${intent[2]}">${icon(intent[2] >= 2 ? 'flame' : 'eye', 18)}<div><b>다음 행동 · ${esc(intent[0])}</b><span>${esc(intent[1])}${tgt ? ` · 지난 라운드 표적: ${esc(tgt.name)}` : ''}</span></div></div>` : ''}
        ${ended() ? resultHtml(s) : ''}
      </div></section>
      ${s.status === 'fight' && me && !me.out ? actHtml(s, b, c) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 함께 선 이 ${(s.members || []).length}명</h2></header><div class="panel-body">
        <ul class="raid-mem">${(s.members || []).map(m => `<li class="${m.id === c.owner_id ? 'me' : ''} ${m.id === s.target_id ? 'tgt' : ''} ${m.out ? 'out' : ''}">
          <div class="mem-pick"><b>${esc(m.name)}</b><small>${esc(JOB[m.job] || nameOf(m.job))}${m.out ? ` · ${OUT[m.out] || m.out}` : s.status === 'fight' ? (m.chosen ? ' · 골랐음' : ' · 고르는 중') : ''}</small></div>
          <div class="bar ${m.health < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, m.health))}%"></span></div>
          <small class="mem-num">체력 ${m.health} · 정신 ${m.mental} · 영력·기력 ${m.sp}</small></li>`).join('')}</ul>
        <p class="muted small">요괴는 이목이 높은 이를 더 자주 노립니다. 합류한 사람마다 요괴 체력이 늘고, 이기면 각자 전리품을 굴리고 경험치를 한 사람마다 10% 더 받습니다(세 명까지).</p></div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2></header><div class="panel-body">
        <ol class="raid-log">${(s.log || []).map(l => `<li class="no-time${/^—/.test(l) ? ' k-round' : ''}"><span>${esc(l)}</span></li>`).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
    </div>`;
  const log = $('.raid-log', el); if (log) log.scrollTop = atBottom ? log.scrollHeight : oldTop;
  bind(); countdown();
}

function actHtml(s, b, c) {
  const a = s.me?.action, on = k => a === k ? 'on' : '';
  const skill = SKILL[c.job_key] || ['기술', ''];
  const ready = Number(b.pfx?.skill_ready || 0), wait = Math.max(0, ready - (Number(b.turn || 0) + 1));
  const medUsed = c.job_key === 'medic' && !!b.pfx?.med_used;
  const inv = c.inventory || {};
  return `<section class="panel raid-act"><header class="panel-head"><h2>${icon('sword', 16)} 이번 라운드</h2><small class="muted">${a ? `${ACT[a] || a}을(를) 골랐습니다 · 마감 전에는 바꿀 수 있습니다` : '고르지 않으면 방어합니다'}</small></header><div class="panel-body">
    <div class="me-bars"><div class="vital"><span>체력</span><b>${c.health}</b>${bar(c.health, 100, 'hp')}</div><div class="vital"><span>정신</span><b>${c.mental}</b>${bar(c.mental, 100, 'mp')}</div>
      <div class="vital"><span>${spOf()[0]}</span><b>${c.spiritual_power}</b>${bar(c.spiritual_power, 100, spOf()[1])}</div></div>
    <div class="raid-buttons">
      <button class="btn primary ${on('attack')}" data-pf="attack">${icon('sword', 16)}<span>공격</span></button>
      <button class="btn ${on('skill')}" data-pf="skill" ${medUsed || wait ? 'disabled' : ''}>${icon('spark', 16)}<span>${esc(skill[0])}${medUsed ? ' (씀)' : wait ? ` (${wait}라운드 뒤)` : ''}</span></button>
      <button class="btn ${on('guard')}" data-pf="guard">${icon('shield', 16)}<span>방어</span></button>
      <button class="btn ${on('item')}" data-pf-tray>${icon('plus', 16)}<span>물품${a === 'item' && s.me?.item ? ` · ${esc(nameOf(s.me.item))}` : ''}</span></button>
      <button class="btn ghost ${on('flee')}" data-pf="flee">${icon('back', 16)}<span>달아나기</span></button>
    </div>
    <div class="item-tray" ${tray ? '' : 'hidden'}>${ITEMS.filter(([k]) => inv[k] > 0).map(([k, d]) => `<button class="btn small" data-pf-item="${k}">${esc(nameOf(k))} ×${fmt.num(inv[k])}<small>${d}</small></button>`).join('') || '<p class="muted small">전투에 쓸 물품이 없습니다.</p>'}</div>
    <p class="muted small">${esc(skill[0])}: ${esc(skill[1])} 달아나면 이 싸움에서 빠집니다.</p>
  </div></section>`;
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
  const t = $('[data-pf-tray]', el); if (t) t.onclick = () => { tray = !tray; draw(); };
  $$('[data-pf-item]', el).forEach(x => x.onclick = () => { tray = false; run(x, () => rpc('world_pfight_act', { p_fight: fid, p_action: 'item', p_item: x.dataset.pfItem })); });
}

async function run(btn, fn) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const prev = snap?.status, prevRound = snap?.round;
    const out = await fn();
    if (out) { snap = out; if (out.now) skew = new Date(out.now).getTime() - Date.now(); }
    if ((ended() && prev !== snap.status) || prevRound !== snap.round || btn.id === 'pf-join') await settle();
    draw(); plan();
  } catch (e) { toast(e.message || String(e), 'error'); btn.disabled = false; }
  finally { sending = false; }
}
