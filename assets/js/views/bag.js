// 가방: 소지품 · 장비 · 제작. 제작은 어디서나 가능하고, 레시피의 지정 장소에서 하면 품질 보너스를 받는다.
import { store, on, act, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar, bagLimit, bagUsed, effectText } from '../core.js';
import { load, panel, chip, loading, errorBox, safeZones } from './common.js';
import { equipRows, bindRepair } from './character.js';

const SUBS = [['items', '소지품'], ['equip', '장비'], ['craft', '제작']];
const CATS = [['all', '전체'], ['consumable', '소모품'], ['material', '재료'], ['gear', '장비'], ['etc', '기타']];
const GEAR = new Set(['tool', 'weapon', 'armor', 'accessory', 'equipment']);
const SLOT = { tool: '도구', weapon: '무기', armor: '방어구', accessory: '장신구' };
const USABLE = { tonic: '체력 35 · 마음 진정', herbal_extract: '체력 22 · 출혈·화상 치료', herb: '체력 12 · 중독 치료', medicine_base: '정신 12 · 피로·한기 치료',
  ward_talisman: '정신 8 · 침식 완화', travel_ration: '탐색력 +5', revival_charm: '전투불능에서 일어나기' };
const LOC_BONUS = 12; // 서버 world_craft_item과 같은 값
// 서버가 같은 장소로 인정하는 옛 지명
const LOC_ALIAS = { '야행국 본부 정청': ['본부 로비', '야행국 본부 · 정청'], '연무장·팔괘진': ['훈련실', '야행국 본부 · 연무장'], '장서각 지하서고': ['기록 보관실', '야행국 본부 · 장서각'] };
const atPlace = (loc, here) => !!loc && (loc === here || (LOC_ALIAS[loc] || []).includes(here));
let el, sub = 'items', cat = 'all', craftFilter = 'can', off = [], q = '';

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

function items(body, inv) {
  const cmap = catalogMap(inv), equipped = new Set(Object.values(inv.equipment || {}));
  const rows = Object.entries(inv.inventory || {}).filter(([, n]) => Number(n) > 0)
    .map(([id, n]) => ({ id, n, it: cmap.get(id) }))
    .filter(r => cat === 'all' || catOf(r.it) === cat)
    .filter(r => !q.trim() || [nameOf(r.id), r.it?.description, nameOf(r.it?.category)].join(' ').toLowerCase().includes(q.trim().toLowerCase()))
    .sort((a, b) => (a.it?.tier || 0) - (b.it?.tier || 0) || nameOf(a.id).localeCompare(nameOf(b.id), 'ko'));
  const c = store.character, used = bagUsed(c), cap = bagLimit(c);
  body.innerHTML = `<div class="bag-cap ${used >= cap ? 'full' : ''}"><span>${icon('bag', 16)} 가방 ${fmt.num(used)} / ${fmt.num(cap)}칸</span>${bar(used, cap, used >= cap ? 'enemy' : 'xp')}
      <small>가득 차면 전리품을 두고 오고, 구매·제작이 막힙니다. 사건 해결·지역 완전 답사·수향연맹 소속으로 넓어집니다.</small></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="bag-q" type="search" placeholder="가방 안 물품 찾기 (이름·설명)" value="${esc(q)}"></label>
    ${segmented('bag-cat', CATS, cat)}
    ${rows.length ? `<ul class="item-list">${rows.map(({ id, n, it }) => `<li class="r-${esc(it?.rarity || 'common')}">
      <div class="item-main"><b>${esc(nameOf(id))}</b><span class="qty">×${fmt.num(n)}</span>
        <div class="chips">${chip(nameOf(it?.rarity || 'common'), 'rar')}${it ? chip(nameOf(it.category)) : ''}${it?.tier ? chip(`${it.tier}단계`) : ''}${equipped.has(id) ? chip('장착 중', 'accent') : ''}</div>
        ${it?.description ? `<small>${esc(it.description)}</small>` : ''}</div>
      <div class="item-act">${USABLE[id] ? `<button class="btn small" data-use="${esc(id)}" title="${esc(USABLE[id])}">사용</button>` : ''}
        ${it && GEAR.has(it.category) && !equipped.has(id) ? `<button class="btn small" data-equip="${esc(id)}">장착</button>` : ''}</div></li>`).join('')}</ul>`
      : empty(q.trim() ? `「${q.trim()}」에 맞는 물품이 없습니다.` : cat === 'all' ? '가방이 비어 있습니다. 탐사와 채집으로 물품을 모으세요.' : '이 분류의 물품이 없습니다.', 'bag')}
    <p class="muted small">판매와 거래는 안전지대의 현장 화면(상점·거래소)에서 할 수 있습니다.</p>`;
  bindSegmented(body, 'bag-cat', k => { cat = k; items(body, inv); });
  const qi = $('#bag-q', body);
  qi.oninput = () => { q = qi.value; const pos = qi.selectionStart; items(body, inv); const n = $('#bag-q', body); n.focus(); n.setSelectionRange(pos, pos); };
  bindActions(body);
}

