select pg_temp.yh_fix('world_raid_action', array[
  $a$pd int; psolo numeric := 1;$a$, $a$pd int; psolo numeric := 1; nl0 int;$a$,
  $a$st := public.world_raid_stats(uid);$a$, $a$st := public.world_raid_stats(uid); nl0 := mb.heal;$a$,
  $a$    mul := mul * psolo;
$a$, $a$    mul := mul * psolo;
    if f ? 'stiff' then mul := mul * (1 - least(2, coalesce((f -> 'stiff' ->> 'n')::int, 0)) * coalesce((f -> 'stiff' ->> 'pct')::numeric, 0) / 100.0); end if;
    if rd.boss_key = 'neol' and rfx ? 'nopen' and (rfx -> 'nopen' ->> 'until')::numeric > extract(epoch from now()) then mul := mul * (1 + (rfx -> 'nopen' ->> 'pct')::numeric / 100.0); end if;
$a$,
  $a$    end if;
  elsif act = 'guard' then$a$, $a$    end if;
    if rd.boss_key = 'neol' and rfx ? 'nc' then rfx := public.world_neol_core_add(p_raid, rfx, uid, dmg + coalesce(pd, 0)); end if;
  elsif act = 'guard' then$a$,
  $a$    if rd.kind = 'world' then
      mk := public.world_shadow_rules() -> 'mk2';$a$, $a$    if rd.kind = 'world' and rd.boss_key = 'shadow' then
      mk := public.world_shadow_rules() -> 'mk2';$a$,
  $a$if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;$a$,
  $a$if act = 'coop' then perform public.world_raid_credit(p_raid, uid, 1, 'skill'); end if;
  if rd.boss_key = 'neol' then perform public.world_neol_after(p_raid, uid, act, mb.heal > nl0); end if;$a$,
  $a$mb.name || '의 일격에 ' || rd.boss_name || '이(가) 무너졌습니다.'$a$,
  $a$mb.name || '의 일격에 ' || rd.boss_name || case when rd.boss_key = 'neol' then '이(가) 흩어졌습니다. 고였던 물이 땅과 물로 돌아갑니다.' else '이(가) 무너졌습니다.' end$a$,
  $a$case newp when 2 then$a$, $a$case when rd.boss_key = 'neol' then public.world_neol_phase_line(rd.boss_name, newp) when newp = 2 then$a$,
  $a$'이(가) 모은 봉연의 기운을 터뜨립니다!'$a$, $a$'이(가) 모은 ' || case when rd.boss_key = 'neol' then '' else '봉연의 ' end || '기운을 터뜨립니다!'$a$,
  $a$'봉연의 사슬이 ' || nm$a$, $a$case when rd.boss_key = 'neol' then '굳은 물살이 ' else '봉연의 사슬이 ' end || nm$a$,
  $a$      if rd.kind = 'world' then update public.world_raid_members set fx = fx || jsonb_build_object('ink'$a$,
  $a$      if rd.kind = 'world' and rd.boss_key = 'shadow' then update public.world_raid_members set fx = fx || jsonb_build_object('ink'$a$,
  $a$and out_until is null; end if;
    end loop;$a$, $a$and out_until is null; end if;
    end loop;
    if rd.boss_key = 'neol' and rd.phase >= (public.world_neol_rules() -> 'mk2' -> 'dry' ->> 'from_phase')::int then perform public.world_neol_dry_on(p_raid, bt); end if;$a$,
  $a$(public.world_shadow_rules() -> 'mk2' ->> 'counter_mul')::numeric$a$, $a$(public.world_raid_boss_rules(p_raid) -> 'mk2' ->> 'counter_mul')::numeric$a$,
  $a$  if rd.kind = 'world' then
    mk := public.world_shadow_rules() -> 'mk2';$a$, $a$  if rd.kind = 'world' and rd.boss_key = 'neol' then
    rfx := public.world_neol_beat(p_raid, rfx, tick, bt, bnow, ph_mul, rd.phase);
    rd.hp := least(rd.max_hp, rd.hp + coalesce((rfx ->> '_hp')::int, 0)); rfx := rfx - '_hp';
  elsif rd.kind = 'world' then
    mk := public.world_shadow_rules() -> 'mk2';$a$,
  $a$rd.intent := case when rfx ? 'charge'$a$, $a$rd.intent := coalesce(case when rd.boss_key = 'neol' then public.world_neol_intent(p_raid, rfx) end, case when rfx ? 'charge'$a$,
  $a$else null end;$a$, $a$else null end);$a$]);

select pg_temp.yh_fix('world_raid_hit', array[
  $a$if p_kind not in ('grip', 'ink') and f ? 'cover'$a$, $a$if p_kind not in ('grip', 'ink', 'dry', 'ebb') and f ? 'cover'$a$,
  $a$if p_kind in ('grip', 'ink') then st := '{}'::jsonb; end if;$a$, $a$if p_kind in ('grip', 'ink', 'dry', 'ebb') then st := '{}'::jsonb; end if;$a$,
  $a$if rk = 'world' and p_kind not in ('grip', 'ink') then p_raw := p_raw * least((public.world_shadow_rules() ->> 'pow_hi')::numeric, greatest((public.world_shadow_rules() ->> 'pow_lo')::numeric,$a$,
  $a$if rk = 'world' and p_kind not in ('grip', 'ink', 'dry') then p_raw := p_raw * least((public.world_raid_boss_rules(p_raid) ->> 'pow_hi')::numeric, greatest((public.world_raid_boss_rules(p_raid) ->> 'pow_lo')::numeric,$a$,
  $a$case p_kind when 'grip' then 'hit_grip' when 'ink' then 'hit_ink' when 'buster' then 'hit_brand' else 'hit' end$a$,
  $a$case p_kind when 'grip' then 'hit_grip' when 'ink' then 'hit_ink' when 'buster' then 'hit_brand' when 'weight' then 'hit_weight' when 'dry' then 'hit_dry' when 'ebb' then 'hit_ebb' else 'hit' end$a$,
  $a$case p_kind when 'grip' then '손아귀에 짓눌려 ' when 'ink' then '묵흔이 번져 ' when 'buster' then '검은 낙인에 ' else '' end$a$,
  $a$case p_kind when 'grip' then '손아귀에 짓눌려 ' when 'ink' then '묵흔이 번져 ' when 'buster' then '검은 낙인에 ' when 'weight' then '고임 무게에 ' when 'dry' then '몸이 말라 ' when 'ebb' then '되밀린 물에 ' else '' end$a$]);

select pg_temp.yh_fix('world_raid_begin_fight', array[
  $a$greatest((public.world_shadow_rules() ->> 'hp_min')::numeric, round(s * (public.world_shadow_rules() ->> 'hp_mul')::numeric))$a$,
  $a$greatest((public.world_raid_boss_rules(p_raid) ->> 'hp_min')::numeric, round(s * (public.world_raid_boss_rules(p_raid) ->> 'hp_mul')::numeric))$a$,
  $a$    perform public.world_raid_chat('「' || rd.boss_name || '」 토벌이 시작되었습니다(참가 ' || n || '명). '$a$,
  $a$    if rd.boss_key = 'neol' then
      perform public.world_raid_chat_k('neol', '「' || rd.boss_name || '」 흩어 보내기가 시작되었습니다(참가 ' || n || '명). ' || (select region_name from public.world_map_regions where region_id = rd.region_id) || '에 가면 지금도 합류할 수 있고, 현장의 너울 띠에서 진행을 볼 수 있습니다.');
    else
    perform public.world_raid_chat('「' || rd.boss_name || '」 토벌이 시작되었습니다(참가 ' || n || '명). '$a$,
  $a$현장의 그림자 띠에서 진행을 볼 수 있습니다.');$a$, $a$현장의 그림자 띠에서 진행을 볼 수 있습니다.');
    end if;$a$]);

select pg_temp.yh_fix('world_raid_join', array[
  $a$(public.world_shadow_rules() ->> 'hp_mul')::numeric$a$, $a$(public.world_raid_boss_rules(p_raid) ->> 'hp_mul')::numeric$a$,
  $a$'(Lv' || c.level || ') — 토벌에 뛰어들었습니다. 그림자의 체력 +' || hp_add$a$,
  $a$'(Lv' || c.level || ') — 토벌에 뛰어들었습니다. ' || case when rd.boss_key = 'neol' then '너울의' else '그림자의' end || ' 체력 +' || hp_add$a$]);

select pg_temp.yh_fix('world_raid_boss_base', array[$a$(public.world_shadow_rules() ->> 'dmg_mul')::numeric$a$, $a$(public.world_raid_boss_rules(p_raid) ->> 'dmg_mul')::numeric$a$]);
select pg_temp.yh_fix('world_raid_charge_need', array[$a$(public.world_shadow_rules() ->> 'charge_mul')::numeric$a$, $a$(public.world_raid_boss_rules(p_raid) ->> 'charge_mul')::numeric$a$]);
select pg_temp.yh_fix('world_raid_leave', array[$a$out_until = now() + interval '30 days', fx = '{}'::jsonb$a$,
  $a$out_until = now() + interval '30 days', fx = jsonb_strip_nulls(jsonb_build_object('stiff', fx -> 'stiff', 'ncnt', fx -> 'ncnt'))$a$]);
select pg_temp.yh_fix('world_raid_broadcast', array[$a$perform public.world_raid_chat(p_text);$a$,
  $a$perform public.world_raid_chat_k((select r.boss_key from public.world_raids r where r.raid_id = p_raid), p_text);$a$]);

select pg_temp.yh_fix('world_raid_snapshot_core', array[
  $a$'buffs', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(x.fx) k)$a$,
  $a$'buffs', (select coalesce(jsonb_agg(k), '[]'::jsonb) from jsonb_object_keys(x.fx) k where k not in ('ng', 'ncnt')), 'stiff', (x.fx -> 'stiff' ->> 'n')::int$a$,
  $a$return jsonb_build_object('raid', jsonb_build_object('id', rd.raid_id, 'kind', rd.kind, 'boss', rd.boss_name,$a$,
  $a$return jsonb_build_object('raid', jsonb_build_object('id', rd.raid_id, 'kind', rd.kind, 'boss_key', rd.boss_key, 'neol', case when rd.boss_key = 'neol' and rd.status = 'fight' then public.world_neol_view(rd.raid_id) end, 'boss', rd.boss_name,$a$,
  $a$'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until)), '[]'::jsonb)
        from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));$a$,
  $a$'locks', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until)), '[]'::jsonb)
        from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now() and l.kind = 'lock'),
    'flows', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'until', l.until, 'kind', l.kind)), '[]'::jsonb)
        from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now() and l.kind <> 'lock'));$a$]);

