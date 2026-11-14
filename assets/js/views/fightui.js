import { esc, icon, fmt, nameOf, JOBS, brief, $, $$, emit, loadCharacter, openLayer, spOf, scrollAfterModal, ask, store } from '../core.js';
import { itemDesc, catItem, catalogList, load } from './common.js';
import { USABLE, fxHtml } from './item.js';
import { baseOf, isHq, haveOf } from '../hq.js';
import { GAMEDATA as GD } from '../gamedata.js';
import { weakNote } from './battle.js';
const SURE = GD.coopRules?.sure_crit || 2;

export const FX_NAME = { ward: '결계', might: '기세', crit: '약점', crit_next: '급소', critnext: '급소', evade: '피할 길', shield: '보호막', cover: '보호받음', gward: '진언', taunt: '철벽', guard: '방어', bound: '사슬',
  expose: '약점 드러남', stagger: '휘청임', smoke: '연막', break: '퇴마 결계', block: '손길 묶임' };
export const FX_ICON = { ward: 'ward', might: 'bolt', crit: 'crosshair', crit_next: 'vital', critnext: 'vital', evade: 'dodge', shield: 'bubble', cover: 'hand', gward: 'talisman', taunt: 'star', guard: 'shield', bound: 'chain',
  expose: 'crosshair', stagger: 'spiral', smoke: 'fog', break: 'ward', block: 'hand' };
export const FX_TIP = { ward: '받는 피해가 줄어든다(정해진 횟수 동안).', might: '주는 피해가 늘어난다(정해진 횟수 동안).', crit: '치명타가 더 잘 터진다.', crit_next: `다음 공격이 반드시 치명타로 들어가고, 치명타 피해가 ${SURE}배가 된다.`, critnext: `다음 공격이 반드시 치명타로 들어가고, 치명타 피해가 ${SURE}배가 된다.`,
  evade: '요괴의 공격을 피할 확률이 오른다.', shield: '받는 피해를 먼저 막아 주는 보호막.', cover: '잠깐 동안 동료가 대신 맞아 준다.', gward: '다음에 받는 공격 한 번의 피해를 절반으로 줄이고 정신을 지킨다.',
  taunt: '요괴의 눈길을 끌어 대신 맞고, 받는 피해가 줄어든다.', guard: '방어 태세 — 다음 공격의 피해가 줄어든다.', bound: '사슬에 묶여 다음 공격의 피해가 절반이 된다.',
  expose: '요괴가 받는 피해가 늘어난다.', stagger: '요괴가 휘청여 반격하지 못한다.', smoke: '연막 속에서 요괴의 공격이 빗나갈 수 있다.', break: '다음 광역·기운 터뜨림의 피해가 줄어든다.', block: '손길이 묶여 반격하지 못한다.' };
export const SKILL_ICON = { art_mend: 'vital', art_supply: 'crosshair', art_shield: 'dodge', art_array: 'bolt', an_share: 'eye', an_point: 'vital', an_break: 'hourglass', an_command: 'bolt',
  exo_cover: 'hand', exo_mantra: 'talisman', exo_barrier: 'ward', exo_guardian: 'star', med_aid: 'heart', med_needle: 'needle', med_revive: 'refresh', med_pulse: 'heart',
  sc_mark: 'crosshair', sc_path: 'dodge', sc_smoke: 'fog', sc_signal: 'flag', seal_ward: 'ward', seal_might: 'bolt', seal_chain: 'chain', seal_bagua: 'shield' };

const BAD = new Set(['bound']);
const tipOf = k => `${FX_NAME[k]} — ${FX_TIP[k] || ''}`;
export const fxKeys = keys => (keys || []).filter(k => FX_NAME[k]);
export const fxIcons = keys => fxKeys(keys).map(k => `<i class="fx-i ${BAD.has(k) ? 'bad' : ''}" data-tip="${esc(tipOf(k))}" aria-label="${esc(FX_NAME[k])}">${icon(FX_ICON[k] || 'spark', 12)}</i>`).join('');
export const fxChip = (k, kind = 'ok') => `<span class="chip fx-chip ${BAD.has(k) ? 'bad' : kind}" data-tip="${esc(tipOf(k))}">${icon(FX_ICON[k] || 'spark', 12)}${esc(FX_NAME[k])}</span>`;
export const fxChips = (keys, kind) => fxKeys(keys).map(k => fxChip(k, kind)).join('');

