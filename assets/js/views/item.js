// 물품 정보 창: 가방·상점·거래소에서 함께 쓴다.
// 설명·효과·조건·거래 가능 여부·기준 시세와, 이 물품이 들어가는(또는 이 물품을 만드는) 제작법을 보여 준다.
// 가방에서 열면 사용·장착·잠금·버리기도 할 수 있다(모두 서버가 다시 검사한다).
import { ask, db, store, act, nameOf, esc, josa, icon, guard, $, $$, fmt, openModal, closeModal, openLayer, closeLayers, effectText, toast, stackOf, JOBS, FACTIONS, RAID_ON } from '../core.js';
import { loreBundle, rebirthScene } from '../lore.js';
import { load, chip } from './common.js';

export const USABLE = { reset_identity: '직업·소속 다시 고르기 · 능력치 포인트 돌려받기', reset_stats: '능력치를 처음으로 · 포인트 돌려받기', tonic: '체력 35 · 마음 진정', herbal_extract: '체력 22 · 출혈·화상 치료', herb: '체력 12 · 중독 치료', medicine_base: '정신 12 · 피로·한기 치료',
  ward_talisman: '정신 8 · 침식 완화', travel_ration: '탐색력 +2', revival_charm: '전투불능에서 일어나기', gwiryeong_cho: '요화 풀기 · 침식 -20',
  // 영력 회복약(낮은 단계부터)
  spirit_tea: '영력·기력 10', clear_spirit_pill: '영력·기력 20', spirit_qi_pill: '영력·기력 35', moonlight_essence: '영력·기력 55 · 심신 동요 치료', heavenly_dew: '영력·기력 80 · 심신 동요·사념 침식 치료',
  // 요리(서버 world_use_item과 같은 값)
  herb_rice: '체력 20 · 든든함', moss_porridge: '체력 35 · 정신 10 · 속이 따뜻함', bark_stew: '체력 50 · 정신 10 · 기운 충천',
  grilled_fish: '체력 25 · 든든함(채집량·회복량)', spicy_stew: '체력 30 · 정신 10 · 속이 따뜻함(침식·받는 피해 감소)', fish_porridge: '정신 15 · 탐색력 +4',
  eel_tonic: '체력 45 · 기운 충천(주는 피해·이동 시간)', carp_broth: '체력 60 · 정신 20 · 든든함 · 속이 따뜻함', bream_sashimi: '체력 40 · 정신 10 · 바다의 복 · 기운 충천',
  herb_fish_steam: '체력 40 · 중독 치료 · 기운 충천', spirit_gukbap: '체력 30 · 정신 15 · 영력 15 · 탐색력 +3 · 속이 따뜻함',
  sweetfish_grill: '체력 30 · 정신 5 · 든든함', catfish_braise: '체력 45 · 중독 치료 · 속이 따뜻함', snakehead_broth: '체력 35 · 정신 15 · 탈진·피로 치료 · 기운 충천',
  goby_soup: '정신 25 · 침식 -8 · 심신 동요 치료', hairtail_braise: '체력 50 · 정신 10 · 든든함', dried_croaker: '체력 15 · 탐색력 +3 · 든든함',
  croaker_soup: '체력 60 · 정신 15 · 속이 따뜻함 · 기운 충천', char_grill: '체력 40 · 정신 10 · 한기 치료 · 든든함', salmon_grill: '체력 40 · 정신 10 · 영력 10 · 든든함',
  trout_sashimi: '체력 25 · 정신 10 · 기운 충천', mirror_soup: '정신 35 · 영력 30 · 침식 -10 · 속이 따뜻함', hagfish_grill: '체력 55 · 정신 10 · 기운 충천',
  ray_steam: '체력 70 · 정신 30 · 침식 -15 · 속이 따뜻함 · 기운 충천', koi_broth: '체력 100 · 정신 40 · 영력 40 · 기운 충천 · 바다의 복 · 속이 따뜻함',
  dragon_feast: '체력 100 · 정신 50 · 영력 50 · 침식 -25 · 기운 충천 · 바다의 복 · 속이 따뜻함 · 든든함',
  wraith_soul_pill: '정신 40 · 침식 -15 · 심신 동요·사념 침식 치료', fish_oil_lamp: '등잔빛 40분(요괴 조우 -15% · 침식 -5% · 정신 손실 -10%)',
  guide_lantern: '탐색력 +10', trail_map: '지금 있는 지역의 비경을 3시간 동안 엶(채집량 +50% · 희귀품·단서 +10%)', exp_elixir_iron: '철벽 30분(받는 피해 -15%)',
  exp_elixir_tiger: '맹호 30분(주는 피해 +12%)', exp_elixir_clear: '청명 30분(침식 -30% · 정신 손실 -15%)', sealed_bundle: '열면 장비·회복약·전 가운데 하나',
  // 연금
  rejuv_pill: '체력 60 · 출혈·화상·삠·중독 치료(전투 중에도)', grand_pill: '체력 100 · 정신 20 · 동요·탈진 치료(전투 중에도)',
  purify_water: '침식 -20 · 정신 5 · 사념 침식 치료', calm_brew: '정신 30 · 동요·피로 치료',
  // 반요촌(귀허도)
  banyo_salve: '체력 70 · 정신 15 · 출혈·화상·중독 치료', oblivion_incense: '침식 -30 · 정신 20 · 사념 침식·심신 동요 치료' };