select pg_temp.yh_fix('world_raid_brief', array[
  $a$w := jsonb_build_object('id', rd.raid_id, 'status', rd.status, 'boss', rd.boss_name,$a$,
  $a$w := jsonb_build_object('id', rd.raid_id, 'status', rd.status, 'boss', rd.boss_name, 'boss_key', rd.boss_key,$a$,
  $a$from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now()));$a$,
  $a$from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now() and l.kind = 'lock'),
    'flows', (select coalesce(jsonb_agg(jsonb_build_object('region_id', l.region_id, 'region', x.region_name, 'kind', l.kind)), '[]'::jsonb)
                from public.world_raid_locks l join public.world_map_regions x on x.region_id = l.region_id where l.until > now() and l.kind <> 'lock'));$a$]);

select pg_temp.yh_fix('world_raid_lock_effect', array[
  $a$  if p_key not in ('erosion_pct', 'encounter_pct', 'gather_qty_pct', 'incoming_damage_pct') then return 0; end if;$a$,
  $a$  if p_key not in ('erosion_pct', 'encounter_pct', 'gather_qty_pct', 'incoming_damage_pct', 'rare_loot_pct', 'healing_pct') then return 0; end if;$a$,
  $a$  for l in select region_id from public.world_raid_locks where until > now() loop$a$,
  $a$  for l in select region_id, kind from public.world_raid_locks where until > now() and kind <> 'lock' loop
    d := case when here = l.region_id then 0
              when here in (select n from public.world_region_neighbors(l.region_id) n join public.world_map_regions a on a.region_id = n join public.world_map_regions b on b.region_id = l.region_id where a.territory_id = b.territory_id) then 1 end;
    if d is null then continue; end if;
    v := v + coalesce((public.world_neol_rules() -> 'result' -> case l.kind when 'flow' then 'win' else 'fail' end
      -> case d when 0 then 'here' else 'near' end ->> p_key)::numeric, 0);
  end loop;
  if p_key in ('rare_loot_pct', 'healing_pct') then return v; end if;
  for l in select region_id from public.world_raid_locks where until > now() and kind = 'lock' loop$a$]);

