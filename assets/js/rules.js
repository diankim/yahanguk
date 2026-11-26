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
export const FACTION_DONATE = { rate: FPK.donate?.rate ?? 50, cap: FPK.donate?.cap ?? 60 };
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
  guard: `진법가가 막아 준 피해는 버팀 갈래에서 ${(CB.guard_mul || {}).formation || 1}배로 셉니다(방패처럼 도발로 맞지 않고 보호막·결계로 미리 막기 때문)`,
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
  expose: `사슬 벗은 그림자에서 급소 드러내기·봉인 사슬은 최근 2분 동안 싸운 조사원 ${CR.expose_per}명마다 이어지는 횟수가 한 배씩 늘어납니다`,
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
  how: `비장도는 가방에서 「펼치기」를 하면 ${BJ.open?.pct ?? 30}% 확률로 비장고가 열려 그 등급 레벨대(세력 땅 포함)의 바깥 지역 하나가 드러납니다(명장 장비로 최대 ${BJ.open?.cap ?? 60}%). 열리지 않으면 비장도는 사라지고 지도 틈의 재료를 조금 챙깁니다. 드러난 지역에서 「비장도 따라 파기」를 하면 파수꾼이 일어납니다.`,
  guardLv: (m, lv) => Math.min((GD.level?.cap ?? 50) + 1, Math.max((m?.lv || 0) + (BJ.guard?.lv_up ?? 3), (lv || 0) + (BJ.guard?.own_up ?? 1))),
  guardRule: `파수꾼 레벨은 지역이 아니라 비장도와 지도 주인에 맞춥니다: 비장도 레벨 + ${BJ.guard?.lv_up ?? 3}과 지도 주인 레벨 + ${BJ.guard?.own_up ?? 1} 가운데 높은 쪽(최고 ${(GD.level?.cap ?? 50) + 1}), 방마다 나오는 파수꾼도 같습니다. 모습과 수법은 그 지역 우두머리입니다.`,
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
const LT = GD.lantern || { body_max: 60, day: { send: 3, catch: 1 }, days: 7, ports: [], shapes: [], colors: [], start: { shape: 'round', color: 'red' }, reply: { counts_send: true }, hanger: { n: 5, name: '등불 걸개' }, titles: [] };
const LT_SHAPE = Object.fromEntries((LT.shapes || []).map(x => [x.key, x.name]));
const LT_COLOR = Object.fromEntries((LT.colors || []).map(x => [x.key, x.name]));
export const LANTERN = {
  ...LT,
  isPort: r => (LT.ports || []).some(p => p.r === r),
  portNames: () => (LT.ports || []).map(p => p.name).join(' · '),
  lookName: (shape, color) => `${LT_COLOR[color] || ''} ${LT_SHAPE[shape] || ''}`.trim(),
  shapeName: k => LT_SHAPE[k] || k,
  colorName: k => LT_COLOR[k] || k,
  total: () => (LT.shapes || []).length * (LT.colors || []).length,
  tile: '글을 적은 등불 띄우기 · 건지기',
  help: `항구 물가에서 글을 적은 등불을 띄웁니다. 등불은 물살을 타고 다른 항구로 흘러가, 그곳 물가에서 누군가 건져 읽습니다. 글은 ${LT.body_max}자까지이고, 띄운 이의 이름은 끝까지 밝혀지지 않습니다(글에 스스로 적는 것은 됩니다). 하루(한국 시각)에 띄우기 ${LT.day?.send}번·건지기 ${LT.day?.catch}번이고, 아무도 건지지 않은 등불은 ${LT.days}일 동안 떠돌다 꺼집니다. 건진 등불에는 답등을 한 번 띄울 수 있고${LT.reply?.counts_send ? ', 답등도 오늘 띄우기 수에 듭니다' : ''}.`,
  bookHelp: `등 모양 ${(LT.shapes || []).length}가지와 색 ${(LT.colors || []).length}가지로 ${(LT.shapes || []).length * (LT.colors || []).length}칸입니다. 처음에는 ${LT_COLOR[LT.start?.color] || ''} ${LT_SHAPE[LT.start?.shape] || ''} 하나만 열려 있고, 남이 띄운 등불을 건지면 그 등불의 모양·색이 열려 내가 띄울 때 고를 수 있습니다.`,
  away: '항구 물가에 있지 않습니다. 등불은 항구가 있는 곳의 물가에서 띄우고 건질 수 있습니다. 지난 등불과 등불첩은 어디서나 볼 수 있습니다.',
  noPool: '지금 이 물가에 흘러온 등불이 없습니다. 다른 항구에 가 보거나 조금 뒤에 다시 와 보세요.',
  status: { float: '떠도는 중', caught: '누군가 건짐', out: '꺼짐', removed: '운영진이 내림' },
  removed: '운영진이 내린 등불입니다.',
  locked: '아직 열리지 않은 등입니다. 남이 띄운 이 모양·색의 등불을 건지면 열립니다.',
  hideAsk: '이 등불을 내 화면에서 숨길까요? 같은 이가 띄운 등불은 앞으로 건지지 않습니다. 되돌릴 수 없습니다.',
  reportTip: '불쾌한 글은 깃발로 운영진에게 알려 주세요. 제보한 등불은 내 화면에서 숨겨집니다.',
  replyNote: `건진 등불을 띄운 이에게만 닿습니다. 한 등불에 한 번만 띄울 수 있고${LT.reply?.counts_send ? ', 오늘 띄우기 수에 듭니다' : ''}. 띄운 이도 나도 서로의 이름은 알 수 없습니다.`,
  hangerLine: (n, got) => got ? `${LT.hanger?.name || '등불 걸개'} — 받음 (별채 곳간)` : `${LT.hanger?.name || '등불 걸개'} — 등불을 ${LT.hanger?.n}번 건지면 별채 곳간에 들어옵니다 (${Math.min(n, LT.hanger?.n)}/${LT.hanger?.n})`,
  left: ms => { const d = Math.floor(ms / 86400000), h = Math.floor(ms % 86400000 / 3600000); return ms <= 0 ? '곧 꺼짐' : d > 0 ? `${d}일 ${h}시간 남음` : `${Math.max(1, h)}시간 남음`; },
};

