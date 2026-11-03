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
};
export const PARTY_EXP = {
  who: '「파티 원정」으로 함께 떠난 동료',
  apart: '각자 따로 떠난 원정은 같은 때·같은 곳이어도 각자 싸웁니다',
  fight: `회차마다 한 싸움을 함께 치릅니다. 요괴는 인원만큼 나오고(둘이면 2:2) 동료 한 명마다 위협 +${PX.threat_pct}%, 승패는 함께 정해지며, 요괴는 이목이 높은 사람을 더 자주 노립니다. 기를 모아 터뜨리거나 휩쓰는 수법은 모두를 칩니다`,
  flee: `누구든 체력이 ${PX.flee_hp} 아래면 그 싸움에서는 모두 함께 물러납니다`,
  bonus: `「파티 원정」으로 함께 떠나 ${PX.overlap_min}분 넘게 같이 다닌 동료 한 명마다 귀환 때 경험치·숙련 경험 +${PX.bonus_pct}%(${PX.bonus_cap}명까지)`,
};
