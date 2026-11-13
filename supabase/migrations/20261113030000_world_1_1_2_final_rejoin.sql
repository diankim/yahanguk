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

select pg_temp.yh_fix('world_raid_final_start()', array[
$q$  if exists (select 1 from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id where m.owner_id = uid and x.status in ('signup', 'fight') and m.left_at is null) then$q$,
$q$  select x.raid_id into rid from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id
   where m.owner_id = uid and x.kind = 'final' and x.status in ('signup', 'fight') and m.left_at is null limit 1;
  if rid is not null then return jsonb_build_object('raid_id', rid, 'again', true); end if;
  if exists (select 1 from public.world_raid_members m join public.world_raids x on x.raid_id = m.raid_id where m.owner_id = uid and x.status in ('signup', 'fight') and m.left_at is null) then$q$]);

update public.world_patch_notes set body = body || E'\n\n## 1.1.2\n- 구중 봉주와의 결전을 연 뒤 결전 화면을 벗어났다가 「결전」 단추를 다시 누르면 「이미 진행 중인 토벌이 있습니다」로 막히던 것을 고쳤습니다. 이제 열려 있는 결전으로 바로 돌아가고, 현장 위 띠에도 「결전이 열려 있습니다 · 들어가기」가 바로 뜹니다.'
where note_id = '1.1.0' and position('열려 있는 결전으로 바로 돌아가고' in body) = 0;

update public.world_app_meta set value = '20261113030000' where key = 'db_version';