const HF = GD.harborFeast || { need: 12, per_person: 3, buff_h: 4, eat_h: 2, slot_h: 12, tie: 'soban', order: ['meat', 'soban', 'sea'], kinds: {}, ports: [], cap: 10 };
const HF_SLOTS = Array.from({ length: Math.max(1, Math.round(24 / (HF.slot_h || 12))) }, (_, i) => `${i * (HF.slot_h || 12)}시`);
const HF_KIND = k => HF.kinds?.[k]?.name || '';
export const HFEAST = {
  ...HF,
  isPort: r => (HF.ports || []).some(p => p.r === r),
  portNames: () => (HF.ports || []).map(p => p.name).join(' · '),
  kindName: HF_KIND,
  minPeople: Math.ceil((HF.need || 12) / Math.max(1, HF.per_person || 3)),
  tile: '요리를 한 상에 모으기 · 다 차면 모두 기운',
  guess: (bowls = []) => {
    const n = {}; for (const b of bowls) n[b.kind] = (n[b.kind] || 0) + 1;
    const mx = Math.max(0, ...Object.values(n)); if (!mx) return null;
    const top = Object.keys(n).filter(k => n[k] === mx);
    return top.length === 1 ? top[0] : HF.tie;
  },
  help: `항구마다 하루 ${HF_SLOTS.length}상(한국 시각 ${HF_SLOTS.join('·')}부터 ${HF.slot_h}시간씩)을 차립니다. 요리를 한 그릇씩 올려 ${HF.need}그릇이 다 차면 상이 열립니다. 한 사람은 한 상에 ${HF.per_person}그릇까지 올릴 수 있어, 상을 채우려면 적어도 ${Math.ceil((HF.need || 12) / Math.max(1, HF.per_person || 3))}명이 함께해야 합니다. 상 종류는 가장 많이 오른 요리 갈래로 정해지고, 같으면 ${HF_KIND(HF.tie)}이(가) 됩니다. 요리를 올린 사람은 상이 열리는 순간 기운을 받고, 그 밖의 사람은 열린 뒤 ${HF.eat_h}시간 안에 그 항구에서 「상에서 먹기」를 한 번 하면 받습니다. 기운은 ${HF.buff_h}시간 갑니다. 칸 시간 안에 다 차지 않은 상은 사라지고, 올린 요리는 돌려받지 못합니다.`,
  dishNote: '요리 분야 제작법으로 만든 음식만 올릴 수 있습니다(노정 건량·말린 생선포 같은 길양식은 빼고). 우수품도 한 그릇입니다.',
  giveAsk: (name, n, need) => `「${name}」 한 그릇을 상에 올릴까요? 올린 요리는 돌려받지 못하고, 이번 칸 안에 ${need}그릇이 다 차지 않으면 상과 함께 사라집니다. (지금 ${n}/${need})`,
  down: '쓰러진 채로는 잔칫상에서 먹을 수도, 요리를 올릴 수도 없습니다. 일어난 뒤 열린 시간 안에 다시 오세요.',
  full: cap => `상태 칸 ${cap}칸이 모두 차 있어 기운을 받을 수 없습니다. 상태 창에서 이로운 효과를 꺼 칸을 비운 뒤 「상에서 먹기」를 하세요.`,
  away: '항구에 있지 않습니다. 요리는 그 항구에서 올리고, 「상에서 먹기」도 그 항구에서 합니다.',
  vanish: '칸 시간이 끝날 때 다 차지 않은 상은 사라집니다.',
  kst: t => { const d = new Date(new Date(t).getTime() + 9 * 3600000); return `한국 시각 ${String(d.getUTCHours()).padStart(2, '0')}:${String(d.getUTCMinutes()).padStart(2, '0')}`; },
};

const RT = GD.rate || { gather_s: 12, fish_s: 15, search_ms: 900, battle_ms: 1000, raid_ms: 1000 };
export const GATHER_GAP = RT.gather_s * 1000;
export const SEARCH_GAP = Math.ceil(RT.search_ms / 1000) * 1000;
const GW = GD.gwiryeong || { hold: 1, cooldown_h: 72, window_days: 3, wither_h: 72, warn_h: 24 };
export const GWIRYEONG = {
  short: `서버 전체에 몇 포기뿐 · 찾은 지 ${GW.wither_h / 24}일이면 시듦 · 쓸 일이 없으면 요화로 곤란한 동료에게 넘겨 주세요`,
  wither: `처음 찾은 때부터 ${GW.wither_h / 24}일이 지나면 쓰지 않은 귀령초는 시들어 사라집니다. 남에게 넘겨도 처음 찾은 때부터 세고, 시들기 ${GW.warn_h}시간 전에 알려 드립니다.`,
  supply: `서버 전체로 나오는 수는 지금 요화에 걸려 있는 조사원 수에 맞춰 정해집니다(지난 ${GW.window_days}일 동안 나온 귀령초가 그 수에 닿으면 더 나오지 않습니다). 요화는 침식을 관리하면 피할 수 있는 위험이라, 귀령초가 걸린 사람보다 많이 쌓이지 않게 해 둔 것입니다.`,
  can: c => !c ? '' : [c.why === 'hold' ? '나는 이미 귀령초를 지니고 있어 새로 나오지 않습니다.' : c.why === 'cooldown' ? `나는 최근에 귀령초를 얻어 ${(t => `${t.getMonth() + 1}월 ${t.getDate()}일 ${String(t.getHours()).padStart(2, "0")}:${String(t.getMinutes()).padStart(2, "0")}`)(new Date(c.until))}까지는 나오지 않습니다.` : '',
    c.open ? '지금은 서버에서 귀령초가 나올 수 있는 때입니다.' : '지금은 서버 전체에서 귀령초가 나오지 않는 때입니다. 시간이 지나거나 요화에 걸린 조사원이 늘면 다시 나옵니다.'].filter(Boolean).join(' '),
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
  guardedOff: '등불로 막는 중',
  guarded: '등불로 막는 중',
  tip: `등도 옛터에는 흰 밤이 걷히지 않습니다. 정신 손실 +${WN.effects?.mental_loss_pct ?? 15}% · 받는 피해 +${WN.effects?.incoming_damage_pct ?? 5}% · 요괴 조우 +${WN.effects?.encounter_pct ?? 5}%, 대신 그림자가 없어 기척 숨기기 +${WN.effects?.wn_sneak ?? 15}% · 조용히 살피기 상한 +${WN.effects?.wn_quiet ?? 10}% · 회피 +${WN.effects?.wn_eva ?? 3}%. 밤을 되찾은 지역과 등도의 안전지대에서는 걸리지 않고, 명등 등롱(등불 아래)·등어 기름 명등(꺼지지 않는 등빛)을 켜면 막습니다. ${WN_WARN}`,
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
  '그림자 소식': { icon: 'flame', cls: 'raidnote' },
  '비무 소식': { icon: 'sword', cls: 'note' },
  '연리 소식': { icon: 'knot', cls: 'note' },
  '운영 공지': { icon: 'bell', cls: 'note' },
  '선배 소식': { icon: 'users', cls: 'note' },
  '사업 소식': { icon: 'hammer', cls: 'note' },
  '잔치 소식': { icon: 'bowl', cls: 'note' },
  '교역 소식': { icon: 'ship', cls: 'note' },
};