export { bindTips, hideTip } from '../tips.js';

export const jobName = j => JOBS[j]?.name || nameOf(j);
const hpBar = (hp, label = hp, big = false) => `<span class="bar mem-hp ${big ? 'big' : ''} ${hp < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, Number(hp) || 0))}%"></span><em>${label}</em></span>`;
export function memberLi(m, o = {}) {
  return `<li class="jb-${esc(m.job || '')} ${o.cls || ''} ${o.me ? 'me' : ''} ${o.tgt ? 'tgt' : ''} ${o.sel ? 'sel' : ''} ${o.out ? 'out' : ''} ${o.turn ? 'turn' : ''}">
    <button type="button" class="mem-pick" data-pick="${esc(m.id)}" title="${esc(o.title || `${m.name} · ${m.level ? `Lv${m.level} ` : ''}${jobName(m.job)}`)}">
      <span class="mem-top"><b>${o.pre || ''}${esc(m.name)}<span class="fx-icons">${fxIcons(o.fx)}</span></b>${o.state ? `<small>${esc(o.state)}</small>` : ''}</span>
      ${hpBar(o.hp ?? m.hp)}
      <small class="mem-sub">${o.sub ?? esc(jobName(m.job))}</small></button></li>`;
}
export function memDetailHtml(m, o = {}) {
  const fx = fxKeys(o.fx);
  return `<div class="md-head"><b>${esc(m.name)}</b><span>${m.level ? `Lv${m.level} ` : ''}${esc(jobName(m.job))}</span><small>${esc(o.state || '')}</small>
      <button type="button" class="md-x" data-md-close aria-label="닫기">${icon('close', 14)}</button></div>
    ${hpBar(o.hp ?? m.hp, `체력 ${o.hp ?? m.hp} / 100`, true)}
    <div class="md-nums">${(o.nums || []).map(([k, v]) => `<span>${esc(k)} <b>${v}</b></span>`).join('')}</div>
    <div class="md-fx">${fx.length ? fx.map(k => fxChip(k)).join('') : '<small class="muted">걸린 효과 없음</small>'}</div>${o.extra || ''}`;
}
export function showMemDetail(box, m, o, onClose) {
  if (!box) return;
  if (!m) { box.hidden = true; box.innerHTML = ''; return; }
  box.hidden = false; box.className = `mem-detail jb-${m.job || ''}`;
  box.innerHTML = memDetailHtml(m, o);
  const x = box.querySelector('[data-md-close]'); if (x) x.onclick = onClose;
}
export function showSelected(box, list, sel, opts, onClose) {
  const m = (list || []).find(x => x.id === sel);
  showMemDetail(box, m, m && opts(m), onClose);
}
export const fightNums = m => [['준 피해', fmt.num(m.dmg || 0)], ['받은 피해', fmt.num(m.taken || 0)], ['회복', fmt.num(m.heal || 0)]];

export const ammoHtml = a => a ? `<div class="raid-ammo ${Number(a.n) > 0 ? (Number(a.n) <= 10 ? 'low' : '') : 'out'}" title="남은 ${esc(nameOf(a.id))} · 다 떨어지면 공격 피해가 절반으로 줄어듭니다"><span>${esc(nameOf(a.id))}</span><b>${fmt.num(a.n ?? 0)}</b></div>` : '';
export const ammoWarn = a => { if (a && !(Number(a.n) > 0)) weakNote('ammo'); };
export const vitHtml = (label, v, kind, low = false) => `<div class="raid-vit ${kind} ${low ? 'low' : ''}"><span>${esc(label)}</span><b>${fmt.num(v ?? 0)}</b><i class="bar"><i style="width:${Math.max(0, Math.min(100, Number(v) || 0))}%"></i></i></div>`;

