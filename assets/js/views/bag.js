// 가방: 소지품 · 장비 · 제작. 제작은 어디서나 가능하고, 레시피의 지정 장소에서 하면 품질 보너스를 받는다.
import { db, store, on, act, rpc, toast, openModal, closeModal, friendlyError, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar, bagLimit, bagUsed, effectText, brief, stackOf } from '../core.js';
import { load, invalidate, panel, chip, loading, errorBox, safeZones } from './common.js';
import { equipRowLi, eqMini, bindRepair, enhancedTraits, DUR_NOTE } from './character.js';
import { tokenRowHtml } from '../bond.js';
import { openItemInfo, loadLocks, isLocked, gearBlock, gearReqHtml, USABLE, GEAR, SLOTS, slotOf, useItem } from './item.js';

const SUBS = [['items', '소지품', 'bag'], ['equip', '장비', 'shield'], ['craft', '제작', 'hammer']];
const CATS = [['all', '전체'], ['consumable', '소모품'], ['material', '재료'], ['gear', '장비'], ['etc', '기타']];
const LOC_BONUS = 12; // 서버 world_craft_item과 같은 값
// 서버가 같은 장소로 인정하는 옛 지명
const LOC_ALIAS = { '야행국 본부 정청': ['본부 로비', '야행국 본부 · 정청'], '연무장·팔괘진': ['훈련실', '야행국 본부 · 연무장'], '장서각 지하서고': ['기록 보관실', '야행국 본부 · 장서각'] };
const atPlace = (loc, here) => !!loc && (loc === here || (LOC_ALIAS[loc] || []).includes(here));
let el, sub = 'items', cat = 'all', craftFilter = 'can', off = [], q = '', cq = '';
// 제작 분야(서버 world_crafting_recipes.craft_field). 아무것도 고르지 않으면 모든 분야를 보인다.
const FIELDS = ['smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking'];
const craftFields = new Set();
// 만드는 것(장착 부위·소모품·재료)으로 거르기, 제작법 정렬(가능 먼저 · 레벨 낮은순 · 레벨 높은순)
const craftKinds = new Set();
let craftSort = 'can';
// 즐겨찾는 제작법(서버 world_craft_favorites, 30개까지): 접속 동안 한 번 읽고, 별을 누르면 서버가 돌려준 목록으로 바꾼다(7.4.1)
const FAV_MAX = 30;
// 별 하나(빈 별 = 즐겨찾기 아님, 채운 별 = 즐겨찾기). 공용 아이콘의 별은 선만 그려 꽃처럼 보여 따로 그린다(7.4.2)
const STAR = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M12 2.8l2.85 5.95 6.55.8-4.8 4.55 1.2 6.5L12 17.4l-5.8 3.2 1.2-6.5-4.8-4.55 6.55-.8z" stroke-linejoin="round"/></svg>';
let favs = null;
const loadFavs = () => favs ? Promise.resolve(favs) : rpc('world_craft_favs').then(r => (favs = new Set(r || []))).catch(() => (favs = new Set()));
const KIND_LABEL = { weapon: '무기', armor: '방어구', hat: '관모', shoes: '신', norigae: '노리개', amulet: '호신부', mask: '탈', tool: '채집 도구', explore: '탐사 도구', fishing: '낚싯대', consumable: '소모품', material: '재료', etc: '기타' };
// 정렬: 기본(단계) · 획득순 · 이름순 · 희귀도순, 각각 정순·역순. 고른 정렬은 이 기기에 기억한다.
const SORTS = { tier: ['기본(단계)', '낮은 단계 먼저', '높은 단계 먼저'], acquired: ['획득순', '최근 얻은 것 먼저', '오래전에 얻은 것 먼저'],
  name: ['이름순', '가나다순', '가나다 역순'], rarity: ['희귀도순', '신품 먼저', '범품 먼저'] };
