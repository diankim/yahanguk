// 캐릭터: 상태(생존·전투 능력·장비·상태이상) · 성장(능력치·생활 전문화·숙련) · 세력 · 기술 · 자율 활동 · 칭호.
// 이름·직업·소속은 생성 시 고정되며 여기서 바꿀 수 없다.
import { midBattle, gmBadge, ask, store, on, act, rpc, nameOf, JOBS, FACTIONS, esc, icon, bar, guard, $, $$, fmt, empty, segmented, bindSegmented, effectText, openModal, closeModal, toast, LEVEL_CAP, spOf, RAID_ON } from '../core.js';
import { load, invalidate, panel, chip, loading, errorBox, MAJOR_FACTIONS, itemsText, safeZones, currentRegion } from './common.js';
import { openStatus, yohwaOf, yohwaLine, yohwaDowned, YOHWA_STAGES } from '../hud.js';
import { focusRegion } from './map.js';
import { paintTitleDot, markTitlesSeen } from '../titledot.js';
import { SLOTS } from './item.js';
import { factionColor } from '../geo.js';
import { loadBond, tokenRowHtml, bindTokenRow } from '../bond.js';
import { fqPops, fqPopHtml, bindFaction } from '../factionquest.js';
import { showLetter } from '../lore.js';

const SUBS = [['status', '상태', 'heart'], ['growth', '성장', 'spark'], ['faction', '세력', 'flag'], ['skills', '기술', 'target'], ['idle', '자율', 'hourglass'], ['titles', '칭호', 'knot'], ['house', '별채', 'home']];
const STATS = [
  ['strength', '근력', '근접 무기의 위력'], ['agility', '민첩', '회피·달아나기·원거리 위력 · 이목 낮춤'], ['vitality', '체질', '방어력·응급 회복 · 이목 높임'],
  ['perception', '감각', '치명타·원거리 위력·단서 발견'], ['willpower', '의지', '술법 위력·응급 회복'], ['spirit_affinity', '영성', '술법 무기의 위력'],
];
const STYLE = { melee: '근접', ranged: '원거리', magic: '술법' };
const GATHER = ['fieldwork', 'mining', 'botany', 'spirit_harvest', 'fishing'];
const CRAFT = ['general', 'smithing', 'carpentry', 'alchemy', 'sealing', 'weaving', 'leatherwork', 'artifice', 'cooking'];
const IDLE = [
  ['training', '자율 수련', '경험치와 전투 숙련, 든 무기에 맞는 전투 기술(근접·원거리·봉인술)을 올립니다.', 'sword'], ['research', '자료 조사', '경험치와 조사 숙련, 추적 기술을 올립니다.', 'search'],
  ['maintenance', '장비 정비', '경험치와 제작 숙련, 제작 분야에 맞는 기술(단조·연금·결계 각인)을 올립니다.', 'hammer'], ['rest', '휴식', '체력·정신·영력을 회복하고 경험치를 조금 얻습니다.', 'moon'],
];
// 자율 활동 보상(서버 world_claim_idle_activity와 같은 식): 시간 h에 대해 숙련·회복 floor(h×12×0.35), 경험치 floor(h×비율×0.35)(최소 1, 최고 레벨이면 0)
const IDLE_RATE = { training: 12, research: 10, maintenance: 8, rest: 3 };
// 오르는 기술(서버 world_idle_skill_for와 같은 규칙): 수련은 든 무기 종류, 정비는 제작 분야
let idleWeapon = 'melee';
const trainSkill = () => ({ ranged: '원거리', magic: '봉인술' })[idleWeapon] || '근접';
const maintSkill = () => ({ sealing: '결계 각인', alchemy: '연금' })[store.character?.crafting_profession] || '단조';
// early: 끝나기 전에 그만두면 지난 시간만큼만, 최소 1 보정 없이
function idleReward(k, min, level, early = false) {
  const h = min / 60, lo = early ? 0 : 1, gain = Math.max(lo, Math.floor(h * 12 * 0.35)), xp = level >= LEVEL_CAP ? 0 : Math.max(lo, Math.floor(h * IDLE_RATE[k] * 0.35));
  const out = xp ? [`경험치 +${xp}`] : [];
  if (early && !gain && !xp) return ['받을 보상 없음'];
  if (k === 'training') out.push(`전투 숙련 +${gain}`, `${trainSkill()} 기술 +${gain}`);
  else if (k === 'research') out.push(`조사 숙련 +${gain}`, `추적 기술 +${gain}`);
  else if (k === 'maintenance') out.push(`제작 숙련 +${gain}`, `${maintSkill()} 기술 +${gain}`);
  else out.push(`체력·정신·영력 각 +${gain}`);
  return out;
}
const DURATIONS = [[30, '30분'], [60, '1시간'], [240, '4시간'], [480, '8시간']];
const EROSION = ['안정', '경미', '주의', '위험', '붕괴 직전', '붕괴'];
// 침식 단계 효과(서버 world_erosion_effect·world_combat_stats·world_apply_activity_status와 같은 값)
function erosionNote(e) {
  const [bad, good] = e >= 80 ? [['회복량 −35%', '받는 피해 +20%', '주는 피해 −10%', '요괴 조우 +20%', '술법 −30%', '행동마다 정신 −1'], '희귀품·단서 +15%']
    : e >= 55 ? [['회복량 −25%', '받는 피해 +10%', '술법 −20%', '행동마다 정신 −1'], '희귀품·단서 +10%']
    : e >= 30 ? [['회복량 −15%', '술법 −10%'], '희귀품·단서 +5%'] : [[], ''];
  const next = e >= 80 ? '100에 닿으면 정신이 0이 됩니다.' : e >= 55 ? '80부터 붕괴 직전입니다.' : e >= 30 ? '55부터 위험 단계입니다.' : '30부터 불이익이 생깁니다.';
  return `<p class="muted small">${bad.length ? `<b class="bad-text">지금 침식 효과: ${esc(bad.join(' · '))}</b> · 대신 ${esc(good)}. ` : ''}${esc(next)} 위험한 곳·삼경·어두운 곳을 탐색하거나 싸움에서 지면 오릅니다. 정화 부적·휴식으로 낮추세요.</p>`;
}
let el, sub = 'status', off = [];

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'status';
  const c = store.character;
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('user', 14)} ${esc(JOBS[c.job_key]?.name || nameOf(c.job_key))} · ${esc(FACTIONS[c.faction_key]?.name || nameOf(c.faction_key))}</p><h1>${esc(c.character_name)}${gmBadge(c.owner_id)} <small>Lv.${c.level}</small></h1></div></div>
    ${segmented('char-sub', SUBS, sub)}<div id="char-body"></div>`;
  paintTitleDot();
  bindSegmented(el, 'char-sub', k => { if (k === 'house') return window.yahangGo?.('house'); sub = k; window.history.replaceState(null, '', `#/char/${k}`); draw(); });
  // 행동 뒤에는 그 행동이 바꿀 수 있는 것만 다시 읽는다(전투 능력치·쉼·정인은 관련 행동 뒤에만, 상태판 요약은 상태판과 같이 씀)
  off.forEach(f => f()); off = [on('changed', ev => { if (midBattle(ev)) return; lastChange = ev.name || ''; draw(true); })];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#char-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try { await ({ status, growth, faction, skills, idle, titles })[sub](body); }
  catch (e) { body.innerHTML = errorBox(e.message); }
}

/* ── 상태 ─────────────────────────────────────────────── */
const USE = [['tonic', '체력 35 · 마음 진정'], ['herbal_extract', '체력 22 · 출혈·화상·근맥 치료'], ['herb', '체력 12 · 중독·소화 불량 치료'],
  ['medicine_base', '정신 12 · 기력 저하·한기·탈진 치료'], ['ward_talisman', '정신 8 · 침식 완화 · 사념·동요·중독 치료'], ['travel_ration', '탐색력 +5']];
