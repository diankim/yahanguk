// 야행국 공통 계층: Supabase 연결, RPC 호출, 상태 저장소, 이름 사전, UI 도우미.
import { framed, framedInner } from './cosmetics.js';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2.57.0';

import { SUPABASE_URL, SUPABASE_KEY, isMaintenanceError, goMaintenance } from './config.js';
export { SUPABASE_URL, SUPABASE_KEY };
export const db = createClient(SUPABASE_URL, SUPABASE_KEY, {
  auth: { persistSession: true, autoRefreshToken: true, detectSessionInUrl: true },
});

/* ── 이벤트 버스 ─────────────────────────────────────────── */
const listeners = new Map();
export function on(evt, fn) { (listeners.get(evt) || listeners.set(evt, new Set()).get(evt)).add(fn); return () => listeners.get(evt)?.delete(fn); }
export function emit(evt, data) { listeners.get(evt)?.forEach(fn => { try { fn(data); } catch (e) { console.error(e); } }); }

/* ── 상태 저장소 ─────────────────────────────────────────── */
export const store = { user: null, character: null, snaps: {} };

/* ── 오류 문구 ───────────────────────────────────────────── */
export function friendlyError(e) {
  const msg = String(e?.message || e || '알 수 없는 오류');
  // 점검 중에는 서버가 데이터 영역을 닫는다. 그 응답을 받으면 점검 페이지로 옮긴다.
  if (isMaintenanceError(msg)) { goMaintenance(); return '서버 점검 중입니다.'; }
  if (/Auth session missing|JWT|not authenticated/i.test(msg)) return '로그인이 필요합니다.';
  if (/permission denied/i.test(msg)) return '이 작업을 할 권한이 없습니다.';
  if (/Failed to fetch|NetworkError|Load failed/i.test(msg)) return '서버에 연결할 수 없습니다. 네트워크를 확인하세요.';
  if (/Invalid login credentials/i.test(msg)) return '아이디 또는 비밀번호가 올바르지 않습니다.';
  if (/Email not confirmed/i.test(msg)) return '이메일 인증을 완료한 뒤 로그인하세요.';
  if (/User already registered|already been registered/i.test(msg)) return '이미 쓰이는 아이디입니다. 다른 아이디를 정하세요.';
  if (/Email signups are disabled|Signups not allowed/i.test(msg)) return '지금은 가입을 받지 않습니다. 관리자에게 Supabase의 Email 로그인 설정을 확인해 달라고 알려 주세요.';
  if (/Email address .* is invalid|invalid format/i.test(msg)) return '아이디는 영문 소문자와 숫자 4~16자로 정하세요.';
  if (/Password should be at least/i.test(msg)) return '비밀번호는 6자 이상이어야 합니다.';
  return msg;
}

/* ── RPC ─────────────────────────────────────────────────── */
// 조회(snapshot)는 캐시에 저장하고, 행동 RPC가 성공하면 'changed' 이벤트로 관련 화면이 다시 불러온다.
export async function rpc(name, args) {
  const { data, error } = args === undefined ? await db.rpc(name) : await db.rpc(name, args);
  if (error) throw new Error(friendlyError(error));
  return data;
}
export async function snap(name, args) {
  const data = await rpc(name, args);
  store.snaps[name] = data;
  return data;
}
// 전투 도중 한 턴(끝나지 않은 공격·방어)은 캐릭터만 다시 읽고, 상태판·알림 같은 다른 화면은 다시 읽지 않는다(서버 부담).
export const midBattle = ({ name, data }) => name === 'world_battle_action' && !data?.ended;
// 같은 일을 짧은 간격으로 여러 번 부르면 한 번만: 처음 부른 뒤 gap 안의 요청은 gap이 끝날 때 한 번으로 묶는다.
export function throttle(fn, gap) {
  let last = 0, t = null;
  return () => { const wait = last + gap - Date.now(); if (wait <= 0) { last = Date.now(); fn(); } else if (!t) t = setTimeout(() => { t = null; last = Date.now(); fn(); }, wait); };
}
// 행동 뒤에는 캐릭터를 먼저 다시 읽어 화면이 바로 새 값을 그리게 한다.
export async function act(name, args) {
  const data = await rpc(name, args);
  if (/equip/.test(name)) equipped = null; // 장착이 바뀌면 다음 읽기에서 장착 목록도 다시 읽는다
  try { await loadCharacter(); } catch {}
  emit('changed', { name, data });
  return data;
}
export async function loadCharacter() {
  if (!store.user) return null;
  const [, { data, error }] = await Promise.all([stacks ? null : loadStacks(), db.from('world_characters').select('*').eq('owner_id', store.user.id).maybeSingle(),
    equipped ? null : loadEquipped()]);
  if (error) throw new Error(friendlyError(error));
  store.character = data;
  emit('character', data);
  return data;
}

