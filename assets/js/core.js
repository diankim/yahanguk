import { framed, framedInner } from './cosmetics.js';
import { GAMEDATA } from './gamedata.js';
import { busyText } from './rules.js';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0';

import { SUPABASE_URL, SUPABASE_KEY, isMaintenanceError, goMaintenance } from './config.js';
import { hit } from './changes.js';
export { SUPABASE_URL, SUPABASE_KEY };
const BOOT_TAG = (() => {
  let nav = 'na', prev = 'new', n = 0;
  try { nav = performance.getEntriesByType('navigation')[0]?.type || 'na'; } catch {}
  try {
    prev = sessionStorage.getItem('yh-life') || 'new';
    n = (+sessionStorage.getItem('yh-boots') || 0) + 1;
    sessionStorage.setItem('yh-boots', String(n));
    sessionStorage.setItem('yh-life', 'open');
    addEventListener('pagehide', () => { try { if (!/^self-/.test(sessionStorage.getItem('yh-life') || '')) sessionStorage.setItem('yh-life', 'hid'); } catch {} });
    addEventListener('pageshow', e => { if (e.persisted) try { sessionStorage.setItem('yh-life', 'open'); } catch {} });
  } catch {}
  return `nav=${nav};disc=${document.wasDiscarded ? 1 : 0};prev=${prev};n=${n}`;
})();
export const db = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
  global: { headers: { 'X-Client-Info': `supabase-js-web/2.57.0 ${BOOT_TAG}` } },
});

const listeners = new Map();
export function on(evt, fn) { (listeners.get(evt) || listeners.set(evt, new Set()).get(evt)).add(fn); return () => listeners.get(evt)?.delete(fn); }
export function emit(evt, data) { listeners.get(evt)?.forEach(fn => { try { fn(data); } catch (e) { console.error(e); } }); }

export const store = { user: null, character: null, snaps: {} };
export function busyOf(s = store) {
  const c = s.character, now = Date.now(), at = c?.travel_arrives_at ? new Date(c.travel_arrives_at).getTime() : 0;
  if (at > now) return { kind: 'travel', until: at };
  if (s.expedition) return { kind: 'expedition', until: null };
  if (s.idle?.active) return { kind: 'idle', until: null };
  if (c && (c.downed_at || c.health <= 0)) return { kind: 'downed', until: null };
  return null;
}
let hereFrame = 0, hereTimer = null;
export function paintHere() {
  const b = busyOf();
  clearTimeout(hereTimer); hereTimer = b?.until ? setTimeout(hereSoon, Math.max(0, b.until - Date.now()) + 300) : null;
  for (const el of document.querySelectorAll('[data-here]')) {
    const lock = !!b && !(b.kind === 'downed' && el.hasAttribute('data-here-down'));
    if (lock) {
      if (!el.classList.contains('here-locked')) el.dataset.hereTitle = el.getAttribute('title') ?? '';
      el.classList.add('here-locked'); el.setAttribute('aria-disabled', 'true'); el.title = josa(busyText(b.kind, el.dataset.here));
    } else if (el.classList.contains('here-locked')) {
      el.classList.remove('here-locked'); el.removeAttribute('aria-disabled');
      if (el.dataset.hereTitle) el.title = el.dataset.hereTitle; else el.removeAttribute('title');
      delete el.dataset.hereTitle;
    }
  }
}
function hereSoon() { if (!hereFrame) hereFrame = requestAnimationFrame(() => { hereFrame = 0; paintHere(); }); }
if (typeof document !== 'undefined') {
  document.addEventListener('click', e => {
    const el = e.target?.closest?.('.here-locked'); if (!el) return;
    e.preventDefault(); e.stopImmediatePropagation(); toast(el.title, 'error');
  }, true);
  const watch = () => new MutationObserver(ms => { if (ms.some(m => [...m.addedNodes].some(n => n.nodeType === 1 && (n.matches?.('[data-here]') || n.querySelector?.('[data-here]'))))) hereSoon(); })
    .observe(document.body, { childList: true, subtree: true });
  if (document.body) watch(); else document.addEventListener('DOMContentLoaded', watch, { once: true });
  for (const ev of ['character', 'expedition', 'idle']) on(ev, hereSoon);
}

export function friendlyError(e) {
  const msg = String(e?.message || e || '알 수 없는 오류');
  if (isMaintenanceError(msg)) { goMaintenance(); return '서버 점검 중입니다.'; }
  if (/Auth session missing|JWT|not authenticated/i.test(msg)) return '로그인이 필요합니다.';
  if (/permission denied/i.test(msg)) return '이 작업을 할 권한이 없습니다.';
  if (/Failed to fetch|NetworkError|Load failed/i.test(msg)) return '서버에 연결할 수 없습니다. 네트워크를 확인하세요.';
  if (/Invalid login credentials/i.test(msg)) return '아이디 또는 비밀번호가 올바르지 않습니다.';
  if (/Email not confirmed/i.test(msg)) return '이메일 인증을 완료한 뒤 로그인하세요.';
  if (/User already registered|already been registered/i.test(msg)) return '이미 쓰이는 아이디입니다. 다른 아이디를 정하세요.';
  if (/Email signups are disabled|Signups not allowed/i.test(msg)) return '지금은 가입을 받지 않습니다. 운영진에게 알려 주세요.';
  if (/Email address .* is invalid|invalid format/i.test(msg)) return '아이디는 영문 소문자와 숫자 4~16자로 정하세요.';
  if (/Password should be at least/i.test(msg)) return '비밀번호는 6자 이상이어야 합니다.';
  if (/known to be weak|weak_password|easy to guess/i.test(msg) || e?.code === 'weak_password') return '너무 흔해서 쓸 수 없는 비밀번호입니다(유출 목록에 있는 비밀번호). 다른 비밀번호로 정해 주세요.';
  if (/[가-힣]/.test(msg)) return msg;
  if (/Database error saving new user/i.test(msg)) return '초대권을 쓸 수 없습니다. 번호를 다시 확인해 주세요.';
  if (/security purposes|rate limit|too many requests/i.test(msg)) return '잠시 뒤 다시 시도하세요.';
  if (/PGRST202|schema cache/i.test(msg)) return '서버가 새 버전으로 바뀌는 중입니다. 잠시 뒤 새로고침해 주세요.';
  if (/invalid input syntax for type uuid/i.test(msg)) return '찾는 기록이 없습니다.';
  if (/statement timeout|canceling statement/i.test(msg)) return '서버가 바쁩니다. 잠시 뒤 다시 시도하세요.';
  if (/duplicate key|deadlock/i.test(msg)) return '다른 요청과 겹쳤습니다. 다시 시도하세요.';
  if (e?.name === 'TypeError' || /TypeError|Cannot read|is not a function|undefined|null/.test(msg)) return '화면을 그리다 문제가 생겼습니다. 새로고침해 주세요.';
  return '알 수 없는 오류가 생겼습니다. 잠시 뒤 다시 시도하세요.';
}

