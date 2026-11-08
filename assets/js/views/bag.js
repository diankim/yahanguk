import { rarTag, db, store, on, act, rpc, toast, openModal, closeModal, friendlyError, nameOf, esc, icon, guard, $, $$, fmt, empty, segmented, bindSegmented, bar, bagLimit, bagUsed, effectText, brief, stackOf } from '../core.js';
import { load, invalidate, panel, chip, loading, errorBox, safeZones, catItem } from './common.js';
import { equipRowLi, eqMini, bindRepair, enhancedTraits, DUR_NOTE } from './character.js';
import { tokenRowHtml } from '../bond.js';
import { helpQ } from '../tips.js';
import { openItemInfo, loadLocks, isLocked, gearBlock, gearReqHtml, USABLE, GEAR, SLOTS, slotOf, useItem, traitText, fxHtml, fxKindsOf, FX_KINDS, bossUse } from './item.js';
import { baseOf, hqOf } from '../hq.js';
import { hit } from '../changes.js';

const SUBS = [['items', '소지품', 'bag'], ['equip', '장비', 'shield'], ['craft', '제작', 'hammer']];
const CATS = [['all', '전체'], ['consumable', '소모품'], ['material', '재료'], ['gear', '장비'], ['etc', '기타']];
const LOC_BONUS = 12;
const LOC_ALIAS = { '야행국 본부 정청': ['본부 로비', '야행국 본부 · 정청'], '연무장·팔괘진': ['훈련실', '야행국 본부 · 연무장'], '장서각 지하서고': ['기록 보관실', '야행국 본부 · 장서각'] };
const atPlace = (loc, here) => !!loc && (loc === here || (LOC_ALIAS[loc] || []).includes(here));
let fxPick = new Set();
let el, sub = 'items', cat = 'all', craftFilter = 'can', off = [], q = '', cq = '';
const FIELDS = ['smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking'];
const craftFields = new Set();
const craftKinds = new Set();
let craftSort = 'can';
const FAV_MAX = 30;
const STAR = '<svg viewBox="0 0 24 24" width="18" height="18" aria-hidden="true"><path d="M12 2.8l2.85 5.95 6.55.8-4.8 4.55 1.2 6.5L12 17.4l-5.8 3.2 1.2-6.5-4.8-4.55 6.55-.8z" stroke-linejoin="round"/></svg>';
let favs = null;
const CRAFT_MAX = 50;
const craftN = new Map();
const craftLabel = n => n > 1 ? `제작 ×${n}` : '제작';
const loadFavs = () => favs ? Promise.resolve(favs) : rpc('world_craft_favs').then(r => (favs = new Set(r || []))).catch(() => (favs = new Set()));
const KIND_LABEL = { weapon: '무기', armor: '방어구', hat: '관모', shoes: '신', norigae: '노리개', amulet: '호신부', mask: '탈', tool: '채집 도구', explore: '탐사 도구', fishing: '낚싯대', craft: '제작 공구', consumable: '소모품', material: '재료', furniture: '가구', etc: '기타' };
const SORTS = { tier: ['기본(단계)', '낮은 단계 먼저', '높은 단계 먼저'], acquired: ['획득순', '최근 얻은 것 먼저', '오래전에 얻은 것 먼저'],
  name: ['이름순', '가나다순', '가나다 역순'], rarity: ['희귀도순', '신품 먼저', '범품 먼저'] };
