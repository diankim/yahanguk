import { ask, db, store, on, act, rpc, nameOf, esc, icon, guard, $, $$, fmt, openModal, closeModal, openLayer, closeLayers, effectText, toast, stackOf, JOBS, JOB_ORDER, FACTIONS, RAID_ON, useItemAct, JOB_LINE } from '../core.js';
import { loreBundle, rebirthScene } from '../lore.js';
import { load, loadPrices, chip, zonesNow, catItem, fxNames } from './common.js';
import { itemSources, regionBtn, sourcesMore, SRC_KINDS, shopNow, shopNowHtml, nearOf, nearH } from '../sources.js';
import { baseOf, isHq, pairOf, hqOf } from '../hq.js';
import { isFurniture } from '../housing/count.js';
import { ownRow, fillOwned } from '../owned.js';
import { GWIRYEONG, weakSafe, gwWhen, BIJANG, weaponRankNeed } from '../rules.js';
import { GAMEDATA as GD } from '../gamedata.js';
import { qtyHtml, bindQty, qtyOf, actBox } from './itempick.js';
import { PETS, petImage } from '../housing/petsprite.js';
import { FIRST_PETS, petGroupOf, petGroupLine } from '../petpick.js';
import { helpLine, helpQ } from '../tips.js';

const USE_SPECIAL = { reset_identity: '직업 다시 고르기 · 능력치는 새 직업에 맞게 저절로 놓임', reset_stats: '능력치를 처음으로 · 포인트 돌려받기',
  revival_charm: '전투불능에서 일어나기', gwiryeong_cho: '요화 풀기 · 침식 −20',
  trail_map: '지금 있는 지역의 비경을 3시간 동안 엶(채집량 +50% · 희귀품·단서 +10%)', sealed_bundle: '열면 장비·회복약·전 가운데 하나',
  hair_pattern: '머리 모양과 색을 마음대로 그려 도안첩에 담음 · 내 모습에서 바로 씀(한 장 씀)',
  furn_pattern: '가구를 직접 그려 도안첩에 담음 · 바닥 칸 하나에 한 장(1×1 한 장 · 2×1 두 장 · 2×2 네 장) · 지어서 별채 곳간에',
  ...Object.fromEntries(BIJANG.maps.map(m => [m.id, `펼치기 · Lv${m.lo}~${m.hi} 바깥 지역 하나에 묻힌 비장고가 지도에 드러남`])) };
