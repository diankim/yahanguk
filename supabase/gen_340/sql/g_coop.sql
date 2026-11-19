insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
('bk_drink', 'bloodknight', 3, '피 갈무리', '세 번의 공격이 20% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 20}', 4, 10, 0.04, 0, '[피 갈무리] 흘린 피를 다잡아 도끼에 힘을 실었습니다', 401),
('bk_mantle', 'bloodknight', 8, '갑주 나눠 주기', '동료 하나에게 보호막 30을 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 30}', 6, 15, 0.04, 0, '[갑주 나눠 주기] 동료 앞에 서서 피 갑주를 나눠 둘렀습니다', 402),
('bk_brace', 'bloodknight', 18, '버티는 기세', '세 번 받는 피해를 30% 줄입니다.', 'self', '{"type": "ward", "n": 3, "pct": 30}', 8, 20, 0.05, 0, '[버티는 기세] 무릎을 꿇지 않고 버텼습니다', 403),
('bk_undying', 'bloodknight', 36, '꺾이지 않는 몸', '세 번 동안 요괴를 끌어당기고 받는 피해를 40% 줄입니다.', 'self', '{"type": "taunt", "n": 3, "pct": 40, "pres": 100}', 12, 30, 0.07, 0, '[꺾이지 않는 몸] 요괴를 제게로 끌어당겨 버텼습니다', 404),
('sp_aim', 'spearman', 3, '창끝 겨누기', '요괴가 받는 피해가 두 번 12% 늘어납니다.', 'boss', '{"type": "expose", "n": 2, "pct": 12}', 4, 10, 0.04, 0, '[창끝 겨누기] 창끝으로 요괴의 빈틈을 짚었습니다', 411),
('sp_wall', 'spearman', 8, '창벽', '두 번 공격을 40% 확률로 흘립니다.', 'self', '{"type": "evade", "n": 2, "pct": 40}', 5, 12, 0.04, 0, '[창벽] 창 자루로 공격을 흘려 냈습니다', 412),
('sp_hook', 'spearman', 18, '자루 걸기', '요괴가 모으는 기운을 늦춥니다.', 'boss', '{"type": "delay", "n": 2}', 9, 22, 0.06, 0, '[자루 걸기] 창 자루로 요괴의 발을 걸었습니다', 413),
('sp_charge', 'spearman', 36, '새벽 돌격', '세 번의 공격이 35% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 35}', 14, 30, 0.07, 0, '[새벽 돌격] 새벽빛처럼 앞으로 내달렸습니다', 414),
('fm_point', 'formation', 3, '방위 진', '동료 하나에게 보호막 25를 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 25}', 4, 8, 0.04, 0, '[방위 진] 다칠 방위를 셈해 진을 쳐 두었습니다', 421),
('fm_gate', 'formation', 8, '팔문 진', '모두 세 번 받는 피해를 15% 줄입니다.', 'all', '{"type": "ward_all", "n": 3, "pct": 15}', 8, 20, 0.05, 0, '[팔문 진] 여덟 문을 닫아 모두를 감쌌습니다', 422),
('fm_reckon', 'formation', 18, '셈 맞추기', '이번 수법 피해를 모두 절반으로 줄입니다.', 'all', '{"type": "break", "pct": 50}', 10, 20, 0.06, 0, '[셈 맞추기] 요괴의 수를 미리 셈해 피해를 덜었습니다', 423),
('fm_nine', 'formation', 36, '구궁 진', '모두에게 보호막 20을 둘러 줍니다.', 'all', '{"type": "shield_all", "amt": 20}', 14, 30, 0.07, 0, '[구궁 진] 아홉 칸 진으로 모두를 감쌌습니다', 424)
on conflict (skill_id) do update set job_key = excluded.job_key, unlock_rank = excluded.unlock_rank, skill_name = excluded.skill_name, description = excluded.description,
  target = excluded.target, effect = excluded.effect, cost = excluded.cost, cooldown_s = excluded.cooldown_s, exp_win = excluded.exp_win, exp_text = excluded.exp_text, sort = excluded.sort;

select pg_temp.yh_fix('world_raid_action', array[
  $q$    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);$q$,
  $q$    elsif k = 'shield_all' then
      update public.world_raid_members x set fx = x.fx || jsonb_build_object('shield', coalesce((x.fx ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid)
       where x.raid_id = p_raid and x.owner_id <> uid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id);
      f := f || jsonb_build_object('shield', coalesce((f ->> 'shield')::int, 0) + (v ->> 'amt')::int, 'shield_by', uid);
    elsif k = 'taunt' then
      f := f || public.world_cb_buff('taunt', v, uid);$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;$q$,
  $q$      when 'shield' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and owner_id = tgt and out_rounds = 0;
      when 'shield_all' then update public.world_gw_members set fx = fx || jsonb_build_object('shield', coalesce((fx ->> 'shield')::int, 0) + (e ->> 'amt')::int, 'shield_by', m.owner_id) where fight_id = p_fight and out_rounds = 0 and not rest;
      when 'cover' then update public.world_gw_members set fx = fx || jsonb_build_object('cover', tgt) where fight_id = p_fight and owner_id = m.owner_id;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;$q$,
  $q$    rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - dmg); mb.dmg := mb.dmg + dmg; credit := 0;
    if c.job_key = 'bloodknight' and dmg > 0 then
      update public.world_characters set health = least(100, health + least(6, greatest(1, round(dmg * (8 + public.world_status_effect_total('leech_pct')) / 100.0)))::int), updated_at = now()
       where owner_id = uid and health > 0 and health < 100;
    end if;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;$q$,
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        if m.job_key = 'bloodknight' and d > 0 then
          update public.world_gw_members set hp = least(100, hp + least(6, greatest(1, round(d * 0.1)))::int) where fight_id = p_fight and owner_id = m.owner_id and out_rounds = 0 and hp > 0;
        end if;$q$]);
