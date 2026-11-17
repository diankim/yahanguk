import { GAMEDATA as GD } from './gamedata.js';

const PX = GD.partyExp || { flee_hp: 30, threat_pct: 45, bonus_pct: 10, bonus_cap: 3, overlap_min: 10 };

export const EXP_ROUNDS = { 30: 3, 60: 6, 120: 10, 240: 16, 480: 24 };
export function expRoundOf(exp, now = Date.now()) {
  if (!exp?.started_at || !exp?.ends_at) return 0;
  const s = new Date(exp.started_at).getTime(), e = new Date(exp.ends_at).getTime(), total = EXP_ROUNDS[exp.minutes] || 24;
  return Math.max(0, Math.min(total, Math.floor(total * (Math.min(now, e) - s) / (e - s))));
}

const AG = GD.agile || { agi_k: 2, tank_k: 0.5, quiet_k: 0.8, quiet_cap: 50, sneak_base: 25, sneak_k: 0.65, sneak_cap: 75, sneak_min: 10, scout_sneak: 10,
  flee_base: 50, flee_k: 0.5, flee_cap: 95, flee_min: 10, scout_flee: 15, hazard_base: 30, hazard_k: 0.75, hazard_cap: 90, hazard_w_k: 0.05, eva_base: 3, eva_k: 0.175, eva_cap: 40, scout_eva: 6 };
export const agileOf = c => { const n = k => Number(c?.[k]) || 0;
  return Math.max(n('agility') + n('perception'), n('agility') * AG.agi_k, n('willpower') + n('spirit_affinity'), (n('strength') + n('vitality')) * AG.tank_k); };
