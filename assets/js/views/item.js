import { ask, db, store, on, act, rpc, nameOf, esc, icon, guard, $, $$, fmt, openModal, closeModal, openLayer, closeLayers, effectText, toast, stackOf, JOBS, FACTIONS, RAID_ON, useItemAct } from '../core.js';
import { loreBundle, rebirthScene } from '../lore.js';
import { load, chip, zonesNow, catItem, fxNames } from './common.js';
import { itemSources, regionBtn, sourcesMore, SRC_KINDS } from '../sources.js';
import { baseOf, isHq, pairOf, hqOf } from '../hq.js';
import { isFurniture, myHomeCounts } from '../housing/count.js';
import { GWIRYEONG, weakSafe } from '../rules.js';
import { GAMEDATA as GD } from '../gamedata.js';
import { qtyHtml, bindQty, qtyOf, actBox } from './itempick.js';

const USE_SPECIAL = { reset_identity: '직업·소속 다시 고르기 · 능력치 포인트 돌려받기', reset_stats: '능력치를 처음으로 · 포인트 돌려받기',
  revival_charm: '전투불능에서 일어나기', gwiryeong_cho: '요화 풀기 · 침식 −20',
  trail_map: '지금 있는 지역의 비경을 3시간 동안 엶(채집량 +50% · 희귀품·단서 +10%)', sealed_bundle: '열면 장비·회복약·전 가운데 하나' };
