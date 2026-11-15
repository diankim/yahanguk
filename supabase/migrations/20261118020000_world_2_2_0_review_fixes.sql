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
        for o in execute format('select ctid::text from public.%I where %I = %L', r.t, r.col, pairs[i][1]) loop
          begin
            execute format('update public.%I set %I = %L where ctid = %L::tid', r.t, r.col, pairs[i][2], o);
          exception when unique_violation then
            execute format('delete from public.%I where ctid = %L::tid', r.t, o);
          end;
        end loop;
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

update public.world_patch_notes set body = replace(body,
  '- 먹줄 긋기 · 따라 쓰는 붓 · 발자국 · 이름 지우기의 네 단계가 있습니다. 따라 쓰는 붓은 지난 라운드에 많이 고른 행동을 흉내 내고, 발자국 단계에서는 같은 칸에 두 번 서면 먹에 묶이며, 이름 지우기에서는 한 사람이 가운데를 지키는 동안 나머지가 이름을 불러 주어야 합니다.',
  '- 지워지는 칸 · 따라 쓰는 붓 · 발자국 · 가운데 칸의 네 단계가 있습니다. 그림자가 무엇을 하려는지는 라운드 띠의 낌새로 보이고, 어떻게 받아칠지는 직접 겪으며 찾아야 합니다.')
 where note_id = '2.0.0';

select pg_temp.yh_fix2('public.world_battle_open(uuid,text,uuid,integer,integer)'::regprocedure,
  $o$(v_gq AND p_depth < 3 AND random() < 0.04)$o$,
  $n$(v_gq AND p_depth < 3 AND random() < CASE WHEN (SELECT c.level FROM public.world_characters c WHERE c.owner_id = p_owner) < coalesce((SELECT min(n.min_level) FROM public.world_exploration_nodes n WHERE n.region_id = p_region AND n.hierarchy_level >= 3), 0) THEN 0.35 ELSE 0.04 END)$n$);

with lv as (select s.quest_id, max(r.min_level) m from public.world_quest_steps s
  cross join lateral (
    select jsonb_array_elements_text(case jsonb_typeof(s.need -> 'at') when 'array' then s.need -> 'at' when 'string' then jsonb_build_array(s.need -> 'at') else '[]'::jsonb end) rid
    union select jsonb_array_elements_text(case jsonb_typeof(t -> 'r') when 'array' then t -> 'r' when 'string' then jsonb_build_array(t -> 'r') else '[]'::jsonb end)
      from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t) x
  join public.world_map_regions r on r.region_id = x.rid group by 1)
update public.world_quests q set min_level = lv.m from lv where lv.quest_id = q.quest_id and lv.m > q.min_level;

select pg_temp.yh_fix2('public.world_cosmetic_equip(text,text)'::regprocedure,
  $o$'content', '「' || nm || '」을(를) 달았습니다.'$o$,
  $n$'content', case when nm like '%「%' then nm else '「' || nm || '」' end || '을(를) 달았습니다.'$n$);

update public.world_cosmetic_catalog set condition_text = '묵적록의 명어 여섯을 모두 낚는다' where cosmetic_key = 'sl_muk' and condition_text = '명어 여섯을 모두 낚으면';

update public.world_crafting_recipes set required_location = '야행국 본부 정청' where recipe_id = 'make_oil_lamp' and required_location = '본부 정청';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