export const GEAR = new Set(['tool', 'weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'accessory', 'equipment']);
// 분해할 수 있는 장비와 필요한 제작 숙련(서버 world_dismantle_need와 같다)
const DISMANTLABLE = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool']);
const dismantleNeed = t => ({ 1: 1, 2: 5, 3: 10, 4: 15 })[t || 1] || 20; // 서버 world_dismantle_need와 같다
// 장착 칸(서버 world_equip_item·world_unequip_item과 같은 이름): [이름, 아이콘, 닳는 때]
export const SLOTS = { weapon: ['무기', 'sword', '공격할 때'], armor: ['방어구', 'shield', '맞을 때'], hat: ['관모', 'hat', '맞을 때'], shoes: ['신', 'shoe', '이동할 때'],
  norigae: ['노리개', 'knot', ''], amulet: ['호신부', 'talisman', ''], mask: ['탈', 'mask', ''], tool: ['채집', 'hammer', '채집할 때'], explore: ['탐사', 'compass', ''], fishing: ['낚시', 'fish', ''] };
// 장착 칸: 도구는 equipment_traits.life_slot(탐사 explore·낚시 fishing, 없으면 채집 tool)으로 나뉜다(서버 world_equip_item과 같은 규칙)
export const slotOf = it => it?.category === 'tool' ? (it.equipment_traits?.life_slot || 'tool') : it?.category;
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

// 장신구(관모·신·노리개·호신부·탈)는 적힌 능력치 대신 가장 높은 능력치가 그 값 이상이면 된다(6.0.0, 서버 world_equip_item과 같음)
const ACCESSORY = new Set(['hat', 'shoes', 'norigae', 'amulet', 'mask']);
const STAT_KEYS = ['strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity'];
const STAT_PAIR = { vitality: 'strength', strength: 'vitality', agility: 'perception', perception: 'agility', willpower: 'spirit_affinity', spirit_affinity: 'willpower' };
const topStat = c => Math.max(...STAT_KEYS.map(k => Number(c?.[k] || 0)));
// 생활 도구는 능력치 대신 숙련 단계(7.0.0, equipment_traits.req_line·req_rank, 서버 world_equip_item과 같음)
const RANK_NAME = { gathering_rank: '채집 숙련', crafting_rank: '제작 숙련', investigation_rank: '조사 숙련' };
const statReqs = (o, c) => {
  const tr = o.equipment_traits || {};
  if (o.category === 'tool' && Number(tr.req_rank) > 1) {
    const n = RANK_NAME[tr.req_line] || '채집 숙련', have = Number(c?.[tr.req_line] || 1), need = Number(tr.req_rank);
    return [[`${n} ${need}단계 이상`, have >= need, `${n} ${need}단계 필요 (지금 ${have}단계)`]];
  }
  const req = Object.entries(o.required_stats || {});
  if (!req.length) return [];
  if (ACCESSORY.has(o.category)) { const v = Math.max(...req.map(([, n]) => Number(n))); return [[`가장 높은 능력치 ${v} 이상`, topStat(c) >= v, `가장 높은 능력치 ${v} 필요 (지금 ${topStat(c)})`]]; }
  // 방어구는 적힌 능력치와 짝(체질↔근력·민첩↔감각·의지↔영성) 가운데 높은 것으로 본다(7.1)
  if (o.category === 'armor') return req.map(([k, v]) => { const p = STAT_PAIR[k] || k, have = Math.max(Number(c?.[k] || 0), Number(c?.[p] || 0));
    return [`${nameOf(k)} 또는 ${nameOf(p)} ${v} 이상`, have >= Number(v), `${nameOf(k)} 또는 ${nameOf(p)} ${v} 필요 (지금 ${have})`]; });
  return req.map(([k, v]) => [`${nameOf(k)} ${v} 이상`, Number(c?.[k] || 0) >= Number(v), `${nameOf(k)} ${v} 필요 (지금 ${Number(c?.[k] || 0)})`]);
};
// 장착 조건(서버 world_equip_item과 같은 순서): 레벨 → 직업 → 소속 → 능력치
export const gearBlock = (o, c) => {
  if (!o) return '';
  if (o.minimum_level > (c?.level || 1)) return `Lv.${o.minimum_level} 필요`;
  if (o.required_job && o.required_job !== c?.job_key) return `${nameOf(o.required_job)} 전용`;
  if (o.required_faction && o.required_faction !== c?.faction_key) return `${nameOf(o.required_faction)} 전용`;
  const miss = statReqs(o, c).find(r => !r[1]);
  return miss ? miss[2] : '';
};
// 장착 조건 목록: [글, 채웠는지]. 레벨 1·조건 없음은 뺀다
export function gearReqs(o, c) {
  if (!o) return [];
  const out = [];
  if (o.minimum_level > 1) out.push([`Lv.${o.minimum_level} 이상`, (c?.level || 1) >= o.minimum_level]);
  if (o.required_job) out.push([`${nameOf(o.required_job)} 전용`, o.required_job === c?.job_key]);
  if (o.required_faction) out.push([`${nameOf(o.required_faction)} 전용`, o.required_faction === c?.faction_key]);
  for (const [t, ok] of statReqs(o, c)) out.push([t, ok]);
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

// 얻는 곳: 서버 world_item_sources(물품마다 이 접속 동안 기억)
const srcCache = new Map();
async function fillSources(box, id) {
  const dd = $('[data-src]', box); if (!dd) return;
  try {
    if (!srcCache.has(id)) srcCache.set(id, await load('world_item_sources', { p_item: id }));
    const s = srcCache.get(id) || {};
    const part = (label, list, n) => list?.length ? `<span class="src"><b>${label}</b> ${esc(list.join(' · '))}${n > list.length ? ` 외 ${n - list.length}곳` : ''}</span>` : '';
    const html = [part('채집', s.gather, s.gather_n), part('조사', s.sites, s.sites_n), part('요괴', s.monsters, s.monsters_n), part('낚시', s.fish, s.fish_n)].filter(Boolean).join('');
    // 사는 곳: 대장간(모든 안전지대)·안전지대 상점(회차마다 품목이 바뀜)·세력 비고(공훈)
    const buy = [s.smithy && '대장간', s.shop && '안전지대 상점(회차마다 바뀜)', s.vault && '세력 비고(공훈)'].filter(Boolean);
    const extra = [s.craft && '<span class="src"><b>제작</b> 가방 › 제작</span>', buy.length && `<span class="src"><b>사기</b> ${esc(buy.join(' · '))}</span>`].filter(Boolean).join('');
    dd.innerHTML = (html + extra) || '<span class="muted">원정·이야기·특별한 보상으로 얻습니다</span>';
  } catch { dd.textContent = '-'; }
}
function draw(box, id, inv, prices, mode) {
  const c = store.character, it = (inv.catalog || []).find(x => x.id === id), pr = prices.get(id);
  const have = Number(inv.inventory?.[id] || 0), equipped = Object.values(inv.equipment || {}).includes(id), locked = isLocked(id);
  const dcMax = Math.max(0, have - (equipped ? 1 : 0));
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
    <p class="item-lore" data-lore hidden></p>
    <dl class="kv info">
      <div><dt>가진 수량</dt><dd>${fmt.num(have)}개${have > 0 ? ` · ${fmt.num(Math.ceil(have / stackOf(id)))}칸` : ''} <small class="muted">(한 칸 ${fmt.num(stackOf(id))}개)</small></dd></div>
      ${pr?.reference_price ? `<div><dt>기준 시세</dt><dd>${fmt.jeon(pr.reference_price)}</dd></div>` : ''}
      ${pr?.npc_sell_price ? `<div><dt>상점 매입</dt><dd>약 ${fmt.jeon(pr.npc_sell_price)}</dd></div>` : ''}
      ${traitText(it) ? `<div><dt>효과</dt><dd>${esc(traitText(it))}</dd></div>` : ''}
      ${USABLE[id] ? `<div><dt>사용하면</dt><dd>${esc(USABLE[id])}</dd></div>` : ''}
      <div class="wide src-row"><dt>얻는 곳</dt><dd data-src>확인 중…</dd></div>
      ${it && GEAR.has(it.category) ? `<div><dt>${slotOf(it) === 'craft' ? '쓰는 조건(가방에 두면)' : '장착 조건'}</dt><dd class="reqs">${gearReqHtml(it, c) || '<span class="req ok">누구나</span>'}</dd></div>` : (it?.minimum_level > 1 ? `<div><dt>필요 레벨</dt><dd>Lv.${it.minimum_level}</dd></div>` : '')}
    </dl>
    ${uses.length ? `<h3 class="sub-h">이 물품이 들어가는 제작법 ${uses.length}</h3><ul class="spot-list">${uses.map(recipeRow).join('')}</ul>
      <button class="btn small ghost" data-mat="${esc(id)}">${icon('hammer', 14)}<span>이 재료로 만들 수 있는 것 모두 보기</span></button>` : ''}
    ${makes.length ? `<h3 class="sub-h">이 물품을 만드는 제작법</h3><ul class="spot-list">${makes.map(recipeRow).join('')}</ul>` : ''}
    ${!uses.length && !makes.length ? '<p class="muted small">이 물품과 관련된 제작법이 없습니다.</p>' : ''}
    ${mode === 'bag' && have > 0 ? `<h3 class="sub-h">다루기</h3>
      <div class="btn-row">
        ${USABLE[id] ? `<button class="btn small primary" data-do="use">${icon('heart', 14)}<span>사용</span></button>` : ''}
        ${it?.category === 'pet' ? `<button class="btn small primary" data-do="adopt">${icon('heart', 14)}<span>열기</span></button>` : ''}
        ${it?.category === 'furniture' ? `<button class="btn small" data-do="house">${icon('home', 14)}<span>별채에서 놓기</span></button>` : ''}
        ${it && GEAR.has(it.category) && slotOf(it) !== 'craft' && !equipped ? (block ? `<span class="bad small">${esc(block)}</span>` : `<button class="btn small primary" data-do="equip">${icon('shield', 14)}<span>장착</span></button>`) : ''}
        <button class="btn small" data-do="lock">${icon(locked ? 'check' : 'shield', 14)}<span>${locked ? '잠금 풀기' : '잠그기'}</span></button>
        ${it && DISMANTLABLE.has(it.category) ? (() => { const need = dismantleNeed(it.tier), rank = c?.crafting_rank || 1;
          return rank < need ? `<span class="muted small">분해: 제작 숙련 ${need}단계부터(지금 ${rank})</span>`
            : `<button class="btn small" data-do="dismantle" ${locked || (equipped && have <= 1) ? 'disabled' : ''}>${icon('hammer', 14)}<span>분해</span></button>`; })() : ''}
      </div>
      <div class="discard-row ${locked ? 'off' : ''}">
        <label class="field"><span>버릴 수량 <small class="muted">· 가진 ${have}개</small></span><input type="number" min="1" max="${dcMax}" value="1" id="dc-qty" ${locked || dcMax < 1 ? 'disabled' : ''}></label>
        <button class="btn small ghost" data-do="dc-max" ${locked || dcMax < 1 ? 'disabled' : ''}>최대</button>
        <button class="btn small danger" data-do="discard" ${locked || dcMax < 1 ? 'disabled' : ''}>${icon('close', 14)}<span>버리기</span></button>
        ${dcMax > 1 ? `<button class="btn small danger" data-do="discard-all" ${locked ? 'disabled' : ''}>${icon('close', 14)}<span>모두 버리기</span></button>` : ''}
      </div>
      <p class="muted small">${locked ? '잠근 물품은 팔거나 버리거나 거래할 수 없습니다. 사용과 제작 재료로는 쓸 수 있습니다.' : equipped ? '장착 중인 마지막 한 개는 팔거나 버릴 수 없습니다.' : '버린 물품은 되찾을 수 없습니다.'}</p>` : ''}`;

  fillSources(box, id);
  // 물품 내력(6.1.1, 서버 world_lore_bundle)
  loreBundle().then(l => { const p = $('[data-lore]', box); if (p && l.items?.[id]) { p.textContent = l.items[id]; p.hidden = false; } });
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
    if (k === 'use') await useItem(id, d);
    if (k === 'adopt') await guard(d, () => act('world_pet_adopt', { p_item: id }));
    if (k === 'house') { closeLayers(); closeModal(); window.yahangGo?.('house'); return; }
    if (k === 'equip') await guard(d, () => act('world_equip_item', { p_item_id: id }));
    if (k === 'lock') await guard(d, async () => { const out = await act('world_item_lock', { p_item_id: id, p_locked: !locked }); await loadLocks(true); return out; });
    if (k === 'dismantle') {
      if (!(await ask(`${nameOf(id)} 하나를 분해해 제작 재료 일부를 돌려받을까요? 되돌릴 수 없습니다.`, { title: '분해', ok: '분해하기' }))) return;
      await guard(d, () => act('world_dismantle_item', { p_item_id: id }));
    }
    // 버리기(제보 12): 「최대」는 칸을 채우고, 「모두 버리기」는 버릴 수 있는 만큼 한 번에(장착 중이면 하나 남김)
    if (k === 'dc-max') { const q = $('#dc-qty', box); if (q) q.value = dcMax; return; }
    if (k === 'discard' || k === 'discard-all') {
      const q = k === 'discard-all' ? dcMax : Math.floor(Number($('#dc-qty', box)?.value) || 0);
      if (!(q >= 1 && q <= dcMax)) return toast(`1~${dcMax}개 사이로 정하세요.`, 'error');
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

// 물품 쓰기: 초기화 물품 두 가지는 확인 창·선택 창을 거쳐 전용 서버 함수로 쓴다
export async function useItem(id, btn) {
  if (id === 'reset_stats') {
    if (!(await ask('능력치를 모두 직업 기본값으로 되돌리고 쓴 포인트를 돌려받을까요? 세심단 하나를 씁니다.', { title: '세심단', ok: '쓰기' }))) return;
    return guard(btn, () => act('world_reset_stats'));
  }
  if (id === 'reset_identity') return openResetIdentity();
  return guard(btn, () => act('world_use_item', { p_item_id: id }));
}
function openResetIdentity() {
  const c = store.character || {};
  const m = openModal({ title: '환골탈태 서첩', body: `
    <p class="muted small">직업과 소속을 다시 고릅니다. 대세력에서 나오고(평판 0) 능력치는 새 직업의 기본값으로 돌아가 쓴 포인트를 모두 돌려받습니다. 레벨·물품·전·칭호·기술은 그대로이고, 새 직업·소속으로 찰 수 없는 장비는 벗깁니다.</p>
    <h3 class="sub-h">직업</h3>
    <div class="choice-grid ri-grid">${Object.entries(JOBS).map(([k, j]) => `<label class="choice"><input type="radio" name="rj" value="${k}" ${k === c.job_key ? 'checked' : ''}><span><b>${esc(j.name)}</b><small>${esc(j.trait || '')}</small></span></label>`).join('')}</div>
    <h3 class="sub-h">소속</h3>
    <div class="choice-grid ri-grid">${Object.entries(FACTIONS).filter(([k]) => ['headquarters', 'fieldbureau', 'archivebureau', 'sealbureau', 'medicalbureau', 'independent'].includes(k)).map(([k, f]) => `<label class="choice"><input type="radio" name="rf" value="${k}" ${k === c.faction_key ? 'checked' : ''}><span><b>${esc(f.name)}</b><small>${esc(f.trait || '')}</small></span></label>`).join('')}</div>
    <div class="modal-actions sticky-actions"><button class="btn primary" id="ri-go">${icon('spark', 15)}<span>이대로 다시 시작</span></button></div>` });
  $('#ri-go', m).onclick = async e => {
    const job = $('input[name=rj]:checked', m)?.value, fac = $('input[name=rf]:checked', m)?.value;
    if (!job || !fac) return toast('직업과 소속을 고르세요.', 'error');
    if (!(await ask(`${JOBS[job]?.name} · ${FACTIONS[fac]?.name}(으)로 다시 시작할까요? 서첩 하나를 쓰고, 되돌릴 수 없습니다.`, { title: '환골탈태', ok: '다시 시작' }))) return;
    await guard(e.currentTarget, async () => { const out = await act('world_reset_identity', { p_job: job, p_faction: fac }); closeModal(); if (RAID_ON) rebirthScene(job, fac); return out; });
  };
}
