import { gmBadge, ask, store, on, emit, rpc, act, loadCharacter, nameOf, fmt, esc, icon, bar, $, $$, guard, emblem, bagLimit, bagUsed, spOf, openModal, closeModal, effectText as fxText, xpNeed, LEVEL_CAP, midBattle, useItemAct, xpPct, xpGot, xpNote } from './core.js';
import { envChip } from './env.js';
import { load, invalidate } from './views/common.js';
import { playAlarm, armAlarm } from './sound.js';
import { QS_DEFAULT, qsDesc, presetNow } from './views/character.js';
import { expRoundOf, DOMAIN_FX, brokenName, NAMELESS } from './rules.js';
import { withHq, baseOf } from './hq.js';
import { hit } from './changes.js';

const IDLE_LABEL = { training: '자율 수련', research: '자료 조사', maintenance: '장비 정비', rest: '휴식' };
let root, tick, poll, refreshTimer, state = { idle: null, hud: null, exp: null };

export function mountHud(el) {
  root = el;
  root.innerHTML = `<button class="hud-strip" id="hud-strip" aria-expanded="false"></button><div class="hud-body" id="hud-body"></div>`;
  $('#hud-strip', root).onclick = () => {
    const open = root.classList.toggle('open');
    $('#hud-strip', root).setAttribute('aria-expanded', open);
  };
  on('character', render);
  on('env', render);
  on('changed', ev => {
    if (midBattle(ev)) { const b = ev.data?.battle; if (b && state.hud?.battle) Object.assign(state.hud.battle, { hp: b.hp ?? state.hud.battle.hp, max_hp: b.max_hp ?? state.hud.battle.max_hp }); return render(); }
    const idle = hit('idle', ev.name);
    clearTimeout(refreshTimer); refreshTimer = setTimeout(() => refresh({ char: false, idle, hudAge: 3000 }), 350);
  });
  refresh();
  clearInterval(tick); tick = setInterval(onTick, 1000);
  clearInterval(poll); poll = setInterval(() => {
    if (document.hidden) return;
    const roundDue = store.expedition && expRoundOf(store.expedition) !== tickedRound;
    if (roundDue || Date.now() - (store.charAt || 0) > 300000) refresh({ char: true, idle: !!state.idle?.active, hudAge: 45000 });
  }, 60000);
  let hiddenAt = 0;
  document.addEventListener('visibilitychange', () => {
    if (document.hidden) { hiddenAt = Date.now(); return; }
    if (Date.now() - hiddenAt < 30000) return;
    refresh({ char: Date.now() - (store.charAt || 0) > 45000, idle: !!state.idle?.active });
  });
}
function bumpStamina() {
  const st = state.hud?.stamina; if (!st?.next_at) return false;
  const t = new Date(st.next_at).getTime(); if (t > Date.now()) return false;
  const was = st.now || 0;
  st.now = Math.min(st.max, (st.now || 0) + 1);
  if (was < st.max && st.now >= st.max) playAlarm('stamina', 'st:' + t);
  st.next_at = st.now >= st.max ? null : new Date(t + (st.per_seconds || 900) * 1000).toISOString();
  return true;
}