export async function rpc(name, args) {
  const { data, error } = args === undefined ? await db.rpc(name) : await db.rpc(name, args);
  if (!hit('reads', name) || hit('settles', name)) charMut++;
  if (error) throw Object.assign(new Error(friendlyError(error)), { hint: error.hint || '', code: error.code || '' });
  return data;
}
export async function snap(name, args) {
  const data = await rpc(name, args);
  store.snaps[name] = data;
  return data;
}
export const midBattle = ({ name, data }) => name === 'world_battle_action' && !data?.ended;
export function throttle(fn, gap) {
  let last = 0, t = null;
  return () => { const wait = last + gap - Date.now(); if (wait <= 0) { last = Date.now(); fn(); } else if (!t) t = setTimeout(() => { t = null; last = Date.now(); fn(); }, wait); };
}
export function battleItemRoute(id) {
  const ev = new CustomEvent('yh-battle-item', { detail: { id, handled: false } });
  window.dispatchEvent(ev);
  return ev.detail.handled;
}
export function useItemAct(id) {
  if (battleItemRoute(id)) return Promise.resolve(null);
  return act('world_use_item', { p_item_id: id }).catch(e => {
    loadCharacter({ hud: true, field: onFieldView() }).catch(() => {});
    throw e;
  });
}
export async function act(name, args) {
  const data = await rpc(name, args);
  if (hit('equipped', name)) equipped = null;
  const mid = midBattle({ name, data });
  if (mid && data?.me && store.character) { Object.assign(store.character, data.me); store.charAt = Date.now(); emit('character', store.character); }
  else try {
    const lvl = store.character?.level, light = fieldLight(name, data);
    await loadCharacter({ hud: !mid, field: !mid && onFieldView() && !light, inv: !mid && onInvView() && !hit('invQuiet', name) });
    if (light) await patchField(light, data, lvl);
  } catch {}
  emit('changed', { name, data });
  return data;
}
const readOwn = () => db.from('world_characters').select('*').eq('owner_id', store.user.id).maybeSingle();
const onFieldView = () => !location.hash || location.hash === '#' || /^#\/(home)?(\/|$)/.test(location.hash);
const FIELD_LIGHT = new Set(['quiet', 'omen', 'cache', 'regional', 'hazard']);
function fieldLight(name, data) {
  if (!/^world_field_search(_quiet)?$/.test(name) || !FIELD_LIGHT.has(data?.outcome) || !onFieldView()) return null;
  const f = store.snaps['world_field_snapshotnull'];
  return f?.stamina && Array.isArray(f.recent) && !f.battle ? f : null;
}
async function patchField(f, data, lvl) {
  const c = store.character;
  if (!c || c.level !== lvl || !c.stamina_at || c.downed_at || c.health <= 0 || store.snaps['world_field_snapshotnull'] !== f) return loadCharacter({ field: true }).catch(() => {});
  const per = 900, mx = f.stamina.max, at = new Date(c.stamina_at).getTime(), sec = Math.max(0, Date.now() - at) / 1000;
  const now = Math.min(mx, Math.max(0, c.stamina) + Math.floor(sec / per));
  const stamina = { ...f.stamina, now, next_at: now >= mx ? null : new Date(at + (Math.floor(sec / per) + 1) * per * 1000).toISOString() };
  const recent = [{ content: data.content, kind: data.outcome, at: new Date().toISOString() }, ...f.recent].slice(0, 12);
  emit('snaps', { world_field_snapshot: { ...f, stamina, recent } });
}
const onInvView = () => /^#\/(bag|char)(\/|$)/.test(location.hash);
let charMut = 0, charSeq = 0, charShown = 0, charUser = null;
const charFlight = new Map();
export function loadCharacter(opts = {}) {
  if (!store.user) return Promise.resolve(null);
  const key = `${!!opts.hud}${!!opts.field}${!!opts.inv}`, f = charFlight.get(key);
  if (f && f.mut === charMut && f.user === store.user.id) return f.p;
  const p = readCharacter(opts).finally(() => { if (charFlight.get(key)?.p === p) charFlight.delete(key); });
  charFlight.set(key, { p, mut: charMut, user: store.user.id });
  return p;
}
async function readCharacter({ hud = false, field = false, inv = false } = {}) {
  const seq = ++charSeq, user = store.user.id;
  if (charUser !== user) { charUser = user; charShown = 0; }
  const both = hud || field || inv;
  const [, res] = await Promise.all([stacksFresh ? null : loadStacks(),
    both ? rpc('world_me', { p_hud: hud, p_field: field, p_inv: inv }).then(d => ({ data: d?.character ?? null, snaps: d }), () => readOwn()) : readOwn(),
    equipped ? null : loadEquipped()]);
  if (res.error) throw new Error(friendlyError(res.error));
  const data = res.data;
  if (store.user?.id !== user || seq < charShown) return store.user?.id === user ? store.character : null;
  charShown = seq;
  store.character = data; store.charAt = Date.now();
  if (res.snaps) emit('snaps', { world_hud_snapshot: res.snaps.hud, world_field_snapshot: res.snaps.field, world_inventory_state: res.snaps.inv });
  emit('character', data);
  return data;
}