export const coopBtn = (k, data = '') => `<button type="button" class="coop-btn ${!k.unlocked ? 'locked' : ''} ${k.on ? 'on' : ''}" ${data} ${k.why ? 'data-lock="1" disabled' : ''} title="${esc(k.desc || '')}">
  <b>${icon(SKILL_ICON[k.id] || 'spark', 13)}<span class="cb-n">${esc(k.name)}</span></b><small>${esc(k.why || `${spOf()[0]} ${k.cost}`)}${k.target === 'ally' ? ' · 동료' : k.target === 'all' ? ' · 모두' : k.target === 'boss' ? ' · 요괴' : ''}</small></button>`;

export const isSpItem = k => { const f = catItem(baseOf(k))?.fx; return !!f && f.sp > 0 && !(f.hp > 0) && !(f.mn > 0); };
export const battleItems = () => (catalogList() || []).filter(i => !isHq(i.id) && i.fx && (i.fx.hp > 0 || i.fx.mn > 0 || i.fx.sp > 0)).map(i => i.id);
export const fxOf = k => fxHtml(String(USABLE[baseOf(k)] || '').split(' · ').filter(x => /^(체력|정신|영력|침식)|치료|풀기/.test(x.trim())).join(' · ') || brief(itemDesc(k)) || '');
export const itemListHtml = (ids, inv, on = '') => ids.length ? `<ul class="raid-item-list">${ids.map(k => `<li><button type="button" class="raid-item ${on === k ? 'on' : ''}" data-use="${esc(k)}" title="${esc(brief(itemDesc(k)) || '')}"><b>${esc(nameOf(k))}</b><span>×${fmt.num(inv[k] || 0)}</span><small>${fxOf(k)}</small></button></li>`).join('')}</ul>` : '<p class="muted small">가방에 없습니다.</p>';
export function itemGroups(list, inv) {
  const have = l => haveOf(l, inv);
  return [have(list.filter(k => !isSpItem(k))), have(list.filter(k => isSpItem(k)))];
}
export function itemSectionsHtml(list, inv, hpTitle = '체력·정신 회복') {
  const [hp, sp] = itemGroups(list, inv);
  return `<h3 class="raid-item-h">${esc(hpTitle)}</h3>${itemListHtml(hp, inv)}<h3 class="raid-item-h">${esc(spOf()[0])} 회복</h3>${itemListHtml(sp, inv)}`;
}
export function itemTray({ title, bodyId, fill }) {
  let layer = null;
  const refill = () => { const box = layer && $(`#${CSS.escape(bodyId)}`, layer); if (box) fill(box); };
  return {
    open() {
      if (layer?.isConnected) return;
      layer = openLayer({ title, body: `<div id="${bodyId}"></div>` });
      refill();
      if (!itemDesc('tonic')) load('world_inventory_snapshot').then(refill).catch(() => {});
    },
    refill,
    redraw() { if (layer?.isConnected) refill(); },
    close() { layer?.close?.(); layer = null; },
  };
}

export const resultBox = (ok, title, body = '') => `<div class="raid-result ${ok ? 'ok' : 'bad'}"><b>${title}</b>
    ${body}</div>`;
