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

do $c$ begin
  if not exists (select 1 from pg_proc where proname = 'world_gw_vote_view') then raise exception '1.1.2g(귀허 포기)가 먼저 들어가야 합니다'; end if;
end $c$;
select pg_temp.yh_fix('world_gw_snapshot(uuid,text)', array[
$q$'my_act', me.act, 'joined', me.owner_id is not null,$q$,
$q$'my_act', me.act, 'joined', me.owner_id is not null, 'vote', public.world_gw_vote_view(fid, uid),$q$])
 where position('world_gw_vote_view' in pg_get_functiondef('public.world_gw_snapshot(uuid,text)'::regprocedure)) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116180000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