export const quietPctOf = c => Math.min(AG.quiet_cap, Math.floor(agileOf(c) * AG.quiet_k));
export const AGILE = {
  quietCap: AG.quiet_cap,
  rule: `기민 = 민첩+감각, 민첩×${AG.agi_k}, 의지+영성, (근력+체질)×${AG.tank_k} 가운데 가장 큰 값`,
  quiet: `요괴와 마주칠 확률이 기민×${AG.quiet_k}%만큼 줄고(최대 ${AG.quiet_cap}%), 꾸러미도 그 절반만큼 덜 나옵니다`,
  sneak: `성공 확률은 ${AG.sneak_base}% + 기민×${AG.sneak_k}이고, 월궁 사수는 +${AG.scout_sneak}입니다`,
  sneakRange: `${AG.sneak_min}~${AG.sneak_cap}%`,
  flee: `달아나기 ${AG.flee_base}% + 기민×${AG.flee_k}(월궁 사수 +${AG.scout_flee}, 최대 ${AG.flee_cap}%)`,
  eva: `회피 ${AG.eva_base}% + 기민×${AG.eva_k}(월궁 사수 +${AG.scout_eva}, 최대 ${AG.eva_cap}%)`,
  hazard: `위험을 피할 확률 ${AG.hazard_base}% + 기민×${AG.hazard_k}(최대 ${AG.hazard_cap}%)`,
  caps: `치명타율 최대 ${AG.crit_cap}% · 회피율 최대 ${AG.eva_cap}% · 달아날 확률 최대 ${AG.flee_cap}%. 능력치·장비·칭호를 더해도 이 위로는 오르지 않습니다`,
};
const QX = GD.questXp || { grace: 3, mid: 6, mid_pct: 50, low_pct: 20 };
export const QUEST_XP = `퀘스트 경험치는 퀘스트 레벨에 맞춰 들어갑니다. 내 레벨이 퀘스트보다 ${QX.grace}까지 높으면 그대로, ${QX.grace + 1}~${QX.mid} 높으면 ${QX.mid_pct}%, ${QX.mid + 1} 이상 높으면 ${QX.low_pct}%만 받습니다(전·물품은 그대로)`;
const FSR = GD.factionSpread || {};
const FS = (FSR.steps || [[0, 100], [1, 75], [2, 55], [3, 40], [4, 25]]).filter(([n]) => n > 0);
export const FACTION_SPREAD = `본래 땅 밖에서 차지한 곳과 1위로 분쟁 중인 곳이 많을수록, 본래 땅 밖에 새로 쌓는 영향력이 줄어듭니다. ${FS.map(([n, p], i) => `${n}곳${i === FS.length - 1 ? ' 이상' : ''} ${p}%`).join(' · ')}`;
export const FACTION_HOME = `본래 주인 세력이 자기 본래 땅에서 쌓는 영향력은 ×${(FSR.home_pct || 150) / 100}`;
export const FACTION_BOOST = `차지한 지역이 적은 세력일수록 새로 쌓는 영향력이 늘어납니다. 가장 적게 차지한 세력 ×${FSR.boost_max || 1.3}, 가장 많이 차지한 세력 ×1, 그 사이는 차지한 수에 따라`;
const FW = (FSR.window_h || 72) / 24;
export const FACTION_SCORE = {
  score: `지역 점수는 최근 ${FW}일 동안 그 지역에 쌓은 영향력 합을 그 세력에서 최근 ${FW}일 동안 ${(FSR.active_min || 60) / 60}시간 넘게 움직인 조사원 수의 제곱근으로 나눈 값입니다. 오래된 몫은 ${FW}일이 지나면 빠집니다`,
  floor: `본래 주인은 점수가 낮아도 ${FSR.floor ?? 60}으로 셉니다`,
  flip: `다른 세력 점수가 지배 세력 점수의 ${FSR.flip_ratio || 1.25}배 이상이 되면 분쟁 중이 되고, ${FSR.hold_h || 24}시간 이어지면 지배 세력이 바뀝니다. 분쟁이 시작되면 지배 세력 조사원에게 알림이 갑니다`,
  idle: `남의 땅을 차지한 세력이 그곳에 ${FSR.idle_h || 24}시간 새로 쌓지 않으면 본래 주인에게 돌아갑니다`,
  hold: FSR.hold_h || 24,
};
const FPK = GD.factionPerk || {};
const FPN = FPK.north_league || {}, FPO = FPK.night_office || {};
export const FACTION_PERK = {
  night_office: `공인 조사 수당: 원정 귀환 경험치 +${FPO.exp_xp_pct ?? 10}%`,
  night_office2: '법적 권한: 본부 구조대가 어디서든 반값·경험치 손실 없음·체력 50으로 데려옵니다',
  north_league: `원정 중 받는 피해 ${FPN.exp_hurt_pct ?? -20}% · 채집·채광 숙련 경험 +${FPN.gather_skill_pct ?? 10}%`,
  north_rank: `받는 피해 ${FPN.rank_hurt_pct ?? -2}%씩`,
};
export const FACTION_CAP = `한 사람이 한 시간 정산에 쌓는 영향력은 지역마다 ${FSR.region_cap || 40}, 모든 지역을 합쳐 ${FSR.person_cap || 60}까지, 하루(한국 시각)에는 지역마다 ${FSR.day_region_cap || 60}, 모든 지역을 합쳐 ${FSR.day_cap || 90}까지`;
export function inflMine(m) {
  if (!m) return null;
  const t = new Date(m.next_at), at = `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}`;
  const dayFull = m.day_cap != null && (m.day >= m.day_cap || m.day_all >= m.day_all_cap);
  const full = dayFull || m.n >= m.cap || m.all >= m.all_cap;
  const day = m.day_cap != null ? ` · 오늘 이 지역 ${m.day}/${m.day_cap} · 오늘 모든 지역 ${m.day_all}/${m.day_all_cap}` : '';
  const why = dayFull ? '오늘 몫이 다 찼습니다. 더 해도 오늘은 쌓이지 않고, 한국 시각 자정부터 다시 쌓입니다.'
    : full ? `몫이 다 찼습니다. 더 해도 ${at} 정산에는 들어가지 않고, ${at}부터 다시 쌓입니다.` : '얻는 몫은 도움말 › 세력 › 영향력.';
  return { full, text: dayFull ? `오늘 몫 다 참 ${m.day}/${m.day_cap}` : `이번 정산 몫 ${full ? "다 참 " : ""}${m.n}/${m.cap}`, tip: `이 지역에 이번 정산(${at})까지 쌓은 내 영향력 몫 ${m.n}/${m.cap} · 모든 지역 합 ${m.all}/${m.all_cap}${day}. ${why} ${FACTION_CAP}.` };
}
export const PARTY_EXP = {
  who: '「파티 원정」으로 함께 떠난 동료',
  apart: '각자 따로 떠난 원정은 같은 때·같은 곳이어도 각자 싸웁니다',
  fight: `회차마다 한 싸움을 함께 치릅니다. 요괴는 인원만큼 나오고(둘이면 2:2) 동료 한 명마다 위협 +${PX.threat_pct}%, 승패는 함께 정해지며, 요괴는 이목이 높은 사람을 더 자주 노립니다. 기를 모아 터뜨리거나 휩쓰는 수법은 모두를 칩니다`,
  flee: `누구든 체력이 ${PX.flee_hp} 아래면 그 싸움에서는 모두 함께 물러납니다`,
  bonus: `「파티 원정」으로 함께 떠나 ${PX.overlap_min}분 넘게 같이 다닌 동료 한 명마다 귀환 때 경험치·숙련 경험 +${PX.bonus_pct}%(${PX.bonus_cap}명까지)`,
};
const BZ = GD.busy || { travel: { name: '이동', after: '도착한 뒤에 하세요.' }, expedition: { name: '원정', after: '원정에서 돌아온 뒤에 하세요.' },
  idle: { name: '자율 활동', after: '자율 활동을 마치거나 그만둔 뒤에 하세요.' }, downed: { name: '전투불능', after: '구조를 받거나 구조대를 부른 뒤에 하세요.' },
  self: '{name} 중에는 {what}을(를) 할 수 없습니다. {after}', other: '그 동료는 지금 {name} 중입니다.', what: '이 일' };
