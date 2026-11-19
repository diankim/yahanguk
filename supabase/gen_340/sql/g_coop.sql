create or replace function public.world_eff_as(p_uid uuid, p_key text) returns numeric
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare os text := current_setting('request.jwt.claim.sub', true); oc text := current_setting('request.jwt.claims', true); v numeric;
begin
  perform set_config('request.jwt.claim.sub', p_uid::text, true);
  perform set_config('request.jwt.claims', json_build_object('sub', p_uid, 'role', 'authenticated')::text, true);
  v := coalesce(public.world_status_effect_total(p_key), 0);
  perform set_config('request.jwt.claims', coalesce(oc, ''), true);
  perform set_config('request.jwt.claim.sub', coalesce(os, ''), true);
  return v;
end $$;
select pg_temp.yh_own('public.world_eff_as(uuid, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_eff_as(uuid, text)');

create or replace function public.world_leech_of(p_uid uuid, p_dmg numeric) returns integer
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  if coalesce(p_dmg, 0) <= 0 then return 0; end if;
  return least(case when 'bloodcraft_m50' = any (public.world_skill_procs(p_uid)) then 8 else 4 end,
               greatest(1, round(p_dmg * (5 + least(6, public.world_eff_as(p_uid, 'leech_pct'))) / 100.0)))::int;
end $$;
select pg_temp.yh_own('public.world_leech_of(uuid, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_leech_of(uuid, numeric)');

create or replace function public.world_shield_amt(p_uid uuid, p_amt numeric) returns integer
 language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return round(coalesce(p_amt, 0) * (1 + least(40, public.world_eff_as(p_uid, 'shield_pct')) / 100.0)
    * case when 'bloodcraft_c13b' = any (public.world_skill_procs(p_uid)) then 1.5 else 1 end)::int;
end $$;
select pg_temp.yh_own('public.world_shield_amt(uuid, numeric)', 'fn_owner_field');
select pg_temp.yh_share('public.world_shield_amt(uuid, numeric)');

insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
('bk_drink', 'bloodknight', 3, '피 갈무리', '세 번의 공격이 20% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 20}', 4, 10, 0.04, 0, '흘린 피를 다잡아 도끼에 힘을 실었습니다', 401),
('bk_mantle', 'bloodknight', 8, '갑주 나눠 주기', '동료 하나에게 보호막 30을 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 30}', 6, 15, 0.04, 0, '동료 앞에 서서 피 갑주를 나눠 둘렀습니다', 402),
('bk_brace', 'bloodknight', 18, '버티는 기세', '세 번 받는 피해를 30% 줄입니다.', 'self', '{"type": "ward", "n": 3, "pct": 30}', 8, 20, 0.05, 0, '무릎을 꿇지 않고 버텼습니다', 403),
('bk_undying', 'bloodknight', 36, '꺾이지 않는 몸', '세 번 동안 요괴를 끌어당기고 받는 피해를 40% 줄입니다.', 'self', '{"type": "taunt", "n": 3, "pct": 40, "pres": 100}', 12, 30, 0.07, 0, '요괴를 제게로 끌어당겨 버텼습니다', 404),
('sp_aim', 'spearman', 3, '창끝 겨누기', '요괴가 받는 피해가 두 번 12% 늘어납니다.', 'boss', '{"type": "expose", "n": 2, "pct": 12}', 4, 10, 0.04, 0, '창끝으로 요괴의 빈틈을 짚었습니다', 411),
('sp_wall', 'spearman', 8, '창벽', '두 번 공격을 40% 확률로 흘립니다.', 'self', '{"type": "evade", "n": 2, "pct": 40}', 5, 12, 0.04, 0, '창 자루로 공격을 흘려 냈습니다', 412),
('sp_hook', 'spearman', 18, '자루 걸기', '요괴가 모으는 기운을 늦춥니다.', 'boss', '{"type": "delay", "n": 2}', 9, 22, 0.06, 0, '창 자루로 요괴의 발을 걸었습니다', 413),
('sp_charge', 'spearman', 36, '새벽 돌격', '내달려 찌르면서(이 기술이 곧 공격) 그 공격부터 세 번이 35% 강해집니다.', 'self', '{"type": "might", "n": 3, "pct": 35, "strike": true}', 14, 30, 0.07, 0, '새벽빛처럼 앞으로 내달렸습니다', 414),
('fm_point', 'formation', 3, '방위 진', '동료 하나에게 보호막 25를 둘러 줍니다.', 'ally', '{"type": "shield", "amt": 25}', 4, 8, 0.04, 0, '다칠 방위를 셈해 진을 쳐 두었습니다', 421),
('fm_gate', 'formation', 8, '팔문 진', '모두 세 번 받는 피해를 15% 줄입니다.', 'all', '{"type": "ward_all", "n": 3, "pct": 15}', 8, 20, 0.05, 0, '여덟 문을 닫아 모두를 감쌌습니다', 422),
('fm_reckon', 'formation', 18, '셈 맞추기', '이번 수법 피해를 모두 절반으로 줄입니다.', 'all', '{"type": "break", "pct": 50}', 10, 20, 0.06, 0, '요괴의 수를 미리 셈해 피해를 덜었습니다', 423),
('fm_nine', 'formation', 36, '구궁 진', '모두에게 보호막 20을 둘러 줍니다.', 'all', '{"type": "shield_all", "amt": 20}', 14, 30, 0.07, 0, '아홉 칸 진으로 모두를 감쌌습니다', 424)
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
      perform set_config('yh.leech', public.world_leech_of(uid, dmg)::text, true);
    end if;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;$q$,
  $q$        if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + d; end if;
        boss_dmg := boss_dmg + d;
        if m.job_key = 'bloodknight' and d > 0 then
          update public.world_gw_members set hp = least(100, hp + public.world_leech_of(m.owner_id, d)) where fight_id = p_fight and owner_id = m.owner_id and out_rounds = 0 and hp > 0;
        end if;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$  if act = 'attack' then
    if st ->> 'style' = 'magic' then$q$,
  $q$  if c.job_key = 'spearman' and act not in ('attack', 'coop') then f := f - 'spch'; end if;
  if act = 'attack' then
    if st ->> 'style' = 'magic' then$q$,
  $q$    mul := mul * psolo;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;$q$,
  $q$    mul := mul * psolo;
    if c.job_key = 'spearman' and st ->> 'style' = 'melee' then
      mul := mul * public.world_spear_mul(uid, coalesce((f ->> 'spch')::int, 0), rd.hp, rd.max_hp);
      f := f || jsonb_build_object('spch', least((public.world_spear_rules() ->> 'max')::int, coalesce((f ->> 'spch')::int, 0) + 1));
    end if;
    dmg := greatest(1, round((cbr ->> 'd')::numeric * mul))::int;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if av = 'attack' then$q$,
  $q$    select coalesce(x.fx, '{}'::jsonb) into vfx from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id;
    if m.job_key = 'spearman' and coalesce(m.act ->> 'a', 'guard') not in ('attack', 'coop') and vfx ? 'spch' then
      vfx := vfx - 'spch'; update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
    end if;
    if av = 'attack' then$q$,
  $q$      if f.mode = 'ultimate' and m.weak <> '[]'::jsonb then d := d * (public.world_ug_weak(p_fight, m.owner_id) ->> 'deal')::numeric; end if;$q$,
  $q$      if f.mode = 'ultimate' and m.weak <> '[]'::jsonb then d := d * (public.world_ug_weak(p_fight, m.owner_id) ->> 'deal')::numeric; end if;
      if m.job_key = 'spearman' and coalesce(m.stats ->> 'style', 'melee') = 'melee' then
        d := d * public.world_spear_mul(m.owner_id, coalesce((vfx ->> 'spch')::int, 0), f.hp, f.max_hp);
        vfx := vfx || jsonb_build_object('spch', least((public.world_spear_rules() ->> 'max')::int, coalesce((vfx ->> 'spch')::int, 0) + 1));
        update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
      end if;$q$]);