const PJ = GD.project || { pay: { day_cap: 8000, faction: { per_merit: 100 }, common: { gil_rate: 0.6 }, help: { gil_rate: 0.6 }, after_mul: 0.5 }, urgent: { n: 2, mul: 1.5 }, hq_mul: 1.5, mul_cap: 2, help_rel: { per_k: 1, person_day: 3, pair_day: 10 }, memento: { pct: 1, faction_merit: 20, common_gil_pct: 0.5 }, lift: {}, perk_text: { faction: [], common: [] }, projects: {}, vault: [], titles: 0 };
export const PROJECT = {
  ...PJ,
  of: k => PJ.projects?.[k] || null,
  facKey: f => f ? `f:${f}` : null,
  rewardOf: (rw, pts) => { const k = 1; return rw === 'merit' ? `공훈 ${fmtN(Math.floor(pts * k / PJ.pay.faction.per_merit))}` : `${fmtN(Math.floor(pts * k * (PJ.pay[rw]?.gil_rate ?? PJ.pay.common.gil_rate)))}전`; },
  goalTip: kind => `단계 목표는 ${kind === 'faction' ? '모든 세력이 같습니다' : '세 땅 모두 같습니다'}: ${(Object.values(PJ.projects || {}).find(p => p.kind === kind)?.base || []).map(fmtN).join(' · ')}몫.`,
  payTip: rw => `넘긴 물품의 몫(1개 기준 몫 × 수량)만큼 ${rw === 'merit' ? `공훈을 받습니다(몫 ${PJ.pay.faction.per_merit} = 공훈 1).` : `전을 받습니다(몫 1 = ${PJ.pay[rw]?.gil_rate ?? PJ.pay.common.gil_rate}전).`} 「급히」 품목은 ×${PJ.urgent.mul}, 우수품은 ×${PJ.hq_mul}(겹쳐도 ×${PJ.mul_cap}까지). 한 사람이 하루에 넘길 수 있는 몫은 거점·공동·남의 세력 사업을 모두 합쳐 ${fmtN(PJ.pay.day_cap)}까지이고, 넘치는 물품은 돌려받습니다. 다섯 단계를 다 마친 뒤에도 같은 보상으로 넘길 수 있습니다.`,
  lapLine: '마지막 단계 목표만큼 찰 때마다 한 바퀴',
  lapTip: kind => `다섯 단계를 마친 뒤에도 납품 보상은 그대로이고, 하루 상한도 같습니다. 마지막 단계 목표만큼 몫이 찰 때마다 「한 바퀴」로 세어, 그 바퀴에 목표의 ${PJ.memento.pct}% 넘게 낸 조사원에게 낙성 떡을 나눕니다${kind === 'faction' ? `(그 세력 조사원은 공훈 +${PJ.memento.faction_merit}도). 아직 낙성 기념패가 없으면 기념패도 함께 받습니다` : `(목표의 ${PJ.memento.common_gil_pct}%만큼 전도). 아직 낙관 「拓」이 없으면 낙관도 함께 받습니다`}. 늦게 온 조사원도 기념품을 받을 수 있습니다.`,
  helpTip: () => `내 세력이 아닌 세력의 거점 사업도 그 거점에서 도울 수 있습니다. 몫 1마다 ${PJ.pay.help.gil_rate}전을 받고, 몫은 그 세력 사업에 쌓입니다. 단계가 찰 때 기여가 ${PJ.memento.pct}% 넘으면 낙성 떡을 받고, 누계는 사업 칭호에 셉니다. 상점·지역 효과·지름길·비고·꾸미기 혜택은 그 세력 조사원만 받습니다. 내 세력이 있으면 몫 1,000마다 두 세력 관계가 +${PJ.help_rel.per_k} 오릅니다(한 사람 하루 +${PJ.help_rel.person_day}, 두 세력 사이 하루 +${PJ.help_rel.pair_day}까지).`,
  mementoTip: () => `한 단계가 차는 순간, 그 단계 목표의 ${PJ.memento.pct}% 넘게 넘긴 사람은 낙성 떡과 ${`공훈 +${PJ.memento.faction_merit}(그 세력 조사원)·단계 목표의 ${PJ.memento.common_gil_pct}%만큼 전(공동)`}을 받습니다. 마지막 단계에 힘을 보태면 기념품이 더 있습니다.`,
};
const fmtN = n => Number(n || 0).toLocaleString('ko-KR');

const RG = GD.regular || { day_n: 6, orders: 3, aff: { give: 10, hq: 15, cap: 420, stages: [0, 60, 150, 270, 420] }, xp: { pct: 25, min: 30, hq_mul: 1.5 }, gil: { rate: 0.3, base: 30 }, qty: { gear: 1, item: 3, gather: 10, fish: 3 }, npcs: {} };
const REGULAR_COUNT = '한국 시각 오늘 0시부터 현장에서 이긴 토벌로 셉니다(혼자 싸운 것과 파티 토벌 모두, 원정·비무·우두머리 싸움은 빼고). 한 번의 토벌이 여러 주문에 함께 셉니다.';
const RG_FIGHT = Object.values(RG.npcs || {}).filter(n => n.kind === 'combat').length;
const RG_CRAFT = Object.keys(RG.npcs || {}).length - RG_FIGHT;
export const BOND_EMOTE = {
  emotes: GD.bondEmote?.emotes || [],
  left: n => `오늘 ${n}번 남음`,
  rate: '조금 천천히 해 주세요.',
  gained: n => `인연도가 ${n} 올랐습니다(오늘 첫 상호작용).`,
  icon: k => ({ heart: 'heart', spark: 'star', note: 'note', sweat: 'sick' })[k] || 'heart',
  help: '별채에서 정인의 모습을 누르면 상호작용을 고를 수 있습니다. 하루 10번까지이고, 하루 처음 한 번은 인연도가 오릅니다. 정인에게 알림이 가며, 설정 › 알림 「연리」에서 끌 수 있습니다.',
};