export function busyText(kind, what, other = false) {
  const k = BZ[kind]; if (!k) return '';
  return (other ? BZ.other : BZ.self).replace('{name}', k.name).replace('{what}', what || BZ.what).replace('{after}', k.after);
}

const CB = GD.contrib || { deal: 0.6, hold: 0.2, heal: 0.1, boost: 0.1, result: 0.2 };
const SH = GD.shadow || { pow_lo: 0.75, pow_hi: 1.5, charge_mul: 5, stay_full: 0.5, gil_lv: 20 };
const CR = GD.coopRules || { sure_crit: 2, all_full: 4, all_pow: 0.5, expose_per: 4 };
const pc = v => Math.round(Number(v) * 100);
const allAt = n => Math.round(100 * Math.min(1, Math.pow(CR.all_full / n, CR.all_pow)));
export const CONTRIB = {
  weights: `공격 약 ${pc(CB.deal)}% · 버팀 약 ${pc(CB.hold)}% · 치유 약 ${pc(CB.heal)}% · 북돋움 약 ${pc(CB.boost)}%`,
  deal: `공격 갈래 안에서 실제로 깎은 피해는 약 ${pc(CB.result)}%, 내 공격력에 비해 얼마나 꾸준히 쳤나는 약 ${pc(1 - CB.result)}%로 셉니다`,
};
export const SHADOW = {
  hp: '그림자의 체력은 모인 조사원들의 공격력 합에 맞춰져, 다 함께 쳐도 15~20분쯤 걸립니다',
  hit: `그림자의 공격은 맞는 사람의 레벨과 공격력에 맞춰 세기가 바뀝니다(레벨에 비해 공격력이 높을수록 세게, 약 ${SH.pow_lo}~${SH.pow_hi}배)`,
  charge: `기운 모으기를 끊는 데 드는 피해는 최근 2분 동안 싸운 조사원들 공격력 합의 ${SH.charge_mul}배입니다`,
  stay: `토벌 시간의 ${pc(SH.stay_full)}% 넘게 함께했으면 기본 보상을 다 받고, 레벨 ${SH.gil_lv} 아래는 전을 레벨만큼 덜 받습니다`,
};
export const COOP_RULE = {
  sure: `확정 치명타(그림자 찌르기·약점 진언)는 피해가 ${CR.sure_crit}배입니다`,
  all: `참가자 모두에게 거는 기술(약점 표시·추격 신호)은 받는 사람이 ${CR.all_full}명을 넘으면 한 사람 몫이 줄어듭니다(${CR.all_full * 2}명이면 약 ${allAt(CR.all_full * 2)}%, ${CR.all_full * 3}명이면 약 ${allAt(CR.all_full * 3)}%)`,
  expose: `봉연의 그림자에서 급소 드러내기·봉인 사슬은 최근 2분 동안 싸운 조사원 ${CR.expose_per}명마다 이어지는 횟수가 한 배씩 늘어납니다`,
  strike: '그림자 찌르기는 쓰는 그 행동이 곧 공격 한 번입니다',
};


