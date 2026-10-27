// 화면 모듈 공용 도우미: 이름 등록을 겸한 스냅샷 로더와 카드·목록 조각.
import { db, rpc, store, on, registerNames, namesDump, nameOf, esc, icon, fmt } from '../core.js';

// 같은 스냅샷을 짧은 시간에 여러 화면이 요청하면 한 번만 호출한다.
const inflight = new Map();
const cacheAt = new Map();
export async function load(name, args, { maxAge = 0 } = {}) {
  const key = name + JSON.stringify(args ?? null);
  if (maxAge && store.snaps[key] && Date.now() - (cacheAt.get(key) || 0) < maxAge) return store.snaps[key];
  if (inflight.has(key)) return inflight.get(key);
  const p = rpc(name, args).then(d => { store.snaps[key] = d; cacheAt.set(key, Date.now()); register(name, d); return d; })
    .finally(() => inflight.delete(key));
  inflight.set(key, p);
  return p;
}
export function invalidate(prefix) { for (const k of [...cacheAt.keys()]) if (!prefix || k.startsWith(prefix)) cacheAt.delete(k); }
// 위치·소속이 바뀌는 행동 뒤에는 지도 캐시를 버린다.
const MAP_CHANGERS = /travel|mount|join_major_faction|field_|battle_|expedition/;
// 여기 있는 이들·동료 목록은 자리나 파티가 바뀌는 행동 뒤에만 새로 읽는다(행동마다 읽으면 서버 부담, 2026-10-28)
const ROSTER_CHANGERS = /travel|field_move|rescue|party|expedition|downed|idle/;
on('changed', ({ name }) => { if (ROSTER_CHANGERS.test(name)) { invalidate('world_region_roster'); invalidate('world_party_overview'); } if (MAP_CHANGERS.test(name)) invalidate('world_map_snapshot'); });
window.addEventListener('yahang:arrived', () => invalidate());

// 응답에 들어 있는 이름을 사전에 등록해 내부 코드(hq_archive 등)가 화면에 노출되지 않게 한다.
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

// 지도·아이템 이름은 어느 화면에서든 필요하므로 게임 진입 시 미리 불러 둔다.
// 이름 사전(지역·물품·제작법 코드 → 이름)은 기기에 남겨 두고, 다음 접속 때 서버 응답을 기다리지 않고 바로 화면을 그린다.
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
  red_moon_cult: { name: '적월교', type: '마교·주술', desc: '금단의 요기를 흡수하는 마교. 고위험 지역 접근과 강력한 주술을 얻지만 정통파와 적대합니다.', entry: '적월교 거점에서 입교 의식', base: 'red_moon_fort' },
  black_lotus: { name: '흑련회', type: '사교·비밀결사', desc: '정보·암시장·기억술을 다루는 비밀 결사. 잠입과 거래에 강합니다.', entry: '암시장 계약 체결', base: 'hidden_bazaar' },
  north_league: { name: '북령맹', type: '무림 정파 연맹', desc: '산문과 무력 문파의 연맹. 방어·호송·수련에 강하고 적월교와 전쟁 중입니다.', entry: '북령맹 산문에서 맹약 체결', base: 'iron_monastery' },
  river_alliance: { name: '수향연맹', type: '상단·수로', desc: '나루·상단·수로를 통제합니다. 이동과 교역에 강합니다.', entry: '구름나루에서 보증인 확보', base: 'river_ferry' },
  southern_remnant: { name: '남명회', type: '망국 유민·저항', desc: '남부 망국의 유민 집단. 생존·채집·유적 탐사에 능합니다.', entry: '잔불촌의 수호 의뢰 완료', base: 'ember_village' },
  mandate_court: { name: '천명원', type: '황실·천문', desc: '천문과 운명을 관리하는 황실 기관. 고위험 사건 기록을 열람합니다.', entry: '천문대의 관측 시험 통과', base: 'star_observatory' },
};
registerNames(Object.entries(MAJOR_FACTIONS).map(([k, v]) => [k, v.name]));

/* ── 조각 ───────────────────────────────────────────────── */
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
export function errorBox(msg) { return `<div class="empty error">${icon('close', 20)}<p>${esc(msg)}</p></div>`; }
export function currentRegion(mapSnap) {
  const c = store.character; if (!mapSnap || !c) return null;
  return (mapSnap.regions || []).find(r => r.region_id === mapSnap.current_region_id) || (mapSnap.regions || []).find(r => r.region_name === c.location) || null;
}
export function inventoryOf() { return store.character?.inventory || {}; }
export { fmt };

// 안전지대·상점·마구간 정보(지역 테이블은 공개 읽기). 한 번 받아 두고 재사용한다.
let zones = null;
export async function safeZones() {
  if (zones) return zones;
  const { data, error } = await db.from('world_map_regions').select('region_id,region_name,is_safe_zone,shop_name,has_stable,control_faction_id,territory_name');
  if (error) throw new Error(error.message);
  zones = new Map((data || []).map(r => [r.region_id, r]));
  return zones;
}
export function zoneOf(map, regionId) { return map?.get(regionId) || null; }
