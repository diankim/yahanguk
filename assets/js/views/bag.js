// 가방: 소지품 · 장비 · 제작. 제작은 어디서나 가능하고, 레시피의 지정 장소에서 하면 품질 보너스를 받는다.
import { db, store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar, bagLimit, bagUsed, effectText } from '../core.js';
import { load, panel, chip, loading, errorBox, safeZones } from './common.js';
import { equipRows, bindRepair } from './character.js';
import { openItemInfo, loadLocks, isLocked, gearBlock, gearReqHtml, USABLE, GEAR, SLOTS } from './item.js';

const SUBS = [['items', '소지품'], ['equip', '장비'], ['craft', '제작']];
const CATS = [['all', '전체'], ['consumable', '소모품'], ['material', '재료'], ['gear', '장비'], ['etc', '기타']];
const LOC_BONUS = 12; // 서버 world_craft_item과 같은 값
// 서버가 같은 장소로 인정하는 옛 지명
const LOC_ALIAS = { '야행국 본부 정청': ['본부 로비', '야행국 본부 · 정청'], '연무장·팔괘진': ['훈련실', '야행국 본부 · 연무장'], '장서각 지하서고': ['기록 보관실', '야행국 본부 · 장서각'] };
const atPlace = (loc, here) => !!loc && (loc === here || (LOC_ALIAS[loc] || []).includes(here));
let el, sub = 'items', cat = 'all', craftFilter = 'can', off = [], q = '', cq = '';
// 제작 분야(서버 world_crafting_recipes.craft_field). 아무것도 고르지 않으면 모든 분야를 보인다.
const FIELDS = ['smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking'];
const craftFields = new Set();
// 정렬: 기본(단계) · 획득순 · 이름순 · 희귀도순, 각각 정순·역순. 고른 정렬은 이 기기에 기억한다.
const SORTS = { tier: ['기본(단계)', '낮은 단계 먼저', '높은 단계 먼저'], acquired: ['획득순', '최근 얻은 것 먼저', '오래전에 얻은 것 먼저'],
  name: ['이름순', '가나다순', '가나다 역순'], rarity: ['희귀도순', '희귀한 것 먼저', '흔한 것 먼저'] };
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
window.addEventListener('yh-craft-focus', e => { matFocus = e.detail?.material || null; recipeFocus = e.detail?.recipe || null; if (matFocus || recipeFocus) craftFilter = 'all'; });

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'items';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}</p><h1>가방</h1></div></div>
    ${segmented('bag-sub', SUBS, sub)}<div id="bag-body"></div>`;
  bindSegmented(el, 'bag-sub', k => { sub = k; window.history.replaceState(null, '', `#/bag/${k}`); draw(); });
  off.forEach(f => f()); off = [on('changed', () => draw(true))];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#bag-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try {
    const inv = await load('world_inventory_snapshot');
    const head = $('.view-head .eyebrow', el); if (head) head.innerHTML = `${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}`;
    await ({ items, equip, craft })[sub](body, inv);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

function catalogMap(inv) { return new Map((inv.catalog || []).map(i => [i.id, i])); }
const catOf = i => !i ? 'etc' : GEAR.has(i.category) ? 'gear' : i.category === 'consumable' ? 'consumable' : /material/.test(i.category) ? 'material' : 'etc';

