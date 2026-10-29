-- ─────────────────────────────────────────────────────────────
-- A. 7.1 ① 편의: 방어구 능력치 조건(갈래의 두 능력치 중 높은 것) · 능력치 한꺼번에 분배(미리 보기 → 확정) · 생활 칸 셋(채집·탐사·낚시)
-- ─────────────────────────────────────────────────────────────

-- ① 방어구: 적힌 능력치와 짝 능력치(체질↔힘 · 민첩↔감각 · 의지↔영기) 가운데 높은 것으로 본다
create or replace function public.world_stat_pair(p_stat text) returns text
language sql immutable set search_path = '' as $$
  select case p_stat when 'vitality' then 'strength' when 'strength' then 'vitality'
                     when 'agility' then 'perception' when 'perception' then 'agility'
                     when 'willpower' then 'spirit_affinity' when 'spirit_affinity' then 'willpower' else p_stat end
$$;
grant execute on function public.world_stat_pair(text) to fn_owner_18453;

select pg_temp.yh_patch('public.world_equip_item(text)', 'elsif coalesce((to_jsonb(c)->>stat_key)::int,0)<required then raise exception ''능력치 조건 미달: % % 필요'',public.world_stat_name(stat_key),required;',
  'elsif (case when it.category = ''armor'' then greatest(coalesce((to_jsonb(c)->>stat_key)::int,0), coalesce((to_jsonb(c)->>public.world_stat_pair(stat_key))::int,0))
        else coalesce((to_jsonb(c)->>stat_key)::int,0) end)<required then
    raise exception ''능력치 조건 미달: % % 필요'', case when it.category = ''armor'' then public.world_stat_name(stat_key) || '' 또는 '' || public.world_stat_name(public.world_stat_pair(stat_key)) else public.world_stat_name(stat_key) end, required;');

-- ② 능력치 분배: 화면에서 쌓은 점수를 한 번에(포인트 합·능력치마다 상한 검사, 캐릭터 행 갱신 한 번 · 기록 한 줄)
create or replace function public.world_allocate_stats(p_alloc jsonb) returns jsonb
language plpgsql security definer set search_path = '' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; k text; v jsonb; n int; tot int := 0; cap int; sets text := ''; clean jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if jsonb_typeof(p_alloc) is distinct from 'object' then raise exception '올릴 능력치를 고르세요.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 등록하세요.'; end if;
  for k, v in select key, value from jsonb_each(p_alloc) loop
    if k not in ('strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity') then raise exception '알 수 없는 능력치입니다.'; end if;
    if jsonb_typeof(v) <> 'number' or v::text !~ '^[0-9]{1,3}$' then raise exception '올릴 점수가 올바르지 않습니다.'; end if;
    n := v::text::int;
    continue when n = 0;
    cap := least(100, public.world_stat_cap_of(c.job_key, k, c.level));
    if (to_jsonb(c) ->> k)::int + n > cap then
      raise exception '지금 레벨에서는 %을(를) %까지 올릴 수 있습니다(레벨이 오르면 늘어납니다).', public.world_stat_name(k), cap; end if;
    tot := tot + n; sets := sets || format('%I = %I + %s, ', k, k, n); clean := clean || jsonb_build_object(k, n);
  end loop;
  if tot = 0 then raise exception '올릴 능력치를 고르세요.'; end if;
  if tot > coalesce(c.stat_points, 0) then raise exception '능력치 포인트가 모자랍니다(남은 %점).', coalesce(c.stat_points, 0); end if;
  execute format('update public.world_characters set %s stat_points = stat_points - $2, updated_at = now() where owner_id = $1', sets) using uid, tot;
  select * into c from public.world_characters where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'progression', '능력치 분배 +' || tot, jsonb_build_object('stats', clean, 'level', c.level, 'stat_points', c.stat_points));
  return jsonb_build_object('spent', tot, 'level', c.level, 'experience', c.experience, 'stat_points', c.stat_points, 'strength', c.strength, 'agility', c.agility,
    'vitality', c.vitality, 'perception', c.perception, 'willpower', c.willpower, 'spirit_affinity', c.spirit_affinity);
