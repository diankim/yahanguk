create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_faction_perk_rules()
 returns jsonb language sql immutable
as $function$
  select '{"night_office":{"exp_xp_pct":10},"north_league":{"gather_skill_pct":10,"exp_hurt_pct":-20,"rank_hurt_pct":-2}}'::jsonb
$function$;
select pg_temp.yh_share('public.world_faction_perk_rules()');

select pg_temp.yh_fix('world_expedition_complete', array[$q$
    xp := round(xp * 1.15); cxp := round(cxp * 1.15); gxp := round(gxp * 1.15); ixp := round(ixp * 1.15); gil_gain := round(gil_gain * 1.15);$q$, $q$
    xp := round(xp * (1 + (public.world_faction_perk_rules() #>> '{night_office,exp_xp_pct}')::numeric / 100));
  elsif c.major_faction_id = 'north_league' then
    gxp := round(gxp * (1 + (public.world_faction_perk_rules() #>> '{north_league,gather_skill_pct}')::numeric / 100));$q$]);

select pg_temp.yh_fix('world_event_char_apply', array[$q$round(sk_xp * greatest(0.5, 1 + public.world_status_self(c.owner_id, 'training_xp_pct') / 100.0))::int$q$,
  $q$floor(sk_xp * greatest(0.5, 1 + public.world_status_self(c.owner_id, 'training_xp_pct') / 100.0) * case when k = 'gather' and c.major_faction_id = 'north_league' then 1 + (public.world_faction_perk_rules() #>> '{north_league,gather_skill_pct}')::numeric / 100 else 1 end + case when k = 'gather' and c.major_faction_id = 'north_league' then random() else 0.5 end)::int$q$]);

select pg_temp.yh_fix('world_expedition_settle', array[
  $q$0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 0.8 else 1 end$q$,
  $q$0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 1 + (public.world_faction_perk_rules() #>> '{north_league,exp_hurt_pct}')::numeric / 100 else 1 end$q$,
  $q$2.4 end * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 0.8 else 1 end$q$,
  $q$2.4 end * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + case when nal > 0 then adef else defense end) * case when c.major_faction_id = 'north_league' then 1 + (public.world_faction_perk_rules() #>> '{north_league,exp_hurt_pct}')::numeric / 100 else 1 end$q$]);

select pg_temp.yh_fix('world_faction_rank_effect', array[
  $q$when 'north_league' then case p_key when 'incoming_damage_pct' then -1 else 0 end$q$,
  $q$when 'north_league' then case p_key when 'incoming_damage_pct' then (public.world_faction_perk_rules() #>> '{north_league,rank_hurt_pct}')::numeric else 0 end$q$]);

update public.world_patch_notes set body = body || E'\n- 북령맹: 채집·채광으로 얻는 숙련 경험이 10% 더 오릅니다(현장 채집과 원정 채집 모두). 등급 효과가 받는 피해 −1%씩에서 −2%씩으로 바뀝니다(5등급 −8%). 원정 중 받는 피해 −20%는 그대로입니다.\n- 정통파: 공인 조사 수당이 원정 귀환 경험치 +10%로 바뀝니다(숙련 경험·전 덤은 없어집니다). 어디서든 부르는 세력 구조대는 그대로입니다.'
where note_id = '1.1.0' and position('북령맹: 채집·채광' in body) = 0;

update public.world_app_meta set value = '20261109180000' where key = 'db_version';