export function combatRows(cur) {
  if (!cur) return '';
  const rows = [
    ['공격 방식', `${STYLE[cur.style] || '근접'}${cur.weapon ? ` · ${esc(cur.weapon.name)}` : ' · 맨손'}`],
    ['공격력', fmt.num(cur.attack)], ['방어력', `${cur.defense} <small>(받는 피해 -${cur.reduction_pct}%)</small>`],
    ['회피율', `${cur.evasion_pct}%`], ['치명타율', `${cur.crit_pct}% <small>(피해 ×${(cur.crit_mult / 100).toFixed(1)})</small>`],
    ['달아날 확률', `${cur.flee_pct}%`], ['주는 피해 보정', `${cur.damage_pct > 0 ? '+' : ''}${cur.damage_pct}%`],
    ['받는 피해 보정', `${cur.incoming_pct > 0 ? '+' : ''}${cur.incoming_pct}%`],
    ['이목', `${fmt.num(cur.presence ?? 30)} <small>(${presenceWord(cur.presence ?? 30)})</small>`],
  ];
  if (cur.spell_cost) rows.push(['술법 영력 소모', `공격마다 ${cur.spell_cost}`]);
  if (cur.mind_mul < 1) rows.push(['정신·침식 불이익', `공격력 ×${cur.mind_mul}`]);
  return `<dl class="stat-sheet">${rows.map(([k, v]) => `<div><dt>${k}</dt><dd>${v}</dd></div>`).join('')}</dl>
    ${(cur.skills || []).length ? `<p class="muted small">적용 중인 전투 기술: ${cur.skills.map(esc).join(', ')}</p>` : ''}`;
}
// 이목: 함께 싸울 때 요괴가 먼저 노리는 정도(체질·무거운 갑옷이 높이고 민첩이 낮춘다)
const presenceWord = p => p >= 90 ? '요괴가 가장 먼저 노림' : p >= 55 ? '눈에 잘 띔' : p >= 25 ? '보통' : '잘 눈에 띄지 않음';
function durBar(d, max) { return `<div class="durab ${d <= 0 ? 'broken' : d * 4 < max ? 'worn' : ''}"><span>내구도 ${d}/${max}</span>${bar(d, max, d <= 0 ? 'enemy' : d * 4 < max ? 'er' : 'xp')}</div>`; }
// 서버 world_item_max_durability와 같은 값(노리개·호신부·탈은 닳지 않는다)
const maxDur = it => it ? (['weapon', 'armor'].includes(it.category) ? 50 + (it.tier || 1) * 30 : ['tool', 'hat', 'shoes'].includes(it.category) ? 40 + (it.tier || 1) * 20 : 0) : 0;
// 강화한 무기의 위력(서버 world_combat_stats: 단계마다 +5%)
export const enhancedTraits = (t, n) => n && t?.power ? { ...t, power: Math.round(t.power * (1 + 0.05 * n) * 10) / 10 } : (t || {});
export function equipRows(inv, prof, here) {
  const cmap = new Map((inv?.catalog || []).map(i => [i.id, i])), eq = inv?.equipment || {}, have = inv?.inventory || {}, durs = prof?.durability || {};
  const kits = Number(have.repair_kit || 0);
  return `<ul class="equip-list">${Object.entries(SLOTS).map(([slot, [label, ic]]) => {
    const id = eq[slot], it = cmap.get(id);
    if (!id) return `<li class="empty-slot">${icon(ic, 18)}<div><b>${label}</b><small>비어 있음 · ${esc(SLOT_HINT[slot])}</small></div></li>`;
    const mx = maxDur(it), d = durs[id]?.durability ?? mx;
    const cost = Math.max(5, Math.ceil((mx - d) * ((it?.tier || 1) + 1) / 2));
    const n = slot === 'weapon' ? Number(prof?.current?.weapon?.enhance) || 0 : 0;
    const enh = n ? ` <span class="enh-lv">+${n}</span>` : '';
    return `<li>${icon(ic, 18)}<div><b>${label} · ${esc(nameOf(id))}${enh}</b><small>${esc(effectText(enhancedTraits(it?.equipment_traits, n)).join(' · ') || it?.description || '')}${n ? ` · 강화 +${n}(위력 +${n * 5}%)` : ''}</small>${mx ? durBar(d, mx) : ''}</div>
      ${mx && d < mx ? `<div class="btn-col"><button class="btn small" data-repair="${esc(id)}" data-how="kit" ${kits ? '' : 'disabled'}>${icon('wrench', 14)}<span>수리 도구 <small>×${kits}</small></span></button>
        <button class="btn small" data-repair="${esc(id)}" data-how="gil" ${here?.is_safe_zone ? '' : 'disabled'} title="${here?.is_safe_zone ? '' : '안전지대에서만 맡길 수 있습니다'}">맡기기 <small>${fmt.jeon(cost)}</small></button></div>` : ''}
      <button class="btn small ghost eq-off" data-unequip="${esc(slot)}" aria-label="${esc(label)} 벗기">벗기</button></li>`;
  }).join('')}${tokenRowHtml()}</ul>
  <p class="muted small">공격할 때마다 무기, 맞을 때마다 방어구·관모, 채집할 때마다 도구, 이동할 때마다 신이 1씩 닳습니다(노리개·호신부·탈은 닳지 않습니다). 4분의 1 아래로 떨어지면 성능이 20% 줄고, 0이 되면 부서져 효과가 없습니다. 수리 도구는 어디서나 절반을 되살리고, 안전지대에서는 전을 내고 완전히 고칠 수 있습니다.</p>`;
}
export function bindRepair(root) {
  $$('[data-repair]', root).forEach(b => b.onclick = () => guard(b, () => act('world_equipment_repair', { p_item_id: b.dataset.repair, p_method: b.dataset.how })));
  $$('[data-unequip]', root).forEach(b => b.onclick = () => guard(b, () => act('world_unequip_item', { p_slot: b.dataset.unequip })));
  bindTokenRow(root);
}
// 빈 칸에 무엇을 끼우면 좋은지
const SLOT_HINT = { weapon: '무기 종류가 공격 방식을 정합니다', armor: '받는 피해를 줄입니다', hat: '방어·침착·단서 발견', shoes: '이동 시간·몸놀림·버티기',
  norigae: '행운·치명타·채집량', amulet: '술법·받는 피해·정화', mask: '이목을 낮추거나 높입니다', tool: '채집량·채집터 덤', explore: '나침반: 숨은 길·채집터를 더 잘 찾음', fishing: '낚싯대: 비워 두면 가방의 가장 좋은 것을 씀' };
async function hereZone() {
  const z = await safeZones().catch(() => null), c = store.character;
  return z ? [...z.values()].find(r => r.region_name === c.location) || null : null;
}
let lastChange = '';
async function status(body) {
  const ch = lastChange; lastChange = '';
  if (/rest|idle|travel|field_move/.test(ch)) invalidate('world_rest_status');
  const [sv, hud, prof, inv, here, rs] = await Promise.all([load('world_survival_snapshot'), load('world_hud_snapshot', undefined, { maxAge: 2000 }).catch(() => null),
    load('world_combat_profile', undefined, { maxAge: 60000 }).catch(() => null), load('world_inventory_snapshot', undefined, { maxAge: 3000 }).catch(() => null), hereZone(),
    load('world_rest_status', undefined, { maxAge: 60000 }).catch(() => null), loadBond(!ch || /bond|equip|travel|party|field_move/.test(ch))]);
  const c = store.character, invItems = c.inventory || {};
  const stage = Number(sv?.erosion_stage ?? c.erosion_stage ?? 0);
  const yo = yohwaOf(hud?.statuses), statuses = yo.rest, yl = yohwaLine(yo);
  const downed = c.downed_at || c.health <= 0, byYohwa = downed && yohwaDowned(c, yo);
  const deathAt = c.downed_at && !byYohwa ? new Date(c.downed_at).getTime() + 4 * 3600e3 : 0;
  // 부적 정화: 정화 부적이 있고 침식이 있어야 한다. 마음 다잡기: 본부에서 15분마다, 정신이 가득하고 침식이 없으면 쓸 수 없다(서버가 다시 검사).
  const wards = Number(invItems.ward_talisman || 0), er0 = Number(sv?.erosion ?? c.erosion ?? 0), mn0 = Number(sv?.mental ?? c.mental ?? 0);
  const groundReady = rs?.ground_ready_at ? new Date(rs.ground_ready_at).getTime() : 0;
  const atHq = ['야행국 본부 정청', '본부 객사', '연무장·팔괘진'].includes(c.location); // 서버 world_survival_action과 같은 곳
  // 부적으로 풀리는 상태이상(중독·심신 동요·사념 침식)이 있으면 침식이 없어도 쓸 수 있다(서버 world_survival_action)
  const wardCures = (statuses || []).filter(s => (s.cure_items || []).includes('ward_talisman')).length;
  const cleanseWhy = downed ? '전투불능' : !wards ? '정화 부적이 없습니다' : (er0 <= 0 && !wardCures) ? '정화할 침식·상태이상이 없습니다' : '';
  const groundWhy = downed ? '전투불능' : !atHq ? '본부(정청·객사·연무장)에서만' : (mn0 >= 100 && er0 <= 0) ? '정신이 이미 맑습니다' : groundReady > Date.now() ? `${fmt.remain(groundReady - Date.now())} 뒤 다시` : '';
  body.innerHTML = `
    ${downed ? panel(byYohwa ? '요화로 쓰러짐' : '전투불능', `
      <p class="desc">${byYohwa ? '요기를 이기지 못해 쓰러졌습니다. 요화로 쓰러진 것이라 목숨은 잃지 않습니다.' : '쓰러져 움직일 수 없습니다. 같은 지역의 조사원이 구조할 수 있고, 아래 방법으로 스스로 일어날 수도 있습니다.'}</p>
      <p class="bad"><b id="death-left">${deathAt ? `목숨이 다하기까지 ${fmt.remain(deathAt - Date.now())}` : ''}</b></p>
      <div class="action-grid">
        ${yo.y ? `<button class="btn primary" id="yohwa-seal"><span>안전지대 봉인</span><small>가장 가까운 안전지대에서 봉인술사들이 24시간 요기를 해독합니다 · 그동안 채팅만 가능 · 끝나면 요화가 풀리고 침식 40 아래</small></button>` : ''}
        <button class="btn primary" data-use="revival_charm" ${invItems.revival_charm > 0 ? '' : 'disabled'}><span>회생 부적 쓰기 <small>×${fmt.num(invItems.revival_charm)}</small></span><small>그 자리에서 체력 50으로 일어납니다</small></button>
        <button class="btn" id="call-rescue"><span>본부 구조대 부르기</span><small>소지금 15%(오늘 첫 구조 반값)·이번 레벨 경험치 5% · 가장 가까운 안전지대로 옮겨집니다</small></button>
      </div>
      <p class="muted small">${byYohwa ? '구조나 회생 부적으로 일어나면 요화는 남아 하루 뒤 다시 쓰러집니다. 귀령초로 풀거나 안전지대 봉인을 받으세요.' : '시간이 다하면 캐릭터는 목숨을 잃고 그 자리에 시신이 남습니다. 새로 시작하려면 계정 화면 맨 아래에서 캐릭터를 정리할 수 있습니다.'}</p>`, { ico: byYohwa ? 'mask' : 'heart', cls: 'danger' }) : ''}
    ${yl && !downed ? `<div class="notice ${yo.seal ? '' : 'danger'} yohwa-note">${icon(yo.seal ? 'shield' : 'mask', 18)}<div><b>${esc(yl.title)}</b><span>${yo.seal ? esc(yl.text) : `${esc(yl.text)} <em data-left="${new Date(yl.until).getTime()}">${fmt.remain(new Date(yl.until) - Date.now())}</em> · 단계마다 회복량 −10%·정신 손실 +10%·받는 피해 +6%·침식 +8%(주는 피해 +4%) · 귀령초로만 풀립니다.`}${yo.seal ? ` 남은 시간 <em data-left="${new Date(yl.until).getTime()}">${fmt.remain(new Date(yl.until) - Date.now())}</em>` : ''}</span></div>${yo.y && (c.inventory?.gwiryeong_cho || 0) > 0 ? '<button class="btn small primary" data-use="gwiryeong_cho">귀령초 쓰기</button>' : ''}</div>` : ''}
    <div class="grid-2">
      ${panel('생존 상태', `
        ${['health:체력:hp', 'mental:정신:mp', `spiritual_power:${spOf().join(':')}`].map(x => { const [k, l, cls] = x.split(':'); return `<div class="vital big"><span>${l}</span><b>${fmt.num(sv?.[k] ?? c[k])}</b>${bar(sv?.[k] ?? c[k], 100, cls)}</div>`; }).join('')}
        <div class="vital big"><span>침식</span><b>${fmt.num(sv?.erosion ?? c.erosion)} <small>${EROSION[Math.min(stage, 5)]}</small></b>${bar(sv?.erosion ?? c.erosion, 100, 'er')}</div>
        ${erosionNote(Number(sv?.erosion ?? c.erosion ?? 0))}
        <div class="action-grid three">
          <button class="btn" data-surv="cleanse" ${cleanseWhy ? 'disabled' : ''}><span>부적 정화 <small>×${fmt.num(wards)}</small></span><small>${esc(cleanseWhy || `정화 부적 1개 · 침식 -18 · 정신 +6${wardCures ? ` · 상태이상 ${wardCures}개 해소` : ''}`)}</small></button>
          <button class="btn" data-surv="ground" ${groundWhy ? 'disabled' : ''}><span>마음 다잡기</span><small id="ground-note" data-ready="${groundReady || ''}">${esc(groundWhy || '본부에서 · 정신 +18 · 침식 -10 · 15분마다')}</small></button>
        </div>`, { ico: 'heart' })}
      ${panel('전투 능력', prof?.current ? combatRows(prof.current) : empty('전투 능력을 불러오지 못했습니다.'), { ico: 'sword', extra: `<a class="btn small ghost" href="#/char/growth">능력치</a>` })}
    </div>
    <div class="grid-2">
      ${panel('장착 장비', inv ? equipRows(inv, prof, here) : empty('장비 정보를 불러오지 못했습니다.'), { ico: 'shield', extra: `<a class="btn small ghost" href="#/bag/equip">바꾸기</a>` })}
      ${panel(`상태 ${statuses.length}/10`, statuses.length ? `<ul class="status-list">${statuses.map((x, i) => `<li class="${x.polarity === 'positive' ? 'good' : 'bad'}">
          <button class="st-open" data-st="${i}"><b>${esc(x.name)}${x.stacks > 1 ? ` ×${x.stacks}` : ''}</b><small>${esc(x.description || '')}</small></button>
          <span class="muted small" data-left="${new Date(x.expires_at).getTime()}">${fmt.remain(new Date(x.expires_at) - Date.now())}</span></li>`).join('')}</ul>
          <p class="muted small">상태를 누르면 자세한 효과와 치료 방법을 볼 수 있습니다.</p>`
        : empty('걸린 상태가 없습니다.', 'shield'), { ico: 'flame' })}
    </div>
    ${panel('회복·치료 물품', `<div class="action-grid">${USE.map(([k, d]) => `<button class="btn" data-use="${k}" ${invItems[k] > 0 && !downed ? '' : 'disabled'}><span>${esc(nameOf(k))} <small>×${fmt.num(invItems[k])}</small></span><small>${d}</small></button>`).join('')}</div>
      <p class="muted small">전투불능일 때는 회생 부적만 쓸 수 있습니다.</p>`, { ico: 'plus' })}`;
  $$('[data-surv]', body).forEach(b => b.onclick = () => guard(b, () => act('world_survival_action', { p_action: b.dataset.surv })));
  $$('[data-use]', body).forEach(b => b.onclick = async () => {
    const k = b.dataset.use, d = USE.find(([x]) => x === k)?.[1] || '';
    if (!(await ask(`${nameOf(k)} 1개를 쓸까요?${d ? ` (${d})` : ''} 남은 수량 ${fmt.num(invItems[k] || 0)}개`, { title: '물품 사용', ok: '사용', cancel: '그만두기' }))) return;
    guard(b, () => act('world_use_item', { p_item_id: k }));
  });
  $$('[data-st]', body).forEach(b => b.onclick = () => openStatus(statuses[Number(b.dataset.st)]));
  bindRepair(body);
  const ys = $('#yohwa-seal', body);
  if (ys) ys.onclick = async () => { if (await ask('안전지대 봉인을 받을까요? 가장 가까운 안전지대로 옮겨져 24시간 동안 요기를 해독합니다. 그동안은 채팅만 할 수 있고, 끝나면 요화가 풀린 채 원래대로 움직입니다.', { title: '안전지대 봉인', ok: '봉인 받기' })) guard(ys, () => act('world_yohwa_seal')); };
  const cr = $('#call-rescue', body);
  if (cr) cr.onclick = async () => { if (await ask('본부 구조대를 부를까요? 소지금의 15%(최소 30전, 레벨×80전·레벨 15 미만은 레벨×40전까지, 오늘 첫 구조 반값, 가까운 안전지대가 내 대세력 지배면 다시 반값)와 이번 레벨에 필요한 경험치의 5%를 잃고 가장 가까운 안전지대로 옮겨집니다(레벨은 내려가지 않습니다). 그 안전지대가 내 대세력 지배면 경험치는 잃지 않고 체력 50으로 깨어납니다.', { title: '구조대 부르기', ok: '부르기' })) guard(cr, () => act('world_call_rescue')); };
  const t = setInterval(() => {
    if (!body.isConnected) return clearInterval(t);
    $$('[data-left]', body).forEach(x => x.textContent = fmt.remain(Number(x.dataset.left) - Date.now()));
    const d = $('#death-left', body); if (d && deathAt) d.textContent = `목숨이 다하기까지 ${fmt.remain(deathAt - Date.now())}`;
    const g = $('#ground-note', body), gr = Number(g?.dataset.ready || 0);
    if (g && gr) { if (gr > Date.now()) g.textContent = `${fmt.remain(gr - Date.now())} 뒤 다시`; else { g.dataset.ready = ''; g.textContent = '본부에서 · 정신 +18 · 침식 -10 · 15분마다'; if (atHq && !(mn0 >= 100 && er0 <= 0) && !downed) g.closest('button').disabled = false; } }
  }, 1000);
}