export const useLabel = id => BIJANG.maps.some(m => m.id === id) ? '펼치기' : id === 'hair_pattern' || id === 'furn_pattern' ? '그리기' : '사용';
export function canStash() {
  const cc = store.character || {}, here = [...(zonesNow()?.values() || [])].find(r => r.region_name === cc.location || r.region_id === cc.location);
  const fsr = store.snaps['world_field_snapshotnull']?.region, weakSt = fsr?.region_id === here?.region_id && fsr?.weak ? !!fsr.weak.storage : weakSafe(here?.region_id);
  return !!here?.is_safe_zone && !weakSt && !(cc.travel_arrives_at && new Date(cc.travel_arrives_at) > Date.now());
}
const hasPic = it => !!(it?.equipment_traits?.look || it?.equipment_traits?.hair_pattern);
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
  if (f.tokens > 0) out.push(`노정패 +${f.tokens}`);
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
export async function staminaRetry(fn, what = '합류') {
  try { return await fn(); } catch (e) {
    if (e?.hint !== 'stamina') throw e;
    const inv = store.character?.inventory || {};
    const opts = Object.entries(inv).filter(([id, n]) => Number(n) > 0 && (catItem(baseOf(id))?.fx?.stam || 0) > 0)
      .map(([id]) => ({ id, s: catItem(baseOf(id)).fx.stam })).sort((a, b) => a.s - b.s);
    if (!opts.length) throw e;
    const o = opts[0];
    if (!await ask(`탐색력이 모자랍니다.\n「${nameOf(o.id)}」 하나를 써서 탐색력을 ${o.s} 채우고 바로 ${what}할까요?`, { title: '탐색력 채우기', ok: `쓰고 ${what}` })) return null;
    await useItemAct(o.id);
    return fn();
  }
}
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
    tip: [raid && '사슬 벗은 그림자·10장 결전에서 「물품」으로 사용(결전은 체력 회복품 한 싸움 다섯 개)', gw && '귀허의 주인과 싸울 때 사용(한 싸움 두 개)'].filter(Boolean).join(' / ') } : null;
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
    const { data, error } = await db.from('world_item_locks').select('item_id, qty');
    if (error) throw error;
    locks = new Map((data || []).map(r => [r.item_id, Math.max(1, Number(r.qty) || 1)]));
  } catch { locks = locks || new Map(); }
  return locks;
}
export const isLocked = id => !!locks?.has(id);
export const lockKeep = id => locks?.get(id) || 0;
const storedOf = id => (store.snaps?.['world_storage_snapshotnull']?.items || []).reduce((a, i) => a + (i.item_id === id ? Number(i.qty) || 0 : 0), 0);
export const lockFree = (id, bag, st = storedOf(id)) => locks?.has(id) ? Math.max(0, (Number(bag) || 0) + (Number(st) || 0) - locks.get(id)) : Infinity;
export const lockTag = id => locks?.has(id) ? `잠금 ${locks.get(id)}` : '';
function openLockPick(id, have, done) {
  const tot = have + storedOf(id), keep = lockKeep(id);
  const m = openLayer({ title: `${nameOf(id)} 잠그기`, body: `<div class="lock-pick">
    <p class="desc">몇 개를 지킬까요?${helpQ('지킨 수만큼은 팔기·버리기·분해·넘기기를 할 수 없고, 넘는 몫만 내줄 수 있습니다. 강화한 것 → 장착 중인 것 → 덜 닳은 것 순으로 지켜집니다. 사용과 제작 재료로는 쓸 수 있고, 새로 얻은 것은 잠기지 않습니다.', '잠금 안내')}</p>
    <p class="muted small">가진 수 ${fmt.num(tot)}개 (가방 ${fmt.num(have)}${tot > have ? ` · 창고 ${fmt.num(tot - have)}` : ''})</p>
    ${qtyHtml({ key: 'keep', min: 1, max: tot, value: keep ? Math.min(keep, tot) : tot, all: true })}
    <div class="btn-row"><button class="btn small primary" data-lock-ok>${icon('shield', 14)}<span>${keep ? '지킬 수 바꾸기' : '잠그기'}</span></button></div></div>` });
  const el = $('.lock-pick', m);
  bindQty(el);
  $('[data-lock-ok]', el).onclick = async e => {
    const q = qtyOf(el, 'keep');
    if (!(q >= 1 && q <= tot)) return toast(`1~${tot}개 사이로 정하세요.`, 'error');
    let ok = false;
    await guard(e.currentTarget, async () => { const out = await act('world_item_lock', { p_item_id: id, p_locked: true, p_qty: q }); await loadLocks(true); ok = true; return out; });
    if (ok) { m.close(); done?.(); }
  };
}

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
  if (o.category === 'weapon') {
    const r = weaponRank(o, c);
    return r && r.need > 1 ? [[`${r.name} ${r.need}단계 이상`, r.ok, `${r.name} ${r.need}단계 필요 (지금 ${r.have}단계)`]] : [];
  }
  const req = Object.entries(o.required_stats || {});
  if (!req.length) return [];
  if (ACCESSORY.has(o.category)) { const v = Math.max(...req.map(([, n]) => Number(n))); return [[`가장 높은 능력치 ${v} 이상`, topStat(c) >= v, `가장 높은 능력치 ${v} 필요 (지금 ${topStat(c)})`]]; }
  if (o.category === 'armor') return req.map(([k, v]) => { const p = STAT_PAIR[k] || k, have = Math.max(Number(c?.[k] || 0), Number(c?.[p] || 0));
    return [`${nameOf(k)} 또는 ${nameOf(p)} ${v} 이상`, have >= Number(v), `${nameOf(k)} 또는 ${nameOf(p)} ${v} 필요 (지금 ${have})`]; });
  return req.map(([k, v]) => [`${nameOf(k)} ${v} 이상`, Number(c?.[k] || 0) >= Number(v), `${nameOf(k)} ${v} 필요 (지금 ${Number(c?.[k] || 0)})`]);
};
export const weaponRank = (o, c) => {
  if (o?.category !== 'weapon') return null;
  const js = weaponJobs(o), job = !c?.job_key || js.includes(c.job_key) || !js.length ? c?.job_key : js[0];
  const line = JOB_LINE[job] || 'melee', need = weaponRankNeed(o.minimum_level), have = Number(c?.skill_progress?.[line]?.rank || 1);
  return { line, name: `${nameOf(line)} 기술`, need, have, ok: have >= need };
};
const FIELD_LINE = { sealing: 'wardcraft' };
const STAT_JOBS = { strength: ['artificer', 'bloodknight', 'spearman'], vitality: ['artificer', 'bloodknight'], agility: ['scout', 'tamer', 'analyst', 'spearman'], perception: ['scout', 'tamer', 'analyst'], spirit_affinity: ['exorcist', 'formation'], willpower: ['medic', 'sealmaster', 'formation'] };
export function suitedJobs(o) {
  if (!o || !['weapon', 'armor'].includes(o.category)) return [];
  const req = Object.entries(o.required_stats || {}).sort((a, b) => Number(b[1]) - Number(a[1]));
  const wt = o.equipment_traits?.weapon_type;
  let jobs = req.length ? STAT_JOBS[req[0][0]] || [] : [];
  if (o.category === 'armor' && req.length) jobs = [...new Set([...jobs, ...(STAT_JOBS[STAT_PAIR[req[0][0]]] || [])])];
  if (o.category === 'weapon') jobs = weaponJobs(o);
  return o.required_job ? [o.required_job] : jobs;
}
const WEAPON_JOBS = { melee: ['artificer', 'analyst', 'bloodknight', 'spearman'], ranged: ['scout', 'tamer'], magic: ['exorcist', 'sealmaster', 'medic', 'formation'] };
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
    const [inv, prices] = await Promise.all([load('world_inventory_snapshot', undefined, { maxAge: 10000 }), loadPrices().catch(() => []), loadLocks(),
      load('world_storage_snapshot', undefined, { maxAge: 300000 }).catch(() => null)]);
    draw(box, id, inv, new Map((prices || []).map(p => [p.item_id, p])), mode);
  } catch (e) { box.innerHTML = `<p class="bad">${esc(e.message)}</p>`; }
}

