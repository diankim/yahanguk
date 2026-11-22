create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_faction_perk_rules()
 returns jsonb language sql immutable
as $function$
  select '{"night_office":{"exp_xp_pct":10},"north_league":{"gather_skill_pct":10,"exp_hurt_pct":-20,"rank_hurt_pct":-2},"donate":{"rate":50,"cap":60}}'::jsonb
$function$;

select pg_temp.yh_fix('world_faction_donate(jsonb)', array[
$q$n int := 0; kinds int := 0;$q$,
$q$n int := 0; kinds int := 0; dr jsonb := public.world_faction_perk_rules() -> 'donate'; v_cap int := (dr ->> 'cap')::int; v_rate int := (dr ->> 'rate')::int;$q$,
$q$if d.merit >= 30 then raise exception '오늘은 더 받지 않습니다(하루 공훈 30까지). 내일 다시 오세요.'; end if;$q$,
$q$if d.merit >= v_cap then raise exception '오늘은 더 받지 않습니다(하루 공훈 %까지). 내일 다시 오세요.', v_cap; end if;$q$,
$q$gain := least(30, (d.value + val) / 50) - d.merit;$q$,
$q$gain := greatest(0, least(v_cap, (d.value + val) / v_rate) - d.merit);$q$,
$q$'cap', 30,$q$,
$q$'cap', v_cap,$q$,
$q$case when d.merit + gain >= 30 then ' · 오늘 기부 상한(공훈 30)에 닿았습니다.' else ' · 오늘 ' || (d.merit + gain) || '/30' end$q$,
$q$case when d.merit + gain >= v_cap then ' · 오늘 기부 상한(공훈 ' || v_cap || ')에 닿았습니다.' else ' · 오늘 ' || (d.merit + gain) || '/' || v_cap end$q$]);

select pg_temp.yh_fix('world_faction_donate_info(uuid)', array[
$q$select jsonb_build_object('rate', 50, 'cap', 30,$q$,
$q$select jsonb_build_object('rate', (public.world_faction_perk_rules() -> 'donate' ->> 'rate')::int, 'cap', (public.world_faction_perk_rules() -> 'donate' ->> 'cap')::int,$q$]);

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125030000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
