import { rpc, act, store, emit, esc, icon, fmt, $, $$, toast, ask, nameOf, RAID_ON, spOf, particle, xpGot } from '../core.js';
import { feastBandRow, bindFeastBand } from '../feast.js';
import { load, invalidate, loading, errorBox, chip } from './common.js';
import { bgroup, bclear } from '../rtb.js';
import { mountMeter } from './meter.js';
import { fxChips, fxKeys, FX_NAME, bindTips, hideTip, memberLi, showSelected, fightNums, vitHtml, coopBtn, itemSectionsHtml, battleItems, itemTray,
  resultBox, reloadCharacter, ammoHtml, ammoWarn, settleFight, untilText, tickUntil, mobileLog, newestFirst, atLogEdge, logRow, fitLog, jobName, showResult, soloAidHtml } from './fightui.js';
import { catItem } from './common.js';
import { clearFightNotes } from '../settings.js';
import { baseOf } from '../hq.js';
const CREDIT = [['dmg', '피해'], ['guard', '막아 줌'], ['hit1', '받아 냄'], ['heal', '회복'], ['boost', '북돋움']];
const creditLine = c => {
  const v = c || {};
  const parts = CREDIT.filter(([k]) => Number(v[k]) > 0).map(([k, n]) => `${n} ${fmt.num(Math.round(v[k]))}`);
  return parts.length ? `<small class="muted raid-credit">(${parts.join(' · ')})</small>` : '';
};

const BOSS_FX = ['expose', 'stagger', 'smoke', 'break'];
const STATUS = { announced: '예고', signup: '참가 신청 중', fight: '토벌 중', won: '토벌 성공', failed: '토벌 실패' };

let el = null, rid = null, snap = null, tick = null, timer = null, lastFetch = 0, target = null, sending = false, readyAt = 0, outUntil = 0, outEnds = {}, shownStatus = '', built = '', logCount = 0, away = false, resting = false, sel = null, chargeEnd = 0, chargeDur = 8000, chargeT = null;

export async function render(root, sub) {
  el = root; rid = sub || null; snap = null; target = null; sel = null; built = ''; logCount = 0; shownStatus = '';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 합동 토벌</p><h1>봉연</h1></div></div>${loading()}`;
  await refresh();
  bindTips(el);
  subscribe();
  clearInterval(tick); tick = setInterval(countdown, 1000);
}
export function destroy() { hideTip(); clearTimeout(chargeT); bclear('raid'); clearInterval(tick); clearTimeout(timer); el = null; tray.close(); }

async function refresh() {
  if (!el) return;
  lastFetch = Date.now();
  try {
    const prev = snap?.raid?.status;
    snap = await rpc('world_raid_snapshot', { p_raid: rid });
    if (snap?.raid?.id && rid !== snap.raid.id) { rid = snap.raid.id; subscribe(); }
    if (prev === 'fight' && settled(snap) && snap.me?.joined) settle();
    draw();
  } catch (e) { el.innerHTML = errorBox(e.message); }
}
const settled = s => s?.raid?.status === 'won' || s?.raid?.status === 'failed';
const settle = () => settleFight('world_raid_settle', () => invalidate('world_raid_brief'));
function onChange(p) {
  const n = p?.new, r = snap?.raid;
  if (n && r && Date.now() - lastFetch < 1200 && n.hp === r.hp && n.phase === r.phase && n.status === r.status && (n.intent ?? null) === (r.intent ?? null)) return;
  soon();
}
function soon() {
  clearTimeout(timer);
  const gap = snap?.me?.joined && snap?.raid?.status === 'fight' ? 1000 : 2000;
  timer = setTimeout(refresh, Math.max(250, lastFetch + gap - Date.now()));
}
function subscribe() {
  let ever = false, was = false;
  bgroup('raid', [rid ? `raid:${rid}` : 'raid:any'], 'change', onChange, l => { if (l && !was && ever && el) soon(); if (l) ever = true; was = l; });
}

const left = t => untilText(t);
function countdown() {
  if (!el) return;
  tickUntil(el);
  const cd = Math.max(0, readyAt - Date.now());
  const out = outUntil > Date.now() || away;
  $$('[data-act]', el).forEach(b => { if (!b.dataset.lock) b.disabled = cd > 0 || sending || out; });
  const os = $('#raid-out-sec', el); if (os) os.textContent = Math.max(0, Math.ceil((outUntil - Date.now()) / 1000));
  for (const [id, end] of Object.entries(outEnds)) {
    const st = $(`#raid-mem [data-pick="${CSS.escape(id)}"] .mem-top small`, el); if (!st) continue;
    const sec = Math.ceil((end - Date.now()) / 1000); st.textContent = sec > 0 ? `쉼 ${sec}초` : '쉬는 중';
  }
  if (outUntil && outUntil <= Date.now() && !resting && !away) { outUntil = 0; resting = true; outBox(); }
}