async function equip(body, inv) {
  const cmap = catalogMap(inv), eq = inv.equipment || {}, have = inv.inventory || {};
  const c = store.character;
  const [prof, zones] = await Promise.all([load('world_combat_profile').catch(() => null), safeZones().catch(() => null)]);
  const here = zones ? [...zones.values()].find(r => r.region_name === c.location) : null;
  const slots = Object.keys(SLOT).map(slot => {
    const cur = eq[slot], it = cmap.get(cur);
    const options = (inv.catalog || []).filter(i => i.category === slot && Number(have[i.id]) > 0 && i.id !== cur);
    return panel(SLOT[slot], `
      ${cur ? `<div class="equip-cur"><b>${esc(nameOf(cur))}</b>${it?.tier ? chip(`${it.tier}단계`) : ''}${traits(it)}</div>` : `<p class="muted">비어 있음</p>`}
      ${options.length ? `<ul class="spot-list">${options.map(o => {
        const blocked = (o.required_job && o.required_job !== c.job_key) ? `${nameOf(o.required_job)} 전용` : (o.minimum_level > c.level) ? `Lv.${o.minimum_level} 필요` : '';
        return `<li><div><b>${esc(o.name)}</b><small>${o.tier}단계 · ${esc(o.description || '')}</small>${traits(o)}${blocked ? `<small class="bad">${esc(blocked)}</small>` : ''}</div>
          <button class="btn small" data-equip="${esc(o.id)}" ${blocked ? 'disabled' : ''}>장착</button></li>`; }).join('')}</ul>` : `<p class="muted small">교체할 수 있는 물품이 없습니다.</p>`}`, { ico: slot === 'tool' ? 'hammer' : slot === 'weapon' ? 'sword' : slot === 'armor' ? 'shield' : 'spark', cls: 'compact' });
  }).join('');
  body.innerHTML = `${panel('장착 중인 장비', equipRows(inv, prof, here), { ico: 'shield' })}<h3 class="sub-h">바꿔 낄 장비</h3><div class="grid-2">${slots}</div><p class="muted small">무기 종류가 공격 방식을 정합니다: 칼·창은 근접, 활·쇠뇌는 원거리, 방울·부채·거울은 술법. 요괴마다 잘 통하는 방식이 다릅니다. 방어구는 받는 피해를 줄이고, 도구는 채집량을 늘립니다.</p>`;
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
  const rows = (inv.recipes || []).map(r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => Number(have[k] || 0) < n);
    const toolOk = !r.tool || Number(have[r.tool] || 0) > 0 || eq.has(r.tool);
    const jobOk = !r.required_job || r.required_job === c.job_key;
    const lvOk = !r.minimum_level || c.level >= r.minimum_level;
    const can = !lacks.length && toolOk && jobOk && lvOk;
    return { r, lacks, toolOk, jobOk, lvOk, can, atLoc: atPlace(r.location, c.location) };
  }).filter(x => craftFilter === 'all' || (craftFilter === 'can' ? x.can : x.atLoc))
    .sort((a, b) => b.can - a.can || b.atLoc - a.atLoc || (a.r.difficulty || 0) - (b.r.difficulty || 0));
  body.innerHTML = `
    <div class="notice">${icon('hammer', 18)}<div><b>제작은 어디서나 할 수 있습니다</b><span>레시피에 적힌 장소에서 제작하면 품질 +${LOC_BONUS}. 제작 분야 ${esc(nameOf(inv.crafting_profession))} · ${fmt.num(inv.crafting_rank)}단계</span></div></div>
    ${segmented('craft-filter', [['can', '지금 가능'], ['here', '이곳 보너스'], ['all', '전체']], craftFilter)}
    ${rows.length ? `<div class="recipe-grid">${rows.map(({ r, lacks, toolOk, jobOk, lvOk, can, atLoc }) => `
      <article class="recipe ${can ? 'can' : ''}">
        <header><b>${esc(r.name)}</b>${atLoc ? chip(`품질 +${LOC_BONUS}`, 'accent') : ''}</header>
        <p class="muted small">${esc(r.description || '')}</p>
        <p class="out">${icon('chevron', 14)} ${esc(r.output_name || nameOf(r.output))} ×${r.qty || 1}</p>
        <ul class="ingr">${Object.entries(r.ingredients || {}).map(([k, n]) => { const h = Number(have[k] || 0); return `<li class="${h >= n ? 'ok' : 'bad'}"><span>${esc(nameOf(k))}</span><b>${fmt.num(h)}/${n}</b></li>`; }).join('')}</ul>
        <p class="muted small">${r.tool ? `도구: ${esc(r.tool_name || nameOf(r.tool))}${toolOk ? '' : ' (없음)'} · ` : ''}보너스 장소: ${esc(r.location || '없음')}${!jobOk ? ` · ${esc(nameOf(r.required_job))} 전용` : ''}${!lvOk ? ` · Lv.${r.minimum_level} 필요` : ''}</p>
        <button class="btn small ${can ? 'primary' : ''}" data-craft="${esc(r.id)}" ${can ? '' : 'disabled'}>${icon('hammer', 14)}<span>${can ? '제작' : lacks.length ? '재료 부족' : '조건 미충족'}</span></button>
      </article>`).join('')}</div>`
      : empty(craftFilter === 'can' ? '지금 재료가 모두 갖춰진 레시피가 없습니다. 전체 목록에서 필요한 재료를 확인하세요.' : '해당하는 레시피가 없습니다.', 'hammer')}`;
  bindSegmented(body, 'craft-filter', k => { craftFilter = k; craft(body, inv); });
  $$('[data-craft]', body).forEach(b => b.onclick = () => guard(b, () => act('world_craft_item', { p_recipe_id: b.dataset.craft })));
}

function bindActions(body) {
  $$('[data-use]', body).forEach(b => b.onclick = () => guard(b, () => act('world_use_item', { p_item_id: b.dataset.use })));
  $$('[data-equip]', body).forEach(b => b.onclick = () => guard(b, () => act('world_equip_item', { p_item_id: b.dataset.equip })));
}