/* ── 이름 사전 (내부 코드를 화면에 그대로 노출하지 않는다) ───────────── */
export const JOBS = {
  exorcist: { name: '퇴마관', trait: '부적 제압', desc: '공격 시 영성 보정이 강화되고, 요괴를 토벌하면 영력을 추가로 회복합니다.' },
  scout: { name: '현장 조사원', trait: '흔적 추적', desc: '탐사·채집에서 감각 보정을 얻고 희귀 재료 발견에 유리합니다.' },
  medic: { name: '의무관', trait: '응급 처치', desc: '약초 회복 효과가 강화되고 체질이 높아 생존에 유리합니다.' },
  sealmaster: { name: '봉인술사', trait: '결계 유지', desc: '의지가 강해 반격 피해와 정신 교란에 잘 버팁니다.' },
  analyst: { name: '기록 분석관', trait: '패턴 해독', desc: '감각이 예리해 전투에서 치명타를 노리고 사건 조사에 유리합니다.' },
  artificer: { name: '법구 제작사', trait: '정밀 가공', desc: '근력이 강하고 장비 제작·채집에 특화되어 있습니다.' },
};
export const FACTIONS = {
  headquarters: { name: '본부 직속', trait: '본부 보급', desc: '본부의 제작·정비 활동에 익숙하고 보급을 안정적으로 받습니다.' },
  fieldbureau: { name: '현장대응국', trait: '현장 적응', desc: '외부 현장 임무를 중심으로 성장합니다.' },
  archivebureau: { name: '기록감찰국', trait: '사건 기록', desc: '단서와 사건 기록을 다루는 조사 임무에 특화됩니다.' },
  sealbureau: { name: '봉인관리국', trait: '봉인 규정', desc: '봉인과 요괴 대응 절차에 특화되어 정신 소모에 강합니다.' },
  medicalbureau: { name: '의무지원국', trait: '후방 지원', desc: '회복과 생존 지원 임무에 특화됩니다.' },
  independent: { name: '외부 협력자', trait: '자유 행동', desc: '정규 부서의 제약이 적고 다양한 현장과 협력합니다.' },
};
const FIXED = {
  // 생활 전문화
  fieldwork: '현장 채집', mining: '채광', botany: '약초학', spirit_harvest: '영기 채취', fishing: '수렵·어로',
  general: '종합 제작', smithing: '단조', carpentry: '목공', alchemy: '연금', sealing: '봉인 공예', weaving: '직조', leatherwork: '가죽 공예', artifice: '법구 공예',
  // 기술 계열
  melee: '근접', ranged: '원거리', analysis: '분석', first_aid: '응급 처치', guarding: '방어', herbalism: '약초', spirit_gathering: '영기 채집', wardcraft: '결계 각인', tracking: '추적', foraging: '채취',
  // 분류
  tool: '도구', weapon: '무기', armor: '방어구', hat: '관모', shoes: '신', norigae: '노리개', amulet: '호신부', mask: '탈', accessory: '장신구', consumable: '소모품', material: '재료', craft_material: '제작 재료', quest: '임무 물품', trade_goods: '교역품', mount: '탈것', equipment: '장비',
  common: '범품', uncommon: '양품', rare: '진품', epic: '명품', legendary: '신품',
  // 지역 유형
  abyss: '심연', archive: '서고', blood_forest: '혈림', bridge: '다리', burial_ground: '묘역', canyon: '협곡', celestial_tower: '천문탑', coast: '해안', desert: '사막',
  faction_stronghold: '세력 거점', forest: '숲', frontier_gate: '변경 관문', haunted_garden: '흉가 정원', headquarters: '본부', ice_valley: '빙곡', islands: '군도', lake: '호수',
  lost_city: '잊힌 도시', market: '시장', mine: '광산', monastery: '사원', mountain_pass: '고갯길', mountain_peak: '산정', observatory: '관측소', pavilion: '정자',
  rift: '균열', river_port: '나루', ruined_temple: '폐사원', ruins: '폐허', safe_zone: '안전 지대', sealed_shrine: '봉인 사당', swamp: '늪', training: '수련장',
  underground: '지하', underwater_ruins: '수중 유적', underworld_market: '귀시', village: '마을', wilderness: '황야',
  // 요괴 습성
  ambush: '매복', toxic: '독성', venom: '맹독', spectral: '영체', warded: '결계', seal_breaker: '봉인 파괴', tide: '수계', swarm: '떼',
  armored: '장갑', reflect: '반사', aerial: '비행', boss: '우두머리',
  // 원정 태세
  cautious: '신중', balanced: '균형', bold: '강행',
  // 지점 유형
  supply: '보급', relic: '유적', medical: '의료', combat: '전투', hidden: '은신처',
  // 능력치
  strength: '근력', agility: '민첩', vitality: '체질', perception: '감각', willpower: '의지', spirit_affinity: '영성',
  // 효과
  gather_qty_pct: '채집량', rare_loot_pct: '희귀품 발견', craft_quality: '제작 품질', combat_damage_pct: '주는 피해', incoming_damage_pct: '받는 피해',
  travel_time_pct: '이동 시간', clue_bonus_pct: '단서 발견', healing_pct: '회복량', erosion_pct: '침식 위험', melee_pct: '근접 피해', ranged_pct: '원거리 피해',
  magic_pct: '술법 피해', encounter_pct: '요괴 조우', mental_per_action: '행동마다 정신', health_per_action: '행동마다 체력', training_xp_pct: '수련 경험치',
  action_quality_pct: '행동 효율', agility_pct: '민첩', gathering_bonus_pct: '채집량', damage_reduction_pct: '피해 감소', defense: '방어', power: '위력',
  fish_bite_pct: '낚시 입질', fish_rare_pct: '희귀 어종', fish_size_pct: '물고기 크기',
  presence: '이목', crit_pct: '치명타', evasion_pct: '회피', flee_pct: '달아나기', mental_loss_pct: '정신 손실',
  // 서식지
  river: '강', marsh: '늪', sea: '바다', lake: '호수', deep: '깊은 물', canal: '수로', abyss: '심연', fishing: '낚시', cooking: '요리',
  // 날씨·시간대
  dawn: '해돋이', noon: '한낮', dusk: '땅거미', night: '삼경', clear: '청명', cloudy: '담운', rain: '장우', fog: '농무', wind: '삭풍', snow: '설한', bloodmist: '혈무',
};
// 효과 수치를 "채집량 +5%"처럼 읽기 쉬운 문장으로 바꾼다. 값이 클수록 나쁜 효과는 부호를 그대로 보여 준다.
const FLAT = new Set(['craft_quality', 'defense', 'power', 'presence', 'mental_per_action', 'health_per_action']);
const PER_ACTION = new Set(['mental_per_action', 'health_per_action']);
export function effectText(effects, potency = 1) {
  return Object.entries(effects || {}).filter(([k, v]) => k !== 'trait' && k !== 'weapon_type' && Number(v)).map(([k, v]) => {
    const n = Math.round(Number(v) * (potency || 1) * 10) / 10;
    if (PER_ACTION.has(k)) return `${FIXED[k]} -${Math.abs(n)}`;
    return `${FIXED[k] || '기타 효과'} ${n > 0 ? '+' : ''}${n}${FLAT.has(k) ? '' : '%'}`;
  });
}
// 효과가 이로운지(받는 피해·이동 시간·침식은 줄어야 좋다)
const LOWER_BETTER = new Set(['incoming_damage_pct', 'travel_time_pct', 'erosion_pct', 'mental_loss_pct', 'mental_per_action', 'health_per_action']);
export function effectGood(k, v) { return LOWER_BETTER.has(k) ? Number(v) < 0 : Number(v) > 0; }
const names = new Map(Object.entries(FIXED));
export function registerNames(entries) { for (const [k, v] of entries) if (k && v) names.set(k, v); }
export function namesDump() { return [...names]; }
export function nameOf(code) {
  if (code == null) return '';
  if (JOBS[code]) return JOBS[code].name;
  if (FACTIONS[code]) return FACTIONS[code].name;
  // 사전에 없는 영문 코드는 화면에 그대로 내보이지 않는다.
  return names.get(code) || (/^[a-z0-9_]+$/i.test(String(code)) ? '이름 미상' : String(code));
}