export const JOB_LINE = { artificer: 'melee', scout: 'ranged', sealmaster: 'sealing', exorcist: 'exorcism', analyst: 'dagger', medic: 'medicine' };
export const COMBAT_LINES = ['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine'];
export const JOBS = {
  exorcist: { name: '퇴마관', trait: '술법 공격', desc: '【술법 공격】 부적과 방울로 요괴를 치는 술법 공격수. 몸은 약하지만 이목이 낮아(−15) 뒷줄에서 술법을 쏟습니다. 술법 피해 +8%·받는 피해 −6%·의지·영성이 오르면 회피·도주도 함께, 퇴마진(반드시 치명타로 꽂히는 한 방, 결계 깨기). 협동 기술은 약점 진언·멸마 진격 같은 공격 쪽.',
    kit: '영령 방울 · 삼베 도포 · 무명 부적낭',
    fx: ['술법 피해 +8%', '받는 피해 −6%', '이목 −15(몸은 약하지만 요괴 눈에 덜 띔)', '퇴마진: 술법 ×1.4·반드시 치명타(한 방), 결계 깨기', '원정 기술: 파사 부적'] },
  scout: { name: '월궁 사수', trait: '원거리 공격', desc: '【원거리 공격】 뒷줄에서 활로 꾸준히 쏘는 원거리 공격수. 가장 잘 피하고 잘 빠져나옵니다. 원거리 피해 +8%·원거리 치명타 +4·회피 +6·도주 +15, 급소 사격(표식 세 번 — 맞힐 때마다 피해 +25%).',
    kit: '매눈 활 · 화살 100 · 무명 철릭 · 미투리',
    fx: ['원거리 피해 +8%', '원거리 치명타 +4', '회피 +6', '도주 +15', '급소 사격: ×1.4 · 표식 세 번(맞힐 때마다 +25%)', '원정 기술: 선제 사격'] },
  artificer: { name: '호위 무사', trait: '방패·수호', desc: '【방패·수호】 앞에 서서 요괴의 시선을 끌고 동료를 지키는 방패. 받는 피해 −12%·이목 +80(요괴가 먼저 노림)·방패를 든 만큼 공격력 ×0.85, 파갑참(근접 ×1.7, 방어·결계 무시). 대신 막기·철벽 수호로 동료를 감쌉니다.',
    kit: '월철 환도 · 쇠미늘 갑옷 · 무명 두건 · 주사 호신부',
    fx: ['받는 피해 −12%', '이목 +80(요괴가 먼저 노림)', '공격력 ×0.85(방패를 든 만큼)', '파갑참: 근접 ×1.7, 방어·결계 무시', '원정 기술: 반격 태세'] },
  medic: { name: '의무관', trait: '치유', desc: '【치유】 다치고 쓰러진 동료를 살리는 치유사. 회복품 ×1.15(파티원에게 쓰면 ×1.4)·회복 +10%(의술 기술로 더 늘어남), 응급 처방(한 전투에 한 번, 체력 회복·나쁜 상태 걷기).',
    kit: '먹 부채 · 삼베 도포 · 쑥 향낭 · 약초·탕약',
    fx: ['회복품 ×1.15, 파티원에게 쓰면 ×1.4', '회복 +10%(의술 계열 기본 기술로 50단계까지 +35% 더)', '응급 처방: 한 전투에 한 번, 25 소모. 체력 15 + 체질÷2 + 의지÷2 회복, 최대 40. 나쁜 상태도 걷어 냅니다.', '원정 기술: 야전 처치'] },
  sealmaster: { name: '봉인술사', trait: '보조·버팀', desc: '【보조·버팀】 요괴를 묶고 동료를 북돋는 술사이자, 앞줄이 비면 받쳐 내는 두 번째 방패. 이목·방어는 호위 무사 다음(이목 +60·방어 +30)·정신 손실 −10%·침식 −5%, 봉인술(묶기)과 협동 기술.',
    sub: '북돋기·약화', kit: '무쇠 금강령 · 누비 전포 · 유건 · 봉인 부적',
    fx: ['이목 +60 · 방어 +30(호위 무사 다음)', '정신 손실 −10%', '침식 −5%', '봉인술: 묶기', '원정 기술: 결계 야영'] },
  analyst: { name: '암영 검객', trait: '근접 공격', desc: '【근접 공격】 단도로 급소를 찌르는, 근접에서 가장 빨리 쓰러뜨리는 공격수. 근접 공격력 ×1.18(피해 상한과 따로)·근접 치명타 +5·단도 기술로 이목이 낮아짐, 약점 간파(다음 세 번 공격 +40%·치명타가 잘 남).',
    kit: '날선 단도 · 누비 전포 · 은방울 노리개 · 짚신 · 청심환 2',
    fx: ['근접 공격력 ×1.18(피해 상한과 따로)', '단도 기술: 이목 −45%까지', '근접 무기를 들면 치명타 +5', '약점 간파: 다음 세 번 공격 강화', '원정 기술: 급소 찌르기'] },
};
const STAT_KEYS = ['strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity'];
for (const [k, j] of Object.entries(JOBS)) j.base = Object.fromEntries(STAT_KEYS.map(s => [s, GAMEDATA.jobBase?.[k]?.[s] ?? 3]));
export const RAID_ON = true;
export const MARKET_ONLY = new Set();
export const GRADES = ['', '범품', '양품', '진품', '명품', '신품'];
export const FACTIONS = {
  headquarters: { name: '본부 직속', trait: '본부 보급', desc: '본부의 제작·정비에 익숙합니다. 제작 품질 +4 · 회복량 +5% · 상점 판매 한도 +500전.' },
  fieldbureau: { name: '현장대응국', trait: '현장 적응', desc: '외부 현장을 누빕니다. 채집량 +6% · 이동 시간 −6% · 요괴 조우 −5%.' },
  archivebureau: { name: '기록감찰국', trait: '사건 기록', desc: '단서와 기록을 다룹니다. 단서 +8% · 희귀품 +3% · 주는 피해 +2%.' },
  sealbureau: { name: '봉인관리국', trait: '봉인 규정', desc: '봉인과 요괴 대응 절차에 밝습니다. 정신 손실 −10% · 침식 −8% · 주는 피해 +3%.' },
  medicalbureau: { name: '의무지원국', trait: '후방 지원', desc: '회복과 생존을 돕습니다. 회복량 +10% · 받는 피해 −4% · 채집량 +3%.' },
  independent: { name: '외부 협력자', trait: '자유 행동', desc: '정규 부서에 매이지 않습니다. 이동 시간 −5% · 희귀품 +2% · 상점 판매 수수료 3%(보통 5%).' },
};
const FIXED = {
  fieldwork: '채집', mining: '채광', fishing: '낚시',
  ...GAMEDATA.names.field,
  melee: '근접', ranged: '사격', dagger: '단도', exorcism: '퇴마술', medicine: '의술', analysis: '분석', first_aid: '응급 처치', guarding: '방어', wardcraft: '봉인 공예', tracking: '탐사', foraging: '채집',
  tool: '도구', weapon: '무기', armor: '방어구', hat: '관모', shoes: '신', norigae: '노리개', amulet: '호신부', mask: '탈', accessory: '장신구', consumable: '소모품', material: '재료', craft_material: '제작 재료', quest: '임무 물품', trade_goods: '교역품', mount: '탈것', equipment: '장비', furniture: '별채 가구', pet: '꼬마 동무', outfit: '옷',
  common: '범품', uncommon: '양품', rare: '진품', epic: '명품', legendary: '신품',
  abyss: '심연', archive: '서고', blood_forest: '혈림', bridge: '다리', burial_ground: '묘역', canyon: '협곡', celestial_tower: '천문탑', coast: '해안', desert: '사막',
  faction_stronghold: '세력 거점', forest: '숲', frontier_gate: '변경 관문', haunted_garden: '흉가 정원', headquarters: '본부', ice_valley: '빙곡', islands: '군도', lake: '호수',
  lost_city: '잊힌 도시', market: '시장', mine: '광산', monastery: '사원', mountain_pass: '고갯길', mountain_peak: '산정', observatory: '관측소', pavilion: '정자',
  rift: '균열', river_port: '나루', ruined_temple: '폐사원', ruins: '폐허', safe_zone: '안전 지대', sealed_shrine: '봉인 사당', swamp: '늪', training: '수련장',
  underground: '지하', underwater_ruins: '수중 유적', underworld_market: '귀시', village: '마을', wilderness: '황야',
  ambush: '매복', toxic: '독성', venom: '맹독', spectral: '영체', warded: '결계', seal_breaker: '봉인 파괴', tide: '수계', swarm: '떼',
  armored: '장갑', reflect: '반사', aerial: '비행', boss: '우두머리',
  cautious: '신중', balanced: '균형', bold: '강행',
  supply: '보급', relic: '유적', medical: '의료', combat: '전투', hidden: '은신처',
  strength: '근력', agility: '민첩', vitality: '체질', perception: '감각', willpower: '의지', spirit_affinity: '영성',
  gather_qty_pct: '채집량', rare_loot_pct: '희귀품 발견', craft_quality: '제작 품질', combat_damage_pct: '주는 피해', incoming_damage_pct: '받는 피해',
  travel_time_pct: '이동 시간', clue_bonus_pct: '단서 발견', healing_pct: '회복량', erosion_pct: '침식 위험', melee_pct: '근접 피해', ranged_pct: '원거리 피해',
  magic_pct: '술법 피해', encounter_pct: '요괴 조우', mental_per_action: '행동마다 정신', health_per_action: '행동마다 체력', training_xp_pct: '기술 경험',
  action_quality_pct: '행동 효율', agility_pct: '민첩', gathering_bonus_pct: '채집량', damage_reduction_pct: '피해 감소', defense: '방어', power: '위력',
  fish_bite_pct: '낚시 입질', fish_rare_pct: '희귀 어종', fish_size_pct: '물고기 크기',
  supply_save_pct: '원정 보급품 아낌', expedition_xp_pct: '원정 경험치', trail_find_pct: '비경 찾기', search_find_pct: '숨은 길·채집터 찾기',
  sig_pct: '지역 희귀품', presence: '이목', crit_pct: '치명타', evasion_pct: '회피', flee_pct: '달아나기', mental_loss_pct: '정신 손실',
  river: '강', marsh: '늪', sea: '바다', deep: '깊은 물', canal: '수로',
  dawn: '해돋이', noon: '한낮', dusk: '땅거미', night: '삼경', clear: '청명', cloudy: '담운', rain: '장우', drizzle: '세우', fog: '농무', wind: '삭풍', snow: '설한', bloodmist: '혈무',
};
const FLAT = new Set(['craft_quality', 'defense', 'power', 'presence', 'mental_per_action', 'health_per_action']);
const PER_ACTION = new Set(['mental_per_action', 'health_per_action']);
const LINE_FX = { cq: '제작 품질', cs: '재료 아낄 확률', cx: '하나 더 만들 확률', gq: '채집량', gr: '희귀품 발견' };
function fxLabel(k) {
  if (FIXED[k]) return FIXED[k];
  if (k === 'food_dur_pct') return '음식 기운 지속';
  const m = /^(cq|cs|cx|gq|gr)_(.+)$/.exec(k);
  if (!m) return '기타 효과';
  const line = m[2] === 'all' ? (m[1][0] === 'g' ? '모든 채집' : '모든 제작') : (FIXED[m[2]] || m[2]);
  return `${line} ${LINE_FX[m[1]]}`;
}
export function effectText(effects, potency = 1) {
  return Object.entries(effects || {}).filter(([k, v]) => k !== 'trait' && k !== 'weapon_type' && k !== 'req_rank' && Number(v) && fxLabel(k) !== '기타 효과').map(([k, v]) => {
    const n = Math.round(Number(v) * (potency || 1) * 10) / 10;
    if (PER_ACTION.has(k)) return n < 0 ? `${FIXED[k]} 손실 ${Math.abs(n)} 줄임` : `${FIXED[k]} -${Math.abs(n)}`;
    return `${fxLabel(k)} ${n > 0 ? '+' : ''}${n}${FLAT.has(k) || k.startsWith('cq_') ? '' : '%'}`;
  });
}
const LOWER_BETTER = new Set(['encounter_pct', 'incoming_damage_pct', 'travel_time_pct', 'erosion_pct', 'mental_loss_pct', 'mental_per_action', 'health_per_action']);
export function effectGood(k, v) { return LOWER_BETTER.has(k) ? Number(v) < 0 : Number(v) > 0; }
const names = new Map(Object.entries(FIXED));
export function registerNames(entries) { for (const [k, v] of entries) if (k && v) names.set(k, v); }
export function namesDump() { return [...names]; }
export function nameOf(code) {
  if (code == null) return '';
  if (JOBS[code]) return JOBS[code].name;
  if (FACTIONS[code]) return FACTIONS[code].name;
  return names.get(code) || (/^[a-z0-9_]+$/i.test(String(code)) ? '이름 미상' : String(code));
}

