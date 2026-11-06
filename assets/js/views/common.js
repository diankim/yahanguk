import { db, rpc, store, on, emit, registerNames, namesDump, nameOf, esc, icon, fmt, dbVersion, MARKET_ONLY, friendlyError } from '../core.js';
import { armAlarm } from '../sound.js';
import { GAMEDATA } from '../gamedata.js';
import { baseOf } from '../hq.js';
import { hit } from '../changes.js';

const inflight = new Map();
const cacheAt = new Map();
export async function load(name, args, { maxAge = 0 } = {}) {
  const key = name + JSON.stringify(args ?? null);
  if (maxAge && cacheAt.has(key) && key in store.snaps && Date.now() - (cacheAt.get(key) || 0) < maxAge) return store.snaps[key];
  if (inflight.has(key)) return inflight.get(key);
  const p = (name === 'world_inventory_snapshot' ? inventorySnap() : rpc(name, args)).then(d => { store.snaps[key] = d; cacheAt.set(key, Date.now()); register(name, d); if (name === 'world_rest_status') { armAlarm('rest_short', 'end', d?.short_ready_at); armAlarm('rest_full', 'end', d?.full_ready_at); } return d; })
    .finally(() => inflight.delete(key));
  inflight.set(key, p);
  return p;
}
let invFreshAt = 0;
on('snaps', snaps => {
  for (const [name, d] of Object.entries(snaps || {})) {
    if (d == null) continue;
    if (name === 'world_inventory_state') {
      if (!invStatic) continue;
      const key = 'world_inventory_snapshotnull';
      store.snaps[key] = { ...d, catalog: invStatic.catalog, recipes: invStatic.recipes }; cacheAt.set(key, Date.now()); invFreshAt = Date.now();
      continue;
    }
    const key = name + 'null'; store.snaps[key] = d; cacheAt.set(key, Date.now()); register(name, d);
  }
});
let invStatic = null, invLite = true;
export const knownRecipes = () => invStatic?.recipes || [];
const INV_KEY = 'yh-inv-static-v1';
let catMap = null, fxNameMap = {};
function useCatalog(cat, names) {
  if (!cat?.length) return;
  catMap = new Map(cat.map(i => [i.id, i])); fxNameMap = names || {};
  registerNames(cat.filter(i => i.id && i.name).map(i => [i.id, i.name]));
  MARKET_ONLY.clear(); for (const i of cat) if (i.mk) MARKET_ONLY.add(i.id);
  emit('catalog');
}
function catalogMap() {
  if (!catMap) {
    if (invStatic?.catalog) useCatalog(invStatic.catalog, invStatic.fxNames);
    else try { const c = JSON.parse(localStorage.getItem(INV_KEY) || 'null'); if (c?.fxNames) useCatalog(c.catalog, c.fxNames); } catch {}
  }
  return catMap;
}
export const catItem = id => catalogMap()?.get(id) || catMap?.get(baseOf(id)) || null;
export const fxNames = () => (catalogMap(), fxNameMap);
export const catalogList = () => { const m = catalogMap(); return m ? [...m.values()] : null; };
export const itemDesc = id => catItem(id)?.description || '';
catalogMap();
export async function ensureCatalog() {
  if (invStatic) return;
  const v = await dbVersion();
  try { const c = JSON.parse(localStorage.getItem(INV_KEY) || 'null'); if (v && c?.v === v && c.catalog?.length && c.fxNames) { invStatic = { catalog: c.catalog, recipes: c.recipes || [], fxNames: c.fxNames }; useCatalog(c.catalog, c.fxNames); return; } } catch {}
  try { await load('world_inventory_snapshot'); } catch {}
}
async function inventorySnap() {
  if (!invStatic) {
    const v = await dbVersion();
    try { const c = JSON.parse(localStorage.getItem(INV_KEY) || 'null'); if (v && c?.v === v && c.catalog?.length && c.fxNames) { invStatic = { catalog: c.catalog, recipes: c.recipes || [], fxNames: c.fxNames }; useCatalog(c.catalog, c.fxNames); } } catch {}
  }
  if (invStatic && invLite) {
    try { const d = await rpc('world_inventory_state'); return { ...d, catalog: invStatic.catalog, recipes: invStatic.recipes }; }
    catch (e) { const m = String(e?.message || '') + ' ' + String(e?.code || ''); if (/로그인|권한/.test(m)) throw e; if (/PGRST202|does not exist|Could not find/.test(m)) invLite = false; }
  }
  const d = await rpc('world_inventory_snapshot');
  if (d?.catalog?.length) {
    invStatic = { catalog: d.catalog, recipes: d.recipes || [], fxNames: d.fx_names || {} };
    useCatalog(invStatic.catalog, invStatic.fxNames);
    const v = await dbVersion();
    if (v) try { localStorage.setItem(INV_KEY, JSON.stringify({ v, ...invStatic })); } catch {}
  }
  return d;
}
export function invalidate(prefix) { for (const k of [...cacheAt.keys()]) if (!prefix || k.startsWith(prefix)) cacheAt.delete(k); }
const invSigOf = c => c ? JSON.stringify([c.inventory, c.level, c.location, c.crafting_rank, c.gathering_rank, c.crafting_profession, c.gathering_profession]) : '';
let invSig = '';
on('changed', ({ name = '' }) => {
  const sig = invSigOf(store.character), moved = sig !== invSig; invSig = sig;
  if (!hit('invQuiet', name) && (moved || hit('invAlways', name)) && Date.now() - invFreshAt > 1500) invalidate('world_inventory_snapshot');
  if (hit('fishSpot', name) || (store.snaps['world_fish_spotnull'] != null && hit('fishSpotNone', name))) invalidate('world_fish_spot');
  if (hit('rest', name)) invalidate('world_rest_status');
  if (hit('idle', name)) invalidate('world_idle_activity_snapshot');
});
on('changed', ({ name }) => { if (hit('combat', name)) invalidate('world_combat_profile'); if (hit('skill', name)) invalidate('world_skill_snapshot'); if (hit('codex', name)) { invalidate('world_monster_codex_snapshot'); invalidate('world_gather_codex_snapshot'); } if (hit('roster', name)) { invalidate('world_region_roster'); invalidate('world_party_overview'); } if (hit('map', name)) invalidate('world_map_snapshot'); if (hit('journal', name)) invalidate('world_quest_journal'); });
window.addEventListener('yahang:arrived', () => invalidate());