/* ── 성장: 능력치를 올리면 바뀌는 수치를 미리 보여 준다 ───────── */
const PREVIEW = [['attack', '공격력', ''], ['defense', '방어력', ''], ['reduction_pct', '받는 피해 감소', '%'], ['evasion_pct', '회피율', '%'], ['crit_pct', '치명타율', '%'], ['flee_pct', '달아날 확률', '%'], ['presence', '이목', '']];
function previewText(cur, next) {
  if (!cur || !next) return '';
  const parts = PREVIEW.filter(([k]) => Number(next[k]) !== Number(cur[k])).map(([k, n, u]) => `${n} ${cur[k]}${u} → <b>${next[k]}${u}</b>`);
  return parts.length ? parts.join(' · ') : '전투 수치 변화 없음 (지금 무기로는 영향이 적습니다)';
}
// 능력치 하나의 상한(서버 world_stat_cap과 같은 식)
// 직업마다 기본 능력치가 달라 상한도 능력치마다 다르다(world_stat_cap_of = 직업 기본값 + 레벨×1.5)
const statCap = (lv, k, job) => (JOBS[job]?.base?.[k] ?? 5) + Math.floor(Math.max(1, Number(lv) || 1) * 1.5);
// 화면에서 나눈 점수(확정 전): 캐릭터마다 sessionStorage에 남긴다
const allocKey = c => `yh-alloc-${c?.owner_id || c?.character_name || ''}`;
const allocSum = a => Object.values(a || {}).reduce((x, y) => x + (Number(y) || 0), 0);
function loadAlloc(c) { try { const a = JSON.parse(sessionStorage.getItem(allocKey(c)) || '{}'); return a && typeof a === 'object' ? a : {}; } catch { return {}; } }
function saveAlloc(c, a) { try { allocSum(a) ? sessionStorage.setItem(allocKey(c), JSON.stringify(a)) : sessionStorage.removeItem(allocKey(c)); } catch { /* 저장 못 해도 화면은 그대로 */ } }
async function growth(body) {
  // 능력치를 올렸을 때 바뀔 값(plus_one)은 서버가 7번 계산하므로 쓸 포인트가 있을 때만 받는다
  const [inv, prof] = await Promise.all([load('world_inventory_snapshot', undefined, { maxAge: 5000 }), load('world_combat_profile', Number(store.character?.stat_points || 0) > 0 ? { p_preview: true } : undefined, { maxAge: 60000 }).catch(() => null)]);
  const c = store.character, pts = Number(c.stat_points || 0), cur = prof?.current;
  // 남은 포인트·상한을 넘는 몫은 버린다(다른 기기에서 썼거나 세심단을 쓴 뒤)
  let pend = {}, room = pts;
  Object.entries(loadAlloc(c)).forEach(([k, v]) => { if (!STATS.some(x => x[0] === k)) return; const n = Math.max(0, Math.min(Number(v) || 0, room, statCap(c.level, k, c.job_key) - c[k])); if (n) { pend[k] = n; room -= n; } });
  const sp = c.skill_progress || {}, bestOf = cats => { const k = cats.reduce((a, x) => (sp[x]?.rank || 1) > (sp[a]?.rank || 1) ? x : a, cats[0]); return `가장 높은 기술: ${SKILL_NAME[k] || nameOf(k)}`; };
  const ranks = [...BRANCHES.map(([k, n, , cats]) => [n, c[k + '_rank'], bestOf(cats)]), ['요리', c.cooking_rank, `${fmt.num(c.cooking_xp)} 경험`]];
  body.innerHTML = `
    <div class="grid-2">
      ${panel('능력치', `<p class="muted small">레벨이 오르면 능력치 포인트를 얻습니다. 남은 포인트: <b class="accent" id="al-left">${pts - allocSum(pend)}</b> / ${pts} · + / − 로 나눈 뒤 「확정」을 눌러야 반영됩니다. 한 능력치는 <b>직업 기본값 + ${Math.floor(Math.max(1, Number(c.level) || 1) * 1.5)}</b>까지 올릴 수 있습니다(레벨×1.5, 능력치마다 오른쪽 숫자).</p>
        <ul class="stat-list">${STATS.map(([k, n, d]) => `<li><div><b>${n} <span class="stat-val">${fmt.num(c[k])}</span><em class="al-add" data-add="${k}">${pend[k] ? ` +${pend[k]}` : ''}</em> <small class="muted">/ ${statCap(c.level, k, c.job_key)}</small></b><small>${d}</small>
            <small class="preview">${previewText(cur, prof?.plus_one?.[k])}</small></div>
          <span class="al-btns"><button class="icon-btn" data-dec="${k}" aria-label="${n} 내리기">${icon('minus', 16)}</button><button class="icon-btn" data-stat="${k}" aria-label="${n} 올리기">${icon('plus', 16)}</button></span></li>`).join('')}</ul>
        <div class="al-foot"><p class="preview" id="al-prev"></p>
          <div class="row-actions"><button class="btn ghost" id="al-reset">되돌리기</button><button class="btn" id="al-preview">미리 보기</button><button class="btn primary" id="al-ok">${icon('check', 16)}<span>확정</span></button></div></div>`, { ico: 'spark' })}
      ${panel('지금 전투 능력', cur ? combatRows(cur) : empty('전투 능력을 불러오지 못했습니다.'), { ico: 'sword' })}
    </div>
    <div class="grid-2">
      ${panel('기능 숙련', `<ul class="rank-list">${ranks.map(([n, r, best]) => `<li><span>${n}</span><b>${fmt.num(r || 1)}단계</b><small>${esc(best)}</small></li>`).join('')}</ul>
        <p class="muted small">숙련은 그 갈래 기술 가운데 가장 높은 단계입니다(최고 50, 요리는 따로 20단계). 전투 숙련은 단계마다 공격력 +0.6%입니다. 기술 탭에서 계열별 단계를 봅니다.</p>`, { ico: 'target' })}
      ${panel('생활 전문화', `<p class="desc">채집과 제작에서 집중할 분야입니다. 맞는 채집터에서는 채집량이 1 늘고, 내 제작 분야의 제작법은 품질 +12(종합 제작은 모든 분야 +4)입니다. 요리를 고르면 요리 제작법이 품질 +12입니다.</p>
        <p class="${profWait(c) > 0 ? 'hint' : 'muted small'}">${profWait(c) > 0 ? `${icon('hourglass', 14)} 다음 변경까지 ${fmt.remain(profWait(c))}` : '한 번 바꾸면 3일 동안 다시 바꿀 수 없습니다.'}</p>
        <div class="form-grid">
          <label class="field"><span>채집 분야</span><select id="g-prof">${GATHER.map(k => `<option value="${k}" ${inv?.gathering_profession === k ? 'selected' : ''}>${esc(nameOf(k))}</option>`).join('')}</select></label>
          <label class="field"><span>제작 분야</span><select id="c-prof">${CRAFT.map(k => `<option value="${k}" ${inv?.crafting_profession === k ? 'selected' : ''}>${esc(nameOf(k))}</option>`).join('')}</select></label>
        </div><button class="btn" id="prof-save" ${profWait(c) > 0 ? 'disabled' : ''}>${icon('check', 16)}<span>전문화 정하기</span></button>`, { ico: 'leaf' })}
    </div>
    ${panel('신원', `<dl class="kv"><div><dt>이름</dt><dd>${esc(c.character_name)}</dd></div><div><dt>직업</dt><dd>${esc(nameOf(c.job_key))} · ${esc(JOBS[c.job_key]?.trait || '')}</dd></div>
      <div><dt>소속</dt><dd>${esc(nameOf(c.faction_key))}</dd></div><div><dt>대세력</dt><dd>${c.major_faction_id ? `${esc(nameOf(c.major_faction_id))} · 평판 ${fmt.num(c.faction_reputation)}` : '미가입'}</dd></div></dl>
      <p class="muted small">이름·직업·소속은 캐릭터 생성 시 정해지며 바꿀 수 없습니다.</p>`, { ico: 'idcard' })}`;
  // 나눈 점수는 화면을 옮겨도 남는다(sessionStorage, 캐릭터마다). 미리 보기는 누를 때 한 번만 서버에 묻는다
  const sync = () => {
    const left = pts - allocSum(pend);
    $('#al-left', body).textContent = left;
    STATS.forEach(([k]) => {
      $(`[data-add="${k}"]`, body).textContent = pend[k] ? ` +${pend[k]}` : '';
      const up = $(`[data-stat="${k}"]`, body), cap = statCap(c.level, k, c.job_key);
      up.disabled = left <= 0 || c[k] + (pend[k] || 0) >= cap; up.title = c[k] + (pend[k] || 0) >= cap ? '지금 레벨의 상한입니다' : '';
      $(`[data-dec="${k}"]`, body).disabled = !pend[k];
    });
    const any = allocSum(pend) > 0;
    ['#al-reset', '#al-preview', '#al-ok'].forEach(id => $(id, body).disabled = !any);
    if (!any) $('#al-prev', body).innerHTML = '';
    saveAlloc(c, pend);
  };
  $$('[data-stat]', body).forEach(b => b.onclick = () => { const k = b.dataset.stat; pend[k] = (pend[k] || 0) + 1; $('#al-prev', body).innerHTML = ''; sync(); });
  $$('[data-dec]', body).forEach(b => b.onclick = () => { const k = b.dataset.dec; if (pend[k] > 0) pend[k]--; if (!pend[k]) delete pend[k]; $('#al-prev', body).innerHTML = ''; sync(); });
  $('#al-reset', body).onclick = () => { pend = {}; sync(); };
  const pv = $('#al-preview', body);
  pv.onclick = () => guard(pv, async () => {
    const r = await rpc('world_combat_preview', { p_alloc: pend });
    $('#al-prev', body).innerHTML = previewText(r?.current, r?.after);
  });
  const ok = $('#al-ok', body);
  ok.onclick = async () => {
    const list = STATS.filter(([k]) => pend[k]).map(([k, n]) => `${n} +${pend[k]}`).join(' · ');
    if (!(await ask(`능력치를 이대로 올릴까요? ${list} (포인트 ${allocSum(pend)}점) 한 번 올린 능력치는 세심단 없이는 되돌릴 수 없습니다.`, { title: '능력치 확정', ok: '확정' }))) return;
    guard(ok, async () => {
      const spent = { ...pend };
      pend = {}; saveAlloc(c, pend);
      try {
        const r = await act('world_allocate_stats', { p_alloc: spent });
        return { content: `능력치 +${r?.spent ?? allocSum(spent)} · 남은 포인트 ${r?.stat_points ?? ''}` };
      } catch (e) { pend = spent; saveAlloc(c, pend); throw e; }
    });
  };
  sync();
  const save = $('#prof-save', body);
  save.onclick = async () => { if (await ask('전문화를 이대로 정할까요? 3일 동안 다시 바꿀 수 없습니다.', { title: '생활 전문화', ok: '정하기' })) guard(save, () => act('world_set_life_profession_v2', { p_gathering: $('#g-prof', body).value, p_crafting: $('#c-prof', body).value })); };
}
function profWait(c) { return c.life_changed_at ? new Date(c.life_changed_at).getTime() + 72 * 3600e3 - Date.now() : 0; }

