-- ── 도우미(7.5.0): 계열·우수품 ─────────────────────────────────────────────
-- 제작 분야 → 기술 계열(봉인 공예 분야는 키가 wardcraft)
create or replace function public.world_craft_line_of(p_field text)
returns text language plpgsql immutable set search_path = pg_catalog as $f$
begin
  return case p_field when 'smithing' then 'smithing' when 'carpentry' then 'carpentry' when 'artifice' then 'artifice'
    when 'sealing' then 'wardcraft' when 'weaving' then 'weaving' when 'leatherwork' then 'leatherwork'
    when 'alchemy' then 'alchemy' when 'cooking' then 'cooking' else 'smithing' end;
end $f$;

-- 제작법 → 기술 계열
create or replace function public.world_craft_line(p_recipe text)
returns text language plpgsql stable security definer set search_path = pg_catalog, public as $f$
#variable_conflict use_column
begin
  return (select * from (select public.world_craft_line_of(r.craft_field) from public.world_crafting_recipes r where r.recipe_id = p_recipe) yhq limit 1);
end $f$;

-- 계열 이름(화면·서버 문구)
create or replace function public.world_line_name(p_line text)
returns text language plpgsql immutable set search_path = pg_catalog as $f$
begin
  return case p_line when 'smithing' then '단조' when 'carpentry' then '목공' when 'artifice' then '법구 공예' when 'wardcraft' then '봉인 공예'
    when 'weaving' then '직조' when 'leatherwork' then '가죽 공예' when 'alchemy' then '연금' when 'cooking' then '요리'
    when 'foraging' then '채집' when 'mining' then '채광' when 'fishing' then '낚시' when 'tracking' then '탐사'
    when 'melee' then '근접' when 'ranged' then '원거리' when 'sealing' then '봉인술' when 'analysis' then '분석'
    when 'guarding' then '막기' when 'first_aid' then '응급 처치' else p_line end;
end $f$;

-- 그 계열 기본 기술(slot base)의 효과 합(상한은 부르는 쪽에서)
create or replace function public.world_line_base(p_sp jsonb, p_line text, p_key text)
returns numeric language plpgsql stable security definer set search_path = pg_catalog, public as $f$
#variable_conflict use_column
begin
  return (select * from (select coalesce(sum((sk.passive_effect ->> p_key)::numeric), 0) from public.world_skill_catalog sk
    where sk.category = p_line and sk.slot = 'base' and sk.passive_effect ? p_key
      and sk.unlock_rank <= coalesce((p_sp -> p_line ->> 'rank')::int, 1)) yhq limit 1);
end $f$;

-- 장비 → 그 장비를 맡는 기술 계열(제작법이 있으면 그 분야, 없으면 world_gear_line_map, 그래도 없으면 부위)
create table if not exists public.world_gear_line_map (
  item_id text primary key,
  line text not null check (line in ('smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking'))
);
alter table public.world_gear_line_map enable row level security;
revoke all on public.world_gear_line_map from public, anon, authenticated;

create or replace function public.world_gear_line(p_item text)
returns text language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare b text; ln text; cat text; wt text;
begin
  select coalesce(i.base_item_id, i.item_id), i.category, i.equipment_traits ->> 'weapon_type' into b, cat, wt from public.world_item_catalog i where i.item_id = p_item;
  if b is null then return 'smithing'; end if;
  select public.world_craft_line_of(r.craft_field) into ln from public.world_crafting_recipes r where r.output_item = b order by r.recipe_id limit 1;
  if ln is not null then return ln; end if;
  select m.line into ln from public.world_gear_line_map m where m.item_id = b;
  if ln is not null then return ln; end if;
  return case cat when 'weapon' then case wt when 'ranged' then 'carpentry' when 'magic' then 'artifice' else 'smithing' end
    when 'armor' then 'weaving' when 'hat' then 'weaving' when 'shoes' then 'leatherwork' when 'norigae' then 'weaving'
    when 'amulet' then 'wardcraft' when 'mask' then 'wardcraft' else 'smithing' end;
end $f$;

