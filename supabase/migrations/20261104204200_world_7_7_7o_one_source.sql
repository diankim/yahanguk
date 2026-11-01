-- 7.7.7o — 한 곳에서만 고치게(사용자 결정 2026-11-02: 공용화·구조화로 관리 절차 줄이기)
--  ① 물품 사용 효과: world_item_fx의 CASE 표를 물품 표 칸 world_item_catalog.use_fx로 옮긴다.
--     world_item_fx는 그 칸을 읽고(서버 공용), 가방 정보(world_inventory_snapshot)의 물품 목록에도 실어 보내 화면 효과 문구(item.js USABLE)를 여기서 만든다.
--     → 새 소모품은 use_fx 한 칸만 채우면 서버(사용·파티 사용·귀허·원정 보급)와 화면(사용 단추·효과 문구·색·거르기)이 함께 따른다.
--  ② 거래소 전용: world_market_only의 하드코딩 목록 → world_item_catalog.market_only 칸(화면 core.js MARKET_ONLY도 물품 목록에서 읽음).
--  ③ 도구 계열: 화면 bag.js TOOL_LINE이 world_tool_lines를 손으로 베껴 두던 것을 물품 목록의 tl 칸으로.
--  권한은 늘리지 않는다: authenticated는 이미 world_item_catalog·world_status_catalog·world_tool_lines를 읽는다.
lock table public.world_characters in access exclusive mode;

alter table public.world_item_catalog add column if not exists use_fx jsonb;
alter table public.world_item_catalog add column if not exists market_only boolean not null default false;

-- ① 지금 CASE 표의 값을 그대로 옮긴다(값이 하나라도 있는 물품만, 우수품은 기본 물품 값을 쓰므로 비워 둔다)
do $m$
declare r record; f jsonb;
begin
  if position('use_fx' in pg_get_functiondef('public.world_item_fx(text)'::regprocedure)) = 0 then
    for r in select item_id from public.world_item_catalog where base_item_id is null loop
      f := public.world_item_fx(r.item_id);
      if coalesce((f->>'hp')::int, 0) <> 0 or coalesce((f->>'mn')::int, 0) <> 0 or coalesce((f->>'sp')::int, 0) <> 0
         or coalesce((f->>'er')::int, 0) <> 0 or coalesce((f->>'stam')::int, 0) <> 0
         or jsonb_array_length(coalesce(f->'buffs', '[]')) > 0 or jsonb_array_length(coalesce(f->'cures', '[]')) > 0 then
        update public.world_item_catalog set use_fx = f where item_id = r.item_id;
      end if;
    end loop;
  end if;
end $m$;

create or replace function public.world_item_fx(p_base text)
returns jsonb language plpgsql stable set search_path to 'pg_catalog', 'public' as $f$
-- 물품을 썼을 때의 회복·치료·기운(우수품·직업·상태 보정 전 기본값) — 원본은 world_item_catalog.use_fx(7.7.7o).
-- world_use_item·world_party_use_item·귀허 정산·원정 정산이 함께 쓰고, 화면은 가방 정보의 물품 목록 fx로 같은 값을 받는다.
#variable_conflict use_column
declare f jsonb;
begin
  select use_fx into f from public.world_item_catalog where item_id = p_base;
  return jsonb_build_object('hp', coalesce((f->>'hp')::int, 0), 'mn', coalesce((f->>'mn')::int, 0), 'sp', coalesce((f->>'sp')::int, 0),
    'er', coalesce((f->>'er')::int, 0), 'stam', coalesce((f->>'stam')::int, 0),
    'buffs', coalesce(f->'buffs', '[]'::jsonb), 'cures', coalesce(f->'cures', '[]'::jsonb));
end $f$;
revoke all on function public.world_item_fx(text) from public, anon, authenticated;
grant execute on function public.world_item_fx(text) to fn_owner_field;