export const GARDEN = {
  help: '별채 뒤뜰 밭입니다. 가진 식재료를 한 칸에 하나씩 심고 물을 주면 자랍니다. 심기·거두기는 안전지대에서, 물 주기는 어디서나 합니다. 심을 식재료·비료는 가방과 창고에서 꺼내 쓰고, 거둔 작물은 가방에 들어갑니다. 물 한 번이 하루 가고, 물이 마른 동안은 자라지 않습니다. 작물 단계가 높을수록 오래 자랍니다. 다 자란 뒤 이틀 안에 거두지 않으면 썩습니다. 비료는 심을 때 함께 골라 빨리 자라게 하거나 더 많이 거두게 합니다. 이따금 까마귀가 내려앉아 작물을 쪼아 먹으니 눌러 쫓아 주세요. 허수아비를 세우면 이레 동안 까마귀가 오지 않습니다. 밭은 별채 주인과 한 지붕 정인이 가꾸고, 손님은 까마귀를 쫓아 줄 수 있습니다.',
  plantTip: '식재료 하나를 가방(모자라면 창고)에서 꺼내 심습니다. 다음 창에서 비료를 함께 고릅니다. 심은 뒤 물을 주어야 자랍니다.',
  growLine: (r, t) => `${r.hours?.[t] ?? '?'}시간 · 비료 ${r.fert_n?.[t] ?? 1}개씩`,
  fertFx: f => f.kind === 'speed' ? `남은 자라는 시간 −${f.pct}%` : `거둘 양 +${f.n}개`,
  fertTip: (t, n) => `${t}단계 작물에는 비료가 ${n}개 듭니다. 비료는 심을 때만 줄 수 있고, 심은 뒤에는 더 줄 수 없습니다.`,
  crowEvery: r => `${r?.crow?.every_h ?? 3}시간`,
};

const TD = GD.trade || { ports: {}, goods: {}, foods: {}, ships: [], parts: {}, part_names: {}, sail: { tokens: 2, board_s: 60, send_mul: 0.8, direct_div: 4 }, bonus: {}, day_cap: 3000, slot_n: 10, lose_pct: 20, send_lose: [10, 20], dur: { voyage: 2, raid: 10, repair_gil: 2 }, name_max: 12, seek: { n: 2, days: 3 }, events: [] };
const tLeft = ms => { const s = Math.max(0, Math.round(ms / 1000)); return s >= 3600 ? `${Math.floor(s / 3600)}시간 ${Math.floor(s % 3600 / 60)}분` : s >= 60 ? `${Math.floor(s / 60)}분 ${s % 60}초` : `${s}초`; };
export const TRADE = {
  ...TD,
  port: k => TD.ports?.[k] || null,
  ship: t => TD.ships?.[Math.max(1, Math.min(5, t || 1)) - 1] || null,
  isPort: k => !!TD.ports?.[k],
  tags: { origin: '산지', want: '찾는 곳', far: '먼 뭍 물건', seek: '찾는 물건', event: '수요', hot: '많이 팔림' },
  tagTip: { origin: '이 항구에서 나는 물건입니다. 여기서만 사서 실을 수 있고, 파는 값은 싸게 쳐 줍니다.', want: '이 항구가 늘 비싸게 사 주는 물건입니다.', far: '바다 건너에서 온 물건이라 비싸게 쳐 줍니다.',
    seek: `이 항구가 요즘 찾는 물건입니다. ${TD.seek?.days || 3}일마다 바뀝니다.`, event: '오늘 이 항구에 큰일이 있어 모든 교역품을 평소보다 비싸게 삽니다.', hot: '조사원들이 이 항구에 많이 팔아 값이 내려갔습니다. 하루에 걸쳐 돌아옵니다.' },
  help: `항구에서 산지 교역품을 사서 배 짐칸에 싣고, 다른 항구로 가서 팝니다. 같은 물건도 항구마다 값이 다르고, 값은 한국 시각 0시마다 조금씩 흔들립니다. 산지에서는 싸고, 그 물건을 찾는 항구에서는 비쌉니다. 다른 항구의 값은 그 항구에 들렀을 때 본 값이 시세판에 남습니다. 하루에 팔 수 있는 몫은 판 물건의 정가 합 ${(TD.day_cap || 3000).toLocaleString('ko-KR')}전까지이고, 받는 돈은 그날 시세대로입니다. 배는 노정패 ${TD.sail?.tokens ?? 2}개로 띄웁니다. 직접 타고 가면 빠르고 제값을 받으며 그 항구 시세판을 새로 봅니다. 보내 두면 사람은 남고 배와 짐만 가서 그 항구에서 저절로 팔리는데, 받는 돈이 ${Math.round((1 - (TD.sail?.send_mul ?? 0.8)) * 100)}% 적습니다. 뱃길에서는 습격을 받을 수 있습니다. 직접 타고 갔다면 싸워 물리치면 짐을 지키고, 지면 짐 ${TD.lose_pct ?? 20}%를 잃고 배가 상합니다.`,
  modeName: { direct: '직접 타고 가기', send: '보내 두기' },
  modeTip: {
    direct: `내가 배를 타고 갑니다. 닿을 때까지 다른 일을 할 수 없고, 닿으면 그 항구에 서 있습니다. 습격을 받으면 싸웁니다. 파티원을 태우면 덤 하나를 고릅니다.`,
    send: `배와 짐만 보냅니다. 나는 이 자리에 남아 다른 일을 할 수 있습니다. 닿으면 짐이 그 항구에서 저절로 팔리고(떠날 때 값의 ${Math.round((TD.sail?.send_mul ?? 0.8) * 100)}%), 습격을 받으면 짐 ${(TD.send_lose || [10, 20]).join('~')}%를 잃습니다. 하루 판매 몫을 넘는 짐은 배에 남습니다.`,
  },
  bonusTip: k => { const b = TD.bonus?.[k] || {}, m = TD.bonus?.max_mates || 3;
    return k === 'time' ? `함께 탄 동료 한 명마다 뱃길 시간 −${b.per}%(${m}명까지)` : k === 'guard' ? `습격에 졌을 때 잃는 짐이 동료 한 명마다 −${b.per}%(${m}명까지)` : `닿은 항구에서 팔 때 값이 동료 한 명마다 +${b.per}%(${m}명까지)`; },
  boardTip: `같은 항구에 있는 파티원에게 함께 타자고 합니다. ${TD.sail?.board_s ?? 60}초 안에 답한 사람만 태우고 떠납니다. 태울 수 있는 사람 수는 내 배 크기를 따릅니다. 함께 탄 동료의 배는 짐칸만 끌배로 따라옵니다.`,
  leftText: ms => ms > 0 ? `${tLeft(ms)} 뒤 닿음` : '닿는 중…',
  inviteText: ms => ms > 0 ? `${tLeft(ms)} 안에 답하세요` : '마감',
  boardText: ms => ms > 0 ? `${tLeft(ms)} 뒤 떠남 · 동료의 답을 기다리는 중` : '떠나는 중…',
  sailTitle: v => `${v.status === 'raid' ? '뱃길 습격' : '항해 중'} → ${v.to_name || ''}`,
  boardTitle: v => `배 띄우기 준비 → ${v.to_name || ''}`,
  sendTitle: v => `보낸 배 → ${v.to_name || ''}`,
  raidText: '배가 습격을 받았습니다. 물리치면 짐을 지킵니다.',
  dayTip: cap => `하루에 팔 수 있는 몫은 판 교역품의 정가 합 ${Number(cap).toLocaleString('ko-KR')}전까지입니다. 받는 돈은 시세대로라 정가보다 비싸게 팔면 더 많이 법니다. 한국 시각 0시에 다시 찹니다. 상점 되팔기 한도와는 따로입니다.`,
  foodTip: '세력 특선 음식은 가방에서 짐칸으로 옮겨 실을 수 있습니다. 시세판에는 없고, 파는 값은 팔 때 그 항구 시세로 정해집니다.',
  repairTip: g => `내구도 1마다 ${g}전입니다. 항해마다 조금씩, 습격을 받으면 크게 닳고, 다 닳으면 고치기 전에는 띄울 수 없습니다. 조선소가 없는 항구에서도 고칠 수 있습니다.`,
  yardTip: '조선소가 있는 항구에서 다음 배에 드는 재료를 갈래마다 넣습니다. 재료는 가방을 먼저 쓰고 모자라면 창고에서 꺼냅니다(빈약한 안전지대에서는 창고를 쓰지 않음). 모든 갈래가 차고 레벨이 되면 전을 내고 배를 올립니다. 재료를 넣을 때마다 목공 경험을 조금 얻습니다.',
  raidPct: (from, to, min) => { const R = TD.raid || { p: 10, p_far: 15, far_min: 180 }, cross = (TD.cross || []).some(([a, b]) => (a === from && b === to) || (a === to && b === from));
    return (min != null && min >= R.far_min) || cross ? R.p_far : R.p; },
  raidLine: pct => `습격 ${pct}%`,
  raidTip: () => { const R = TD.raid || { p: 10, p_far: 15, far_min: 180 };
    return `뱃길마다 습격을 받을 확률은 ${R.p}%이고, 나룻배 기준 ${Math.round(R.far_min / 60)}시간 넘는 먼 뱃길과 바다 건너기는 ${R.p_far}%입니다. 한 번 띄우면 가는 길 가운데쯤 한 번만 굴립니다. 직접 타고 가면 싸워서 막을 수 있고, 보내 두면 저절로 짐 ${(TD.send_lose || [10, 20]).join('~')}%를 잃습니다.`; },
  partyLine: (n, min) => n > 0 ? `지금 함께 탈 수 있는 파티원 ${n}명 · 물길 줄이기면 약 ${min}분` : '지금 이 항구에 함께 탈 수 있는 파티원이 없습니다',
  departText: ms => ms > 0 ? `${tLeft(ms)} 뒤 떠남` : '떠나는 중…',
  boardingTitle: v => `${v.captain_name || ''}의 배 · ${v.to_name || ''}행`,
  boardingText: ms => ms > 0 ? `함께 타기로 함 · ${tLeft(ms)} 뒤 떠남` : '떠나는 중…',
  cmpHead: name => `모든 항구 · ${name}`,
  cmpTip: '시세판에서 물건 이름을 누르면 그 물건의 항구별 값을 견줍니다. 다른 항구 값은 마지막으로 들렀을 때 본 값입니다.',
  seenNone: '들른 적 없음',
  away: '항구에 있지 않습니다. 배를 타고 내린 항구나 항구가 있는 지역으로 가면 교역을 할 수 있습니다.',
};