const ID = GD.idle || { rate: { training: 12, research: 10, maintenance: 8, rest: 3 }, gain: 12, eff: 0.35 };
export const idleGain = h => Math.floor(h * ID.gain * ID.eff);
export const idleXp = (k, h) => Math.floor(h * (ID.rate[k] ?? ID.rate.rest) * ID.eff);

const RS = GD.rescue || { pct: 15, min: 30, per_lv: 80, per_lv_low: 40, low_lv: 15, xp_pct: 5 };
export const RESCUE = {
  fee: `소지금의 ${RS.pct}%. 최소 ${RS.min}전이고, 최대 레벨×${RS.per_lv}전입니다. Lv${RS.low_lv} 미만은 최대 레벨×${RS.per_lv_low}전입니다.`,
  xp: `이번 레벨 경험치의 ${RS.xp_pct}%. 레벨은 내려가지 않습니다.`,
  ask: `본부 구조대를 부를까요? 소지금의 ${RS.pct}%(최소 ${RS.min}전, 레벨×${RS.per_lv}전·레벨 ${RS.low_lv} 미만은 레벨×${RS.per_lv_low}전까지, 오늘 첫 구조 반값, 가까운 안전지대가 내 대세력 지배면 다시 반값)와 이번 레벨에 필요한 경험치의 ${RS.xp_pct}%를 잃고 가장 가까운 안전지대로 옮겨집니다(레벨은 내려가지 않습니다). 그 안전지대가 내 대세력 지배면 경험치는 잃지 않고 체력 50으로 깨어납니다.`,
};

export const MARKET_SOLD = { days: 7, max: 30 };
export const SHOP_CAP = (cap, bought) => `하루 ${cap}개 · 오늘 ${bought}개 삼`;
export const GW_DAILY = '처치는 하루 한 번입니다. 이긴 날(한국 시각 자정까지)은 다시 도전할 수 없고, 지면 30분 뒤에 다시 도전할 수 있습니다.';
export const FIGHT_KINDS = {
  raid: { route: 'raid', label: '토벌' },
  gw: { route: 'gw', label: '우두머리와 싸우는 중' },
  pfight: { route: 'pfight', label: '파티 토벌' },
  bijang: { route: 'bijang', label: '비장고' },
};
export const onFightRoute = (h = location.hash) => Object.values(FIGHT_KINDS).some(k => h.startsWith(`#/${k.route}`));
const BJ = GD.bijang || { entry_day: 3, rooms: 5, party_max: 4, hold: 1, maps: [] };
export const BIJANG = {
  rule: `비장도 한 장으로 함께 선 이(${BJ.party_max}명까지) 모두가 상자를 굴립니다. 비장고 들어가기는 한 사람이 한국 시각 하루 ${BJ.entry_day}번까지(내 지도·남의 지도·혼자 모두 합쳐)이고, 다 쓴 사람은 숨은 문이 열려도 들지 못합니다(파수꾼 싸움·첫 상자는 받음).`,
  how: `비장도는 가방에서 「펼치기」를 하면 ${BJ.open?.pct ?? 30}% 확률로 비장고가 열려 그 등급 레벨대의 바깥 지역 하나가 드러납니다(명장 장비로 최대 ${BJ.open?.cap ?? 60}%). 열리지 않으면 비장도는 사라지고 지도 틈의 재료를 조금 챙깁니다. 드러난 지역에서 「비장도 따라 파기」를 하면 파수꾼이 일어납니다.`,
  hold: `비장도는 등급마다 한 사람이 ${BJ.hold}장만 지닐 수 있습니다(가방·창고·보따리·거래소 등록·받지 않은 서신·펼친 지도를 합쳐).`,
  result: { final: '마지막 방에 닿았습니다', wrong: '문을 잘못 골랐습니다', lost: '파수꾼에게 밀렸습니다', nodoor: '숨은 문이 없었습니다', full: '오늘은 들어갈 수 없었습니다' },
  end: { final: '이름을 적은 함과 재물을 함께 간 이들이 나눠 가졌습니다.', wrong: '비장고가 무너졌지만 그때까지 얻은 것은 모두 가졌습니다.',
    lost: '파수꾼과의 첫 싸움에서 졌다면 비장도는 그대로 남아 다시 팔 수 있습니다.', nodoor: '상자만 얻고 끝났습니다. 비장도는 다 썼습니다.',
    full: '함께 선 이 모두 오늘 비장고 들어가기를 다 써서 숨은 문을 다시 덮었습니다.' },
  maps: BJ.maps || [],
};
export const UCOMM_NOTE = { ph: '남길 글 (안 써도 됩니다)', hint: '게시판의 이 의뢰 아래에 보입니다. 다른 조사원이 읽는 글이니 알맞게 적어 주세요.', removed: '운영진이 이 의뢰의 글을 내렸습니다.', ask: '이 의뢰에 남긴 글을 내릴까요? 의뢰는 그대로 남고, 올린 사람에게 알림이 갑니다.' };
const QR = GD.questReplay || { pct: 20, min: 5, max_active: 3 };
export const QUEST_REPLAY = {
  ask: `경험치·물품 보상 없이 처음부터 다시 합니다. 할 일·넘길 물품은 처음과 같고, 다 마치면 그 퀘스트 전 보상의 ${QR.pct}%(최소 ${QR.min}전)를 받습니다. 한 번에 ${QR.max_active}편까지 다시 할 수 있습니다.`,
};
export const UCOMM_PAST ='받거나 거둔 의뢰입니다. 며칠 지나면 저절로 사라집니다.';