select pg_temp.yh_fix('world_raid_rule_count', array[
  $a$    when 'join' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and m.acts > 0)
    when 'win' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.status = 'won' and m.acts > 0)
    when 'top' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.status = 'won' and r.kind = 'world' and coalesce((m.reward ->> 'top')::boolean, false))$a$,
  $a$    when 'join' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.boss_key = 'shadow' and m.acts > 0)
    when 'win' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.boss_key = 'shadow' and r.status = 'won' and m.acts > 0)
    when 'top' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.status = 'won' and r.kind = 'world' and r.boss_key = 'shadow' and coalesce((m.reward ->> 'top')::boolean, false))
    when 'neol_win' then (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol' and r.status = 'won' and m.acts > 0 and coalesce((m.reward ->> 'share')::numeric, 0) >= 1)
    when 'neol_w' then (select sum(coalesce((m.reward -> 'nc' ->> 'w')::int, 0)) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol')
    when 'neol_d' then (select sum(coalesce((m.reward -> 'nc' ->> 'd')::int, 0)) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol')
    when 'neol_c' then (select sum(coalesce((m.reward -> 'nc' ->> 'c')::int, 0)) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol')
    when 'neol_e' then (select sum(coalesce((m.reward -> 'nc' ->> 'e')::int, 0)) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol')
    when 'both' then least(
      (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.kind = 'world' and r.boss_key = 'shadow' and r.status = 'won' and m.acts > 0),
      (select count(*) from public.world_raid_members m join public.world_raids r on r.raid_id = m.raid_id where m.owner_id = p_owner and r.boss_key = 'neol' and r.status = 'won' and m.acts > 0))$a$,
  $a$and r.kind = 'world' and r.status = 'won' and m.level <= 15 and m.acts > 0)$a$, $a$and r.kind = 'world' and r.boss_key = 'shadow' and r.status = 'won' and m.level <= 15 and m.acts > 0)$a$]);

select pg_temp.yh_fix('world_housing_raid_trg', array[
  $a$elsif coalesce(m.contrib, 0) / tot >= 0.01 then perform public.world_housing_roll(m.owner_id, 'raid_world', 0.06 + 0.2 * least(1, coalesce(m.contrib, 0) / tot), '사슬 벗은 그림자 토벌'); end if;$a$,
  $a$elsif coalesce(m.contrib, 0) / tot >= 0.01 then
      if new.boss_key = 'neol' then perform public.world_housing_grant_once(m.owner_id, 'raid_neol_first', new.boss_name || ' 첫 흩어 보냄'); end if;
      perform public.world_housing_roll(m.owner_id, 'raid_world', 0.06 + 0.2 * least(1, coalesce(m.contrib, 0) / tot), case when new.boss_key = 'neol' then new.boss_name || ' 흩어 보내기' else '사슬 벗은 그림자 토벌' end); end if;$a$]);