/* ── 포맷 ────────────────────────────────────────────────── */
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

/* ── 아이콘 (선형 SVG, 장식용 이모지 대신 사용) ───────────────────── */
const ICONS = {
  home: 'M3 11l9-7 9 7v9a1 1 0 01-1 1h-5v-6H9v6H4a1 1 0 01-1-1z',
  map: 'M9 4L3 6v14l6-2 6 2 6-2V4l-6 2-6-2zM9 4v14M15 6v14',
  user: 'M12 12a4 4 0 100-8 4 4 0 000 8zM4 21a8 8 0 0116 0',
  bag: 'M6 8h12l-1 12H7L6 8zM9 8V6a3 3 0 016 0v2',
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
  plus: 'M12 5v14M5 12h14', minus: 'M5 12h14', target: 'M12 21a9 9 0 100-18 9 9 0 000 18zM12 16a4 4 0 100-8 4 4 0 000 8zM12 12h.01',
  close: 'M6 6l12 12M18 6L6 18', check: 'M5 12l5 5L20 7', chevron: 'M9 6l6 6-6 6', back: 'M15 6l-6 6 6 6',
  search: 'M11 18a7 7 0 100-14 7 7 0 000 14zM20 20l-4-4', flame: 'M12 22c4 0 7-3 7-7 0-5-5-7-5-12-3 2-5 5-5 8-1-1-2-2-2-4-2 2-2 5-2 8 0 4 3 7 7 7z',
  moon: 'M20 14A8 8 0 1110 4a7 7 0 0010 10z', users: 'M9 11a4 4 0 100-8 4 4 0 000 8zM2 21a7 7 0 0114 0M17 11a3 3 0 000-6M22 21a6 6 0 00-4-5.7',
  shop: 'M4 9l1-5h14l1 5M4 9h16v11H4zM4 9c0 2 2 3 4 3s4-1 4-3c0 2 2 3 4 3s4-1 4-3M10 20v-5h4v5',
  heart: 'M12 20s-8-5-8-11a4.5 4.5 0 018-2.8A4.5 4.5 0 0120 9c0 6-8 11-8 11z', eye: 'M2 12s4-7 10-7 10 7 10 7-4 7-10 7-10-7-10-7zM12 15a3 3 0 100-6 3 3 0 000 6z',
  spark: 'M12 3v4M12 17v4M3 12h4M17 12h4M6 6l2.5 2.5M15.5 15.5L18 18M6 18l2.5-2.5M15.5 8.5L18 6',
  shield: 'M12 3l8 3v6c0 5-3.5 8-8 9-4.5-1-8-4-8-9V6z', volume: 'M4 9h4l5-4v14l-5-4H4zM17 8a5 5 0 010 8',
  refresh: 'M20 12a8 8 0 11-2.3-5.7M20 4v5h-5',
  sun: 'M12 16a4 4 0 100-8 4 4 0 000 8zM12 2v2M12 20v2M4.9 4.9l1.4 1.4M17.7 17.7l1.4 1.4M2 12h2M20 12h2M4.9 19.1l1.4-1.4M17.7 6.3l1.4-1.4',
  cloud: 'M7 18h10a4 4 0 000-8 6 6 0 00-11.5 1.5A3.5 3.5 0 007 18z',
  rain: 'M7 14h10a4 4 0 000-8 6 6 0 00-11.5 1.5A3.5 3.5 0 007 14zM8 17l-1 3M12 17l-1 3M16 17l-1 3',
  fog: 'M4 9h16M3 13h18M5 17h14M7 5h10',
  wind: 'M3 8h11a3 3 0 10-3-3M3 12h15a3 3 0 11-3 3M3 16h8',
  snow: 'M12 2v20M4 7l16 10M20 7L4 17M9 4l3 2 3-2M9 20l3-2 3 2',
  mist: 'M12 3c3 4 6 7 6 11a6 6 0 01-12 0c0-4 3-7 6-11zM9 15h6',
  dawn: 'M4 18h16M7 18a5 5 0 0110 0M12 7v3M5.6 11.6l1.4 1.4M18.4 11.6L17 13M2 22h20',
  // 장착 칸: 관모(갓)·신·노리개·호신부(부적)·탈
  hat: 'M3 16h18M8 16V9a4 4 0 018 0v7M6 19h12', shoe: 'M4 7v9h16v-2c0-2-2-3-5-3l-3-4H4zM4 19h16',
  knot: 'M12 3a3 3 0 100 6 3 3 0 000-6zM12 9v3M9 12h6M10 12l-2 9M12 12v9M14 12l2 9', talisman: 'M7 3h10v18H7zM10 7h4M10 11h4M10 15h4',
  mask: 'M5 5c4-1 10-1 14 0 0 8-3 14-7 14S5 13 5 5zM8 10h3M13 10h3M10 15h4',
  letter: 'M3 6h18v12H3zM3 7l9 6 9-6', flag: 'M5 21V4M5 4h12l-2.5 4L17 12H5',
  wrench: 'M14.7 6.3a4 4 0 00-5.4 5.4L3 18l3 3 6.3-6.3a4 4 0 005.4-5.4l-2.6 2.6-2.4-.6-.6-2.4z',
};
export const ENV_ICON = { dawn: 'dawn', noon: 'sun', dusk: 'moon', night: 'moon', clear: 'sun', cloudy: 'cloud', rain: 'rain', fog: 'fog', wind: 'wind', snow: 'snow', bloodmist: 'mist' };
export function icon(name, size = 18) {
  const p = ICONS[name] || ICONS.spark;
  return `<svg class="ico" width="${size}" height="${size}" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="1.7" stroke-linecap="round" stroke-linejoin="round" aria-hidden="true"><path d="${p}"/></svg>`;
}

