create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;
select pg_temp.yh_fix('world_pet_act', array[$q$
  if uid = p_owner then$q$, $q$
  if uid = p_owner or public.world_housing_married(uid, p_owner) then$q$, $q$'counts', case when uid = p_owner then$q$, $q$'counts', case when uid = p_owner or public.world_housing_married(uid, p_owner) then$q$], 1);


update public.world_patch_notes set body = body || E'\n- 혼례를 올린 정인은 서로의 별채 꼬마 동무를 주인처럼 돌볼 수 있습니다(쓰다듬기·놀기·먹이, 하루 횟수는 주인과 함께 씁니다).\n- 별채 곳간 창을 PC는 곳간·가방 두 칸으로, 휴대폰은 탭으로 나눠 가구가 많아도 덜 길게 보이게 했습니다.\n- 창고 꺼내기 목록도 가방처럼 「칸대로 나눠 보기」로 볼 수 있습니다.\n- 도움말 전투 항목에 치명타율(60%)·회피율(40%)·달아날 확률(95%) 상한을 적었습니다.'
 where note_id = '1.1.0';
update public.world_app_meta set value = '20261109010000' where key = 'db_version';
