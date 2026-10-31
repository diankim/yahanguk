// 합동 토벌(10장 결전·봉연의 그림자): 참가자는 행동하고, 신청하지 않은 사람은 같은 화면에서 관전한다.
// 판정은 모두 서버(world_raid_*)가 하고, 화면은 world_raids 실시간 변경을 받아 스냅샷을 다시 읽는다(관전 2초·참가 1초에 한 번까지).
import { db, rpc, store, emit, esc, icon, fmt, $, $$, toast, ask, nameOf, JOBS, RAID_ON, loadCharacter } from '../core.js';
import { load, invalidate, loading, errorBox, chip } from './common.js';

// 토벌에서 쓸 수 있는 회복·영력 물품(가방에 있는 것만 보인다)
const RAID_ITEMS = ['tonic', 'herbal_extract', 'herb', 'rejuv_pill', 'grand_pill', 'banyo_salve', 'fish_porridge', 'herb_rice', 'moss_porridge', 'bark_stew', 'herb_fish_steam', 'spirit_gukbap', 'calm_brew',
  'spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew'];
const BOSS_FX = { expose: '약점 드러남', stagger: '휘청임', smoke: '연막', break: '퇴마 결계' };
const BUFF = { ward: '결계', might: '기세', crit: '약점', crit_next: '급소', evade: '피할 길', shield: '보호막', cover: '보호받음', gward: '진언', taunt: '호법', guard: '방어', bound: '사슬' };
const STATUS = { announced: '예고', signup: '참가 신청 중', fight: '토벌 중', won: '토벌 성공', failed: '토벌 실패' };

let el = null, rid = null, snap = null, ch = null, tick = null, timer = null, lastFetch = 0, target = null, sending = false, readyAt = 0, pickedItem = null, outUntil = 0;