function authLost(e) { if (/로그인이 필요합니다|권한이 없습니다/.test(String(e?.message || e || ''))) window.dispatchEvent(new Event('yh-auth-lost')); return null; }
export async function refresh({ char = true, idle: readIdle = true, hudAge = 0 } = {}) {
  try {
    if (store.expedition) {
      const r = expRoundOf(store.expedition), id = store.expedition.expedition_id;
      if (r !== tickedRound || id !== tickedExp) { tickedRound = r; tickedExp = id; await rpc('world_expedition_tick').catch(() => null); }
    }
    const first = !state.hud;
    if (!(first || !char) || !store.character) { await loadCharacter({ hud: true }); hudAge = Math.max(hudAge, 1000); }
    const [idle, hud] = await Promise.all([
      readIdle || first ? load('world_idle_activity_snapshot', undefined, { maxAge: first ? 0 : 10000 }).catch(authLost) : state.idle,
      load('world_hud_snapshot', undefined, { maxAge: hudAge }).catch(authLost),
    ]);
    const was = !!store.expedition;
    { const was = state.hud?.stamina, st = hud?.stamina;
      if (was?.next_at && was.now < was.max && st && st.now >= st.max) playAlarm('stamina', 'st:' + new Date(was.next_at).getTime()); }
    state = { idle, hud, exp: hud?.expedition || null };
    armAlarm('idle', 'end', idleReadyAt(idle)); armAlarm('exp', 'end', hud?.expedition?.ends_at);
    const wasIdle = !!store.idle?.active;
    store.expedition = state.exp; store.idle = idle;
    store.hud = hud;
    render();
    if (was !== !!state.exp) emit('expedition', state.exp);
    if (wasIdle !== !!idle?.active) emit('idle', idle);
  } catch (e) { console.warn('HUD 갱신 실패', e); }
}

function effectText(effects, potency = 1) { return fxText(effects, potency); }
export function openStatus(st) {
  const good = st.polarity === 'positive';
  const left = new Date(st.expires_at).getTime() - Date.now();
  const inv = store.character?.inventory || {};
  const m = openModal({ title: `${good ? '이로운 효과' : '상태이상'} · ${st.name}`, body: `
    <div class="status-detail ${good ? 'good' : 'bad'}">
      <p>${esc(st.description || '')}</p>
      <ul class="fx-list">${effectText(st.effects, st.potency).map(t => `<li>${esc(t)}</li>`).join('')}</ul>
      <p class="muted small">남은 시간 <b data-left="${new Date(st.expires_at).getTime()}">${fmt.remain(left)}</b>${st.stacks > 1 ? ` · ${st.stacks}겹` : ''}</p>
      ${good ? '' : `<h3 class="sub-h">치료 방법</h3><p>${esc(st.cure || '시간이 지나면 사라집니다.')}</p>
        ${(st.cure_items || []).length ? `<div class="btn-row">${withHq(st.cure_items, inv).map(k => `<button class="btn small primary" data-here="물품 사용" data-here-down data-cure="${esc(k)}" ${inv[k] > 0 ? '' : 'disabled'}>${esc(nameOf(k))} 쓰기 <small>×${fmt.num(inv[k])}</small></button>`).join('')}</div>` : ''}`}
    </div>` });
  const t = setInterval(() => { const b = m.querySelector('[data-left]'); if (!b) return clearInterval(t); b.textContent = fmt.remain(Number(b.dataset.left) - Date.now()); }, 1000);
  $$('[data-cure]', m).forEach(b => b.onclick = () => guard(b, async () => { const r = await useItemAct(b.dataset.cure); closeModal(); return r; }));
}

function idleReadyAt(idle) {
  if (!idle?.active) return null;
  if (idle.ready_at) return new Date(idle.ready_at).getTime();
  if (idle.started_at && idle.duration_minutes) return new Date(idle.started_at).getTime() + idle.duration_minutes * 60000;
  return null;
}

