CREATE OR REPLACE FUNCTION public.world_rate_check(p_kind text, p_uid uuid, p_ref uuid DEFAULT NULL::uuid)
 RETURNS void
 LANGUAGE plpgsql
 STABLE
 SET search_path TO 'pg_catalog', 'public'
AS $function$
begin
  if p_uid is null then return; end if;
  if p_kind = 'gather' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'gather' and created_at > now() - interval '12 seconds') then
    raise exception '채집은 12초마다 가능합니다. 잠시 후 다시 시도하세요.';
  elsif p_kind = 'fish' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'fish' and created_at > now() - interval '15 seconds') then
    raise exception '찌를 다시 던지려면 조금 더 기다리세요.';
  elsif p_kind = 'search' and exists (select 1 from public.world_events where actor_id = p_uid and event_type = 'explore' and created_at > now() - interval '900 milliseconds') then
    raise exception '숨을 고르는 중입니다. 잠시 후 다시 탐색하세요.';
  elsif p_kind = 'battle' and exists (select 1 from public.world_active_encounters where owner_id = p_uid and last_action_at > now() - interval '1 second') then
    raise exception '전투 행동 간격이 너무 짧습니다. 잠시 후 다시 시도하세요.';
  elsif p_kind = 'raid' and exists (select 1 from public.world_raid_members where raid_id = p_ref and owner_id = p_uid and last_action_at > now() - interval '1 second') then
    raise exception '숨을 고르는 중입니다. 잠시 후 다시 행동하세요.';
  end if;
end $function$;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_field_search()'::regprocedure), E'\r\n', E'\n');
  if position('world_rate_check(''search''' in d) > 0 then return; end if;
  a := '  SELECT * INTO c FROM public.world_characters WHERE owner_id = uid FOR UPDATE;';
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.4o world_field_search 기준 문구가 없습니다'; end if;
  execute replace(d, a, '  PERFORM public.world_rate_check(''search'', uid);' || E'\n' || a);
end $w$;

update public.world_item_catalog set use_fx = jsonb_set(use_fx, '{stam}', '2'::jsonb)
where item_id = 'fish_porridge' and (use_fx->>'stam')::int = 4;

update public.world_crafting_recipes set output_qty = 3 where recipe_id = 'make_travel_ration' and output_qty = 5;

update public.world_patch_notes set body = body ||
  E'\n### 탐색 간격과 어죽\n- 탐색은 짧은 간격을 두고 한 번씩 할 수 있습니다. 누르면 탐색 단추가 잠깐 잠겼다가 풀립니다. 아주 빠르게 연달아 누르는 탐색이 서버에 큰 부담을 주고 있어서입니다.\n- 어죽으로 채우는 탐색력을 줄였습니다. 정신 회복은 그대로입니다.\n- 노정 건량을 만들 때 나오는 개수를 줄였습니다. 상점에서 사는 값은 그대로입니다.\n- 우수품 요리도 탐색력은 보통 요리와 같습니다(원래도 같았습니다). 물품 설명에 그렇게 적습니다.\n'
where note_id = '1.0.0' and position('### 탐색 간격과 어죽' in body) = 0;

update public.world_app_meta set value = '20261106100000' where key = 'db_version';