const CAT_SHORT = { consumable: '소모', material: '재료', craft_material: '재료', tool: '도구', weapon: '무기', armor: '방어', hat: '관모', shoes: '신', norigae: '노리', amulet: '호신', mask: '탈', accessory: '장신', equipment: '장비', quest: '임무', trade_goods: '교역' };
async function items(body, inv) {
  const [, acq] = await Promise.all([loadLocks(), sortKey === 'acquired' ? acquiredMap() : Promise.resolve(new Map())]);
  const cmap = catalogMap(inv), equipped = new Set(Object.values(inv.equipment || {}));
  const rows = Object.entries(inv.inventory || {}).filter(([, n]) => Number(n) > 0)
    .map(([id, n]) => ({ id, n: Number(n), it: cmap.get(id) }))
    .filter(r => cat === 'all' || catOf(r.it) === cat)
    .filter(r => !q.trim() || [nameOf(r.id), r.it?.description, nameOf(r.it?.category)].join(' ').toLowerCase().includes(q.trim().toLowerCase()))
    .sort(sorter(acq));
  const c = store.character, used = bagUsed(c), cap = bagLimit(c);
  body.innerHTML = `<div class="bag-cap ${used >= cap ? 'full' : ''}"><span>${icon('bag', 16)} 가방 ${fmt.num(used)} / ${fmt.num(cap)}칸</span>${bar(used, cap, used >= cap ? 'enemy' : 'xp')}
      <small>같은 물품은 한 칸에 묶음으로 쌓입니다(장비 1개 · 소모품 3~20개 · 재료 5~20개, 물품 정보에서 확인). 가득 차면 전리품을 두고 오고, 구매·제작이 막힙니다. 사건 해결·지역 완전 답사·수향연맹 소속으로 넓어집니다.</small></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="bag-q" type="search" placeholder="가방 안 물품 찾기 (이름·설명)" value="${esc(q)}"></label>
    ${segmented('bag-cat', CATS, cat)}
    <div class="bag-sort"><label><span>정렬</span><select id="bag-sort">${Object.entries(SORTS).map(([k, [n]]) => `<option value="${k}" ${k === sortKey ? 'selected' : ''}>${n}</option>`).join('')}</select></label>
      <button class="btn small" id="bag-dir" aria-label="정렬 방향 바꾸기">${icon('back', 14)}<span>${SORTS[sortKey][sortRev ? 2 : 1]}</span></button></div>
    ${rows.length ? `<ul class="inv-list">${rows.map(({ id, n, it }) => {
      const tags = [it?.tier ? `${it.tier}단계` : '', equipped.has(id) ? '장착 중' : '', isLocked(id) ? '잠금' : '', USABLE[id] ? '사용 가능' : '', GEAR.has(it?.category) && !equipped.has(id) && gearBlock(it, c) ? gearBlock(it, c) : ''].filter(Boolean);
      return `<li class="inv-item r-${esc(it?.rarity || 'common')}"><button class="inv-row" data-info="${esc(id)}">
        <span class="inv-cat c-${esc(catOf(it))}">${esc(CAT_SHORT[it?.category] || '기타')}</span>
        <span class="inv-name"><span class="inv-title"><b>${esc(nameOf(id))}</b><span class="inv-qty">${fmt.num(n)}</span></span>${tags.length ? `<small>${tags.map(t => `<i class="${t === '장착 중' ? 'eq' : t === '잠금' ? 'lk' : /필요|전용/.test(t) ? 'bad' : ''}">${esc(t)}</i>`).join('')}</small>` : ''}</span>
</button>
        ${USABLE[id] ? `<button class="btn small inv-quick" data-use="${esc(id)}" aria-label="${esc(nameOf(id))} 사용" title="${esc(USABLE[id])}">사용</button>` : ''}</li>`; }).join('')}</ul>`
      : empty(q.trim() ? `「${q.trim()}」에 맞는 물품이 없습니다.` : cat === 'all' ? '가방이 비어 있습니다. 탐사와 채집으로 물품을 모으세요.' : '이 분류의 물품이 없습니다.', 'bag')}
    <p class="muted small">물품을 누르면 정보·제작법·잠금·버리기가 나옵니다. 판매와 거래는 안전지대의 현장 화면(상점·거래소)에서 할 수 있습니다.</p>`;
  bindSegmented(body, 'bag-cat', k => { cat = k; items(body, inv); });
  $('#bag-sort', body).onchange = e => { sortKey = e.target.value; sortRev = false; saveSort(); items(body, inv); };
  $('#bag-dir', body).onclick = () => { sortRev = !sortRev; saveSort(); items(body, inv); };
  const qi = $('#bag-q', body);
  qi.oninput = () => { q = qi.value; const pos = qi.selectionStart; items(body, inv).then(() => { const n = $('#bag-q', body); n.focus(); n.setSelectionRange(pos, pos); }); };
  $$('[data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  bindActions(body);
}

async function equip(body, inv) {
  const cmap = catalogMap(inv), eq = inv.equipment || {}, have = inv.inventory || {};
  const c = store.character;
  const [prof, zones] = await Promise.all([load('world_combat_profile').catch(() => null), safeZones().catch(() => null), import('../bond.js').then(m => m.loadBond(true))]);
  const here = zones ? [...zones.values()].find(r => r.region_name === c.location) : null;
  const slots = Object.keys(SLOTS).map(slot => {
    const cur = eq[slot], it = cmap.get(cur);
    const options = (inv.catalog || []).filter(i => i.category === slot && Number(have[i.id]) > 0 && i.id !== cur);
    return panel(SLOTS[slot][0], `
      ${cur ? `<div class="equip-cur"><b>${esc(nameOf(cur))}</b>${it?.tier ? chip(`${it.tier}단계`) : ''}${traits(it)}</div>` : `<p class="muted">비어 있음</p>`}
      ${options.length ? `<ul class="spot-list">${options.map(o => {
        const blocked = gearBlock(o, c);
        const reqs = gearReqHtml(o, c);
        return `<li><div><b>${esc(o.name)}</b><small>${o.tier}단계 · ${esc(o.description || '')}</small>${traits(o)}${reqs ? `<small class="reqs">장착 조건 ${reqs}</small>` : ''}</div>
          <button class="btn small" data-equip="${esc(o.id)}" ${blocked ? 'disabled' : ''}>장착</button></li>`; }).join('')}</ul>` : `<p class="muted small">교체할 수 있는 물품이 없습니다.</p>`}`, { ico: SLOTS[slot][1], cls: 'compact' });
  }).join('');
  body.innerHTML = `${panel('장착 중인 장비', equipRows(inv, prof, here), { ico: 'shield' })}<h3 class="sub-h">바꿔 낄 장비</h3><div class="grid-2">${slots}</div><p class="muted small">무기 종류가 공격 방식을 정합니다: 칼·창은 근접, 활·쇠뇌는 원거리, 방울·부채·거울은 술법. 요괴마다 잘 통하는 방식이 다릅니다. 방어구는 받는 피해를 줄이고, 도구는 채집량을 늘립니다. 같은 단계라도 장비마다 갈래가 달라(위력·치명타·회피·방어·이목 등) 무엇을 끼느냐에 따라 캐릭터가 다르게 자랍니다. <b>이목</b>이 높으면 함께 싸울 때 요괴가 먼저 노립니다 — 앞을 막는 이는 높이고, 뒤에서 치는 이는 낮추세요.</p>`;
  bindActions(body); bindRepair(body);
}
function traits(it) {
  const t = it?.equipment_traits; if (!t) return '';
  const STY = { melee: '근접 공격', ranged: '원거리 공격', magic: '술법 공격' };
  const parts = effectText(t);
  return `<small class="muted">${esc([STY[t.weapon_type] || t.trait, ...parts].filter(Boolean).join(' · '))}</small>`;
}

function craft(body, inv) {
  const have = inv.inventory || {}, eq = new Set(Object.values(inv.equipment || {}));
  const c = store.character;
  const cookOut = new Set((inv.catalog || []).filter(i => i.crafting_specialization === 'cooking').map(i => i.id)); // 요리·손질 결과물
  const rows = (inv.recipes || []).filter(r => (!matFocus || r.ingredients?.[matFocus]) && (!recipeFocus || r.id === recipeFocus)).map(r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => Number(have[k] || 0) < n);
    const toolOk = !r.tool || Number(have[r.tool] || 0) > 0 || eq.has(r.tool);
    const jobOk = !r.required_job || r.required_job === c.job_key;
    const lvOk = !r.minimum_level || c.level >= r.minimum_level;
    const can = !lacks.length && toolOk && jobOk && lvOk;
    return { r, lacks, toolOk, jobOk, lvOk, can, atLoc: atPlace(r.location, c.location) };
  // 검색: 제작법 이름·만드는 물품·재료·도구·설명으로 찾는다. 검색하는 동안에는 위 거르기와 상관없이 모든 제작법에서 찾는다.
  }).filter(x => { const t = cq.trim().toLowerCase(); if (!t) return true;
    return [x.r.name, x.r.output_name || nameOf(x.r.output), x.r.description, x.r.tool_name || (x.r.tool ? nameOf(x.r.tool) : ''), ...Object.keys(x.r.ingredients || {}).map(nameOf)].join(' ').toLowerCase().includes(t); })
    .filter(x => !craftFields.size || craftFields.has(x.r.field || (cookOut.has(x.r.output) ? 'cooking' : '')))
    .filter(x => cq.trim() || craftFilter === 'all' || (craftFilter === 'can' ? x.can : x.atLoc))
    .sort((a, b) => b.can - a.can || b.atLoc - a.atLoc || (a.r.difficulty || 0) - (b.r.difficulty || 0));
  body.innerHTML = `
    <div class="notice">${icon('hammer', 18)}<div><b>제작은 어디서나 할 수 있습니다</b><span>레시피에 적힌 장소에서 제작하면 품질 +${LOC_BONUS}. 제작 분야 ${esc(nameOf(inv.crafting_profession))} · ${fmt.num(inv.crafting_rank)}단계</span></div></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="craft-q" type="search" placeholder="제작법 찾기 (이름·완성품·재료·도구)" value="${esc(cq)}"></label>
    ${segmented('craft-filter', [['can', '지금 가능'], ['here', '이곳 보너스'], ['all', '전체']], craftFilter)}
    <div class="craft-cats" role="group" aria-label="제작 분야 거르기">${FIELDS.map(f => { const n = (inv.recipes || []).filter(r => (r.field || '') === f).length;
      return `<label class="check ${inv.crafting_profession === f ? 'mine' : ''}"><input type="checkbox" data-field="${f}" ${craftFields.has(f) ? 'checked' : ''}><span>${esc(nameOf(f))} <small>${n}</small></span></label>`; }).join('')}
      ${craftFields.size ? '<button class="btn small ghost" id="craft-fields-clear">모든 분야</button>' : ''}</div>
    <p class="muted small">내 제작 분야(${esc(nameOf(inv.crafting_profession || 'general'))})의 제작법은 품질 +12, 종합 제작은 모든 분야 +4입니다. 분야는 캐릭터 › 성장 › 생활 전문화에서 정합니다.</p>
    ${cq.trim() ? `<p class="muted small">「${esc(cq.trim())}」 검색 결과 ${rows.length}개 · 검색 중에는 모든 제작법에서 찾습니다.</p>` : ''}
    ${matFocus || recipeFocus ? `<div class="focus-bar">${icon('search', 14)}<span>${matFocus ? `${esc(`「${nameOf(matFocus)}」이(가)`)} 들어가는 제작법` : `「${esc(nameOf(recipeFocus))}」 제작법`}</span><button class="btn small ghost" id="craft-unfocus">모두 보기</button></div>` : ''}
    ${rows.length ? `<div class="recipe-grid">${rows.map(({ r, lacks, toolOk, jobOk, lvOk, can, atLoc }) => `
      <article class="recipe ${can ? 'can' : ''}">
        <header><button class="linkish recipe-name" data-info="${esc(r.output)}" title="만드는 물품 정보 보기"><b>${esc(r.name)}</b></button>${r.field ? chip(nameOf(r.field), r.field === inv.crafting_profession ? 'ok' : '') : ''}${atLoc ? chip(`품질 +${LOC_BONUS}`, 'accent') : ''}</header>
        <p class="muted small">${esc(r.description || '')}</p>
        <p class="out">${icon('chevron', 14)} <button class="linkish" data-info="${esc(r.output)}">${esc(r.output_name || nameOf(r.output))}</button> ×${r.qty || 1}</p>
        <ul class="ingr">${Object.entries(r.ingredients || {}).map(([k, n]) => { const h = Number(have[k] || 0); return `<li class="${h >= n ? 'ok' : 'bad'}"><button class="linkish" data-info="${esc(k)}">${esc(nameOf(k))}</button><b>${fmt.num(h)}/${n}</b></li>`; }).join('')}</ul>
        <p class="muted small">${r.tool ? `도구: <button class="linkish" data-info="${esc(r.tool)}">${esc(r.tool_name || nameOf(r.tool))}</button>${toolOk ? '' : ' (없음)'} · ` : ''}보너스 장소: ${esc(r.location || '없음')}${!jobOk ? ` · ${esc(nameOf(r.required_job))} 전용` : ''}${!lvOk ? ` · Lv.${r.minimum_level} 필요` : ''}</p>
        <button class="btn small ${can ? 'primary' : ''}" data-craft="${esc(r.id)}" ${can ? '' : 'disabled'}>${icon('hammer', 14)}<span>${can ? '제작' : lacks.length ? '재료 부족' : '조건 미충족'}</span></button>
      </article>`).join('')}</div>`
      : empty(cq.trim() ? `「${cq.trim()}」에 맞는 제작법이 없습니다.` : craftFilter === 'can' ? '지금 재료가 모두 갖춰진 레시피가 없습니다. 전체 목록에서 필요한 재료를 확인하세요.' : '해당하는 레시피가 없습니다.', 'hammer')}`;
  bindSegmented(body, 'craft-filter', k => { craftFilter = k; craft(body, inv); });
  $$('[data-field]', body).forEach(b => b.onchange = () => { b.checked ? craftFields.add(b.dataset.field) : craftFields.delete(b.dataset.field); craft(body, inv); });
  $('#craft-fields-clear', body)?.addEventListener('click', () => { craftFields.clear(); craft(body, inv); });
  const ci = $('#craft-q', body);
  // 한글을 조합하는 동안에는 다시 그리지 않는다(조합이 끊긴다). 조합이 끝나면 그린다.
  const redo = () => { cq = ci.value; const pos = ci.selectionStart; craft(body, inv); const n = $('#craft-q', body); n.focus(); n.setSelectionRange(pos, pos); };
  ci.oninput = e => { if (!e.isComposing) redo(); };
  ci.addEventListener('compositionend', redo);
  $('#craft-unfocus', body)?.addEventListener('click', () => { matFocus = recipeFocus = null; craft(body, inv); });
  // 제작법 이름·만드는 물품·재료·도구 이름을 누르면 물품 정보 창을 띄운다
  $$('.recipe [data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  $$('[data-craft]', body).forEach(b => b.onclick = () => guard(b, () => act('world_craft_item', { p_recipe_id: b.dataset.craft })));
}

function bindActions(body) {
  $$('[data-use]', body).forEach(b => b.onclick = () => guard(b, () => act('world_use_item', { p_item_id: b.dataset.use })));
  $$('[data-equip]', body).forEach(b => b.onclick = () => guard(b, () => act('world_equip_item', { p_item_id: b.dataset.equip })));
}
