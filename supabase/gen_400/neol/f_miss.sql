create or replace function pg_temp.yh_resig(p_sig text, p_pairs text[]) returns void language plpgsql as $f$
declare o regprocedure := ('public.' || p_sig)::regprocedure; d text; own text; acl aclitem[]; nm text; i int; n int; no regprocedure; a record; had boolean;
begin
  select pg_get_functiondef(p.oid), pg_get_userbyid(p.proowner), p.proacl, p.proname into d, own, acl, nm from pg_proc p where p.oid = o;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_sig, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute 'drop function ' || o::text;
  execute d;
  select p.oid::regprocedure into strict no from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = nm;
  execute format('revoke all on function %s from public, anon, authenticated', no);
  for a in select distinct x.grantee from aclexplode(acl) x where x.privilege_type = 'EXECUTE' loop
    if a.grantee = 0 then execute format('grant execute on function %s to public', no);
    else execute format('grant execute on function %s to %I', no, pg_get_userbyid(a.grantee)); end if;
  end loop;
  if own <> current_user then
    had := has_schema_privilege(own, 'public', 'create');
    if not had then execute format('grant create on schema public to %I', own); end if;
    execute format('alter function %s owner to %I', no, own);
    if not had then execute format('revoke create on schema public from %I', own); end if;
  end if;
end $f$;

select pg_temp.yh_fix('world_shadow_rules', array[$a$"counter_mul": 2}$a$, $a$"counter_mul": 2, "miss": {"pierce": 0.25, "regrow": 1, "regrow_none": 2}}$a$]);

select pg_temp.yh_resig('world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean)', array[
  $a$p_evade boolean DEFAULT false)$a$, $a$p_evade boolean DEFAULT false, p_pierce numeric DEFAULT 0)$a$,
  $a$declare f jsonb := coalesce(p_fx, '{}'::jsonb);$a$, $a$declare q numeric := 1 - least(1, greatest(0, coalesce(p_pierce, 0))); d0 numeric; f jsonb := coalesce(p_fx, '{}'::jsonb);$a$,
  $a$  d := d * (1 - red / 100.0)$a$, $a$  d0 := d * (1 + coalesce((p_stats ->> 'inc')::numeric, 0) / 100.0);
  d := d * (1 - red / 100.0)$a$,
  $a$  sh := coalesce((f ->> 'shield')::int, 0);$a$, $a$  if q < 1 then
    d := d + greatest(0, d0 - d) * (1 - q);
    cr := coalesce((select jsonb_agg(jsonb_build_array(e -> 0, (e ->> 1)::numeric * q, e -> 2)) from jsonb_array_elements(cr) e), '[]'::jsonb);
  end if;
  sh := coalesce((f ->> 'shield')::int, 0);$a$]);

select pg_temp.yh_resig('world_raid_hit(uuid, uuid, numeric, text)', array[
  $a$(p_raid uuid, p_target uuid, p_raw numeric, p_kind text)$a$, $a$(p_raid uuid, p_target uuid, p_raw numeric, p_kind text, p_pierce numeric DEFAULT 0)$a$,
  $a$p_kind = 'single');$a$, $a$p_kind = 'single', p_pierce);$a$,
  $a$    if self_guard > 0 then$a$, $a$    self_guard := self_guard * (1 - least(1, greatest(0, coalesce(p_pierce, 0))));
    if self_guard > 0 then$a$]);

create or replace function public.world_raid_pierce(p_raid uuid)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $f$
begin
  return coalesce((public.world_raid_boss_rules(p_raid) -> 'mk2' -> 'miss' ->> 'pierce')::numeric, 0);
end $f$;

create or replace function public.world_raid_regrow_say(p_raid uuid, p_none boolean)
 returns int language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $f$
declare rd public.world_raids%rowtype; mi jsonb := public.world_raid_boss_rules(p_raid) -> 'mk2' -> 'miss'; pct numeric; n int;
begin
  select * into rd from public.world_raids where raid_id = p_raid;
  if not found or mi is null then return 0; end if;
  pct := coalesce((mi ->> case when p_none then 'regrow_none' else 'regrow' end)::numeric, 0);
  n := ceil(rd.max_hp * pct / 100.0)::int;
  if n <= 0 then return 0; end if;
  perform public.world_raid_say(p_raid, 'boss', '수법을 놓친 틈에 ' || rd.boss_name || '이(가) 다시 엉깁니다(체력 +' || pct::text || '%' || case when p_none then ', 아무도 받아 내지 못함' else '' end || ').');
  return n;
end $f$;

select pg_temp.yh_share('public.world_raid_pierce(uuid)');
select pg_temp.yh_share('public.world_raid_regrow_say(uuid, boolean)');

select pg_temp.yh_fix('world_raid_action', array[
  $a$pd int; psolo numeric := 1; nl0 int;$a$, $a$pd int; psolo numeric := 1; nl0 int; mg boolean; mgn int; mgt int;$a$,
  $a$      for m in select x.owner_id, x.level from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst');
      end loop;$a$,
  $a$      mgn := 0; mgt := 0;
      for m in select x.owner_id, x.level, coalesce((x.fx ->> 'guard')::int, 0) > 0 as gd from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval '120 seconds' loop
        raw := public.world_raid_boss_base(p_raid, rd.kind, m.level) * ph_mul * 2.2 * case when rfx ? 'break' then (1 - (rfx ->> 'break')::numeric / 100.0) else 1 end;
        mgt := mgt + 1; if not m.gd then mgn := mgn + 1; end if;
        perform public.world_raid_hit(p_raid, m.owner_id, raw, 'burst', case when rd.kind = 'world' and not m.gd then public.world_raid_pierce(p_raid) else 0 end);
      end loop;
      if rd.kind = 'world' and mgn > 0 then rd.hp := least(rd.max_hp, rd.hp + public.world_raid_regrow_say(p_raid, mgn >= mgt)); end if;$a$,
  $a$select x.owner_id, x.level, x.name into pick, lv, nm from public.world_raid_members x join$a$,
  $a$select x.owner_id, x.level, x.name, coalesce((x.fx ->> 'guard')::int, 0) > 0 into pick, lv, nm, mg from public.world_raid_members x join$a$,
  $a$* (1 + (mk -> 'brand' ->> 'streak')::numeric * gx), 'buster');$a$,
  $a$* (1 + (mk -> 'brand' ->> 'streak')::numeric * gx), 'buster', case when mg then 0 else public.world_raid_pierce(p_raid) end);
        if not mg then rd.hp := least(rd.max_hp, rd.hp + public.world_raid_regrow_say(p_raid, false)); end if;$a$]);