function statusItems(c) {
  const items = [];
  if (c.is_dead) items.push({ kind: 'danger', icon: 'flame', title: '영구 사망', text: c.death_reason || '이 캐릭터는 더 이상 행동할 수 없습니다.' });
  else if (c.downed_at || c.health <= 0) {
    const yo = yohwaOf(state.hud?.statuses);
    if (yohwaDowned(c, yo)) items.push({ kind: 'danger', icon: 'mask', title: '요화로 쓰러짐', text: '목숨은 잃지 않습니다. 구조·회생 부적으로는 일어날 수 없고, 안전지대 봉인(24시간 해독)을 골라야 합니다.', action: ['대처하기', () => window.yahangGo('char', 'status')] });
    else items.push({ kind: 'danger', icon: 'heart', title: '전투불능', timer: new Date(c.downed_at || Date.now()).getTime() + 4 * 3600e3, text: '구조를 기다리거나 회생 부적·구조대를 쓰세요.', action: ['대처하기', () => window.yahangGo('char', 'status')] });
  }
  { const yo = yohwaOf(state.hud?.statuses); if (yo.seal) items.push({ kind: 'busy', icon: 'shield', title: '봉인 해독 중', timer: new Date(yo.seal.expires_at).getTime(), text: '끝날 때까지 채팅만 할 수 있습니다.' }); }
  if (c.travel_arrives_at) {
    const left = new Date(c.travel_arrives_at).getTime() - Date.now();
    items.push({ kind: 'travel', icon: 'route', title: `이동 중 → ${nameOf(c.travel_destination) || '목적지'}`, timer: c.travel_arrives_at, text: left > 0 ? `${fmt.remain(left)} 후 도착` : '도착 처리 중…', action: left > 0 ? ['이동 취소', cancelTravel] : null });
  }
  const e = state.hud?.battle;
  if (e) items.push({ kind: 'combat', icon: 'sword', title: `전투 중 · ${e.name}`, text: `적 체력 ${e.hp}/${e.max_hp}`, meter: [e.hp, e.max_hp], action: ['전투로', () => window.yahangGo('home')] });
  const ready = idleReadyAt(state.idle);
  if (ready) {
    const left = ready - Date.now();
    items.push({ kind: 'idle', icon: 'hourglass', title: IDLE_LABEL[state.idle.activity_type] || '자율 활동', timer: ready, text: left > 0 ? `${fmt.remain(left)} 남음` : '완료 · 보상 수령 가능', action: left > 0 ? null : ['보상 수령', claimIdle], ready: left <= 0 });
  }
  if (state.exp) {
    const left = new Date(state.exp.ends_at).getTime() - Date.now();
    items.push({ kind: 'exp', icon: 'flame', title: `원정 · ${state.exp.place_name || ''}`, timer: state.exp.ends_at, text: left > 0 ? `${fmt.remain(left)} 남음` : '귀환 · 결과 확인 가능', action: ['원정 보기', openExpeditionView], ready: left <= 0,
      action2: onField() ? null : ['현장 보기', () => window.yahangGo('home')] });
  }
  if (!items.length) items.push({ kind: 'calm', icon: 'moon', title: '대기 중', text: '지도에서 이동하거나 현재 지역을 탐사하세요.' });
  return items;
}