/* ── 기술 ─────────────────────────────────────────────── */
const CAT_DESC = {
  melee: '칼·창 같은 근접 무기로 싸울 때 오릅니다. 익히면 근접 피해가 늘어납니다.',
  ranged: '활·쇠뇌로 싸울 때 오릅니다. 익히면 치명타와 원거리 피해가 늘어납니다.',
  sealing: '방울·부채·거울 같은 술법 무기로 싸울 때 오릅니다. 익히면 술법 피해가 늘어납니다.',
  analysis: '요괴의 약점을 살피며 싸울 때 오릅니다. 익히면 치명타 확률이 오릅니다.',
  guarding: '막기 자세로 공격을 받아낼 때 오릅니다.',
  first_aid: '회복약을 쓰거나 동료를 구조할 때 오릅니다.',
  tracking: '탐색과 원정으로 낯선 곳을 살필 때 오릅니다.',
  foraging: '일반 채집터에서 채집할 때 오릅니다.', herbalism: '약초 채집터에서 채집할 때 오릅니다.', mining: '광맥에서 채집할 때 오릅니다.',
  spirit_gathering: '영기가 서린 곳에서 채집할 때 오릅니다.', smithing: '단조·목공·법구 공예·직조·가죽 공예 제작법으로 만들 때 오릅니다.', alchemy: '연금 제작법으로 약제를 만들 때 오릅니다.', wardcraft: '봉인 공예 제작법으로 부적·봉인 도구를 만들 때 오릅니다.',
};
// 행동 한 번에 오르는 기술 경험(서버 world_track_specialized_skill과 같은 값).
// 단계 r → r+1에 80+8r 경험, 30단계부터 6×(r−29)²를 더함(누적 4r²+76r−80 + n(n+1)(2n+1), n=r−30, 서버 world_skill_line_xp), 최고 50단계.
const SKILL_GAIN = {
  melee: '전투 행동 +10', ranged: '전투 행동 +10', sealing: '전투 행동 +10', analysis: '전투 행동 +10', first_aid: '전투 행동 +10', guarding: '전투 행동 +10',
  mining: '채집 +8', herbalism: '채집 +8', spirit_gathering: '채집 +8', foraging: '채집 +8',
  smithing: '제작 +12', alchemy: '제작 +12', wardcraft: '제작 +12', tracking: '탐색 +5 · 이야기 +10 · 이동 +3',
};
const SKILL_CAP = 50;
const lineXp = r => { if (r <= 1) return 0; const n = Math.max(0, r - 30); return 4 * r * r + 76 * r - 80 + n * (n + 1) * (2 * n + 1); };
const SKILL_NAME = { sealing: '봉인술' }; // 제작 분야 「봉인 공예」와 이름이 겹치는 전투 계열
// 숙련 네 갈래 = 그 갈래 기술 가운데 가장 높은 단계(서버 world_skill_sync)
export const BRANCHES = [
  ['combat', '전투', 'sword', ['melee', 'ranged', 'sealing', 'analysis', 'guarding', 'first_aid']],
  ['gathering', '채집', 'leaf', ['foraging', 'herbalism', 'mining', 'spirit_gathering']],
  ['crafting', '제작', 'hammer', ['smithing', 'alchemy', 'wardcraft']],
  ['investigation', '조사', 'search', ['tracking']],
];
async function skills(body) {
  const [list, coop] = await Promise.all([load('world_skill_snapshot', undefined, { maxAge: 10000 }), RAID_ON ? load('world_coop_list', undefined, { maxAge: 60000 }).catch(() => []) : []]);
  const groups = {}, combos = [];
  (list || []).forEach(s => s.category === 'combo' ? combos.push(s) : (groups[s.category] ||= []).push(s));
  const SLOT = { base: '', extra: '추가 기술', a: '택일 ①', b: '택일 ②', master: '숙달 기술' };
  const line = cat => {
    const sk = groups[cat]; if (!sk) return '';
    const rank = Number(sk[0].rank || 1), xp = Number(sk[0].xp || 0), top = rank >= SKILL_CAP;
    const need = lineXp(rank + 1) - lineXp(rank), into = top ? need : Math.max(0, xp - lineXp(rank));
    const tiers = [...new Set(sk.map(x => x.unlock_rank))].sort((a, b) => a - b);
    const next = tiers.find(t => t > rank);
    // 택일 단계에 닿았는데 아직 고르지 않았으면 그 칸에 표시한다
    const pending = t => sk.some(x => x.unlock_rank === t && x.slot === 'a' && x.reached) && !sk.some(x => x.unlock_rank === t && x.picked);
    return `<div class="sk-line" data-cat="${cat}">
      <div class="sk-head"><b>${esc(SKILL_NAME[cat] || nameOf(cat))}</b><span class="sk-rank">${fmt.num(rank)}<small>/${SKILL_CAP}</small></span></div>
      <div class="bar sk-bar"><span style="width:${Math.max(0, Math.min(100, into / need * 100))}%"></span></div>
      <small class="muted">${top ? '최고 단계' : `${fmt.num(into)} / ${fmt.num(need)} 경험`}${next ? ` · 다음 기술 ${next}단계까지 ${fmt.num(Math.max(0, lineXp(next) - xp))}` : ''}</small>
      <ol class="sk-nodes" style="--n:${tiers.length}">${tiers.map(t => `<li><button type="button" class="sk-node ${rank >= t ? 'on' : ''} ${pending(t) ? 'pick' : ''} ${t === 50 ? 'master' : ''}" data-t="${t}" aria-label="${t}단계" title="${t}단계">${t}</button></li>`).join('')}</ol>
      <div class="sk-detail" hidden></div>
    </div>`;
  };
  const c = store.character || {};
  const KN = Object.fromEntries(BRANCHES.flatMap(([, , , cats]) => cats.map(k => [k, SKILL_NAME[k] || nameOf(k)])));
  body.innerHTML = `<div class="notice">${icon('help', 18)}<div><b>숙련과 기술</b><span>기술은 행동을 되풀이할수록 오르는 계열별 단계(최고 50)입니다. 단계마다 기술을 익히고, 13·30단계에는 추가 기술(근접·봉인술은 13·30단계도 택일), 24·43단계에는 둘 중 하나를 고르는 기술, 50단계에는 가장 강한 숙달 기술이 있습니다. 네모를 누르면 그 단계의 기술이 펼쳐집니다(빨간 점: 고를 기술이 있음).</span></div></div>
    ${Object.keys(groups).length ? `<div class="skill-groups">${BRANCHES.map(([k, n, ico, cats]) => panel(`${n} 숙련 · ${fmt.num(c[k + '_rank'] || 1)}단계`,
      `<div class="sk-lines">${cats.map(line).join('')}</div>`, { ico, cls: 'compact' })).join('')}</div>`
    : empty('익힌 기술 정보가 없습니다.')}
    ${combos.length ? panel('조합 기술', `<ul class="combo-list">${combos.map(x => {
      const req = Object.entries(x.requires || {}).map(([k, v]) => `<span class="${(x.req_ranks?.[k] || 1) >= v ? 'ok' : 'bad'}">${esc(KN[k] || nameOf(k))} ${x.req_ranks?.[k] || 1}/${v}</span>`).join(' · ');
      return `<li class="${x.unlocked ? 'on' : ''}"><b>${esc(x.skill_name)}</b>${x.unlocked ? chip('익힘', 'ok') : ''}<small>${esc(String(x.description || '').replace(/^조합 기술\([^)]*\) · /, ''))}</small><small>${req}</small></li>`; }).join('')}</ul>
      <p class="muted small">두 계열이 모두 18단계에 닿으면 열립니다. 계열마다 조합은 하나씩입니다.</p>`, { ico: 'knot' }) : ''}
    ${(coop || []).length ? panel(`협동 기술 · 전투 숙련 ${fmt.num(c.combat_rank || 1)}단계`, `<ul class="combo-list coop-list">${coop.map(x => `<li class="${x.unlocked ? 'on' : ''}">
        <b>${esc(x.name)}</b>${x.unlocked ? chip('익힘', 'ok') : chip(`전투 숙련 ${x.rank}단계`)}
        <small>${esc(x.desc || '')}</small><small>${x.target === 'ally' ? '동료 한 명' : x.target === 'all' ? '참가자 모두' : x.target === 'boss' ? '요괴' : '나'} · 영력 ${x.cost} · 다시 쓰기 ${x.cooldown}초</small></li>`).join('')}</ul>
      <p class="muted small">합동 토벌(10장 결전·봉연의 그림자)에서만 그 턴의 행동으로 고릅니다. 같은 지역 파티 원정의 합동 전투에서는 열린 기술이 확률로 저절로 나옵니다.</p>`, { ico: 'users' }) : ''}
    <p class="muted small">전투 계열(근접·원거리·봉인술)의 피해 효과는 지금 든 무기의 공격 방식에 맞는 것만 적용됩니다(치명타는 분석·조합 기술도 더함). 그 밖의 효과(주는 피해·채집량·희귀품·단서·회복·제작 품질·받는 피해·정신·침식·이동·요괴 조우)는 익히는 즉시 늘 적용되며, 효과마다 상한이 있습니다. 택일 기술은 처음 고르기는 무료, 바꾸기는 13단계 1,000전·24단계 2,000전·30단계 3,000전·43단계 5,000전입니다.</p>`;
  $$('.sk-line', body).forEach(el => {
    const sk = groups[el.dataset.cat], box = $('.sk-detail', el);
    $$('.sk-node', el).forEach(b => b.onclick = () => {
      const open = b.classList.contains('sel');
      $$('.sk-node', el).forEach(x => x.classList.remove('sel'));
      if (open) { box.hidden = true; return; }
      b.classList.add('sel');
      const t = Number(b.dataset.t), here = sk.filter(x => x.unlock_rank === t);
      box.innerHTML = here.map(s => `<div class="sk-one ${s.slot}">
          <b>${esc(s.skill_name)}</b>${SLOT[s.slot] ? ` <small class="accent">${SLOT[s.slot]}</small>` : ''}
          <span class="chip ${s.unlocked ? 'ok' : ''}">${s.unlocked ? '익힘' : s.reached && (s.slot === 'a' || s.slot === 'b') ? '고르지 않음' : `${s.unlock_rank}단계에 익힘`}</span>
          <p>${esc(String(s.description || '').replace(/^(추가|택일|숙달) 기술 · /, ''))}</p>
          ${(s.slot === 'a' || s.slot === 'b') && s.reached && !s.picked ? `<button class="btn small primary" data-pick="${s.slot}" data-t="${t}">이 기술 고르기</button>` : ''}
        </div>`).join('') + `<p class="muted small">${esc(CAT_DESC[el.dataset.cat] || '')}${SKILL_GAIN[el.dataset.cat] ? ` 얻는 경험: ${esc(SKILL_GAIN[el.dataset.cat])}.` : ''}</p>`;
      box.hidden = false;
      $$('[data-pick]', box).forEach(pb => pb.onclick = async () => {
        const other = here.find(x => x.slot !== pb.dataset.pick && (x.slot === 'a' || x.slot === 'b'));
        const fee = other?.picked ? (t === 24 ? 2000 : 5000) : 0;
        const pick = here.find(x => x.slot === pb.dataset.pick);
        if (!(await ask(`「${pick.skill_name}」을(를) 고를까요?${other ? ` 「${other.skill_name}」은(는) 쓸 수 없게 됩니다.` : ''}${fee ? `\n바꾸는 값 ${fmt.jeon(fee)}이 듭니다.` : ' 처음 고르기는 무료이고, 나중에 바꾸려면 전이 듭니다.'}`, { title: `${t}단계 택일 기술`, ok: '고르기' }))) return;
        guard(pb, () => act('world_skill_choose', { p_line: el.dataset.cat, p_tier: t, p_pick: pb.dataset.pick }));
      });
    });
  });
}