export const NEAR = {
  tag: h => h === 0 ? '지금 여기' : `가까움 · ${h}구간`,
  tip: '지금 있는 곳에서 가장 가까운 곳입니다. 내 레벨로 지날 수 없거나 아직 열리지 않은 지역은 셈하지 않습니다.',
  head: '가까운 곳 먼저 · 나머지는 낮은 레벨부터',
};

export const REGULAR = {
  ...RG,
  stageAt: n => RG.aff.stages[Math.max(0, Math.min(RG.aff.stages.length, n) - 1)] || 0,
  none: '아직 연담을 맺은 사람이 없습니다. 인물마다 여는 퀘스트를 마치면 그 사람의 주문을 받을 수 있습니다.',
  titleTip: who => `${who}와(과)의 다섯째 이야기를 마치면 받는 칭호`,
  othersLine: '여기서 함께 맺은 연담',
  taskWhere: '오늘 0시부터 센 수',
  isMeat: id => (GD.food?.meat_ids || []).includes(id),
  huntLine: name => `요괴를 토벌해 「${name}」을(를) 가져오세요. 거래소에서 사 온 것도 받습니다.`,
  taskName: o => o.type === 'kill' ? `${o.region_name || ''}에서 ${o.kind_name || o.name} 요괴 물리치기` : o.act === 'win' ? '탐사에서 토벌 이기기' : `탐사 토벌에서 「${o.name}」`,
  taskUnit: o => o.type === 'kill' ? '마리' : '번',
  countRule: REGULAR_COUNT,
  actHelp: {
    analysis: () => `요괴가 수법 낌새를 보인 턴(전투 화면에 요괴의 수법 이름과 낌새가 뜨는 턴)에 공격·방어·직업 기술·물품 가운데 무엇이든 한 번 하면 1번으로 셉니다. ${GD.jobSkills?.analyst?.name ? `암영 검객은 직업 기술 「${GD.jobSkills.analyst.name}」을(를) 쓸 때도 1번입니다. ` : ''}분석 기술 경험이 오르는 기준과 같아서, 이렇게 싸우면 분석 기술도 함께 오릅니다.`,
    guarding: () => '토벌 중 「방어」를 고른 횟수를 셉니다. 막기 기술 경험이 오르는 기준과 같습니다.',
    first_aid: () => `토벌 중 회복품을 쓰거나 ${GD.jobSkills?.medic?.name ? `의무관 「${GD.jobSkills.medic.name}」을(를) 쓴` : '응급 처치를 한'} 횟수를 셉니다. 응급 처치 기술 경험이 오르는 기준과 같습니다.`,
  },
  taskTip: o => `${o.type === 'act' && REGULAR.actHelp?.[o.act] ? REGULAR.actHelp[o.act]() + ' ' : ''}${REGULAR_COUNT} ${o.type === 'kill' ? `${o.region_name || '그 지역'}에서 이긴 토벌의 요괴가 ${o.kind_name || o.name} 갈래면 한 마리로 셉니다. 다른 지역에서 잡은 것은 세지 않습니다.` : o.act === 'win' ? '이긴 토벌 한 번이 한 번입니다.' : `이긴 토벌에서 「${o.name}」을(를) 한 횟수를 셉니다.`} 다 채우면 이 사람이 있는 곳에서 「보고」합니다.`,
  tip: () => `연담은 채집·제작 분야마다 한 사람씩 ${RG_CRAFT}명, 싸움 쪽 기술(분석·막기·응급 처치·지금 직업의 전투 기술)마다 한 사람씩 ${RG_FIGHT}명과 맺습니다. 날마다 사람마다 주문 ${RG.orders}개가 들어오고(내 그 분야 단계에 맞는 물품 — 싸움 쪽 연담은 탐사 행동·처치·물품 주문 하나씩), 한 주문은 하루 한 번 넘깁니다. 모든 연담을 합쳐 하루 ${RG.day_n}번까지 넘길 수 있습니다. 넘기면 그 분야 기술 경험(다음 단계까지 필요한 경험의 ${RG.xp.pct}%, 최소 ${RG.xp.min} — 우수품 ×${RG.xp.hq_mul})·전(시세 × 수량 × ${RG.gil.rate} + ${RG.gil.base})·친밀도 +${RG.aff.give}(우수품 +${RG.aff.hq})를 받습니다. 친밀도가 ${RG.aff.stages.slice(1).map(fmtN).join('·')}에 닿을 때마다 그 사람과의 이야기가 하나씩 열리고, 다섯째 이야기를 마치면 칭호와 기념품을 받습니다.`,
};