end $$;
revoke all on function public.world_allocate_stats(jsonb) from public, anon;
grant execute on function public.world_allocate_stats(jsonb) to authenticated;

-- 미리 보기: 확정 전 한 번만 부른다(점수는 검사만 하고 쓰지 않음)
create or replace function public.world_combat_preview(p_alloc jsonb) returns jsonb
language plpgsql stable security definer set search_path = 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); k text; v jsonb; clean jsonb := '{}'::jsonb;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if jsonb_typeof(p_alloc) is distinct from 'object' then raise exception '올릴 능력치를 고르세요.'; end if;
  for k, v in select key, value from jsonb_each(p_alloc) loop
    if k not in ('strength', 'agility', 'vitality', 'perception', 'willpower', 'spirit_affinity') or jsonb_typeof(v) <> 'number' or v::text !~ '^[0-9]{1,3}$' then
      raise exception '올릴 점수가 올바르지 않습니다.'; end if;
    if v::text::int > 0 then clean := clean || jsonb_build_object(k, v::text::int); end if;
  end loop;
  return jsonb_build_object('current', public.world_combat_stats(uid) - 'weapon' - 'armor' - 'stats',
                            'after', public.world_combat_stats(uid, clean) - 'weapon' - 'armor' - 'stats');
end $$;
do $$ declare o text; begin
  select pg_get_userbyid(proowner) into o from pg_proc where oid = 'public.world_combat_profile(boolean)'::regprocedure;
  if not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute format('alter function public.world_combat_preview(jsonb) owner to %I', o);
  execute format('set role %I', o);
  revoke all on function public.world_combat_preview(jsonb) from public, anon;
  grant execute on function public.world_combat_preview(jsonb) to authenticated;
  reset role;
end $$;

-- ③ 생활 칸 셋: 채집(tool) · 탐사(explore: 나침반) · 낚시(fishing: 낚싯대). 칸은 equipment_traits.life_slot으로 정한다(없으면 채집)
--    제작 공구는 지금처럼 가방에 있으면 된다(world_craft_item). 나침반은 채집량 덤을 빼고 탐색 찾기 +20%(search_find_pct)만 남긴다
alter table public.world_character_equipment drop constraint world_character_equipment_slot_check;
alter table public.world_character_equipment add constraint world_character_equipment_slot_check
  check (slot = any (array['tool', 'explore', 'fishing', 'weapon', 'armor', 'charm', 'hat', 'shoes', 'norigae', 'amulet', 'mask']));
update public.world_item_catalog set equipment_traits = (equipment_traits - 'gathering_bonus_pct') || '{"life_slot": "explore", "trait": "탐사", "search_find_pct": 20}'::jsonb,
       description = '영맥과 숨은 자원을 가리키는 나침반. 탐사 칸에 장착하면 탐색할 때 숨은 길과 채집터를 더 잘 찾는다(찾을 확률 +20%).'
 where item_id = 'spirit_compass';
update public.world_item_catalog set equipment_traits = equipment_traits || '{"life_slot": "fishing"}'::jsonb where item_id in ('fishing_rod', 'spirit_rod');
-- 이미 도구 칸에 낀 나침반·낚싯대는 맞는 칸으로 옮긴다(새 칸은 비어 있어 겹치지 않음)
update public.world_character_equipment e set slot = i.equipment_traits ->> 'life_slot'
  from public.world_item_catalog i where i.item_id = e.item_id and e.slot = 'tool' and i.equipment_traits ? 'life_slot';

select pg_temp.yh_patch('public.world_equip_item(text)', ' slot_name:=it.category;',
  ' slot_name:=case when it.category = ''tool'' then coalesce(it.equipment_traits->>''life_slot'', ''tool'') else it.category end;');
