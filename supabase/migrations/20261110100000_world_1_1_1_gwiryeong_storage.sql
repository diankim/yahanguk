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

create or replace function public.world_use_item_batch(p_item_id text, p_times integer)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); n int; i int; r jsonb; last jsonb; done int := 0; why text; outs jsonb := '{}'::jsonb; parts text[] := '{}'; k text; v text; nm text; fx jsonb; c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if public.world_item_base(p_item_id) in ('reset_stats', 'reset_identity', 'gwiryeong_cho') then raise exception '이 물품은 한 번에 하나씩만 쓸 수 있습니다.'; end if;
  n := least(greatest(coalesce(p_times, 1), 1), 50);
  fx := public.world_item_fx(public.world_item_base(p_item_id));
  for i in 1 .. n loop
    if i > 1 then
      select * into c from public.world_characters where owner_id = uid;
      if coalesce(jsonb_array_length(fx -> 'buffs'), 0) > 0
        and not exists (select 1 from jsonb_array_elements_text(fx -> 'buffs') b(k) join public.world_status_catalog sc on sc.status_key = b.k
          where not exists (select 1 from public.world_character_statuses s where s.owner_id = uid and s.status_key = b.k and s.expires_at >= now() + make_interval(mins => 2 * sc.duration_minutes)))
        and (coalesce((fx ->> 'hp')::int, 0) = 0 or c.health >= 100) and (coalesce((fx ->> 'mn')::int, 0) = 0 or c.mental >= 100)
        and (coalesce((fx ->> 'sp')::int, 0) = 0 or c.spiritual_power >= 100) and (coalesce((fx ->> 'er')::int, 0) = 0 or c.erosion <= 0)
        and (coalesce((fx ->> 'stam')::int, 0) = 0 or public.world_stamina_now(c.stamina, c.stamina_at, c.level) >= public.world_stamina_max(c.level))
        and not exists (select 1 from jsonb_array_elements_text(coalesce(fx -> 'cures', '[]'::jsonb)) x(k) join public.world_character_statuses s on s.owner_id = uid and s.status_key = x.k and s.expires_at > now()) then
        why := '기운이 이미 두 번 몫까지 찼습니다'; exit;
      end if;
    end if;
    begin
      r := public.world_use_item(p_item_id);
    exception when others then
      why := sqlerrm; exit;
    end;
    done := done + 1; last := r;
    outs := outs || jsonb_build_object(coalesce(r ->> 'content', ''), coalesce((outs ->> coalesce(r ->> 'content', ''))::int, 0) + 1);
  end loop;
  if done = 0 then raise exception '%', coalesce(why, '쓰지 못했습니다.'); end if;
  select item_name into nm from public.world_item_catalog where item_id = p_item_id;
  for k, v in select key, value::text from jsonb_each(outs) where key <> '' loop
    parts := parts || (k || case when v::int > 1 then ' (×' || v || ')' else '' end);
  end loop;
  return (last - 'content') || jsonb_build_object(
    'content', coalesce(nm, p_item_id) || ' ' || done || '번 사용: ' || array_to_string(parts, ' · ')
      || case when done < n then ' · ' || n || '번 가운데 ' || done || '번에서 멈춤(' || coalesce(why, '') || ')' else '' end,
    'done', done, 'asked', n, 'stopped', why);
end $function$;
revoke all on function public.world_use_item_batch(text, integer) from public, anon, authenticated;
grant execute on function public.world_use_item_batch(text, integer) to authenticated, service_role;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function public.world_battle_item_rules()
 returns jsonb language sql immutable
as $function$
  select '{"tourney":{"items":["tonic","herbal_extract","herb","rejuv_pill","grand_pill","banyo_salve"],"heal":{"tonic":0.22,"herbal_extract":0.15,"herb":0.1,"rejuv_pill":0.32,"grand_pill":0.45,"banyo_salve":0.36},"pick":2,"hq_mul":1.15},"gw":{"items":["tonic","herbal_extract","rejuv_pill","grand_pill","banyo_salve"]}}'::jsonb
$function$;
select pg_temp.yh_share('public.world_battle_item_rules()');

create or replace function public.world_battle_item_ids(p_kind text)
 returns text[] language sql immutable
as $function$
  select array(select jsonb_array_elements_text(public.world_battle_item_rules() -> p_kind -> 'items'))
$function$;
select pg_temp.yh_share('public.world_battle_item_ids(text)');

create or replace function public.world_battle_item_have(p_kind text)
 returns text[] language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select array(select i.item_id from public.world_item_catalog i where coalesce(i.base_item_id, i.item_id) = any (public.world_battle_item_ids(p_kind)) order by i.item_id)
$function$;
select pg_temp.yh_share('public.world_battle_item_have(text)');

create or replace function public.world_battle_item_names(p_kind text)
 returns text language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select string_agg(coalesce(i.item_name, x.k), '·' order by x.n) from unnest(public.world_battle_item_ids(p_kind)) with ordinality x(k, n)
    left join public.world_item_catalog i on i.item_id = x.k