export const fmt = {
  num: n => Number(n || 0).toLocaleString('ko-KR'),
  jeon: n => Number(n || 0).toLocaleString('ko-KR') + '전',
  remain(ms) {
    if (ms <= 0) return '완료';
    const s = Math.ceil(ms / 1000), h = Math.floor(s / 3600), m = Math.floor(s % 3600 / 60), r = s % 60;
    return h ? `${h}시간 ${m}분` : m ? `${m}분 ${String(r).padStart(2, '0')}초` : `${r}초`;
  },
  time: t => new Date(t).toLocaleTimeString('ko-KR', { hour: '2-digit', minute: '2-digit', hour12: false }),
};

const ICONS = {
  home: 'M3 11l9-7 9 7v9a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z',
  popout: 'M14 4h6v6M20 4l-9 9M18 14v5a1 1 0 01-1 1H5a1 1 0 01-1-1V7a1 1 0 011-1h5',
  map: 'M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2zM9 4v14M15 6v14',
  user: 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0',
  bag: 'M6 8h12l-1 12H7L6 8zM9 8V6a3 3 0 016 0v2',
  chest: 'M3 10h18v10H3zM3 10l2-5h14l2 5M10 14h4',
  scroll: 'M7 3h10v14a3 3 0 01-3 3H6a3 3 0 01-3-3v-1h11M7 3a3 3 0 00-3 3v1h3M10 8h4M10 12h4',
  help: 'M12 22a10 10 0 100-20 10 10 0 000 20zM9.5 9a2.5 2.5 0 015 .5c0 1.5-2.5 2-2.5 3.5M12 17h.01',
  gear: 'M12 15a3 3 0 100-6 3 3 0 000 6zM19.4 15a1.7 1.7 0 00.3 1.8l.1.1a2 2 0 11-2.8 2.8l-.1-.1a1.7 1.7 0 00-1.8-.3 1.7 1.7 0 00-1 1.5V21a2 2 0 11-4 0v-.1a1.7 1.7 0 00-1.1-1.5 1.7 1.7 0 00-1.8.3l-.1.1a2 2 0 11-2.8-2.8l.1-.1a1.7 1.7 0 00.3-1.8 1.7 1.7 0 00-1.5-1H3a2 2 0 110-4h.1a1.7 1.7 0 001.5-1.1 1.7 1.7 0 00-.3-1.8l-.1-.1a2 2 0 112.8-2.8l.1.1a1.7 1.7 0 001.8.3H9a1.7 1.7 0 001-1.5V3a2 2 0 114 0v.1a1.7 1.7 0 001 1.5 1.7 1.7 0 001.8-.3l.1-.1a2 2 0 112.8 2.8l-.1.1a1.7 1.7 0 00-.3 1.8V9a1.7 1.7 0 001.5 1H21a2 2 0 110 4h-.1a1.7 1.7 0 00-1.5 1z',
  palette: 'M12 22a10 10 0 110-20c5.5 0 10 4 10 9a5 5 0 01-5 5h-2a2 2 0 00-1 3.7A1.5 1.5 0 0112 22zM7.5 11h.01M10.5 7h.01M15.5 8h.01',
  idcard: 'M3 5h18v14H3zM8 11a2 2 0 100-4 2 2 0 000 4zM5 16a3 3 0 016 0M14 9h4M14 13h4',
  logout: 'M15 4h4a1 1 0 011 1v14a1 1 0 01-1 1h-4M10 17l-5-5 5-5M5 12h11',
  bell: 'M6 8a6 6 0 0112 0c0 7 3 8 3 8H3s3-1 3-8M10 21a2 2 0 004 0',
  chat: 'M4 5h16v11H8l-4 4V5z',
  sword: 'M14.5 4H20v5.5L9 20.5 3.5 15 14.5 4zM5 13l6 6M3 21l3-3',
  route: 'M6 19a2 2 0 100-4 2 2 0 000 4zM18 9a2 2 0 100-4 2 2 0 000 4zM8 17h6a3 3 0 000-6H10a3 3 0 010-6h6',
  hourglass: 'M6 3h12M6 21h12M7 3c0 5 10 5 10 9s-10 4-10 9M17 3c0 5-10 5-10 9s10 4 10 9',
  leaf: 'M5 21c0-9 5-15 15-16-1 10-7 15-15 16zM5 21l7-7',
  hammer: 'M14 6l4 4M3 21l9-9M12 4l8 8-3 3-8-8z',
  coin: 'M12 21a9 9 0 100-18 9 9 0 000 18zM9 12h6M12 9v6',
  token: 'M12 3l8 4v6c0 4-3.5 7-8 8-4.5-1-8-4-8-8V7z',
  pin: 'M12 21s-7-6.5-7-12a7 7 0 0114 0c0 5.5-7 12-7 12zM12 11a2 2 0 100-4 2 2 0 000 4z',
  plus: 'M12 5v14M5 12h14', minus: 'M5 12h14', fish: 'M3 12c3-5 9-6 13-2l4-3v10l-4-3c-4 4-10 3-13-2zM8 11h.01', compass: 'M12 21a9 9 0 100-18 9 9 0 000 18zM15 9l-2 4-4 2 2-4z', target: 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 16a4 4 0 100-8 4 4 0 000 8zM12 12h.01',
  close: 'M6 6l12 12M18 6L6 18', check: 'M5 12l5 5L20 7', chevron: 'M9 6l6 6-6 6', back: 'M15 6l-6 6 6 6',
  search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM20 20l-4-4', filter: 'M4 6h16M7 12h10M10 18h4', flame: 'M12 22c4 0 7-3 7-7 0-5-5-7-5-12-3 2-5 5-5 8-1-1-2-2-2-4-2 2-2 5-2 8 0 4 3 7 7 7z',
  moon: 'M20 14A8 8 0 1110 4a7 7 0 0010 10z', users: 'M9 11a4 4 0 100-8 4 4 0 000 8zM2 21a7 7 0 0114 0M17 11a3 3 0 000-6M22 21a6 6 0 00-4-5.7',
  shop: 'M4 9l1-5h14l1 5M4 9h16v11H4zM4 9c0 2 2 3 4 3s4-1 4-3c0 2 2 3 4 3s4-1 4-3M10 20v-5h4v5',
  heart: 'M12 20s-8-5-8-11a4.5 4.5 0 018-2.8A4.5 4.5 0 0120 9c0 6-8 11-8 11z', eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zM12 15a3 3 0 100-6 3 3 0 000 6z',
  spark: 'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5L18 18M6 18l2.5-2.5M15.5 8.5L18 6',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z', volume: 'M4 9h4l5-4v14l-5-4H4zM17 8a5 5 0 010 8',
  refresh: 'M20 12a8 8 0 11-2.3-5.7M20 4v5h-5',
  sun: 'M12 16a4 4 0 100-8 4 4 0 000 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  cloud: 'M7 18h10a4 4 0 000-8 6 6 0 00-11.5 1.5A3.5 3.5 0 007 18z',
  rain: 'M7 14h10a4 4 0 000-8 6 6 0 00-11.5 1.5A3.5 3.5 0 007 14zM8 17l-1 3M12 17l-1 3M16 17l-1 3',
  drizzle: 'M7 14h10a4 4 0 000-8 6 6 0 00-11.5 1.5A3.5 3.5 0 007 14zM9 17.5l-.5 1.5M14 18.5l-.5 1.5',
  fog: 'M4 9h16M3 13h18M5 17h14M7 5h10',
  wind: 'M3 8h11a3 3 0 10-3-3M3 12h15a3 3 0 11-3 3M3 16h8',
  snow: 'M12 2v20M4 7l16 10M20 7L4 17M9 4l3 2 3-2M9 20l3-2 3 2',
  mist: 'M12 3c3 4 6 7 6 11a6 6 0 01-12 0c0-4 3-7 6-11zM9 15h6',
  dawn: 'M4 18h16M7 18a5 5 0 0110 0M12 7v3M5.6 11.6l1.4 1.4M18.4 11.6L17 13M2 22h20',
  hat: 'M3 16h18M8 16V9a4 4 0 018 0v7M6 19h12', shoe: 'M4 7v9h16v-2c0-2-2-3-5-3l-3-4H4zM4 19h16',
  knot: 'M12 3a3 3 0 100 6 3 3 0 000-6zM12 9v3M9 12h6M10 12l-2 9M12 12v9M14 12l2 9', talisman: 'M7 3h10v18H7zM10 7h4M10 11h4M10 15h4',
  mask: 'M5 5c4-1 10-1 14 0 0 8-3 14-7 14S5 13 5 5zM8 10h3M13 10h3M10 15h4',
  letter: 'M3 6h18v12H3zM3 7l9 6 9-6', flag: 'M5 21V4M5 4h12l-2.5 4L17 12H5',
  wrench: 'M14.7 6.3a4 4 0 00-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 005.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z',
  crosshair: 'M12 20a8 8 0 100-16 8 8 0 000 16zM12 2v5M12 17v5M2 12h5M17 12h5', vital: 'M12 17a5 5 0 100-10 5 5 0 000 10zM12 12h.01M12 3v3M12 18v3M3 12h3M18 12h3',
  bolt: 'M13 2L4 14h7l-1 8 9-12h-7z', dodge: 'M4 19c4 0 5-7 9-7s4-6 7-6M16 4l4 2-2 4',
  bubble: 'M12 21a9 9 0 100-18 9 9 0 000 18zM8 10a5 5 0 015-3', ward: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6zM9 12l2 2 4-4',
  hand: 'M8 12V6a1.5 1.5 0 013 0v5M11 11V4.5a1.5 1.5 0 013 0V11M14 11V6.5a1.5 1.5 0 013 0V14a7 7 0 01-7 7h-.5a6 6 0 01-5-2.7L3 15a1.5 1.5 0 012.5-1.7L8 15',
  chain: 'M10 14l4-4M10.5 6.5l1.5-1.5a3.5 3.5 0 015 5L15.5 11.5M8.5 12.5L7 14a3.5 3.5 0 005 5l1.5-1.5', star: 'M12 3l2.7 5.6 6.1.9-4.4 4.3 1 6.1L12 17l-5.4 2.9 1-6.1L3.2 9.5l6.1-.9z',
  spiral: 'M12 12a1.5 1.5 0 102 2 3.5 3.5 0 01-4.5 3A5.5 5.5 0 016.5 10 7.5 7.5 0 0120 13', needle: 'M4 20l9-9M13 11l3-7 4 4-7 3M7 14l3 3', drop: 'M12 3s6 6.5 6 11a6 6 0 01-12 0c0-4.5 6-11 6-11z',
  up: 'M6 14l6-6 6 6',
  down: 'M6 10l6 6 6-6',
};
export const ENV_ICON = { dawn: 'dawn', noon: 'sun', dusk: 'moon', night: 'moon', clear: 'sun', cloudy: 'cloud', rain: 'rain', drizzle: 'drizzle', fog: 'fog', wind: 'wind', snow: 'snow', bloodmist: 'mist' };
export function icon(name, size = 18) {
  const p = ICONS[name] || ICONS.spark;
  return `<svg class="ico" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${p}"/></svg>`;
}