function draw() {
  if (!el) return;
  const s = snap || {}, r = s.raid;
  if (!r) {
    built = '';
    el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 합동 토벌</p><h1>봉연</h1></div></div>
      <div class="panel"><div class="panel-body"><p class="desc">지금은 드러난 봉연의 그림자가 없습니다. 출현 하루 전부터 전체 채팅 「봉연 소식」과 알림으로 후보 지역을 알려 드립니다.</p>${locksHtml(s.locks)}</div></div>`;
    return;
  }
  const me = s.me || {}, ended = settled(s);
  if (me.joined || ended) clearFightNotes(['raid_invite'], 'raid_id', r.id);
  if (s.vote?.mine || ended) clearFightNotes(['raid_vote'], 'raid_id', r.id);
  const t0 = Date.now();
  outEnds = r.status === 'fight' ? Object.fromEntries((s.members || []).filter(m => m.out && !m.away).map(m => [m.id, t0 + m.out * 1000])) : {};
  outUntil = me.out ? t0 + me.out * 1000 : 0;
  away = !!(me.joined && !me.left && me.away && r.status === 'fight');
  resting = !!(me.joined && !me.left && me.resting && !me.out && !away && r.status === 'fight');
  const key = `${r.id}:${r.status}:${!!me.joined}:${me.left ? 1 : 0}:${me.can_join ? 1 : 0}:${s.vote ? s.vote.until : ''}`;
  if (key !== built) { build(); built = key; } else patch();
  countdown();
  const was = shownStatus; shownStatus = r.status;
  if (was && was !== r.status && ended) showResult(el);
}
function build() {
  const s = snap, r = s.raid, me = s.me || {}, fight = r.status === 'fight', ended = r.status === 'won' || r.status === 'failed';
  const timeLine = r.status === 'announced' ? (r.spawn_at ? `${icon('hourglass', 14)} <b>${esc(r.region || '')}</b> · <span data-until="${esc(r.spawn_at)}">${left(r.spawn_at)}</span> 뒤 출현`
      : `${icon('hourglass', 14)} 후보 · ${esc((r.candidates || []).join(', '))} 가운데 한 곳`)
    : r.status === 'signup' ? `${icon('hourglass', 14)} 참가 신청 · <span data-until="${esc(r.signup_until)}">${left(r.signup_until)}</span> 남음`
    : fight ? `${icon('hourglass', 14)} 남은 시간 · <span data-until="${esc(r.ends_at)}">${left(r.ends_at)}</span>`
    : `${icon('check', 14)} ${r.ended_at ? new Date(r.ended_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''} 끝남`;
  const playing = me.joined && !me.left && fight;
  el.innerHTML = `<div class="view-head raid-head"><div><p class="eyebrow">${icon('flag', 14)} ${r.kind === 'final' ? '10장 최종 결전' : '서버 토벌'}${r.region ? ` · ${esc(r.region)}` : ''}</p>
      <h1>${esc(r.boss)} <small>${esc(STATUS[r.status] || '')}</small></h1></div>
      <div class="head-actions">${me.joined ? '' : chip('관전 중')}${me.joined && r.kind === 'final' && (fight || r.status === 'signup') ? `<button class="btn small danger raid-forfeit keep-label" id="raid-forfeit">${icon('back', 15)}<span>포기</span></button>` : ''}${me.joined && !me.left && r.kind === 'world' && (fight || r.status === 'signup') ? `<button class="btn small keep-label" id="raid-leave" title="${fight ? '토벌에서 나가기(기여도는 남음)' : '참가 신청 거두기'}" aria-label="${fight ? '토벌에서 퇴장' : '신청 거두기'}">${icon('back', 15)}<span>${fight ? '퇴장' : '신청 거두기'}</span></button>` : ''}${r.kind === 'world' ? `<a class="btn small ghost" href="#/guide">${icon('help', 15)}<span>도움말</span></a>` : ''}</div></div>
    <div class="raid-wrap ${playing ? 'playing' : ''}">
      <section class="panel raid-boss"><div class="panel-body">
        <p class="raid-time">${timeLine}</p>
        ${r.status === 'announced' ? '' : `<div class="raid-hp"><div class="bar boss"><span id="raid-hpbar"></span></div><b id="raid-hpnum"></b><span id="raid-phase"></span></div>`}
        ${r.status === 'announced' || ended ? '' : '<div class="raid-says" id="raid-says" aria-live="polite"></div>'}
        ${voteHtml(s.vote)}
        ${joinHtml(r, me)}
        ${ended ? resultHtml(r, s.members) : ''}
      </div></section>
      ${playing ? actionsShell(me) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 참가자 <span id="raid-mcount"></span></h2>${playing ? '<small class="muted">이름을 누르면 협동 기술 대상</small>' : ''}</header><div class="panel-body"><ul class="raid-mem" id="raid-mem"></ul><div class="mem-detail" id="raid-memdetail" hidden></div>${r.status === 'announced' ? '' : '<div class="dm-host" id="raid-meter"></div>'}</div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2><span class="raid-legend"><i class="lg-out"></i>내가 준 피해<i class="lg-in"></i>받은 피해</span></header><div class="panel-body"><ol class="raid-log" id="raid-log"></ol></div></section>
    </div>
    ${locksHtml(s.locks)}`;
  logCount = 0;
  patch();
  bind();
}
function patch() {
  const s = snap, r = s.raid, me = s.me || {}, members = s.members || [];
  const pct = r.max_hp ? Math.max(0, Math.min(100, r.hp / r.max_hp * 100)) : 100;
  const hb = $('#raid-hpbar', el); if (hb) hb.style.width = pct + '%';
  const hn = $('#raid-hpnum', el); if (hn) hn.textContent = r.max_hp ? `${fmt.num(r.hp)} / ${fmt.num(r.max_hp)}` : '모이는 중';
  $('.raid-hp .bar', el)?.toggleAttribute('hidden', !r.max_hp);
  const ph = $('#raid-phase', el); if (ph) ph.innerHTML = r.phase > 1 ? chip(`${r.phase}단계`, 'bad') : '';
  const sy = $('#raid-says', el);
  if (sy) {
    const fx = fxChips((r.boss_fx || []).filter(k => BOSS_FX.includes(k)));
    sy.innerHTML = `<p class="raid-intent ${r.intent ? 'on' : ''}">${icon('flame', 14)}<span>${r.intent ? esc(r.intent) : '요괴가 숨을 고르는 중'}</span></p>
      <div class="raid-charge ${r.charge ? 'on' : ''} ${r.charge?.secs != null ? 'timed' : ''}">${r.charge ? `${r.charge.secs != null ? '<i class="ch-time"></i>' : ''}<span title="${fmt.num(r.charge.need)} 넘게 몰아치면 끊깁니다">${icon('flame', 14)} 기운 모으기 ${r.charge.secs != null ? '<span class="ch-left"><b class="ch-sec"></b>초 남음</span>' : `${r.charge.left}번 남음`} · 끊기까지 ${fmt.num(Math.max(0, r.charge.need - (r.charge.got || 0)))}</span><div class="bar"><span style="width:${Math.min(100, (r.charge.got || 0) / Math.max(1, r.charge.need) * 100)}%"></span></div>` : ''}</div>
      <div class="chips raid-bfx">${fx}</div>`;
    chargeEnd = r.charge?.secs != null ? Date.now() + r.charge.secs * 1000 : 0; chargeDur = (r.charge?.dur || 8) * 1000;
    chargeTick();
  }
  const mc = $('#raid-mcount', el); if (mc) mc.textContent = `${members.length}명`;
  const ml = $('#raid-mem', el); if (ml) ml.innerHTML = membersHtml(members);
  memDetail(members);
  mountMeter($('#raid-meter', el), members);
  patchActions(me, members);
  const log = $('#raid-log', el);
  if (log) {
    const all = s.log || [], top = mobileLog(), myName = members.find(m => m.me)?.name || '';
    const lastId = all.length ? all[all.length - 1].id : 0, fresh = all.filter(l => l.id > logCount);
    const html = list => newestFirst(list, top).map(l => logLine(l, r.boss, myName)).join('');
    if (!logCount || log.dataset.top !== String(top) || fresh.length === all.length) {
      log.innerHTML = html(all) || '<li class="muted">아직 기록이 없습니다.</li>'; log.dataset.top = String(top);
      log.scrollTop = top ? 0 : log.scrollHeight;
    } else if (fresh.length) {
      const near = atLogEdge(log, top);
      log.insertAdjacentHTML(top ? 'afterbegin' : 'beforeend', html(fresh));
      while (log.children.length > 80) (top ? log.lastElementChild : log.firstElementChild).remove();
      if (near) log.scrollTop = top ? 0 : log.scrollHeight;
    }
    logCount = lastId;
    fitLog(log);
  }
  tray.redraw();
}
function chargeTick() {
  clearTimeout(chargeT);
  const box = el && $('#raid-says .raid-charge.timed', el); if (!box || !chargeEnd) return;
  const ms = Math.max(0, chargeEnd - Date.now());
  const sec = $('.ch-sec', box); if (sec) sec.textContent = (ms / 1000).toFixed(1);
  if (ms <= 0) { const lf = $('.ch-left', box); if (lf) lf.textContent = '곧 터짐'; }
  const bar = $('.ch-time', box); if (bar) bar.style.width = `${Math.min(100, ms / chargeDur * 100)}%`;
  box.classList.toggle('urgent', ms < 3000);
  if (ms > 0) chargeT = setTimeout(chargeTick, 100);
}
let fitT = null;
window.addEventListener('resize', () => { clearTimeout(fitT); fitT = setTimeout(() => { if (el && snap?.raid && built) { logCount = 0; patch(); } }, 150); });
function logLine(l, boss, myName) {
  const who = l.who, n = l.n, has = who != null && n != null, mine = who && who === myName ? ' mine' : '';
  const t = `<time>${fmt.time(l.at)}</time>`;
  if (has && (l.kind === 'atk' || l.kind === 'crit')) return logRow(`k-out${mine}`, `<b>${esc(who)}</b> → ${esc(boss)} <em>${fmt.num(+n)}</em> 피해${l.kind === 'crit' ? ' <i class="crit">치명타</i>' : ''}`, t);
  if (has && l.kind === 'hit') return logRow(`k-in${mine}`, `${esc(boss)} → <b>${esc(who)}</b> <em>−${fmt.num(+n)}</em> 맞음`, t);
  if (has && l.kind === 'fall') return logRow(`k-in fall${mine}`, `${esc(boss)} → <b>${esc(who)}</b> <em>−${fmt.num(+n)}</em> 쓰러져 물러남`, t);
  return logRow(`k-${esc(l.kind)}${mine || (myName && String(l.text || '').startsWith(`${myName} — `) ? ' mine' : '')}`, esc(l.text), t);
}
let votedFor = null;
function askVote(r) {
  const v = snap?.vote;
  if (!v || v.mine || votedFor === v.until || !snap.me?.joined) return;
  votedFor = v.until;
  ask(`${v.by}이(가) 결전을 포기하자고 합니다.\n모두 동의하면 다 함께 물러나고 결전은 실패로 끝납니다(보상 없음).\n한 사람이라도 반대하면 결전을 이어 갑니다.\n지금 동의 ${v.yes}/${v.need} · ${left(v.until)} 안에 답해 주세요.`,
    { title: '결전 포기 제안', ok: '동의하고 물러나기', cancel: '반대하고 계속 싸우기', danger: true })
    .then(agree => rpc('world_raid_forfeit_vote', { p_raid: r.id, p_agree: !!agree }))
    .then(out => { if (out?.raid) { snap = out; lastFetch = Date.now(); if (settled(snap)) settle(); draw(); } })
    .catch(e => toast(e.message || String(e), 'error'));
}
const voteHtml = v => v ? `<p class="hint warn">${icon('flag', 14)}<span><b>${esc(v.by)}</b>의 포기 제안 · 동의 <b>${v.yes}/${v.need}</b> · <span data-until="${esc(v.until)}">${left(v.until)}</span> 남음${v.mine ? ' · 나는 동의함' : ''}</span></p>` : '';

function joinHtml(r, me) {
  const late = r.kind === 'world' && r.status === 'fight';
  if (r.status !== 'signup' && !late) return '';
  if (late && me.joined && me.left) return `<p class="hint">${icon('back', 14)} 토벌에서 나왔습니다. 지금까지의 기여는 남아 토벌이 끝나면 그 몫만큼 보상을 받습니다.</p>
    <button class="btn primary" id="raid-join" data-here="토벌 합류">${icon('flag', 16)}<span>다시 참가</span></button><p class="muted small">토벌 지역에 있어야 다시 참가할 수 있습니다. 돌아오면 쉬는 중이니 준비되면 행동하세요.</p>`;
  if (late && me.joined) return '';
  if (me.joined) return `<p class="hint good">${icon('check', 14)} 참가를 신청했습니다. 신청이 끝나면 토벌이 시작됩니다.</p>
    ${r.kind === 'final' && r.leader ? `<button class="btn primary" id="raid-begin">${icon('sword', 16)}<span>지금 시작하기</span></button><p class="muted small">함께할 동료가 다 왔으면 바로 시작합니다. 90초가 지나면 저절로 시작합니다.</p>` : ''}`;
  return me.can_join ? `<button class="btn primary" id="raid-join" data-here="토벌 합류">${icon('flag', 16)}<span>${r.kind === 'final' ? '결전에 합류' : late ? '지금 토벌에 합류' : '토벌 참가 신청'}</span></button>${late ? '<p class="muted small">지금 합류하면 남은 시간만큼 그림자의 체력이 늘고, 기여도는 합류한 뒤부터 쌓입니다.</p>' : ''}`
    : `<p class="hint">${icon('pin', 14)} ${esc(me.why || '신청할 수 없습니다.')}</p>`;
}

function resultHtml(r, members) {
  const mine = (members || []).find(m => m.me), rw = mine?.reward;
  const items = rw?.items ? Object.entries(rw.items).map(([k, v]) => `${esc(nameOf(k))} ×${v}`).join(', ') : '';
  return resultBox(r.status === 'won', esc(`${r.boss || '요괴'}을(를) ${r.status === 'won' ? '물리쳤습니다' : '막지 못했습니다'}`),
    `${rw ? `<p class="small">기여도 ${rw.share}%${rw.gil ? ` · ${fmt.num(rw.gil)}전` : ''}${rw.xp ? ` · 경험치 ${fmt.num(xpGot(rw.xp))}` : ''}${items ? ` · ${items}` : ''}${rw.lost ? ` · 가방이 모자라 두고 옴: ${esc(rw.lost)}` : ''}</p>` : mine ? '' : '<p class="muted small">관전한 토벌입니다.</p>'}
    ${r.kind === 'world' && r.status === 'failed' ? '<p class="muted small">출현 지역이 다음 회차까지 봉연에 잠깁니다(그곳·이웃 침식과 요괴 조우 증가).</p>' : ''}`);
}

function actionsShell(me) {
  return `<section class="panel raid-act"><div class="panel-body">
    <div class="raid-out" id="raid-out" hidden><b id="raid-out-title"></b><span id="raid-out-text"></span></div>
    <div class="raid-me" id="raid-me"></div>
    <div class="raid-buttons">
      <button class="btn primary" data-act="attack">${icon('sword', 16)}<span>공격</span></button>
      <button class="btn" data-act="guard">${icon('shield', 16)}<span>방어</span></button>
      <button class="btn" id="raid-items" type="button">${icon('heart', 16)}<span>물품</span></button>
      <button class="btn raid-coop-open" id="raid-coop-open" type="button">${icon('users', 16)}<span>기술</span></button>
    </div>
    <div class="raid-coopbox" id="raid-coopbox"></div>
  </div></section>`;
}
function coopButtons(me) {
  return (me.coop || []).map(k => coopBtn({ ...k, why: !k.unlocked ? `전투 숙련 ${k.rank}단계` : k.cd > 0 ? `${k.cd}초` : (me.sp || 0) < k.cost ? `${spOf()[0]} ${k.cost}` : '' },
    `data-act="coop" data-skill="${esc(k.id)}" data-tgt="${esc(k.target)}"`)).join('');
}
function patchActions(me, members) {
  const box = $('#raid-me', el); if (!box) return;
  const tgt = target && members.some(m => m.id === target) ? target : members.find(m => m.me)?.id;
  const tName = members.find(m => m.id === tgt)?.name || '나';
  const mine = members.find(m => m.me), spName = spOf()[0];
  const so = me.solo;
  box.innerHTML = `${vitHtml('체력', me.hp, 'hp', me.hp < 35)}${vitHtml(spName, me.sp, spOf()[1])}${ammoHtml(me.ammo)}${so ? soloAidHtml(so.final_dmg ?? so.solo_dmg, so.final_guard ?? 0, so.solo_falls) : ''}
    <div class="raid-mine"><span class="rm-txt">${mine ? `내 피해 <b>${fmt.num(mine.dmg || 0)}</b> · 기여 <b>${mine.share}%</b>${creditLine(mine.credits)}` : ''}</span><span class="rm-fx">${fxChips(Object.keys(me.fx || {}))}</span></div>`;
  outBox(me);
  const cb = $('#raid-coopbox', el);
  if (cb) {
    const btns = coopButtons(me);
    cb.innerHTML = btns ? `<p class="raid-tgt muted small">협동 기술 대상 · <b>${esc(tName)}</b></p><div class="coop-grid">${btns}</div>` : '<p class="muted small">협동 기술은 전투 숙련 3·8·18·36단계에서 열립니다.</p>';
    bindActs(cb);
  }
}
function outBox(me = snap?.me || {}) {
  const ob = el && $('#raid-out', el); if (!ob || !snap?.raid) return;
  const outNow = outUntil > Date.now(), off = outNow || away || resting;
  ob.hidden = !off; el.classList.toggle('raid-is-out', outNow || away); el.classList.toggle('raid-is-rest', !outNow && !away && resting); ob.classList.toggle('rest', resting && !outNow && !away);
  const region = esc(snap.raid.region || '토벌 자리');
  $('#raid-out-title', ob).innerHTML = away ? `${icon('pin', 14)} 토벌 자리를 비웠습니다`
    : outNow ? `${icon('hourglass', 14)} 물러나 숨을 고르는 중 · <span id="raid-out-sec">${Math.ceil((outUntil - Date.now()) / 1000)}</span>초`
    : `${icon('check', 14)} 쉬는 중 · 준비되면 행동해서 돌아가세요`;
  $('#raid-out-text', ob).innerHTML = away
    ? `지금은 물러난 것으로 셉니다. 요괴가 나를 노리지 않고 쌓은 기여도는 그대로입니다. 가방·퀵슬롯·거점 휴식으로 회복한 뒤 <b>${region}</b>${particle(snap?.raid?.region || '토벌 자리', '(으)로')} 돌아오면 다시 합류하지 않고 바로 싸웁니다.`
    : snap.raid.kind === 'final' ? (outNow ? `체력이 1이 되어 물러났습니다. 30초 동안 숨을 고른 뒤에도 <b>저절로 돌아가지 않으니</b>, <b>결전 화면의 「물품」</b>으로 회복하세요(결전 중에는 가방·퀵슬롯에서 바로 쓸 수 없습니다).`
      : `요괴가 나를 노리지 않습니다. 준비가 되면 <b>결전 화면의 「물품」</b>으로 회복하거나(쉬는 중에 쓰면 체력 30으로 돌아갑니다) <b>공격·방어·기술</b>을 눌러 돌아가세요. 돌아가면 먼저 <b>방어</b>가 안전합니다.`)
    : outNow ? `체력이 1이 되어 물러났습니다. 1분 동안 숨을 고른 뒤에도 <b>저절로 돌아가지 않으니</b>, 그사이 <b>「물품」·가방·퀵슬롯</b>으로 회복하거나 거점에 가서 쉬고 오세요(자리를 비운 동안도 물러난 것으로 셉니다).`
    : `요괴가 나를 노리지 않습니다. 가방·퀵슬롯으로 마저 회복하고, 준비가 되면 <b>공격·방어·기술</b>을 눌러 돌아가세요(「물품」 창의 물품도 쉬는 동안은 행동이 되지 않습니다). 돌아가면 먼저 <b>방어</b>가 안전합니다.`;
}
const tray = itemTray({ title: '토벌에서 쓸 물품', bodyId: 'raid-items-body', fill: fillItems });
function fillItems(box) {
  const inv = store.character?.inventory || {}, out = outUntil > Date.now() || away || resting;
  const fin = snap?.raid?.kind === 'final', left = snap?.me?.items_left;
  box.innerHTML = `<p class="muted small">${fin ? `체력 회복품은 <b>한 싸움에 다섯 개까지</b> · 남은 횟수 <b>${left ?? 0}/5</b>. 물품을 쓰면 그 차례의 행동이 되고, 쉬는 중이면 체력 30으로 싸움에 돌아갑니다.` : out ? '물러나 있거나 쉬는 중·자리를 비운 동안에는 행동 간격 없이 쓰고, 써도 싸움에 돌아가지 않습니다.' : '물품을 쓰면 그 차례의 행동이 됩니다(1초 간격).'}</p>
    ${fin && !left ? '<p class="hint warn">이 결전에서 쓸 수 있는 체력 회복품을 다 썼습니다.</p>' : ''}
    ${itemSectionsHtml(battleItems(), inv)}`;
  if (fin && !left) $$('[data-use]', box).forEach(b => { if (catItem(baseOf(b.dataset.use))?.fx?.hp > 0) { b.disabled = true; b.title = '다 썼습니다'; } });
  $$('[data-use]:not(:disabled)', box).forEach(b => b.onclick = () => {
    const k = b.dataset.use;
    if (!fin && (outUntil > Date.now() || away || resting)) run(b, async () => { await act('world_use_item', { p_item_id: k }); return rpc('world_raid_snapshot', { p_raid: snap.raid.id }); }, false).then(tray.refill);
    else run(b, () => rpc('world_raid_action', { p_raid: snap.raid.id, p_action: 'item', p_item: k }), true).then(tray.refill);
  });
}
function membersHtml(list) {
  if (!(list || []).length) return '<li class="muted small raid-mem-empty">아직 참가자가 없습니다.</li>';
  return list.map(m => memberLi(m, { me: m.me, tgt: m.id === target, sel: m.id === sel, out: m.out || m.away || m.resting || m.left, fx: m.buffs,
    state: settled(snap) ? '' : m.left ? '퇴장' : m.away ? '자리 비움' : m.out ? `쉼 ${m.out}초` : m.resting ? '쉬는 중' : '',
    title: `${m.name} · Lv${m.level} ${jobName(m.job)} · 기여 ${m.share}%`,
    sub: `${esc(jobName(m.job))} · 기여 ${m.share}%${fxKeys(m.buffs).length ? ` · ${fxKeys(m.buffs).map(k => FX_NAME[k]).join('·')}` : ''}` })).join('');
}
function memDetail(list) {
  showSelected(el && $('#raid-memdetail', el), list, sel, m => ({
    state: settled(snap) ? '' : m.left ? '퇴장(기여 남음)' : m.away ? '자리 비움' : m.out ? `물러남 · ${m.out}초` : m.resting ? '쉬는 중' : snap.raid.status === 'fight' ? '싸우는 중' : '',
    nums: [['기여', `${m.share}%`], ...fightNums(m)],
    fx: m.buffs, extra: creditLine(m.credits) }), () => { sel = null; patch(); });
}
function locksHtml(locks) {
  if (!(locks || []).length) return '';
  return `<p class="hint warn raid-locks">${icon('flame', 14)}<span>봉연에 잠긴 곳 · ${locks.map(l => `<b>${esc(l.region)}</b>`).join(', ')} — 그곳은 침식·요괴 조우·받는 피해가 늘고 채집량이 줄며, 이웃 지역도 침식·요괴 조우가 늘어납니다. 다음 그림자를 물리치면 풀립니다.</span></p>`;
}

function bindActs(scope) {
  const r = snap?.raid; if (!r) return;
  $$('[data-act]', scope).forEach(b => b.onclick = () => {
    const a = b.dataset.act;
    const args = { p_raid: r.id, p_action: a };
    if (a === 'coop') {
      args.p_skill = b.dataset.skill;
      if (b.dataset.tgt === 'ally') {
        const ms = snap.members || [], picked = ms.find(m => m.id === target && !m.me);
        const ally = picked || ms.find(m => !m.me && !m.out && !m.away && !m.resting) || ms.find(m => !m.me && !m.away);
        if (!ally) { toast('이 기술을 받을 동료가 없습니다.', 'warn'); return; }
        args.p_target = ally.id;
      }
    }
    run(b, () => rpc('world_raid_action', args), true);
  });
}
function bind() {
  const r = snap?.raid; if (!r) return;
  const jb = $('#raid-join', el);
  if (jb) jb.onclick = () => run(jb, async () => { const o = await rpc('world_raid_join', { p_raid: r.id }); if (o?.content) toast(o.content, 'info'); return rpc('world_raid_snapshot', { p_raid: r.id }); });
  const fb = $('#raid-forfeit', el);
  if (fb) fb.onclick = async () => {
    const solo = (snap.members || []).length <= 1, v = snap.vote;
    const ok = await ask(solo ? '결전을 포기하면 지금 바로 실패로 끝납니다.\n보상은 없고, 다시 도전할 수 있습니다.'
      : v ? `${v.by}의 포기 제안에 동의합니다.\n모두 동의하면 다 함께 물러나고 결전은 실패로 끝납니다(보상 없음).`
      : '함께 싸우는 동료들에게 포기를 제안합니다.\n60초 안에 모두 동의하면 다 함께 물러나고 결전은 실패로 끝납니다(보상 없음).\n한 사람이라도 반대하면 결전을 이어 갑니다.',
      { title: solo ? '결전을 포기합니까?' : '동료에게 포기를 제안합니까?', ok: solo ? '포기하고 나오기' : v ? '동의하기' : '포기 제안하기', cancel: '계속 싸우기', danger: true });
    if (!ok) return;
    await run(fb, () => rpc('world_raid_forfeit', { p_raid: r.id }));
  };
  const lb = $('#raid-leave', el);
  if (lb) lb.onclick = async () => {
    const fighting = r.status === 'fight';
    const ok = await ask(fighting ? '토벌에서 나옵니다.\n지금까지 쌓은 기여도는 그대로 남아, 토벌이 끝나면 그 몫만큼 보상을 받습니다(기여 1% 이상).\n나간 동안은 요괴가 노리지 않고 가방 물품도 쓸 수 있습니다. 다시 참가하면 이어서 싸웁니다.'
      : '참가 신청을 거둡니다. 모집이 끝나기 전이면 다시 신청할 수 있습니다.', { title: fighting ? '토벌에서 나갈까요?' : '신청을 거둘까요?', ok: fighting ? '퇴장' : '거두기', cancel: '그대로 있기' });
    if (!ok) return;
    await run(lb, async () => { const o = await rpc('world_raid_leave', { p_raid: r.id }); if (o?.content) toast(o.content, 'info'); return rpc('world_raid_snapshot', { p_raid: r.id }); });
  };
  askVote(r);
  const bb = $('#raid-begin', el);
  if (bb) bb.onclick = () => run(bb, () => rpc('world_raid_begin', { p_raid: r.id }));
  const ml = $('#raid-mem', el);
  if (ml) ml.onclick = e => { const b = e.target.closest('[data-pick]'); if (!b) return; const id = b.dataset.pick; sel = sel === id ? null : id; if (snap?.me?.joined && snap?.raid?.status === 'fight') target = id; patch(); };
  $$('.raid-buttons [data-act]', el).forEach(b => b.onclick = () => { if (b.dataset.act === 'attack') ammoWarn(snap?.me?.ammo); return run(b, () => rpc('world_raid_action', { p_raid: r.id, p_action: b.dataset.act }), true); });
  const ib = $('#raid-items', el); if (ib) ib.onclick = tray.open;
  const co = $('#raid-coop-open', el); if (co) co.onclick = () => { const w = $('.raid-act', el); w?.classList.toggle('coop-open'); co.classList.toggle('on', !!w?.classList.contains('coop-open')); };
}

async function run(btn, fn, isAct) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const out = await fn();
    if (out?.raid) { snap = out; lastFetch = Date.now(); }
    if (isAct) readyAt = Date.now() + 1000;
    if (settled(snap)) await settle();
    else if (btn.dataset.act === 'item' || btn.dataset.use) await reloadCharacter();
    else if (store.character && snap?.me) { store.character = { ...store.character, health: snap.me.hp, spiritual_power: snap.me.sp }; emit('character', store.character); }
    invalidate('world_raid_brief');
    draw();
  } catch (e) { toast(e.message || String(e), 'error'); if (!btn.dataset.act) btn.disabled = false; }
  finally { sending = false; countdown(); }
  return null;
}

function briefAge() {
  const w = store.snaps['world_raid_briefnull']?.world; if (!w) return 600000;
  if (w.status === 'signup' || w.status === 'fight') return 60000;
  const now = Date.now(), at = x => x ? new Date(x).getTime() : Infinity;
  const due = Math.min(at(w.spawn_at), w.region ? Infinity : at(w.spawn_at) - 12 * 3600e3);
  return now >= due ? 0 : 600000;
}
export const raidBand = () => '<div id="raid-band"></div>';
export async function fillRaidBand(box) {
  if (!box) return;
  const wedP = load('world_wedding_now', undefined, { maxAge: 60000 }).catch(() => null);
  let b = null; if (RAID_ON) { try { b = await load('world_raid_brief', undefined, { maxAge: briefAge() }); } catch {} }
  const wed = await wedP;
  if (!box.isConnected) return;
  const w = b?.world, rows = [];
  const fr = feastBandRow(); if (fr) rows.push(fr);
  if (wed?.wed_id) rows.push(`<a class="raid-band-row hot" href="#" data-wed-band="${esc(wed.wed_id)}">${icon('heart', 14)}<span><b>${esc(wed.a)}·${esc(wed.b)}</b>의 혼례 · ${esc(wed.place || '')} · ${wed.status === 'ceremony' || new Date(wed.starts_at) <= new Date() ? `${left(wed.ends_at)} 남음` : `${left(wed.starts_at)} 뒤 시작`}</span><small>혼례 보기</small></a>`);
  if (b?.final) rows.push(`<a class="raid-band-row hot" href="#/raid/${esc(b.final)}">${icon('sword', 14)}<span><b>구중 봉주와의 결전</b>이 열려 있습니다</span><small>들어가기</small></a>`);
  if (w) {
    const t = x => x ? left(x) : '';
    const what = w.status === 'announced' ? (w.region ? `<b>${esc(w.region)}</b> · ${t(w.spawn_at)} 뒤 출현` : `후보 · ${esc((w.candidates || []).join(', '))}`)
      : w.status === 'signup' ? `<b>${esc(w.region || '')}</b> · 참가 신청 ${t(w.signup_until)} 남음${w.joined ? ' · 신청함' : ''}`
      : `<b>${esc(w.region || '')}</b> · 토벌 중 ${w.max_hp ? Math.round(w.hp / w.max_hp * 100) : 0}% · ${t(w.ends_at)} 남음${w.joined ? '' : ' · 지금도 합류 가능'}`;
    rows.push(`<a class="raid-band-row ${w.status === 'announced' ? '' : 'hot'}" href="#/raid/${esc(w.id)}">${icon('flame', 14)}<span>${esc(w.boss)} · ${what}</span><small>${w.status === 'announced' ? '보기' : w.joined ? '들어가기' : w.status === 'signup' ? '신청·보기' : '합류·관전'}</small></a>`);
  }
  if ((b?.locks || []).length) rows.push(`<a class="raid-band-row lock" href="#/raid">${icon('moon', 14)}<span>봉연에 잠김 · ${b.locks.map(l => esc(l.region)).join(', ')}</span><small>자세히</small></a>`);
  box.innerHTML = rows.length ? `<div class="raid-band">${rows.join('')}</div>` : '';
  bindFeastBand(box);
  const wb = $('[data-wed-band]', box);
  if (wb) wb.onclick = async e => { e.preventDefault(); (await import('../bond.js')).openWedding(wb.dataset.wedBand); };
  backPrompt(w);
}
function backPrompt(w) {
  const loc = store.character?.location; if (!w || !loc || w.status !== 'fight' || !w.joined) return;
  const key = `yh-raid-back:${w.id}`; let prev = null;
  try { prev = sessionStorage.getItem(key); sessionStorage.setItem(key, loc); } catch {}
  if (loc !== w.region || prev === loc || location.hash.startsWith('#/raid')) return;
  ask(`${w.boss}과(와)의 토벌이 아직 이어지고 있습니다(${w.max_hp ? Math.round(w.hp / w.max_hp * 100) : 0}% · ${left(w.ends_at)} 남음).\n참가 기록과 쌓은 기여도는 그대로라, 다시 합류하지 않고 바로 싸울 수 있습니다.`,
    { title: '토벌로 돌아가기', ok: '토벌 화면으로', cancel: '나중에' }).then(ok => { if (ok) location.hash = `#/raid/${w.id}`; });
}
export const raidShadow = async () => { if (!RAID_ON) return null; try { const w = (await load('world_raid_brief', undefined, { maxAge: briefAge() }))?.world; return w?.region ? w : null; } catch { return null; } };
export const raidLocks = async () => { if (!RAID_ON) return []; try { return (await load('world_raid_brief', undefined, { maxAge: briefAge() }))?.locks || []; } catch { return []; } };