export function fillGwWhen(root) {
  const els = $$('[data-gw-when]', root), cans = $$('[data-gw-can]', root); if (!els.length && !cans.length) return;
  load('world_gwiryeong_mine', undefined, { maxAge: 60000 }).then(r => {
    for (const el of cans) { el.textContent = GWIRYEONG.can(r?.can); el.hidden = !r?.can; }
    const p = r?.plants || [];
    for (const el of els) {
      if (!p.length) { if (el.dataset.gwKeep == null) el.hidden = true; continue; }
      const w = p.map(x => gwWhen(x.until, r.warn_h)), many = p.length > 1;
      const bag = el.dataset.gwKeep != null;
      el.textContent = w.map((x, i) => `${many ? `${i + 1}. ` : bag ? '' : '내 귀령초 · '}${bag ? x.short : x.text}`).join(' / ');
      el.classList.toggle('soon', w.some(x => x.soon)); el.hidden = false;
    }
  }).catch(() => {});
}
async function fillSources(box, id) {
  const dd = $('[data-src]', box); if (!dd) return;
  try {
    const s = await itemSources(id) || {};
    const part = (label, all, n, near) => { const list = (all || []).slice(0, 2), tot = Math.max(n || 0, (all || []).length);
      return list.length ? `<span class="src"><b>${label}</b> ${list.map(r => regionBtn(r, false, nearH(near, r))).join(' · ')}${tot > list.length ? ` ${sourcesMore(id, tot - list.length)}` : ''}</span>` : ''; };
    const html = SRC_KINDS.map(([k, label]) => part(label, s[k], s[`${k}_n`], nearOf(s, k))).filter(Boolean).join('');
    const buy = [s.smithy && '대장간', s.shop && '안전지대 상점(회차마다 바뀜)', s.vault && '세력 비고(공훈)'].filter(Boolean);
    const extra = [s.craft && '<span class="src"><b>제작</b> 가방 › 제작</span>', buy.length && `<span class="src"><b>사기</b> ${esc(buy.join(' · '))}</span>`, s.bijang && `<span class="src"><b>비장고</b> ${s.bijang === 'final' ? '마지막 방' : '상자'}</span>`, s.luck && '<span class="src"><b>드물게</b> 탐색 · 채집 · 낚시(잡았을 때)</span>', s.token && `<span class="src"><b>바꾸기</b> 동무 정표 ${s.token}개</span>`].filter(Boolean).join('');
    const sh = s.shop ? shopNowHtml(await shopNow(id).catch(() => null), t => `<b>${t}</b> `) : '';
    dd.innerHTML = (html + extra + (sh ? `<span class="src">${sh}</span>` : '')) || '<span class="muted">원정·이야기·특별한 보상으로 얻습니다</span>';
  } catch { dd.textContent = '-'; }
}
function draw(box, id, inv, prices, mode) {
  const c = store.character, it = (inv.catalog || []).find(x => x.id === id), pr = prices.get(id);
  const have = Number(inv.inventory?.[id] || 0), equipped = Object.values(inv.equipment || {}).includes(id), locked = isLocked(id);
  const pairId = pairOf(id), pairHave = Number(inv.inventory?.[pairId] || 0);
  const both = k => Number(inv.inventory?.[k] || 0) + (isHq(k) ? 0 : Number(inv.inventory?.[hqOf(k)] || 0));
  const stMax = Math.max(0, have - (equipped ? 1 : 0)), dcMax = Math.min(stMax, lockFree(id, have)), keep = lockKeep(id);
  const stashOk = canStash();
  const bid = baseOf(id);
  const uses = (inv.recipes || []).filter(r => r.ingredients && r.ingredients[bid]);
  const makes = (inv.recipes || []).filter(r => r.output === bid);
  const block = it && GEAR.has(it.category) ? gearBlock(it, c) : '';
  const tradeable = pr ? pr.tradeable !== false : null;
  const recipeRow = r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => both(k) < n).length;
    return `<li><div><b>${esc(r.name)}</b><small>${esc(Object.entries(r.ingredients || {}).map(([k, n]) => `${nameOf(k)} ${n}`).join(' · '))} → ${esc(r.output_name || nameOf(r.output))} ×${r.qty || 1}</small></div>
      <button class="btn small ${lacks ? '' : 'primary'}" data-recipe="${esc(r.id)}">${lacks ? '제작법 보기' : '만들 수 있음'}</button></li>`;
  };
  box.innerHTML = `
    <div class="chips">${it ? chip(nameOf(it.category)) : ''}${it?.tier ? chip(`${it.tier}단계`) : ''}${chip(nameOf(it?.rarity || 'common'), 'rar')}
      ${equipped ? chip('장착 중', 'accent') : ''}${locked ? chip(lockTag(id), 'warn') : ''}${tradeable === false ? chip('거래 불가', 'bad') : tradeable ? chip('거래 가능', 'ok') : ''}</div>
    ${isFurniture(id) || hasPic(it) ? `<p class="fpic" data-fpic="${esc(id)}"></p>` : ''}
    ${it?.description ? `<p class="desc">${esc(it.description)}</p>` : ''}
    ${baseOf(id) === 'gwiryeong_cho' ? `<div class="notice item-note">${icon('mask', 18)}<div><b class="gw-when" data-gw-when hidden></b><span class="gw-can" data-gw-can hidden></span><b>귀령초는 서버에 몇 포기 없습니다</b><span>${esc(GWIRYEONG.supply)}</span><span>${esc(GWIRYEONG.trade)}</span><span>${esc(GWIRYEONG.wither)}</span><span>${esc(GWIRYEONG.hold)}</span></div></div>` : ''}
    ${BIJANG.maps.some(m => m.id === id) ? `<div class="notice item-note">${icon('chest', 18)}<div><b>비장도</b><span>${esc(BIJANG.how)}</span><span>${esc(BIJANG.hold)}</span></div></div>` : ''}
    <p class="item-lore" data-lore hidden></p>
    <dl class="kv info">
      <div><dt>가진 수량</dt><dd>${fmt.num(have)}개${have > 0 ? ` · ${fmt.num(Math.ceil(have / stackOf(id)))}칸` : ''} <small class="muted">(한 칸 ${fmt.num(stackOf(id))}개)</small>${pairHave > 0 ? `<br><small class="muted">${isHq(id) ? '보통' : '우수품'} ${fmt.num(pairHave)}개 따로 · 제작·사용에는 함께 ${fmt.num(have + pairHave)}개</small>` : ''}</dd></div>
      ${ownRow(id)}
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
      <button class="btn small ghost" data-mat="${esc(bid)}">${icon('hammer', 14)}<span>이 재료로 만들 수 있는 것 모두 보기</span></button>` : ''}
    ${makes.length ? `<h3 class="sub-h">이 물품을 만드는 제작법</h3>${isHq(id) ? '<p class="muted small">우수품은 따로 만드는 제작법이 없습니다. 아래 제작법으로 만들 때 품질이 높으면 우수품이 나옵니다.</p>' : ''}<ul class="spot-list">${makes.map(recipeRow).join('')}</ul>` : ''}
    ${!uses.length && !makes.length ? '<p class="muted small">이 물품과 관련된 제작법이 없습니다.</p>' : ''}
    ${mode === 'bag' && have > 0 ? `<h3 class="sub-h">다루기</h3>
      <div class="btn-row">
        ${it?.category === 'outfit' ? `<button class="btn small primary" data-do="wear">${icon('palette', 14)}<span>${it.equipment_traits?.box ? '풀기' : '옷장에 넣기'}</span></button>` : ''}
        ${it?.category === 'pet' ? `<button class="btn small primary" data-do="adopt">${icon('heart', 14)}<span>열기</span></button>` : ''}
        ${id === 'pet_token' ? `<button class="btn small ${have >= 5 ? 'primary' : ''}" data-do="token" data-here="동무 정표 바꾸기" ${have >= 5 ? '' : 'disabled'} title="동무 정표 다섯 개를 빛나는 알 하나로 바꿉니다">${icon('heart', 14)}<span>빛나는 알로 바꾸기</span></button>` : ''}
        ${it?.category === 'furniture' ? `<button class="btn small" data-do="house">${icon('home', 14)}<span>별채에서 놓기</span></button>` : ''}
        ${it && GEAR.has(it.category) && slotOf(it) !== 'craft' && !equipped ? (block ? `<span class="bad small">${esc(block)}</span>` : `<button class="btn small primary" data-do="equip">${icon('shield', 14)}<span>장착</span></button>`) : ''}
        ${locked ? `<button class="btn small" data-do="unlock">${icon('check', 14)}<span>잠금 풀기</span></button>` : ''}
        <button class="btn small" data-do="lock">${icon('shield', 14)}<span>${locked ? `지킬 수 바꾸기 · ${keep}` : '잠그기'}</span></button>
        ${it && DISMANTLABLE.has(it.category) ? `<button class="btn small" data-do="dismantle" data-here="분해" ${dcMax < 1 ? 'disabled' : ''}>${icon('hammer', 14)}<span>분해</span></button>` : ''}
      </div>
      ${actBox({ key: 'q', max: Math.max(useMaxOf(id, have), stashOk ? stMax : dcMax), cls: 'act-end', btns: [
        `<button class="btn small act-dc" data-do="discard" ${dcMax < 1 ? 'disabled' : ''}>버리기</button>`,
        stashOk && stMax > 0 ? '<button class="btn small" data-do="stash" data-here="창고 이용">창고에</button>' : '',
        USABLE[id] ? (useLabel(id) !== '사용' ? `<button class="btn small primary" data-do="use" data-here="물품 사용">${useLabel(id)}</button>` : '<button class="btn small primary" data-do="use" data-here="물품 사용" data-here-down>사용</button>') : ''] })}
      <p class="muted small">${locked ? `잠금 ${keep}개 · ${dcMax > 0 ? `내줄 수 있는 것 ${dcMax}개` : '내줄 수 있는 것 없음'}${helpQ('잠근 수만큼은 가방·창고를 합쳐 팔기·버리기·분해·넘기기를 할 수 없습니다. 사용과 제작 재료로는 쓸 수 있습니다.', '잠금 안내')}` : equipped ? '장착 중인 마지막 한 개는 팔거나 버릴 수 없습니다.' : '버린 물품은 되찾을 수 없습니다.'}</p>
      ${isHq(id) && (inv.catalog || []).some(x => x.id === bid) ? `<div class="dg-box"><p class="muted small">${esc(`보통 ${nameOf(bid)}(으)로 바꾸면 같은 물품끼리 한 칸에 모입니다. 되돌릴 수 없습니다.`)}</p>
      ${actBox({ key: 'dq', max: dcMax, cls: 'act-end', btns: ['', '', `<button class="btn small" data-do="downgrade" data-here="보통 물품으로 바꾸기" ${dcMax < 1 ? 'disabled' : ''}>품질 하향</button>`] })}</div>` : ''}` : ''}`;

  bindQty(box);
  fillSources(box, id);
  if (isFurniture(id)) import('../housing/thumbs.js').then(({ furnPic }) => { const x = $('[data-fpic]', box); if (x) { x.innerHTML = furnPic(id); if (!x.innerHTML) x.remove(); } }).catch(() => {});
  else if (hasPic(it)) import('./outfitdesign.js').then(({ itemPic }) => itemPic(id, it)).then(h => { const x = $('[data-fpic]', box); if (x) { x.innerHTML = h; if (!h) x.remove(); } }).catch(() => {});
  fillOwned(box).catch(() => {});
  fillGwWhen(box);
  loreBundle().then(l => { const p = $('[data-lore]', box); const t = l.items?.[baseOf(id)]; if (p && t) { p.textContent = t; p.hidden = false; } });
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
    if (k === 'wear') { if (await run(() => act('world_wardrobe_add', { p_item: id }))) closeInfo(); return; }
    if (k === 'token') await guard(d, () => act('world_pet_token_trade'));
    if (k === 'house') { closeLayers(); closeModal(); window.yahangGo?.('house'); return; }
    if (k === 'equip') await guard(d, () => act('world_equip_item', { p_item_id: id }));
    if (k === 'unlock') await guard(d, async () => { const out = await act('world_item_lock', { p_item_id: id, p_locked: false }); await loadLocks(true); return out; });
    if (k === 'lock') { openLockPick(id, have, redraw); return; }
    if (k === 'dismantle') {
      const di = (await load('world_dismantle_info', undefined, { maxAge: 600000 }).catch(() => ({})))?.[id];
      const low = di && di.rank < di.need, n = Math.max(1, Math.min(dcMax, qtyOf(box, 'q') || 1)), what = n > 1 ? `${n}개` : '하나';
      if (!(await ask(low ? `${di.line_name} 기술이 ${di.need}단계가 되지 않아(지금 ${di.rank}단계) 재료를 돌려받지 못합니다. 분해하면 ${di.line_name} 경험 ${12 * n}만 얻고 이 장비 ${what}는 사라집니다.`
        : `${nameOf(id)} ${what}를 분해해 제작 재료 일부를 돌려받을까요?${di ? ` ${di.line_name} 경험 +${12 * n}.` : ''} 되돌릴 수 없습니다.`,
        { title: low ? '경험만 얻는 분해' : n > 1 ? '한꺼번에 분해' : '분해', ok: low ? '경험만 받고 분해' : '분해하기', cancel: '그만두기' }))) return;
      if (await run(() => n > 1 ? act('world_dismantle_batch', { p_item_id: id, p_times: n }) : act('world_dismantle_item', { p_item_id: id }))) { closeInfo(); return; }
      return;
    }
    if (k === 'stash') {
      const q = qtyOf(box, 'q') || 1;
      if (!(q >= 1 && q <= stMax)) return toast(`1~${stMax}개 사이로 정하세요.`, 'error');
      const ok = await run(() => act('world_storage_put', { p_item: id, p_qty: q }));
      if (ok && q >= have) { closeInfo(); return; }
    }
    if (k === 'downgrade') {
      const q = qtyOf(box, 'dq') || 1;
      if (!(q >= 1 && q <= dcMax)) return toast(`1~${dcMax}개 사이로 정하세요.`, 'error');
      if (!(await ask(`${nameOf(id)} ×${q}을(를) 보통 ${nameOf(bid)}(으)로 바꿀까요? 되돌릴 수 없습니다.`, { title: '품질 하향', ok: '바꾸기', cancel: '그만두기' }))) return;
      const ok = await run(() => act('world_item_downgrade', { p_item_id: id, p_qty: q }));
      if (ok && q >= have) { closeInfo(); return; }
      if (!ok) return;
    }
    if (k === 'discard') {
      const q = qtyOf(box, 'q') || 1;
      if (!(q >= 1 && q <= dcMax)) return toast(`1~${dcMax}개 사이로 정하세요.`, 'error');
      if (!(await ask(`${nameOf(id)} ×${q}을(를) 버릴까요? 되찾을 수 없습니다.`, { title: '버리기', ok: '버리기', danger: true }))) return;
      const ok = await run(() => act('world_item_discard', { p_item_id: id, p_qty: q }));
      if (ok) { closeInfo(); return; }
      return;
    }
    await redraw();
  };
  async function redraw() {
    try {
      const [inv2, prices2] = await Promise.all([load('world_inventory_snapshot'), loadPrices().catch(() => [])]);
      if (box.isConnected) draw(box, id, inv2, new Map((prices2 || []).map(p => [p.item_id, p])), mode);
    } catch {}
  }
}

export async function useItem(id, btn, n = 1) {
  if (id === 'reset_stats') {
    if (!(await ask('능력치를 모두 직업 기본값으로 되돌리고 쓴 포인트를 돌려받을까요? 세심단 하나를 씁니다.', { title: '세심단', ok: '쓰기' }))) return;
    return guard(btn, () => act('world_reset_stats'));
  }
  if (id === 'reset_identity') return openResetIdentity();
  if (id === 'hair_pattern') {
    const [{ openFreeEditor }, snap] = await Promise.all([import('./outfitdesign.js'), load('world_avatar_get', undefined, { maxAge: 600000 })]);
    if (snap) openFreeEditor('hair', snap, () => {});
    return;
  }
  if (id === 'furn_pattern') { const { openFurnBook } = await import('./furndesign.js'); openFurnBook(); return; }
  const bj = BIJANG.maps.find(m => m.id === id);
  if (bj) {
    if (!(await ask(`${bj.name}을(를) 펼칩니다. Lv${bj.lo}~${bj.hi} 바깥 지역 하나가 지도에 드러나고, 그 지역에서 「비장도 따라 파기」를 할 수 있습니다. 파수꾼은 Lv${BIJANG.guardLv(bj, store.character?.level)}입니다(지도 주인 레벨에 맞춤). 펼친 지도는 거래할 수 없습니다.`, { title: '비장도 펼치기', ok: '펼치기' }))) return;
    return guard(btn, () => act('world_bijang_open', { p_item: id }));
  }
  return guard(btn, () => useItemAct(id, n));
}
export const USE_ONE = new Set(['reset_stats', 'reset_identity', 'hair_pattern', 'furn_pattern', ...BIJANG.maps.map(m => m.id)]);
export const useMaxOf = (id, have) => USABLE[id] ? (USE_ONE.has(baseOf(id)) ? 1 : Math.min(50, have)) : 0;
export const useQtyHtml = (id, have, key, small = true) => USABLE[id] && !USE_ONE.has(baseOf(id)) && have > 1 ? qtyHtml({ key, min: 1, max: Math.min(50, have), value: 1, all: true, small, label: '쓸 수량' }) : '';
function openResetIdentity() {
  const c = store.character || {};
  const m = openModal({ title: '환골탈태 서첩', body: `
    ${helpLine(`직업을 새로 고릅니다. 레벨로 받은 능력치는 새 직업의 주 능력치에 맞게 저절로 놓이고, 소속·레벨·기술 단계·대세력·물품·전·칭호는 그대로입니다. 새 직업이 들 수 없는 장비는 벗고, 무기 칸이 비면 가진 새 직업 무기 가운데 가장 높은 단계를 저절로 낍니다. 새 직업 무기가 하나도 없으면 맨손이 되니 미리 마련해 두세요. 전투 기술은 새 직업의 계열만 쓰고, 지난 직업의 전투 계열은 단계만 남고 효과가 없습니다. 쓴 뒤 ${GD.jobChange?.cd_min || 60}분은 다시 쓸 수 없습니다.`, '환골탈태 안내')}
    <p class="hint" data-jobcd hidden></p>
    <h3 class="sub-h">직업</h3>
    <div class="choice-grid ri-grid">${JOB_ORDER.map(k => [k, JOBS[k]]).map(([k, j]) => `<label class="choice"><input type="radio" name="rj" value="${k}" ${k === c.job_key ? 'checked' : ''}><span><b>${esc(j.name)}</b><small>${esc(j.trait || '')}</small></span></label>`).join('')}</div>
    <div id="ri-pet" hidden><h3 class="sub-h">데리고 다닐 꼬마 동무</h3><div class="ri-pet-body"></div></div>
    <div class="modal-actions sticky-actions"><button class="btn primary" id="ri-go" data-jobcd="btn" data-jobcd-text="이대로 다시 시작">이대로 다시 시작</button></div>` });
  let pets = null;
  const petBox = $('#ri-pet', m);
  const petCard = (id, sub, on) => { const g = petGroupOf(id); return `<label class="choice ri-petc"><input type="radio" name="rp" value="${esc(id)}" ${on ? 'checked' : ''}><img src="${petImage(id, sub.adult, { scale: 2, skin: sub.skin })}" alt=""><span><b>${esc(sub.name)}</b><small>${esc([g?.name, sub.note].filter(Boolean).join(' · '))}</small></span></label>`; };
  const drawPets = () => {
    const mine = pets?.mine || [];
    $('.ri-pet-body', petBox).innerHTML = !pets ? '<p class="muted small">동무를 불러오는 중…</p>' : mine.length
      ? `<p class="muted small">조련사는 데리고 다니는 동무와 함께 싸웁니다. 함께하는 동무 가운데 하나를 고르세요(힘은 친밀도로 정해집니다).</p><div class="choice-grid ri-grid">${[...mine].sort((a, b) => (b.id === pets.profile) - (a.id === pets.profile) || b.affinity - a.affinity).map((p, i) => petCard(p.id, { name: p.nick || PETS[p.id]?.name || p.id, adult: p.adult, skin: p.skin, note: `친밀도 ${p.affinity}` }, pets.profile ? p.id === pets.profile : i === 0)).join('')}</div>`
      : `<p class="muted small">조련사는 데리고 다니는 동무와 함께 싸웁니다. 아직 함께하는 동무가 없으니 처음 동무 하나를 고르세요.</p><div class="choice-grid ri-grid">${FIRST_PETS.map(id => petCard(id, { name: PETS[id]?.name || id, adult: false, note: petGroupLine(petGroupOf(id)) }, false)).join('')}</div>`;
  };
  const showPets = async () => {
    petBox.hidden = $('input[name=rj]:checked', m)?.value !== 'tamer';
    if (petBox.hidden || pets) return;
    drawPets();
    try { pets = await rpc('world_pet_snapshot'); drawPets(); } catch (err) { $('.ri-pet-body', petBox).innerHTML = `<p class="muted small">${esc(err.message)}</p>`; }
  };
  $$('input[name=rj]', m).forEach(r => r.addEventListener('change', showPets));
  showPets();
  $('#ri-go', m).onclick = async e => {
    const job = $('input[name=rj]:checked', m)?.value, fac = c.faction_key;
    if (!job) return toast('직업을 고르세요.', 'error');
    if (job === c.job_key) return toast('지금과 같은 직업입니다.', 'error');
    const pet = job === 'tamer' ? $('input[name=rp]:checked', m)?.value || null : null;
    if (job === 'tamer' && !pets) return toast('동무 목록을 불러오는 중입니다.', 'error');
    if (job === 'tamer' && !pet) return toast('데리고 다닐 꼬마 동무를 고르세요.', 'error');
    const petName = pet ? (pets.mine || []).find(p => p.id === pet)?.nick || PETS[pet]?.name || pet : '';
    const armed = Object.entries(c.inventory || {}).some(([id, n]) => Number(n) > 0 && catItem(id)?.category === 'weapon' && weaponJobs(catItem(id)).includes(job));
    if (!(await ask(`${JOBS[job]?.name}(으)로 직업을 바꿀까요?${petName ? ` ${petName}와(과) 함께 다닙니다.` : ''} 서첩 하나를 쓰고, ${GD.jobChange?.cd_min || 60}분 동안은 다시 바꿀 수 없습니다.${armed ? '' : `\n\n가방에 ${JOBS[job]?.name} 무기가 없습니다. 바꾸면 맨손이 되니, 무기를 먼저 마련해 두는 것이 좋습니다.`}`, { title: '환골탈태', ok: '바꾸기', alarm: !armed }))) return;
    await guard(e.currentTarget, async () => { const out = await act('world_reset_identity', { p_job: job, p_faction: fac, p_pet: pet }); closeModal();
      if (out?.no_weapon && await ask(`${JOBS[job]?.name}이(가) 들 수 있는 무기가 없어 지금은 맨손입니다. 상점·제작·거래소에서 무기를 마련해 가방 › 장비에서 끼우세요.`, { title: '무기가 없습니다', ok: '장비 보기', cancel: '닫기', alarm: true })) location.hash = '#/bag/equip';
      else if (RAID_ON) rebirthScene(job, fac); return out; });
  };
}