export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
const JOSA = { '을(를)': ['을', '를'], '를(을)': ['을', '를'], '이(가)': ['이', '가'], '가(이)': ['이', '가'], '은(는)': ['은', '는'], '는(은)': ['은', '는'],
  '과(와)': ['과', '와'], '와(과)': ['과', '와'], '(으)로': ['으로', '로'], '(이)': ['이', ''] };
const JOSA_RE = /을\(를\)|를\(을\)|이\(가\)|가\(이\)|은\(는\)|는\(은\)|과\(와\)|와\(과\)|\(으\)로|\(이\)/g;
const SKIP = new Set([')', ']', '」', '』', '"', "'", '’', '”', '》', '〉']);
function finalSound(str, end) {
  let i = end - 1;
  while (i >= 0 && SKIP.has(str[i])) i--;
  if (i < 0) return null;
  const ch = str[i], code = ch.charCodeAt(0);
  if (code >= 0xac00 && code <= 0xd7a3) { const jong = (code - 0xac00) % 28; return { has: jong > 0, rieul: jong === 8 }; }
  if (/[0-9]/.test(ch)) return { has: '0136781'.includes(ch), rieul: '178'.includes(ch) };
  if (/cm$/i.test(str.slice(0, i + 1))) return { has: false, rieul: false };
  if (/[a-z]/i.test(ch)) { const l = ch.toLowerCase(); return { has: 'lmn'.includes(l), rieul: l === 'l' }; }
  return null;
}
export function josa(s) {
  const t = String(s ?? '');
  if (!t.includes('(')) return t;
  return t.replace(JOSA_RE, (m, at, all) => {
    const f = finalSound(all, at); if (!f) return m;
    const [withB, without] = JOSA[m];
    if (m === '(으)로') return f.has && !f.rieul ? withB : without;
    return f.has ? withB : without;
  });
}
export const particle = (word, form) => josa(String(word ?? '') + form).slice(String(word ?? '').length);
export function esc(s) { return josa(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
export function h(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; }

export function toast(message, kind = 'info') {
  const box = $('#toasts'); if (!box) return;
  const el = h(`<div class="toast toast-${kind}" role="status">${esc(message)}</div>`);
  if (kind === 'error') window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'error' }));
  box.append(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, kind === 'error' ? 4200 : 2800);
}

