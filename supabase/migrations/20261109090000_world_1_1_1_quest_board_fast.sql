create or replace function pg_temp.yh_fix(p_name text, p_pairs text[], p_n int) returns void language plpgsql as $f$
declare d text; i int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    if (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]) <> p_n then raise exception '함수 % 모양이 예상과 다릅니다', p_name; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

alter table public.world_quest_label_cache add column if not exists regions jsonb, add column if not exists mn jsonb;

select pg_temp.yh_fix('world_quest_task_label', array[
$q$declare nm jsonb := public.world_name_rules();
begin
  return coalesce((select l.label from public.world_quest_label_cache l where l.k = md5(p_task::text)), (select * from (select case$q$,
$q$declare nm jsonb; v_lbl text;
begin
  select l.label into v_lbl from public.world_quest_label_cache l where l.k = md5(p_task::text);
  if v_lbl is not null then return v_lbl; end if;
  nm := public.world_name_rules();
  return ((select * from (select case$q$], 1);

select pg_temp.yh_fix('world_task_row', array[
$q$declare n int; it jsonb := case when jsonb_typeof(p_task -> 'items') = 'array' then p_task -> 'items' else '[]'::jsonb end;$q$,
$q$declare n int; it jsonb := case when jsonb_typeof(p_task -> 'items') = 'array' then p_task -> 'items' else '[]'::jsonb end; lc record;$q$,
$q$  return jsonb_build_object('label', public.world_quest_task_label(p_task),$q$,
$q$  select l.label, l.regions, l.mn into lc from public.world_quest_label_cache l where l.k = md5(p_task::text);
  return jsonb_build_object('label', coalesce(lc.label, public.world_quest_task_label(p_task)),$q$,
$q$    'regions', coalesce(p_task -> 'r', case when p_task ->> 't' = 'win' and p_task ? 'm' then$q$,
$q$    'regions', coalesce(p_task -> 'r', case when lc.label is not null then lc.regions when p_task ->> 't' = 'win' and p_task ? 'm' then$q$,
$q$    'mn', case when p_task ->> 't' = 'win' and p_task ? 'm' then$q$,
$q$    'mn', case when lc.label is not null then lc.mn when p_task ->> 't' = 'win' and p_task ? 'm' then$q$], 1);

create or replace function public.world_quest_label_refresh()
 returns integer
 language plpgsql
 security definer
 set search_path to ''
as $function$
declare n int;
begin
  delete from public.world_quest_label_cache where true;
  insert into public.world_quest_label_cache (k, label, regions, mn)
  select md5(t::text), public.world_quest_task_label(t),
         case when t ->> 't' = 'win' and t ? 'm' then (select jsonb_agg(distinct rm.region_id) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(t -> 'm'))) end,
         case when t ->> 't' = 'win' and t ? 'm' then (select jsonb_agg(rm.monster_name order by rm.monster_name) from public.world_region_monsters rm where rm.monster_id in (select jsonb_array_elements_text(t -> 'm'))) end
    from (select distinct t from (select jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t from public.world_quest_steps s
                                  union all select jsonb_array_elements(coalesce(f.need -> 'tasks', '[]'::jsonb)) from public.world_faction_scenes f) z) y
   where public.world_quest_task_label(t) is not null
  on conflict (k) do nothing;
  get diagnostics n = row_count;
  return n;
end $function$;

select public.world_quest_label_refresh();
update public.world_app_meta set value = '20261109090000' where key = 'db_version';
