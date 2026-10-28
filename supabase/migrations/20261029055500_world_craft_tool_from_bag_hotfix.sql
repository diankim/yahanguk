-- 조용한 수정(2026-10-29 저녁, 운영 DB에 바로 적용함 · db_version은 올리지 않아 새로고침 안내 없음):
-- 제작할 때 필요한 도구를 「도구 칸에 장착한 것」만 인정해, 곡괭이를 낀 채 채집도가 가방에 있어도 갈아 끼워야 했다.
-- 이제 장착했든 가방에 있든 그 도구(또는 같은 계열의 상위 도구, world_tool_covers)를 가지고 있으면 된다. 화면(bag.js)은 이미 가방까지 보고 있었다.
do $T$ begin
grant fn_owner_18452 to postgres with inherit true, set true;
execute $X$ do $$ declare d text := pg_get_functiondef('public.world_craft_item(text)'::regprocedure);
  a text := E'  select coalesce(i.tier,0) into tool_tier from public.world_character_equipment e join public.world_item_catalog i on i.item_id=e.item_id where e.owner_id=uid and e.slot=''tool'' and public.world_tool_covers(e.item_id, r.required_tool);\n  if not found then raise exception ''필요 도구를 장착해야 합니다: %''';
  b text := E'  select max(coalesce(i.tier,0)) into tool_tier from public.world_item_catalog i where public.world_tool_covers(i.item_id, r.required_tool) and (coalesce((c.inventory->>i.item_id)::numeric,0)>0 or exists (select 1 from public.world_character_equipment e where e.owner_id=uid and e.item_id=i.item_id));\n  if tool_tier is null then raise exception ''필요 도구가 가방에 있어야 합니다: %''';
begin
  if position('필요 도구가 가방에 있어야 합니다' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '제작 도구 검사 고칠 자리'; end if;
  execute replace(d, a, b);
end $$ $X$;
grant fn_owner_18452 to postgres with inherit false, set false;
end $T$;
