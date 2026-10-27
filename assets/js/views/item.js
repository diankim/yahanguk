// 물품 정보 창: 가방·상점·거래소에서 함께 쓴다.
// 설명·효과·조건·거래 가능 여부·기준 시세와, 이 물품이 들어가는(또는 이 물품을 만드는) 제작법을 보여 준다.
// 가방에서 열면 사용·장착·잠금·버리기도 할 수 있다(모두 서버가 다시 검사한다).
import { ask, db, store, act, nameOf, esc, josa, icon, guard, $, $$, fmt, openModal, closeModal, openLayer, closeLayers, effectText, toast, stackOf } from '../core.js';
import { load, chip } from './common.js';

export const USABLE = { tonic: '체력 35 · 마음 진정', herbal_extract: '체력 22 · 출혈·화상 치료', herb: '체력 12 · 중독 치료', medicine_base: '정신 12 · 피로·한기 치료',
  ward_talisman: '정신 8 · 침식 완화', travel_ration: '탐색력 +5', revival_charm: '전투불능에서 일어나기',
  // 영력 회복약(낮은 단계부터)
  spirit_tea: '영력 10', clear_spirit_pill: '영력 20', spirit_qi_pill: '영력 35', moonlight_essence: '영력 55 · 심신 동요 치료', heavenly_dew: '영력 80 · 심신 동요·사념 침식 치료',
  // 요리(서버 world_use_item과 같은 값)
  grilled_fish: '체력 25 · 든든함(채집량·회복량)', spicy_stew: '체력 30 · 정신 10 · 속이 따뜻함(침식·받는 피해 감소)', fish_porridge: '정신 15 · 탐색력 +4',
  eel_tonic: '체력 45 · 기운 충천(주는 피해·이동 시간)', carp_broth: '체력 60 · 정신 20 · 든든함 · 속이 따뜻함', bream_sashimi: '체력 40 · 정신 10 · 바다의 복 · 기운 충천',
  herb_fish_steam: '체력 40 · 중독 치료 · 기운 충천', spirit_gukbap: '체력 30 · 정신 15 · 영력 15 · 탐색력 +3 · 속이 따뜻함',
  // 연금
  rejuv_pill: '체력 60 · 출혈·화상·삠·중독 치료(전투 중에도)', grand_pill: '체력 100 · 정신 20 · 동요·탈진 치료(전투 중에도)',
  purify_water: '침식 -20 · 정신 5 · 사념 침식 치료', calm_brew: '정신 30 · 동요·피로 치료' };