-- 우수품 장비 특성: 수치는 ×1.05(0이 아니면 최소 1 더), 조건·모양 값은 그대로
create or replace function public.world_item_hq_traits(p jsonb)
returns jsonb language plpgsql immutable set search_path = pg_catalog as $f$
declare o jsonb := '{}'::jsonb; k text; v jsonb; x numeric; y numeric;
begin
  if p is null or jsonb_typeof(p) <> 'object' then return coalesce(p, '{}'::jsonb); end if;
  for k, v in select key, value from jsonb_each(p) loop
    if jsonb_typeof(v) = 'number' and k not in ('req_rank', 'w', 'd', 'ww', 'wh', 'top', 'grade', 'z', 't') and (v #>> '{}')::numeric <> 0 then
      x := (v #>> '{}')::numeric;
      if x = trunc(x) then
        y := case when x > 0 then greatest(x + 1, round(x * 1.05)) else least(x - 1, round(x * 1.05)) end;
      else y := round(x * 1.05, 2); end if;
      o := o || jsonb_build_object(k, y);
    else o := o || jsonb_build_object(k, v); end if;
  end loop;
  return o;
end $f$;

-- 물품 정보 문구: 우수품이 무엇이 나은지
create or replace function public.world_item_hq_note(p_base text, p_cat text)
returns text language plpgsql stable security definer set search_path = pg_catalog, public as $f$
declare fld text;
begin
  if p_cat in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then return '우수품: 장비 수치 +5% · 최대 내구도 +10%.'; end if;
  if p_base = 'repair_kit' then return '우수품: 내구도를 60% 되살립니다.'; end if;
  if p_base = 'fish_oil_lamp' then return '우수품: 등잔빛이 20% 더 오래 갑니다.'; end if;
  if p_base = 'revival_charm' then return '우수품: 일어날 때 체력 58.'; end if;
  select r.craft_field into fld from public.world_crafting_recipes r where r.output_item = p_base order by r.recipe_id limit 1;
  if fld = 'cooking' then return '우수품: 회복 +15% · 붙는 기운 지속 +20%.'; end if;
  return '우수품: 회복 +15%.';
end $f$;

-- 기본 물품을 고치면 우수품 행도 따라 고친다
create or replace function public.world_item_hq_sync()
returns trigger language plpgsql security definer set search_path = pg_catalog, public as $f$
begin
  if new.base_item_id is not null or coalesce(current_setting('yh.hq_sync', true), '') = 'off' then return new; end if;
  update public.world_item_catalog h set
    item_name = new.item_name || ' (우수)', category = new.category, tier = new.tier,
    description = new.description || ' ' || public.world_item_hq_note(new.item_id, new.category),
    stackable = new.stackable, stack_size = new.stack_size, tradeable = new.tradeable,
    required_stats = new.required_stats, required_job = new.required_job, required_faction = new.required_faction,
    minimum_level = new.minimum_level, crafting_specialization = new.crafting_specialization,
    reference_price = ceil(coalesce(new.reference_price, 0) * 1.3),
    equipment_traits = case when new.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
      then public.world_item_hq_traits(new.equipment_traits) else new.equipment_traits end
  where h.base_item_id = new.item_id
    and (h.item_name, h.category, h.tier, h.description, h.stack_size, h.tradeable, h.minimum_level, h.reference_price, h.equipment_traits, h.required_stats)
        is distinct from (new.item_name || ' (우수)', new.category, new.tier, new.description || ' ' || public.world_item_hq_note(new.item_id, new.category), new.stack_size, new.tradeable,
          new.minimum_level, ceil(coalesce(new.reference_price, 0) * 1.3)::bigint,
          case when new.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(new.equipment_traits) else new.equipment_traits end,
          new.required_stats);
  return new;
end $f$;

-- 기술 이름(결과 문구용) — 제작 등 함수 주인 역할은 기술표를 직접 읽을 권한이 없다
create or replace function public.world_skill_name(p_id text)
returns text language plpgsql stable security definer set search_path = pg_catalog, public as $f$
#variable_conflict use_column
begin
  return (select * from (select sk.skill_name from public.world_skill_catalog sk where sk.skill_id = p_id) yhq limit 1);
end $f$;

-- 우수품 id → 기본 id
create or replace function public.world_item_base(p_item text)
returns text language plpgsql immutable set search_path = pg_catalog as $f$
begin
  return case when p_item like '%\_hq' then left(p_item, length(p_item) - 3) else p_item end;
end $f$;
