create or replace function public.world_story_shop_items() returns text[]
language sql stable set search_path = '' as $$
  select coalesce(array_agg(distinct n.i), '{}') from public.world_quests q
    join public.world_quest_steps s on s.quest_id = q.quest_id
    cross join lateral (
      select g.key i from jsonb_each(case when jsonb_typeof(s.need -> 'give') = 'object' then s.need -> 'give' else '{}'::jsonb end) g
      union all select g ->> 'item_id' from jsonb_array_elements(case when jsonb_typeof(s.need -> 'give') = 'array' then s.need -> 'give' else '[]'::jsonb end) g
      union all select x from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t, jsonb_array_elements_text(case when jsonb_typeof(t -> 'items') = 'array' then t -> 'items' else '[]'::jsonb end) x
    ) n
  where q.active and (q.kind = 'main' or q.cat like '외전·%') and n.i is not null
    and not exists (select 1 from public.world_crafting_recipes r where r.output_item = n.i)
$$;
revoke all on function public.world_story_shop_items() from public, anon, authenticated;
select pg_temp.yh_own('public.world_story_shop_items()', 'fn_owner_field');

select pg_temp.yh_fix('world_shop_refresh(text)', array[
  E'declare slot timestamptz := public.world_shop_slot();',
  E'declare slot timestamptz := public.world_shop_slot(); story text[];',
  E'if exists (select 1 from public.world_shop_stock where shop_id = p_shop and refreshed_at >= slot) then return; end if;',
  E'if exists (select 1 from public.world_shop_stock where shop_id = p_shop and refreshed_at >= slot) then return; end if;\n  story := public.world_story_shop_items();',
  E'or sc.item_id in (''gwiheo_charm'', ''seal_inkline'')',
  E'or sc.item_id in (''gwiheo_charm'', ''seal_inkline'') or sc.item_id = any(story)'
]);

with st as (select public.world_story_shop_items() a)
update public.world_shop_stock s set stock = 1 from st
 where s.stock = 0 and s.refreshed_at >= public.world_shop_slot() and s.item_id = any(st.a)
   and public.world_project_shop_item(s.shop_id, s.item_id) is null;

create or replace function public.world_item_shop_now(p_item text) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare slot timestamptz := public.world_shop_slot(); sh text; story text[] := public.world_story_shop_items();
begin
  if public.fn_owner_auth_uid() is null then raise exception '로그인이 필요합니다.'; end if;
  for sh in select distinct c.shop_id from public.world_shop_catalog c
             where c.item_id = p_item and exists (select 1 from public.world_map_regions m where m.shop_id = c.shop_id) loop
    perform public.world_shop_refresh(sh);
  end loop;
  return jsonb_build_object(
    'sold', exists (select 1 from public.world_shop_catalog c where c.item_id = p_item),
    'shops', coalesce((select jsonb_agg(x.region_id order by x.region_id) from (select distinct m.region_id from public.world_shop_stock s join public.world_map_regions m on m.shop_id = s.shop_id
               where s.item_id = p_item and s.stock > 0 and s.refreshed_at >= slot and public.world_project_shop_item(s.shop_id, p_item) is null) x), '[]'::jsonb),
    'always', p_item = any(story),
    'next_at', slot + interval '8 hours');
end $f$;
revoke all on function public.world_item_shop_now(text) from public, anon;
grant execute on function public.world_item_shop_now(text) to authenticated;
select pg_temp.yh_own('public.world_item_shop_now(text)', 'fn_owner_field');
