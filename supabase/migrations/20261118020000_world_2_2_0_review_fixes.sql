create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

select pg_temp.yh_fix2('public.world_ucomm_post(text,integer,integer)'::regprocedure,
  $o$  if public.world_market_only(it.item_id) then$o$,
  $n$  if it.item_id = 'gwiryeong_cho' then raise exception '귀령초는 조사원 의뢰로 구할 수 없습니다.'; end if;
  if public.world_market_only(it.item_id) then$n$);

select pg_temp.yh_fix2('public.world_ucomm_collect(bigint)'::regprocedure,
  $o$  select item_name into nm from public.world_item_catalog where item_id = u.item_id;
  return jsonb_build_object('ok', true, 'content', '의뢰한 ' || nm || ' ×' || u.qty || '을(를) 받았습니다.');$o$,
  $n$  select string_agg(coalesce(i.item_name, e.key) || ' ×' || e.value::text, ', ' order by i.item_name) into nm
    from jsonb_each(u.delivered) e left join public.world_item_catalog i on i.item_id = e.key;
  return jsonb_build_object('ok', true, 'content', '의뢰한 ' || coalesce(nm, '') || '을(를) 받았습니다.');$n$);

select pg_temp.yh_fix2('public.world_gw_open(text,text)'::regprocedure,
  $o$  perform public.world_seal_guard();
  c := public.world_gw_ready(uid, boss, md);$o$,
  $n$  perform public.world_seal_guard();
  select f.fight_id into fid from public.world_gw_members m join public.world_gw_fights f using (fight_id) where m.owner_id = uid and f.status in ('wait', 'fight') limit 1;
  if fid is not null then
    perform public.world_gw_snapshot(fid);
    if exists (select 1 from public.world_gw_fights f where f.fight_id = fid and f.status in ('wait', 'fight')) then
      return public.world_gw_snapshot(fid) || jsonb_build_object('again', true);
    end if;
    fid := null;
  end if;
  c := public.world_gw_ready(uid, boss, md);$n$);

select pg_temp.yh_fix2('public.world_pet_token_trade()'::regprocedure,
  $o$  perform public.world_seal_guard();
  select coalesce((inventory ->> 'pet_token')::int, 0)$o$,
  $n$  perform public.world_seal_guard();
  perform public.world_travel_guard('동무 정표 바꾸기');
  select coalesce((inventory ->> 'pet_token')::int, 0)$n$);

do $rn$
declare pairs text[][] := array[array['lt_knife_7_hq','lt_knife_6_hq'], array['lt_knife_7','lt_knife_6'], array['r_lt_knife_7','r_lt_knife_6']];
  i int; r record; o text; nw text; js text;
begin
  if not exists (select 1 from public.world_item_catalog where item_id = 'lt_knife_7') then return; end if;
  if exists (select 1 from public.world_item_catalog where item_id in ('lt_knife_6', 'lt_knife_6_hq')) then raise exception 'lt_knife_6 이미 있음'; end if;
  alter table public.world_item_catalog disable trigger user;
  insert into public.world_item_catalog select (jsonb_populate_record(null::public.world_item_catalog,
    to_jsonb(c) || jsonb_build_object('item_id', 'lt_knife_6'))).* from public.world_item_catalog c where c.item_id = 'lt_knife_7';
  insert into public.world_item_catalog select (jsonb_populate_record(null::public.world_item_catalog,
    to_jsonb(c) || jsonb_build_object('item_id', 'lt_knife_6_hq', 'base_item_id', 'lt_knife_6'))).* from public.world_item_catalog c where c.item_id = 'lt_knife_7_hq';
  alter table public.world_item_catalog enable trigger user;
  insert into public.world_crafting_recipes select (jsonb_populate_record(null::public.world_crafting_recipes,
    to_jsonb(c) || jsonb_build_object('recipe_id', 'r_lt_knife_6', 'output_item', 'lt_knife_6'))).* from public.world_crafting_recipes c where c.recipe_id = 'r_lt_knife_7';
  for r in select c.table_name t, c.column_name col, case when c.data_type = 'ARRAY' and c.udt_name = '_text' then 'ARRAY' when c.data_type = 'ARRAY' then 'skip' else c.data_type end dt from information_schema.columns c join information_schema.tables tb using (table_schema, table_name)
           where c.table_schema = 'public' and tb.table_type = 'BASE TABLE' and c.data_type in ('text', 'jsonb', 'character varying', 'ARRAY')
             and c.table_name not in ('world_events', 'world_item_catalog') and not (c.table_name = 'world_crafting_recipes' and c.column_name in ('recipe_id', 'output_item')) loop
    if r.dt = 'jsonb' then
      js := format('update public.%I set %I = replace(replace(replace(%I::text, %L, %L), %L, %L), %L, %L)::jsonb where %I::text like %L',
        r.t, r.col, r.col, '"lt_knife_7_hq"', '"lt_knife_6_hq"', '"lt_knife_7"', '"lt_knife_6"', '"r_lt_knife_7"', '"r_lt_knife_6"', r.col, '%lt_knife_7%');
      execute js;
    elsif r.dt = 'skip' then
      null;
    elsif r.dt = 'ARRAY' then
      execute format('update public.%I set %I = array_replace(array_replace(array_replace(%I, %L, %L), %L, %L), %L, %L) where %I::text like %L',
        r.t, r.col, r.col, 'lt_knife_7_hq', 'lt_knife_6_hq', 'lt_knife_7', 'lt_knife_6', 'r_lt_knife_7', 'r_lt_knife_6', r.col, '%lt_knife_7%');
    else
      for i in 1 .. array_length(pairs, 1) loop
        execute format('update public.%I set %I = %L where %I = %L', r.t, r.col, pairs[i][2], r.col, pairs[i][1]);
      end loop;
    end if;
  end loop;
  delete from public.world_crafting_recipes where recipe_id = 'r_lt_knife_7';
  set constraints all immediate;
  alter table public.world_item_catalog disable trigger user;
  delete from public.world_item_catalog where item_id = 'lt_knife_7_hq';
  delete from public.world_item_catalog where item_id = 'lt_knife_7';
  alter table public.world_item_catalog enable trigger user;
  if exists (select 1 from public.world_tool_lines where item_id like 'lt_knife_7%') then raise exception 'lt_knife_7 남음'; end if;
end $rn$;

update public.world_crafting_recipes set required_location = '야행국 본부 정청' where recipe_id = 'make_oil_lamp' and required_location = '본부 정청';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
