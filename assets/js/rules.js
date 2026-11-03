import { GAMEDATA as GD } from './gamedata.js';

const PX = GD.partyExp || { flee_hp: 30, threat_pct: 45, bonus_pct: 10, bonus_cap: 3, overlap_min: 10 };

export const EXP_ROUNDS = { 30: 3, 60: 6, 120: 10, 240: 16, 480: 24 };
export function expRoundOf(exp, now = Date.now()) {
  if (!exp?.started_at || !exp?.ends_at) return 0;
  const s = new Date(exp.started_at).getTime(), e = new Date(exp.ends_at).getTime(), total = EXP_ROUNDS[exp.minutes] || 24;
  return Math.max(0, Math.min(total, Math.floor(total * (Math.min(now, e) - s) / (e - s))));
}

export const PARTY_EXP = {
  who: '「파티 원정」으로 함께 떠난 동료',
  apart: '각자 따로 떠난 원정은 같은 때·같은 곳이어도 각자 싸웁니다',
  fight: `회차마다 한 싸움을 함께 치릅니다. 요괴는 인원만큼 나오고(둘이면 2:2) 동료 한 명마다 위협 +${PX.threat_pct}%, 승패는 함께 정해지며, 요괴는 이목이 높은 사람을 더 자주 노립니다. 기를 모아 터뜨리거나 휩쓰는 수법은 모두를 칩니다`,
  flee: `누구든 체력이 ${PX.flee_hp} 아래면 그 싸움에서는 모두 함께 물러납니다`,
  bonus: `「파티 원정」으로 함께 떠나 ${PX.overlap_min}분 넘게 같이 다닌 동료 한 명마다 귀환 때 경험치·숙련 경험 +${PX.bonus_pct}%(${PX.bonus_cap}명까지)`,
};