const useCache = new Map();
function useText(id) {
  if (USE_SPECIAL[id]) return USE_SPECIAL[id];
  const f = catItem(id)?.fx;
  if (!f) return undefined;
  if (useCache.has(id)) return useCache.get(id);
  const names = fxNames(), nm = k => names[k]?.n || nameOf(k), out = [];
  if (f.hp > 0) out.push(`체력 ${f.hp}`);
  if (f.mn > 0) out.push(`정신 ${f.mn}`);
  if (f.sp > 0) out.push(`영력·기력 ${f.sp}`);
  if (f.er > 0) out.push(`침식 −${f.er}`);
  if (f.stam > 0) out.push(`탐색력 +${f.stam}`);
  if (f.cures?.length) out.push(`${f.cures.map(nm).join('·')} 치료`);
  for (const b of f.buffs || []) {
    const s = names[b], fx = effectText(s?.e || {});
    out.push(`${nm(b)}${s?.m ? ` ${s.m}분` : ''}${fx.length ? `(${fx.join(', ')})` : ''}`);
  }
  const t = out.join(' · ') || undefined;
  useCache.set(id, t);
  return t;
}
on('catalog', () => useCache.clear());
export const USABLE = new Proxy({}, {
  get(t, k) {
    if (typeof k !== 'string') return undefined;
    const v = useText(k);
    if (v || !isHq(k)) return v;
    const b = useText(baseOf(k)), f = catItem(baseOf(k))?.fx;
    return b ? `${b} · 우수품 효과 더 큼${f?.stam > 0 ? '(탐색력은 같음)' : ''}` : undefined;
  },
  has(t, k) { return !!this.get(t, k); },
});
export const GW_HEAL = GD.battleItems?.gw?.items || [];
export function bossUse(id) {
  const b = baseOf(id), f = catItem(b)?.fx;
  const raid = !!f && (f.hp > 0 || f.mn > 0 || f.sp > 0), gw = GW_HEAL.includes(b);
  return raid || gw ? { raid, gw, label: raid && gw ? '토벌·귀허' : raid ? '토벌' : '귀허',
    tip: [raid && '봉연의 그림자·10장 결전에서 「물품」으로 사용(결전은 체력 회복품 한 싸움 다섯 개)', gw && '귀허의 주인과 싸울 때 사용(한 싸움 두 개)'].filter(Boolean).join(' / ') } : null;
}
export const FX_KINDS = [['hp', '체력', /^체력/], ['mind', '정신', /^정신/], ['sp', '영력·기력', /^영력/], ['er', '침식', /^침식/], ['cure', '치료', /치료|풀기|일어나기/], ['stam', '탐색력', /^탐색력/]];
const FX_ORDER = ['cure', 'hp', 'mind', 'sp', 'er', 'stam'].map(k => FX_KINDS.find(x => x[0] === k));
const fxKindOf = seg => (FX_ORDER.find(([, , re]) => re.test(seg)) || [])[0] || '';
export function fxHtml(text) {
  return String(text || '').split(' · ').map(seg => { const k = fxKindOf(seg.trim()); return k ? `<span class="fxk fxk-${k}">${esc(seg)}</span>` : esc(seg); }).join(' · ');
}
export const fxKindsOf = id => { const t = USABLE[id]; return t ? new Set(String(t).split(' · ').map(x => fxKindOf(x.trim())).filter(Boolean)) : new Set(); };
export const GEAR = new Set(['tool', 'weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'accessory', 'equipment']);
const DISMANTLABLE = new Set(['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool']);
export const SLOTS = { weapon: ['무기', 'sword', '공격할 때'], armor: ['방어구', 'shield', '맞을 때'], hat: ['관모', 'hat', '맞을 때'], shoes: ['신', 'shoe', '이동할 때'],
  norigae: ['노리개', 'knot', ''], amulet: ['호신부', 'talisman', ''], mask: ['탈', 'mask', ''], tool: ['채집', 'hammer', '채집할 때'], explore: ['탐사', 'compass', ''], fishing: ['낚시', 'fish', ''] };
export const slotOf = it => it?.category === 'tool' ? (it.equipment_traits?.life_slot || 'tool') : it?.category;
const STY = { melee: '근접 공격', ranged: '원거리 공격', magic: '술법 공격' };

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

const ACCESSORY = new Set(['hat', 'shoes', 'norigae', 'amulet', 'mask']);
const STAT_KEYS = ['strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity'];
const STAT_PAIR = { vitality: 'strength', strength: 'vitality', agility: 'perception', perception: 'agility', willpower: 'spirit_affinity', spirit_affinity: 'willpower' };
const topStat = c => Math.max(...STAT_KEYS.map(k => Number(c?.[k] || 0)));
const RANK_NAME = { gathering_rank: '채집 숙련', crafting_rank: '제작 숙련', investigation_rank: '조사 숙련' };
const statReqs = (o, c) => {
  const tr = o.equipment_traits || {};
  if (o.category === 'tool' && Number(tr.req_rank) > 1) {
    if ((tr.req_line || 'crafting_rank') === 'crafting_rank' && Array.isArray(tr.craft_fields) && tr.craft_fields.length) {
      const lines = tr.craft_fields.map(f => FIELD_LINE[f] || f), need = Number(tr.req_rank);
      const have = Math.max(...lines.map(l => Number(c?.skill_progress?.[l]?.rank || 1))), n = lines.map(l => nameOf(l)).join('·');
      return [[`${n} 기술 ${need}단계 이상`, have >= need, `${n} 기술 ${need}단계 필요 (지금 ${have}단계)`]];
    }
    const n = RANK_NAME[tr.req_line] || '채집 숙련', have = Number(c?.[tr.req_line] || 1), need = Number(tr.req_rank);
    return [[`${n} ${need}단계 이상`, have >= need, `${n} ${need}단계 필요 (지금 ${have}단계)`]];
  }
  const req = Object.entries(o.required_stats || {});
  if (!req.length) return [];
  if (ACCESSORY.has(o.category)) { const v = Math.max(...req.map(([, n]) => Number(n))); return [[`가장 높은 능력치 ${v} 이상`, topStat(c) >= v, `가장 높은 능력치 ${v} 필요 (지금 ${topStat(c)})`]]; }
  if (o.category === 'armor') return req.map(([k, v]) => { const p = STAT_PAIR[k] || k, have = Math.max(Number(c?.[k] || 0), Number(c?.[p] || 0));
    return [`${nameOf(k)} 또는 ${nameOf(p)} ${v} 이상`, have >= Number(v), `${nameOf(k)} 또는 ${nameOf(p)} ${v} 필요 (지금 ${have})`]; });
  return req.map(([k, v]) => [`${nameOf(k)} ${v} 이상`, Number(c?.[k] || 0) >= Number(v), `${nameOf(k)} ${v} 필요 (지금 ${Number(c?.[k] || 0)})`]);
};
const FIELD_LINE = { sealing: 'wardcraft' };
const STAT_JOBS = { strength: ['artificer'], vitality: ['artificer'], agility: ['scout', 'analyst'], perception: ['scout', 'analyst'], spirit_affinity: ['exorcist'], willpower: ['medic', 'sealmaster'] };
export function suitedJobs(o) {
  if (!o || !['weapon', 'armor'].includes(o.category)) return [];
  const req = Object.entries(o.required_stats || {}).sort((a, b) => Number(b[1]) - Number(a[1]));
  const wt = o.equipment_traits?.weapon_type;
  let jobs = req.length ? STAT_JOBS[req[0][0]] || [] : [];
  if (o.category === 'armor' && req.length) jobs = [...new Set([...jobs, ...(STAT_JOBS[STAT_PAIR[req[0][0]]] || [])])];
  if (o.category === 'weapon') jobs = weaponJobs(o);
  return o.required_job ? [o.required_job] : jobs;
}
const WEAPON_JOBS = { melee: ['artificer', 'analyst'], ranged: ['scout'], magic: ['exorcist', 'sealmaster', 'medic'] };
export const weaponJobs = o => Array.isArray(o?.equipment_traits?.jobs) ? o.equipment_traits.jobs : WEAPON_JOBS[o?.equipment_traits?.weapon_type || 'melee'] || [];
const weaponOk = (o, c) => o?.category !== 'weapon' || !c?.job_key || weaponJobs(o).includes(c.job_key);
const weaponJobText = o => `${weaponJobs(o).map(nameOf).join('·')} 무기`;
export const gearBlock = (o, c) => {
  if (!o) return '';
  if (o.minimum_level > (c?.level || 1)) return `Lv.${o.minimum_level} 필요`;
  if (o.required_job && o.required_job !== c?.job_key) return `${nameOf(o.required_job)} 전용`;
  if (!weaponOk(o, c)) return weaponJobText(o);
  if (o.required_faction && o.required_faction !== c?.faction_key) return `${nameOf(o.required_faction)} 전용`;
  const miss = statReqs(o, c).find(r => !r[1]);
  return miss ? miss[2] : '';
};
export function gearReqs(o, c) {
  if (!o) return [];
  const out = [];
  if (o.minimum_level > 1) out.push([`Lv.${o.minimum_level} 이상`, (c?.level || 1) >= o.minimum_level]);
  if (o.required_job) out.push([`${nameOf(o.required_job)} 전용`, o.required_job === c?.job_key]);
  else if (o.category === 'weapon') out.push([weaponJobText(o), weaponOk(o, c)]);
  if (o.required_faction) out.push([`${nameOf(o.required_faction)} 전용`, o.required_faction === c?.faction_key]);
  for (const [t, ok] of statReqs(o, c)) out.push([t, ok]);
  return out;
}
export const gearReqHtml = (o, c) => gearReqs(o, c).map(([t, ok]) => `<span class="req ${ok ? 'ok' : 'bad'}">${esc(t)}</span>`).join('');

export function traitText(it) {
  const t = it?.equipment_traits; if (!t) return '';
  return [STY[t.weapon_type] || t.trait, ...effectText(t)].filter(Boolean).join(' · ');
}

export async function openItemInfo(id, { mode = 'view' } = {}) {
  const opts = { title: nameOf(id), wide: true, body: '<div class="item-info"><div class="loading"><span class="spinner"></span>불러오는 중…</div></div>' };
  const m = document.getElementById('modal') ? openLayer(opts) : openModal(opts);
  const box = $('.item-info', m);
  try {
    const [inv, prices] = await Promise.all([load('world_inventory_snapshot', undefined, { maxAge: 10000 }), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => []), loadLocks()]);
    draw(box, id, inv, new Map((prices || []).map(p => [p.item_id, p])), mode);
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}

async function fillSources(box, id) {
  const dd = $('[data-src]', box); if (!dd) return;
  try {
    const s = await itemSources(id) || {};
    const part = (label, all, n) => { const list = (all || []).slice(0, 2), tot = Math.max(n || 0, (all || []).length);
      return list.length ? `<span class="src"><b>${label}</b> ${list.map(r => regionBtn(r)).join(' · ')}${tot > list.length ? ` ${sourcesMore(id, tot - list.length)}` : ''}</span>` : ''; };
    const html = SRC_KINDS.map(([k, label]) => part(label, s[k], s[`${k}_n`])).filter(Boolean).join('');
    const buy = [s.smithy && '대장간', s.shop && '안전지대 상점(회차마다 바뀜)', s.vault && '세력 비고(공훈)'].filter(Boolean);
    const extra = [s.craft && '<span class="src"><b>제작</b> 가방 › 제작</span>', buy.length && `<span class="src"><b>사기</b> ${esc(buy.join(' · '))}</span>`].filter(Boolean).join('');
    dd.innerHTML = (html + extra) || '<span class="muted">원정·이야기·특별한 보상으로 얻습니다</span>';
  } catch { dd.textContent = '-'; }
}
function draw(box, id, inv, prices, mode) {
  const c = store.character, it = (inv.catalog || []).find(x => x.id === id), pr = prices.get(id);
  const have = Number(inv.inventory?.[id] || 0), equipped = Object.values(inv.equipment || {}).includes(id), locked = isLocked(id);
  const pairId = pairOf(id), pairHave = Number(inv.inventory?.[pairId] || 0);
  const both = k => Number(inv.inventory?.[k] || 0) + (isHq(k) ? 0 : Number(inv.inventory?.[hqOf(k)] || 0));
  const dcMax = Math.max(0, have - (equipped ? 1 : 0));
  const cc = store.character || {}, here = [...(zonesNow()?.values() || [])].find(r => r.region_name === cc.location || r.region_id === cc.location);
  const stashOk = !!here?.is_safe_zone && !weakSafe(here.region_id) && !(cc.travel_arrives_at && new Date(cc.travel_arrives_at) > Date.now());
  const uses = (inv.recipes || []).filter(r => r.ingredients && r.ingredients[id]);
  const makes = (inv.recipes || []).filter(r => r.output === id);
  const block = it && GEAR.has(it.category) ? gearBlock(it, c) : '';
  const tradeable = pr ? pr.tradeable !== false : null;
  const recipeRow = r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => both(k) < n).length;
    return `<li><div><b>${esc(r.name)}</b><small>${esc(Object.entries(r.ingredients || {}).map(([k, n]) => `${nameOf(k)} ${n}`).join(' · '))} → ${esc(r.output_name || nameOf(r.output))} ×${r.qty || 1}</small></div>
      <button class="btn small ${lacks ? '' : 'primary'}" data-recipe="${esc(r.id)}">${lacks ? '제작법 보기' : '만들 수 있음'}</button></li>`;
  };
  box.innerHTML = `
    <div class="chips">${it ? chip(nameOf(it.category)) : ''}${it?.tier ? chip(`${it.tier}단계`) : ''}${chip(nameOf(it?.rarity || 'common'), 'rar')}
      ${equipped ? chip('장착 중', 'accent') : ''}${locked ? chip('잠금', 'warn') : ''}${tradeable === false ? chip('거래 불가', 'bad') : tradeable ? chip('거래 가능', 'ok') : ''}</div>
    ${isFurniture(id) ? `<p class="fpic" data-fpic="${esc(id)}"></p>` : ''}
    ${it?.description ? `<p class="desc">${esc(it.description)}</p>` : ''}
    ${baseOf(id) === 'gwiryeong_cho' ? `<div class="notice item-note">${icon('mask', 18)}<div><b>귀령초는 서버에 몇 포기 없습니다</b><span>${esc(GWIRYEONG.supply)}</span><span>${esc(GWIRYEONG.trade)}</span><span>${esc(GWIRYEONG.wither)}</span><span>${esc(GWIRYEONG.hold)}</span></div></div>` : ''}
    <p class="item-lore" data-lore hidden></p>
    <dl class="kv info">
      <div><dt>가진 수량</dt><dd>${fmt.num(have)}개${have > 0 ? ` · ${fmt.num(Math.ceil(have / stackOf(id)))}칸` : ''} <small class="muted">(한 칸 ${fmt.num(stackOf(id))}개)</small>${pairHave > 0 ? `<br><small class="muted">${isHq(id) ? '보통' : '우수품'} ${fmt.num(pairHave)}개 따로 · 제작·사용에는 함께 ${fmt.num(have + pairHave)}개</small>` : ''}</dd></div>
      ${isFurniture(id) ? `<div data-home-have hidden><dt>별채</dt><dd></dd></div>` : ''}
      ${pr?.reference_price ? `<div><dt>기준 시세</dt><dd>${fmt.jeon(pr.reference_price)}</dd></div>` : ''}
      ${pr?.npc_sell_price ? `<div><dt>상점 매입</dt><dd>약 ${fmt.jeon(pr.npc_sell_price)}</dd></div>` : ''}
      ${traitText(it) ? `<div><dt>효과</dt><dd>${esc(traitText(it))}</dd></div>` : ''}
      ${suitedJobs(it).length ? `<div><dt>어울리는 직업</dt><dd>${esc(suitedJobs(it).map(nameOf).join(' · '))}</dd></div>` : ''}
      ${USABLE[id] ? `<div><dt>사용하면</dt><dd>${esc(USABLE[id])}</dd></div>` : ''}
      ${bossUse(id) ? `<div><dt>보스 싸움</dt><dd>${esc(bossUse(id).tip)}</dd></div>` : ''}
      ${/\d+분|든든함|속이 따뜻함|기운 충천|바다의 복/.test(USABLE[id] || '') ? `<div><dt>다시 쓰면</dt><dd>같은 기운이 남아 있으면 그 시간에 더해집니다(두 번 몫까지)</dd></div>` : ''}
      <div class="wide src-row"><dt>얻는 곳</dt><dd data-src>확인 중…</dd></div>
      ${it && GEAR.has(it.category) ? `<div><dt>${slotOf(it) === 'craft' ? '쓰는 조건(가방에 두면)' : '장착 조건'}</dt><dd class="reqs">${gearReqHtml(it, c) || '<span class="req ok">누구나</span>'}</dd></div>` : (it?.minimum_level > 1 ? `<div><dt>필요 레벨</dt><dd>Lv.${it.minimum_level}</dd></div>` : '')}
    </dl>
    ${uses.length ? `<details class="fold-recipes" ${uses.length <= 3 ? 'open' : ''}><summary class="sub-h">이 물품이 들어가는 제작법 ${uses.length}</summary><ul class="spot-list">${uses.map(recipeRow).join('')}</ul></details>
      <button class="btn small ghost" data-mat="${esc(id)}">${icon('hammer', 14)}<span>이 재료로 만들 수 있는 것 모두 보기</span></button>` : ''}
    ${makes.length ? `<h3 class="sub-h">이 물품을 만드는 제작법</h3><ul class="spot-list">${makes.map(recipeRow).join('')}</ul>` : ''}
    ${!uses.length && !makes.length ? '<p class="muted small">이 물품과 관련된 제작법이 없습니다.</p>' : ''}
    ${mode === 'bag' && have > 0 ? `<h3 class="sub-h">다루기</h3>
      <div class="btn-row">
        ${it?.category === 'pet' ? `<button class="btn small primary" data-do="adopt">${icon('heart', 14)}<span>열기</span></button>` : ''}
        ${id === 'pet_token' ? `<button class="btn small ${have >= 5 ? 'primary' : ''}" data-do="token" ${have >= 5 ? '' : 'disabled'} title="동무 정표 다섯 개를 빛나는 알 하나로 바꿉니다">${icon('heart', 14)}<span>빛나는 알로 바꾸기</span></button>` : ''}
        ${it?.category === 'furniture' ? `<button class="btn small" data-do="house">${icon('home', 14)}<span>별채에서 놓기</span></button>` : ''}
        ${it && GEAR.has(it.category) && slotOf(it) !== 'craft' && !equipped ? (block ? `<span class="bad small">${esc(block)}</span>` : `<button class="btn small primary" data-do="equip">${icon('shield', 14)}<span>장착</span></button>`) : ''}
        <button class="btn small" data-do="lock">${icon(locked ? 'check' : 'shield', 14)}<span>${locked ? '잠금 풀기' : '잠그기'}</span></button>
        ${it && DISMANTLABLE.has(it.category) ? `<button class="btn small" data-do="dismantle" data-here="분해" ${locked || (equipped && have <= 1) ? 'disabled' : ''}>${icon('hammer', 14)}<span>분해</span></button>` : ''}
      </div>
      ${actBox({ key: 'q', max: Math.max(useMaxOf(id, have), locked ? 0 : dcMax), cls: 'act-end', btns: [
        `<button class="btn small act-dc" data-do="discard" ${locked || dcMax < 1 ? 'disabled' : ''}>버리기</button>`,
        stashOk && dcMax > 0 ? '<button class="btn small" data-do="stash" data-here="창고 이용">창고에</button>' : '',
        USABLE[id] ? '<button class="btn small primary" data-do="use" data-here="물품 사용" data-here-down>사용</button>' : ''] })}
      <p class="muted small">${locked ? '잠근 물품은 팔거나 버리거나 거래할 수 없습니다. 사용과 제작 재료로는 쓸 수 있습니다.' : equipped ? '장착 중인 마지막 한 개는 팔거나 버릴 수 없습니다.' : '버린 물품은 되찾을 수 없습니다.'}</p>` : ''}`;

  bindQty(box);
  fillSources(box, id);
  if (isFurniture(id)) import('../housing/thumbs.js').then(({ furnPic }) => { const x = $('[data-fpic]', box); if (x) { x.innerHTML = furnPic(id); if (!x.innerHTML) x.remove(); } }).catch(() => {});
  if (isFurniture(id)) myHomeCounts(rpc).then(h => {
    const row = $('[data-home-have]', box); if (!row) return;
    const placed = h.placed[id] || 0, stored = h.stored[id] || 0; if (!placed && !stored) return;
    $('dd', row).textContent = [placed ? `놓은 것 ${fmt.num(placed)}개` : '', stored ? `곳간 ${fmt.num(stored)}개` : ''].filter(Boolean).join(' · ');
    row.hidden = false;
  }).catch(() => {});
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
    const run = async fn => { let ok = false; await guard(d, async () => { const r = await fn(); ok = true; return r; }); return ok; };
    const closeInfo = () => box.closest('.modal-backdrop')?.querySelector('[data-close]')?.click();
    if (k === 'use') await useItem(id, d, Math.max(1, Math.min(useMaxOf(id, have), qtyOf(box, 'q') || 1)));
    if (k === 'adopt') await guard(d, () => act('world_pet_adopt', { p_item: id }));
    if (k === 'token') await guard(d, () => act('world_pet_token_trade'));
    if (k === 'house') { closeLayers(); closeModal(); window.yahangGo?.('house'); return; }
    if (k === 'equip') await guard(d, () => act('world_equip_item', { p_item_id: id }));
    if (k === 'lock') await guard(d, async () => { const out = await act('world_item_lock', { p_item_id: id, p_locked: !locked }); await loadLocks(true); return out; });
    if (k === 'dismantle') {
      const di = (await load('world_dismantle_info', undefined, { maxAge: 600000 }).catch(() => ({})))?.[id];
      const low = di && di.rank < di.need;
      if (!(await ask(low ? `${di.line_name} 기술이 ${di.need}단계가 되지 않아(지금 ${di.rank}단계) 재료를 돌려받지 못합니다. 분해하면 ${di.line_name} 경험 12만 얻고 이 장비는 사라집니다.`
        : `${nameOf(id)} 하나를 분해해 제작 재료 일부를 돌려받을까요?${di ? ` ${di.line_name} 경험 +12.` : ''} 되돌릴 수 없습니다.`,
        { title: low ? '경험만 얻는 분해' : '분해', ok: low ? '경험만 받고 분해' : '분해하기', cancel: '그만두기' }))) return;
      if (await run(() => act('world_dismantle_item', { p_item_id: id }))) { closeInfo(); return; }
      return;
    }
    if (k === 'stash') {
      const q = qtyOf(box, 'q') || 1;
      if (!(q >= 1 && q <= dcMax)) return toast(`1~${dcMax}개 사이로 정하세요.`, 'error');
      const ok = await run(() => act('world_storage_put', { p_item: id, p_qty: q }));
      if (ok && q >= have) { closeInfo(); return; }
    }
    if (k === 'discard') {
      const q = qtyOf(box, 'q') || 1;
      if (!(q >= 1 && q <= dcMax)) return toast(`1~${dcMax}개 사이로 정하세요.`, 'error');
      if (!(await ask(`${nameOf(id)} ×${q}을(를) 버릴까요? 되찾을 수 없습니다.`, { title: '버리기', ok: '버리기', danger: true }))) return;
      const ok = await run(() => act('world_item_discard', { p_item_id: id, p_qty: q }));
      if (ok) { closeInfo(); return; }
      return;
    }
    try {
      const [inv2, prices2] = await Promise.all([load('world_inventory_snapshot'), load('world_economy_price_snapshot', undefined, { maxAge: 120000 }).catch(() => [])]);
      if (box.isConnected) draw(box, id, inv2, new Map((prices2 || []).map(p => [p.item_id, p])), mode);
    } catch {}
  };
}