select pg_temp.yh_fix('world_raid_action', array[
  $q$  update public.world_characters set spiritual_power = sp, inventory = inv, updated_at = now() where owner_id = uid;$q$,
  $q$  update public.world_characters set spiritual_power = sp, inventory = inv,
    health = case when health > 0 then least(100, health + coalesce(nullif(current_setting('yh.leech', true), '')::int, 0)) else health end, updated_at = now() where owner_id = uid;
  perform set_config('yh.leech', '', true);$q$,
  $q$    k := sk.effect ->> 'type'; v := sk.effect;$q$,
  $q$    k := sk.effect ->> 'type'; v := sk.effect;
    if k in ('shield', 'shield_all') and v ? 'amt' then v := v || jsonb_build_object('amt', public.world_shield_amt(uid, (v ->> 'amt')::numeric)); end if;$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
  $q$    if e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$q$,
  $q$    if e ? 'amt' and e ->> 'type' in ('shield', 'shield_all') then
      e := e || jsonb_build_object('amt', public.world_shield_amt(m.owner_id, (e ->> 'amt')::numeric));
    elsif e ? 'amt' then
      e := e || jsonb_build_object('amt', round((e ->> 'amt')::int * (1 + coalesce((select (x.skill_progress -> 'first_aid' ->> 'rank')::int from public.world_characters x where x.owner_id = m.owner_id), 0) / 100.0)));
    end if;$q$]);

select pg_temp.yh_fix('world_gw_hurt', array[
  $q$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg); v_n int; v_out int;$q$,
  $q$declare m public.world_gw_members%rowtype; d int := greatest(0, p_dmg); v_n int; v_out int; bk public.world_gw_members%rowtype;$q$,
  $q$  if m.hp - d <= 0 then
    -- $q$,
  $q$  if m.hp - d <= 0 and m.hp > 1 then
    select * into bk from public.world_gw_members w where w.fight_id = p_fight and w.owner_id <> p_uid and w.job_key = 'bloodknight' and w.out_rounds = 0 and not w.rest and w.hp > 20
       and not coalesce((w.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(w.owner_id)) order by w.joined_at limit 1 for update;
    if found then
      update public.world_gw_members set hp = hp - 20, taken = taken + 20, fx = fx || '{"oath": true}'::jsonb where fight_id = p_fight and owner_id = bk.owner_id;
      perform public.world_gw_credit(p_fight, bk.owner_id, d - (m.hp - 1), 'guard');
      d := m.hp - 1;
      perform public.world_gw_say(p_fight, p_round, 'good', bk.name || ' — 「피로 잇는 맹세」 제 피 20을 내어 ' || m.name || '을(를) 버티게 했습니다.');
    end if;
  end if;
  if m.hp - d <= 0 then
    -- $q$]);

select pg_temp.yh_fix('world_raid_hit', array[
  $q$nm text; absorb int;$q$,
  $q$nm text; absorb int; v_bko uuid; v_d0 int;$q$,
  $q$  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;$q$,
  $q$  if d > 0 and (select ch.health from public.world_characters ch where ch.owner_id = who) - d <= 1 then
    perform 1 from public.world_raid_members bm join public.world_characters bc on bc.owner_id = bm.owner_id
     where bm.raid_id = p_raid and bm.owner_id <> who and bc.job_key = 'bloodknight' and bc.health > 21 and bm.out_until is null and bm.left_at is null
       and not coalesce((bm.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(bm.owner_id)) limit 1;
    if found then
      with b as (select bm.owner_id from public.world_raid_members bm join public.world_characters bc on bc.owner_id = bm.owner_id
                  where bm.raid_id = p_raid and bm.owner_id <> who and bc.job_key = 'bloodknight' and bc.health > 21 and bm.out_until is null and bm.left_at is null
                    and not coalesce((bm.fx ->> 'oath')::boolean, false) and 'bloodcraft_c43b' = any (public.world_skill_procs(bm.owner_id)) order by bm.owner_id limit 1),
           u1 as (update public.world_raid_members x set fx = x.fx || '{"oath": true}'::jsonb, taken = x.taken + 20 from b where x.raid_id = p_raid and x.owner_id = b.owner_id returning x.owner_id)
      update public.world_characters ch set health = ch.health - 20, updated_at = now() from u1 where ch.owner_id = u1.owner_id returning ch.owner_id into v_bko;
      v_d0 := d;
      d := greatest(0, (select ch.health from public.world_characters ch where ch.owner_id = who) - 2);
      perform public.world_raid_credit(p_raid, v_bko, v_d0 - d, 'guard');
      perform public.world_raid_say_n(p_raid, 'good', nm || ' — 「피로 잇는 맹세」로 쓰러지지 않고 버텼습니다.', nm, 0);
    end if;
  end if;
  update public.world_characters set health = greatest(1, health - d), updated_at = now() where owner_id = who returning health into hp;$q$]);