const RARITY = { common: 0, uncommon: 1, rare: 2, epic: 3, legendary: 4 };
let sortKey = 'tier', sortRev = false;
try { const v = JSON.parse(localStorage.getItem('yh-bag-sort') || 'null'); if (v && SORTS[v.k]) { sortKey = v.k; sortRev = !!v.r; } } catch {}
let splitView = true; try { splitView = localStorage.getItem('yh-bag-split') !== '0'; } catch {}
const saveSort = () => { try { localStorage.setItem('yh-bag-sort', JSON.stringify({ k: sortKey, r: sortRev })); } catch {} };
let acqCache = null, acqInv = null, acqAt = 0;
async function acquiredMap(inv) {
  const now = Object.fromEntries(Object.entries(inv || {}).map(([id, n]) => [id, Number(n) || 0]));
  const grew = !acqCache || !acqInv || Date.now() - acqAt > 600000 || Object.entries(now).some(([id, n]) => n > (acqInv[id] || 0));
  acqInv = now;
  if (!grew) return acqCache;
  try { const { data, error } = await db.from('world_item_acquired').select('item_id,acquired_at'); if (error) { acqInv = null; return acqCache || new Map(); }
    acqCache = new Map((data || []).map(r => [r.item_id, Date.parse(r.acquired_at) || 0])); acqAt = Date.now(); return acqCache; }
  catch { acqInv = null; return acqCache || new Map(); }
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
let matFocus = null, recipeFocus = null;
window.addEventListener('yh-craft-focus', e => { matFocus = e.detail?.material || null; recipeFocus = e.detail?.recipe || null; if (matFocus || recipeFocus) { craftFilter = 'all'; cq = ''; }
  if (e.detail?.search) cq = e.detail.search; });

export async function render(root, s) {
  if (!store.character) return;
  el = root; sub = SUBS.some(x => x[0] === s) ? s : 'items';
  el.innerHTML = `<div class="view-head"><div><p class="eyebrow">${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}</p><h1>가방</h1></div><button class="btn small ghost" id="open-storage" title="창고에 무엇이 있는지 봅니다. 넣고 꺼내기는 안전지대에서만 됩니다.">${icon('chest', 15)}<span>창고 보기</span></button></div>
    ${segmented('bag-sub', SUBS, sub)}<div id="bag-body"></div>`;
  bindSegmented(el, 'bag-sub', k => { sub = k; window.history.replaceState(null, '', `#/bag/${k}`); draw(); });
  $('#open-storage', el).onclick = () => import('./services.js').then(m => m.openStorage());
  off.forEach(f => f()); off = [on('changed', ({ name } = {}) => { if (hit('storage', name)) invalidate('world_storage_snapshot'); draw(true); })];
  await draw();
}
export function destroy() { off.forEach(f => f()); off = []; }

async function draw(soft) {
  const body = $('#bag-body', el); if (!body) return;
  if (!soft) body.innerHTML = loading();
  try {
    const inv = await load('world_inventory_snapshot', undefined, { maxAge: soft ? 600000 : 30000 });
    const head = $('.view-head .eyebrow', el); if (head) head.innerHTML = `${icon('bag', 14)} 소지금 ${fmt.jeon(store.character.gil)}`;
    const stg = sub === 'craft' ? await load('world_storage_snapshot', undefined, { maxAge: 30000 }).catch(() => null)
      : sub === 'items' ? await load('world_storage_snapshot', undefined, { maxAge: 300000 }).catch(() => null) : null;
    await ({ items, equip, craft })[sub](body, inv, stg);
  } catch (e) { body.innerHTML = errorBox(e.message); }
}

function catalogMap(inv) { return new Map((inv.catalog || []).map(i => [i.id, i])); }
const catOf = i => !i ? 'etc' : GEAR.has(i.category) ? 'gear' : i.category === 'consumable' ? 'consumable' : /material/.test(i.category) ? 'material' : 'etc';

const toolCovers = (have, need) => { const h = baseOf(have);
  if (h === need) return true;
  const a = catItem(h), b = catItem(need);
  return !!(a?.tl && b?.tl && a.tl === b.tl && Number(a.tier) >= Number(b.tier)); };
const toolNote = (need, by) => { if (!by) return ' <span class="bad">(없음 · 같은 갈래의 더 높은 단계 도구도 됨)</span>';
  const st = by.endsWith('@st'), id = st ? by.slice(0, -3) : by, base = baseOf(id);
  return base === need && !st ? '' : ` <small class="muted">(${esc(`${nameOf(id)}${st ? ' · 창고' : ''}(으)로 됨`)})</small>`; };
const CAT_SHORT = { consumable: '소모', material: '재료', craft_material: '재료', tool: '도구', weapon: '무기', armor: '방어', hat: '관모', shoes: '신', norigae: '노리', amulet: '호신', mask: '탈', accessory: '장신', equipment: '장비', quest: '임무', trade_goods: '교역' };

function stayFit(box) {
  if (!box.style.minHeight) return;
  const need = window.scrollY + window.innerHeight - (box.getBoundingClientRect().top + window.scrollY);
  const cur = parseFloat(box.style.minHeight) || 0;
  if (need < cur) box.style.minHeight = need > 0 ? need + 'px' : '';
}
function descFx(desc, name, fx) {
  const d = esc(desc); if (!fx) return d;
  const tag = `<span class="desc-fx">(효과: ${fxHtml(fx)})</span>`, n = name ? esc(name) : '', i = n ? d.indexOf(n) : -1;
  return i < 0 ? `${d} ${tag}` : d.slice(0, i + n.length) + tag + d.slice(i + n.length);
}
function gearFx(it, kind) {
  const t = traitText(it), head = SLOTS[kind]?.[0];
  return head && t.startsWith(head + ' · ') ? t.slice(head.length + 3) : t === head ? '' : t;
}
let craftFiltOpen = (() => { try { return localStorage.getItem('yh-craft-filt') === '1'; } catch { return false; } })();
const KIND_GROUPS = [['장비', ['weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask']], ['생활 도구', ['tool', 'explore', 'fishing', 'craft']], ['그 밖', ['consumable', 'material', 'furniture', 'etc']]];
const CRAFT_SORTS = [['can', '가능한 것 먼저'], ['lv', '제작 레벨 낮은순'], ['lvd', '제작 레벨 높은순']];
function craftFilterBox(inv, kindCount) {
  const tog = (attr, k, on, label, n, cls = '') => `<label class="tg ${cls}"><input type="checkbox" ${attr}="${k}" ${on ? 'checked' : ''}><span>${esc(label)}${n != null ? ` <small>${n}</small>` : ''}</span></label>`;
  const fieldN = f => (inv.recipes || []).filter(r => (r.field || '') === f).length;
  const sumF = craftFields.size ? [...craftFields].map(f => nameOf(f)).join('·') : '모든 분야';
  const sumK = craftKinds.size ? [...craftKinds].map(k => KIND_LABEL[k]).join('·') : '모든 물품';
  const sumS = (CRAFT_SORTS.find(x => x[0] === craftSort) || CRAFT_SORTS[0])[1];
  const on = craftFields.size + craftKinds.size;
  return `<details class="craft-filt" ${craftFiltOpen ? 'open' : ''}>
    <summary>${icon('filter', 14)}<b>거르기·정렬</b>${on ? `<i class="cf-on">${on}</i>` : ''}<span class="cf-sum">${esc(sumF)} · ${esc(sumK)} · ${esc(sumS)}</span></summary>
    <div class="cf-body">
      <div class="cf-row"><span class="cf-h">분야</span><div class="cf-tags">${FIELDS.map(f => tog('data-field', f, craftFields.has(f), nameOf(f), fieldN(f), inv.crafting_profession === f ? 'mine' : '')).join('')}</div></div>
      ${KIND_GROUPS.map(([g, ks]) => { const list = ks.filter(k => kindCount[k]); return list.length ? `<div class="cf-row"><span class="cf-h">${esc(g)}</span><div class="cf-tags">${list.map(k => tog('data-kind', k, craftKinds.has(k), KIND_LABEL[k], kindCount[k])).join('')}</div></div>` : ''; }).join('')}
      <div class="cf-row cf-foot"><label class="craft-sort"><span class="muted small">정렬</span><select id="craft-sort">${CRAFT_SORTS.map(([k, t]) => `<option value="${k}" ${craftSort === k ? 'selected' : ''}>${t}</option>`).join('')}</select></label>
        ${on ? '<button class="btn small ghost" id="craft-filt-clear">거르기 모두 풀기</button>' : ''}</div>
      <p class="muted small">내 제작 분야(${esc(nameOf(inv.crafting_profession || 'smithing'))}, 초록)의 제작법은 품질 +12입니다. 품질 85 이상이면 「우수품」이 나옵니다(30단계 추가 기술이 있으면 80). 분야는 캐릭터 › 성장 › 생활 전문화에서 정합니다.</p>
    </div></details>`;
}
async function stay(sel, fn, box = document.querySelector('.view-host') || document.body) {
  const before = document.querySelector(sel)?.getBoundingClientRect().top;
  box.style.minHeight = box.offsetHeight + 'px';
  if (!box.dataset.stayHold) {
    box.dataset.stayHold = '1';
    const onScroll = () => stayFit(box);
    window.addEventListener('scroll', onScroll, { passive: true });
    window.addEventListener('hashchange', () => { box.style.minHeight = ''; delete box.dataset.stayHold; window.removeEventListener('scroll', onScroll); }, { once: true });
  }
  await fn();
  const el = document.querySelector(sel);
  if (before != null && el) {
    const d = el.getBoundingClientRect().top - before;
    if (Math.abs(d) > 1) window.scrollBy(0, d);
  }
  stayFit(box);
}
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

async function items(body, inv, stg) {
  const stored = Object.fromEntries((stg?.items || []).map(i => [i.item_id, Number(i.qty) || 0]));
  const [, acq] = await Promise.all([loadLocks(), sortKey === 'acquired' ? acquiredMap(inv.inventory) : Promise.resolve(new Map())]);
  const cmap = catalogMap(inv), equipped = new Set(Object.values(inv.equipment || {}));
  const rows = Object.entries(inv.inventory || {}).filter(([, n]) => Number(n) > 0)
    .map(([id, n]) => ({ id, n: Number(n), it: cmap.get(id) }))
    .filter(r => cat === 'all' || catOf(r.it) === cat)
    .filter(r => !fxPick.size || [...fxKindsOf(r.id)].some(k => fxPick.has(k)))
    .filter(r => !q.trim() || nameOf(r.id).toLowerCase().includes(q.trim().toLowerCase()))
    .sort(sorter(acq));
  const c = store.character, used = bagUsed(c), cap = bagLimit(c);
  renderKeep(body, `<div class="bag-cap ${used >= cap ? 'full' : ''}"><div class="cap-top"><span>${icon('bag', 16)} 가방 ${fmt.num(used)} / ${fmt.num(cap)}칸</span><button class="btn small" data-storage title="창고에 무엇이 있는지 봅니다. 맡기기·꺼내기는 안전지대에서만 됩니다.">${icon('chest', 14)}<span>창고 열기</span></button></div>${bar(used, cap, used >= cap ? 'enemy' : 'xp')}
      <small>같은 물품은 한 칸에 묶음으로 쌓입니다(장비 1개 · 화살 등 100개 · 진품 이상 소모품 20개 · 그 밖 40개, 물품 정보에서 확인). 가득 차면 전리품을 두고 오고, 구매·제작이 막힙니다. 사건 해결·지역 완전 답사·수향연맹 소속으로 넓어집니다.</small></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="bag-q" type="search" placeholder="가방 안 물품 찾기 (이름)" value="${esc(q)}"></label>
    ${segmented('bag-cat', CATS, cat)}
    ${cat === 'all' || cat === 'consumable' ? `<div class="chips fx-pick" role="group" aria-label="회복 종류로 거르기"><span class="muted small">효과</span>${FX_KINDS.map(([k, n]) => `<button type="button" class="chip fxk-${k} ${fxPick.has(k) ? 'on' : ''}" data-fxk="${k}" aria-pressed="${fxPick.has(k)}">${n}</button>`).join('')}</div>` : ''}
    <div class="bag-sort"><label><span>정렬</span><select id="bag-sort">${Object.entries(SORTS).map(([k, [n]]) => `<option value="${k}" ${k === sortKey ? 'selected' : ''}>${n}</option>`).join('')}</select></label>
      <button class="btn small" id="bag-dir" aria-label="정렬 방향 바꾸기">${icon('back', 14)}<span>${SORTS[sortKey][sortRev ? 2 : 1]}</span></button>
      <label class="check" title="같은 물품을 묶음 크기만큼 한 칸씩 나눠 보입니다"><input type="checkbox" id="bag-split" ${splitView ? 'checked' : ''}><span>칸대로 나눠 보기</span></label></div>
    ${rows.length ? `<ul class="inv-list">${rows.flatMap(r => {
      if (!splitView) return [{ ...r, part: null }];
      const st = stackOf(r.id), out = []; let left = r.n;
      if (equipped.has(r.id) && left > 0) { out.push({ ...r, part: { q: 1, eq: true, first: true } }); left -= 1; }
      while (left > 0) { const q = Math.min(st, left); out.push({ ...r, part: { q, st, first: !out.length } }); left -= q; }
      return out;
    }).map(({ id, n, it, part }) => {
      const st = stackOf(id), cells = Math.ceil(Math.max(0, n - (equipped.has(id) ? 1 : 0)) / st);
      const cellTag = part ? (part.eq ? '' : st > 1 ? `한 칸 ${part.q}/${st}` : '') : `${cells}칸${st > 1 ? ` · 묶음 ${st}` : ''}`;
      const tags = [it?.tier ? `${it.tier}단계` : '', cellTag, (part ? part.eq : equipped.has(id)) ? '장착 중' : '', isLocked(id) ? '잠금' : '', (!part || part.first) && stored[id] ? `창고 ${fmt.num(stored[id])}` : '', USABLE[id] ? '사용 가능' : '', GEAR.has(it?.category) && !equipped.has(id) && gearBlock(it, c) ? gearBlock(it, c) : ''].filter(Boolean);
      const showQty = part ? part.q : n, showUse = !!USABLE[id];
      const boss = bossUse(id);
      return `<li class="inv-item r-${esc(it?.rarity || 'common')}${tags.includes('장착 중') ? ' is-eq' : ''}"><button class="inv-row" data-info="${esc(id)}">
        <span class="inv-cat c-${esc(catOf(it))}">${esc(CAT_SHORT[it?.category] || '기타')}</span>
        <span class="inv-name"><span class="inv-title"><b>${esc(nameOf(id))}</b><span class="inv-qty">${fmt.num(showQty)}</span></span>${it?.description ? `<small class="brief">${esc(brief(it.description))}</small>` : ''}${USABLE[id] ? `<small class="use-fx">${icon('heart', 11)} <span>${fxHtml(USABLE[id])}</span></small>` : ''}${tags.length || boss ? `<small>${boss ? `<i class="boss" title="${esc(boss.tip)}">${icon('sword', 10)}${esc(boss.label)}</i>` : ''}${tags.map(t => `<i class="${t === '장착 중' ? 'eq' : t === '잠금' ? 'lk' : /^창고 /.test(t) ? 'st' : /필요|전용/.test(t) ? 'bad' : ''}">${esc(t)}</i>`).join('')}</small>` : ''}</span>
</button>
        ${showUse ? `<button class="btn small inv-quick" data-here="물품 사용" data-here-down data-use="${esc(id)}" aria-label="${esc(nameOf(id))} 사용" title="${esc(USABLE[id])}">사용</button>` : ''}
        ${it?.category === 'pet' ? `<button class="btn small inv-quick" data-adopt="${esc(id)}" aria-label="${esc(nameOf(id))} 열기" title="바구니·알을 열어 꼬마 동무를 맞습니다">열기</button>` : ''}
        ${id === 'pet_token' && (!part || part.first) && n >= 5 ? `<button class="btn small inv-quick" data-token-trade title="동무 정표 다섯 개를 빛나는 알 하나로 바꿉니다">알로 바꾸기</button>` : ''}</li>`; }).join('')}</ul>`
      : empty(q.trim() ? `「${q.trim()}」에 맞는 물품이 없습니다.` : cat === 'all' ? '가방이 비어 있습니다. 탐사와 채집으로 물품을 모으세요.' : '이 분류의 물품이 없습니다.', 'bag')}
    <p class="muted small">물품을 누르면 정보·제작법·잠금·버리기가 나옵니다. 판매와 거래는 안전지대의 현장 화면(상점·거래소)에서 할 수 있습니다.</p>`, 'label.search');
  $('[data-storage]', body).onclick = () => import('./services.js').then(m => m.openStorage());
  bindSegmented(body, 'bag-cat', k => { cat = k; items(body, inv, stg); });
  body.querySelectorAll('[data-fxk]').forEach(b => b.onclick = () => { const k = b.dataset.fxk; fxPick.has(k) ? fxPick.delete(k) : fxPick.add(k); items(body, inv, stg); });
  $('#bag-sort', body).onchange = e => { sortKey = e.target.value; sortRev = false; saveSort(); items(body, inv, stg); };
  $('#bag-dir', body).onclick = () => { sortRev = !sortRev; saveSort(); items(body, inv, stg); };
  $('#bag-split', body).onchange = e => { splitView = e.target.checked; try { localStorage.setItem('yh-bag-split', splitView ? '1' : '0'); } catch {} items(body, inv, stg); };
  const qi = $('#bag-q', body);
  const redo = () => { q = qi.value; items(body, inv, stg); };
  qi.oninput = e => { if (!e.isComposing) redo(); };
  if (!qi.dataset.bound) { qi.dataset.bound = '1'; qi.addEventListener('compositionend', () => qi.oninput({})); }
  $$('[data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  bindActions(body);
}

const EQUIP_TIP = '무기 종류가 공격 방식을 정합니다: 칼·창은 근접, 활·쇠뇌는 원거리, 방울·부채·거울은 술법. 요괴마다 잘 통하는 방식이 다릅니다. 방어구는 받는 피해를 줄이고, 생활 칸은 채집(채집도·곡괭이·낫·등)·탐사(나침반)·낚시(낚싯대) 셋입니다. 제작 공구는 가방에 있으면 됩니다. 같은 단계라도 장비마다 갈래가 달라(위력·치명타·회피·방어·이목 등) 무엇을 끼느냐에 따라 캐릭터가 다르게 자랍니다. 이목이 높으면 함께 싸울 때 요괴가 먼저 노립니다 — 앞을 막는 이는 높이고, 뒤에서 치는 이는 낮추세요.';
async function equip(body, inv) {
  const eq = inv.equipment || {}, have = inv.inventory || {};
  const c = store.character;
  const [prof, zones] = await Promise.all([load('world_combat_profile', undefined, { maxAge: 60000 }).catch(() => null), safeZones().catch(() => null), import('../bond.js').then(m => m.loadBond())]);
  const here = zones ? [...zones.values()].find(r => r.region_name === c.location) : null;
  const optionsHtml = slot => {
    const cur = eq[slot], options = (inv.catalog || []).filter(i => slotOf(i) === slot && Number(have[i.id]) > 0 && i.id !== cur);
    return options.length ? `<ul class="spot-list">${options.map(o => {
      const blocked = gearBlock(o, c);
      const reqs = gearReqHtml(o, c);
      return `<li><div><b>${esc(o.name)}</b> ${rarTag(o.rarity)}<small>${o.tier}단계 · ${esc(o.description || '')}</small>${traits(o)}${reqs ? `<small class="reqs">장착 조건 ${reqs}</small>` : ''}</div>
        <button class="btn small" data-equip="${esc(o.id)}" ${blocked ? 'disabled' : ''}>장착</button></li>`; }).join('')}</ul>` : `<p class="muted small">바꿔 낄 수 있는 물품이 없습니다.</p>`;
  };
  const token = tokenRowHtml();
  body.innerHTML = `<div class="eq-split">
      <div class="eq-left">${panel('장착 중인 장비', `${eqMini(inv, prof, true)}${token ? `<ul class="equip-list">${token}</ul>` : ''}<p class="muted small">칸을 누르면 그 부위의 장비를 고치거나 바꿔 낄 수 있습니다.</p>`, { ico: 'shield', extra: helpQ(`${EQUIP_TIP} ${DUR_NOTE}`, '장비 안내') })}</div>
      <div class="eq-right" id="eq-detail"></div>
    </div>`;
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
    const ok = r => { if (r !== undefined) closeModal(); };
    $$('[data-equip]', m).forEach(x => x.onclick = () => guard(x, () => act('world_equip_item', { p_item_id: x.dataset.equip })).then(ok));
    $$('[data-unequip]', m).forEach(x => x.onclick = () => guard(x, () => act('world_unequip_item', { p_slot: x.dataset.unequip })).then(ok));
    $$('[data-repair]', m).forEach(x => x.onclick = () => guard(x, () => act('world_equipment_repair', { p_item_id: x.dataset.repair, p_method: x.dataset.how })).then(ok));
  });
}
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
  const stHave = stg?.in_safe && store.character?.location !== '반요촌' ? Object.fromEntries((stg.items || []).map(i => [i.item_id, Number(i.qty) || 0])) : {};
  const have = new Proxy({}, { get: (_, k) => (Number(bagHave[k]) || 0) + (stHave[k] || 0) + (Number(bagHave[hqOf(k)]) || 0) + (stHave[hqOf(k)] || 0) });
  const c = store.character;
  const cookOut = new Set((inv.catalog || []).filter(i => i.crafting_specialization === 'cooking').map(i => i.id));
  const cmap = catalogMap(inv);
  const kindOf = r => { const it = cmap.get(r.output); if (!it) return 'etc'; if (SLOTS[slotOf(it)]) return slotOf(it); if (slotOf(it) === 'craft') return 'craft'; if (it.category === 'furniture') return 'furniture'; const k = catOf(it); return k === 'consumable' || k === 'material' ? k : 'etc'; };
  const lvOf = x => Number(x.r.minimum_level) || 1, tierOf = x => Number(cmap.get(x.r.output)?.tier) || 0;
  const byLv = (a, b) => lvOf(a) - lvOf(b) || tierOf(a) - tierOf(b) || (a.r.difficulty || 0) - (b.r.difficulty || 0) || String(a.r.name).localeCompare(String(b.r.name), 'ko');
  const SORTS = { can: (a, b) => b.can - a.can || b.atLoc - a.atLoc || byLv(a, b), lv: byLv, lvd: (a, b) => byLv(b, a) };
  const furnLast = (a, b) => craftKinds.has('furniture') ? 0 : (a.kind === 'furniture') - (b.kind === 'furniture');
  const favFirst = (f => (a, b) => favs.has(b.r.id) - favs.has(a.r.id) || furnLast(a, b) || f(a, b))(SORTS[craftSort] || SORTS.can);
  const rows = (inv.recipes || []).filter(r => (!matFocus || r.ingredients?.[matFocus]) && (!recipeFocus || r.id === recipeFocus)).map(r => {
    const lacks = Object.entries(r.ingredients || {}).filter(([k, n]) => Number(have[k] || 0) < n);
    const toolBy = !r.tool ? null : [...Object.keys(bagHave).filter(k => Number(bagHave[k]) > 0), ...eq].find(k => toolCovers(k, r.tool))
      || Object.keys(stHave).filter(k => stHave[k] > 0).map(k => `${k}@st`).find(k => toolCovers(k.slice(0, -3), r.tool)) || null;
    const toolOk = !r.tool || !!toolBy;
    const jobOk = !r.required_job || r.required_job === c.job_key;
    const lvOk = !r.minimum_level || c.level >= r.minimum_level;
    const skRank = r.required_skill ? Number(c.skill_progress?.[r.required_skill]?.rank || 1) : 0;
    const skOk = !r.required_skill || skRank >= (r.required_skill_rank || 1);
    const reqs = [
      r.minimum_level > 1 && [`Lv.${r.minimum_level} 이상${lvOk ? '' : ` (지금 Lv.${c.level})`}`, lvOk],
      r.required_job && [`${nameOf(r.required_job)} 제작`, jobOk],
      r.required_skill && [`${nameOf(r.required_skill)} 기술 ${r.required_skill_rank}단계${skOk ? '' : ` (지금 ${skRank}단계)`}`, skOk],
    ].filter(Boolean);
    const can = !lacks.length && toolOk && jobOk && lvOk && skOk;
    const maxN = Math.min(CRAFT_MAX, ...Object.entries(r.ingredients || {}).map(([k, n]) => Math.floor(Number(have[k] || 0) / Math.max(1, n))));
    return { r, lacks, toolOk, toolBy, jobOk, lvOk, reqs, can, maxN: can ? Math.max(1, maxN) : 0, atLoc: atPlace(r.location, c.location), kind: kindOf(r), tier: cmap.get(r.output)?.tier };
  }).filter(x => { const t = cq.trim().toLowerCase(); if (!t) return true;
    return [x.r.name, x.r.output_name || nameOf(x.r.output)].join(' ').toLowerCase().includes(t); })
    .filter(x => !craftFields.size || craftFields.has(x.r.field || (cookOut.has(x.r.output) ? 'cooking' : '')))
    .filter(x => !craftKinds.size || craftKinds.has(x.kind))
    .filter(x => cq.trim() || craftFilter === 'all' || (craftFilter === 'fav' ? favs.has(x.r.id) : craftFilter === 'can' ? x.can : x.atLoc))
    .sort(favFirst);
  const kindCount = {}; (inv.recipes || []).forEach(r => { const k = kindOf(r); kindCount[k] = (kindCount[k] || 0) + 1; });
  renderKeep(body, `
    ${stg?.in_safe ? `<p class="muted small">${icon('chest', 13)} 안전지대에서는 창고 재료도 함께 씁니다(가방 먼저). 재료 수량에 창고 몫을 더해 보입니다.</p>` : ''}
    ${bagUsed(store.character) >= bagLimit(store.character) ? `<p class="bad small">가방이 가득 찼습니다(${bagUsed(store.character)}/${bagLimit(store.character)}칸). 완성품이 새 칸을 차지하면 제작할 수 없습니다.</p>` : ''}
    <div class="notice">${icon('hammer', 18)}<div><b>제작은 어디서나 할 수 있습니다</b><span>제작법에 적힌 장소에서 제작하면 품질 +${LOC_BONUS}. 제작 분야 ${esc(nameOf(inv.crafting_profession || 'smithing'))} · ${fmt.num(store.character?.skill_progress?.[({ sealing: 'wardcraft' })[inv.crafting_profession] || inv.crafting_profession || 'smithing']?.rank || 1)}단계</span></div></div>
    <label class="search"><span>${icon('search', 16)}</span><input id="craft-q" type="search" placeholder="만들 물품 찾기 (제작법·완성품 이름)" value="${esc(cq)}"></label>
    ${segmented('craft-filter', [['fav', `즐겨찾기 ${favs.size}`], ['can', '지금 가능'], ['here', '이곳 덤'], ['all', '전체']], craftFilter)}
    ${craftFilterBox(inv, kindCount)}
    ${cq.trim() ? `<p class="muted small">「${esc(cq.trim())}」 검색 결과 ${rows.length}개 · 검색 중에는 모든 제작법에서 찾습니다.</p>` : ''}
    ${matFocus || recipeFocus ? `<div class="focus-bar">${icon('search', 14)}<span>${matFocus ? `${esc(`「${nameOf(matFocus)}」이(가)`)} 들어가는 제작법` : `「${esc(nameOf(recipeFocus))}」 제작법`}</span><button class="btn small ghost" id="craft-unfocus">모두 보기</button></div>` : ''}
    ${rows.length ? `<div class="recipe-grid">${rows.map(({ r, lacks, toolOk, toolBy, reqs, can, maxN, atLoc, kind, tier }) => `
      <article class="recipe ${can ? 'can' : ''}">
        <header><button class="fav-star ${favs.has(r.id) ? 'on' : ''}" data-fav="${esc(r.id)}" aria-pressed="${favs.has(r.id)}" aria-label="${favs.has(r.id) ? '즐겨찾기에서 빼기' : '즐겨찾기에 넣기'}" title="${favs.has(r.id) ? '즐겨찾기에서 빼기' : `즐겨찾기에 넣기 (${favs.size}/${FAV_MAX})`}">${STAR}</button><button class="linkish recipe-name" data-info="${esc(r.output)}" title="만드는 물품 정보 보기"><b>${esc(r.name)}</b></button>${SLOTS[kind] ? `<span class="chip slot">${icon(SLOTS[kind][1], 12)}${esc(SLOTS[kind][0])}${tier ? ` ${tier}단계` : ''}</span>` : ''}${r.field ? chip(nameOf(r.field), r.field === inv.crafting_profession ? 'ok' : '') : ''}${atLoc ? chip(`품질 +${LOC_BONUS}`, 'accent') : ''}</header>
        ${(() => { const fx = USABLE[r.output] || ((SLOTS[kind] || kind === 'craft') ? gearFx(cmap.get(r.output), kind) : ''); return `<p class="muted small">${descFx(r.description || '', r.output_name || nameOf(r.output), fx)}</p>`; })()}
        <p class="out">${icon('chevron', 14)} <button class="linkish" data-info="${esc(r.output)}">${esc(r.output_name || nameOf(r.output))}</button> ×${r.qty || 1}</p>
        <ul class="ingr">${Object.entries(r.ingredients || {}).map(([k, n]) => { const h = Number(have[k] || 0), sh = stHave[k] || 0; return `<li class="${h >= n ? 'ok' : 'bad'}"><button class="linkish" data-info="${esc(k)}">${esc(nameOf(k))}</button><b>${fmt.num(h)}/${n}</b>${sh ? `<small class="muted" title="가방 ${fmt.num(Number(bagHave[k]) || 0)} · 창고 ${fmt.num(sh)}">창고 ${fmt.num(sh)}</small>` : ''}</li>`; }).join('')}</ul>
        ${reqs.length ? `<p class="reqs"><span class="muted small">제작 조건</span>${reqs.map(([t, ok]) => `<span class="req ${ok ? 'ok' : 'bad'}">${esc(t)}</span>`).join('')}</p>` : ''}
        <p class="muted small">${r.tool ? `도구: <button class="linkish" data-info="${esc(r.tool)}">${esc(r.tool_name || nameOf(r.tool))}</button>${toolNote(r.tool, toolBy)} · ` : ''}지정 장소: ${esc(r.location || '없음')}</p>
        <div class="craft-act">
          ${can ? (() => { const n = Math.min(maxN, Math.max(1, craftN.get(r.id) || 1)); return `<div class="craft-qty" data-cq="${esc(r.id)}" data-max="${maxN}">
            <button type="button" class="btn small ghost" data-cq-do="reset">초기화</button>
            <button type="button" class="btn small cq-step" data-cq-do="dec" aria-label="하나 덜">−</button>
            <input type="number" class="cq-n" inputmode="numeric" min="1" max="${maxN}" value="${n}" aria-label="만들 횟수 (최대 ${maxN})">
            <button type="button" class="btn small cq-step" data-cq-do="inc" aria-label="하나 더">+</button>
            <button type="button" class="btn small ghost" data-cq-do="all" title="재료로 만들 수 있는 만큼 (${maxN}번${maxN >= CRAFT_MAX ? `, 한 번에 ${CRAFT_MAX}번까지` : ''})">전부</button>
          </div>`; })() : ''}
          <button class="btn small ${can ? 'primary' : ''} craft-go" data-here="제작" data-craft="${esc(r.id)}" ${can ? '' : 'disabled'}>${icon('hammer', 14)}<span>${can ? craftLabel(Math.min(maxN, Math.max(1, craftN.get(r.id) || 1))) : lacks.length ? '재료 부족' : '조건 미충족'}</span></button>
        </div>
      </article>`).join('')}</div>`
      : empty(cq.trim() ? `「${cq.trim()}」에 맞는 제작법이 없습니다.` : craftFilter === 'fav' ? `즐겨찾는 제작법이 없습니다. 제작법 이름 앞의 별을 누르면 여기에 모입니다(${FAV_MAX}개까지).` : craftFilter === 'can' ? '지금 재료가 모두 갖춰진 제작법이 없습니다. 전체 목록에서 필요한 재료를 확인하세요.' : '해당하는 제작법이 없습니다.', 'hammer')}`, 'label.search');
  const redraw = sel => stay(sel, () => craft(body, inv, stg));
  bindSegmented(body, 'craft-filter', k => { craftFilter = k; redraw('[data-seg="craft-filter"]'); });
  $$('[data-field]', body).forEach(b => b.onchange = () => { b.checked ? craftFields.add(b.dataset.field) : craftFields.delete(b.dataset.field); redraw(`[data-field="${b.dataset.field}"]`); });
  $$('[data-kind]', body).forEach(b => b.onchange = () => { b.checked ? craftKinds.add(b.dataset.kind) : craftKinds.delete(b.dataset.kind); redraw(`[data-kind="${b.dataset.kind}"]`); });
  $('#craft-filt-clear', body)?.addEventListener('click', () => { craftFields.clear(); craftKinds.clear(); redraw('.craft-filt'); });
  $('.craft-filt', body)?.addEventListener('toggle', e => { craftFiltOpen = e.target.open; try { localStorage.setItem('yh-craft-filt', craftFiltOpen ? '1' : '0'); } catch {} });
  $('#craft-sort', body).onchange = e => { craftSort = e.target.value; redraw('#craft-sort'); };
  const ci = $('#craft-q', body);
  const redo = () => { cq = ci.value; craft(body, inv, stg); };
  ci.oninput = e => { if (!e.isComposing) redo(); };
  if (!ci.dataset.bound) { ci.dataset.bound = '1'; ci.addEventListener('compositionend', () => ci.oninput({})); }
  $('#craft-unfocus', body)?.addEventListener('click', () => { matFocus = recipeFocus = null; craft(body, inv, stg); });
  $$('.recipe [data-info]', body).forEach(b => b.onclick = () => openItemInfo(b.dataset.info, { mode: 'bag' }));
  $$('.craft-qty', body).forEach(box => {
    const id = box.dataset.cq, max = Number(box.dataset.max) || 1, inp = $('.cq-n', box);
    const go = box.closest('.recipe')?.querySelector('[data-craft]');
    const set = v => { const n = Math.min(max, Math.max(1, Math.floor(Number(v)) || 1)); craftN.set(id, n); inp.value = n; if (go) go.querySelector('span').textContent = craftLabel(n); };
    box.onclick = e => { const d = e.target.closest('[data-cq-do]')?.dataset.cqDo; if (!d) return;
      set(d === 'reset' ? 1 : d === 'all' ? max : (Number(inp.value) || 1) + (d === 'inc' ? 1 : -1)); };
    inp.onchange = () => set(inp.value);
    inp.onkeydown = e => { if (e.key === 'Enter') { e.preventDefault(); set(inp.value); inp.blur(); } };
  });
  $$('[data-craft]', body).forEach(b => b.onclick = () => {
    const id = b.dataset.craft, max = Number(b.closest('.recipe')?.querySelector('.craft-qty')?.dataset.max) || 1;
    const n = Math.min(max, Math.max(1, craftN.get(id) || 1));
    craftN.delete(id);
    return guard(b, () => n > 1 ? act('world_craft_batch', { p_recipe_id: id, p_times: n }) : act('world_craft_item', { p_recipe_id: id }));
  });
  $$('[data-fav]', body).forEach(b => b.onclick = () => guard(b, async () => {
    try { const r = await rpc('world_craft_fav_toggle', { p_recipe: b.dataset.fav }); favs = new Set(r?.favs || []); craft(body, inv, stg); }
    catch (e) { toast(friendlyError(e), 'error'); }
  }));
}

function bindActions(body) {
  $$('[data-use]', body).forEach(b => b.onclick = () => useItem(b.dataset.use, b));
  $$('[data-adopt]', body).forEach(b => b.onclick = () => guard(b, () => act('world_pet_adopt', { p_item: b.dataset.adopt })));
  $$('[data-token-trade]', body).forEach(b => b.onclick = () => guard(b, () => act('world_pet_token_trade')));
  $$('[data-equip]', body).forEach(b => b.onclick = () => guard(b, () => act('world_equip_item', { p_item_id: b.dataset.equip })));
}