export async function useItem(id, btn, n = 1) {
  if (id === 'reset_stats') {
    if (!(await ask('능력치를 모두 직업 기본값으로 되돌리고 쓴 포인트를 돌려받을까요? 세심단 하나를 씁니다.', { title: '세심단', ok: '쓰기' }))) return;
    return guard(btn, () => act('world_reset_stats'));
  }
  if (id === 'reset_identity') return openResetIdentity();
  return guard(btn, () => useItemAct(id, n));
}
export const USE_ONE = new Set(['reset_stats', 'reset_identity']);
export const useMaxOf = (id, have) => USABLE[id] ? (USE_ONE.has(baseOf(id)) ? 1 : Math.min(50, have)) : 0;
export const useQtyHtml = (id, have, key, small = true) => USABLE[id] && !USE_ONE.has(baseOf(id)) && have > 1 ? qtyHtml({ key, min: 1, max: Math.min(50, have), value: 1, all: true, small, label: '쓸 수량' }) : '';
function openResetIdentity() {
  const c = store.character || {};
  const m = openModal({ title: '환골탈태 서첩', body: `
    <p class="muted small">직업과 소속을 다시 고릅니다. 능력치는 새 직업의 기본값으로 돌아가 쓴 포인트를 모두 돌려받습니다. 레벨·기술 단계·대세력·물품·전·칭호는 그대로이고, 새 직업·소속으로 찰 수 없는 장비는 벗깁니다. 전투 기술은 새 직업의 계열만 쓰고, 지난 직업의 전투 계열은 단계만 남고 효과가 없습니다.</p>
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