$function$;
select pg_temp.yh_share('public.world_battle_item_names(text)');

select pg_temp.yh_fix('world_tourney_tactic', array[
  $q$ok_items text[] := array['tonic', 'herbal_extract', 'herb', 'rejuv_pill', 'grand_pill', 'banyo_salve'];$q$,
  $q$ok_items text[] := public.world_battle_item_ids('tourney'); pick int := (public.world_battle_item_rules() #>> '{tourney,pick}')::int;$q$,
  $q$if coalesce(cardinality(p_items), 0) > 2 or$q$, $q$if coalesce(cardinality(p_items), 0) > pick or$q$,
  $q$raise exception '회복품은 두 가지까지 고를 수 있습니다.';$q$, $q$raise exception '회복품은 %가지까지 고를 수 있습니다.', pick;$q$]);

select pg_temp.yh_fix('world_tourney_duel', array[
  $q$heal := round(mx[i] * (case when it like '%\_hq' then 1.15 else 1 end) * case public.world_item_base(it) when 'grand_pill' then 0.45 when 'rejuv_pill' then 0.32 when 'banyo_salve' then 0.36 when 'tonic' then 0.22 when 'herbal_extract' then 0.15 else 0.1 end);$q$,
  $q$heal := round(mx[i] * (case when public.world_item_base(it) <> it then (public.world_battle_item_rules() #>> '{tourney,hq_mul}')::numeric else 1 end) * coalesce((public.world_battle_item_rules() -> 'tourney' -> 'heal' ->> public.world_item_base(it))::numeric, 0.1));$q$]);

select pg_temp.yh_fix('world_gw_act', array[
  $q$if coalesce(public.world_item_base(coalesce(p_item, '')), '') not in ('tonic', 'herbal_extract', 'rejuv_pill', 'grand_pill', 'banyo_salve') then
      raise exception '귀허의 주인과 싸우는 동안에는 체력 회복품(청심환·약초액·회춘단·대환단·반요 고약)만 쓸 수 있습니다.'; end if;$q$,
  $q$if coalesce(public.world_item_base(coalesce(p_item, '')), '') <> all (public.world_battle_item_ids('gw')) then
      raise exception '귀허의 주인과 싸우는 동안에는 체력 회복품(%)만 쓸 수 있습니다.', public.world_battle_item_names('gw'); end if;$q$]);

select pg_temp.yh_fix('world_gw_snapshot', array[
  $q$from unnest(array['tonic', 'tonic_hq', 'herbal_extract', 'rejuv_pill', 'rejuv_pill_hq', 'grand_pill', 'grand_pill_hq', 'banyo_salve']) k$q$,
  $q$from unnest(public.world_battle_item_have('gw')) k$q$]);

create or replace function public.world_ammo_left(p_uid uuid)
 returns jsonb language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select case when x.a is null then null else jsonb_build_object('id', x.a, 'n', coalesce((select (c.inventory ->> x.a)::int from public.world_characters c where c.owner_id = p_uid), 0)) end
    from (select public.world_ammo_of(p_uid) a) x
$function$;
select pg_temp.yh_share('public.world_ammo_left(uuid)');

select pg_temp.yh_fix('world_raid_snapshot_core', array[
  $q$'hp', c.health, 'sp', c.spiritual_power, 'out',$q$, $q$'hp', c.health, 'sp', c.spiritual_power, 'ammo', public.world_ammo_left(c.owner_id), 'out',$q$]);

select pg_temp.yh_fix('world_gw_snapshot', array[
  $q$'joined', me.owner_id is not null, 'sp', c.spiritual_power,$q$, $q$'joined', me.owner_id is not null, 'sp', c.spiritual_power, 'ammo', public.world_ammo_left(c.owner_id),$q$]);

update public.world_patch_notes set body = body || E'\n- 귀령초: 찾을 때 가방이 가득 차 있으면 버려지지 않고 개인 창고로 들어갑니다(창고 칸이 넘쳐도 들어감).\n- 비무회 작전: 우수품 회복품(「… (우수)」)도 고를 수 있게 목록에 보입니다.\n- 가방: 쓸 수 있는 물품은 수량(−·+·전부)을 정해 한 번에 여러 개 쓸 수 있습니다(50개까지, 쓸 수 없게 되면 그 자리에서 멈춤). 물품 정보 창의 창고에 넣기·버리기 수량도 창고와 같은 수량 칸으로 바뀝니다.\n- 봉연 토벌·결전·귀허·먹그림자: 내 막대 옆에 남은 화살(탄) 수가 보이고, 탄이 떨어진 채 공격하면 피해가 절반이라는 안내가 뜹니다.\n- 동료 화면: 친구 목록을 접어 둘 수 있습니다(기기에 기억).\n- 제작: 제작 공구 제작법 카드에도 부위·단계(「제작 공구 n단계」)가 보입니다.'
where note_id = '1.1.0' and position('귀령초: 찾을 때 가방이 가득' in body) = 0;

update public.world_app_meta set value = '20261110100000' where key = 'db_version';