const KN = GD.kin || { cost: 300, talk_day: 10, gift_day: 1, fx_h: 24, rebond_h: 24, reward: { pct: 50, n: 2 }, faded: '빛바랜 정표', npcs: {} };
export const KIN = {
  ...KN,
  tip: () => `연담 다섯째 이야기를 마친 사람과 백년지기를 맺을 수 있습니다(한 사람에 한 인물). 그 사람이 있는 곳에서 정표 짓는 값 ${fmtN(KN.cost)}전을 내면 백년지기가 내 별채에 머뭅니다. 별채에서 하루 ${KN.talk_day}번 말을 걸 수 있고, 그날 첫 말 걸기부터 ${KN.fx_h}시간 동안 정표를 차고 있으면 회복 +5%·침식 −5%(연리 효과가 켜져 있으면 겹치지 않음). 정표는 연리 정표와 같은 칸이라 한 번에 하나만 찹니다. 선물은 하루 ${KN.gift_day}번 — 그 사람 분야의 물품이나 좋아하는 음식이면 가끔 답례(그 사람이 만든 물품 ${KN.reward.n}개)를 받습니다. 끊으면 정표는 「${KN.faded}」로 남고 친밀도·연담 주문은 그대로이며, ${KN.rebond_h}시간 뒤에 다시 맺을 수 있습니다.`,
  giftTip: (name, line, npc) => { const f = KN.npcs?.[npc]?.food; return `하루 한 번 건넬 수 있습니다. ${line ? `${name}의 분야(${line}) 물품이면 특별히 반기고, 가끔 답례를 받습니다.` : ''}${f ? ` 좋아하는 음식 「${f}」을(를) 건네면 답례를 받을 때가 더 많습니다.` : ''}`; },
  mineTip: `별채에서 말을 걸면 그날부터 ${KN.fx_h}시간 회복 +5%·침식 −5%(정표를 찼을 때).`,
  offer: (name, token, cost, again) => `${name}과(와) ${again ? '다시 ' : ''}백년지기를 맺을 수 있습니다. 정표 「${token}」을(를) 짓는 값 ${fmtN(cost)}전.`,
  makeAsk: (name, token, cost) => `${fmtN(cost)}전을 내고 ${name}과(와) 백년지기를 맺을까요? 정표 「${token}」을(를) 나눠 갖고, ${name}이(가) 내 별채에 머뭅니다.`,
  breakAsk: (name, token) => `${name}과(와)의 백년지기를 끊을까요? ${name}은(는) 별채를 떠나고 정표 「${token}」은(는) 「${KN.faded}」로 남습니다. 친밀도와 연담 주문은 그대로이고, ${KN.rebond_h}시간 뒤에 다시 맺을 수 있습니다.`,
  left: n => `오늘 말 걸기 ${n}번 남음`,
};

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

export const ARC_NAME = { '귀허도': '요인록' };
export const storyArcOf = cat => { const [a, b] = String(cat || '').split('·'); return a === '외전' ? (ARC_NAME[b] || b || '') : ''; };
export const storyChapterNo = id => +((/^(?:gq|mkq|mdq|hwq)_(\d+)$/.exec(id || '') || [])[1] || 0);
export const isStoryMain = q => q?.kind === 'main' || q?.quest_id === 'fq_sealed_lord' || storyChapterNo(q?.quest_id) > 0;
export const STORY_ARCS = ['홍인사', '요인록', '묵적록', '명등기', '도해록'];
export const STORY_OTHER = '그 밖';
export const storyTabOf = story => (/^(\S+) \d+장$/.exec(story || '') || [])[1] || STORY_OTHER;