function openExpeditionView() { closeStrip(); window.dispatchEvent(new CustomEvent('yh-open-expedition')); }
function closeStrip() { root?.classList.remove('open'); $('#hud-strip', root)?.setAttribute('aria-expanded', 'false'); }
const onField = () => !location.hash || location.hash === '#' || /^#\/(home)?(\/|$)/.test(location.hash);
window.addEventListener('hashchange', () => { closeStrip(); render(); });
let qsList = null, qsBusy = false;
async function loadQs() {
  if (qsBusy) return; qsBusy = true;
  try { const r = await load('world_quickslots_get', undefined, { maxAge: 600000 }); qsList = Array.isArray(r?.slots) ? r.slots : QS_DEFAULT; }
  catch { qsList = qsList || QS_DEFAULT; }
  qsBusy = false; render();
}
window.addEventListener('yh-qs-changed', () => { qsList = null; loadQs(); });
on('catalog', () => render());
function qsCard(c) {
  if (!qsList) { loadQs(); return ''; }
  const inv = c.inventory || {}, moving = !!c.travel_destination, downed = c.health <= 0 || !!c.downed_at;
  const cells = Array.from({ length: 8 }, (_, i) => qsList[i] || '').map(k => {
    if (!k) return '<span class="hqs empty"></span>';
    const n = Number(inv[k] || 0), off = !n || ((downed || moving) && baseOf(k) !== 'revival_charm');
    return `<button class="hqs ${n ? '' : 'none'}" data-here="물품 사용" data-here-down data-hqs="${esc(k)}" ${off ? 'disabled' : ''} title="${esc(nameOf(k))}${qsDesc(k) ? ` · ${esc(qsDesc(k))}` : ''}"><b>${esc(nameOf(k))}</b><small>×${fmt.num(n)}</small></button>`;
  }).join('');
  return `<section class="hud-card hud-qs"><h3>퀵슬롯 <a class="linkish" href="#/char/status">바꾸기</a></h3><div class="hqs-grid">${cells}</div></section>`;
}
function render() {
  const c = store.character; if (!root || !c) return;
  const items = statusItems(c);
  const need = xpNeed(c.level);
  const first = items[0];
  const rest = yohwaOf(state.hud?.statuses).rest;
  const badN = rest.filter(x => x.polarity !== 'positive').length, goodN = Math.min(10 - Math.min(10, badN), rest.length - badN);
  const slots = Array.from({ length: 10 }, (_, i) => i < badN ? 'bad' : i < badN + goodN ? 'good' : '');
  $('#hud-strip', root).innerHTML = `
    <span class="hs-name"><b><span class="hs-nm">${myName(c)}</span>${gmBadge(c.owner_id)}</b><small>Lv.${c.level}${c.profile?.title_name ? ` <span class="hs-ttl">「${esc(c.profile.title_name)}」</span>` : ''}</small></span>
    <span class="hs-bars"><i style="--v:${c.health}%" class="hp"></i><i style="--v:${c.mental}%" class="mp"></i><i style="--v:${c.spiritual_power}%" class="${spOf()[1]}"></i></span>
    ${erosionRing(c, 'mini')}
    ${(() => { const yo = yohwaOf(state.hud?.statuses);
      return `${yo.y ? `<span class="hs-yohwa s${yo.stage}${yo.fr ? ' frenzy' : ''}">${yo.fr ? '요괴화' : `요화${yo.stage}`}</span>` : yo.seal ? '<span class="hs-yohwa sealed">봉인</span>' : ''}${domainChip()}`; })()}
    ${store.env ? `<span class="hs-env">${esc(store.env.phase?.name || '')}·${esc(store.env.weather?.name || '')}</span>` : ''}
    <span class="hs-status st-${first.kind}">${icon(first.icon, 14)}<em data-timer="${first.timer ? new Date(first.timer).getTime() : ''}">${esc(first.title)}</em></span>
    <span class="hs-slots" role="img" aria-label="상태 ${rest.length}/10 · 나쁜 상태 ${badN}개" title="상태 ${rest.length}/10 · 나쁜 상태 ${badN}개">${slots.map(k => `<i class="${k}"></i>`).join('')}</span>
    <span class="hs-caret">${icon('chevron', 14)}</span>`;
  const body = $('#hud-body', root);
  body.innerHTML = `
    <section class="hud-card">
      <div class="hud-id">${emblem(c.owner_id, c.profile, 44)}
        <div><h2>${myName(c)}${gmBadge(c.owner_id)}</h2><p>${esc(nameOf(c.job_key))} · ${esc(nameOf(c.faction_key))}</p></div>
        <span class="lv">Lv.${c.level}</span>${erosionRing(c)}</div>
      <div class="title-row">${c.profile?.title_name ? `<p class="title-badge">「${esc(c.profile.title_name)}」</p>` : ''}<button class="btn small ghost" id="hud-title-swap" title="저장해 둔 칭호 묶음으로 바꿔 낍니다">${icon('refresh', 13)}<span>칭호 바꾸기</span></button></div>
      ${envChip()}
      <div class="xp"><span>경험치${xpPct() < 100 ? ` <i class="xp-damp" data-tip="${esc(xpNote())}">조절 ${xpPct()}%</i>` : ''}</span><span>${(c.level || 1) >= LEVEL_CAP ? '최고 레벨' : `${fmt.num(c.experience)} / ${fmt.num(need)}`}</span></div>${bar((c.level || 1) >= LEVEL_CAP ? 1 : c.experience, (c.level || 1) >= LEVEL_CAP ? 1 : need, 'xp')}
    </section>
    <section class="hud-card vitals">
      ${vital('체력', c.health, 'hp')}${vital('정신', c.mental, 'mp')}${vital(spOf()[0], c.spiritual_power, spOf()[1])}${vital('침식', c.erosion || 0, 'er')}
      ${stamina(c)}
      ${statusCard()}
    </section>
    <section class="hud-card money">
      <div>${icon('coin', 14)}<span>소지금</span><b>${fmt.jeon(c.gil)}</b></div>
      <div>${icon('token', 14)}<span>노정패</span><b>${fmt.num(c.mount_tokens)}개</b></div>
      <div>${icon('bag', 14)}<span>가방</span><b>${bagUsed(c)} / ${bagLimit(c)}칸</b></div>
      <div title="${esc(c.location)}">${icon('pin', 14)}<span>위치</span><b>${esc(c.location)}</b></div>
    </section>
    ${qsCard(c)}
    <section class="hud-card now"><h3>진행 중</h3>
      ${items.map((it, i) => `<div class="now-item st-${it.kind}">
        <div class="now-ico">${icon(it.icon, 18)}</div>
        <div class="now-text"><b>${esc(it.title)}</b><span data-timer="${it.timer ? new Date(it.timer).getTime() : ''}" data-kind="${it.kind}">${esc(it.text)}</span>
          ${it.meter ? bar(it.meter[0], it.meter[1], 'enemy') : ''}</div>
        ${it.action || it.action2 ? `<div class="now-acts">${it.action ? `<button class="btn small ${it.ready ? 'primary' : 'ghost'}" data-act="${i}">${esc(it.action[0])}</button>` : ''}${it.action2 ? `<button class="btn small ghost" data-act2="${i}">${esc(it.action2[0])}</button>` : ''}</div>` : ''}
      </div>`).join('')}
    </section>`;
  const ts = $('#hud-title-swap', body); if (ts) ts.onclick = () => openTitleSwap();
  body.querySelectorAll('[data-hqs]').forEach(b => b.onclick = () => guard(b, () => useItemAct(b.dataset.hqs)));
  body.querySelectorAll('[data-act]').forEach(b => b.onclick = () => items[Number(b.dataset.act)].action[1](b));
  body.querySelectorAll('[data-act2]').forEach(b => b.onclick = () => { closeStrip(); items[Number(b.dataset.act2)].action2[1](b); });
  const sts = yohwaOf(state.hud?.statuses).rest;
  body.querySelectorAll('[data-st]').forEach(b => b.onclick = () => openStatus(sts[Number(b.dataset.st)]));
}
function stamina(c) {
  const st = state.hud?.stamina; if (!st) return '';
  const t = st.next_at ? new Date(st.next_at).getTime() : 0, left = t - Date.now();
  return `<div class="vital st"><span>탐색력</span><b>${st.now}/${st.max}</b>${bar(st.now, st.max, 'st')}<small class="muted" data-timer="${t || ''}" data-kind="stamina">${st.now >= st.max ? '가득' : (t && left > 0 ? `${fmt.remain(left)} 뒤 +1` : '')}</small></div>`;
}
const myName = c => domainNow()?.nameless ? `<span class="name-broken" title="${esc(NAMELESS.mine)}">${esc(brokenName(c.character_name))}</span>` : esc(c.character_name);
export function domainNow() {
  const d = state.hud?.domain;
  if (!d?.name) return null;
  const until = d.guard_until ? new Date(d.guard_until).getTime() : 0, fx = fxText(d.effects);
  const max = d.blur?.strokes || 0, left = d.blur ? (d.strokes_left ?? max) : 0, stage = d.stage || 0;
  return { name: d.stage_name || d.name, guarded: until > Date.now(), off: !fx.length, until, max, left, stage,
    strokes: d.blur ? `이름 획 ${left}/${max}` : '', nameless: !!(stage && d.blur?.stages?.[stage - 1]?.nameless), text: fx.join(' · ') };
}
function domainChip() {
  const d = domainNow();
  return d ? `<span class="hs-yohwa blur s${d.stage}${d.off ? ' off' : ''}" title="${esc([d.name, d.strokes, d.off ? DOMAIN_FX.guardedOff : d.text].filter(Boolean).join(' · '))}">${d.max ? `획 <b>${d.left}/${d.max}</b>` : esc(d.name)}</span>` : '';
}
function domainPin() {
  const d = domainNow(); if (!d) return '';
  return `<a class="yohwa-pin blur s${d.stage}${d.off ? ' off' : ''}" href="#/char/status" data-tip="${esc(`${DOMAIN_FX.note} ${DOMAIN_FX.blur} ${DOMAIN_FX.guard}`)}">${icon('mask', 14)}<span><b>${esc(d.name)}${d.max ? ` <em class="nb-n">${esc(d.strokes)}</em>` : ''}</b><small>${esc(d.off ? DOMAIN_FX.guardedOff : d.text)}${d.guarded ? ` · ${esc(d.off ? '' : DOMAIN_FX.guarded)} <i data-timer="${d.until}" data-kind="status">${fmt.remain(d.until - Date.now())}</i>` : ''}</small></span></a>`;
}
function statusCard() {
  const yo = yohwaOf(state.hud?.statuses), list = yo.rest, yl = yohwaLine(yo);
  return `<div class="statuses"><h3>상태 ${list.length}/10</h3>${domainPin()}${yl ? `<a class="yohwa-pin ${yl.cls}" href="#/char/status">${icon(yo.seal ? 'shield' : 'mask', 14)}<span><b>${esc(yl.title)}</b><small>${esc(yo.seal ? '해독 끝까지' : yl.text)} <i data-timer="${new Date(yl.until).getTime()}" data-kind="status">${fmt.remain(new Date(yl.until) - Date.now())}</i></small></span></a>` : ''}${list.length ? `<div class="st-chips">${list.map((s, i) => `<button class="st-chip ${s.polarity === 'positive' ? 'good' : 'bad'}" data-st="${i}">
      <b>${esc(s.name)}${s.stacks > 1 ? `×${s.stacks}` : ''}</b><i data-timer="${new Date(s.expires_at).getTime()}" data-kind="status">${fmt.remain(new Date(s.expires_at) - Date.now())}</i></button>`).join('')}</div>`
    : ''}</div>`;
}
export const YOHWA_STAGES = ['', '요기 스밈', '요문 발현', '반요'];
export const PINNED = new Set(['yohwa', 'yohwa_seal', 'yohwa_frenzy']);
export function yohwaOf(statuses) {
  const now = new Date(), live = (statuses || []).filter(s => new Date(s.expires_at) > now || s.key === 'yohwa');
  const y = live.find(s => s.key === 'yohwa'), seal = live.find(s => s.key === 'yohwa_seal');
  const fr = y ? live.find(s => s.key === 'yohwa_frenzy' && new Date(s.expires_at) > now) : null;
  return { y, seal, fr, stage: y ? Math.max(1, Math.min(3, Number(y.potency || 1))) : 0, rest: live.filter(s => !PINNED.has(s.key) && new Date(s.expires_at) > now) };
}
export const yohwaDownNow = c => yohwaDowned(c, yohwaOf(state.hud?.statuses));
export function yohwaDowned(c, yo) {
  const e = Number(yo?.y?.metadata?.down_epoch || 0);
  return !!(e && c?.downed_at && Math.abs(new Date(c.downed_at).getTime() / 1000 - e) < 1);
}
export function yohwaLine(st) {
  if (st.seal) return { cls: 'sealed', title: '봉인 해독 중', text: '안전지대 봉인술사들이 요기를 걷어내고 있습니다. 끝날 때까지 채팅만 할 수 있습니다.', until: st.seal.expires_at };
  if (st.fr) return { cls: 's3 frenzy', title: '요괴화', text: '요괴의 힘이 몸을 차지했습니다 · 쓰러지기까지', until: st.fr.expires_at };
  if (st.y) return { cls: `s${st.stage}`, title: `요화: ${st.stage}단계 ${YOHWA_STAGES[st.stage]}`, text: st.stage < 3 ? '다음 단계까지' : '쓰러지기까지', until: st.y.expires_at };
  return null;
}
function erosionRing(c, cls = '') {
  const v = Math.max(0, Math.min(100, Math.round(Number(c?.erosion || 0))));
  const st = v >= 80 ? ['s3', '붕괴 직전'] : v >= 55 ? ['s2', '위험'] : v >= 30 ? ['s1', '주의'] : ['s0', '안정'];
  const tag = cls === 'mini' ? 'span' : 'a', d = domainNow();
  const blur = d?.max ? `<g class="nb s${d.stage}">${Array.from({ length: d.max }, (_, i) => `<circle class="${i < d.left ? 'on' : ''}" cx="22" cy="22" r="20.4" pathLength="${d.max * 10}" stroke-dasharray="7.5 ${d.max * 10 - 7.5}" stroke-dashoffset="${-i * 10 - 1.25}"/>`).join('')}</g>` : '';
  const tip = `침식 ${v} · ${st[1]}${d?.max ? ` · ${d.name} · ${d.strokes}` : ''}`;
  return `<${tag} class="er-ring ${st[0]} ${cls}${blur ? ' has-nb' : ''}" ${tag === 'a' ? 'href="#/char/status"' : ''} title="${esc(tip)}" aria-label="${esc(tip)}">
    <svg viewBox="${blur ? '0 0 44 44' : '0 0 36 36'}" aria-hidden="true"><g transform="translate(${blur ? 4 : 0} ${blur ? 4 : 0})"><circle class="t" cx="18" cy="18" r="15.9"/><circle class="v" cx="18" cy="18" r="15.9" stroke-dasharray="${v} 100" pathLength="100"/></g>${blur}</svg></${tag}>`;
}
function vital(label, v, kind) {
  return `<div class="vital"><span>${label}</span><b>${Math.round(v || 0)}</b>${bar(v, 100, kind)}</div>`;
}

