insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
  ('tm_fetch', 'tamer', 3, '물어 와', '동무를 보스에게 곧바로 보내 화살과 함께 한 번 공격한다. 이번 동무 공격은 두 배.', 'self', '{"type": "pet_strike", "strike": true, "x": 2}', 4, 8, 0.04, 0, '동무를 보내 요괴에게 달려들게 했습니다', 1),
  ('tm_guard', 'tamer', 8, '곁 지키기', '동무를 동료 곁에 보낸다. 그 동료를 노린 다음 두 번 공격의 피해 −30%(동무의 힘에 따라 줄어든다).', 'ally', '{"type": "ward", "n": 2, "pct": 30}', 5, 12, 0.04, 0, '동무를 동료 곁에 붙여 지키게 했습니다', 2),
  ('tm_herd', 'tamer', 18, '몰이', '동무가 보스 둘레를 돌며 몬다. 다음 반격 한 번을 막고, 보스가 받는 피해가 네 번 동안 +10%(동무의 힘에 따라 줄어든다, 봉연의 그림자에서는 사람이 많을수록 더 여러 번).', 'boss', '{"type": "expose", "n": 4, "pct": 10, "stagger": 1}', 9, 20, 0.06, 0, '동무가 요괴를 몰아 빈틈을 만들었습니다', 3),
  ('tm_pack', 'tamer', 36, '한 몸 사냥', '내 다음 세 번 공격 +25%(동무의 힘에 따라 줄어든다), 그동안 동무 공격은 두 배.', 'self', '{"type": "might", "n": 3, "pct": 25, "pet_x2": true}', 14, 30, 0.07, 0, '동무와 한 몸처럼 몰아쳤습니다', 4);