export function showResult(root) {
  const box = root && $('.raid-result', root); if (!box) return;
  const head = Math.max(56, ...[...document.querySelectorAll('header, aside.hud, .app-header')].filter(x => /sticky|fixed/.test(getComputedStyle(x).position) && x.getBoundingClientRect().top < 160 && x.getBoundingClientRect().bottom < innerHeight / 2).map(x => x.getBoundingClientRect().bottom));
  scrollAfterModal(Math.max(0, Math.round(window.scrollY + box.getBoundingClientRect().top - head - 8)), true);
}
export function soloAidHtml(dmg, guard, falls) {
  const pct = v => `${v > 0 ? '+' : '−'}${Math.abs(v)}%`, parts = [];
  if (Number(dmg)) parts.push(`주는 피해 ${pct(Number(dmg))}`);
  if (Number(guard)) parts.push(`받는 피해 ${pct(-Number(guard))}`);
  if (Number(falls)) parts.push(`쓰러짐 ${Number(falls) > 0 ? '+' : '−'}${Math.abs(Number(falls))}`);
  return parts.length ? `<p class="solo-aid" title="혼자 도전할 때만 붙는 직업 보정">혼자 도전 보정 · ${parts.join(' · ')}</p>` : '';
}
export async function reloadCharacter() { try { await loadCharacter(); } catch {} }
export async function settleFight(name, before) { await reloadCharacter(); before?.(); emit('changed', { name }); }

export const untilText = (t, now = Date.now(), sec = false) => { const ms = new Date(t) - now; return ms > 0 ? (sec ? `${Math.ceil(ms / 1000)}초` : fmt.remain(ms)) : '곧'; };
export function tickUntil(root, now = Date.now(), sec = false) { $$('[data-until]', root).forEach(x => { x.textContent = untilText(x.dataset.until, now, sec || !!x.dataset.sec); }); }
export function serverClock() {
  let skew = 0;
  return { now: () => Date.now() + skew, sync(o) { if (o?.now) skew = new Date(o.now).getTime() - Date.now(); } };
}

export const mobileLog = () => window.matchMedia('(max-width: 640px)').matches;
export const newestFirst = (list, top) => top ? [...list].reverse() : list;
export const atLogEdge = (log, top) => top ? log.scrollTop < 24 : log.scrollHeight - log.scrollTop - log.clientHeight < 24;
export function keepLogScroll(root, top) {
  const old = $('.raid-log', root), edge = !old || atLogEdge(old, top), y = old?.scrollTop || 0;
  return () => { const log = $('.raid-log', root); if (log) log.scrollTop = edge ? (top ? 0 : log.scrollHeight) : y; };
}
export const logRow = (cls, body, pre = '') => `<li class="${cls}">${pre}<span>${body}</span></li>`;
export function fitLog(log) {
  if (!log) return;
  if (!mobileLog()) { log.style.height = ''; return; }
  const vis = q => { const e = document.querySelector(q); return e && !e.hidden && getComputedStyle(e).display !== 'none' && e.getClientRects().length ? e.getBoundingClientRect().top : window.innerHeight; };
  const stop = Math.min(vis('.tabbar'), vis('#chat-fab'));
  const top = log.getBoundingClientRect().top, pad = 14;
  log.style.height = Math.max(92, Math.floor(stop - top - pad)) + 'px';
  const over = document.documentElement.scrollHeight - window.innerHeight;
  if (over > 0 && window.scrollY < 4) log.style.height = Math.max(92, log.offsetHeight - over) + 'px';
}

export const fightCol = (side, html) => `<div class="fight-col fight-col-${side}">${html}</div>`;
let fitRoot = null, fitRO = null, fitT = null;
function fitNow() {
  const wrap = fitRoot?.isConnected && fitRoot.querySelector('.raid-wrap.playing');
  if (!wrap) return;
  if (mobileLog() || !window.matchMedia('(min-width: 900px)').matches) { wrap.style.removeProperty('--fit-h'); return; }
  const top = wrap.getBoundingClientRect().top + window.scrollY;
  wrap.style.setProperty('--fit-h', Math.max(360, Math.floor(window.innerHeight - top - 12)) + 'px');
}
const fitSoon = () => { clearTimeout(fitT); fitT = setTimeout(fitNow, 120); };
window.addEventListener('resize', fitSoon);
export function fitFight(root) {
  fitRoot = root; fitNow();
  fitRO?.disconnect(); fitRO = null;
  if (!root || !window.ResizeObserver) return;
  fitRO = new ResizeObserver(fitSoon);
  for (const e of root.querySelectorAll('.raid-wrap.playing > .fight-col > section:not(.raid-log-box), :scope > .view-head')) fitRO.observe(e);
}
export function unfitFight() { fitRO?.disconnect(); fitRO = null; fitRoot = null; clearTimeout(fitT); }