/* ── 자율 활동 ───────────────────────────────────────── */
async function idle(body) {
  const [snap, prof] = await Promise.all([load('world_idle_activity_snapshot'), load('world_combat_profile', undefined, { maxAge: 30000 }).catch(() => null)]);
  idleWeapon = prof?.current?.weapon?.type || 'melee';
  const active = snap?.active;
  const ready = active && (snap.ready || new Date(snap.ready_at) <= new Date());
  const name = IDLE.find(x => x[0] === snap?.activity_type)?.[1] || '자율 활동';
  body.innerHTML = `
    ${active ? panel('진행 중인 자율 활동', `
      <div class="idle-now"><div class="idle-ring ${ready ? 'done' : ''}">${icon(ready ? 'check' : 'hourglass', 24)}</div>
        <div><b>${esc(name)} · ${snap.duration_minutes}분</b><span id="idle-left">${ready ? '완료되었습니다. 보상을 받으세요.' : `${fmt.remain(new Date(snap.ready_at) - Date.now())} 남음`}</span>
        ${bar(Math.min(snap.elapsed_seconds || 0, snap.duration_minutes * 60), snap.duration_minutes * 60, 'xp')}</div></div>
      <div class="btn-row">${ready ? `<button class="btn primary" id="idle-claim">${icon('check', 16)}<span>보상 수령</span></button>`
        : `<button class="btn" id="idle-stop">${icon('close', 16)}<span>그만두기</span></button>`}</div>
      <p class="muted small">완료 시각은 서버가 기록합니다. 접속하지 않아도 진행되며, 한 번에 하나만 할 수 있습니다. 도중에 그만두면 지난 시간만큼만 받습니다.</p>`, { ico: 'hourglass' }) : ''}
    <div class="idle-grid">${IDLE.map(([k, n, d, ic]) => `<article class="idle-card" data-idle-card="${k}">
      <header>${icon(ic, 18)}<b>${n}</b></header><p>${d}</p>
      <div class="dur">${DURATIONS.map(([m, l]) => `<button class="btn small" data-idle="${k}" data-min="${m}" ${active ? 'disabled' : ''}><b>${l}</b><small>${esc(idleReward(k, m, store.character?.level || 1).join(' · '))}</small></button>`).join('')}</div></article>`).join('')}</div>
    <p class="muted small">자율 활동은 접속하지 않는 동안의 보조 성장입니다. 직접 탐사·전투·제작이 더 큰 보상을 줍니다.</p>`;
  const claim = $('#idle-claim', body);
  if (claim) claim.onclick = () => guard(claim, async () => { const r = await act('world_claim_idle_activity'); return { content: `${r?.message || '보상을 받았습니다.'}${r?.experience ? ` · 경험치 +${r.experience}` : ''}` }; });
  const stop = $('#idle-stop', body);
  if (stop) stop.onclick = async () => {
    const mins = Math.max(0, Math.floor((Date.now() - new Date(snap.started_at).getTime()) / 60000));
    const got = idleReward(snap.activity_type, mins, store.character?.level || 1, true).join(' · ');
    if (!(await ask(`${name}을(를) 지금 그만둘까요?\n지난 시간 ${fmt.num(mins)}분만큼만 받습니다: ${got}\n그만두면 바로 다른 행동을 할 수 있습니다.`, { title: '자율 활동 그만두기', ok: '그만두기', cancel: '계속하기', danger: true }))) return;
    guard(stop, async () => { const r = await act('world_claim_idle_activity'); return { content: r?.message || '자율 활동을 그만두었습니다.' }; });
  };
  // 현장의 「자율 휴식」에서 왔으면 휴식 칸을 짚어 준다
  let focus = null; try { focus = sessionStorage.getItem('yh-idle-focus'); sessionStorage.removeItem('yh-idle-focus'); } catch {}
  const fc = focus && $(`[data-idle-card="${focus}"]`, body);
  if (fc) { fc.classList.add('focus'); requestAnimationFrame(() => fc.scrollIntoView({ block: 'center', behavior: 'smooth' })); setTimeout(() => fc.classList.remove('focus'), 2600); }
  $$('[data-idle]', body).forEach(b => b.onclick = async () => {
    const k = b.dataset.idle, m = Number(b.dataset.min), n = IDLE.find(x => x[0] === k)?.[1] || '자율 활동', l = DURATIONS.find(x => x[0] === m)?.[1] || `${m}분`;
    const ok = await ask(`${n}을(를) ${l} 동안 할까요?\n받을 것: ${idleReward(k, m, store.character?.level || 1).join(' · ')}\n끝날 때까지 다른 자율 활동은 할 수 없고, 다 끝난 뒤에 보상을 받습니다.`, { title: '자율 활동 시작', ok: '시작', cancel: '그만두기' });
    if (ok) guard(b, () => act('world_start_idle_activity', { p_activity: k, p_duration_minutes: m }));
  });
  if (active && !ready) {
    const t = setInterval(() => {
      const left = $('#idle-left', body); if (!left) return clearInterval(t);
      const ms = new Date(snap.ready_at) - Date.now();
      if (ms <= 0) { clearInterval(t); draw(true); } else left.textContent = `${fmt.remain(ms)} 남음`;
    }, 1000);
  }
}

