lock table public.world_characters in access exclusive mode;

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

create or replace function public.world_my_fight(p_uid uuid)
 returns jsonb language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce(
    (select jsonb_build_object('kind', 'raid', 'id', x.raid_id, 'name', x.boss_name, 'status', x.status)
       from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
      where m.owner_id = p_uid and m.left_at is null and x.status in ('signup', 'fight') order by x.created_at desc limit 1),
    (select jsonb_build_object('kind', 'gw', 'id', x.fight_id, 'status', x.status)
       from public.world_gw_members m join public.world_gw_fights x on x.fight_id = m.fight_id
      where m.owner_id = p_uid and x.status in ('wait', 'fight') order by x.created_at desc limit 1),
    (select jsonb_build_object('kind', 'pfight', 'id', f.fight_id, 'name', f.monster_name, 'status', f.status)
       from public.world_pfight_members m join public.world_pfights f on f.fight_id = m.fight_id
      where m.owner_id = p_uid and m.out_reason is null and f.status in ('gather', 'fight') limit 1))
$function$;
revoke all on function public.world_my_fight(uuid) from public, anon, authenticated;
grant execute on function public.world_my_fight(uuid) to fn_owner_field, service_role;

select pg_temp.yh_fix('world_hud_snapshot()', array[
$q$'battle', public.world_field_battle_view(uid),$q$,
$q$'battle', public.world_field_battle_view(uid),
    'fight', public.world_my_fight(uid),$q$]);

update public.world_patch_notes set body = body || E'\n- 토벌·결전·귀허의 주인·파티 토벌 화면을 벗어나 있어도 상태판 「진행 중」 칸에 그 싸움이 보이고, 「싸움으로」를 누르면 바로 돌아갑니다.'
where note_id = '1.1.0' and position('「싸움으로」를 누르면' in body) = 0;

update public.world_app_meta set value = '20261113040000' where key = 'db_version';