/* ── DOM 도우미 ──────────────────────────────────────────── */
export const $ = (sel, root = document) => root.querySelector(sel);
export const $$ = (sel, root = document) => [...root.querySelectorAll(sel)];
// 받침에 맞는 조사: "생선구이을(를)" → "생선구이를", "백지교(으)로" → "백지교로". 서버 문구도 화면에 나갈 때 여기서 고른다.
// 앞 글자가 한글이면 받침으로, 숫자면 읽는 소리로, 영문이면 끝소리로 정하고, 알 수 없으면 원래 표기를 둔다.
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
  if (/cm$/i.test(str.slice(0, i + 1))) return { has: false, rieul: false }; // 센티미터
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
// 낱말 뒤에 붙일 조사만: particle('백지교', '(으)로') → '로'
export const particle = (word, form) => josa(String(word ?? '') + form).slice(String(word ?? '').length);
export function esc(s) { return josa(s).replace(/[&<>"']/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;', "'": '&#39;' }[c])); }
export function h(html) { const t = document.createElement('template'); t.innerHTML = html.trim(); return t.content.firstElementChild; }

/* ── 토스트 ──────────────────────────────────────────────── */
export function toast(message, kind = 'info') {
  const box = $('#toasts'); if (!box) return;
  const el = h(`<div class="toast toast-${kind}" role="status">${esc(message)}</div>`);
  if (kind === 'error') window.dispatchEvent(new CustomEvent('yh-sfx', { detail: 'error' }));
  box.append(el);
  setTimeout(() => { el.classList.add('out'); setTimeout(() => el.remove(), 300); }, kind === 'error' ? 4200 : 2800);
}

/* ── 중복 실행 방지 행동 버튼 ─────────────────────────────── */
// 같은 버튼을 여러 번 눌러도 요청은 한 번만 보낸다. 서버 측 중복 방지와 별개로 UX 보호용이다.
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

/* ── 모달·시트 ───────────────────────────────────────────── */
// 운영진(GM) 표식: 서버 명단(world_staff)에 있는 캐릭터만. 이름에 GM을 넣어도 붙지 않는다.
store.staff = new Set();
export async function loadStaff() {
  try { const { data, error } = await db.from('world_staff').select('owner_id'); if (!error) store.staff = new Set((data || []).map(r => r.owner_id)); } catch {}
  return store.staff;
}
export const isGM = id => !!id && store.staff.has(id);
export const gmBadge = id => isGM(id) ? '<span class="gm-badge" title="운영진(GM)">GM</span>' : '';

// 게임 안 확인 팝업(브라우저 confirm 대신). 열린 창 위에 겹쳐 뜨고, 고르면 true/false로 끝난다.
// ask('도망칠까요?', { title: '도주', ok: '도망치기', danger: true })
export function ask(message, { title = '확인', ok = '확인', cancel = '그만두기', danger = false } = {}) {
  return new Promise(resolve => {
    const lines = String(message ?? '').split('\n').map(l => `<p>${esc(l)}</p>`).join('');
    const el = h(`<div class="ask-layer" role="alertdialog" aria-modal="true" aria-label="${esc(title)}"><div class="ask-card">
      <h3>${esc(title)}</h3><div class="ask-body">${lines}</div>
      <div class="ask-act"><button class="btn" data-ask="0">${esc(cancel)}</button><button class="btn ${danger ? 'danger' : 'primary'}" data-ask="1">${esc(ok)}</button></div></div></div>`);
    const done = v => { el.remove(); document.removeEventListener('keydown', key, true); resolve(v); };
    const key = e => { if (e.key === 'Escape') { e.stopPropagation(); done(false); } if (e.key === 'Enter') { e.preventDefault(); done(true); } };
    el.addEventListener('click', e => { const b = e.target.closest('[data-ask]'); if (b) done(b.dataset.ask === '1'); else if (e.target === el) done(false); });
    document.addEventListener('keydown', key, true);
    document.body.append(el);
    setTimeout(() => el.querySelector('[data-ask="1"]')?.focus(), 20);
  });
}

export function openModal({ title, body, wide = false, onClose } = {}) {
  closeModal();
  const el = h(`<div class="modal-backdrop" id="modal"><div class="modal ${wide ? 'modal-wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header class="modal-head"><h2>${esc(title)}</h2><button class="icon-btn" data-close aria-label="닫기">${icon('close')}</button></header>
    <div class="modal-body"></div></div></div>`);
  const content = typeof body === 'string' ? h(`<div>${body}</div>`) : body;
  $('.modal-body', el).append(content);
  el.addEventListener('click', e => { if (e.target === el || e.target.closest('[data-close]')) closeModal(); });
  document.addEventListener('keydown', escClose);
  el._onClose = onClose;
  document.body.append(el);
  document.body.classList.add('has-modal');
  setTimeout(() => $('.modal button, .modal input', el)?.focus(), 30);
  return el;
}
function escClose(e) { if (e.key === 'Escape') closeModal(); }

// 겹쳐 뜨는 창: 상점 같은 창 위에 물품 정보·조사원 카드를 띄우고, 닫으면 아래 창은 그대로 남는다.
export function openLayer({ title, body, wide = false } = {}) {
  const el = h(`<div class="modal-backdrop layer"><div class="modal ${wide ? 'modal-wide' : ''}" role="dialog" aria-modal="true" aria-label="${esc(title)}">
    <header class="modal-head"><h2>${esc(title)}</h2><button class="icon-btn" data-close aria-label="닫기">${icon('close')}</button></header>
    <div class="modal-body"></div></div></div>`);
  $('.modal-body', el).append(typeof body === 'string' ? h(`<div>${body}</div>`) : body);
  const key = e => { if (e.key === 'Escape' && $$('.modal-backdrop.layer').pop() === el) { e.stopImmediatePropagation(); close(); } };
  const close = () => {
    document.removeEventListener('keydown', key, true); el.remove();
    if (!$('#modal') && !$('.modal-backdrop.layer')) document.body.classList.remove('has-modal');
  };
  el.addEventListener('click', e => { if (e.target === el || e.target.closest('[data-close]') && e.target.closest('.modal-backdrop') === el) close(); });
  document.addEventListener('keydown', key, true);
  el.close = close;
  document.body.append(el);
  document.body.classList.add('has-modal');
  setTimeout(() => $('.modal-head button', el)?.focus(), 30);
  return el;
}
export const closeLayers = () => $$('.modal-backdrop.layer').forEach(l => l.close?.());
export function closeModal() {
  const el = $('#modal'); if (!el) return;
  document.removeEventListener('keydown', escClose);
  el._onClose?.();
  el.remove();
  if (!$('.modal-backdrop.layer')) document.body.classList.remove('has-modal');
}

/* ── 공통 조각 ───────────────────────────────────────────── */
export function bar(value, max = 100, kind = '') {
  const pct = Math.max(0, Math.min(100, (Number(value) || 0) / (max || 1) * 100));
  return `<div class="bar ${kind}" role="progressbar" aria-valuenow="${Math.round(value || 0)}" aria-valuemax="${max}"><span style="width:${pct}%"></span></div>`;
}
export function empty(text, iconName = 'moon') {
  return `<div class="empty">${icon(iconName, 22)}<p>${esc(text)}</p></div>`;
}
// items: [key, label, icon?] — 아이콘이 있으면 아이콘 위·이름 아래로 쌓는다
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

/* ── 프로필 문장 (선택하지 않으면 캐릭터마다 고정된 무작위 문장) ─────────── */
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
// 서버에 저장한 문장이 없으면 owner_id로 정해지는 고정 문장을 쓴다(누가 봐도 같은 모양).
export function profileOf(ownerId, profile) {
  const e = Object.keys(EMBLEMS), c = Object.keys(EMBLEM_COLORS);
  const h = [...String(ownerId || '')].reduce((a, ch) => a + ch.charCodeAt(0), 0);
  return { emblem: EMBLEMS[profile?.emblem] ? profile.emblem : e[h % e.length], color: EMBLEM_COLORS[profile?.color] ? profile.color : c[(h * 7) % c.length], bio: profile?.bio || '' };
}
// 문장: 사진 또는 고른 문양. 테두리(profile.frame)를 달았으면 둘레에 두른다.
export function emblem(ownerId, profile, size = 40) {
  const fr = profile?.frame;
  return fr ? framed(emblemBase(ownerId, profile, framedInner(fr, size)), fr, size) : emblemBase(ownerId, profile, size);
}
function emblemBase(ownerId, profile, size) {
  const p = profileOf(ownerId, profile), col = EMBLEM_COLORS[p.color][1];
  if (typeof profile?.avatar === 'string' && /^data:image\/(webp|jpeg|png);base64,/.test(profile.avatar))
    return `<span class="emblem photo" style="--em:${col};width:${size}px;height:${size}px" aria-hidden="true"><img src="${profile.avatar}" alt="" width="${size}" height="${size}"></span>`;
  return `<span class="emblem" style="--em:${col};width:${size}px;height:${size}px" aria-hidden="true"><svg viewBox="0 0 24 24" width="${Math.round(size * 0.58)}" height="${Math.round(size * 0.58)}" fill="none" stroke="currentColor" stroke-width="1.6" stroke-linecap="round" stroke-linejoin="round"><path d="${EMBLEMS[p.emblem][1]}"/></svg></span>`;
}
// 다음 레벨까지 경험치(서버 world_xp_need와 같다). 최고 레벨은 30.
export const LEVEL_CAP = 30;
export const xpNeed = lv => 100 * Math.max(1, lv || 1) + 12 * Math.max(1, lv || 1) ** 2;
export function bagLimit(c) { return (c?.bag_capacity || 24) + (c?.major_faction_id === 'river_alliance' ? 6 : 0); }
// 가방 칸: 물품마다 올림(수량 ÷ 묶음 크기)의 합(서버 world_bag_count와 같다). 묶음 크기는 접속할 때 한 번 읽는다.
let stacks = null, stacksP = null;
function loadStacks() { return stacksP ||= readStacks(); } // 동시에 불려도 한 번만 읽는다
async function readStacks() {
  try { const { data, error } = await db.from('world_item_catalog').select('item_id,stack_size'); stacks = error ? new Map() : new Map((data || []).map(r => [r.item_id, Math.max(1, Number(r.stack_size) || 1)])); }
  catch { stacks = new Map(); }
}
export const stackOf = id => stacks?.get(id) || 1;
// 장착한 장비는 가방 칸을 차지하지 않는다(서버 world_bag_limit은 장착한 수만큼 용량을 더하고, 화면은 쓴 칸에서 뺀다)
let equipped = null;
async function loadEquipped() {
  try { const { data } = await db.from('world_character_equipment').select('item_id').eq('owner_id', store.user.id); equipped = (data || []).map(r => r.item_id); }
  catch { equipped = null; }
}
export function bagUsed(c) {
  const inv = c?.inventory || {}, eq = (equipped || []).filter(id => Number(inv[id]) > 0).length;
  return Object.entries(inv).reduce((a, [id, n]) => a + Math.ceil(Math.max(0, Number(n) || 0) / stackOf(id)), 0) - eq;
}