-- ② 거래소 전용
update public.world_item_catalog set market_only = true
 where item_id in ('jade_shard', 'mirror_shard', 'thunder_ore', 'star_sand', 'monster_core', 'ember_crystal', 'sky_feather', 'rune_plate', 'reinforced_leather')
   and not market_only;
-- 주인 역할(fn_owner_field)의 실행 권한을 그대로 두려고 주인으로 바꾼다
set role fn_owner_field;
create or replace function public.world_market_only(p_item text)
returns boolean language sql stable set search_path to 'pg_catalog', 'public' as $f$
  -- 원본은 world_item_catalog.market_only(7.7.7o). 우수품은 기본 물품을 따른다.
  select coalesce((select market_only from public.world_item_catalog where item_id = public.world_item_base(p_item)), false)
$f$;
reset role;

-- ①②③ 가방 정보의 물품 목록에 fx(사용 효과)·mk(거래소 전용)·tl(도구 계열)과 효과 이름표(fxn: 상태 이름·지속·효과)를 싣는다
do $p$
declare d text;
begin
  d := replace(pg_get_functiondef('public.world_inventory_snapshot()'::regprocedure), E'\r\n', E'\n');
  if position('''mk''' in d) = 0 then
    if (length(d) - length(replace(d, '''crafting_specialization'',crafting_specialization)),''[]''::jsonb) into cat from public.world_item_catalog;', ''))) / length('''crafting_specialization'',crafting_specialization)),''[]''::jsonb) into cat from public.world_item_catalog;') <> 1 then
      raise exception '7.7.7o anchor inventory catalog';
    end if;
    d := replace(d, '''crafting_specialization'',crafting_specialization)),''[]''::jsonb) into cat from public.world_item_catalog;',
      '''crafting_specialization'',crafting_specialization) || jsonb_strip_nulls(jsonb_build_object(''fx'',use_fx,''mk'',case when market_only then 1 end,''tl'',(select t.line from public.world_tool_lines t where t.item_id = world_item_catalog.item_id limit 1)))),''[]''::jsonb) into cat from public.world_item_catalog;
 -- 7.7.7o: 사용 효과에 나오는 상태(기운·치료)의 이름·지속(분)·효과 — 화면이 효과 문구를 만든다
 select coalesce(jsonb_object_agg(s.status_key, jsonb_build_object(''n'', s.status_name, ''m'', s.duration_minutes, ''e'', s.effects)), ''{}''::jsonb) into fxn
   from public.world_status_catalog s
  where s.status_key in (select jsonb_array_elements_text(coalesce(i.use_fx->''buffs'',''[]'') || coalesce(i.use_fx->''cures'',''[]'')) from public.world_item_catalog i where i.use_fx is not null);');
    d := replace(d, 'cat jsonb; rec jsonb;', 'cat jsonb; rec jsonb; fxn jsonb;');
    if position('fxn jsonb' in d) = 0 then raise exception '7.7.7o anchor inventory declare'; end if;
    d := replace(d, 'return jsonb_build_object(''inventory'',inv,''equipment'',eq,''catalog'',cat,''recipes'',rec,',
                    'return jsonb_build_object(''inventory'',inv,''equipment'',eq,''catalog'',cat,''fx_names'',fxn,''recipes'',rec,');
    if position('''fx_names''' in d) = 0 then raise exception '7.7.7o anchor inventory return'; end if;
    execute d;
  end if;
end $p$;

update public.world_patch_notes set body = body || $N$
## 7.7.7o
- 물품을 쓸 때의 효과 문구(가방·물품 정보·퀵슬롯·토벌 물품 창)가 이제 서버의 실제 효과에서 바로 만들어집니다. 문구와 실제 효과가 어긋나던 곳이 사라지고, 음식·약의 이로운 기운은 지속 시간과 효과 수치까지 적힙니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7o' in body) = 0;

update public.world_app_meta set value = '20261104204200' where key = 'db_version';