export async function render(root, sub) {
  el = root; rid = sub || null; snap = null; target = null;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 합동 토벌</p><h1>봉연</h1></div></div>${loading()}`;
  await refresh();
  subscribe();
  clearInterval(tick); tick = setInterval(countdown, 1000);
}
export function destroy() { if (ch) db.removeChannel(ch); ch = null; clearInterval(tick); clearTimeout(timer); el = null; }

async function refresh() {
  if (!el) return;
  lastFetch = Date.now();
  try {
    const prev = snap?.raid?.status;
    snap = await rpc('world_raid_snapshot', { p_raid: rid });
    if (snap?.raid?.id && rid !== snap.raid.id) { rid = snap.raid.id; subscribe(); }
    // 다른 사람의 마지막 한 방으로 끝났으면 내 전·경험치·가방을 다시 읽는다
    if (prev === 'fight' && settled(snap) && snap.me?.joined) settle();
    draw();
  } catch (e) { el.innerHTML = errorBox(e.message); }
}
const settled = s => s?.raid?.status === 'won' || s?.raid?.status === 'failed';
async function settle() { try { await loadCharacter(); } catch {} invalidate('world_raid_brief'); emit('changed', { name: 'world_raid_settle' }); }
// 다른 사람이 행동하면 토벌 줄이 바뀐다 — 너무 자주 다시 읽지 않게 간격을 둔다.
// 내 행동의 응답이 이미 스냅샷을 돌려주므로, 그 직후 같은 값으로 오는 실시간 변경은 건너뛴다
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
  if (ch) db.removeChannel(ch);
  ch = db.channel(`yh-raid-${rid || 'any'}`).on('postgres_changes', { event: '*', schema: 'public', table: 'world_raids', ...(rid ? { filter: `raid_id=eq.${rid}` } : {}) }, onChange).subscribe();
}

const left = t => { const ms = new Date(t) - Date.now(); return ms > 0 ? fmt.remain(ms) : '곧'; };
function countdown() {
  if (!el) return;
  $$('[data-until]', el).forEach(x => { x.textContent = left(x.dataset.until); });
  const cd = Math.max(0, readyAt - Date.now());
  const out = outUntil > Date.now();
  $$('[data-act]', el).forEach(b => { if (!b.dataset.lock) b.disabled = cd > 0 || sending || out; });
}

function draw() {
  if (!el) return;
  const s = snap || {}, r = s.raid;
  if (!r) {
    el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} 합동 토벌</p><h1>봉연</h1></div></div>
      <div class="panel"><div class="panel-body"><p class="desc">지금은 드러난 봉연의 그림자가 없습니다. 출현 하루 전부터 전체 채팅 「봉연 소식」과 알림으로 후보 지역을 알려 드립니다.</p>${locksHtml(s.locks)}</div></div>`;
    return;
  }
  const me = s.me || {}, fight = r.status === 'fight', ended = r.status === 'won' || r.status === 'failed';
  outUntil = me.out ? Date.now() + me.out * 1000 : 0;
  // 다시 그려도 고른 물품과 읽던 기록 자리를 지킨다
  const oldLog = $('.raid-log', el), atBottom = !oldLog || oldLog.scrollHeight - oldLog.scrollTop - oldLog.clientHeight < 24, oldTop = oldLog?.scrollTop || 0;
  const pct = r.max_hp ? Math.max(0, Math.min(100, r.hp / r.max_hp * 100)) : 100;
  const timeLine = r.status === 'announced' ? (r.spawn_at ? `${icon('hourglass', 14)} <b>${esc(r.region || '')}</b> · <span data-until="${esc(r.spawn_at)}">${left(r.spawn_at)}</span> 뒤 출현`
      : `${icon('hourglass', 14)} 후보 · ${esc((r.candidates || []).join(', '))} 가운데 한 곳`)
    : r.status === 'signup' ? `${icon('hourglass', 14)} 참가 신청 · <span data-until="${esc(r.signup_until)}">${left(r.signup_until)}</span> 남음`
    : fight ? `${icon('hourglass', 14)} 남은 시간 · <span data-until="${esc(r.ends_at)}">${left(r.ends_at)}</span>`
    : `${icon('check', 14)} ${r.ended_at ? new Date(r.ended_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : ''} 끝남`;
  const bossFx = (r.boss_fx || []).filter(k => BOSS_FX[k]).map(k => chip(BOSS_FX[k], 'ok')).join('');
  const charge = r.charge ? `<div class="raid-charge"><span>${icon('flame', 14)} 기운 모으기 · 남은 ${r.charge.left}번</span><div class="bar"><span style="width:${Math.min(100, (r.charge.got || 0) / Math.max(1, r.charge.need) * 100)}%"></span></div><small>${fmt.num(r.charge.got || 0)} / ${fmt.num(r.charge.need)} 몰아치면 끊긴다</small></div>` : '';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('flag', 14)} ${r.kind === 'final' ? '10장 최종 결전' : '서버 토벌'} · ${esc(r.region || '')}</p>
      <h1>${esc(r.boss)} <small>${esc(STATUS[r.status] || '')}</small></h1></div>
      <div class="head-actions">${me.joined ? '' : chip('관전 중')}${me.joined && r.kind === 'final' && (fight || r.status === 'signup') ? `<button class="btn small danger" id="raid-forfeit">${icon('back', 15)}<span>포기하고 나오기</span></button>` : ''}${r.kind === 'world' ? `<a class="btn small ghost" href="#/guide">${icon('help', 15)}<span>도움말</span></a>` : ''}</div></div>
    <div class="raid-grid">
      <section class="panel raid-boss"><div class="panel-body">
        <p class="raid-time">${timeLine}</p>
        ${r.status === 'announced' ? '' : `<div class="raid-hp"><div class="bar boss"><span style="width:${pct}%"></span></div><b>${fmt.num(r.hp)} / ${fmt.num(r.max_hp)}</b>${r.phase > 1 ? chip(`${r.phase}단계`, 'bad') : ''}</div>`}
        ${r.intent ? `<p class="hint warn">${icon('flame', 14)} ${esc(r.intent)}</p>` : ''}${charge}
        ${bossFx ? `<div class="chips">${bossFx}</div>` : ''}
        ${voteHtml(s.vote)}
        ${joinHtml(r, me)}
        ${ended ? resultHtml(r, s.members) : ''}
      </div></section>
      ${me.joined && fight ? actionsHtml(r, me, s.members) : ''}
      <section class="panel raid-members"><header class="panel-head"><h2>${icon('users', 16)} 참가자 ${(s.members || []).length}명</h2></header><div class="panel-body">
        ${membersHtml(s.members, me, r)}</div></section>
      <section class="panel raid-log-box"><header class="panel-head"><h2>${icon('scroll', 16)} 전투 기록</h2></header><div class="panel-body">
        <ol class="raid-log">${(s.log || []).map(l => `<li class="k-${esc(l.kind)}"><time>${fmt.time(l.at)}</time><span>${esc(l.text)}</span></li>`).join('') || '<li class="muted">아직 기록이 없습니다.</li>'}</ol></div></section>
    </div>
    ${locksHtml(s.locks)}`;
  const log = $('.raid-log', el); if (log) log.scrollTop = atBottom ? log.scrollHeight : oldTop;
  bind();
  countdown();
}

// 포기 제안이 오면 한 번 팝업으로 묻는다(제안마다 한 번, 내가 이미 동의했으면 묻지 않음). 창이 열린 사이 끝나면 답이 거절된다.
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
  // 서버 보스는 토벌 중에도 그 지역에서 합류할 수 있다(늦게 와도 합류할 수 있고, 늦을수록 기여도는 덜 쌓인다)
  const late = r.kind === 'world' && r.status === 'fight';
  if (r.status !== 'signup' && !late) return '';
  if (late && me.joined) return '';
  if (me.joined) return `<p class="hint good">${icon('check', 14)} 참가를 신청했습니다. 신청이 끝나면 토벌이 시작됩니다.</p>
    ${r.kind === 'final' && r.leader ? `<button class="btn primary" id="raid-begin">${icon('sword', 16)}<span>지금 시작하기</span></button><p class="muted small">함께할 동료가 다 왔으면 바로 시작합니다. 90초가 지나면 저절로 시작합니다.</p>` : ''}`;
  return me.can_join ? `<button class="btn primary" id="raid-join">${icon('flag', 16)}<span>${r.kind === 'final' ? '결전에 합류' : late ? '지금 토벌에 합류' : '토벌 참가 신청'}</span></button>${late ? '<p class="muted small">지금 합류하면 남은 시간만큼 그림자의 체력이 늘고, 기여도는 합류한 뒤부터 쌓입니다.</p>' : ''}`
    : `<p class="hint">${icon('pin', 14)} ${esc(me.why || '신청할 수 없습니다.')}</p>`;
}

function resultHtml(r, members) {
  const mine = (members || []).find(m => m.me), rw = mine?.reward;
  const items = rw?.items ? Object.entries(rw.items).map(([k, v]) => `${esc(nameOf(k))} ×${v}`).join(', ') : '';
  return `<div class="raid-result ${r.status === 'won' ? 'ok' : 'bad'}"><b>${esc(`${r.boss}을(를) ${r.status === 'won' ? '물리쳤습니다' : '막지 못했습니다'}`)}</b>
    ${rw ? `<p class="small">기여도 ${rw.share}%${rw.gil ? ` · ${fmt.num(rw.gil)}전` : ''}${rw.xp ? ` · 경험치 ${fmt.num(rw.xp)}` : ''}${items ? ` · ${items}` : ''}${rw.lost ? ` · 가방이 모자라 두고 옴: ${esc(rw.lost)}` : ''}</p>` : mine ? '' : '<p class="muted small">관전한 토벌입니다.</p>'}
    ${r.kind === 'world' && r.status === 'failed' ? '<p class="muted small">출현 지역이 다음 회차까지 봉연에 잠깁니다(그곳·이웃 침식과 요괴 조우 증가).</p>' : ''}</div>`;
}

function actionsHtml(r, me, members) {
  const inv = store.character?.inventory || {};
  const items = RAID_ITEMS.filter(k => Number(inv[k]) > 0);
  const tgt = target && (members || []).some(m => m.id === target) ? target : (members || []).find(m => m.me)?.id;
  const tName = (members || []).find(m => m.id === tgt)?.name || '나';
  const coop = (me.coop || []).map(k => {
    const lock = !k.unlocked, cd = k.cd > 0, low = (me.sp || 0) < k.cost;
    return `<button type="button" class="coop-btn ${lock ? 'locked' : ''}" data-act="coop" data-skill="${esc(k.id)}" data-tgt="${esc(k.target)}" ${lock || cd || low ? 'data-lock="1" disabled' : ''}
      title="${esc(k.desc)}"><b>${esc(k.name)}</b><small>${lock ? `전투 숙련 ${k.rank}단계` : cd ? `${k.cd}초` : `영력 ${k.cost}`}${k.target === 'ally' ? ' · 동료' : k.target === 'all' ? ' · 모두' : k.target === 'boss' ? ' · 요괴' : ''}</small></button>`;
  }).join('');
  return `<section class="panel raid-act"><header class="panel-head"><h2>${icon('sword', 16)} 내 행동</h2></header><div class="panel-body">
    ${me.out ? `<p class="hint warn">${icon('hourglass', 14)}<span>물러나 숨을 고르는 중 · <b>${me.out}초</b> 뒤 돌아옵니다.</span></p>` : ''}
    <div class="raid-me">${chip(`체력 ${me.hp}`, me.hp < 35 ? 'bad' : '')}${chip(`영력 ${me.sp}`)}${Object.keys(me.fx || {}).filter(k => BUFF[k]).map(k => chip(BUFF[k], k === 'bound' ? 'bad' : 'ok')).join('')}</div>
    <div class="raid-buttons">
      <button class="btn primary" data-act="attack">${icon('sword', 16)}<span>공격</span></button>
      <button class="btn" data-act="guard">${icon('shield', 16)}<span>방어</span></button>
      ${items.length ? `<select id="raid-item" aria-label="쓸 물품">${items.map(k => `<option value="${esc(k)}" ${k === pickedItem ? 'selected' : ''}>${esc(nameOf(k))} ×${inv[k]}</option>`).join('')}</select><button class="btn" data-act="item">${icon('heart', 16)}<span>쓰기</span></button>` : ''}
    </div>
    ${coop ? `<h3 class="sub-h">협동 기술 <small class="muted">대상: <b>${esc(tName)}</b> (참가자 이름을 눌러 고름)</small></h3><div class="coop-grid">${coop}</div>`
      : `<p class="muted small">협동 기술은 전투 숙련 3·8·18·36단계에서 열립니다.</p>`}
  </div></section>`;
}

function membersHtml(list, me, r) {
  if (!(list || []).length) return '<p class="muted small">아직 참가자가 없습니다.</p>';
  return `<ul class="raid-mem">${list.map(m => `<li class="${m.me ? 'me' : ''} ${m.id === target ? 'tgt' : ''} ${m.out ? 'out' : ''}">
      <button type="button" class="mem-pick" data-pick="${esc(m.id)}" ${me.joined && r.status === 'fight' ? '' : 'disabled'}>
        <b>${esc(m.name)}</b><small>Lv${m.level} · ${esc(JOBS[m.job]?.name || nameOf(m.job))}${m.out ? ` · 물러남 ${m.out}초` : ''}</small></button>
      <div class="bar ${m.hp < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, m.hp))}%"></span></div>
      <small class="mem-num">체력 ${m.hp} · 기여 ${m.share}%${m.buffs?.length ? ` · ${m.buffs.filter(k => BUFF[k]).map(k => BUFF[k]).join('·')}` : ''}</small></li>`).join('')}</ul>`;
}

function locksHtml(locks) {
  if (!(locks || []).length) return '';
  return `<p class="hint warn raid-locks">${icon('flame', 14)}<span>봉연에 잠긴 곳 · ${locks.map(l => `<b>${esc(l.region)}</b>`).join(', ')} — 그곳은 침식·요괴 조우·받는 피해가 늘고 채집량이 줄며, 이웃 지역도 침식·요괴 조우가 늘어납니다. 다음 그림자를 물리치면 풀립니다.</span></p>`;
}

function bind() {
  const r = snap?.raid; if (!r) return;
  const sel = $('#raid-item', el); if (sel) sel.onchange = () => { pickedItem = sel.value; };
  const jb = $('#raid-join', el);
  if (jb) jb.onclick = () => run(jb, () => rpc('world_raid_join', { p_raid: r.id }));
  // 결전 포기(7.4.3): 혼자면 바로 실패, 함께면 동료에게 제안하고 모두 동의하면 다 함께 물러난다(서버 world_raid_forfeit)
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
  askVote(r);
  const bb = $('#raid-begin', el);
  if (bb) bb.onclick = () => run(bb, () => rpc('world_raid_begin', { p_raid: r.id }));
  $$('[data-pick]', el).forEach(b => b.onclick = () => { target = b.dataset.pick; draw(); });
  $$('[data-act]', el).forEach(b => b.onclick = () => {
    const a = b.dataset.act;
    const args = { p_raid: r.id, p_action: a };
    if (a === 'item') args.p_item = $('#raid-item', el)?.value;
    if (a === 'coop') { args.p_skill = b.dataset.skill; if (b.dataset.tgt === 'ally') args.p_target = target || (snap.members || []).find(m => m.me)?.id; }
    run(b, () => rpc('world_raid_action', args), true);
  });
}

// 행동: 응답을 받은 때부터 이 기기 시계로 1초를 센다(전투 화면과 같은 방식)
async function run(btn, fn, isAct) {
  if (sending) return;
  sending = true; btn.disabled = true;
  try {
    const out = await fn();
    if (out?.raid) { snap = out; lastFetch = Date.now(); }
    if (isAct) readyAt = Date.now() + 1000;
    // 상태판의 체력·영력을 서버 값에 맞춘다(물품을 쓴 때만 가방까지 캐릭터를 다시 읽는다)
    if (settled(snap)) await settle();
    else if (btn.dataset.act === 'item') { try { await loadCharacter(); } catch {} }
    else if (store.character && snap?.me) { store.character = { ...store.character, health: snap.me.hp, spiritual_power: snap.me.sp }; emit('character', store.character); }
    invalidate('world_raid_brief');
    draw();
  } catch (e) { toast(e.message || String(e), 'error'); }
  finally { sending = false; countdown(); }
}

// 현장 머리의 토벌 띠: 봉연의 그림자 예고·신청·토벌, 내 결전, 봉연에 잠긴 곳(1분 동안 다시 씀)
export const raidBand = () => '<div id="raid-band"></div>';
export async function fillRaidBand(box) {
  if (!box) return;
  if (!RAID_ON) { box.remove(); return; }
  let b; try { b = await load('world_raid_brief', undefined, { maxAge: 60000 }); } catch { box.remove(); return; }
  if (!box.isConnected) return;
  const w = b?.world, rows = [];
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
}
// 봉연의 그림자가 나올 곳이 정해졌으면(world_raid_brief.world.region — 12시간 전 확정부터) 그 회차를, 아니면 null(지도 표시용, 7.5.9)
export const raidShadow = async () => { if (!RAID_ON) return null; try { const w = (await load('world_raid_brief', undefined, { maxAge: 60000 }))?.world; return w?.region ? w : null; } catch { return null; } };
export const raidLocks = async () => { if (!RAID_ON) return []; try { return (await load('world_raid_brief', undefined, { maxAge: 60000 }))?.locks || []; } catch { return []; } };