const RT = GD.rate || { gather_s: 12, fish_s: 15, search_ms: 900, battle_ms: 1000, raid_ms: 1000 };
export const GATHER_GAP = RT.gather_s * 1000;
export const SEARCH_GAP = Math.ceil(RT.search_ms / 1000) * 1000;
const GW = GD.gwiryeong || { hold: 1, cooldown_h: 72, window_days: 3, wither_h: 72, warn_h: 24 };
export const GWIRYEONG = {
  short: `서버 전체에 몇 포기뿐 · 찾은 지 ${GW.wither_h / 24}일이면 시듦 · 쓸 일이 없으면 요화로 곤란한 동료에게 넘겨 주세요`,
  wither: `처음 찾은 때부터 ${GW.wither_h / 24}일이 지나면 쓰지 않은 귀령초는 시들어 사라집니다. 남에게 넘겨도 처음 찾은 때부터 세고, 시들기 ${GW.warn_h}시간 전에 알려 드립니다.`,
  supply: `서버 전체로 나오는 수는 지금 요화에 걸려 있는 조사원 수에 맞춰 정해집니다(지난 ${GW.window_days}일 동안 나온 귀령초가 그 수에 닿으면 더 나오지 않습니다). 요화는 침식을 관리하면 피할 수 있는 위험이라, 귀령초가 걸린 사람보다 많이 쌓이지 않게 해 둔 것입니다.`,
  trade: '거래할 수 있게 만든 것은 주고받으라는 뜻입니다. 당장 쓸 일이 없으면 요화로 곤란한 동료에게 넘겨 주세요.',
  hold: `한 사람은 귀령초를 ${GW.hold}포기까지만 지닐 수 있습니다(가방·창고·거래소 등록·받지 않은 서신을 합쳐). 지닌 동안에는 새로 찾지도, 남에게 더 받지도 못합니다. 귀령초끼리 서로 맞바꿀 수도 없습니다. 한 번 얻으면 ${GW.cooldown_h}시간 동안은 다시 나오지 않습니다. 찾을 때 가방이 가득 차 있으면 개인 창고로 들어갑니다.`
};
const MUK_BLUR = GD.domains?.mukjeok?.fx?.blur || { strokes: 9, stages: [] };
const MUK_ER = MUK_BLUR.stages.map(s => s.er);
export const DOMAIN_FX = {
  note: '이 땅에 있는 동안 늘 걸리고, 떠나면 사라집니다. 상태 칸 10칸에 세지 않습니다.',
  guarded: '부적·탕으로 한 단계 가볍게',
  guardedOff: '부적·탕으로 막는 중',
  guard: `이름 새김 탕(또렷한 이름 2시간)·이름 먹 부적(이름 지킴 1시간)은 한 단계 가볍게 하고, 침식 ${MUK_ER[0] ?? 30} 아래면 막습니다.`,
  blur: `묵적 봉쇄령에서는 침식이 이름을 지웁니다. 침식 ${MUK_ER.join('·')}마다 이름 획 ${MUK_BLUR.strokes}개 가운데 ${Math.floor(MUK_BLUR.strokes / Math.max(1, MUK_ER.length))}개씩 지워지며 이름 흐림이 깊어지고, 침식을 낮추면 바로 돌아옵니다.`,
};
const WN = GD.domains?.deungdo?.fx || {};
const WN_DEATH = GD.rescue?.death_h ?? 4, WN_DAY = WN.recall?.per_day ?? 1;
const WN_WARN = `이곳은 본부 구조대가 오지 못합니다. 쓰러진 지 ${WN_DEATH}시간이 지나면 숨집니다 — 「제 이름 외기」(하루 ${WN_DAY}번)·회생 부적·같은 곳 조사원의 구조로 일어나세요.`;
export const WHITE_NIGHT = {
  band: `흰 밤 — ${WN_WARN}`,
  downed: `흰 밤 속입니다. ${WN_WARN}`,
  recall: `하루 ${WN.recall?.per_day ?? 1}번, 체력 ${WN.recall?.hp ?? 1}로 가장 가까운 등도 안전지대에서 일어납니다 · 소지금·경험치 손실 없음 · 1시간 「바랜 이름」(주는 피해 −10%)`,
  ask: '제 이름을 끝까지 외어 스스로 일어날까요? 가장 가까운 등도 안전지대에서 깨어나고, 1시간 동안 주는 피해가 줄어듭니다.',
  phase: n => `백야 · ${n}`,
  phaseTip: '흰 밤이라 하늘은 밝지만 시간은 흐릅니다 — 시간대 효과(낚시·조우 등)는 그대로 받습니다.',
};
export const UG_RESULT = {
  title: name => `${name}을(를) 깼습니다`,
  wiped: '이야기꾼의 무용담이 여기서 끊겼습니다',
  won: (tok, n, first) => `${tok}을(를) ${n}개 받았습니다. 이 판을 처음 깼다면 ${first}개를 더 받습니다(가방이 차면 창고로, 받은 수는 알림에). 횟수 제한 없이 다시 설 수 있습니다.`,
  lost: '무용담은 져도 잃는 것이 없습니다(장비 닳음·침식·재도전 대기 없음). 다시 열면 1막부터입니다.',
};
const BROKEN = '▒▣▤▥▦▧▨▩◈■';
export const brokenName = name => [...String(name || '')].map((ch, i) => ch === ' ' ? ' ' : BROKEN[(ch.codePointAt(0) + i) % BROKEN.length]).join('');
export const NAMELESS = { mine: '이름을 잃었습니다 — 묵적 봉쇄령의 침식을 낮추면 돌아옵니다', other: '이름이 지워져 읽을 수 없습니다' };
export const domainFxOf = territory => GD.domains?.[territory]?.fx || null;
export const gwWhen = (until, warnH = GW.warn_h) => {
  const t = new Date(until), left = Math.max(0, t - Date.now()), h = Math.floor(left / 3600000), m = Math.floor(left / 60000) % 60;
  const hm = `${String(t.getHours()).padStart(2, '0')}:${String(t.getMinutes()).padStart(2, '0')}`;
  return { text: `${t.getMonth() + 1}월 ${t.getDate()}일 ${hm}에 시듦 · ${h ? `${h}시간 ` : ''}${m}분 남음`,
    short: `${t.getMonth() + 1}/${t.getDate()} ${hm} 시듦 · ${h ? `${h}시간` : `${m}분`} 남음`, soon: left < warnH * 3600000 };
};
export const weakSafe = id => (GD.weakSafe || ['banyo_village']).includes(id);
export const WEAK_NAMES = (GD.weakSafeNames || ['반요촌']).join('·');
export const SYS_CHAT = {
  '구조 알림': { icon: 'heart', cls: '' },
  '세력 소식': { icon: 'pin', cls: 'note' },
  '봉연 소식': { icon: 'flame', cls: 'raidnote' },
  '비무 소식': { icon: 'sword', cls: 'note' },
  '연리 소식': { icon: 'knot', cls: 'note' },
  '운영 공지': { icon: 'bell', cls: 'note' },
  '선배 소식': { icon: 'users', cls: 'note' },
  '사업 소식': { icon: 'hammer', cls: 'note' },
};

