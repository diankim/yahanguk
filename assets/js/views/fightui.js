// 파티 전투 화면 공용 부품: 봉연 토벌 화면을 기준으로 합동 토벌(raid.js)·파티 토벌(pfight.js)·귀허의 주인(gw.js)이 함께 쓴다.
// 북돋기·약화 아이콘과 떠 있는 짧은 설명, 직업 색 참가자 칸·자세히 칸, 내 체력·영력 막대, 협동 기술 아이콘,
// 물품 창(겹쳐 뜨는 창·목록), 결과 칸, 전투 기록 줄·스크롤, 남은 시간 글, 정산 뒤 캐릭터 다시 읽기.
// 새 효과·기술을 넣으면 FX_NAME·FX_ICON·FX_TIP·SKILL_ICON에 함께 더한다.
import { esc, icon, fmt, nameOf, JOBS, brief, $, $$, emit, loadCharacter, openLayer, spOf, scrollAfterModal } from '../core.js';
import { itemDesc, catItem, catalogList, load } from './common.js';
import { USABLE, fxHtml } from './item.js';

// 효과 이름: 봉연(world_raid_members.fx)과 귀허(world_gw_members.fx·world_gw_fights.bfx)의 키를 한 표로
export const FX_NAME = { ward: '결계', might: '기세', crit: '약점', crit_next: '급소', critnext: '급소', evade: '피할 길', shield: '보호막', cover: '보호받음', gward: '진언', taunt: '철벽', guard: '방어', bound: '사슬',
  expose: '약점 드러남', stagger: '휘청임', smoke: '연막', break: '퇴마 결계', block: '손길 묶임' };
export const FX_ICON = { ward: 'ward', might: 'bolt', crit: 'crosshair', crit_next: 'vital', critnext: 'vital', evade: 'dodge', shield: 'bubble', cover: 'hand', gward: 'talisman', taunt: 'star', guard: 'shield', bound: 'chain',
  expose: 'crosshair', stagger: 'spiral', smoke: 'fog', break: 'ward', block: 'hand' };
