create or replace function public.world_regular_rare()
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare m jsonb := public.world_meisho_rules(); rare text[]; more text[];
begin
  select array_agg(distinct z.x) into rare from (
    select f.fish_id as x from public.world_fish_species f where coalesce(f.named, false)
    union select jsonb_array_elements_text(k.value -> 'items') from jsonb_each(m -> 'kinds') k
    union select l.value #>> '{}' from jsonb_each(m -> 'lamp' -> 'items') l) z;
  rare := coalesce(rare, '{}');
  loop
    select array_agg(distinct w.output_item) into more from public.world_crafting_recipes w
     where not (w.output_item = any (rare))
       and not exists (select 1 from public.world_crafting_recipes v
                        where v.output_item = w.output_item
                          and not exists (select 1 from jsonb_object_keys(v.ingredients) k where k = any (rare)));
    exit when more is null;
    rare := rare || more;
  end loop;
  return rare;
end $f$;

create or replace function public.world_regular_pool(p_line text, p_rank int)
 returns text[] language plpgsql stable security definer set search_path = pg_catalog, public
as $f$
declare r jsonb := public.world_regular_rules(); span int := (r ->> 'span')::int; hi int := greatest(p_rank, 5); lo int := greatest(1, p_rank - span); out text[]; rare text[] := '{}';
begin
  if p_line <> 'fishing' and not (r -> 'lines' ? p_line) then rare := public.world_regular_rare(); end if;
  for pass in 1 .. 2 loop
    if p_line = 'fishing' then
      select array_agg(distinct f.fish_id order by f.fish_id) into out from public.world_fish_species f join public.world_item_catalog i on i.item_id = f.fish_id
       where f.active and not coalesce(f.named, false) and f.min_level <= hi and f.min_level >= case when pass = 1 then lo - 3 else 0 end
         and i.tradeable and not coalesce(i.market_only, false);
    elsif r -> 'lines' ? p_line then
      select array_agg(distinct x order by x) into out from public.world_gathering_spots s, unnest(s.loot_items) x join public.world_item_catalog i on i.item_id = x
       where s.active and s.category = any (array(select jsonb_array_elements_text(r -> 'lines' -> p_line)))
         and s.min_level <= hi and s.min_level >= case when pass = 1 then lo - 3 else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.category = 'material';
    else
      select array_agg(distinct w.output_item order by w.output_item) into out from public.world_crafting_recipes w join public.world_item_catalog i on i.item_id = w.output_item
       where public.world_craft_line_of(w.craft_field) = p_line and coalesce(w.minimum_level, 1) <= hi and coalesce(w.minimum_level, 1) >= case when pass = 1 then lo else 0 end
         and i.tradeable and not coalesce(i.market_only, false) and i.base_item_id is null and i.category not in ('furniture', 'outfit', 'pet', 'quest')
         and not (w.output_item = any (rare));
    end if;
    exit when coalesce(array_length(out, 1), 0) >= (r ->> 'orders')::int;
  end loop;
  return coalesce(out, '{}');
end $f$;

grant create on schema public to fn_owner_field;
alter function public.world_regular_rare() owner to fn_owner_field;
revoke create on schema public from fn_owner_field;
revoke all on function public.world_regular_rare() from public, anon, authenticated;
grant execute on function public.world_regular_rare() to service_role;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125010000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