const RARITY = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4 };
let sortKey = 'tier', sortRev = false;
try { const v = JSON.parse(localStorage.getItem('yh-bag-sort') || 'null'); if (v && SORTS[v.k]) { sortKey = v.k; sortRev = !!v.r; } } catch {}
const saveSort = () => { try { localStorage.setItem('yh-bag-sort', JSON.stringify({ k: sortKey, r: sortRev })); } catch {} };
// 물품별 마지막으로 얻은 시각(서버 world_item_acquired). 기록이 없는 물품은 오래전에 얻은 것으로 본다.
async function acquiredMap() {
  try { const { data, error } = await db.from('world_item_acquired').select('item_id,acquired_at'); if (error) return new Map(); return new Map((data || []).map(r => [r.item_id, Date.parse(r.acquired_at) || 0])); }
  catch { return new Map(); }
}
function sorter(acq) {
  const byName = (a, b) => nameOf(a.id).localeCompare(nameOf(b.id), 'ko');
  const base = {
    tier: (a, b) => (a.it?.tier || 0) - (b.it?.tier || 0) || byName(a, b),
    acquired: (a, b) => (acq.get(b.id) || 0) - (acq.get(a.id) || 0) || byName(a, b),
    name: byName,
    rarity: (a, b) => (RARITY[b.it?.rarity] ?? 0) - (RARITY[a.it?.rarity] ?? 0) || (b.it?.tier || 0) - (a.it?.tier || 0) || byName(a, b),
  }[sortKey];
  return sortRev ? (a, b) => base(b, a) : base;
}
let matFocus = null, recipeFocus = null; // 물품 정보에서 넘어온 제작 거르기
window.addEventListener('yh-craft-focus', e => { matFocus = e.detail?.material || null; recipeFocus = e.detail?.recipe || null; if (matFocus || recipeFocus) craftFilter = 'all';
  // 퀘스트에서 넘어온 「○○ 만들기」: 검색칸에 그 이름을 넣어 둔다(7.4.6)
  if (e.detail?.search) cq = e.detail.search; });

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'items';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}</p><h1>가방</h1></div><button class="btn small ghost" id="open-storage" title="창고에 무엇이 있는지 봅니다. 넣고 꺼내기는 안전지대에서만 됩니다.">${icon('chest', 15)}<span>창고 보기</span></button></div>
    ${segmented('bag-sub', SUBS, sub)}<div id="bag-body"></div>`;
  bindSegmented(el, 'bag-sub', k => { sub = k; window.history.replaceState(null, '', `#/bag/${k}`); draw(); });
  $('#open-storage', el).onclick = () => import('./services.js').then(m => m.openStorage());
  off.forEach(f => f()); off = [on('changed', ({ name } = {}) => { if (/craft|storage|travel|field_move/.test(name || '')) invalidate('world_storage_snapshot'); draw(true); })];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#bag-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try {
    const inv = await load('world_inventory_snapshot');
    const head = $('.view-head .eyebrow', el); if (head) head.innerHTML = `${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}`;
    // 제작: 안전지대에서는 창고 재료도 쓴다(서버 world_craft_item). 창고 수량은 30초 동안 다시 쓰고, 제작·창고·이동 뒤에는 새로 읽는다.
    const stg = sub === 'craft' ? await load('world_storage_snapshot', undefined, { maxAge: 30000 }).catch(() => null) : null;
    await ({ items, equip, craft })[sub](body, inv, stg);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

function catalogMap(inv) { return new Map((inv.catalog || []).map(i => [i.id, i])); }
const catOf = i => !i ? 'etc' : GEAR.has(i.category) ? 'gear' : i.category === 'consumable' ? 'consumable' : /material/.test(i.category) ? 'material' : 'etc';

// 같은 계열의 더 높은 단계 도구는 낮은 단계 도구가 필요한 제작법도 만든다(서버 world_tool_lines·world_tool_covers와 같다)
// 도구 계열(서버 world_tool_lines와 같음, supabase/gen71/data_life.py가 만든 줄): 같은 계열 높은 단계가 낮은 단계 대신 쓰인다
const TOOL_LINE = { ore_pick: ['pick', 1], t4_gather: ['pick', 4], spirit_sickle: ['sickle', 2], spirit_lantern: ['lantern', 2], spirit_compass: ['explore', 3], fishing_rod: ['rod', 1], spirit_rod: ['rod', 2], seal_knife: ['carve', 2], field_knife: ['knife', 1], field_knife_2: ['knife', 2], t3_gather: ['knife', 3], t5_gather: ['knife', 5], t6_gather: ['knife', 6], lt_pick_2: ['pick', 2], lt_pick_3: ['pick', 3], lt_pick_5: ['pick', 5], lt_pick_6: ['pick', 6], lt_knife_4: ['knife', 4], lt_knife_7: ['knife', 6], lt_sickle_4: ['sickle', 4], lt_sickle_6: ['sickle', 6], lt_lantern_4: ['lantern', 4], lt_lantern_6: ['lantern', 6], lt_staff_2: ['explore', 2], lt_compass_4: ['explore', 4], lt_compass_5: ['explore', 5], lt_compass_6: ['explore', 6], lt_rod_3: ['rod', 3], lt_rod_4: ['rod', 4], lt_rod_5: ['rod', 5], lt_rod_6: ['rod', 6], lt_hammer_2: ['hammer', 2], lt_hammer_4: ['hammer', 4], lt_hammer_6: ['hammer', 6], lt_needle_2: ['needle', 2], lt_needle_4: ['needle', 4], lt_needle_6: ['needle', 6], lt_still_2: ['still', 2], lt_still_4: ['still', 4], lt_still_6: ['still', 6], lt_carve_4: ['carve', 4], lt_carve_6: ['carve', 6], lt_cook_2: ['cook', 2], lt_cook_4: ['cook', 4], lt_cook_6: ['cook', 6] };
const toolCovers = (have, need) => have === need || (TOOL_LINE[have] && TOOL_LINE[need] && TOOL_LINE[have][0] === TOOL_LINE[need][0] && TOOL_LINE[have][1] >= TOOL_LINE[need][1]);
const CAT_SHORT = { consumable: '소모', material: '재료', craft_material: '재료', tool: '도구', weapon: '무기', armor: '방어', hat: '관모', shoes: '신', norigae: '노리', amulet: '호신', mask: '탈', accessory: '장신', equipment: '장비', quest: '임무', trade_goods: '교역' };

