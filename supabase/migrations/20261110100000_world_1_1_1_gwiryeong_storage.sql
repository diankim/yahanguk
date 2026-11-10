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

create or replace function public.world_gwiryeong_place(p_uid uuid, p_inv jsonb)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare inv jsonb := coalesce(p_inv, '{}'::jsonb);
begin
  if public.world_bag_room(inv, 'gwiryeong_cho', public.world_bag_limit(p_uid)) >= 1 then
    return jsonb_build_object('inv', public.world_inv_add(inv, 'gwiryeong_cho', 1), 'stored', false);
  end if;
  perform public.world_letter_spill(p_uid, '{"gwiryeong_cho":1}'::jsonb);
  return jsonb_build_object('inv', inv, 'stored', true);
end $function$;
revoke all on function public.world_gwiryeong_place(uuid, jsonb) from public, anon, authenticated;
grant create on schema public to fn_owner_field;
alter function public.world_gwiryeong_place(uuid, jsonb) owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_gwiryeong_place(uuid, jsonb) from public, anon, authenticated;
reset role;

select pg_temp.yh_fix('world_field_search', array[
  $q$inv jsonb; it text;$q$, $q$inv jsonb; gwp jsonb; it text;$q$,
  $q$    inv := public.world_inv_add(coalesce(inv, c.inventory, '{}'::jsonb), 'gwiryeong_cho', 1); txt := txt || ' 「영초 감별」 귀령초를 찾았다.'; payload := payload || jsonb_build_object('gwiryeong', 1);$q$,
  $q$    gwp := public.world_gwiryeong_place(uid, coalesce(inv, c.inventory, '{}'::jsonb)); inv := gwp -> 'inv';
    txt := txt || ' 「영초 감별」 귀령초를 찾았다.' || case when (gwp ->> 'stored')::boolean then ' 가방이 가득 차 개인 창고에 넣었다.' else '' end;
    payload := payload || jsonb_build_object('gwiryeong', 1, 'gwiryeong_stored', (gwp ->> 'stored')::boolean);$q$]);

create or replace function public.world_gwiryeong_give(p_uid uuid, p_chance numeric, p_source text)
 returns boolean
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare inv jsonb; gwp jsonb; stored boolean;
begin
  if p_uid is null or coalesce(p_chance, 0) <= 0 or random() >= least(0.05, p_chance * public.world_gwiryeong_mul(p_uid)) then return false; end if;
  select inventory into inv from public.world_characters where owner_id = p_uid for update;
  if not found then return false; end if;
  if not public.world_gwiryeong_reserve(p_uid, p_source) then return false; end if;
  gwp := public.world_gwiryeong_place(p_uid, inv); stored := (gwp ->> 'stored')::boolean;
  if not stored then
    update public.world_characters set inventory = gwp -> 'inv', updated_at = now() where owner_id = p_uid;
  end if;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_uid, 'reward', '귀령초를 찾았습니다',
    '음습한 기운 사이에서 귀령초 한 포기를 찾았습니다. 요화를 다스리는 귀한 풀입니다.' || case when stored then ' 가방이 가득 차 개인 창고에 넣었습니다.' else '' end,
    jsonb_build_object('item_id', 'gwiryeong_cho', 'qty', 1, 'source', p_source, 'storage', stored));
  return true;
end $function$;

update public.world_patch_notes set body = body || E'\n- 귀령초: 찾을 때 가방이 가득 차 있으면 버려지지 않고 개인 창고로 들어갑니다(창고 칸이 넘쳐도 들어감).\n- 비무회 작전: 우수품 회복품(「… (우수)」)도 고를 수 있게 목록에 보입니다.'
where note_id = '1.1.0' and position('귀령초: 찾을 때 가방이 가득' in body) = 0;

update public.world_app_meta set value = '20261110100000' where key = 'db_version';