export async function guard(btn, fn, { success } = {}) {
  if (btn?.dataset.busy === '1') return;
  if (btn) { btn.dataset.busy = '1'; btn.disabled = true; btn.classList.add('is-busy'); }
  try {
    const out = await fn();
    const msg = success ?? out?.content ?? out?.message ?? out?.result;
    if (msg) toast(typeof msg === 'string' ? msg : '처리했습니다.', 'ok');
    return out;
  } catch (e) {
    toast(friendlyError(e), 'error');
  } finally {
    if (btn) { btn.dataset.busy = ''; btn.disabled = false; btn.classList.remove('is-busy'); }
  }
}

store.staff = new Set();
const STAFF_KEY = 'yh-staff-v1';
export async function loadStaff() {
  try { const c = JSON.parse(localStorage.getItem(STAFF_KEY) || 'null'); if (c && Date.now() - c.at < 6 * 3600e3) { store.staff = new Set(c.ids || []); return store.staff; } } catch {}
  try {
    const { data, error } = await db.from('world_staff').select('owner_id');
    if (!error) { store.staff = new Set((data || []).map(r => r.owner_id)); try { localStorage.setItem(STAFF_KEY, JSON.stringify({ at: Date.now(), ids: [...store.staff] })); } catch {} }
  } catch {}
  return store.staff;
}
let dbvP = null;
export function dbVersion() { return dbvP ||= fetch(`version.json?vc=${Date.now()}`, { cache: 'no-store' }).then(r => r.ok ? r.json() : null).then(j => j?.db_version || null).catch(() => { dbvP = null; return null; }); }
export const isGM = id => !!id && store.staff.has(id);
export const gmBadge = id => isGM(id) ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : '';

export function ask(message, { title = '확인', ok = '확인', cancel = '그만두기', danger = false, alarm = false } = {}) {
  return new Promise(resolve => {
    const lines = String(message ?? '').split('\n').map(l => `<p>${esc(l)}</p>`).join('');
    const el = h(`<div class="ask-layer" role="alertdialog" aria-modal="true" aria-label="${esc(title)}"><div class="ask-card${alarm ? ' alarm' : ''}">
      <h3>${alarm ? icon('flame', 18) : ''}${esc(title)}</h3><div class="ask-body">${lines}</div>
      <div class="ask-act"><button class="btn" data-ask="0">${esc(cancel)}</button><button class="btn ${danger || alarm ? 'danger' : 'primary'}" data-ask="1">${esc(ok)}</button></div></div></div>`);
    const done = v => { el.remove(); document.removeEventListener('keydown', key, true); resolve(v); };
    const key = e => { if (e.key === 'Escape') { e.stopPropagation(); done(false); } if (e.key === 'Enter') { e.preventDefault(); done(!document.activeElement?.closest?.('[data-ask="0"]')); } };
    el.addEventListener('click', e => { const b = e.target.closest('[data-ask]'); if (b) done(b.dataset.ask === '1'); else if (e.target === el) done(false); });
    document.addEventListener('keydown', key, true);
    document.body.append(el);
    setTimeout(() => focusIn(el.querySelector('[data-ask="1"]')), 20);
  });
}