let arriving = false, lastArriveTry = 0;
let staminaDue = false, statusDue = false, tickedRound = -1, tickedExp = null;
function onTick() {
  if (!root) return;
  const now = Date.now();
  if (staminaDue) { staminaDue = false; if (bumpStamina()) render(); }
  if (statusDue) { statusDue = false; render(); }
  root.querySelectorAll('[data-timer]').forEach(el => {
    const t = Number(el.dataset.timer); if (!t) return;
    const left = t - now, kind = el.dataset.kind;
    if (el.tagName === 'EM') return;
    if (kind === 'travel') el.textContent = left > 0 ? `${fmt.remain(left)} 후 도착` : '도착 처리 중…';
    if (kind === 'busy') el.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '곧 끝납니다';
    if (kind === 'idle') el.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '완료 · 보상 수령 가능';
    if (kind === 'exp') el.textContent = left > 0 ? `${fmt.remain(left)} 남음` : '귀환 · 결과 확인 가능';
    if (kind === 'danger') el.textContent = left > 0 ? `목숨이 다하기까지 ${fmt.remain(left)}` : '시간이 다했습니다';
    if (kind === 'status') { el.textContent = left > 0 ? fmt.remain(left) : '끝'; if (left <= 0) statusDue = true; }
    if (kind === 'stamina') { el.textContent = left > 0 ? `${fmt.remain(left)} 뒤 +1` : ''; if (left <= 0) staminaDue = true; }
  });
  const c = store.character;
  if (c?.travel_arrives_at && new Date(c.travel_arrives_at).getTime() <= now && !arriving && now - lastArriveTry > 5000) {
    arriving = true; lastArriveTry = now;
    let where = null;
    rpc('world_travel_status').then(s => { if (!s?.in_transit) where = s.location; return refresh(); })
      .catch(() => {}).finally(() => { arriving = false; if (where) window.dispatchEvent(new CustomEvent('yahang:arrived', { detail: { location: where } })); });
  }
  const ready = idleReadyAt(state.idle);
  if (ready && ready <= now && !root.dataset.idleReady) { root.dataset.idleReady = '1'; render(); }
  const expEnd = state.exp?.ends_at ? new Date(state.exp.ends_at).getTime() : 0;
  if (expEnd && expEnd <= now && root.dataset.expDone !== String(expEnd)) {
    root.dataset.expDone = String(expEnd);
    render(); emit('expedition', state.exp);
    const seen = `yh-exp-done-${c?.owner_id}-${expEnd}`;
    let shown = false; try { shown = !!localStorage.getItem(seen); localStorage.setItem(seen, '1'); } catch {}
    if (!shown) window.dispatchEvent(new CustomEvent('yh-local-note', { detail: { id: `exp-${expEnd}`, kind: 'expedition_done', title: '원정 귀환',
      content: `${state.exp.place_name || '원정지'}에서 돌아왔습니다. 결과를 받아 보세요.` } }));
  }
  if (!ready) delete root.dataset.idleReady;
}