// 검색칸은 그대로 두고 나머지만 새로 그린다(7.5.0, 제보: 아이폰에서 한 글자 칠 때마다 칸을 새로 만들어 키보드가 내려가던 것)
function renderKeep(body, html, sel) {
  const keep = body.querySelector(sel);
  if (!keep || keep.parentNode !== body) { body.innerHTML = html; return false; }
  const tmp = document.createElement('div'); tmp.innerHTML = html;
  const ph = tmp.querySelector(sel);
  if (!ph || ph.parentNode !== tmp) { body.innerHTML = html; return false; }
  const before = [], after = []; let seen = false;
  [...tmp.childNodes].forEach(n => { if (n === ph) seen = true; else (seen ? after : before).push(n); });
  [...body.childNodes].forEach(n => { if (n !== keep) n.remove(); });
  keep.before(...before); keep.after(...after);
  return true;
}

async function items(body, inv) {
  const [, acq] = await Promise.all([loadLocks(), sortKey === 'acquired' ? acquiredMap() : Promise.resolve(new Map())]);
  const cmap = catalogMap(inv), equipped = new Set(Object.values(inv.equipment || {}));
  const rows = Object.entries(inv.inventory || {}).filter(([, n]) => Number(n) > 0)
    .map(([id, n]) => ({ id, n: Number(n), it: cmap.get(id) }))
    .filter(r => cat === 'all' || catOf(r.it) === cat)
    .filter(r => !q.trim() || [nameOf(r.id), r.it?.description, nameOf(r.it?.category)].join(' ').toLowerCase().includes(q.trim().toLowerCase()))
    .sort(sorter(acq));
  const c = store.character, used = bagUsed(c), cap = bagLimit(c);
  renderKeep(body, `<div class="bag-cap ${used >= cap ? 'full' : ''}"><div class="cap-top"><span>${icon('bag', 16)} 가방 ${fmt.num(used)} / ${fmt.num(cap)}칸</span><button class="btn small" data-storage title="창고에 무엇이 있는지 봅니다. 맡기기·꺼내기는 안전지대에서만 됩니다.">${icon('chest', 14)}<span>창고 열기</span></button></div>${bar(used, cap, used >= cap ? 'enemy' : 'xp')}
      <small>같은 물품은 한 칸에 묶음으로 쌓입니다(장비 1개 · 소모품 3~20개 · 재료 5~20개, 물품 정보에서 확인). 가득 차면 전리품을 두고 오고, 구매·제작이 막힙니다. 사건 해결·지역 완전 답사·수향연맹 소속으로 넓어집니다.</small></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="bag-q" type="search" placeholder="가방 안 물품 찾기 (이름·설명)" value="${esc(q)}"></label>
    ${segmented('bag-cat', CATS, cat)}
    <div class="bag-sort"><label><span>정렬</span><select id="bag-sort">${Object.entries(SORTS).map(([k, [n]]) => `<option value="${k}" ${k === sortKey ? 'selected' : ''}>${n}</option>`).join('')}</select></label>
      <button class="btn small" id="bag-dir" aria-label="정렬 방향 바꾸기">${icon('back', 14)}<span>${SORTS[sortKey][sortRev ? 2 : 1]}</span></button></div>
    ${rows.length ? `<ul class="inv-list">${rows.map(({ id, n, it }) => {
      // 차지하는 칸(장착한 하나는 칸을 쓰지 않음) · 묶음 크기(제보 23)
      const st = stackOf(id), cells = Math.ceil(Math.max(0, n - (equipped.has(id) ? 1 : 0)) / st);
      const tags = [it?.tier ? `${it.tier}단계` : '', `${cells}칸${st > 1 ? ` · 묶음 ${st}` : ''}`, equipped.has(id) ? '장착 중' : '', isLocked(id) ? '잠금' : '', USABLE[id] ? '사용 가능' : '', GEAR.has(it?.category) && !equipped.has(id) && gearBlock(it, c) ? gearBlock(it, c) : ''].filter(Boolean);
      return `<li class="inv-item r-${esc(it?.rarity || 'common')}"><button class="inv-row" data-info="${esc(id)}">
        <span class="inv-cat c-${esc(catOf(it))}">${esc(CAT_SHORT[it?.category] || '기타')}</span>
        <span class="inv-name"><span class="inv-title"><b>${esc(nameOf(id))}</b><span class="inv-qty">${fmt.num(n)}</span></span>${it?.description ? `<small class="brief">${esc(brief(it.description))}</small>` : ''}${USABLE[id] ? `<small class="use-fx">${icon('heart', 11)} ${esc(USABLE[id])}</small>` : ''}${tags.length ? `<small>${tags.map(t => `<i class="${t === '장착 중' ? 'eq' : t === '잠금' ? 'lk' : /필요|전용/.test(t) ? 'bad' : ''}">${esc(t)}</i>`).join('')}</small>` : ''}</span>
</button>
        ${USABLE[id] ? `<button class="btn small inv-quick" data-use="${esc(id)}" aria-label="${esc(nameOf(id))} 사용" title="${esc(USABLE[id])}">사용</button>` : ''}</li>`; }).join('')}</ul>`
      : empty(q.trim() ? `「${q.trim()}」에 맞는 물품이 없습니다.` : cat === 'all' ? '가방이 비어 있습니다. 탐사와 채집으로 물품을 모으세요.' : '이 분류의 물품이 없습니다.', 'bag')}
    <p class="muted small">물품을 누르면 정보·제작법·잠금·버리기가 나옵니다. 판매와 거래는 안전지대의 현장 화면(상점·거래소)에서 할 수 있습니다.</p>`, 'label.search');
  $('[data-storage]', body).onclick = () => import('./services.js').then(m => m.openStorage());
  bindSegmented(body, 'bag-cat', k => { cat = k; items(body, inv); });
  $('#bag-sort', body).onchange = e => { sortKey = e.target.value; sortRev = false; saveSort(); items(body, inv); };
  $('#bag-dir', body).onclick = () => { sortRev = !sortRev; saveSort(); items(body, inv); };
  const qi = $('#bag-q', body);
  // 목록과 함께 검색칸도 다시 그리므로, 한글 조합 중에는 그리지 않고 조합이 끝나면(compositionend) 거른다(조합 중 칸이 바뀌면 「ㅂㅜㅈ」처럼 낱자로 깨진다)
  const redo = () => { q = qi.value; items(body, inv); };
  qi.oninput = e => { if (!e.isComposing) redo(); };
  if (!qi.dataset.bound) { qi.dataset.bound = '1'; qi.addEventListener('compositionend', () => qi.oninput({})); }
  $$('[data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  bindActions(body);
}

async function equip(body, inv) {
  const cmap = catalogMap(inv), eq = inv.equipment || {}, have = inv.inventory || {};
  const c = store.character;
  const [prof, zones] = await Promise.all([load('world_combat_profile', undefined, { maxAge: 60000 }).catch(() => null), safeZones().catch(() => null), import('../bond.js').then(m => m.loadBond())]);
  const here = zones ? [...zones.values()].find(r => r.region_name === c.location) : null;
  const enh = Number(prof?.current?.weapon?.enhance) || 0;
  // 그 부위에 바꿔 낄 수 있는 장비 목록(PC 칸·모바일 부위 창이 함께 쓴다)
  const optionsHtml = slot => {
    const cur = eq[slot], options = (inv.catalog || []).filter(i => slotOf(i) === slot && Number(have[i.id]) > 0 && i.id !== cur);
    return options.length ? `<ul class="spot-list">${options.map(o => {
      const blocked = gearBlock(o, c);
      const reqs = gearReqHtml(o, c);
      return `<li><div><b>${esc(o.name)}</b><small>${o.tier}단계 · ${esc(o.description || '')}</small>${traits(o)}${reqs ? `<small class="reqs">장착 조건 ${reqs}</small>` : ''}</div>
        <button class="btn small" data-equip="${esc(o.id)}" ${blocked ? 'disabled' : ''}>장착</button></li>`; }).join('')}</ul>` : `<p class="muted small">바꿔 낄 수 있는 물품이 없습니다.</p>`;
  };
  // 장비 화면(7.5.4): 왼쪽에 장착 칸(작은 칸), 오른쪽에 고른 부위의 지금 장비·수리·벗기·바꿔 낄 장비를 나란히(넓은 화면).
  // 좁은 화면(모바일, 제보 53)은 오른쪽 칸 없이 칸을 누르면 부위 창을 띄운다
  const token = tokenRowHtml();
  body.innerHTML = `<div class="eq-split">
      <div class="eq-left">${panel('장착 중인 장비', `${eqMini(inv, prof, true)}${token ? `<ul class="equip-list">${token}</ul>` : ''}<p class="muted small">칸을 누르면 그 부위의 장비를 고치거나 바꿔 낄 수 있습니다.</p>`, { ico: 'shield' })}</div>
      <div class="eq-right" id="eq-detail"></div>
    </div><p class="muted small">무기 종류가 공격 방식을 정합니다: 칼·창은 근접, 활·쇠뇌는 원거리, 방울·부채·거울은 술법. 요괴마다 잘 통하는 방식이 다릅니다. 방어구는 받는 피해를 줄이고, 생활 칸은 채집(채집도·곡괭이·낫·등)·탐사(나침반)·낚시(낚싯대) 셋입니다. 제작 공구는 가방에 있으면 됩니다. 같은 단계라도 장비마다 갈래가 달라(위력·치명타·회피·방어·이목 등) 무엇을 끼느냐에 따라 캐릭터가 다르게 자랍니다. <b>이목</b>이 높으면 함께 싸울 때 요괴가 먼저 노립니다 — 앞을 막는 이는 높이고, 뒤에서 치는 이는 낮추세요. ${esc(DUR_NOTE)}</p>`;
  const slotBody = slot => `<ul class="equip-list">${equipRowLi(inv, prof, here, slot)}</ul><h3 class="sub-h">바꿔 낄 장비</h3>${optionsHtml(slot)}`;
  const drawDetail = slot => {
    eqSel = slot;
    $('#eq-detail', body).innerHTML = panel(SLOTS[slot][0], slotBody(slot), { ico: SLOTS[slot][1] });
    $$('[data-eqslot]', body).forEach(b => b.classList.toggle('on', b.dataset.eqslot === slot));
    bindActions(body); bindRepair(body);
  };
  bindActions(body); bindRepair(body);
  if (wideEq()) drawDetail(SLOTS[eqSel] ? eqSel : 'weapon');
  $$('[data-eqslot]', body).forEach(b => b.onclick = () => {
    const slot = b.dataset.eqslot;
    if (wideEq()) return drawDetail(slot);
    const m = openModal({ title: SLOTS[slot][0], body: slotBody(slot) });
    // 창 안의 행동은 성공하면 창을 닫는다(가방 화면은 행동 뒤 다시 그려진다). 실패하면 창을 그대로 둔다
    const ok = r => { if (r !== undefined) closeModal(); };
    $$('[data-equip]', m).forEach(x => x.onclick = () => guard(x, () => act('world_equip_item', { p_item_id: x.dataset.equip })).then(ok));
    $$('[data-unequip]', m).forEach(x => x.onclick = () => guard(x, () => act('world_unequip_item', { p_slot: x.dataset.unequip })).then(ok));
    $$('[data-repair]', m).forEach(x => x.onclick = () => guard(x, () => act('world_equipment_repair', { p_item_id: x.dataset.repair, p_method: x.dataset.how })).then(ok));
  });
}
// 넓은 화면의 장비 화면에서 고른 부위(다시 그려도 그대로)
let eqSel = 'weapon';
const wideEq = () => matchMedia('(min-width: 900px)').matches;
function traits(it, n = 0) {
  const t = enhancedTraits(it?.equipment_traits, n); if (!it?.equipment_traits) return '';
  const STY = { melee: '근접 공격', ranged: '원거리 공격', magic: '술법 공격' };
  const parts = effectText(t);
  return `<small class="muted">${esc([STY[t.weapon_type] || t.trait, ...parts].filter(Boolean).join(' · '))}</small>`;
}

async function craft(body, inv, stg) {
  await loadFavs();
  const bagHave = inv.inventory || {}, eq = new Set(Object.values(inv.equipment || {}));
  // 안전지대면 창고 수량을 더해 보인다
  const stHave = stg?.in_safe ? Object.fromEntries((stg.items || []).map(i => [i.item_id, Number(i.qty) || 0])) : {};
  // 우수품(<id>_hq)도 같은 재료로 쓴다(7.5.0, 서버는 보통을 먼저 쓴다)
  const have = new Proxy({}, { get: (_, k) => (Number(bagHave[k]) || 0) + (stHave[k] || 0) + (Number(bagHave[k + '_hq']) || 0) + (stHave[k + '_hq'] || 0) });
  const c = store.character;
  const cookOut = new Set((inv.catalog || []).filter(i => i.crafting_specialization === 'cooking').map(i => i.id)); // 요리·손질 결과물
  const cmap = catalogMap(inv);
  const kindOf = r => { const it = cmap.get(r.output); if (!it) return 'etc'; if (SLOTS[slotOf(it)]) return slotOf(it); const k = catOf(it); return k === 'consumable' || k === 'material' ? k : 'etc'; };
  const lvOf = x => Number(x.r.minimum_level) || 1, tierOf = x => Number(cmap.get(x.r.output)?.tier) || 0;
  const byLv = (a, b) => lvOf(a) - lvOf(b) || tierOf(a) - tierOf(b) || (a.r.difficulty || 0) - (b.r.difficulty || 0) || String(a.r.name).localeCompare(String(b.r.name), 'ko');
  const SORTS = { can: (a, b) => b.can - a.can || b.atLoc - a.atLoc || byLv(a, b), lv: byLv, lvd: (a, b) => byLv(b, a) };
  const favFirst = (f => (a, b) => favs.has(b.r.id) - favs.has(a.r.id) || f(a, b))(SORTS[craftSort] || SORTS.can);
  const rows = (inv.recipes || []).filter(r => (!matFocus || r.ingredients?.[matFocus]) && (!recipeFocus || r.id === recipeFocus)).map(r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => Number(have[k] || 0) < n);
    const toolOk = !r.tool || [...Object.keys(bagHave).filter(k => Number(bagHave[k]) > 0), ...eq].some(k => toolCovers(k, r.tool));
    // 백공 기술관(생활 특화)은 다른 직업 전용 제작법도 만든다(6.1.0, 서버 world_craft_item과 같음)
    const jobOk = !r.required_job || r.required_job === c.job_key || c.job_key === 'analyst';
    const lvOk = !r.minimum_level || c.level >= r.minimum_level;
    const skRank = r.required_skill ? Number(c.skill_progress?.[r.required_skill]?.rank || 1) : 0;
    const skOk = !r.required_skill || skRank >= (r.required_skill_rank || 1);
    // 제작 조건(레벨·직업·기술 숙련): 채운 것은 초록, 못 채운 것은 빨강으로 카드에 바로 보인다
    const reqs = [
      r.minimum_level > 1 && [`Lv.${r.minimum_level} 이상${lvOk ? '' : ` (지금 Lv.${c.level})`}`, lvOk],
      r.required_job && [`${nameOf(r.required_job)}·백공 기술관 제작`, jobOk],
      r.required_skill && [`${nameOf(r.required_skill)} 기술 ${r.required_skill_rank}단계${skOk ? '' : ` (지금 ${skRank}단계)`}`, skOk],
    ].filter(Boolean);
    const can = !lacks.length && toolOk && jobOk && lvOk && skOk;
    return { r, lacks, toolOk, jobOk, lvOk, reqs, can, atLoc: atPlace(r.location, c.location), kind: kindOf(r), tier: cmap.get(r.output)?.tier };
  // 검색: 제작법 이름·만드는 물품·재료·도구·설명으로 찾는다. 검색하는 동안에는 위 거르기와 상관없이 모든 제작법에서 찾는다.
  }).filter(x => { const t = cq.trim().toLowerCase(); if (!t) return true;
    return [x.r.name, x.r.output_name || nameOf(x.r.output), x.r.description, x.r.tool_name || (x.r.tool ? nameOf(x.r.tool) : ''), ...Object.keys(x.r.ingredients || {}).map(nameOf)].join(' ').toLowerCase().includes(t); })
    .filter(x => !craftFields.size || craftFields.has(x.r.field || (cookOut.has(x.r.output) ? 'cooking' : '')))
    .filter(x => !craftKinds.size || craftKinds.has(x.kind))
    .filter(x => cq.trim() || craftFilter === 'all' || (craftFilter === 'fav' ? favs.has(x.r.id) : craftFilter === 'can' ? x.can : x.atLoc))
    .sort(favFirst);
  const kindCount = {}; (inv.recipes || []).forEach(r => { const k = kindOf(r); kindCount[k] = (kindCount[k] || 0) + 1; });
  renderKeep(body, `
    ${stg?.in_safe ? `<p class="muted small">${icon('chest', 13)} 안전지대에서는 창고 재료도 함께 씁니다(가방 먼저). 재료 수량에 창고 몫을 더해 보입니다.</p>` : ''}
    ${bagUsed(store.character) >= bagLimit(store.character) ? `<p class="bad small">가방이 가득 찼습니다(${bagUsed(store.character)}/${bagLimit(store.character)}칸). 완성품이 새 칸을 차지하면 제작할 수 없습니다.</p>` : ''}
    <div class="notice">${icon('hammer', 18)}<div><b>제작은 어디서나 할 수 있습니다</b><span>레시피에 적힌 장소에서 제작하면 품질 +${LOC_BONUS}. 제작 분야 ${esc(nameOf(inv.crafting_profession || 'smithing'))} · ${fmt.num(store.character?.skill_progress?.[({ sealing: 'wardcraft' })[inv.crafting_profession] || inv.crafting_profession || 'smithing']?.rank || 1)}단계</span></div></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="craft-q" type="search" placeholder="제작법 찾기 (이름·완성품·재료·도구)" value="${esc(cq)}"></label>
    ${segmented('craft-filter', [['fav', `즐겨찾기 ${favs.size}`], ['can', '지금 가능'], ['here', '이곳 보너스'], ['all', '전체']], craftFilter)}
    <div class="craft-cats" role="group" aria-label="제작 분야 거르기"><span class="muted small">분야</span>${FIELDS.map(f => { const n = (inv.recipes || []).filter(r => (r.field || '') === f).length;
      return `<label class="check ${inv.crafting_profession === f ? 'mine' : ''}"><input type="checkbox" data-field="${f}" ${craftFields.has(f) ? 'checked' : ''}><span>${esc(nameOf(f))} <small>${n}</small></span></label>`; }).join('')}
      ${craftFields.size ? '<button class="btn small ghost" id="craft-fields-clear">모든 분야</button>' : ''}</div>
    <div class="craft-cats" role="group" aria-label="만드는 것 거르기"><span class="muted small">만드는 것</span>${Object.keys(KIND_LABEL).filter(k => kindCount[k]).map(k =>
      `<label class="check"><input type="checkbox" data-kind="${k}" ${craftKinds.has(k) ? 'checked' : ''}><span>${esc(KIND_LABEL[k])} <small>${kindCount[k]}</small></span></label>`).join('')}
      ${craftKinds.size ? '<button class="btn small ghost" id="craft-kinds-clear">모두</button>' : ''}
      <label class="craft-sort"><span class="muted small">정렬</span><select id="craft-sort">${[['can', '가능한 것 먼저'], ['lv', '제작 레벨 낮은순'], ['lvd', '제작 레벨 높은순']].map(([k, t]) => `<option value="${k}" ${craftSort === k ? 'selected' : ''}>${t}</option>`).join('')}</select></label></div>
    <p class="muted small">내 제작 분야(${esc(nameOf(inv.crafting_profession || 'smithing'))})의 제작법은 품질 +12입니다. 제작하면 그 제작법 분야의 기술 계열이 오르고, 품질은 그 계열 단계를 따릅니다. 품질 85 이상이면 「우수품」이 나옵니다(30단계 추가 기술이 있으면 80). 분야는 캐릭터 › 성장 › 생활 전문화에서 정합니다.</p>
    ${cq.trim() ? `<p class="muted small">「${esc(cq.trim())}」 검색 결과 ${rows.length}개 · 검색 중에는 모든 제작법에서 찾습니다.</p>` : ''}
    ${matFocus || recipeFocus ? `<div class="focus-bar">${icon('search', 14)}<span>${matFocus ? `${esc(`「${nameOf(matFocus)}」이(가)`)} 들어가는 제작법` : `「${esc(nameOf(recipeFocus))}」 제작법`}</span><button class="btn small ghost" id="craft-unfocus">모두 보기</button></div>` : ''}
    ${rows.length ? `<div class="recipe-grid">${rows.map(({ r, lacks, toolOk, reqs, can, atLoc, kind, tier }) => `
      <article class="recipe ${can ? 'can' : ''}">
        <header><button class="fav-star ${favs.has(r.id) ? 'on' : ''}" data-fav="${esc(r.id)}" aria-pressed="${favs.has(r.id)}" aria-label="${favs.has(r.id) ? '즐겨찾기에서 빼기' : '즐겨찾기에 넣기'}" title="${favs.has(r.id) ? '즐겨찾기에서 빼기' : `즐겨찾기에 넣기 (${favs.size}/${FAV_MAX})`}">${STAR}</button><button class="linkish recipe-name" data-info="${esc(r.output)}" title="만드는 물품 정보 보기"><b>${esc(r.name)}</b></button>${SLOTS[kind] ? `<span class="chip slot">${icon(SLOTS[kind][1], 12)}${esc(SLOTS[kind][0])}${tier ? ` ${tier}단계` : ''}</span>` : ''}${r.field ? chip(nameOf(r.field), r.field === inv.crafting_profession ? 'ok' : '') : ''}${atLoc ? chip(`품질 +${LOC_BONUS}`, 'accent') : ''}</header>
        <p class="muted small">${esc(r.description || '')}</p>
        <p class="out">${icon('chevron', 14)} <button class="linkish" data-info="${esc(r.output)}">${esc(r.output_name || nameOf(r.output))}</button> ×${r.qty || 1}</p>
        ${USABLE[r.output] ? `<p class="use-fx small">${icon('heart', 12)} ${esc(USABLE[r.output])}</p>` : ''}
        <ul class="ingr">${Object.entries(r.ingredients || {}).map(([k, n]) => { const h = Number(have[k] || 0), sh = stHave[k] || 0; return `<li class="${h >= n ? 'ok' : 'bad'}"><button class="linkish" data-info="${esc(k)}">${esc(nameOf(k))}</button><b>${fmt.num(h)}/${n}</b>${sh ? `<small class="muted" title="가방 ${fmt.num(Number(bagHave[k]) || 0)} · 창고 ${fmt.num(sh)}">창고 ${fmt.num(sh)}</small>` : ''}</li>`; }).join('')}</ul>
        ${reqs.length ? `<p class="reqs"><span class="muted small">제작 조건</span>${reqs.map(([t, ok]) => `<span class="req ${ok ? 'ok' : 'bad'}">${esc(t)}</span>`).join('')}</p>` : ''}
        <p class="muted small">${r.tool ? `도구: <button class="linkish" data-info="${esc(r.tool)}">${esc(r.tool_name || nameOf(r.tool))}</button>${toolOk ? '' : ' (없음)'} · ` : ''}보너스 장소: ${esc(r.location || '없음')}</p>
        <button class="btn small ${can ? 'primary' : ''}" data-craft="${esc(r.id)}" ${can ? '' : 'disabled'}>${icon('hammer', 14)}<span>${can ? '제작' : lacks.length ? '재료 부족' : '조건 미충족'}</span></button>
      </article>`).join('')}</div>`
      : empty(cq.trim() ? `「${cq.trim()}」에 맞는 제작법이 없습니다.` : craftFilter === 'fav' ? `즐겨찾는 제작법이 없습니다. 제작법 이름 앞의 별을 누르면 여기에 모입니다(${FAV_MAX}개까지).` : craftFilter === 'can' ? '지금 재료가 모두 갖춰진 레시피가 없습니다. 전체 목록에서 필요한 재료를 확인하세요.' : '해당하는 레시피가 없습니다.', 'hammer')}`, 'label.search');
  bindSegmented(body, 'craft-filter', k => { craftFilter = k; craft(body, inv, stg); });
  $$('[data-field]', body).forEach(b => b.onchange = () => { b.checked ? craftFields.add(b.dataset.field) : craftFields.delete(b.dataset.field); craft(body, inv, stg); });
  $('#craft-fields-clear', body)?.addEventListener('click', () => { craftFields.clear(); craft(body, inv, stg); });
  $$('[data-kind]', body).forEach(b => b.onchange = () => { b.checked ? craftKinds.add(b.dataset.kind) : craftKinds.delete(b.dataset.kind); craft(body, inv, stg); });
  $('#craft-kinds-clear', body)?.addEventListener('click', () => { craftKinds.clear(); craft(body, inv, stg); });
  $('#craft-sort', body).onchange = e => { craftSort = e.target.value; craft(body, inv, stg); };
  const ci = $('#craft-q', body);
  // 한글을 조합하는 동안에는 다시 그리지 않는다(조합이 끊긴다). 조합이 끝나면 그린다.
  const redo = () => { cq = ci.value; craft(body, inv, stg); };
  ci.oninput = e => { if (!e.isComposing) redo(); };
  if (!ci.dataset.bound) { ci.dataset.bound = '1'; ci.addEventListener('compositionend', () => ci.oninput({})); }
  $('#craft-unfocus', body)?.addEventListener('click', () => { matFocus = recipeFocus = null; craft(body, inv, stg); });
  // 제작법 이름·만드는 물품·재료·도구 이름을 누르면 물품 정보 창을 띄운다
  $$('.recipe [data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  $$('[data-craft]', body).forEach(b => b.onclick = () => guard(b, () => act('world_craft_item', { p_recipe_id: b.dataset.craft })));
  $$('[data-fav]', body).forEach(b => b.onclick = () => guard(b, async () => {
    try { const r = await rpc('world_craft_fav_toggle', { p_recipe: b.dataset.fav }); favs = new Set(r?.favs || []); craft(body, inv, stg); }
    catch (e) { toast(friendlyError(e), 'error'); }
  }));
}

function bindActions(body) {
  $$('[data-use]', body).forEach(b => b.onclick = () => useItem(b.dataset.use, b));
  $$('[data-equip]', body).forEach(b => b.onclick = () => guard(b, () => act('world_equip_item', { p_item_id: b.dataset.equip })));
}
