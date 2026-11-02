// 파티 전투 화면 공용 부품(7.7.7i, 사용자 결정 — 봉연 토벌 화면을 기준으로 봉연·파티 토벌·귀허의 주인을 같게):
// 북돋기·약화 아이콘과 떠 있는 짧은 설명, 직업 색 참가자 칸·자세히 칸, 내 체력·영력 막대, 협동 기술 아이콘, 물품 창 목록(이름·회복 수치).
// 새 효과·기술을 넣으면 FX_NAME·FX_ICON·FX_TIP·SKILL_ICON에 함께 더한다.
import { esc, icon, fmt, nameOf, JOBS, brief } from '../core.js';
import { itemDesc, catItem, catalogList } from './common.js';
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

const jobName = j => JOBS[j]?.name || nameOf(j);
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

// 내 체력·영력(기력)·정신 막대
export const vitHtml = (label, v, kind, low = false) => `<div class="raid-vit ${kind} ${low ? 'low' : ''}"><span>${esc(label)}</span><b>${fmt.num(v ?? 0)}</b><i class="bar"><i style="width:${Math.max(0, Math.min(100, Number(v) || 0))}%"></i></i></div>`;

// 협동 기술 단추(봉연 모양). k: { id, name, desc, cost, target, unlocked, rank, why(못 쓰는 까닭, 있으면 막음), on }
export const coopBtn = (k, data = '') => `<button type="button" class="coop-btn ${!k.unlocked ? 'locked' : ''} ${k.on ? 'on' : ''}" ${data} ${k.why ? 'data-lock="1" disabled' : ''} title="${esc(k.desc || '')}">
  <b>${icon(SKILL_ICON[k.id] || 'spark', 13)}${esc(k.name)}</b><small>${esc(k.why || `영력 ${k.cost}`)}${k.target === 'ally' ? ' · 동료' : k.target === 'all' ? ' · 모두' : k.target === 'boss' ? ' · 요괴' : ''}</small></button>`;

// 물품 창 목록: 이름·남은 수·회복 수치만(제보 86), 짧은 설명은 title
// 영력·기력만 채우는 물품(7.7.7o: 물품 목록의 서버 효과로 가름 — 새 물품도 저절로 이 칸에)
export const isSpItem = k => { const f = catItem(String(k).replace(/_hq$/, ''))?.fx; return !!f && f.sp > 0 && !(f.hp > 0) && !(f.mn > 0); };
// 토벌에서 쓸 수 있는 회복 물품: 체력·정신·영력을 채우는 모든 소모품(우수품은 itemGroups가 더함)
export const battleItems = () => (catalogList() || []).filter(i => !String(i.id).endsWith('_hq') && i.fx && (i.fx.hp > 0 || i.fx.mn > 0 || i.fx.sp > 0)).map(i => i.id);
export const fxOf = k => fxHtml(String(USABLE[k.replace(/_hq$/, '')] || '').split(' · ').filter(x => /^(체력|정신|영력|침식)|치료|풀기/.test(x.trim())).join(' · ') || brief(itemDesc(k)) || '');
export const itemListHtml = (ids, inv, on = '') => ids.length ? `<ul class="raid-item-list">${ids.map(k => `<li><button type="button" class="raid-item ${on === k ? 'on' : ''}" data-use="${esc(k)}" title="${esc(brief(itemDesc(k)) || '')}"><b>${esc(nameOf(k))}</b><span>×${fmt.num(inv[k] || 0)}</span><small>${fxOf(k)}</small></button></li>`).join('')}</ul>` : '<p class="muted small">가방에 없습니다.</p>';
// 가방에 있는 것만(우수품 포함), 체력·정신 / 영력 둘로 나눔
export function itemGroups(list, inv) {
  const have = l => l.flatMap(k => [k, `${k}_hq`]).filter(k => Number(inv[k]) > 0);
  return [have(list.filter(k => !isSpItem(k))), have(list.filter(k => isSpItem(k)))];
}