export const FX_TIP = { ward: '받는 피해가 줄어든다(정해진 횟수 동안).', might: '주는 피해가 늘어난다(정해진 횟수 동안).', crit: '치명타가 더 잘 터진다.', crit_next: '다음 공격이 반드시 치명타로 들어간다.', critnext: '다음 공격이 반드시 치명타로 들어간다.',
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

// 떠 있는 짧은 설명: 마우스를 올린 동안(휴대폰은 누르면 1.8초) — 창을 띄우지 않는다
let tipEl = null, tipTimer = 0;
function showTip(t) {
  if (!tipEl) { tipEl = document.createElement('div'); tipEl.className = 'fx-tip'; tipEl.setAttribute('role', 'tooltip'); document.body.appendChild(tipEl); }
  tipEl.textContent = t.dataset.tip; tipEl.hidden = false;
  const r = t.getBoundingClientRect(), w = tipEl.offsetWidth, h = tipEl.offsetHeight;
  const x = Math.max(8, Math.min(window.innerWidth - w - 8, r.left + r.width / 2 - w / 2));
  const y = r.top - h - 6 >= 8 ? r.top - h - 6 : r.bottom + 6;
  tipEl.style.left = `${x}px`; tipEl.style.top = `${y}px`;
}
export function hideTip() { clearTimeout(tipTimer); if (tipEl) tipEl.hidden = true; }
export function bindTips(root) {
  if (!root || root.dataset.tips) return; root.dataset.tips = '1';
  root.addEventListener('mouseover', e => { const t = e.target.closest?.('[data-tip]'); if (t && root.contains(t)) showTip(t); });
  root.addEventListener('mouseout', e => { const t = e.target.closest?.('[data-tip]'); if (t && !t.contains(e.relatedTarget)) hideTip(); });
  root.addEventListener('click', e => { const t = e.target.closest?.('[data-tip]'); if (!t) return; e.stopPropagation(); e.preventDefault(); showTip(t); clearTimeout(tipTimer); tipTimer = setTimeout(hideTip, 1800); }, true);
  window.addEventListener('scroll', hideTip, { passive: true, capture: true });
}

export const jobName = j => JOBS[j]?.name || nameOf(j);
const hpBar = (hp, label = hp, big = false) => `<span class="bar mem-hp ${big ? 'big' : ''} ${hp < 35 ? 'low' : ''}"><span style="width:${Math.max(0, Math.min(100, Number(hp) || 0))}%"></span><em>${label}</em></span>`;
// 참가자 칸 하나. o: { cls(더 붙일 칸 이름), hp, me, tgt, sel, out(흑백·점선), turn, state(이름 오른쪽 작은 글), pre(이름 앞), sub(아래 줄 글), fx(효과 키), title, pickable }
export function memberLi(m, o = {}) {
  return `<li class="jb-${esc(m.job || '')} ${o.cls || ''} ${o.me ? 'me' : ''} ${o.tgt ? 'tgt' : ''} ${o.sel ? 'sel' : ''} ${o.out ? 'out' : ''} ${o.turn ? 'turn' : ''}">
    <button type="button" class="mem-pick" data-pick="${esc(m.id)}" title="${esc(o.title || `${m.name} · ${m.level ? `Lv${m.level} ` : ''}${jobName(m.job)}`)}">
      <span class="mem-top"><b>${o.pre || ''}${esc(m.name)}<span class="fx-icons">${fxIcons(o.fx)}</span></b>${o.state ? `<small>${esc(o.state)}</small>` : ''}</span>
      ${hpBar(o.hp ?? m.hp)}
      <small class="mem-sub">${o.sub ?? esc(jobName(m.job))}</small></button></li>`;
}
// 고른 참가자 자세히(같은 칸 #…memdetail에). o: { state, nums: [[이름, 값]], fx, extra(html) }
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
// 참가자 목록에서 고른 사람(sel)을 찾아 자세히 칸에 그린다. opts(m)이 state·nums·fx·extra를 돌려준다(없으면 칸을 닫음)
export function showSelected(box, list, sel, opts, onClose) {
  const m = (list || []).find(x => x.id === sel);
  showMemDetail(box, m, m && opts(m), onClose);
}
// 자세히 칸의 공통 수치: 준 피해·받은 피해·회복(서버가 센 참가자 줄 값)
export const fightNums = m => [['준 피해', fmt.num(m.dmg || 0)], ['받은 피해', fmt.num(m.taken || 0)], ['회복', fmt.num(m.heal || 0)]];

// 내 체력·영력(기력)·정신 막대
export const vitHtml = (label, v, kind, low = false) => `<div class="raid-vit ${kind} ${low ? 'low' : ''}"><span>${esc(label)}</span><b>${fmt.num(v ?? 0)}</b><i class="bar"><i style="width:${Math.max(0, Math.min(100, Number(v) || 0))}%"></i></i></div>`;

// 협동 기술 단추(봉연 모양). k: { id, name, desc, cost, target, unlocked, rank, why(못 쓰는 까닭, 있으면 막음), on }
export const coopBtn = (k, data = '') => `<button type="button" class="coop-btn ${!k.unlocked ? 'locked' : ''} ${k.on ? 'on' : ''}" ${data} ${k.why ? 'data-lock="1" disabled' : ''} title="${esc(k.desc || '')}">
  <b>${icon(SKILL_ICON[k.id] || 'spark', 13)}<span class="cb-n">${esc(k.name)}</span></b><small>${esc(k.why || `${spOf()[0]} ${k.cost}`)}${k.target === 'ally' ? ' · 동료' : k.target === 'all' ? ' · 모두' : k.target === 'boss' ? ' · 요괴' : ''}</small></button>`;

/* ── 물품 창 ─────────────────────────────────────────────── */
// 목록은 이름·남은 수·회복 수치만, 짧은 설명은 title.
// 영력·기력만 채우는 물품인지는 물품 목록의 서버 효과(use_fx)로 가른다 — 새 물품도 저절로 영력 칸에 들어간다
export const isSpItem = k => { const f = catItem(String(k).replace(/_hq$/, ''))?.fx; return !!f && f.sp > 0 && !(f.hp > 0) && !(f.mn > 0); };
// 토벌에서 쓸 수 있는 회복 물품: 체력·정신·영력을 채우는 모든 소모품(우수품은 itemGroups가 더함)
export const battleItems = () => (catalogList() || []).filter(i => !String(i.id).endsWith('_hq') && i.fx && (i.fx.hp > 0 || i.fx.mn > 0 || i.fx.sp > 0)).map(i => i.id);
export const fxOf = k => fxHtml(String(USABLE[k.replace(/_hq$/, '')] || '').split(' · ').filter(x => /^(체력|정신|영력|침식)|치료|풀기/.test(x.trim())).join(' · ') || brief(itemDesc(k)) || '');
export const itemListHtml = (ids, inv, on = '') => ids.length ? `<ul class="raid-item-list">${ids.map(k => `<li><button type="button" class="raid-item ${on === k ? 'on' : ''}" data-use="${esc(k)}" title="${esc(brief(itemDesc(k)) || '')}"><b>${esc(nameOf(k))}</b><span>×${fmt.num(inv[k] || 0)}</span><small>${fxOf(k)}</small></button></li>`).join('')}</ul>` : '<p class="muted small">가방에 없습니다.</p>';
// 물품 칸을 나누는 한 규칙: list(보통 물품 id — 화면마다 쓸 수 있는 것)에서 inv에 있는 것만(우수품 <id>_hq 포함, 보통 바로 뒤),
// [체력·정신(치료 포함), 영력·기력] 둘로 나눈다
export function itemGroups(list, inv) {
  const have = l => l.flatMap(k => [k, `${k}_hq`]).filter(k => Number(inv[k]) > 0);
  return [have(list.filter(k => !isSpItem(k))), have(list.filter(k => isSpItem(k)))];
}
// 두 칸(체력·정신 / 영력·기력)을 머리글과 함께
export function itemSectionsHtml(list, inv, hpTitle = '체력·정신 회복') {
  const [hp, sp] = itemGroups(list, inv);
  return `<h3 class="raid-item-h">${esc(hpTitle)}</h3>${itemListHtml(hp, inv)}<h3 class="raid-item-h">${esc(spOf()[0])} 회복</h3>${itemListHtml(sp, inv)}`;
}
// 물품 고르기 창: 겹쳐 뜨는 창이라 전투 화면이 다시 그려져도 닫히지 않고, 닫기는 직접.
// fill(box)가 창 안(#bodyId)을 채운다. 물품 설명을 아직 안 받았으면 가방 정보를 한 번 받아 다시 채운다
export function itemTray({ title, bodyId, fill }) {
  let layer = null;
  const refill = () => { const box = layer && $(`#${bodyId}`, layer); if (box) fill(box); };
  return {
    open() {
      if (layer?.isConnected) return;
      layer = openLayer({ title, body: `<div id="${bodyId}"></div>` });
      refill();
      if (!itemDesc('tonic')) load('world_inventory_snapshot').then(refill).catch(() => {});
    },
    refill,
    // 열려 있을 때만 다시 채운다(전투 화면을 다시 그릴 때)
    redraw() { if (layer?.isConnected) refill(); },
    close() { layer?.close?.(); layer = null; },
  };
}

/* ── 결과·정산 ───────────────────────────────────────────── */
// 끝난 싸움의 결과 칸: 제목(html)과 아래 줄(html)
export const resultBox = (ok, title, body = '') => `<div class="raid-result ${ok ? 'ok' : 'bad'}"><b>${title}</b>
    ${body}</div>`;
// 끝난 싸움으로 바뀌면 결과 칸이 화면 위로 밀려 있지 않게 그 칸을 머리 아래로 보인다(창이 떠 있으면 닫을 때)
export function showResult(root) {
  const box = root && $('.raid-result', root); if (!box) return;
  const head = parseFloat(getComputedStyle(document.documentElement).getPropertyValue('--header-h')) || 56;
  scrollAfterModal(Math.max(0, Math.round(window.scrollY + box.getBoundingClientRect().top - head - 8)), true);
}
// 혼자 도전 보정 한 줄(서버 world_solo_aid — 귀허 snapshot.solo {dmg, guard, falls} · 결전 me.solo {solo_dmg|final_dmg, solo_guard, solo_falls})
export function soloAidHtml(dmg, guard, falls) {
  const pct = v => `${v > 0 ? '+' : '−'}${Math.abs(v)}%`, parts = [];
  if (Number(dmg)) parts.push(`주는 피해 ${pct(Number(dmg))}`);
  if (Number(guard)) parts.push(`받는 피해 ${pct(-Number(guard))}`);
  if (Number(falls)) parts.push(`쓰러짐 ${Number(falls) > 0 ? '+' : '−'}${Math.abs(Number(falls))}`);
  return parts.length ? `<p class="solo-aid" title="혼자 도전할 때만 붙는 직업 보정">혼자 도전 보정 · ${parts.join(' · ')}</p>` : '';
}
export async function reloadCharacter() { try { await loadCharacter(); } catch {} }
// 싸움이 끝나면(다른 사람의 마지막 한 방이어도) 내 전·경험치·가방을 다시 읽고 관련 화면에 알린다. before는 알리기 전에 할 일(캐시 버리기 등)
export async function settleFight(name, before) { await reloadCharacter(); before?.(); emit('changed', { name }); }

/* ── 시각 ────────────────────────────────────────────────── */
// 남은 시간 글: sec면 「n초」, 아니면 fmt.remain, 지났으면 「곧」
export const untilText = (t, now = Date.now(), sec = false) => { const ms = new Date(t) - now; return ms > 0 ? (sec ? `${Math.ceil(ms / 1000)}초` : fmt.remain(ms)) : '곧'; };
// root 안의 [data-until] 칸을 다시 적는다(sec이거나 칸에 data-sec가 있으면 초로)
export function tickUntil(root, now = Date.now(), sec = false) { $$('[data-until]', root).forEach(x => { x.textContent = untilText(x.dataset.until, now, sec || !!x.dataset.sec); }); }
// 서버 시계: 스냅샷의 now로 이 기기 시계와의 차이를 기억해 마감·남은 초를 서버 시각으로 센다
export function serverClock() {
  let skew = 0;
  return { now: () => Date.now() + skew, sync(o) { if (o?.now) skew = new Date(o.now).getTime() - Date.now(); } };
}

/* ── 전투 기록 ───────────────────────────────────────────── */
// 휴대폰(640px 아래)은 최근 기록이 위, PC는 아래로 쌓는다
export const mobileLog = () => window.matchMedia('(max-width: 640px)').matches;
export const newestFirst = (list, top) => top ? [...list].reverse() : list;
// 기록의 최근 쪽 끝(휴대폰 맨 위·PC 맨 아래)을 보던 중인지
export const atLogEdge = (log, top) => top ? log.scrollTop < 24 : log.scrollHeight - log.scrollTop - log.clientHeight < 24;
// 화면을 통째로 다시 그리기 전에 기록 칸(.raid-log)의 자리를 기억하고, 그린 뒤 되돌리는 함수를 준다(끝을 보던 중이면 새 끝으로)
export function keepLogScroll(root, top) {
  const old = $('.raid-log', root), edge = !old || atLogEdge(old, top), y = old?.scrollTop || 0;
  return () => { const log = $('.raid-log', root); if (log) log.scrollTop = edge ? (top ? 0 : log.scrollHeight) : y; };
}
// 기록 한 줄: pre는 줄 앞에 붙는 것(시각 등), body는 html
export const logRow = (cls, body, pre = '') => `<li class="${cls}">${pre}<span>${body}</span></li>`;
// 휴대폰: 전투 기록 칸을 화면 아래까지 늘리되, 떠 있는 탭 막대와 채팅 단추(오른쪽 아래) 위에서 멈춘다
export function fitLog(log) {
  if (!log) return;
  if (!mobileLog()) { log.style.height = ''; return; }
  // 떠 있는(fixed) 요소는 offsetParent가 null이라 getClientRects로 보이는지 본다
  const vis = q => { const e = document.querySelector(q); return e && !e.hidden && getComputedStyle(e).display !== 'none' && e.getClientRects().length ? e.getBoundingClientRect().top : window.innerHeight; };
  const stop = Math.min(vis('.tabbar'), vis('#chat-fab'));
  const top = log.getBoundingClientRect().top, pad = 14;
  log.style.height = Math.max(92, Math.floor(stop - top - pad)) + 'px';
  // 그래도 화면이 조금 넘치면(머리·여백 차이) 넘친 만큼 줄인다
  const over = document.documentElement.scrollHeight - window.innerHeight;
  if (over > 0 && window.scrollY < 4) log.style.height = Math.max(92, log.offsetHeight - over) + 'px';
}