const PJ = GD.project || { pay: { day_cap: 8000, faction: { per_merit: 100 }, common: { gil_rate: 0.6 }, help: { gil_rate: 0.6 }, after_mul: 0.5 }, urgent: { n: 2, mul: 1.5 }, hq_mul: 1.5, mul_cap: 2, help_rel: { per_k: 1, person_day: 3, pair_day: 10 }, memento: { pct: 1, faction_merit: 20, common_gil_pct: 0.5 }, lift: {}, perk_text: { faction: [], common: [] }, projects: {}, vault: [], titles: 0 };
export const PROJECT = {
  ...PJ,
  of: k => PJ.projects?.[k] || null,
  facKey: f => f ? `f:${f}` : null,
  rewardOf: (rw, pts, after) => { const k = after ? PJ.pay.after_mul : 1; return rw === 'merit' ? `공훈 ${fmtN(Math.floor(pts * k / PJ.pay.faction.per_merit))}` : `${fmtN(Math.floor(pts * k * (PJ.pay[rw]?.gil_rate ?? PJ.pay.common.gil_rate)))}전`; },
  goalTip: kind => `단계 목표는 ${kind === 'faction' ? '모든 세력이 같습니다' : '세 땅 모두 같습니다'}: ${(Object.values(PJ.projects || {}).find(p => p.kind === kind)?.base || []).map(fmtN).join(' · ')}몫.`,
  payTip: rw => `넘긴 물품의 몫(1개 기준 몫 × 수량)만큼 ${rw === 'merit' ? `공훈을 받습니다(몫 ${PJ.pay.faction.per_merit} = 공훈 1).` : `전을 받습니다(몫 1 = ${PJ.pay[rw]?.gil_rate ?? PJ.pay.common.gil_rate}전).`} 「급히」 품목은 ×${PJ.urgent.mul}, 우수품은 ×${PJ.hq_mul}(겹쳐도 ×${PJ.mul_cap}까지). 한 사람이 하루에 넘길 수 있는 몫은 거점·공동·남의 세력 사업을 모두 합쳐 ${fmtN(PJ.pay.day_cap)}까지이고, 넘치는 물품은 돌려받습니다. 다섯 단계를 다 마친 뒤에도 넘길 수 있지만 보상은 ${PJ.pay.after_mul * 100}%입니다.`,
  helpTip: () => `내 세력이 아닌 세력의 거점 사업도 그 거점에서 도울 수 있습니다. 몫 1마다 ${PJ.pay.help.gil_rate}전을 받고, 몫은 그 세력 사업에 쌓입니다. 단계가 찰 때 기여가 ${PJ.memento.pct}% 넘으면 낙성 떡을 받고, 누계는 사업 칭호에 셉니다. 상점·지역 효과·지름길·비고·꾸미기 혜택은 그 세력 조사원만 받습니다. 내 세력이 있으면 몫 1,000마다 두 세력 관계가 +${PJ.help_rel.per_k} 오릅니다(한 사람 하루 +${PJ.help_rel.person_day}, 두 세력 사이 하루 +${PJ.help_rel.pair_day}까지).`,
  mementoTip: () => `한 단계가 차는 순간, 그 단계 목표의 ${PJ.memento.pct}% 넘게 넘긴 사람은 낙성 떡과 ${`공훈 +${PJ.memento.faction_merit}(그 세력 조사원)·단계 목표의 ${PJ.memento.common_gil_pct}%만큼 전(공동)`}을 받습니다. 마지막 단계에 힘을 보태면 기념품이 더 있습니다.`,
};
const fmtN = n => Number(n || 0).toLocaleString('ko-KR');