let modalY = null, modalHash = '';
function lockPage() {
  if (!document.body.classList.contains('has-modal')) { modalY = window.scrollY; modalHash = location.hash; }
  document.body.classList.add('has-modal');
}
function unlockPage() {
  document.body.classList.remove('has-modal');
  const y = modalY; modalY = null;
  if (y == null || location.hash !== modalHash) return;
  const fix = () => { if (location.hash === modalHash && Math.abs(window.scrollY - y) > 2) window.scrollTo(0, y); };
  requestAnimationFrame(fix); setTimeout(fix, 250); setTimeout(fix, 700);
}
export function scrollAfterModal(y, force = false) { if (modalY != null) modalY = y; else if (window.scrollY < y - 2 || (force && Math.abs(window.scrollY - y) > 2)) window.scrollTo(0, y); }
const focusIn = (el) => { try { el?.focus({ preventScroll: true }); } catch { el?.focus(); } };
export function openModal({ title, body, wide = false, onClose, sticky = false } = {}) {
  closeModal();
  const el = h(`<div class="modal-backdrop" id="modal"><div class="modal ${wide ? 'modal-wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header class="modal-head"><h2>${esc(title)}</h2><button class="icon-btn" data-close aria-label="닫기">${icon('close')}</button></header>
    <div class="modal-body"></div></div></div>`);
  const content = typeof body === 'string' ? h(`<div>${body}</div>`) : body;
  $('.modal-body', el).append(content);
  let downOn = null; el.addEventListener('pointerdown', e => { downOn = e.target; });
  el.addEventListener('click', e => { if ((!sticky && e.target === el && downOn === el) || e.target.closest('[data-close]')) closeModal(); });
  document.addEventListener('keydown', escClose);
  el._onClose = onClose;
  document.body.append(el);
  lockPage();
  setTimeout(() => focusIn($('.modal button, .modal input', el)), 30);
  return el;
}
function escClose(e) { if (e.key === 'Escape') closeModal(); }

export function openLayer({ title, body, wide = false } = {}) {
  const el = h(`<div class="modal-backdrop layer"><div class="modal ${wide ? 'modal-wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header class="modal-head"><h2>${esc(title)}</h2><button class="icon-btn" data-close aria-label="닫기">${icon('close')}</button></header>
    <div class="modal-body"></div></div></div>`);
  $('.modal-body', el).append(typeof body === 'string' ? h(`<div>${body}</div>`) : body);
  const key = e => { if (e.key === 'Escape' && $$('.modal-backdrop.layer').pop() === el) { e.stopImmediatePropagation(); close(); } };
  const close = () => {
    document.removeEventListener('keydown', key, true); el.remove();
    if (!$('#modal') && !$('.modal-backdrop.layer')) unlockPage();
  };
  let downOn = null; el.addEventListener('pointerdown', e => { downOn = e.target; });
  el.addEventListener('click', e => { if ((e.target === el && downOn === el) || e.target.closest('[data-close]') && e.target.closest('.modal-backdrop') === el) close(); });
  document.addEventListener('keydown', key, true);
  el.close = close;
  document.body.append(el);
  lockPage();
  setTimeout(() => focusIn($('.modal-head button', el)), 30);
  return el;
}
export const closeLayers = () => $$('.modal-backdrop.layer').forEach(l => l.close?.());
export function closeModal() {
  const el = $('#modal'); if (!el) return;
  document.removeEventListener('keydown', escClose);
  el._onClose?.();
  el.remove();
  if (!$('.modal-backdrop.layer')) unlockPage();
}

export function bar(value, max = 100, kind = '') {
  const pct = Math.max(0, Math.min(100, (Number(value) || 0) / (max || 1) * 100));
  return `<div class="bar ${kind}" role="progressbar" aria-valuenow="${Math.round(value || 0)}" aria-valuemax="${max}"><span style="width:${pct}%"></span></div>`;
}
export function empty(text, iconName = 'moon') {
  return `<div class="empty">${icon(iconName, 22)}<p>${esc(text)}</p></div>`;
}
export function segmented(id, items, active) {
  const withIco = items.some(x => x[2]);
  return `<div class="segmented ${withIco ? 'with-ico' : ''}" role="tablist" data-seg="${id}" style="--n:${items.length}">${items.map(([key, label, ic]) =>
    `<button role="tab" data-key="${key}" class="${key === active ? 'on' : ''}" aria-selected="${key === active}" title="${esc(label)}">${ic ? icon(ic, 17) : ''}<span>${esc(label)}</span></button>`).join('')}</div>`;
}
export function bindSegmented(root, id, onChange) {
  const seg = $(`[data-seg="${id}"]`, root); if (!seg) return;
  seg.addEventListener('click', e => {
    const b = e.target.closest('button[data-key]'); if (!b) return;
    $$('button', seg).forEach(x => { x.classList.toggle('on', x === b); x.setAttribute('aria-selected', x === b); });
    onChange(b.dataset.key);
  });
}

