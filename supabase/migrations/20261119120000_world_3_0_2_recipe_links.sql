lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_setjson(p_fn regprocedure, p_j jsonb) returns void language plpgsql as $f$
declare src text := pg_get_functiondef(p_fn); body text := (select prosrc from pg_proc where oid = p_fn);
begin
  if position(body in src) = 0 then raise exception 'yh_setjson %: 본문을 못 찾음', p_fn; end if;
  execute replace(src, body, ' select ' || quote_literal(p_j::text) || '::jsonb ');
end $f$;

do $d$
declare n int;
begin
  update public.world_crafting_recipes set ingredients = '{"herb": 2, "cheong_carp": 1, "plank_water_jar": 1}'::jsonb
   where recipe_id = 'r_cheong_carp_steam' and ingredients = '{"herb": 2, "cheong_carp": 1}'::jsonb;
  get diagnostics n = row_count; if n <> 1 then raise exception '청씨 잉어찜 제작법을 못 찾음'; end if;
  update public.world_crafting_recipes set ingredients = '{"lacquer": 1, "waterlogged_plank": 2, "plank_water_jar": 1}'::jsonb
   where recipe_id = 'r_hf_floor_cheong_prow' and ingredients = '{"lacquer": 1, "waterlogged_plank": 3}'::jsonb;
  get diagnostics n = row_count; if n <> 1 then raise exception '청씨 선단 뱃머리 제작법을 못 찾음'; end if;
  update public.world_crafting_recipes set ingredients = '{"md_litter": 1, "lacquer": 2, "king_ember_ash": 2}'::jsonb
   where recipe_id = 'r_hf_floor_empty_throne_stool' and ingredients = '{"lumber": 2, "lacquer": 2, "king_ember_ash": 2}'::jsonb;
  get diagnostics n = row_count; if n <> 1 then raise exception '빈 옥좌 걸상 제작법을 못 찾음'; end if;
  update public.world_item_catalog set reference_price = 1450 where item_id = 'hf_floor_empty_throne_stool' and reference_price = 1232;
  get diagnostics n = row_count; if n <> 1 then raise exception '빈 옥좌 걸상 시세를 못 찾음'; end if;
end $d$;

select pg_temp.yh_setjson('public.world_project_rules()'::regprocedure,
  jsonb_set(public.world_project_rules(), '{v,cheong_carp_steam}', to_jsonb(least(220, round((2 * 12 + 32 + 303) / 2.0 * 1.2))::int)));

update public.world_patch_notes set body = body || $N$
- 상점·거래소·세력 비고·무용담 교환 목록과 물품 정보 창에 가구·옷·꼬마 동무 바구니를 이미 가졌는지(가방·창고·곳간·놓은 수, 옷장에 있음, 이미 있는 동무)가 파란 글씨로 보입니다.
- 가방에서 사용·열기 단추가 없는 물품은 안전지대에서 「버리기」 옆 「창고」 단추로 바로 맡길 수 있습니다.
- 들것과 뱃판 물동이가 다른 제작법에도 쓰입니다. 청씨 잉어찜(뱃판 물동이 1 더함)·청씨 선단 뱃머리(물 먹은 뱃판 하나를 뱃판 물동이로)·빈 옥좌 걸상(가공 부적목 둘을 들것 하나로, 시세 1,450전)입니다.$N$
 where note_id = '3.0.0' and position('들것과 뱃판 물동이가 다른 제작법에도' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261119120000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