const MT = GD.mentor || { gap: 10, near_min: 10, day_cap: 60, pair_cap: 30, xp_day: 50, kinds: {}, skip: [], shop: [], post: { hours: 2, note: 30, wants: {} } };
export const MENTOR = {
  ...MT,
  role: (me, other) => other - me >= MT.gap ? 'mentor' : me - other >= MT.gap ? 'mentee' : '',
  canSeek: lv => lv <= (GD.level?.cap ?? 45) - MT.gap,
  canOffer: lv => lv >= 1 + MT.gap,
  help: () => `레벨이 ${MT.gap} 이상 차이 나는 파티원과 함께하면 새내기는 경험치 덤을 받고, 선배는 「챙김」을 쌓아 꾸미기·탈것·칭호로 바꿉니다(능력치 효과 없음).
· 셈하는 것: 함께 토벌(파티 현장 토벌 +${MT.kinds.pfight?.pct ?? 25}%) · 곁에서 토벌(새내기 혼자 토벌, 같은 곳의 선배가 ${MT.near_min}분 안에 움직였을 때 +${MT.kinds.win?.pct ?? 15}%) · 파티 원정 완주(+${MT.kinds.exp?.pct ?? 25}%) · 할 일 있는 퀘스트 보고(+${MT.kinds.quest?.pct ?? 25}%, 같은 곳에 선배)
· 셈하지 않는 것: ${(MT.skip || []).join('·')}
· 같은 파티·같은 곳이어야 하고, 쓰러졌거나 이동 중이면 셈하지 않습니다. 다른 경험치 덤과 합쳐 상한이 있습니다.
· 하루 챙김 ${MT.day_cap}(같은 새내기에게서 ${MT.pair_cap})까지, 새내기 덤은 하루 그 레벨 필요 경험치의 ${MT.xp_day}%까지입니다.`,
};
export const CHEER_NAME = { clap: '박수 치기', petal: '꽃잎 뿌리기', cup: '술잔 올리기', bow: '절하기', cake: '떡 돌리기', pet: '동무 나서기' };
export const SCENE_ACTS = {
  claps: { label: CHEER_NAME.clap, fx: 'star' }, petals: { label: CHEER_NAME.petal, fx: 'petal' }, cups: { label: CHEER_NAME.cup, fx: 'note' },
  bows: { label: CHEER_NAME.bow, fx: 'heart' }, cakes: { label: CHEER_NAME.cake, fx: 'star' }, pets: { label: CHEER_NAME.pet, fx: 'pet' },
  wished: { label: '축사', fx: 'note' }, joined: { label: '함께하기', fx: 'star' }, join: { label: '신청', fx: 'star' },
};
export const DUEL_FX = { miss: { label: '피함' }, stun: { label: '묶임' }, down: { label: '무릎 꿇음' }, end: { label: '이겼다' } };
const WEEKDAY = ['월', '화', '수', '목', '금', '토', '일'];
export const TOURNEY_WEEK = (() => {
  const t = GD.tourney;
  return { signup: `${WEEKDAY[0]}요일 0시부터 ${WEEKDAY[t.signup_end_day - 1]}요일 23시 59분까지`, solo: `${WEEKDAY[t.solo_day]}요일 ${t.start_h}시`, team: `${WEEKDAY[t.team_day]}요일 ${t.start_h}시`, absent: t.absent_min, min: t.min_entries };
})();
export const SURVIVAL = (() => {
  const g = GD.survival.ground, c = GD.survival.cleanse;
  return { ground: `정신 +${g.mn} · 침식 −${g.er}`, groundEvery: g.min, cleanse: `침식 −${c.er} · 정신 +${c.mn}`, cleanseHq: `침식 −${c.hq_er} · 정신 +${c.hq_mn}` };
})();

export const REBOND = (h => h % 24 ? `${h}시간` : h === 24 ? '하루' : `${h / 24}일`)(GD.wedding?.rebond_h ?? 24);