/* ── 칭호: 검색·분류·장착 3개·대표 칭호 ──────────────────── */
// 분류별로 묶어 카드 격자로 한꺼번에 보여 준다(더 보기 없음). 분류 칩을 누르면 그 분류만 남는다.
const TCAT_ORDER = ['운영', '레거시', '탐사', '전투', '이동', '이야기', '채집', '제작', '낚시', '도감', '교류', '비무', '세력', '성장', '비밀', '기타'];
let tq = '', tf = 'all', tcat = '', tOwned = false, tEquipped = false;
// 칭호 보기 순서(6.1.1): 분류별 · 등급 높은순 · 등급 낮은순(기기에 기억)
let tsort = (() => { try { return localStorage.getItem('yh-title-sort') || 'cat'; } catch { return 'cat'; } })();
// 칭호 등급(서버 world_title_catalog.grade)
const TGRADE = { 1: '범품', 2: '양품', 3: '진품', 4: '명품', 5: '신품' }; // 凡品·良品·珍品·名品·神品
const LEGACY_HANJA = { legacy_first_night: '第一夜', legacy_unfinished_road: '未完', legacy_ember: '殘火' };
async function titles(body) {
  const snap = await load('world_title_snapshot');
  const list = snap?.titles || [];
  const order = c => { const i = TCAT_ORDER.indexOf(c); return i < 0 ? 99 : i; };
  const cats = [...new Set(list.map(t => t.category))].sort((a, b) => order(a) - order(b));
  const countIn = c => { const l = list.filter(t => t.category === c); return `${l.filter(t => t.earned).length}/${l.length}`; };
  body.innerHTML = `
    <div class="title-head">
      <div class="chips">${chip(`얻은 칭호 ${snap?.earned_count || 0}/${snap?.total || list.length}`, 'accent')}${chip(`숨겨진 칭호 ${snap?.hidden_earned || 0}/${snap?.hidden_total || 0}`)}${chip(`장착 ${snap?.equipped_count || 0}/3`)}</div>
      <p class="muted small">칭호는 최대 3개까지 장착해 효과를 받습니다. 그와 별개로 <b>대표 칭호</b> 하나를 정하면 채팅과 프로필에 이름과 함께 보입니다.</p>
      ${presetsHtml(snap, list)}
      <label class="search"><span>${icon('search', 16)}</span><input id="t-q" type="search" placeholder="칭호 이름·조건·효과로 찾기" value="${esc(tq)}"></label>
      <div class="t-checks"><label class="check"><input type="checkbox" id="t-owned" ${tOwned ? 'checked' : ''}><span>얻은 칭호만 보기</span></label>
        <label class="check"><input type="checkbox" id="t-eq" ${tEquipped ? 'checked' : ''}><span>장착 중만 보기</span></label>
        <label class="t-sort"><span>보기</span><select id="t-sort" aria-label="칭호 보기 순서">${[['cat', '분류별'], ['grade_desc', '등급 높은순'], ['grade_asc', '등급 낮은순']].map(([v, n]) => `<option value="${v}" ${tsort === v ? 'selected' : ''}>${n}</option>`).join('')}</select></label></div>
      <p class="muted small t-grades">등급: ${Object.entries(TGRADE).map(([g, n]) => `<span class="t-grade g${g}">${n}</span>`).join(' ')} — 범품(凡品)에서 신품(神品)으로 갈수록 얻기 어렵고, 효과가 크고 여러 갈래입니다.</p>
      <div class="cat-chips"><button class="chip ${tcat ? '' : 'accent'}" data-cat="">모든 분류</button>${cats.map(c => `<button class="chip ${tcat === c ? 'accent' : ''}" data-cat="${esc(c)}">${esc(c)} <small>${countIn(c)}</small></button>`).join('')}</div>
    </div>
    <div id="t-list"></div>`;
  // 레거시(야행의 흔적) 칭호는 등급 칩 대신 옻칠 현판: 세로 낙관 「흔적」과 한자 이름을 단다
  const card = t => { const lg = t.category === '레거시'; return `<li class="t-card ${lg ? 'legacy' : ''} ${t.earned ? 'earned' : ''} ${t.equipped ? 'on' : ''} ${t.hidden && !t.earned ? 'secret' : ''}">
      ${lg ? `<span class="lg-tag" aria-hidden="true">흔적</span>${LEGACY_HANJA[t.key] ? `<span class="lg-hj">${LEGACY_HANJA[t.key]}</span>` : ''}` : ''}
      <div class="t-top">${lg ? '' : icon(t.icon || 'spark', 18)}${t.grade && !lg && !(t.hidden && !t.earned) ? `<span class="t-grade g${t.grade}">${TGRADE[t.grade] || ''}</span>` : ''}<b>${esc(t.name)}${t.new ? ' <span class="new-dot" title="새로 얻은 칭호" aria-label="새로 얻은 칭호"></span>' : ''}</b>
        ${tsort !== 'cat' ? `<small class="muted t-catl">${esc(t.category)}</small>` : ''}${t.display ? chip('대표', 'accent') : ''}${t.equipped ? chip('장착 중', 'ok') : !t.earned ? chip(t.hidden ? '숨김' : '미획득') : ''}</div>
      ${t.description ? `<p class="t-desc">${esc(t.description)}</p>` : ''}
      <p class="t-cond">조건 · ${esc(t.condition || '-')}</p>
      ${t.bonus ? `<p class="t-bonus">${esc(effectText(t.bonus).join(' · '))}</p>` : ''}
      ${!t.earned && t.progress ? (() => { const cur = Number(t.progress.cur) || 0, need = Math.max(1, Number(t.progress.need) || 1);
        return `<div class="t-prog">${bar(cur, need, 'xp')}<small>${t.progress.pct ? `${Math.round(cur / need * 100)}%` : `${fmt.num(cur)} / ${fmt.num(need)}`}</small></div>`; })() : ''}
      ${t.earned ? `<div class="t-act"><button class="btn ${t.equipped ? '' : 'primary'}" data-title="${esc(t.key)}">${t.equipped ? '장착 해제' : '장착'}</button>
        <button class="btn ghost" data-disp="${t.display ? '' : esc(t.key)}">${t.display ? '대표 내리기' : '대표로'}</button>${RAID_ON && t.hidden ? `<button class="btn ghost" data-story="${esc(t.key)}">유래</button>` : ''}</div>` : ''}</li>`; };
  const paint = () => {
    const q = tq.trim().toLowerCase();
    const rows = list.filter(t => (!tOwned || t.earned) && (!tEquipped || t.equipped)
      && (!tcat || t.category === tcat)
      && (!q || [t.name, t.description, t.condition, effectText(t.bonus || {}).join(' ')].join(' ').toLowerCase().includes(q)));
    // 등급순: 신품→범품(또는 반대)으로 묶고, 같은 등급 안은 얻은 것 먼저. 얻지 못한 숨김 칭호는 등급을 드러내지 않게 맨 끝 「숨김」에
    const gradeOf = t => (t.hidden && !t.earned) || t.category === '레거시' ? 0 : Number(t.grade) || 1;
    const byGrade = tsort !== 'cat';
    const gLabel = g => g ? `${TGRADE[g] || ''}` : '숨김·기타';
    const gradeKeys = [...new Set(rows.map(gradeOf))].sort((a, b) => !a ? 1 : !b ? -1 : tsort === 'grade_desc' ? b - a : a - b);
    const groups = byGrade
      ? gradeKeys.map(g => [g, rows.filter(t => gradeOf(t) === g).sort((a, b) => (b.earned ? 1 : 0) - (a.earned ? 1 : 0) || order(a.category) - order(b.category))])
      : cats.map(c => [c, rows.filter(t => t.category === c)]).filter(([, l]) => l.length);
    const headOf = (k, l) => byGrade
      ? `${k ? `<span class="t-grade g${k}">${esc(gLabel(k))}</span>` : esc(gLabel(k))} <small class="muted">${l.length}개 · 얻음 ${l.filter(t => t.earned).length}</small>`
      : `${esc(k)} <small class="muted">${l.length}개 · 얻음 ${countIn(k)}</small>`;
    $('#t-list', body).innerHTML = groups.length ? groups.map(([c, l]) => `<section class="t-group"><h3 class="sub-h">${headOf(c, l)}</h3>
        <ul class="t-grid">${l.map(card).join('')}</ul></section>`).join('')
      : empty('조건에 맞는 칭호가 없습니다.', 'search');
    $$('[data-title]', body).forEach(b => b.onclick = () => guard(b, async () => {
      const r = await act('world_title_equip', { p_title_key: b.dataset.title });
      return { content: r?.equipped ? '칭호를 장착했습니다. (3개를 넘으면 가장 오래된 칭호가 내려갑니다)' : '칭호를 내렸습니다.' };
    }));
    $$('[data-disp]', body).forEach(b => b.onclick = () => guard(b, () => act('world_title_set_display', { p_title_key: b.dataset.disp || null })));
    // 숨김 칭호 유래(6.1.1): 그 칭호를 두고 이야기 속 인물이 하는 말
    $$('[data-story]', body).forEach(b => b.onclick = () => guard(b, async () => {
      const r = await rpc('world_title_story', { p_title: b.dataset.story });
      if (!r?.lines?.length) { toast('이 칭호의 유래는 아직 전해지지 않았습니다.'); return null; }
      (await import('../factionquest.js')).playDialogue({ title: r.title, lines: r.lines, cast: r.cast }, null); return null;
    }));
  };
  bindPresets(body, snap);
  $('#t-q', body).oninput = e => { tq = e.target.value; paint(); };
  $('#t-owned', body).onchange = e => { tOwned = e.target.checked; paint(); };
  $('#t-eq', body).onchange = e => { tEquipped = e.target.checked; paint(); };
  $('#t-sort', body).onchange = e => { tsort = e.target.value; try { localStorage.setItem('yh-title-sort', tsort); } catch {} paint(); };
  $$('[data-cat]', body).forEach(b => b.onclick = () => { tcat = b.dataset.cat; $$('[data-cat]', body).forEach(x => x.classList.toggle('accent', x === b)); paint(); });
  paint();
  // 한 번 본 새 칭호는 확인 처리한다(이번 화면에서는 점이 남고, 다음부터는 사라진다)
  if (list.some(t => t.new)) markTitlesSeen();
}