select pg_temp.yh_patch('public.world_unequip_item(text)', '(''tool'', ''weapon'', ''armor'', ''hat'', ''shoes'', ''norigae'', ''amulet'', ''mask'')',
  '(''tool'', ''explore'', ''fishing'', ''weapon'', ''armor'', ''hat'', ''shoes'', ''norigae'', ''amulet'', ''mask'')');

-- 탐사 칸: 부서지지 않은 장비의 search_find_pct(가장 큰 것)
create or replace function public.world_explore_find_pct(p_uid uuid) returns numeric
language sql stable security definer set search_path = '' as $$
  select coalesce(max((i.equipment_traits ->> 'search_find_pct')::numeric), 0)
    from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
    left join public.world_item_durability dd on dd.owner_id = e.owner_id and dd.item_id = e.item_id
   where e.owner_id = p_uid and e.slot = 'explore' and coalesce(dd.durability, 1) > 0
$$;
revoke all on function public.world_explore_find_pct(uuid) from public, anon, authenticated;
grant execute on function public.world_explore_find_pct(uuid) to fn_owner_field;
select pg_temp.yh_patch('public.world_field_search()', '  IF EXISTS (SELECT 1 FROM public.world_character_equipment e LEFT JOIN public.world_item_durability dd ON dd.owner_id = e.owner_id AND dd.item_id = e.item_id
             WHERE e.owner_id = uid AND e.slot = ''tool'' AND e.item_id = ''spirit_compass'' AND coalesce(dd.durability, 1) > 0) THEN
    w_path := w_path * 1.2; w_spot := w_spot * 1.2;
  END IF;',
  '  -- 탐사 칸(나침반 등): 숨은 길·채집터 무게 +search_find_pct%
  w_path := w_path * (1 + public.world_explore_find_pct(uid) / 100.0); w_spot := w_spot * (1 + public.world_explore_find_pct(uid) / 100.0);');

-- 낚시: 낚시 칸에 낀 낚싯대(가방에 있을 때), 없으면 가방에서 가장 높은 단계 낚싯대. 단계가 그대로 rod 값(대나무 1·영사 2)
create or replace function public.world_fish_rod(p_uid uuid) returns text
language sql stable security definer set search_path = '' as $$
  select coalesce(
    (select e.item_id from public.world_character_equipment e join public.world_characters c on c.owner_id = e.owner_id
      where e.owner_id = p_uid and e.slot = 'fishing' and coalesce((c.inventory ->> e.item_id)::int, 0) > 0),
    (select i.item_id from public.world_characters c join public.world_item_catalog i
        on i.equipment_traits ->> 'life_slot' = 'fishing' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0
      where c.owner_id = p_uid order by i.tier desc, i.item_id limit 1))
$$;
revoke all on function public.world_fish_rod(uuid) from public, anon, authenticated;
grant execute on function public.world_fish_rod(uuid) to fn_owner_field;
select pg_temp.yh_patch('public.world_fish()', '  rod := case when coalesce((c.inventory ->> ''spirit_rod'')::int, 0) > 0 then 2 when coalesce((c.inventory ->> ''fishing_rod'')::int, 0) > 0 then 1 else 0 end;',
  '  rod := coalesce((select i.tier from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);');
select pg_temp.yh_patch('public.world_fish()', 'i.item_id = case rod when 2 then ''spirit_rod'' else ''fishing_rod'' end', 'i.item_id = public.world_fish_rod(uid)');
select pg_temp.yh_patch('public.world_fish()', 'i.item_id = ''spirit_rod'' and rod = 2', 'i.item_id = public.world_fish_rod(uid)');
select pg_temp.yh_patch('public.world_fish_spot()', '  rod := case when coalesce((c.inventory ->> ''spirit_rod'')::int, 0) > 0 then 2 when coalesce((c.inventory ->> ''fishing_rod'')::int, 0) > 0 then 1 else 0 end;',
  '  rod := coalesce((select i.tier from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);');
select pg_temp.yh_patch('public.world_fish_spot()', '''rod_name'', case rod when 2 then ''영사 낚싯대'' when 1 then ''대나무 낚싯대'' end',
  '''rod_name'', (select i.item_name from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid))');
