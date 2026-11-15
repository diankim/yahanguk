create or replace function public.world_bijang_rules()
 RETURNS jsonb
 LANGUAGE sql
 IMMUTABLE
AS $function$
  select jsonb_build_object(
    'maps', jsonb_build_array(
      jsonb_build_object('tier', 1, 'id', 'bj_map_1', 'name', '낡은 비장도', 'lv', 30, 'lo', 30, 'hi', 37),
      jsonb_build_object('tier', 2, 'id', 'bj_map_2', 'name', '귀한 비장도', 'lv', 38, 'lo', 38, 'hi', 43),
      jsonb_build_object('tier', 3, 'id', 'bj_map_3', 'name', '봉인된 비장도', 'lv', 44, 'lo', 44, 'hi', 46)),
    'hold', 1, 'party_max', 4, 'gather_s', 60, 'stamina', 1, 'entry_day', 3, 'rooms', 5,
    'door_pct', jsonb_build_array(50, 60, 70),
    'reveal_pct', jsonb_build_array(25, 30, 35, 40),
    'room_guard_pct', 100,
    'guard', jsonb_build_object('lv_up', 3, 'hp_mul', 1.2, 'atk_mul', 1.0, 'room_rank', 'guardian'),
    'chest', jsonb_build_object(
      '1', jsonb_build_object('gil', jsonb_build_array(120, 280), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'steel_ingot', 'w', 3), jsonb_build_object('id', 'spirit_bark', 'w', 3), jsonb_build_object('id', 'reinforced_lumber', 'w', 3),
        jsonb_build_object('id', 'reed_silk', 'w', 2), jsonb_build_object('id', 'inverted_incense', 'w', 2), jsonb_build_object('id', 'moonless_silk', 'w', 2),
        jsonb_build_object('id', 'oblivion_crystal', 'w', 2), jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1))),
      '2', jsonb_build_object('gil', jsonb_build_array(220, 450), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'gwiheo_iron', 'w', 3), jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'jade_shard', 'w', 2),
        jsonb_build_object('id', 'blank_hanji', 'w', 2), jsonb_build_object('id', 'meokbi_ebony', 'w', 2), jsonb_build_object('id', 'spirit_core', 'w', 1), jsonb_build_object('id', 'hair_pattern', 'w', 1),
        jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1))),
      '3', jsonb_build_object('gil', jsonb_build_array(350, 700), 'n', jsonb_build_array(1, 2), 'items', jsonb_build_array(
        jsonb_build_object('id', 'register_slip', 'w', 2), jsonb_build_object('id', 'drifting_name_thread', 'w', 2), jsonb_build_object('id', 'erased_plate', 'w', 2),
        jsonb_build_object('id', 'yoin_blood', 'w', 2), jsonb_build_object('id', 'gwiheo_pearl', 'w', 1), jsonb_build_object('id', 'spirit_core', 'w', 1), jsonb_build_object('id', 'hair_pattern', 'w', 2),
        jsonb_build_object('id', 'mz_herb', 'w', 1), jsonb_build_object('id', 'mz_wood', 'w', 1), jsonb_build_object('id', 'mz_stone', 'w', 1)))),
    'egg', jsonb_build_object('id', 'pet_egg_3', 'pct', jsonb_build_array(0.5, 1, 2)),
    'final', jsonb_build_object('gil', jsonb_build_array(1000, 1800, 2800), 'picks', jsonb_build_array(1, 1, 2), 'tiers', jsonb_build_object(
      '1', jsonb_build_array(
        jsonb_build_object('id', 'mz_herb_j', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_wood_j', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_stone_j', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'pet_egg_3', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hair_pattern', 'w', 4, 'n', 1),
        jsonb_build_object('id', 'hf_bj_map_frame', 'w', 2, 'n', 1),
        jsonb_build_object('pet', 'bj_mandarin_duck', 'w', 1),
        jsonb_build_object('pet', 'bj_horseshoe_crab', 'w', 1),
        jsonb_build_object('pet', 'bj_pink_marten', 'w', 1),
        jsonb_build_object('pet', 'bj_silkmoth', 'w', 1)),
      '2', jsonb_build_array(
        jsonb_build_object('id', 'mz_herb_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_wood_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_stone_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'pet_egg_3', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hair_pattern', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'hf_bj_map_frame', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hf_bj_vault_gate', 'w', 2, 'n', 1),
        jsonb_build_object('pet', 'bj_mandarin_duck', 'w', 1),
        jsonb_build_object('pet', 'bj_horseshoe_crab', 'w', 1),
        jsonb_build_object('pet', 'bj_pink_marten', 'w', 1),
        jsonb_build_object('pet', 'bj_silkmoth', 'w', 1),
        jsonb_build_object('pet', 'bj_mirage_cat', 'w', 1),
        jsonb_build_object('pet', 'bj_black_goat', 'w', 1),
        jsonb_build_object('pet', 'bj_seahorse', 'w', 1),
        jsonb_build_object('pet', 'bj_rainbow_lizard', 'w', 1)),
      '3', jsonb_build_array(
        jsonb_build_object('id', 'mz_herb_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_wood_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'mz_stone_n', 'w', 3, 'n', 1),
        jsonb_build_object('id', 'pet_egg_3', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hair_pattern', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hf_bj_vault_gate', 'w', 2, 'n', 1),
        jsonb_build_object('id', 'hf_bj_name_chest', 'w', 2, 'n', 1),
        jsonb_build_object('pet', 'bj_mandarin_duck', 'w', 1),
        jsonb_build_object('pet', 'bj_horseshoe_crab', 'w', 1),
        jsonb_build_object('pet', 'bj_pink_marten', 'w', 1),
        jsonb_build_object('pet', 'bj_silkmoth', 'w', 1),
        jsonb_build_object('pet', 'bj_mirage_cat', 'w', 1),
        jsonb_build_object('pet', 'bj_black_goat', 'w', 1),
        jsonb_build_object('pet', 'bj_seahorse', 'w', 1),
        jsonb_build_object('pet', 'bj_rainbow_lizard', 'w', 1),
        jsonb_build_object('pet', 'bj_phoenix', 'w', 1.5),
        jsonb_build_object('pet', 'bj_bukcheong_lion', 'w', 1.5),
        jsonb_build_object('pet', 'bj_mountain_turtle', 'w', 1.5),
        jsonb_build_object('pet', 'bj_rose_wolf', 'w', 1.5),
        jsonb_build_object('pet', 'bj_moon_halo', 'w', 1.5)))),
    'open', jsonb_build_object('pct', 30, 'cap', 60, 'gear', 'mz_soil_pct'),
    'fail', jsonb_build_object(
      '1', jsonb_build_object('n', jsonb_build_array(2, 4), 'items', jsonb_build_array(jsonb_build_object('id', 'herb', 'w', 1), jsonb_build_object('id', 'wood', 'w', 1), jsonb_build_object('id', 'ore', 'w', 1), jsonb_build_object('id', 'charcoal', 'w', 1), jsonb_build_object('id', 'raw_iron', 'w', 1), jsonb_build_object('id', 'resin', 'w', 1))),
      '2', jsonb_build_object('n', jsonb_build_array(2, 4), 'items', jsonb_build_array(jsonb_build_object('id', 'iron_ingot', 'w', 1), jsonb_build_object('id', 'lumber', 'w', 1), jsonb_build_object('id', 'lacquer', 'w', 1), jsonb_build_object('id', 'seal_paper', 'w', 1), jsonb_build_object('id', 'inkstone', 'w', 1))),
      '3', jsonb_build_object('n', jsonb_build_array(2, 3), 'items', jsonb_build_array(jsonb_build_object('id', 'iron_ingot', 'w', 1), jsonb_build_object('id', 'talisman_thread', 'w', 1), jsonb_build_object('id', 'medicine_base', 'w', 1), jsonb_build_object('id', 'lacquer', 'w', 1)))),
    'titles', jsonb_build_array(1, 5, 20), 'seal', 'sl_bj')
$function$;

create or replace function pg_temp.yh_fix2(p_fn regprocedure, p_old text, p_new text) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); n int;
begin
  n := (length(src) - length(replace(src, p_old, ''))) / greatest(length(p_old), 1);
  if n <> 1 then raise exception 'yh_fix2 %: 조각이 % 번 있음', p_fn, n; end if;
  execute replace(src, p_old, p_new);
end $f$;

select pg_temp.yh_fix2('public.world_meisho_rules()'::regprocedure,
$o$"soil":{"pct":{"1":12,"2":9,"3":6},"cap":30,"grade_lv":[[44,3],[38,2],[30,1]]}$o$, $n$"soil":{"grade_lv":[[44,3],[38,2],[30,1]]}$n$);
select pg_temp.yh_fix2('public.world_meisho_rules()'::regprocedure,
$o$"mz_soil_pct":"흙 살피기 비장도"$o$, $n$"mz_soil_pct":"비장고가 열릴 확률"$n$);

select pg_temp.yh_fix2('public.world_meisho_soil(text)'::regprocedure,
$o$  pct := least((ru #>> '{soil,cap}')::numeric, (ru -> 'soil' -> 'pct' ->> g::text)::numeric * greatest(0, 1 + public.world_meisho_gear(uid, 'mz_soil_pct') / 100.0));
  rolled := random() * 100 < pct;
  if rolled then got := coalesce(public.world_bijang_grant(uid, g), false); end if;$o$,
$n$  rolled := true;
  got := coalesce(public.world_bijang_grant(uid, g), false);$n$);

select pg_temp.yh_fix2('public.world_bijang_open(text)'::regprocedure,
$o$rg public.world_map_regions%rowtype; mid uuid;$o$,
$n$rg public.world_map_regions%rowtype; mid uuid; br jsonb := public.world_bijang_rules(); fl jsonb; pct numeric; jid text; jn int; jname text;$n$);

select pg_temp.yh_fix2('public.world_bijang_open(text)'::regprocedure,
$o$  update public.world_characters set inventory = case when (inventory ->> p_item)::int <= 1 then inventory - p_item else public.world_inv_add(inventory, p_item, -1) end, updated_at = now()$o$,
$n$  pct := least((br #>> '{open,cap}')::numeric, (br #>> '{open,pct}')::numeric * greatest(0, 1 + public.world_meisho_gear(uid, br #>> '{open,gear}') / 100.0));
  if random() * 100 >= pct then
    fl := br -> 'fail' -> t::text;
    select x ->> 'id' into jid from jsonb_array_elements(coalesce(fl -> 'items', '[]'::jsonb)) x
     where exists (select 1 from public.world_item_catalog i where i.item_id = x ->> 'id')
     order by -ln(greatest(random(), 1e-9)) / greatest(coalesce((x ->> 'w')::numeric, 1), 0.01) limit 1;
    jn := coalesce((fl #>> '{n,0}')::int, 1) + floor(random() * (coalesce((fl #>> '{n,1}')::int, 1) - coalesce((fl #>> '{n,0}')::int, 1) + 1))::int;
    select item_name into jname from public.world_item_catalog where item_id = jid;
    perform set_config('yh.bag_drop', 'on', true);
    update public.world_characters set inventory = case when jid is null then x.inv else public.world_inv_add(x.inv, jid, jn) end, updated_at = now()
      from (select case when (inventory ->> p_item)::int <= 1 then inventory - p_item else public.world_inv_add(inventory, p_item, -1) end inv from public.world_characters where owner_id = uid) x
     where owner_id = uid;
    return jsonb_build_object('ok', true, 'opened', false, 'tier', t, 'item', jid, 'qty', jn,
      'content', (mr ->> 'name') || '을(를) 펼쳐 보니 비장고를 가리키지 않는 빈 그림이었습니다.' || case when jid is not null then ' 지도 틈에 끼어 있던 ' || jname || ' ' || jn || '개를 챙겼습니다.' else '' end);
  end if;
  update public.world_characters set inventory = case when (inventory ->> p_item)::int <= 1 then inventory - p_item else public.world_inv_add(inventory, p_item, -1) end, updated_at = now()$n$);

select pg_temp.yh_fix2('public.world_bijang_final_give(uuid, uuid)'::regprocedure,
$o$jsonb_array_elements(coalesce(f -> 'items', '[]'::jsonb)) x$o$,
$n$jsonb_array_elements(coalesce(f -> 'tiers' -> r.tier::text, '[]'::jsonb)) x$n$);

select pg_temp.yh_fix2('public.world_item_sources_all(text)'::regprocedure,
$o$jsonb_array_elements(public.world_bijang_rules() -> 'final' -> 'items') v$o$,
$n$jsonb_each(public.world_bijang_rules() -> 'final' -> 'tiers') ft, jsonb_array_elements(ft.value) v$n$);

update public.world_item_catalog set description = replace(replace(replace(replace(description,
  '쓰고 흙을 살피면 묻힌 것이 더 잘 보인다.', '쓰고 비장도를 펼치면 비장고를 가리키는 자리가 더 잘 보인다.'),
  '흙을 살필 때 눈이 밝아진다.', '비장도를 펼칠 때 눈이 밝아진다.'),
  '발끝으로 흙의 결을 느낀다.', '비장도 위의 옛 흙길을 발끝으로 읽는다.'),
  '흙을 살필 때 묻힌 것의 기척을 잡는다.', '비장도를 펼칠 때 묻힌 곳간의 기척을 잡는다.')
 where equipment_traits ? 'mz_soil_pct';

update public.world_patch_notes set body = body || '

## 2.3.4
- 명소의 흙을 살피면 이제 늘 비장도가 나옵니다(명소마다 하루 한 번, 등급마다 한 장까지 지니는 것은 그대로).
- 비장도를 펼치면 30% 확률로 비장고가 열려 지도에 자리가 뜹니다. 열리지 않으면 비장도는 사라지고 지도 틈에 끼어 있던 재료를 조금 챙깁니다.
- 명장 장비의 「흙 살피기」 효과는 「비장고가 열릴 확률」을 올리는 효과로 바뀌었습니다(최대 60%).
- 비장고 마지막 방의 보상이 등급마다 달라졌습니다. 높은 등급일수록 「이름 서린」 재료와 귀한 가구, 그 등급에서만 나오는 비장고 동무가 나옵니다.
' where note_id = '2.3.0' and body not like '%## 2.3.4%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118160000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