// 칭호 묶음: 처음 3칸, 정해진 칭호 셋을 얻을 때마다 한 칸씩(최대 6칸). 지금 장착한 칭호(최대 3)와 대표 칭호를 저장해 두고 한 번에 바꿔 낀다(서버 world_title_preset_*)
function presetsHtml(snap, list) {
  const nm = Object.fromEntries(list.map(t => [t.key, t.name]));
  const eq = list.filter(t => t.equipped).map(t => t.key).sort().join(','), disp = snap?.display || null;
  const open = Number(snap?.preset_slots || 3), locked = (snap?.preset_unlocks || []).filter(u => !u.earned);
  return `<div class="t-presets">${Array.from({ length: open }, (_, i) => i + 1).map(n => {
    const p = (snap?.presets || []).find(x => x.slot === n);
    const now = p && [...(p.titles || [])].sort().join(',') === eq && (p.display || null) === disp;
    return `<div class="t-preset ${p ? '' : 'empty'} ${now ? 'now' : ''}">
      <input class="t-pname" data-pname="${n}" maxlength="12" value="${esc(p?.name || '')}" placeholder="묶음 ${n}" aria-label="묶음 ${n} 이름">
      <p class="t-pbody">${p ? `${(p.titles || []).map(k => esc(nm[k] || '?')).join(' · ') || '장착 없음'}${p.display ? `<small>대표 · ${esc(nm[p.display] || '?')}</small>` : ''}` : '<small>비어 있음 · 지금 장착한 칭호를 저장하세요</small>'}</p>
      <div class="t-pact">${p ? `<button class="btn small ${now ? '' : 'primary'}" data-papply="${n}" ${now ? 'disabled' : ''}>${now ? '쓰는 중' : '바꿔 끼기'}</button>` : ''}
        <button class="btn small ghost" data-psave="${n}">${p ? '덮어쓰기' : '저장'}</button>${p ? `<button class="chip-x" data-pclear="${n}" title="비우기" aria-label="묶음 비우기">×</button>` : ''}</div></div>`; }).join('')}
    ${locked.map(u => `<div class="t-preset locked">${icon('chest', 16)}<p class="t-pbody"><b>잠긴 칸</b><small>「${esc(u.name)}」 칭호를 얻으면 열립니다 · ${esc(u.condition)}</small></p></div>`).join('')}</div>`;
}
function bindPresets(body, snap) {
  const has = n => (snap?.presets || []).some(x => x.slot === n);
  $$('[data-papply]', body).forEach(b => b.onclick = () => guard(b, () => act('world_title_preset_apply', { p_slot: Number(b.dataset.papply) })));
  $$('[data-psave]', body).forEach(b => b.onclick = async () => {
    const n = Number(b.dataset.psave);
    if (has(n) && !(await ask('지금 장착한 칭호와 대표 칭호로 이 묶음을 덮어씁니다.', { title: '묶음 덮어쓰기', ok: '덮어쓰기' }))) return;
    guard(b, () => act('world_title_preset_save', { p_slot: n, p_name: $(`[data-pname="${n}"]`, body)?.value || '' }));
  });
  $$('[data-pclear]', body).forEach(b => b.onclick = async () => {
    if (!(await ask('이 묶음을 비웁니다. 장착한 칭호는 그대로 둡니다.', { title: '묶음 비우기', ok: '비우기', danger: true }))) return;
    guard(b, () => act('world_title_preset_clear', { p_slot: Number(b.dataset.pclear) }));
  });
}

/* ── 세력: 소속 임무·일일 보급·대세력 ─────────────────────── */
const PERKS = {
  night_office: '원정·임무 보급이 안정적입니다(보급 보너스).', red_moon_cult: '강행 태세 원정의 전리품 +15%. 위험한 지역에 강합니다.',
  black_lotus: '정보·암시장에 밝습니다.', north_league: '원정 중 받는 피해 -20%.', river_alliance: '가방 +6칸. 교역과 운송에 강합니다.',
  southern_remnant: '원정 채집량 +15%.', mandate_court: '원정 답사도 상승 +20%.',
};
const HOSTILE = { night_office: ['red_moon_cult', 'black_lotus'], red_moon_cult: ['night_office', 'north_league'], black_lotus: ['night_office', 'mandate_court'],
  north_league: ['red_moon_cult'], river_alliance: [], southern_remnant: ['mandate_court'], mandate_court: ['black_lotus'] };
// 가입을 받는 곳(서버 world_faction_join_regions와 같음): 거점 · 본부 정청 · 그 세력의 들머리 지역. 가입은 레벨 5부터
const JOIN_AT = { night_office: ['hq_yard', 'hq_dorm', 'ghost_bamboo'], red_moon_cult: ['red_moon_fort', 'hq_yard', 'bone_market', 'red_plain'], black_lotus: ['hidden_bazaar', 'hq_yard', 'lamp_alley'],
  north_league: ['iron_monastery', 'hq_yard', 'snow_hollow'], river_alliance: ['river_ferry', 'hq_yard', 'salt_village'], southern_remnant: ['ember_village', 'hq_yard', 'ember_pass'],
  mandate_court: ['star_observatory', 'hq_yard', 'hq_dorm', 'star_hill'] };
const JOIN_LV = 5;
const BASE = { night_office: 'hq_yard', red_moon_cult: 'red_moon_fort', black_lotus: 'hidden_bazaar', north_league: 'iron_monastery', river_alliance: 'river_ferry', southern_remnant: 'ember_village', mandate_court: 'star_observatory' };

async function openFactionGuide(id) {
  const f = MAJOR_FACTIONS[id]; if (!f) return;
  const map = await load('world_map_snapshot', undefined, { maxAge: 30000 }).catch(() => null);
  const base = (map?.regions || []).find(r => r.region_id === BASE[id]), here = currentRegion(map), c = store.character;
  const atBase = (JOIN_AT[id] || [BASE[id]]).includes(here?.region_id);
  const places = (JOIN_AT[id] || [BASE[id]]).map(r => (map?.regions || []).find(x => x.region_id === r)?.region_name || nameOf(r)).join('·');
  const m = openModal({ title: `${f.name} 가입 안내`, body: `<div class="faction-guide">
    <p class="desc">${esc(f.desc)}</p>
    <ol class="guide-steps">
      <li><b>거점으로 가기</b><span>${esc(base?.region_name || nameOf(BASE[id]))}${base ? ` · ${esc(base.territory_name || '')} · 레벨 ${base.min_level}부터` : ''}. 지도에서 목적지로 고르면 경유지를 거쳐 한 번에 이동합니다.</span></li>
      <li><b>가입 조건 채우기</b><span>레벨 ${JOIN_LV}부터. ${esc(f.entry)}. ${esc(places)} 가운데 한 곳에서 「가입 신청」을 누르면 서버가 조건을 확인합니다.</span></li>
      <li><b>한 세력만</b><span>대세력은 하나만 들 수 있습니다. 이미 다른 대세력에 들어 있다면 가입할 수 없습니다.</span></li>
    </ol>
    <dl class="kv"><div><dt>혜택</dt><dd>${esc(PERKS[id] || '')}</dd></div><div><dt>적대</dt><dd>${(HOSTILE[id] || []).map(x => esc(MAJOR_FACTIONS[x]?.name)).join(', ') || '없음'}</dd></div>
      <div><dt>지금 위치</dt><dd>${esc(c.location)}${atBase ? ' (거점에 있음)' : ''}</dd></div></dl>
    <p class="muted small">가입하면 전용 거점 콘텐츠·임무·세력 채팅을 쓸 수 있고, 적대 세력 지역에서는 견제를 받을 수 있습니다.</p>
    <div class="btn-row">${atBase && (c.level || 1) >= JOIN_LV ? `<button class="btn primary" data-join-now="${id}">가입 신청</button>` : atBase ? `<span class="hint">${icon('pin', 14)} 레벨 ${JOIN_LV}부터 가입할 수 있습니다.</span>`
      : base && !base.level_locked ? `<button class="btn primary" data-go="${BASE[id]}">${icon('route', 16)}<span>거점으로 출발</span></button>` : ''}
      <button class="btn" data-show="${BASE[id]}">${icon('map', 16)}<span>지도에서 보기</span></button></div></div>` });
  $('[data-go]', m)?.addEventListener('click', e => guard(e.currentTarget, async () => { const r = await act('world_travel_route', { p_region_id: BASE[id] }); closeModal(); return r; }));
  $('[data-show]', m)?.addEventListener('click', () => { closeModal(); focusRegion(BASE[id]); window.yahangGo('map', 'world'); });
  $('[data-join-now]', m)?.addEventListener('click', e => guard(e.currentTarget, async () => { const r = await act('world_join_major_faction', { p_faction_id: id }); closeModal(); return r; }));
}
// 세력 판도: 세력마다 조사원·지배 지역·영향력, 관계, 다투는 지역, 최근 소식
function boardPanel(b) {
  const nm = id => b.factions.find(f => f.id === id)?.name || nameOf(id) || '무주';
  const dot = id => `<span class="fdot" style="--fc:${factionColor(id)}"></span>`;
  const rels = b.relations.filter(r => b.mine ? (r.a === b.mine || r.b === b.mine) : Math.abs(r.score) >= 15)
    .sort((x, y) => y.score - x.score);
  const ago = t => { const m = Math.round((Date.now() - new Date(t)) / 60000); return m < 60 ? `${m}분 전` : m < 1440 ? `${Math.round(m / 60)}시간 전` : `${Math.round(m / 1440)}일 전`; };
  return panel('세력 판도', `
    <p class="muted small">대세력 조사원이 안전지대 밖에서 토벌·탐색·채집·원정을 하면 그 지역에 세력 영향력이 쌓이고, 한 시간마다 정산해 지배 세력이 바뀝니다. 안전지대는 바뀌지 않습니다. 내 세력이 지배하는 곳에서는 채집 +8%·희귀품 +3%·회복량 +5%, 적대 세력이 지배하는 곳에서는 요괴 조우 +8%·정신 손실 +5%, 분쟁 중인 곳은 모두에게 희귀품 +3%·요괴 조우 +5%. 조사원이 적은 세력은 쌓는 영향력에 인원 보정(√(가장 많은 세력 인원 ÷ 우리 인원), 최대 ×2.5)이 붙습니다.</p>
    <ul class="fboard">${b.factions.map(f => `<li class="${f.id === b.mine ? 'mine' : ''}" style="--fc:${factionColor(f.id)}"><b>${esc(f.name)}${f.id === b.mine ? ' <small class="accent">내 세력</small>' : ''}</b>조사원 ${f.members} · 지배 ${f.regions}곳 · 영향력 ${fmt.num(f.influence)}${f.boost > 1 ? ` · 인원 보정 ×${f.boost}` : ''}</li>`).join('')}</ul>
    <div class="grid-2" style="margin-top:8px">
      <div><h3 class="small">${b.mine ? `${esc(nm(b.mine))}의 관계` : '세력 관계'}</h3>
        <ul class="frel">${rels.map(r => { const o = b.mine ? (r.a === b.mine ? r.b : r.a) : null;
          return `<li><span>${o ? `${dot(o)}${esc(nm(o))}` : `${dot(r.a)}${esc(nm(r.a))} · ${dot(r.b)}${esc(nm(r.b))}`}</span><b class="stance-${esc(r.stance.split(' ')[0])}">${esc(r.stance)} ${r.score > 0 ? '+' : ''}${r.score}</b></li>`; }).join('') || '<li class="muted">두드러진 관계가 없습니다.</li>'}</ul>
        <p class="muted small">다른 세력 조사원과 한 파티로 활동하면 관계가 오르고, 같은 지역에서 영향력을 다투면 내려갑니다. 동맹(40 이상) 세력 조사원과 같은 곳에 있으면 단서 +5%·희귀품 +2%, 적대(−40 이하)면 정신 손실 +5%.</p></div>
      <div><h3 class="small">다투는 지역</h3>
        <ul class="fregion">${b.regions.slice(0, 8).map(r => `<li><span>${dot(r.control)}${esc(r.name)}${r.contested ? ' <b class="contest">분쟁 중</b>' : ''}${r.control !== r.home ? ` <small class="muted">(본래 ${esc(nm(r.home))})</small>` : ''}</span><small>${r.top.map(t => `${esc(nm(t.f))} ${t.p}`).join(' · ')}</small></li>`).join('') || '<li class="muted">아직 영향력을 다투는 곳이 없습니다.</li>'}</ul>
        ${b.log.length ? `<h3 class="small" style="margin-top:8px">소식</h3><ul class="flog">${b.log.slice(0, 6).map(l => `<li><span>${esc(l.text)}</span><small>${ago(l.at)}</small></li>`).join('')}</ul>` : ''}</div>
    </div>`, { ico: 'flag' });
}