const BOSS_ASK = {
  final: {
    tail: '결전은 20분 동안 이어지고, 체력이 다하면 30초씩 물러납니다. 모두 물러나 있는 동안 구중 봉주가 기운을 되찾습니다.\n싸우는 동안에는 이동·탐색을 할 수 없고, 결전 화면의 「포기하고 나오기」로만 먼저 나올 수 있습니다.',
    1: ['혼자서 결전을 엽니까?', '혼자서는 거의 이길 수 없습니다.\n구중 봉주는 넷이 함께 맞서도록 만든 최종 보스입니다.', '그래도 혼자 시작'],
    2: '둘이서는 어렵지만 해볼 만한 싸움입니다. 회복품을 넉넉히 챙기고, 한 사람이 막는 동안 다른 사람이 몰아치세요.',
    3: '셋이면 해볼 만한 싸움입니다. 막는 사람·치는 사람·돌보는 사람으로 나누면 한결 수월합니다.',
    4: '넷이 함께하는 것이 이 결전에 가장 알맞은 인원입니다.',
    call: n => `같은 곳의 파티원 ${n - 1}명에게 합류 알림이 갑니다(90초 안에 합류, 함께 ${n}명).`, ok: '결전 시작', name: '결전',
  },
  gw: {
    tail: '싸움은 15분 동안 라운드마다 행동 하나를 고릅니다. 지면 장착 장비 내구도가 10% 깎이고 침식이 10 오르며, 30분 뒤에야 다시 도전할 수 있습니다. 모두 귀허 부적을 하나씩 씁니다.',
    1: ['혼자서 귀허의 주인 앞에 섭니까?', '혼자서는 열 번에 두세 번 이기는 싸움입니다.\n직업에 맞춘 「혼자 도전 보정」이 붙고 쓰러져도 열 번까지 다시 일어나지만, 정석대로 싸워도 쉽지 않습니다.', '그래도 혼자 서기'],
    2: '둘이서는 열 번에 다섯 번쯤 이기는 싸움입니다. 한 사람이 버티는 동안 다른 사람이 수법을 끊어 주세요.',
    3: '셋이면 한결 수월합니다. 버티는 사람·치는 사람·돌보는 사람으로 나누세요.',
    4: '넷이 함께하는 것이 귀허의 주인에게 가장 알맞은 인원입니다.',
    call: n => `같은 곳의 파티원 ${n - 1}명에게 합류 알림이 갑니다(60초 안에 합류, 함께 ${n}명).`, ok: '귀허의 주인 앞에 서기', name: '도전',
  },
};
export async function partyHere() {
  const p = await load('world_party_overview', undefined, { maxAge: 30000 }).catch(() => null);
  const here = store.character?.location, me = store.user?.id;
  return 1 + Math.min(3, (p?.party ? p.members || [] : []).filter(m => m.owner_id !== me && m.location === here && !m.downed && !m.expedition).length);
}
export function askPartySize(kind, n, begin = false) {
  const b = BOSS_ASK[kind]; n = Math.max(1, Math.min(4, n));
  if (n === 1) { const [title, head, ok] = b[1]; return ask(`${head}\n${b.tail}\n파티원을 모아 함께 오기를 강하게 권합니다.`, { title, ok, cancel: '돌아가기', alarm: true }); }
  return ask(`${begin ? `지금 모인 ${n}명으로 시작합니다. 아직 오지 않은 파티원은 함께하지 못합니다.` : b.call(n)}\n${b[n]}\n${b.tail}`, { title: `${n}명이 함께 ${b.name}을 시작합니까?`, ok: b.ok, cancel: '돌아가기' });
}