export const GEAR = new Set(['tool', 'weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'accessory', 'equipment']);
// 분해할 수 있는 장비와 필요한 제작 숙련(서버 world_dismantle_need와 같다)
const DISMANTLABLE = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool']);
const dismantleNeed = t => ({ 1: 1, 2: 4, 3: 8, 4: 12 })[t || 1] || 16;
// 장착 칸(서버 world_equip_item·world_unequip_item과 같은 이름): [이름, 아이콘, 닳는 때]
export const SLOTS = { weapon: ['무기', 'sword', '공격할 때'], armor: ['방어구', 'shield', '맞을 때'], hat: ['관모', 'hat', '맞을 때'], shoes: ['신', 'shoe', '이동할 때'],
  norigae: ['노리개', 'knot', ''], amulet: ['호신부', 'talisman', ''], mask: ['탈', 'mask', ''], tool: ['도구', 'hammer', '채집할 때'] };
const STY = { melee: '근접 공격', ranged: '원거리 공격', magic: '술법 공격' };

// 잠근 물품 목록(서버 world_item_locks, 내 것만 보인다)
let locks = null;
export async function loadLocks(force) {
  if (locks && !force) return locks;
  try {
    const { data, error } = await db.from('world_item_locks').select('item_id');
    if (error) throw error;
    locks = new Set((data || []).map(r => r.item_id));
  } catch { locks = locks || new Set(); }
  return locks;
}
export const isLocked = id => !!locks?.has(id);

// 장착 조건(서버 world_equip_item과 같은 순서): 레벨 → 직업 → 소속 → 능력치
export const gearBlock = (o, c) => {
  if (!o) return '';
  if (o.minimum_level > (c?.level || 1)) return `Lv.${o.minimum_level} 필요`;
  if (o.required_job && o.required_job !== c?.job_key) return `${nameOf(o.required_job)} 전용`;
  if (o.required_faction && o.required_faction !== c?.faction_key) return `${nameOf(o.required_faction)} 전용`;
  for (const [k, v] of Object.entries(o.required_stats || {})) if (Number(c?.[k] || 0) < Number(v)) return `${nameOf(k)} ${v} 필요 (지금 ${Number(c?.[k] || 0)})`;
  return '';
};
// 장착 조건 목록: [글, 채웠는지]. 레벨 1·조건 없음은 뺀다
export function gearReqs(o, c) {
  if (!o) return [];
  const out = [];
  if (o.minimum_level > 1) out.push([`Lv.${o.minimum_level} 이상`, (c?.level || 1) >= o.minimum_level]);
  if (o.required_job) out.push([`${nameOf(o.required_job)} 전용`, o.required_job === c?.job_key]);
  if (o.required_faction) out.push([`${nameOf(o.required_faction)} 전용`, o.required_faction === c?.faction_key]);
  for (const [k, v] of Object.entries(o.required_stats || {})) out.push([`${nameOf(k)} ${v} 이상`, Number(c?.[k] || 0) >= Number(v)]);
  return out;
}
export const gearReqHtml = (o, c) => gearReqs(o, c).map(([t, ok]) => `<span class="req ${ok ? 'ok' : 'bad'}">${esc(t)}</span>`).join('');

export function traitText(it) {
  const t = it?.equipment_traits; if (!t) return '';
  return [STY[t.weapon_type] || t.trait, ...effectText(t)].filter(Boolean).join(' · ');
}

// mode: 'bag'(행동 단추 포함) | 'view'(정보만)
export async function openItemInfo(id, { mode = 'view' } = {}) {
  // 상점·거래소 같은 창이 열려 있으면 그 위에 겹쳐 띄워, 닫아도 아래 창이 남는다
  const opts = { title: nameOf(id), wide: true, body: '<div class="item-info"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' };
  const m = document.getElementById('modal') ? openLayer(opts) : openModal(opts);
  const box = $('.item-info', m);
  try {
    const [inv, prices] = await Promise.all([load('world_inventory_snapshot', undefined, { maxAge: 10000 }), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), loadLocks()]);
    draw(box, id, inv, new Map((prices || []).map(p => [p.item_id, p])), mode);
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}

function draw(box, id, inv, prices, mode) {
  const c = store.character, it = (inv.catalog || []).find(x => x.id === id), pr = prices.get(id);
  const have = Number(inv.inventory?.[id] || 0), equipped = Object.values(inv.equipment || {}).includes(id), locked = isLocked(id);
  const uses = (inv.recipes || []).filter(r => r.ingredients && r.ingredients[id]);
  const makes = (inv.recipes || []).filter(r => r.output === id);
  const block = it && GEAR.has(it.category) ? gearBlock(it, c) : '';
  const tradeable = pr ? pr.tradeable !== false : null;
  const recipeRow = r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => Number(inv.inventory?.[k] || 0) < n).length;
    return `<li><div><b>${esc(r.name)}</b><small>${esc(Object.entries(r.ingredients || {}).map(([k, n]) => `${nameOf(k)} ${n}`).join(' · '))} → ${esc(r.output_name || nameOf(r.output))} ×${r.qty || 1}</small></div>
      <button class="btn small ${lacks ? '' : 'primary'}" data-recipe="${esc(r.id)}">${lacks ? '제작법 보기' : '만들 수 있음'}</button></li>`;
  };
  box.innerHTML = `
    <div class="chips">${it ? chip(nameOf(it.category)) : ''}${it?.tier ? chip(`${it.tier}단계`) : ''}${chip(nameOf(it?.rarity || 'common'), 'rar')}
      ${equipped ? chip('장착 중', 'accent') : ''}${locked ? chip('잠금', 'warn') : ''}${tradeable === false ? chip('거래 불가', 'bad') : tradeable ? chip('거래 가능', 'ok') : ''}</div>
    ${it?.description ? `<p class="desc">${esc(it.description)}</p>` : ''}
    <dl class="kv info">
      <div><dt>가진 수량</dt><dd>${fmt.num(have)}개${have > 0 ? ` · ${fmt.num(Math.ceil(have / stackOf(id)))}칸` : ''}</dd></div>
      <div><dt>한 칸에</dt><dd>${fmt.num(stackOf(id))}개까지</dd></div>
      ${pr?.reference_price ? `<div><dt>기준 시세</dt><dd>${fmt.jeon(pr.reference_price)}</dd></div>` : ''}
      ${pr?.npc_sell_price ? `<div><dt>상점 매입</dt><dd>약 ${fmt.jeon(pr.npc_sell_price)}</dd></div>` : ''}
      ${traitText(it) ? `<div><dt>효과</dt><dd>${esc(traitText(it))}</dd></div>` : ''}
      ${USABLE[id] ? `<div><dt>사용하면</dt><dd>${esc(USABLE[id])}</dd></div>` : ''}
      ${it && GEAR.has(it.category) ? `<div><dt>장착 조건</dt><dd class="reqs">${gearReqHtml(it, c) || '<span class="req ok">누구나</span>'}</dd></div>` : (it?.minimum_level > 1 ? `<div><dt>필요 레벨</dt><dd>Lv.${it.minimum_level}</dd></div>` : '')}
    </dl>
    ${uses.length ? `<h3 class="sub-h">이 물품이 들어가는 제작법 ${uses.length}</h3><ul class="spot-list">${uses.map(recipeRow).join('')}</ul>
      <button class="btn small ghost" data-mat="${esc(id)}">${icon('hammer', 14)}<span>이 재료로 만들 수 있는 것 모두 보기</span></button>` : ''}
    ${makes.length ? `<h3 class="sub-h">이 물품을 만드는 제작법</h3><ul class="spot-list">${makes.map(recipeRow).join('')}</ul>` : ''}
    ${!uses.length && !makes.length ? '<p class="muted small">이 물품과 관련된 제작법이 없습니다.</p>' : ''}
    ${mode === 'bag' && have > 0 ? `<h3 class="sub-h">다루기</h3>
      <div class="btn-row">
        ${USABLE[id] ? `<button class="btn small primary" data-do="use">${icon('heart', 14)}<span>사용</span></button>` : ''}
        ${it && GEAR.has(it.category) && !equipped ? (block ? `<span class="bad small">${esc(block)}</span>` : `<button class="btn small primary" data-do="equip">${icon('shield', 14)}<span>장착</span></button>`) : ''}
        <button class="btn small" data-do="lock">${icon(locked ? 'check' : 'shield', 14)}<span>${locked ? '잠금 풀기' : '잠그기'}</span></button>
        ${it && DISMANTLABLE.has(it.category) ? (() => { const need = dismantleNeed(it.tier), rank = c?.crafting_rank || 1;
          return rank < need ? `<span class="muted small">분해: 제작 숙련 ${need}단계부터(지금 ${rank})</span>`
            : `<button class="btn small" data-do="dismantle" ${locked || (equipped && have <= 1) ? 'disabled' : ''}>${icon('hammer', 14)}<span>분해</span></button>`; })() : ''}
      </div>
      <div class="discard-row ${locked ? 'off' : ''}">
        <label class="field"><span>버릴 수량</span><input type="number" min="1" max="${have}" value="1" id="dc-qty" ${locked ? 'disabled' : ''}></label>
        <button class="btn small danger" data-do="discard" ${locked ? 'disabled' : ''}>${icon('close', 14)}<span>버리기</span></button>
      </div>
      <p class="muted small">${locked ? '잠근 물품은 팔거나 버리거나 거래할 수 없습니다. 사용과 제작 재료로는 쓸 수 있습니다.' : equipped ? '장착 중인 마지막 한 개는 팔거나 버릴 수 없습니다.' : '버린 물품은 되찾을 수 없습니다.'}</p>` : ''}`;

  box.onclick = async e => {
    const r = e.target.closest('[data-recipe]'), mat = e.target.closest('[data-mat]'), d = e.target.closest('[data-do]');
    if (r || mat) {
      closeLayers(); closeModal();
      window.dispatchEvent(new CustomEvent('yh-craft-focus', { detail: r ? { recipe: r.dataset.recipe } : { material: mat.dataset.mat } }));
      window.yahangGo?.('bag', 'craft');
      return;
    }
    if (!d) return;
    const k = d.dataset.do;
    if (k === 'use') await guard(d, () => act('world_use_item', { p_item_id: id }));
    if (k === 'equip') await guard(d, () => act('world_equip_item', { p_item_id: id }));
    if (k === 'lock') await guard(d, async () => { const out = await act('world_item_lock', { p_item_id: id, p_locked: !locked }); await loadLocks(true); return out; });
    if (k === 'dismantle') {
      if (!(await ask(`${nameOf(id)} 하나를 분해해 제작 재료 일부를 돌려받을까요? 되돌릴 수 없습니다.`, { title: '분해', ok: '분해하기' }))) return;
      await guard(d, () => act('world_dismantle_item', { p_item_id: id }));
    }
    if (k === 'discard') {
      const q = Math.floor(Number($('#dc-qty', box)?.value) || 0);
      if (!(q >= 1 && q <= have)) return toast(`1~${have}개 사이로 정하세요.`, 'error');
      if (!(await ask(`${nameOf(id)} ×${q}을(를) 버릴까요? 되찾을 수 없습니다.`, { title: '버리기', ok: '버리기', danger: true }))) return;
      await guard(d, () => act('world_item_discard', { p_item_id: id, p_qty: q }));
    }
    // 바뀐 가방으로 창을 다시 그린다(다 써서 0개가 되면 정보만 남는다)
    try {
      const [inv2, prices2] = await Promise.all([load('world_inventory_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => [])]);
      if (box.isConnected) draw(box, id, inv2, new Map((prices2 || []).map(p => [p.item_id, p])), mode);
    } catch {}
  };
}