const tcdKey = () => `yh-travel-cd:${store.character?.owner_id || ''}`;
export function travelCdLeft(now = Date.now()) { try { return Math.max(0, Number(localStorage.getItem(tcdKey()) || 0) - now); } catch { return 0; } }
export function setTravelCd(secs) { try { const s = Number(secs) || 0; if (s > 0) localStorage.setItem(tcdKey(), String(Date.now() + s * 1000)); else localStorage.removeItem(tcdKey()); } catch {} }
export const travelCdFromError = msg => { const m = /이동을 취소한 뒤 3분[^(]*\((\d+)초 남음\)/.exec(String(msg || '')); if (m) setTravelCd(m[1]); return !!m; };
on('changed', ({ name, data }) => { if (name === 'world_travel_cancel') setTravelCd(data?.cooldown_seconds ?? 180); });

function register(name, d) {
  if (!d) return;
  if (name === 'world_inventory_snapshot') {
    registerNames((d.catalog || []).map(i => [i.id, i.name]));
    registerNames((d.recipes || []).map(r => [r.id, r.name]));
  } else if (name === 'world_map_snapshot') {
    registerNames((d.regions || []).map(r => [r.region_id, r.region_name]));
    registerNames((d.regions || []).filter(r => r.territory_id).map(r => [r.territory_id, r.territory_name]));
  } else if (name === 'world_mount_snapshot') registerNames((d.mounts || []).map(m => [m.mount_id, m.mount_name]));
  else if (name === 'world_shop_snapshot') registerNames((d.stock || []).map(s => [s.item_id, s.item_name]));
  else if (name === 'world_economy_price_snapshot' || name === 'world_item_rarity_snapshot') registerNames((d || []).map(s => [s.item_id, s.item_name]));
  else if (name === 'world_skill_snapshot') registerNames((d || []).map(s => [s.skill_id, s.skill_name]));
  else if (name === 'world_region_site_snapshot') registerNames((d.sites || []).map(s => [s.site_id, s.site_name]));
}

const NAME_KEY = 'yh-names-v1';
let nameCache = false;
try { const c = JSON.parse(localStorage.getItem(NAME_KEY) || 'null'); if (Array.isArray(c) && c.length) { registerNames(c); nameCache = true; } } catch {}
export const hasNameCache = () => nameCache;
export function preloadNames() {
  return Promise.allSettled([load('world_map_snapshot', undefined, { maxAge: 60000 }), load('world_inventory_snapshot', undefined, { maxAge: 15000 })])
    .then(r => { try { localStorage.setItem(NAME_KEY, JSON.stringify(namesDump())); } catch {} return r; });
}

export const MAJOR_FACTIONS = {
  night_office: { name: '야행국 정통파', type: '관청·퇴마', desc: '관료제와 조사망을 장악한 공인 퇴마 조직. 자원·정보·법적 권한이 강하지만 규정이 엄격합니다.', entry: '기초 교육과 신원 심사 통과', base: 'hq_yard' },
  red_moon_cult: { name: '적월교', type: '마교·주술', desc: '금단의 요기를 흡수하는 마교. 고위험 지역 접근과 강력한 주술을 얻지만 정통파와 적대합니다.', entry: '적월교 거점에서 입교 의식', base: 'bone_market' },
  black_lotus: { name: '흑련회', type: '사교·비밀결사', desc: '정보·암시장·기억술을 다루는 비밀 결사. 잠입과 거래에 강합니다.', entry: '암시장 계약 체결', base: 'hidden_bazaar' },
  north_league: { name: '북령맹', type: '무림 정파 연맹', desc: '산문과 무력 문파의 연맹. 방어·호송·수련에 강하고 적월교와 전쟁 중입니다.', entry: '북령맹 산문에서 맹약 체결', base: 'iron_monastery' },
  river_alliance: { name: '수향연맹', type: '상단·수로', desc: '나루·상단·수로를 통제합니다. 이동과 교역에 강합니다.', entry: '구름나루에서 보증인 확보', base: 'river_ferry' },
  southern_remnant: { name: '남명회', type: '망국 유민·저항', desc: '남부 망국의 유민 집단. 생존·채집·유적 탐사에 능합니다.', entry: '잔불촌의 수호 의뢰 완료', base: 'ember_village' },
  mandate_court: { name: '천명원', type: '황실·천문', desc: '천문과 운명을 관리하는 황실 기관. 고위험 사건 기록을 열람합니다.', entry: '천문대의 관측 시험 통과', base: 'star_observatory' },
};
for (const [k, f] of Object.entries(MAJOR_FACTIONS)) f.base = GAMEDATA.factionHome?.[k]?.[0] || f.base;
registerNames(Object.entries(MAJOR_FACTIONS).map(([k, v]) => [k, v.name]));

export function panel(title, body, { ico, extra = '', cls = '', id = '' } = {}) {
  return `<section class="panel ${cls}" ${id ? `id="${id}"` : ''}><header class="panel-head"><h2>${ico ? icon(ico, 16) : ''}${esc(title)}</h2>${extra}</header><div class="panel-body">${body}</div></section>`;
}
export function itemsText(obj) {
  const e = Object.entries(obj || {}).filter(([, n]) => Number(n) > 0);
  return e.length ? e.map(([k, n]) => `${nameOf(k)} ×${n}`).join(', ') : '없음';
}
export function chip(text, kind = '') { return `<span class="chip ${kind}">${esc(text)}</span>`; }
export function danger(lv) {
  const n = Number(lv) || 0;
  return chip(`위험 ${n}`, n >= 7 ? 'bad' : n >= 4 ? 'warn' : 'ok');
}
export function loading(text = '불러오는 중…') { return `<div class="loading"><span class="spinner"></span>${esc(text)}</div>`; }
export function errorBox(msg) { return `<div class="empty error">${icon('close', 20)}<p>${esc(friendlyError(msg))}</p></div>`; }
export function currentRegion(mapSnap) {
  const c = store.character; if (!mapSnap || !c) return null;
  return (mapSnap.regions || []).find(r => r.region_id === mapSnap.current_region_id) || (mapSnap.regions || []).find(r => r.region_name === c.location) || null;
}
export { fmt };

let zones = null, zonesAt = 0;
export async function safeZones() {
  if (zones && Date.now() - zonesAt < 600000) return zones;
  const { data, error } = await db.from('world_map_regions').select('region_id,region_name,is_safe_zone,shop_name,has_stable,control_faction_id,territory_name,contested');
  if (error) { if (zones) return zones; throw new Error(error.message); }
  zones = new Map((data || []).map(r => [r.region_id, r])); zonesAt = Date.now();
  return zones;
}
export function zonesNow() { return zones; }