async function cancelTravel(btn) {
  if (!(await ask('이동을 취소할까요? 취소하면 3분 동안 다시 출발할 수 없습니다. 출발할 때 낸 운임은 돌려받지 못합니다.', { title: '이동 취소', ok: '취소하기', cancel: '계속 가기', danger: true }))) return;
  await guard(btn, () => act('world_travel_cancel'));
}
async function claimIdle(btn) {
  await guard(btn, async () => {
    const r = await act('world_claim_idle_activity');
    return { content: `${r.message || '보상 수령'} · 경험치 +${xpGot(r.experience)}` };
  });
}

async function openTitleSwap() {
  const m = openModal({ title: '칭호 바꾸기', body: '<div class="t-swap"><p class="muted small">읽는 중…</p></div>' });
  const box = $('.t-swap', m);
  try {
    invalidate('world_title_snapshot'); const snap = await load('world_title_snapshot');
    const list = snap?.titles || [], nm = Object.fromEntries(list.map(t => [t.key, t.name]));
    const ps = (snap?.presets || []).slice().sort((a, b) => a.slot - b.slot);
    box.innerHTML = ps.length ? `<ul class="spot-list">${ps.map(p => {
      const now = presetNow(p, list);
      return `<li><div><b>${esc(p.name || `묶음 ${p.slot}`)}</b><small>${(p.titles || []).filter(k => nm[k]).map(k => esc(nm[k])).join(' · ') || '장착 없음'}</small></div>
        <button class="btn small ${now ? '' : 'primary'}" data-tsw="${p.slot}" ${now ? 'disabled' : ''}>${now ? '쓰는 중' : '바꿔 끼기'}</button></li>`; }).join('')}</ul>`
      : '<p class="muted small">저장한 칭호 묶음이 없습니다. 캐릭터 › 칭호 위의 묶음 칸에 지금 장착한 칭호를 저장해 두세요.</p>';
    box.insertAdjacentHTML('beforeend', '<p class="muted small"><a href="#/char/titles" data-tsw-go>칭호 화면에서 묶음 고치기</a></p>');
    $('[data-tsw-go]', box).onclick = () => closeModal();
    $$('[data-tsw]', box).forEach(b => b.onclick = () => guard(b, async () => { const r = await act('world_title_preset_apply', { p_slot: Number(b.dataset.tsw) }); closeModal(); return r; }));
  } catch (e) { box.innerHTML = `<p class="bad small">${esc(e.message)}</p>`; }
}