// 세력 화면: 칸 단추만 두고 누르면 팝업으로 연다(상점처럼). 세력 판도만 화면에 그대로 보인다.
// 팝업 안에서 행동하면 화면이 'changed'로 다시 그려질 때 열린 팝업도 새 값으로 다시 채운다.
let fx = null;
const missionsHtml = mine => mine.length ? `<ul class="mission-list">${mine.map(m => {
  const done = m.progress >= m.target_count;
  return `<li><div><b>${esc(m.title)}</b><small>${esc(m.description || '')}</small>
    <div class="mini-bar"><span style="width:${Math.min(100, m.progress / m.target_count * 100)}%"></span></div>
    <small class="muted">${Math.min(m.progress, m.target_count)}/${m.target_count} · 보상 경험치 ${m.reward_xp}${m.reward_items ? ' · ' + esc(itemsText(m.reward_items)) : ''}</small></div>
    ${m.claimed ? chip('완료', 'ok') : `<button class="btn small ${done ? 'primary' : ''}" data-mission="${esc(m.mission_id)}" ${done ? '' : 'disabled'}>${done ? '보상 받기' : '진행 중'}</button>`}</li>`; }).join('')}</ul>` : empty('진행할 수 있는 임무가 없습니다.');
const baseHtml = (c, base, board) => { const major = c.major_faction_id; return `
  <p class="desc">${esc(MAJOR_FACTIONS[major]?.desc || '')}</p><p class="accent small">${esc(PERKS[major] || '')}</p>
  <div class="chips">${chip(`평판 ${fmt.num(c.faction_reputation)}`, 'accent')}${(() => { const bst = board?.factions?.find(f => f.id === major)?.boost; return bst > 1 ? chip(`인원 보정 영향력 ×${bst}`, 'ok') : ''; })()}${chip(`거점: ${base?.base_region_name || nameOf(base?.base_region_id)}`)}${base?.at_base ? chip('거점에 있음', 'ok') : chip('거점 밖')}</div>
  ${(base?.contents || []).length ? `<ul class="mission-list">${base.contents.map(x => `<li><div><b>${esc(x.title)}</b><small>${esc(x.description || '')}</small><small class="muted">Lv.${x.min_level}+${x.reward ? ' · ' + esc(itemsText(x.reward.items || x.reward)) : ''}</small></div>
    ${x.used_today ? chip('오늘 완료') : `<button class="btn small" data-base="${esc(x.content_id)}" ${base.at_base && c.level >= x.min_level ? '' : 'disabled'}>수행</button>`}</li>`).join('')}</ul>
    ${base.at_base ? '' : `<p class="hint">${icon('pin', 14)} 거점 콘텐츠는 ${esc(base.base_region_name || '거점')}에 있을 때 이용할 수 있습니다.</p>`}` : empty('이용할 수 있는 거점 콘텐츠가 없습니다.')}
  <div class="btn-row" style="margin-top:8px"><button class="btn small ghost" id="leave-faction">세력 떠나기</button></div>`; };
function popOf(key) {
  const { c, mine, base, board, fq } = fx;
  if (key === 'missions') return [`${nameOf(c.faction_key)} 임무`, missionsHtml(mine)];
  if (key === 'base') return [`${nameOf(c.major_faction_id)} 거점`, baseHtml(c, base, board)];
  const t = fq?.faction_id && fqPops(fq).find(x => x[0] === key);
  return t ? [t[1], fqPopHtml(key, fq)] : null;
}
function bindPop(root) {
  const { c, fq } = fx, major = c.major_faction_id;
  $$('[data-mission]', root).forEach(b => b.onclick = () => guard(b, () => act('world_faction_mission_action', { p_mission_id: b.dataset.mission })));
  $$('[data-base]', root).forEach(b => b.onclick = () => guard(b, () => act('world_faction_base_action', { p_content_id: b.dataset.base })));
  const lv = $('#leave-faction', root);
  if (lv) lv.onclick = async () => { if (await ask(`${nameOf(major)}에서 나갈까요?\n평판이 0이 되고 세력 채팅·거점·세력 효과가 사라집니다. 쌓은 영향력은 세력에 남습니다. 떠난 뒤 12시간이 지나야 다른 세력에 가입할 수 있습니다.`, { title: '세력 떠나기', ok: '떠나기', danger: true })) guard(lv, async () => { const r = await act('world_leave_major_faction'); closeModal(); return r; }); };
  if (fq?.faction_id) bindFaction(root, fq);
}
function openPop(key) {
  const p = popOf(key); if (!p) return;
  const m = openModal({ title: p[0], body: p[1], wide: key === 'vault' || key === 'donate' });
  m.dataset.fpop = key; bindPop($('.modal-body', m));
}
function refreshPop() {
  const m = $('#modal'), key = m?.dataset.fpop; if (!key) return;
  const p = popOf(key); if (!p) { closeModal(); return; }
  const mb = $('.modal-body', m), top = mb.scrollTop;
  mb.innerHTML = `<div>${p[1]}</div>`; mb.scrollTop = top; bindPop(mb);
}

async function faction(body) {
  const [missions, base, map, board, fq] = await Promise.all([load('world_faction_mission_snapshot'), load('world_faction_base_snapshot').catch(() => null), load('world_map_snapshot', undefined, { maxAge: 30000 }).catch(() => null), load('world_faction_board', undefined, { maxAge: 60000 }).catch(() => null),
    store.character?.major_faction_id ? load('world_faction_snapshot').catch(() => null) : null]);
  const c = store.character, here = currentRegion(map);
  const mine = (missions || []).filter(m => m.faction_key === c.faction_key || m.eligible);
  const major = c.major_faction_id;
  fx = { c, mine, base, board, fq };
  const supplied = !!store.hud?.supply?.claimed_today;
  const tile = (k, label, ico, dot, extra = '') => `<button class="tile" data-fpop="${k}" ${extra}>${icon(ico, 20)}<span>${esc(label)}</span>${dot ? '<i class="tile-dot" aria-label="할 일 있음"></i>' : ''}</button>`;
  const tiles = [
    tile('missions', '소속 임무', 'scroll', mine.some(m => !m.claimed && m.progress >= m.target_count)),
    `<button class="tile ${supplied ? '' : 'primary'}" id="supply" ${supplied ? 'disabled' : ''} title="소속 부서에서 하루 한 번 보급품을 받습니다">${icon('bag', 20)}<span>${supplied ? '보급 받음' : '일일 보급'}</span></button>`,
    ...(major ? [tile('base', '거점', 'shield', false)] : []),
    ...(major && fq?.faction_id ? fqPops(fq).map(([k, l, ico, dot]) => tile(k, l, ico, dot)) : []),
  ].join('');
  body.innerHTML = `
    ${panel(major ? `${nameOf(major)}${fq?.ranks ? ` · ${esc(fq.ranks[(fq.rank || 1) - 1] || '')}` : ''}` : `${nameOf(c.faction_key)}`, `
      ${major && fq?.faction_id ? `<div class="chips">${chip(`평판 ${fmt.num(fq.rep)}`, 'accent')}${chip(`공훈 ${fmt.num(fq.merit)}`, 'ok')}${base?.at_base ? chip('거점에 있음', 'ok') : ''}</div>` : ''}
      <div class="act-tiles fq-tiles">${tiles}</div>
      ${supplied ? `<p class="muted small">다음 보급: ${store.hud.supply.next_at ? new Date(store.hud.supply.next_at).toLocaleString('ko-KR', { month: 'numeric', day: 'numeric', hour: '2-digit', minute: '2-digit' }) : '내일'}</p>` : ''}`, { ico: 'flag' })}
    ${major ? '' : panel('대세력', `<p class="desc">대세력은 세계의 큰 흐름을 이끄는 조직입니다. 가입하면 전용 거점·임무·보상과 세력 채팅을 이용할 수 있습니다. 가입하려면 그 세력의 거점까지 직접 가야 합니다.</p>
        <div class="faction-grid">${Object.entries(MAJOR_FACTIONS).map(([k, f]) => {
          const at = (JOIN_AT[k] || [BASE[k]]).includes(here?.region_id);
          return `<article class="faction">
          <header><b>${esc(f.name)}</b>${chip(f.type)}</header><p>${esc(f.desc)}</p><small class="accent">${esc(PERKS[k] || '')}</small><small class="muted">가입 조건: ${esc(f.entry)} · 거점 ${esc(nameOf(f.base))}</small>
          <div class="join-row" id="jr-${k}"><button class="btn small ${at ? 'primary' : ''}" data-join="${k}">가입 신청</button><button class="btn small ghost" data-guide="${k}">${icon('help', 14)}<span>자세히 알아보기</span></button></div></article>`; }).join('')}</div>`, { ico: 'shield' })}
    ${board ? boardPanel(board) : ''}`;
  $$('[data-fpop]', body).forEach(b => b.onclick = () => openPop(b.dataset.fpop));
  const sup = $('#supply', body); if (sup) sup.onclick = () => guard(sup, async () => { const r = await act('world_claim_faction_supply'); if (store.hud) store.hud.supply = { claimed_today: true }; if (r?.letter) showLetter(r.letter); return r; });
  $$('[data-guide]', body).forEach(b => b.onclick = () => openFactionGuide(b.dataset.guide));
  $$('[data-join]', body).forEach(b => b.onclick = async () => {
    const k = b.dataset.join, row = $(`#jr-${k}`, body);
    if ((store.character?.level || 1) < JOIN_LV || !(JOIN_AT[k] || [BASE[k]]).includes(here?.region_id)) {
      // 가입할 수 없는 곳·레벨: 짧은 안내와 함께 가이드 버튼을 바로 옆에 둔다
      row.querySelector('.join-msg')?.remove();
      row.insertAdjacentHTML('beforeend', `<p class="join-msg hint">${icon('pin', 14)} ${(store.character?.level || 1) < JOIN_LV ? `레벨 ${JOIN_LV}부터 가입할 수 있습니다.` : `${esc((JOIN_AT[k] || [BASE[k]]).map(r => nameOf(r)).join('·'))} 가운데 한 곳에서 가입할 수 있습니다.`}</p>`);
      return;
    }
    if (await ask(`${MAJOR_FACTIONS[k].name}에 가입할까요? 대세력은 하나만 들 수 있습니다.`, { title: '대세력 가입', ok: '가입하기' })) guard(b, () => act('world_join_major_faction', { p_faction_id: k }));
  });
  refreshPop();
  // 현장 「세력」 칸·퀘스트 칸에서 넘어오면 바로 그 팝업을 연다
  try { const k = sessionStorage.getItem('yh-fpop'); if (k) { sessionStorage.removeItem('yh-fpop'); openPop(k); } } catch {}
}