export const EMBLEMS = {
  moon: ['달', 'M17 4a8 8 0 1 0 3 13 7 7 0 0 1-3-13z'],
  lantern: ['등롱', 'M9 3h6M10 3v2M14 3v2M7 7h10l-1 10H8L7 7zM9 17v3h6v-3M12 10v4'],
  seal: ['인장', 'M5 5h14v14H5zM9 9h6M9 12h6M9 15h3'],
  bell: ['방울', 'M12 3a6 6 0 0 0-6 6v4l-2 3h16l-2-3V9a6 6 0 0 0-6-6zM10 19a2 2 0 0 0 4 0'],
  lotus: ['연꽃', 'M12 20c-4 0-8-3-8-7 3 0 5 1 8 4 3-3 5-4 8-4 0 4-4 7-8 7zM12 17c-2-3-2-8 0-12 2 4 2 9 0 12z'],
  blade: ['검', 'M14 3l7 0 0 7-10 10-4-4zM5 15l4 4M3 21l3-3'],
  crane: ['학', 'M4 18c4-1 7-4 8-9 1 3 4 5 8 5-3 2-7 3-10 2M12 9l2-5 2 3'],
  flame: ['불꽃', 'M12 21c4 0 7-3 7-7 0-5-5-7-5-11-3 2-5 5-5 8-1-1-2-2-2-4-2 2-2 5-2 7 0 4 3 7 7 7z'],
  wave: ['물결', 'M3 9c3-3 6 3 9 0s6 3 9 0M3 15c3-3 6 3 9 0s6 3 9 0'],
  mountain: ['산', 'M3 19l6-10 4 6 3-4 5 8z'],
  star: ['별', 'M12 3l2.6 6 6.4.6-4.8 4.2 1.4 6.2L12 17l-5.6 3 1.4-6.2L3 9.6 9.4 9z'],
  eye: ['눈', 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zM12 15a3 3 0 1 0 0-6 3 3 0 0 0 0 6z'],
};
export const EMBLEM_COLORS = {
  vermilion: ['주홍', '#d2553a'], gold: ['금빛', '#d1a65a'], jade: ['비취', '#3fae8a'], indigo: ['쪽빛', '#5a74d6'], violet: ['자주', '#9b5cd6'],
  ash: ['잿빛', '#8d8f96'], crimson: ['진홍', '#c8344c'], teal: ['청록', '#2fa3a3'], amber: ['호박', '#e0902c'], ivory: ['상아', '#d9cfb8'],
};
export function profileOf(ownerId, profile) {
  const e = Object.keys(EMBLEMS), c = Object.keys(EMBLEM_COLORS);
  const h = [...String(ownerId || '')].reduce((a, ch) => a + ch.charCodeAt(0), 0);
  return { emblem: EMBLEMS[profile?.emblem] ? profile.emblem : e[h % e.length], color: EMBLEM_COLORS[profile?.color] ? profile.color : c[(h * 7) % c.length], bio: profile?.bio || '' };
}
export function emblem(ownerId, profile, size = 40) {
  const fr = profile?.frame;
  return fr ? framed(emblemBase(ownerId, profile, framedInner(fr, size)), fr, size) : emblemBase(ownerId, profile, size);
}
function emblemBase(ownerId, profile, size) {
  const p = profileOf(ownerId, profile), col = EMBLEM_COLORS[p.color][1];
  if (typeof profile?.avatar === 'string' && /^data:image\/(webp|jpeg|png);base64,/.test(profile.avatar))
    return `<span class="emblem photo${profile.avatar_px ? ' px' : ''}" style="--em:${col};width:${size}px;height:${size}px" aria-hidden="true"><img src="${profile.avatar}" alt="" width="${size}" height="${size}"></span>`;
  return `<span class="emblem" style="--em:${col};width:${size}px;height:${size}px" aria-hidden="true"><svg viewBox="0 0 24 24" width="${Math.round(size * 0.58)}" height="${Math.round(size * 0.58)}" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="${EMBLEMS[p.emblem][1]}"/></svg></span>`;
}
export const LEVEL_CAP = GAMEDATA.level?.cap || 45;
export const xpNeed = lv => 100 * Math.max(1, lv || 1) + 12 * Math.max(1, lv || 1) ** 2;
export const xpPct = () => Math.max(0, Math.min(100, Number(store.hud?.xp_pct ?? 100)));
export const xpGot = x => Math.round((Number(x) || 0) * xpPct() / 100);
export const xpNote = () => xpPct() < 100 ? `성장 조절 ${xpPct()}% — 최근 활동한 조사원 평균보다 많이 앞서 있어 얻는 경험치가 줄어듭니다. 평균이 따라오면 저절로 풀립니다.` : '';
export function bagLimit(c) { return (c?.bag_capacity || 34) + (c?.major_faction_id === 'river_alliance' ? 6 : 0); }
const STACK_KEY = 'yh-stacks-v3', STACK_VER = 'yh-stacks-ver';
let stacks = null, cats = null, wtypes = null;
(() => { try { const o = JSON.parse(localStorage.getItem(STACK_KEY) || 'null'); if (o) { const e = Object.entries(o); stacks = new Map(e.map(([k, v]) => [k, v[0]])); cats = new Map(e.map(([k, v]) => [k, v[1]])); wtypes = new Map(e.filter(([, v]) => v[2]).map(([k, v]) => [k, v[2]])); } } catch {} })();
let stacksP = null, stacksFresh = false;
function loadStacks() { return stacksP ||= readStacks(); }
async function readStacks() {
  try {
    const v = await dbVersion();
    let saved = null; try { saved = localStorage.getItem(STACK_VER); } catch {}
    if (v && stacks?.size && wtypes && saved === v) { stacksFresh = true; return; }
    const { data, error } = await db.from('world_item_catalog').select('item_id,stack_size,category,wt:equipment_traits->>weapon_type');
    if (error || !data?.length) throw new Error(error?.message || 'empty');
    stacks = new Map(data.map(r => [r.item_id, Math.max(1, Number(r.stack_size) || 1)]));
    cats = new Map(data.map(r => [r.item_id, r.category || ''])); wtypes = new Map(data.filter(r => r.wt).map(r => [r.item_id, r.wt])); stacksFresh = true;
    try { localStorage.setItem(STACK_KEY, JSON.stringify(Object.fromEntries(data.map(r => [r.item_id, [stacks.get(r.item_id), r.category || '', r.wt || '']])))); if (v) localStorage.setItem(STACK_VER, v); } catch {}
  } catch { stacksP = null; }
}
export const stackOf = id => stacks?.get(id) || 1;
export const catOf = id => cats?.get(id) || '';
export const kindChip = (id, cat) => { const c = cat || catOf(id); return c ? `<span class="kind-chip k-${esc(c)}">${esc(nameOf(c))}</span>` : ''; };
let equipped = null, weaponStyle = 'melee';
async function loadEquipped() {
  try {
    const { data } = await db.from('world_character_equipment').select('item_id,slot').eq('owner_id', store.user.id); equipped = (data || []).map(r => r.item_id);
    const w = (data || []).find(r => r.slot === 'weapon');
    weaponStyle = 'melee';
    if (w) {
      if (!stacksFresh) await loadStacks();
      if (wtypes) weaponStyle = wtypes.get(w.item_id) || 'melee';
      else { const { data: it } = await db.from('world_item_catalog').select('equipment_traits').eq('item_id', w.item_id).maybeSingle(); weaponStyle = it?.equipment_traits?.weapon_type || 'melee'; }
    }
  } catch { equipped = null; }
}
export function spOf() { return weaponStyle === 'melee' ? ['기력', 'ki'] : ['영력', 'sp']; }
export function brief(t, n = 42) { const s = String(t || '').split(/(?<=[.!?。])\s|\n/)[0].trim(); return s.length > n ? `${s.slice(0, n - 1)}…` : s; }
export const rarTag = r => `<span class="rar-tag r-${esc(r || 'common')}">${esc(nameOf(r || 'common'))}</span>`;
export function equippedIds() { return equipped || []; }
export function forgetEquipped() { equipped = null; }
export function bagUsed(c) {
  const inv = c?.inventory || {}, eq = (equipped || []).filter(id => Number(inv[id]) > 0).length;
  return Object.entries(inv).reduce((a, [id, n]) => a + Math.ceil(Math.max(0, Number(n) || 0) / stackOf(id)), 0) - eq;
}