const WRK = GD.weaponRank?.steps || [[1, 1], [10, 5], [14, 10], [20, 15], [32, 25], [42, 33], [47, 38]];
export const weaponRankNeed = lv => { let n = 1; for (const [l, r] of WRK) if (Number(lv || 1) >= l) n = r; return n; };
export const WEAPON_RANK = {
  steps: WRK,
  keep: (line, need, have) => `지금 ${line} ${have}단계라 이 무기의 기준(${need}단계)에 못 미칩니다. 끼고 있는 동안은 그대로 쓰지만, 내려놓으면 ${line} ${need}단계가 되기 전에는 다시 낄 수 없습니다.`,
};
export const SPAR_WATCH = (r => ({
  keepMin: r.keep_min ?? 10, step: r.step_ms ?? 550,
  band: n => `비무 ${n}판 · 관전`, live: '겨루는 중', done: w => w ? `끝남 · ${w} 승` : '끝남',
  tip: '관전 중입니다. 같은 곳에서 벌어진 비무는 끝난 뒤에도 잠시 다시 볼 수 있습니다.',
  listTip: `이 지역에서 ${r.keep_min ?? 10}분 안에 벌어진 비무입니다. 골라서 보세요.`,
  gone: '볼 수 없는 비무입니다. 그 지역을 떠났거나 시간이 지났습니다.',
}))(GD.sparWatch || {});
export const TRAVEL_FAMILIAR = (f => ({
  ...f,
  pct: r => Math.max(0, Math.round((Number(r?.travel_discount) || 0) * 100)),
  tag: n => `익숙한 곳 −${n}%`,
  routeTag: n => `익숙한 길 −${n}%`,
  routeTip: n => `지나는 구간 가운데 익숙한 지역으로 들어가는 구간이 빨라져, 이번 길 전체가 ${n}% 줄었습니다(예상 시간에 이미 들어 있음).`,
  tip: n => `이 지역을 자주 탐색해 길이 익숙합니다. 이 지역으로 들어가는 구간의 이동 시간이 ${n}% 줄어듭니다(최대 ${f.cap}%).`,
  line: `자주 탐색한 지역은 지날 때 이동이 빨라집니다. 그 지역에서 탐색한 시간마다(한 시간에 한 번 셈) 그 지역으로 들어가는 구간이 ${f.per}%씩, 최대 ${f.cap}%까지 줄어듭니다. 지도에서 지역을 고르면 「익숙한 곳 −n%」로 보입니다.`,
}))(GD.travel?.fam || { per: 6, cap: 30 });
const DHB = GD.boss?.dohaesu || {}, DUB = GD.boss?.ttangul || {}, DHb = DHB.board || {}, DUb = DUB.board || {};
const SEA_PH = B => Object.fromEntries((B.phases || []).map((p, i) => [i + 1, p]));
export const SEA_BOSS = {
  dohaesu: {
    boss: { name: DHB.name || '도해수', arc: `본편 · ${DHB.arc || '도해록'}`, place: DHB.place || '뒤집힌 물목', PHASE: SEA_PH(DHB), last: (DHB.phases || [])[3] || '틈의 숨', mechs: [],
      calm: '도해수가 틈 속에서 낮게 운다. 물이 판 가장자리를 핥는다.', tray: '뒤집힌 물목에서 쓸 물품', win: '도해수를 바다로 돌려보냈습니다', lose: '틈의 물살에 밀려났습니다', open: '뒤집힌 물목 앞에 서기', killed: '돌려보낸 횟수',
      wonTag: '돌려보냄', lostTag: '밀려남', hpName: '도해수', after: { won: '틈에서 빠져나온 도해수가 물살을 타고 제 바다로 돌아갔습니다.', lost: '도해수는 아직 틈에 끼어 버둥대고, 물목은 거꾸로 돕니다.' },
      desc: '쪽빛 바다 네 칸 네 줄, 가운데 네 칸은 갈라진 틈입니다. 틈에 끼어 버둥대는 바다 거인을 떼어 내 제 바다로 돌려보내는 싸움입니다. 이야기판은 혼자서도, 깊은 판은 같은 곳의 파티원 둘에서 넷이 함께 섭니다.', ask: 'dh',
      story: `이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 입장 물품이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다. 틈에 빨려 들어도 떨어지지 않고 체력 ${DHB.story?.board?.fall_hp ?? 40}을 잃은 채 모서리로 돌아옵니다.`,
      hard: `${DHB.modes?.hard || '깊은 물목'} · 라운드마다 마감이 있고 수법이 거셉니다(둘에서 넷). 모두 ${DHB.item_name || '입장 물품'}을 하나씩 쓰고, 틈에 빨려 들면 그 싸움에서 빠져 다시 돌아올 수 없습니다. 지면 장비가 닳고 침식이 오릅니다.` },
    ask: {
      tail: `싸움은 ${DHB.min ?? 18}분 동안 라운드마다 행동 하나를 고르고, 가로·세로 이웃 칸으로 한 칸씩 옮겨 설 수 있습니다. 해류에 밀려 가운데 틈으로 들어가면 그 싸움에서 빠지고 다시 돌아올 수 없습니다. 지면 장착 장비 내구도가 ${DHB.fail?.dur ?? 10}% 깎이고 침식이 ${DHB.fail?.er ?? 10} 오르며, ${DHB.fail?.cd ?? 30}분 뒤에야 다시 도전할 수 있습니다.`,
      1: ['혼자서는 깊은 물목에 설 수 없습니다', `깊은 물목은 ${DHB.hard_min ?? 2}명 이상이 함께해야 합니다. 혼자라면 이야기판에 서세요.`, '돌아가기'],
      2: '둘이서는 열 번에 다섯 번쯤 이기는 싸움입니다. 머리 칸에 누가 설지 미리 정해 두세요.',
      3: '셋이면 한결 수월합니다. 머리 칸에 설 사람과 물보라를 피해 칠 사람을 나누세요.',
      4: '넷이 함께하는 것이 도해수에게 가장 알맞은 인원입니다.',
      call: n => `같은 곳의 파티원 ${n - 1}명에게 합류 알림이 갑니다(60초 안에 합류, 함께 ${n}명).`, ok: '뒤집힌 물목 앞에 서기', name: '도전',
    },
    act: { guide: '길 알려 주기' },
    gim: {
      head: '물목',
      guide: c => `머리 칸(${c}번)에 서서, 도해수가 머리를 드는 라운드(!)에 바다 쪽 길을 알려 줍니다(공격 대신). 제때 알려 주면 크게 휘청이고, 젖은 몸이 마릅니다.`,
      off: c => `머리 칸(${c}번)에 서야 길을 알려 줄 수 있습니다. 머리 칸으로 옮겨 서는 라운드에도 누를 수 있습니다.`,
      breath: '절반 넘게 머리 칸에 모여 「길 알려 주기」를 해야 막힙니다. 막지 못하면 버티지 않은 사람은 가운데로 끌려갑니다.',
    },
    hz: { current: '해류', surge: '뒤집힌 해류', spray: '물보라', tentacle: '촉수', whirl: '소용돌이 기둥', head: '머리', breath: '틈의 숨' },
    cell: { rift: `틈 · 서 있으면 받는 피해 +${DHb.rift_hurt ?? 20}%, 밀려 들어가면 빨려 듦`, head: '머리 칸', sea: '바다' },
    wet: n => `젖은 몸 ${n}/${DHb.wet?.max ?? 3}`,
    wetTip: `물살·물보라에 젖을 때마다 한 겹, ${DHb.wet?.extra_at ?? 3}겹이면 물살에 한 칸 더 밀립니다. 머리 칸에서 길을 알려 주면 마릅니다.`,
    tent: d => `촉수 거리 ${d}칸 · ${(DHb.tentacle?.dist ?? 4) - 1}칸 넘게 떨어지면 끊김`,
    stun: n => `도해수가 휘청임 · ${n}라운드 동안 더 아프게 맞음`,
  },
  ttangul: {
    boss: { name: DUB.name || '땅울이', arc: `본편 · ${DUB.arc || '도해록'}`, place: DUB.place || '고임터', PHASE: SEA_PH(DUB), last: (DUB.phases || [])[3] || '판 깎기', mechs: [],
      calm: '땅울이가 낮게 운다. 돌판 밑으로 흐름이 꿈틀거린다.', tray: '고임터에서 쓸 물품', win: '땅울이를 잠재웠습니다', lose: '고임 구덩이로 밀려났습니다', open: '고임터 돌판에 서기', killed: '잠재운 횟수',
      wonTag: '잠재움', lostTag: '밀려남', hpName: '땅울이', after: { won: '막혔던 흐름이 돌판 밑으로 빠져나가고, 땅울이가 낮게 울다 잠들었습니다.', lost: '땅울이의 울음이 아직 고임터를 뒤덮고 있습니다.' },
      desc: '가운데 땅울이를 둘러싼 육각 돌판 열아홉 칸, 판 밖은 빛이 고인 깊은 구덩이입니다. 끌개를 멈추고 판 위에서 버텨 막힌 흐름을 되돌리는 싸움입니다. 이야기판은 혼자서도, 깊은 판은 같은 곳의 파티원 둘에서 넷이 함께 섭니다.', ask: 'du',
      story: `이야기판 · 누구든 깰 수 있는 쉬운 판입니다. 마감이 없고(여럿이면 1분), 입장 물품이 필요 없고, 회복품도 마음껏 쓰며 밀려나도 잃는 것이 없습니다. 구덩이로 미끄러져도 떨어지지 않고 체력 ${DUB.story?.board?.fall_hp ?? 40}을 잃은 채 기어 올라옵니다.`,
      hard: `${DUB.modes?.hard || '깊은 고임터'} · 라운드마다 마감이 있고 수법이 거셉니다(둘에서 넷). 모두 ${DUB.item_name || '입장 물품'}을 하나씩 쓰고, 구덩이로 떨어지면 그 싸움에서 빠져 다시 돌아올 수 없습니다. 지면 장비가 닳고 침식이 오릅니다.` },
    ask: {
      tail: `싸움은 ${DUB.min ?? 18}분 동안 라운드마다 행동 하나를 고르고, 이웃 칸으로 한 칸씩 옮겨 설 수 있습니다. 판 밖이나 무너진 칸으로 밀리면 고임 구덩이로 떨어져 그 싸움에서 빠지고 다시 돌아올 수 없습니다. 지면 장착 장비 내구도가 ${DUB.fail?.dur ?? 10}% 깎이고 침식이 ${DUB.fail?.er ?? 10} 오르며, ${DUB.fail?.cd ?? 30}분 뒤에야 다시 도전할 수 있습니다.`,
      1: ['혼자서는 깊은 고임터에 설 수 없습니다', `깊은 고임터는 ${DUB.hard_min ?? 2}명 이상이 함께해야 합니다. 혼자라면 이야기판에 서세요.`, '돌아가기'],
      2: '둘이서는 열 번에 다섯 번쯤 이기는 싸움입니다. 쐐기돌을 누가 주울지 미리 정해 두세요.',
      3: '셋이면 한결 수월합니다. 끌개를 멈출 사람과 땅울이를 칠 사람을 나누세요.',
      4: '넷이 함께하는 것이 땅울이에게 가장 알맞은 인원입니다.',
      call: n => `같은 곳의 파티원 ${n - 1}명에게 합류 알림이 갑니다(60초 안에 합류, 함께 ${n}명).`, ok: '고임터 돌판에 서기', name: '도전',
    },
    act: { stop: '끌개 멈추기' },
    gim: {
      head: '고임터',
      stop: c => `${c}번 끌개 칸에서, 끌개가 도는 라운드(!)에 쐐기돌을 박아 멈춥니다(공격 대신). 제때 박으면 끌개가 한동안 멈추고 땅울이가 크게 휘청입니다.`,
      noWedge: '쐐기돌을 먼저 주워 드세요. 쐐기돌이 놓인 칸으로 옮겨 서면 저절로 줍습니다(한 사람 하나).',
      noPull: '끌개 칸(바깥 고리의 돌림대)에 서야 합니다. 끌개 칸으로 옮겨 서는 라운드에도 누를 수 있습니다.',
      carry: '쐐기돌을 들고 있음',
      brace: '「버티기」를 고르면 밀림이 한 칸 줄어듭니다.',
      final: n => `마지막 몸부림 · ${n}라운드 남음 — 돌판이 기울 때마다 모두 버텨야 제자리에 남습니다.`,
    },
    hz: { pull: '끌개', slide: '산사태', weight: '땅의 무게', fist: '돌주먹', boulder: '굴러오는 바위', shave: '판 깎기', tilt: '기우는 돌판' },
    cell: { core: '가운데 · 땅울이(설 수 없음)', hole: n => `무너진 자리 · ${n}라운드 뒤 메워짐(디디면 떨어짐)`, pit: '영영 무너진 구덩이(디디면 떨어짐)', cracked: '금 간 칸 · 한 번 더 무너지면 영영 구덩이', wedge: '쐐기돌 · 옮겨 서면 주움', pull: '끌개', inner: '안쪽 고리', outer: '바깥 고리', stopped: n => `끌개 멈춤 · ${n}라운드` },
  },
  common: {
    fell: '떨어짐',
    fellLong: '떨어짐 · 이 싸움에는 돌아올 수 없음',
    fellRes: '이 싸움에서 떨어짐',
    fellStory: n => `이야기판에서는 떨어지지 않고 체력 ${n}을 잃은 채 돌아옵니다.`,
    pushed: '밀림',
    cut: (pct, n) => `체력 ${pct}%까지 ${n}라운드 안에`,
    cutLate: n => `제때 달래지 못함 · 받는 피해 +${n}겹`,
    gimTip: p => `${p}에서 늘 쓰는 행동`,
    step: '테 두른 이웃 칸을 누르면 이번 라운드에 옮겨 섭니다(행동과 따로)',
    stepTo: c => `${c}번 칸으로 옮겨 섭니다 · 내 칸을 누르면 취소`,
    solo: n => `깊은 판은 ${n}명 이상이 함께해야 합니다. 혼자라면 이야기판에 서세요.`,
  },
};

export const PET_SKIN = {
  noPet: '바탕 동무가 있어야 고를 수 있음',
  basic: '바탕 동무가 있으면 누구나 고를 수 있음',
  got: '얻음',
  can: '고를 수 있음',
  prog: (n, need) => `${Number(n || 0).toLocaleString()} / ${Number(need || 0).toLocaleString()}`,
  book: '무늬 모음',
  bookHelp: '건넛누리 권역 활동으로 무늬를 얻습니다. 얻은 무늬는 기록에 남아, 바탕 동무가 없어도 그 동무를 얻는 대로 바로 고를 수 있습니다. 운에 맡기는 길은 없고, 거래할 수 없습니다.',
  guide: '건넛누리의 무늬는 권역 활동(이야기·답사·보조 퀘스트·교역·등불·잔칫상·습격·원정·도감·우두머리)으로 얻습니다. 얻는 길과 진행은 동무 창의 「무늬 모음」에 보이고, 얻으면 알림이 옵니다. 바탕 동무가 없어도 기록은 남아, 그 동무를 얻으면 바로 고를 수 있습니다.',
};
