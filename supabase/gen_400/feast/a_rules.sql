create or replace function public.world_harbor_feast_rules()
 returns jsonb
 language sql
 immutable
 set search_path to 'pg_catalog'
as $function$
  select jsonb_build_object(
    'need', 12,
    'per_person', 3,
    'buff_h', 4,
    'eat_h', 2,
    'slot_h', 12,
    'tz', 'Asia/Seoul',
    'tie', 'soban',
    'keep_days', 2,
    'order', jsonb_build_array('meat', 'soban', 'sea'),
    'kinds', jsonb_build_object(
      'meat', jsonb_build_object('name', '고기상', 'key', 'hfeast_meat', 'buff', '고깃상의 힘', 'icon', 'spark', 'desc', '고기 요리가 가장 많이 오른 상', 'effects', jsonb_build_object('combat_damage_pct', 5)),
      'soban', jsonb_build_object('name', '소반', 'key', 'hfeast_soban', 'buff', '소반의 온기', 'icon', 'leaf', 'desc', '나물·밥·떡처럼 고기도 생선도 아닌 요리가 가장 많이 오른 상', 'effects', jsonb_build_object('healing_pct', 10)),
      'sea', jsonb_build_object('name', '바다상', 'key', 'hfeast_sea', 'buff', '바다상의 물때', 'icon', 'shield', 'desc', '생선 요리가 가장 많이 오른 상', 'effects', jsonb_build_object('gather_qty_pct', 8, 'fish_bite_pct', 5))),
    'sea_items', jsonb_build_array('fish_fillet'),
    'skip', jsonb_build_array('travel_ration', 'treat_fish'),
    'chat', '잔치 소식',
    'note', 'hfeast')
$function$;
revoke all on function public.world_harbor_feast_rules() from public, anon;
grant execute on function public.world_harbor_feast_rules() to authenticated, service_role;
do $g$ declare x text; begin
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' loop
    execute format('grant execute on function public.world_harbor_feast_rules() to %I', x);
  end loop;
end $g$;

insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, effects, max_stacks, active, icon, cure)
select k.value ->> 'key', k.value ->> 'buff', 'positive', '항구 나눔 잔칫상(' || (k.value ->> 'name') || ')에서 나눠 먹은 기운이 남아 있습니다.',
       (public.world_harbor_feast_rules() ->> 'buff_h')::int * 60, k.value -> 'effects', 1, true, k.value ->> 'icon', '시간이 지나면 사라집니다.'
  from jsonb_each(public.world_harbor_feast_rules() -> 'kinds') k
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, duration_minutes = excluded.duration_minutes,
  effects = excluded.effects, icon = excluded.icon, polarity = excluded.polarity, active = true;
