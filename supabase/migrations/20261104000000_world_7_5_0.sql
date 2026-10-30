-- 7.5.0 생산 기술 개편(생성기 supabase/gen750/gen.py — 이 파일을 손으로 고치지 말고 생성기를 고친다)
-- 제작 여덟 계열(단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리), 채집 셋(채집·채광·낚시), 우수품, 기본 생산량,
-- 분해 경험·경험만 분해, 생활 전문화 정리, 조사 36 「영초 감별」, 기술 칭호 32, 조합 기술, 택일 무료 다시 고르기, 쌓은 경험 이주.
lock table public.world_characters in access exclusive mode;
set local check_function_bodies = off;

create or replace function pg_temp.yh_own(p_fn text) returns void language plpgsql as $f$
declare o text;
begin
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
end $f$;

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := replace(pg_get_functiondef(p_fn::regprocedure), E'
', E'
'); -- 줄 끝이 CRLF인 함수도 있다
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  perform pg_temp.yh_own(p_fn);
  execute replace(d, p_old, p_new);
end $f$;


-- ── 표 ──────────────────────────────────────────────────────────────────
alter table public.world_item_catalog add column if not exists base_item_id text;
alter table public.world_item_catalog add column if not exists quality_grade smallint not null default 0;
create index if not exists world_item_catalog_base_idx on public.world_item_catalog(base_item_id) where base_item_id is not null;
alter table public.world_skill_picks add column if not exists free_repick text[] not null default '{}';
alter table public.world_characters alter column crafting_profession set default 'smithing';

select pg_temp.yh_own('public.world_craft_item(text)');
select pg_temp.yh_own('public.world_dismantle_need(integer)');
select pg_temp.yh_own('public.world_dismantle_yield(text)');
select pg_temp.yh_own('public.world_dismantle_item(text)');
select pg_temp.yh_own('public.world_field_gather(uuid)');
select pg_temp.yh_own('public.world_fish()');
select pg_temp.yh_own('public.world_skill_effect(text)');
select pg_temp.yh_own('public.world_skill_sync()');
select pg_temp.yh_own('public.world_skill_choose(text,integer,text)');
select pg_temp.yh_own('public.world_skill_snapshot()');
select pg_temp.yh_own('public.world_idle_skill_for(uuid,text)');
select pg_temp.yh_own('public.world_set_life_profession_v2(text,text)');
select pg_temp.yh_own('public.world_craft_tool_bonus(uuid,text)');
select pg_temp.yh_own('public.world_tool_covers(text,text)');
select pg_temp.yh_own('public.world_item_max_durability(text)');

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

-- ── 기술(7.5.0): 계열 열넷 → 제작 여덟·채집 셋·전투 여섯·탐사 ──
-- 기본 기술 효과 합: 제작 품질은 world_craft_item이, 채집 계열 채집량·희귀품은 world_field_gather·world_fish가 그 계열에서만 직접 더한다.
create or replace function public.world_skill_effect(p_effect_key text)
 returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid; v numeric;
begin
  if p_effect_key not in ('gather_qty_pct', 'rare_loot_pct', 'clue_bonus_pct', 'healing_pct', 'incoming_damage_pct', 'mental_loss_pct', 'erosion_pct', 'travel_time_pct', 'combat_damage_pct', 'encounter_pct') then return 0; end if;
  uid := public.fn_owner_auth_uid(); if uid is null then return 0; end if;
  select coalesce(sum((sk.passive_effect ->> p_effect_key)::numeric), 0) into v
    from public.world_skill_catalog sk join public.world_characters c on c.owner_id = uid left join public.world_skill_picks pk on pk.owner_id = uid
   where sk.passive_effect ? p_effect_key
     and not (p_effect_key in ('gather_qty_pct', 'rare_loot_pct') and sk.category in ('foraging', 'mining', 'fishing'))
     and sk.category not in ('smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking')
     and public.world_skill_has(c.skill_progress, coalesce(pk.picks, '{}'::jsonb), sk.category, sk.unlock_rank, sk.slot, sk.requires);
  return case p_effect_key
    when 'gather_qty_pct' then least(v, 40) when 'rare_loot_pct' then least(v, 22) when 'clue_bonus_pct' then least(v, 28)
    when 'healing_pct' then least(v, 45) when 'combat_damage_pct' then least(v, 15)
    when 'incoming_damage_pct' then greatest(v, -28) when 'mental_loss_pct' then greatest(v, -32)
    when 'erosion_pct' then greatest(v, -28) when 'travel_time_pct' then greatest(v, -20) when 'encounter_pct' then greatest(v, -15) else v end;
end $function$;

-- 숙련 4갈래 = 그 갈래 기술 가운데 가장 높은 단계(제작 = 제작 여덟 계열, 채집 = 채집·채광·낚시)
create or replace function public.world_skill_sync()
 returns trigger language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare k text; v jsonb; outp jsonb := '{}'::jsonb; r int; cb int := 1; ga int := 1; cr int := 1; iv int := 1;
begin
  if tg_op = 'UPDATE' and coalesce(current_setting('yh.rank_sync', true), '') <> 'all'
     and new.skill_progress is not distinct from old.skill_progress
     and new.combat_rank is not distinct from old.combat_rank and new.gathering_rank is not distinct from old.gathering_rank
     and new.crafting_rank is not distinct from old.crafting_rank and new.investigation_rank is not distinct from old.investigation_rank then
    return new;
  end if;
  for k, v in select e.key, e.value from jsonb_each(coalesce(new.skill_progress, '{}'::jsonb)) e loop
    if jsonb_typeof(v) = 'object' then
      r := public.world_skill_line_rank(coalesce((v ->> 'xp')::numeric, 0)::int);
      outp := outp || jsonb_build_object(k, v || jsonb_build_object('rank', r));
    else outp := outp || jsonb_build_object(k, v); r := 1; end if;
    if k in ('melee', 'ranged', 'sealing', 'analysis', 'guarding', 'first_aid') then cb := greatest(cb, r);
    elsif k in ('foraging', 'mining', 'fishing') then ga := greatest(ga, r);
    elsif k in ('smithing', 'carpentry', 'artifice', 'wardcraft', 'weaving', 'leatherwork', 'alchemy', 'cooking') then cr := greatest(cr, r);
    elsif k = 'tracking' then iv := greatest(iv, r); end if;
  end loop;
  new.skill_progress := outp;
  new.combat_rank := cb; new.gathering_rank := ga; new.crafting_rank := cr; new.investigation_rank := iv;
  return new;
end $function$;

-- 택일 고르기: 7.5.0에서 효과가 바뀐 칸은 한 번 무료로 다시 고른다(world_skill_picks.free_repick)
create or replace function public.world_skill_choose(p_line text, p_tier integer, p_pick text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; cur text; fee int := 0; nm text; free boolean := false; key text := p_line || ':' || p_tier;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if p_tier not in (13, 24, 30, 43) or p_pick not in ('a', 'b') then raise exception '고를 수 없는 기술입니다.'; end if;
  select skill_name into nm from public.world_skill_catalog where category = p_line and unlock_rank = p_tier and slot = p_pick;
  if nm is null then raise exception '고를 수 없는 기술입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce((c.skill_progress -> p_line ->> 'rank')::int, 1) < p_tier then raise exception '%단계에 닿아야 고를 수 있습니다.', p_tier; end if;
  select picks ->> key, key = any (free_repick) into cur, free from public.world_skill_picks where owner_id = uid for update;
  if cur = p_pick then raise exception '이미 고른 기술입니다.'; end if;
  if cur is not null and not coalesce(free, false) then
    fee := case p_tier when 13 then 1000 when 24 then 2000 when 30 then 3000 else 5000 end;
    if c.gil < fee then raise exception '기술을 바꾸려면 %전이 필요합니다.', fee; end if;
  end if;
  insert into public.world_skill_picks(owner_id, picks) values (uid, jsonb_build_object(key, p_pick))
  on conflict (owner_id) do update set picks = public.world_skill_picks.picks || excluded.picks,
    free_repick = case when public.world_skill_picks.picks ? key then array_remove(public.world_skill_picks.free_repick, key) else public.world_skill_picks.free_repick end, updated_at = now();
  if fee > 0 then update public.world_characters set gil = gil - fee, updated_at = now() where owner_id = uid; end if;
  return jsonb_build_object('ok', true, 'fee', fee, 'free', cur is not null and coalesce(free, false),
    'content', '「' || nm || '」을(를) 익혔습니다.' || case when fee > 0 then ' 바꾸는 값 ' || fee || '전을 냈습니다.' when cur is not null and coalesce(free, false) then ' 이번 한 번은 무료로 바꿨습니다.' else '' end);
end $function$;

create or replace function public.world_skill_snapshot()
 returns jsonb language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb; pk jsonb; fr text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
  select picks, free_repick into pk, fr from public.world_skill_picks where owner_id = uid;
  pk := coalesce(pk, '{}'::jsonb); fr := coalesce(fr, '{}');
  select jsonb_agg(jsonb_build_object('skill_id', s.skill_id, 'skill_name', s.skill_name, 'category', s.category, 'description', s.description,
      'rank', coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1), 'xp', coalesce((c.skill_progress -> s.category ->> 'xp')::int, 0),
      'unlock_rank', s.unlock_rank, 'active_skill', s.active_skill, 'passive_effect', s.passive_effect, 'slot', s.slot, 'requires', s.requires,
      'reached', case when s.category = 'combo' then public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires)
                      else coalesce((c.skill_progress -> s.category ->> 'rank')::int, 1) >= s.unlock_rank end,
      'picked', case when s.slot in ('a', 'b') then coalesce(pk ->> (s.category || ':' || s.unlock_rank), '') = s.slot end,
      'free_repick', case when s.slot in ('a', 'b') then (s.category || ':' || s.unlock_rank) = any (fr) end,
      'req_ranks', case when s.category = 'combo' then (select jsonb_object_agg(r.k, coalesce((c.skill_progress -> r.k ->> 'rank')::int, 1)) from jsonb_each(s.requires) r(k, v)) end,
      'unlocked', public.world_skill_has(c.skill_progress, pk, s.category, s.unlock_rank, s.slot, s.requires))
    order by s.category, s.unlock_rank, case s.slot when 'base' then 0 when 'extra' then 1 when 'a' then 2 when 'b' then 3 else 4 end) into out
  from public.world_skill_catalog s;
  return coalesce(out, '[]'::jsonb);
end $function$;

-- 자율 정비 경험은 고른 제작 분야의 계열로
create or replace function public.world_idle_skill_for(p_owner uuid, p_activity text)
 returns text language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (select case p_activity
    when 'training' then coalesce((
      select case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'ranged' when 'magic' then 'sealing' else 'melee' end
        from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id
       where e.owner_id = p_owner and e.slot = 'weapon' limit 1), 'melee')
    when 'research' then 'tracking'
    when 'maintenance' then coalesce((select public.world_craft_line_of(c.crafting_profession) from public.world_characters c where c.owner_id = p_owner), 'smithing')
    else null end) yhq limit 1);
end $function$;

-- 생활 전문화: 제작 분야 여덟 가운데 하나(종합 제작 없음), 채집 분야 셋
create or replace function public.world_set_life_profession_v2(p_gathering text, p_crafting text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_gathering not in ('fieldwork', 'mining', 'fishing') then raise exception '없는 채집 분야입니다.'; end if;
  if p_crafting not in ('smithing', 'carpentry', 'alchemy', 'sealing', 'weaving', 'leatherwork', 'artifice', 'cooking') then raise exception '없는 제작 분야입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if c.gathering_profession = p_gathering and c.crafting_profession = p_crafting then raise exception '이미 그 분야입니다.'; end if;
  if c.life_changed_at is not null and c.life_changed_at > now() - interval '72 hours' then
    raise exception '%', format('전문화는 %s 이후에 다시 바꿀 수 있습니다.', to_char((c.life_changed_at + interval '72 hours') at time zone 'Asia/Seoul', 'MM월 DD일 HH24:MI'));
  end if;
  update public.world_characters set gathering_profession = p_gathering, crafting_profession = p_crafting, life_changed_at = now(), updated_at = now() where owner_id = uid;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'mission', '생활 전문 분야 변경', jsonb_build_object('v2', true, 'gathering_profession', p_gathering, 'crafting_profession', p_crafting));
  return jsonb_build_object('ok', true, 'content', '전문화를 정했습니다. 3일 뒤에 다시 바꿀 수 있습니다.');
end $function$;

-- 제작 공구: 그 공구가 맡는 분야 계열 가운데 가장 높은 단계로 조건을 본다
create or replace function public.world_craft_tool_bonus(p_uid uuid, p_field text)
 returns integer language plpgsql stable security definer set search_path to ''
as $function$
#variable_conflict use_column
begin
  return (select * from (
  select coalesce(max((i.equipment_traits ->> 'craft_quality')::int), 0)
    from public.world_characters c join public.world_item_catalog i
      on i.equipment_traits ->> 'life_slot' = 'craft' and coalesce((c.inventory ->> i.item_id)::int, 0) > 0
     and coalesce(i.equipment_traits -> 'craft_fields', '[]'::jsonb) ? p_field
     and coalesce(c.level, 1) >= coalesce(i.minimum_level, 1)
     and (case when coalesce(i.equipment_traits ->> 'req_line', 'crafting_rank') = 'crafting_rank'
            then (select coalesce(max(coalesce((c.skill_progress -> public.world_craft_line_of(f) ->> 'rank')::int, 1)), 1) from jsonb_array_elements_text(coalesce(i.equipment_traits -> 'craft_fields', '[]'::jsonb)) f)
            else coalesce((to_jsonb(c) ->> (i.equipment_traits ->> 'req_line'))::int, 1) end) >= coalesce((i.equipment_traits ->> 'req_rank')::int, 0)
   where c.owner_id = p_uid) yhq limit 1);
end $function$;

-- 상위 도구가 하위 도구를 덮는다(우수품 도구도 기본 도구의 줄로)
create or replace function public.world_tool_covers(p_have text, p_need text)
 returns boolean language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select p_have = p_need or public.world_item_base(p_have) = p_need or exists (
    select 1 from public.world_tool_lines a join public.world_tool_lines b on b.line = a.line
      join public.world_item_catalog ia on ia.item_id = a.item_id join public.world_item_catalog ib on ib.item_id = b.item_id
     where a.item_id = public.world_item_base(p_have) and b.item_id = p_need and ia.tier >= ib.tier)
$function$;

-- 최대 내구도: 우수품은 기본 ×1.1
create or replace function public.world_item_max_durability(p_item text)
 returns integer language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
#variable_conflict use_column
begin
  return (select * from (
  select case when category in ('weapon', 'armor') then 50 + coalesce(tier, 1) * 30
              when category in ('tool', 'hat', 'shoes') then 40 + coalesce(tier, 1) * 20 else null end
         * case when base_item_id is not null then 1.1 else 1 end
  from public.world_item_catalog where item_id = p_item
) yhq limit 1)::int;
end $function$;

-- ── 제작(7.5.0): 계열마다 기술·품질, 우수품, 품질은 개수를 바꾸지 않음 ─────────
create or replace function public.world_craft_item(p_recipe_id text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_crafting_recipes%rowtype; inv jsonb; tool_tier int := 0;
  k text; need int; have int; out_qty int; quality int; result_text text; loc_bonus int := 0; st jsonb; take int; from_st jsonb := '{}'::jsonb; room int;
  sk text[]; line text; lname text; ln_rank int; lb numeric; rq int; free_mat boolean := false; notes text[] := '{}'; rf text;
  ocat text; is_furn boolean; hq_ok boolean; is_hq boolean := false; hq_th int := 85; out_item text; left_n int; part text; saved boolean;
  cs_pct numeric; cx_pct numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
  if c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태입니다. 다른 조사원의 구조를 받아야 행동할 수 있습니다.'; end if;
  select * into r from public.world_crafting_recipes where recipe_id = p_recipe_id;
  if not found then raise exception '존재하지 않는 제작법입니다.'; end if;
  if c.level < r.minimum_level then raise exception '이 제작법은 레벨 %부터 해금됩니다.', r.minimum_level; end if;
  if r.required_skill is not null and coalesce((c.skill_progress -> r.required_skill ->> 'rank')::int, 1) < r.required_skill_rank then
    raise exception '% 기술 %단계가 필요합니다(지금 %단계). 캐릭터 › 기술에서 확인하세요.', public.world_line_name(r.required_skill), r.required_skill_rank, coalesce((c.skill_progress -> r.required_skill ->> 'rank')::int, 1);
  end if;
  if r.required_job is not null and c.job_key <> r.required_job and c.job_key <> 'analyst' then
    raise exception '필요 직업: %', case r.required_job when 'exorcist' then '퇴마관' when 'scout' then '현장 조사원' when 'medic' then '의무관' when 'sealmaster' then '봉인술사' when 'analyst' then '백공 기술관' when 'artificer' then '호위 무사' else r.required_job end;
  end if;
  if r.required_location is not null and (coalesce(c.location, '') = r.required_location or (r.required_location = '야행국 본부 정청' and c.location in ('본부 로비', '야행국 본부 · 정청'))
     or (r.required_location = '연무장·팔괘진' and c.location in ('훈련실', '야행국 본부 · 연무장')) or (r.required_location = '장서각 지하서고' and c.location in ('기록 보관실', '야행국 본부 · 장서각'))) then loc_bonus := 12; end if;
  sk := public.world_skill_procs(uid);
  line := public.world_craft_line_of(r.craft_field); lname := public.world_line_name(line);
  ln_rank := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  select i.category into ocat from public.world_item_catalog i where i.item_id = r.output_item;
  is_furn := ocat = 'furniture';
  hq_ok := exists (select 1 from public.world_item_catalog h where h.item_id = r.output_item || '_hq' and h.base_item_id = r.output_item);
  inv := coalesce(c.inventory, '{}'::jsonb);
  if exists (select 1 from public.world_current_shop(uid)) and not public.world_banyo_here(uid) then select items into st from public.world_storage where owner_id = uid for update; end if;
  st := coalesce(st, '{}'::jsonb);
  if r.required_tool is not null then
    select max(coalesce(i.tier, 0)) into tool_tier from public.world_item_catalog i where public.world_tool_covers(i.item_id, r.required_tool)
      and (coalesce((c.inventory ->> i.item_id)::numeric, 0) > 0 or exists (select 1 from public.world_character_equipment e where e.owner_id = uid and e.item_id = i.item_id));
    if tool_tier is null then raise exception '필요 도구가 가방에 있어야 합니다: %', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = r.required_tool), r.required_tool); end if;
    if coalesce(tool_tier, 0) < r.required_tool_tier then raise exception '도구 단계가 부족합니다. 필요 단계: %', r.required_tool_tier; end if;
  end if;
  -- 재료: 기본 물품 + 우수품(가방·창고)을 함께 센다
  for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
    have := coalesce((inv ->> k)::int, 0) + coalesce((st ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0) + coalesce((st ->> (k || '_hq'))::int, 0);
    if have < need then raise exception '재료 부족: % (필요 %, 보유 %)', coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = k), k), need, have; end if;
  end loop;
  -- 숙달(50단계): 10%는 재료를 하나도 쓰지 않는다
  free_mat := (line || '_m50') = any (sk) and random() < 0.10;
  if free_mat then notes := notes || ('「' || public.world_skill_name(line || '_m50') || '」 재료를 하나도 쓰지 않았다');
  else
    for k, need in select key, value::text::int from jsonb_each(r.ingredients) loop
      -- 약재 바탕 아끼기(연금 24b): 약제 바탕·농축 약초액은 30% 쓰지 않는다
      if line = 'alchemy' and 'alchemy_c24b' = any (sk) and k in ('medicine_base', 'herbal_extract') and random() < 0.30 then
        notes := notes || ('「약재 바탕 아끼기」 ' || coalesce((select item_name from public.world_item_catalog where item_id = k), '재료') || '을(를) 아꼈다'); continue;
      end if;
      left_n := need;
      -- 기본 먼저(가방 → 창고), 모자라면 우수품(가방 → 창고)
      foreach part in array array[k, k || '_hq'] loop
        exit when left_n <= 0;
        take := least(left_n, greatest(0, coalesce((inv ->> part)::int, 0)));
        if take > 0 then inv := jsonb_set(inv, array[part], to_jsonb(coalesce((inv ->> part)::int, 0) - take), true); left_n := left_n - take; end if;
        take := least(left_n, greatest(0, coalesce((st ->> part)::int, 0)));
        if take > 0 then st := jsonb_set(st, array[part], to_jsonb(coalesce((st ->> part)::int, 0) - take)); from_st := from_st || jsonb_build_object(part, coalesce((from_st ->> part)::int, 0) + take); left_n := left_n - take; end if;
      end loop;
    end loop;
    inv := (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(inv) where not (jsonb_typeof(value) = 'number' and value::text::numeric <= 0));
  end if;
  if from_st <> '{}'::jsonb then
    update public.world_storage set items = (select coalesce(jsonb_object_agg(key, value), '{}'::jsonb) from jsonb_each(st) where jsonb_typeof(value) = 'number' and value::text::int > 0), updated_at = now() where owner_id = uid;
  end if;
  -- 품질 = 10 + 계열 단계 + 계열 기본 기술(≤40) + 분야 일치 12 + 백공 15 + 장비·칭호·음식·상태 + 제작 공구 + 장소 12 − 8×난이도 + 0~19
  rq := floor(random() * 20)::int;
  if (line || '_c24a') = any (sk) then rq := greatest(rq, floor(random() * 20)::int); end if;
  lb := least(40, public.world_line_base(c.skill_progress, line, 'craft_quality'));
  quality := least(100, greatest(0, 10 + ln_rank + lb::int
    + case when c.crafting_profession = r.craft_field then 12 else 0 end
    + case when c.job_key = 'analyst' then 15 else 0 end
    + case when r.required_skill is not null and exists (select 1 from public.world_character_equipment e join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and i.crafting_specialization = r.required_skill) then 10 else 0 end
    + public.world_craft_tool_bonus(uid, r.craft_field)
    + (public.world_status_effect_total('craft_quality') + public.world_title_bonus('craft_quality') + public.world_title_bonus('cq_' || line))::int
    + public.world_status_effect_total('action_quality_pct')::int
    + loc_bonus - r.recipe_difficulty * 8 + rq));
  -- 우수품: 품질 85(30단계 추가 기술이 있으면 80) 이상
  if (line || '_x30') = any (sk) then hq_th := 80; end if;
  is_hq := hq_ok and quality >= hq_th;
  out_item := case when is_hq then r.output_item || '_hq' else r.output_item end;
  room := public.world_bag_room(inv, out_item, public.world_bag_limit(uid));
  if room < r.output_qty then raise exception '가방에 완성품을 넣을 자리가 없습니다. 가방을 한 칸 비운 뒤 다시 제작하세요.'; end if;
  out_qty := r.output_qty;
  -- 개수 덤(가구는 언제나 하나)
  if not is_furn then
    if line = 'carpentry' and 'carpentry_c24b' = any (sk) and r.output_item in ('ammo_arrow', 'ammo_bolt', 'ammo_dart') then
      out_qty := ceil(out_qty * 1.25)::int; notes := notes || '「살대 다듬기」 25% 더 만들었다'::text; end if;
    if line = 'wardcraft' and 'wardcraft_c24b' = any (sk) and ocat = 'consumable' then
      out_qty := ceil(out_qty * 1.25)::int; notes := notes || '「부적 묶음」 25% 더 만들었다'::text; end if;
    if line = 'cooking' and 'cooking_c24b' = any (sk) and r.output_item = 'fish_fillet' and random() < 0.30 then
      out_qty := out_qty + 1; notes := notes || '「생선 손질 솜씨」 하나 더'::text; end if;
    if line in ('weaving', 'leatherwork', 'wardcraft', 'alchemy') and (line || '_c43a') = any (sk) and random() < 0.15 then
      out_qty := out_qty + 1; notes := notes || ('「' || public.world_skill_name(line || '_c43a') || '」 하나 더'); end if;
    if line = 'cooking' and 'cooking_c43a' = any (sk) and ocat = 'consumable' and random() < 0.15 then
      out_qty := out_qty + 1; notes := notes || '「넉넉한 솥」 한 그릇 더'::text; end if;
    cx_pct := public.world_title_bonus('cx_' || line) + public.world_title_bonus('cx_all');
    if cx_pct > 0 and random() * 100 < cx_pct then out_qty := out_qty + 1; notes := notes || '칭호 덕에 하나 더'::text; end if;
  end if;
  out_qty := greatest(r.output_qty, least(room, out_qty));
  inv := jsonb_set(inv, array[out_item], to_jsonb(coalesce((inv ->> out_item)::int, 0) + out_qty), true);
  -- 재료 돌려받기(13단계 추가 기술 10% · 칭호 cs_), 금단(연금 43b 30%, 가장 비싼 재료), 살림 목수(목공 43b, 가구 25%)
  if not free_mat and r.ingredients <> '{}'::jsonb then
    saved := false;
    cs_pct := public.world_title_bonus('cs_' || line) + public.world_title_bonus('cs_all');
    if ((line || '_x13') = any (sk) and random() < 0.10) or (cs_pct > 0 and random() * 100 < cs_pct)
       or (is_furn and line = 'carpentry' and 'carpentry_c43b' = any (sk) and random() < 0.25) then
      select key into rf from jsonb_each(r.ingredients) order by random() limit 1;
      if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true); saved := true;
        notes := notes || ('재료를 아껴 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
    end if;
    if line = 'alchemy' and 'alchemy_c43b' = any (sk) and random() < 0.30 then
      rf := null;
      select j.key into rf from jsonb_each(r.ingredients) j left join public.world_item_catalog ic on ic.item_id = j.key order by coalesce(ic.reference_price, 0) desc limit 1;
      if rf is not null then inv := jsonb_set(inv, array[rf], to_jsonb(coalesce((inv ->> rf)::int, 0) + 1), true);
        notes := notes || ('「금단」 ' || coalesce((select item_name from public.world_item_catalog where item_id = rf), '재료') || ' 하나를 돌려받았다'); end if;
    end if;
  end if;
  update public.world_characters set inventory = inv, crafting_successes = crafting_successes + 1, crafting_quality = crafting_quality + quality, updated_at = now() where owner_id = uid;
  result_text := '제작 성공: ' || r.recipe_name || ' → ' || coalesce((select ic.item_name from public.world_item_catalog ic where ic.item_id = out_item), out_item) || ' ×' || out_qty || ' · 품질 ' || quality
    || case when loc_bonus > 0 then ' · 제작 장소 가산 +' || loc_bonus else '' end || case when is_hq then ' · 우수품!' else '' end
    || case when from_st <> '{}'::jsonb then ' · 창고 재료 사용' else '' end
    || case when cardinality(notes) > 0 then ' · ' || array_to_string(notes, ' · ') else '' end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'craft', result_text, jsonb_build_object('recipe', r.recipe_id, 'output', r.output_item, 'item', out_item, 'hq', is_hq, 'qty', out_qty,
    'quality', quality, 'difficulty', r.recipe_difficulty, 'line', line));
  return jsonb_build_object('content', result_text, 'inventory', inv, 'recipe', r.recipe_id, 'output', out_item, 'base', r.output_item, 'hq', is_hq, 'hq_at', case when hq_ok then hq_th end,
    'qty', out_qty, 'quality', quality, 'location_bonus', loc_bonus, 'from_storage', from_st, 'line', line, 'line_name', lname);
end $function$;

-- ── 분해(7.5.0): 언제나 할 수 있고 그 장비 계열 경험 12, 계열 단계가 모자라면 재료 없이 경험만 ──
create or replace function public.world_dismantle_need(p_tier integer)
returns integer language plpgsql immutable set search_path = pg_catalog as $f$
begin
  return case coalesce(p_tier, 1) when 1 then 1 when 2 then 3 when 3 then 6 when 4 then 9 when 5 then 12 else 15 end;
end $f$;

create or replace function public.world_dismantle_yield(p_item text)
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare it public.world_item_catalog%rowtype; ing jsonb; out jsonb := '{}'::jsonb; k text; v int; b text;
begin
  select * into it from public.world_item_catalog where item_id = p_item;
  if not found then return '{}'::jsonb; end if;
  b := coalesce(it.base_item_id, it.item_id); -- 우수품은 기본 물품의 제작법으로(더 주지 않음)
  select r.ingredients into ing from public.world_crafting_recipes r where r.output_item = b order by r.recipe_id limit 1;
  if ing is null then
    select r.ingredients into ing from public.world_crafting_recipes r join public.world_item_catalog o on o.item_id = r.output_item
     where o.category = it.category and o.tier between greatest(1, it.tier - 1) and it.tier and r.ingredients <> '{}'::jsonb
     order by o.tier desc, r.recipe_id limit 1;
  end if;
  if ing is null or ing = '{}'::jsonb then return jsonb_build_object('spirit_dust', greatest(1, coalesce(it.tier, 1))); end if;
  for k, v in select key, (value)::text::int from jsonb_each(ing) loop
    if floor(v * 0.5) >= 1 then out := out || jsonb_build_object(k, floor(v * 0.5)::int); end if;
  end loop;
  if out = '{}'::jsonb then
    select key into k from jsonb_each(ing) order by (value)::text::int desc, key limit 1;
    out := jsonb_build_object(k, 1);
  end if;
  return out;
end $function$;

create or replace function public.world_dismantle_item(p_item_id text)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; have int; y jsonb := '{}'::jsonb; inv jsonb;
  k text; v int; need int; rk int; gain int; sxp int; nm text := ''; line text; lname text; no_y boolean; sk text[]; extra_k text; msg text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if; perform set_config('yh.wear_leaves', 'on', true);
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 분해할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 분해할 수 없습니다.'; end if;
  select * into it from public.world_item_catalog where item_id = p_item_id;
  if not found or it.category not in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then raise exception '분해할 수 있는 장비가 아닙니다.'; end if;
  inv := coalesce(c.inventory, '{}'::jsonb); have := coalesce((inv ->> p_item_id)::int, 0);
  if have < 1 then raise exception '가방에 그 장비가 없습니다.'; end if;
  perform public.world_item_give_guard(uid, p_item_id, have, 1);
  line := public.world_gear_line(p_item_id); lname := public.world_line_name(line);
  need := public.world_dismantle_need(it.tier);
  rk := coalesce((c.skill_progress -> line ->> 'rank')::int, 1);
  no_y := rk < need;
  if not no_y then
    y := public.world_dismantle_yield(p_item_id);
    -- 법기 해체·올 풀기·짐틀 장인·부적 해체(43b): 그 계열 장비면 돌려받는 재료 하나를 하나 더
    sk := public.world_skill_procs(uid);
    if line in ('artifice', 'weaving', 'leatherwork', 'wardcraft') and (line || '_c43b') = any (sk) and y <> '{}'::jsonb then
      select key into extra_k from jsonb_each(y) order by random() limit 1;
      y := jsonb_set(y, array[extra_k], to_jsonb((y ->> extra_k)::int + 1));
    end if;
  end if;
  inv := case when have - 1 <= 0 then inv - p_item_id else jsonb_set(inv, array[p_item_id], to_jsonb(have - 1)) end;
  for k, v in select key, (value)::text::int from jsonb_each(y) loop
    inv := jsonb_set(inv, array[k], to_jsonb(coalesce((inv ->> k)::int, 0) + v), true);
    nm := nm || case when nm = '' then '' else ', ' end || coalesce((select item_name from public.world_item_catalog where item_id = k), k) || ' ×' || v;
  end loop;
  gain := 6 * coalesce(it.tier, 1);
  sxp := round(12 * greatest(0.5, 1 + public.world_status_self(uid, 'training_xp_pct') / 100.0))::int;
  -- 기술 경험은 같은 UPDATE에서(단계는 trg_world_skill_sync가 다시 매김)
  update public.world_characters set inventory = inv, crafting_xp = coalesce(crafting_xp, 0) + gain,
    skill_progress = public.world_skill_add(skill_progress, line, sxp), updated_at = now()
   where owner_id = uid;
  msg := case when no_y then it.item_name || '을(를) 분해했습니다 · 재료는 돌려받지 못했습니다(' || lname || ' ' || need || '단계부터) · ' || lname || ' 경험 +' || sxp
    else it.item_name || '을(를) 분해해 ' || nm || '을(를) 얻었습니다 · ' || lname || ' 경험 +' || sxp end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'dismantle', case when no_y then it.item_name || ' 분해(재료 없음)' else it.item_name || ' 분해 → ' || nm end,
    jsonb_build_object('item', p_item_id, 'yield', y, 'xp', gain, 'line', line, 'need', need, 'rank', rk, 'no_yield', no_y, 'skill_xp', sxp));
  return jsonb_build_object('ok', true, 'content', msg, 'yield', y, 'no_yield', no_y, 'need', need, 'rank', rk, 'line', line, 'line_name', lname, 'skill_xp', sxp);
end $function$;

-- 분해 창·물품 정보 창이 열릴 때만 부른다: 가방의 장비마다 맡는 계열·재료가 나오는 단계·지금 단계
create or replace function public.world_dismantle_info()
 returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; out jsonb := '{}'::jsonb; r record; ln text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then return out; end if;
  for r in select i.item_id, i.tier from jsonb_each_text(coalesce(c.inventory, '{}'::jsonb)) e join public.world_item_catalog i on i.item_id = e.key
            where e.value::numeric > 0 and i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') loop
    ln := public.world_gear_line(r.item_id);
    out := out || jsonb_build_object(r.item_id, jsonb_build_object('line', ln, 'line_name', public.world_line_name(ln),
      'need', public.world_dismantle_need(r.tier), 'rank', coalesce((c.skill_progress -> ln ->> 'rank')::int, 1),
      'yield', case when coalesce((c.skill_progress -> ln ->> 'rank')::int, 1) >= public.world_dismantle_need(r.tier) then public.world_dismantle_yield(r.item_id) else '{}'::jsonb end));
  end loop;
  return out;
end $function$;
revoke all on function public.world_dismantle_info() from public, anon;
grant execute on function public.world_dismantle_info() to authenticated;

-- ── 채집(7.5.0): 채집(약초·목재·보급품·물가·영기)·채광(광맥·유물) 두 계열, 기본 기술은 그 계열 채집터에만 ──
create or replace function public.world_field_gather(p_spot_id uuid)
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_gathering_spots%rowtype;
  d public.world_gathering_discoveries%rowtype; it text; qty int; tool_bonus int := 0; inv jsonb; left_st int; prof_match boolean; nm text;
  sk text[]; line text; rg public.world_map_regions%rowtype; mult int := 1; mnote text; notes text[] := '{}'; extra jsonb := '{}'::jsonb;
  wait_s int := 300; no_wear boolean := false; free_st boolean := false; tool_ln text;
  x text; k text; v int; tool_id text; free_day int := 0; gcnt int := 0; q_pct numeric; r_pct numeric;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 채집할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 채집할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 채집할 수 없습니다.'; end if;
  select * into s from public.world_gathering_spots where spot_id = p_spot_id and active and (node_id = c.current_exploration_node_id or (node_id = (select n0.node_id from public.world_exploration_nodes n0 join public.world_map_regions r0 on r0.region_id = n0.region_id where r0.region_name = c.location and n0.hierarchy_level = 1 limit 1) and not exists (select 1 from public.world_exploration_nodes n1 join public.world_map_regions r1 on r1.region_id = n1.region_id where n1.node_id = c.current_exploration_node_id and r1.region_name = c.location)));
  if not found then raise exception '지금 있는 곳의 채집터가 아닙니다.'; end if;
  select * into d from public.world_gathering_discoveries where owner_id = uid and spot_id = s.spot_id for update;
  if not found then raise exception '먼저 탐색으로 채집터를 찾으세요.'; end if;
  if d.last_gathered_at is not null and d.last_gathered_at > now() - interval '5 minutes' then
    raise exception '%', format('이 채집터는 %s초 뒤에 다시 쓸 수 있습니다.', ceil(extract(epoch from d.last_gathered_at + interval '5 minutes' - now()))::int); end if;
  if c.level < s.min_level then raise exception '%', format('레벨 %s부터 채집할 수 있습니다.', s.min_level); end if;
  sk := public.world_skill_procs(uid);
  line := case when s.category in ('ore', 'relics') then 'mining' else 'foraging' end;
  rg := public.world_field_region(c.location);
  select count(*)::int into gcnt from public.world_events e where e.actor_id = uid and e.event_type = 'gather'
     and e.created_at >= (date_trunc('day', now() at time zone 'Asia/Seoul') at time zone 'Asia/Seoul') and (e.payload ->> 'free_day') = 'true';
  if gcnt < 10 then free_st := true; free_day := gcnt + 1; notes := notes || format('오늘의 무료 채집 %s/10 · 탐색력을 쓰지 않았다', gcnt + 1); end if;
  if not free_st and line = 'foraging' and 'foraging_m50' = any (sk) and random() < 0.25 then free_st := true; notes := notes || '「산천의 은혜」 탐색력을 쓰지 않았다'::text; end if;
  left_st := public.world_stamina_change(uid, case when free_st then 0 else -1 end);
  select * into c from public.world_characters where owner_id = uid;
  select round(coalesce((i.equipment_traits ->> 'gathering_bonus_pct')::numeric, 0))::int, i.item_id into tool_bonus, tool_id from public.world_character_equipment e
    join public.world_item_catalog i on i.item_id = e.item_id where e.owner_id = uid and e.slot = 'tool';
  it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];
  qty := s.yield_min + floor(random() * (s.yield_max - s.yield_min + 1))::int + coalesce(c.gathering_rank, 1) / 12;
  prof_match := (c.gathering_profession = 'mining' and s.category in ('ore', 'relics')) or (c.gathering_profession = 'fishing' and s.category = 'water')
    or (c.gathering_profession = 'fieldwork' and s.category in ('herbs', 'wood', 'supplies', 'spirit'));
  if prof_match then qty := qty + 1; end if;
  if exists (select 1 from public.world_character_equipment e join public.world_item_durability dd on dd.owner_id = e.owner_id and dd.item_id = e.item_id
             where e.owner_id = uid and e.slot = 'tool' and dd.durability <= 0) then tool_bonus := 0; end if;
  -- 도구 닳기: 길목 기억(채집 30)·갱도 감각(채광 30)은 닳지 않고, 짐꾼의 요령(채광·가죽 공예 조합)은 50%
  no_wear := (line = 'foraging' and 'foraging_x30' = any (sk)) or (line = 'mining' and 'mining_x30' = any (sk))
    or ('combo_mining_leatherwork' = any (sk) and random() < 0.5);
  if not no_wear then perform public.world_durability_wear(uid, 'tool', 1); end if;
  -- 곡괭이는 광맥·유물, 채집도는 약초·목재·보급품·물가에서 +10%p(우수품 도구도 기본 도구의 줄로)
  select tl.line into tool_ln from public.world_tool_lines tl where tl.item_id = public.world_item_base(tool_id);
  if coalesce(tool_bonus, 0) > 0 and ((tool_ln = 'pick' and s.category in ('ore', 'relics')) or (tool_ln = 'knife' and s.category in ('herbs', 'wood', 'supplies', 'water'))) then
    tool_bonus := tool_bonus + 10;
  end if;
  -- 그 계열 기본 기술(채집량 ≤30·희귀품 ≤8)과 그 계열 칭호
  q_pct := least(30, public.world_line_base(c.skill_progress, line, 'gather_qty_pct')) + public.world_title_bonus('gq_' || line);
  r_pct := least(8, public.world_line_base(c.skill_progress, line, 'rare_loot_pct')) + public.world_title_bonus('gr_' || line);
  qty := greatest(1, round(qty * (1 + (coalesce(tool_bonus, 0) + q_pct + public.world_status_effect_total('gather_qty_pct') + public.world_title_bonus('gather_qty_pct')) / 100.0)));

  -- 몇 배 거두기: 굴림마다 따로, 가장 큰 배수 하나만
  if line = 'foraging' then
    if 'foraging_c24a' = any (sk) and random() < 0.15 and mult < 2 then mult := 2; mnote := '「넓게 줍기」 두 번 거뒀다'; end if;
    if 'foraging_c43a' = any (sk) and random() < 0.10 and mult < 3 then mult := 3; mnote := '「대풍」 세 배로 거뒀다'; end if;
  else
    if 'mining_c24a' = any (sk) and random() < 0.15 and mult < 2 then mult := 2; mnote := '「힘껏 캐기」 두 번 캤다'; end if;
    if 'mining_c43a' = any (sk) and random() < 0.05 and mult < 5 then mult := 5; mnote := '「노다지」 다섯 배로 캤다'; end if;
  end if;
  qty := qty * mult;
  if mnote is not null then notes := notes || mnote; end if;
  -- 영맥 세공(채광·법구 공예 조합): 유물 채집터 15% 하나 더
  if s.category = 'relics' and 'combo_mining_artifice' = any (sk) and random() < 0.15 then qty := qty + 1; notes := notes || '「영맥 세공」 하나 더'::text; end if;

  -- 덤
  if line = 'foraging' then
    if 'foraging_x13' = any (sk) and cardinality(s.loot_items) > 1 and random() < 0.10 then
      select y into x from unnest(s.loot_items) y where y <> it order by random() limit 1;
      if x is not null then extra := public.world_inv_add(extra, x, 1); notes := notes || ('「눈썰미」 덤: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
    end if;
    if 'foraging_c43b' = any (sk) and s.category = 'herbs' and random() < 0.10 then extra := public.world_inv_add(extra, 'herbal_extract', 1); notes := notes || '「본초 감별」 농축 약초액'::text; end if;
    if 'foraging_c43b' = any (sk) and s.category = 'spirit' and random() < 0.05 then extra := public.world_inv_add(extra, 'spirit_core', 1); notes := notes || '「본초 감별」 응축 영핵'::text; end if;
  else
    if 'mining_x13' = any (sk) and random() < 0.10 then extra := public.world_inv_add(extra, 'charcoal', 1); notes := notes || '「광맥 읽기」 정련 숯 덤'::text; end if;
    if 'mining_c24b' = any (sk) and random() < 0.10 then extra := public.world_inv_add(extra, 'iron_ingot', 1); notes := notes || '「옥석 가리기」 월철 주괴'::text; end if;
    if 'mining_c43b' = any (sk) and random() < 0.08 then extra := public.world_inv_add(extra, 'steel_ingot', 1); notes := notes || '「보석 눈」 강철 주괴'::text; end if;
  end if;
  -- 그 지역 희귀품: 기본 기술·칭호 희귀품 %(채집·채광 모두) + 골라 줍기(채집 24b) 10%
  if random() * 100 < r_pct + (case when line = 'foraging' and 'foraging_c24b' = any (sk) then 10 else 0 end) then
    x := null;
    select y into x from public.world_region_profiles p, unnest(p.signature_items) y join public.world_item_catalog ic on ic.item_id = y
     where p.region_id = rg.region_id and y not in ('courier_token', 'spirit_compass', 'gwiryeong_cho') order by random() limit 1;
    if x is not null then extra := public.world_inv_add(extra, x, 1); notes := notes || ('희귀품: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
  end if;
  -- 영맥 낫(약초·영기 3%) · 영등(유물 채집터나 어두운 지역 5%): 그 지역의 희귀품 하나
  if coalesce(tool_bonus, 0) > 0 and exists (select 1 from public.world_item_catalog ti where ti.item_id = tool_id
       and random() * 100 < coalesce((ti.equipment_traits ->> 'sig_pct')::numeric, 0)
       and ((ti.equipment_traits ->> 'sig_where' = 'herb' and s.category in ('herbs', 'spirit'))
         or (ti.equipment_traits ->> 'sig_where' = 'dark' and (s.category = 'relics' or rg.region_type in ('sealed_shrine', 'ruined_temple', 'burial_ground', 'underground', 'abyss', 'rift', 'lost_city', 'underwater_ruins', 'haunted_garden', 'blood_forest'))))) then
    x := null;
    select y into x from public.world_region_profiles p, unnest(p.signature_items) y
     where p.region_id = rg.region_id and y not in ('courier_token', 'spirit_compass', 'gwiryeong_cho') order by random() limit 1;
    if x is not null then extra := public.world_inv_add(extra, x, 1);
      notes := notes || ((select ti.item_name from public.world_item_catalog ti where ti.item_id = tool_id) || ' 희귀품: ' || (select item_name from public.world_item_catalog where item_id = x)); end if;
  end if;

  -- 채집터 대기
  if line = 'foraging' and 'foraging_x30' = any (sk) then wait_s := 240; end if;
  if (line = 'mining' and 'mining_m50' = any (sk)) or (s.category = 'spirit' and 'combo_analysis_spirit_gathering' = any (sk)) then wait_s := wait_s / 2; end if;

  inv := public.world_inv_add(c.inventory, it, qty);
  for k, v in select key, value::text::int from jsonb_each(extra) loop inv := public.world_inv_add(inv, k, v); end loop;
  update public.world_characters set inventory = inv, updated_at = now() where owner_id = uid;
  update public.world_gathering_discoveries set last_gathered_at = now() - make_interval(secs => 300 - wait_s), gather_count = gather_count + 1 where owner_id = uid and spot_id = s.spot_id;
  select item_name into nm from public.world_item_catalog where item_id = it;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'gather', s.spot_name || '에서 ' || nm || ' ×' || qty || ' 채집',
    jsonb_build_object('spot_id', s.spot_id, 'category', s.category, 'item_id', it, 'qty', qty, 'node_id', s.node_id, 'line', line,
      'node', case s.category when 'ore' then 'ore' when 'herbs' then 'herb' when 'spirit' then 'shrine' else 'field' end, 'profession_match', prof_match, 'extra', extra, 'free_day', free_day > 0));
  return jsonb_build_object('ok', true, 'content', s.spot_name || '에서 ' || nm || ' ×' || qty || '을(를) 얻었습니다.' || case when prof_match then ' (전문 분야 +1)' else '' end
      || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end,
    'item_id', it, 'qty', qty, 'extra', extra, 'line', line, 'stamina', left_st, 'free_left', greatest(0, 10 - gcnt - case when free_day > 0 then 1 else 0 end), 'ready_at', now() + make_interval(secs => wait_s));
end $function$;

-- ── 낚시(7.5.0): 낚시 계열(입질·희귀 어종·크기), 한 번에 기술 경험 8(낚든 놓치든) ──
-- 캐릭터 행 갱신은 한 번(탐색력·가방·경험을 함께) — 전에는 낚으면 두 번이었다.
create or replace function public.world_fish()
 returns jsonb language plpgsql security definer set search_path to ''
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; g public.world_fish_grounds%rowtype;
  sp public.world_fish_species%rowtype; rod int; last timestamptz; ph text; wk text; bite numeric; boost numeric; size numeric; first boolean;
  xp int := 0; left_st int; inv jsonb; msg text; rname text; sk text[]; prog jsonb; gap int := 20; mx int; ticks int; cur int; base_at timestamptz;
  cost int := 1; caught boolean; notes text[] := '{}'; sxp int; more int := 0; nmore int := 0;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.downed_at is not null or c.health <= 0 then raise exception '전투불능 상태에서는 낚시할 수 없습니다.'; end if;
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then raise exception '전투 중에는 낚시할 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then raise exception '원정 중에는 낚시할 수 없습니다.'; end if;
  r := public.world_field_region(c.location);
  select * into g from public.world_fish_grounds where region_id = r.region_id;
  if g.region_id is null then raise exception '이곳에는 낚시터가 없습니다. 강·늪·바다·호수가 있는 지역에서 낚을 수 있습니다.'; end if;
  rod := coalesce((select i.tier from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);
  if rod = 0 then raise exception '낚싯대가 있어야 낚시할 수 있습니다. 구름나루·백등 야시장·잔불촌 상점에서 사거나 직접 만들 수 있습니다.'; end if;
  sk := public.world_skill_procs(uid);
  if 'fishing_c24a' = any (sk) then gap := 15; end if; -- 재빠른 챔질
  select max(created_at) into last from public.world_events where actor_id = uid and event_type = 'fish' and created_at > now() - make_interval(secs => gap);
  if last is not null then raise exception '%', format('찌를 다시 던지려면 %s초 기다리세요.', ceil(extract(epoch from (last + make_interval(secs => gap) - now())))::int); end if;
  -- 탐색력(용왕의 손 25%는 쓰지 않음, 놓친 고기 없다는 놓치면 돌려받음)
  if 'fishing_m50' = any (sk) and random() < 0.25 then cost := 0; notes := notes || '「용왕의 손」 탐색력을 쓰지 않았다'::text; end if;
  mx := public.world_stamina_max(c.level);
  ticks := floor(greatest(0, extract(epoch from now() - c.stamina_at)) / 900)::int;
  cur := least(mx, greatest(0, c.stamina) + ticks);
  if cur - cost < 0 then
    raise exception '%', format('탐색력이 부족합니다. %s분 뒤에 1 회복됩니다.', greatest(1, ceil((900 - mod(greatest(0, extract(epoch from now() - c.stamina_at))::numeric, 900)) / 60)::int));
  end if;
  base_at := case when cur >= mx then now() else c.stamina_at + make_interval(secs => ticks * 900) end;
  ph := public.world_time_phase(now()); wk := public.world_weather_key(r.territory_id, now());
  bite := 0.62 + least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 0.06 + case when c.gathering_profession = 'fishing' then 0.08 else 0 end + case when wk in ('rain', 'fog', 'cloudy') then 0.05 else 0 end
    + (public.world_title_bonus('fish_bite_pct') + public.world_status_effect_total('fish_bite_pct') + public.world_line_base(c.skill_progress, 'fishing', 'fish_bite_pct')) / 100.0
    + coalesce((select (i.equipment_traits ->> 'fish_bite_pct')::numeric from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0) / 100.0
    + case when 'fishing_c43b' = any (sk) and exists (select 1 from public.world_fish_species s where s.habitat = g.habitat and s.active and (s.phase = ph or s.weather = wk)) then 0.10 else 0 end;
  bite := least(0.95, greatest(0.3, bite));
  caught := random() <= bite;
  sxp := round(8 * greatest(0.5, 1 + public.world_status_self(uid, 'training_xp_pct') / 100.0))::int;
  prog := public.world_skill_add(c.skill_progress, 'fishing', sxp);
  if not caught then
    if 'fishing_c24b' = any (sk) and cost > 0 then cost := 0; notes := notes || '「놓친 고기 없다」 탐색력을 돌려받았다'::text; end if;
    left_st := least(mx, cur - cost);
    update public.world_characters set stamina = left_st, stamina_at = base_at, skill_progress = prog, updated_at = now() where owner_id = uid;
    msg := g.ground_name || '에서 찌가 흔들렸지만 놓쳤습니다.' || case when cardinality(notes) > 0 then ' ' || array_to_string(notes, ' · ') || '.' else '' end;
    insert into public.world_events(actor_id, actor_name, event_type, content, payload)
    values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', false, 'region_id', r.region_id, 'habitat', g.habitat, 'skill_xp', sxp));
    return jsonb_build_object('ok', true, 'caught', false, 'content', msg, 'stamina', left_st, 'ready_at', now() + make_interval(secs => gap));
  end if;
  boost := public.world_title_bonus('fish_rare_pct') + public.world_status_effect_total('fish_rare_pct') + public.world_status_effect_total('rare_loot_pct')
    + least(rod, case when 'combo_fishing_carpentry' = any (sk) then 3 else 2 end) * 3 + public.world_line_base(c.skill_progress, 'fishing', 'fish_rare_pct')
    + coalesce((select (i.equipment_traits ->> 'fish_rare_pct')::numeric from public.world_item_catalog i where i.item_id = public.world_fish_rod(uid)), 0);
  select * into sp from public.world_fish_species s
   where s.habitat = g.habitat and s.active and s.min_level <= c.level + 2 and (s.grounds is null or r.region_id = any(s.grounds))
   order by -ln(greatest(random(), 1e-9)) / (
       (case s.rarity when 'common' then 60 when 'uncommon' then 25 when 'rare' then 9 * (1 + boost / 100.0) when 'epic' then 3 * (1 + boost / 100.0) else 0.6 * (1 + boost / 100.0) end)
     * (case when s.rarity in ('epic', 'legendary') and 'fishing_c43a' = any (sk) then 1.5 else 1 end)
     * (case when s.phase is null then 1 when s.phase = ph then 3 when 'fishing_x30' = any (sk) then 0.6 else 0.3 end)
     * (case when s.weather is null then 1 when s.weather = wk then 3 when 'fishing_x30' = any (sk) then 0.6 else 0.3 end)) limit 1;
  if sp.fish_id is null then raise exception '물고기가 보이지 않습니다.'; end if;
  size := round(least(sp.size_max * 1.1, (sp.size_min + (sp.size_max - sp.size_min) * power(random(), 1.6)::numeric)
    * (1 + (public.world_title_bonus('fish_size_pct') + public.world_line_base(c.skill_progress, 'fishing', 'fish_size_pct')) / 100.0)), 1);
  first := not exists (select 1 from public.world_fish_log where owner_id = uid and fish_id = sp.fish_id);
  -- 두 마리(낚시 13)·그물 짓기(낚시·직조 조합): 따로 굴리되 한 번에 하나만 더
  if ('fishing_x13' = any (sk) and random() < 0.08) or ('combo_fishing_weaving' = any (sk) and random() < 0.10) then more := 1; notes := notes || '같은 물고기를 하나 더 낚았다'::text; end if;
  insert into public.world_fish_log(owner_id, fish_id, caught, best_size) values (uid, sp.fish_id, 1 + more, size)
  on conflict (owner_id, fish_id) do update set caught = public.world_fish_log.caught + 1 + more, best_size = greatest(public.world_fish_log.best_size, excluded.best_size), last_at = now();
  xp := case sp.rarity when 'common' then 6 when 'uncommon' then 10 when 'rare' then 18 when 'epic' then 30 else 50 end;
  inv := public.world_inv_add(c.inventory, sp.fish_id, 1 + more);
  -- 갯가 주방(낚시·요리 조합): 20% 손질한 생선 하나
  if 'combo_fishing_cooking' = any (sk) and random() < 0.20 then inv := public.world_inv_add(inv, 'fish_fillet', 1); nmore := 1; notes := notes || '「갯가 주방」 손질한 생선 하나'::text; end if;
  left_st := least(mx, cur - cost);
  update public.world_characters set inventory = inv, gathering_xp = gathering_xp + xp, skill_progress = prog,
    stamina = left_st, stamina_at = base_at, updated_at = now() where owner_id = uid;
  rname := case sp.rarity when 'uncommon' then '양품' when 'rare' then '진품' when 'epic' then '명품' when 'legendary' then '신품' else '' end;
  msg := g.ground_name || '에서 ' || sp.fish_name || '을(를) 낚았습니다. ' || size || 'cm' || case when rname <> '' then ' · ' || rname else '' end
    || case when first then ' · 도감에 새로 올랐습니다' else '' end || case when cardinality(notes) > 0 then ' · ' || array_to_string(notes, ' · ') else '' end;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'fish', msg, jsonb_build_object('caught', true, 'fish', sp.fish_id, 'rarity', sp.rarity, 'size', size,
    'region_id', r.region_id, 'habitat', g.habitat, 'first', first, 'qty', 1 + more, 'skill_xp', sxp));
  perform public.world_title_award_check(uid, 'fish');
  return jsonb_build_object('ok', true, 'caught', true, 'content', msg, 'fish', sp.fish_id, 'fish_name', sp.fish_name, 'rarity', sp.rarity,
    'size', size, 'first', first, 'xp', xp, 'qty', 1 + more, 'stamina', left_st, 'ready_at', now() + make_interval(secs => gap));
end $function$;


-- ── 기술 표 ─────────────────────────────────────────────────────────────

delete from public.world_skill_catalog where category in ('herbalism', 'spirit_gathering');
delete from public.world_exp_skill_def where skill_id ~ '^(herbalism|spirit_gathering|smithing|alchemy|wardcraft)_';
update public.world_skill_catalog set skill_name = skill_name || '#' || skill_id where category in ('smithing','carpentry','artifice','weaving','leatherwork','wardcraft','alchemy','cooking','foraging','mining','fishing');
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_forge', '정밀 단조', 'smithing', '단조 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_master', '요철 합금', 'smithing', '단조 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t13', '담금질', 'smithing', '단조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_x13', '불꽃 담금', 'smithing', '추가 기술 · 단조 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t18', '두드림', 'smithing', '단조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t24', '불 다루기', 'smithing', '단조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_c24a', '섬세한 단조', 'smithing', '택일 기술 · 단조 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_c24b', '현장 수리', 'smithing', '택일 기술 · 수리 도구로 단조로 만든 장비를 손보면 내구도를 전부 되살린다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t30', '합금 비법', 'smithing', '단조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_x30', '명장의 눈', 'smithing', '추가 기술 · 단조 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t36', '명장의 손', 'smithing', '단조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t43', '천공', 'smithing', '단조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_c43a', '일품 단조', 'smithing', '택일 기술 · 근접 무기 강화 성공 확률 +10%p', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_c43b', '대장간 단골', 'smithing', '택일 기술 · 단조로 만든 장비는 대장간 수리비가 절반', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_t50', '대장장 명인', 'smithing', '단조 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('smithing_m50', '천하명장', 'smithing', '숙달 기술 · 단조 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t3', '먹줄 놓기', 'carpentry', '목공 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t8', '결 읽기', 'carpentry', '목공 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t13', '대패질', 'carpentry', '목공 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_x13', '톱밥 줍기', 'carpentry', '추가 기술 · 목공 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t18', '짜맞춤', 'carpentry', '목공 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t24', '나무 고르기', 'carpentry', '목공 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_c24a', '활장이', 'carpentry', '택일 기술 · 목공 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_c24b', '살대 다듬기', 'carpentry', '택일 기술 · 화살·쇠뇌살·취관 침을 만들면 만드는 개수 +25%(올림)', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t30', '부레풀 붙임', 'carpentry', '목공 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_x30', '목심 보기', 'carpentry', '추가 기술 · 목공 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t36', '옻칠', 'carpentry', '목공 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t43', '도편수의 손', 'carpentry', '목공 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_c43a', '백보천양', 'carpentry', '택일 기술 · 원거리 무기 강화 성공 확률 +10%p', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_c43b', '살림 목수', 'carpentry', '택일 기술 · 가구를 만들면 25% 확률로 재료 한 종류를 하나 돌려받는다(가구는 언제나 하나만 만든다)', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_t50', '대목장', 'carpentry', '목공 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('carpentry_m50', '천년 목심', 'carpentry', '숙달 기술 · 목공 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t3', '영문 새기기', 'artifice', '법구 공예 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t8', '법기 조율', 'artifice', '법구 공예 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t13', '청동 주조', 'artifice', '법구 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_x13', '쇳물 거두기', 'artifice', '추가 기술 · 법구 공예 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t18', '방위 맞추기', 'artifice', '법구 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t24', '등불 심지', 'artifice', '법구 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_c24a', '정밀 법구', 'artifice', '택일 기술 · 법구 공예 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_c24b', '법기 손질', 'artifice', '택일 기술 · 수리 도구로 법구 공예로 만든 장비를 손보면 내구도를 전부 되살린다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t30', '혼천 설계', 'artifice', '법구 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_x30', '명기 감정', 'artifice', '추가 기술 · 법구 공예 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t36', '천기 읽기', 'artifice', '법구 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t43', '신기 각성', 'artifice', '법구 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_c43a', '법륜 단련', 'artifice', '택일 기술 · 술법 무기 강화 성공 확률 +10%p', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_c43b', '법기 해체', 'artifice', '택일 기술 · 법구 공예로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_t50', '법구 명인', 'artifice', '법구 공예 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('artifice_m50', '신기 현현', 'artifice', '숙달 기술 · 법구 공예 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t3', '씨실 날실', 'weaving', '직조 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t8', '베틀 다루기', 'weaving', '직조 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t13', '홈질', 'weaving', '직조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_x13', '실 아끼기', 'weaving', '추가 기술 · 직조 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t18', '누빔', 'weaving', '직조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t24', '고운 결', 'weaving', '직조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_c24a', '겹바느질', 'weaving', '택일 기술 · 직조 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_c24b', '수선 바느질', 'weaving', '택일 기술 · 수리 도구로 직조로 만든 장비를 손보면 내구도를 전부 되살린다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t30', '자수', 'weaving', '직조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_x30', '천의 솜씨', 'weaving', '추가 기술 · 직조 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t36', '금박 찍기', 'weaving', '직조 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t43', '비단 장인', 'weaving', '직조 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_c43a', '비단 솜씨', 'weaving', '택일 기술 · 직조 제작 때 15% 확률로 하나 더', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_c43b', '올 풀기', 'weaving', '택일 기술 · 직조로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_t50', '침선 명인', 'weaving', '직조 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('weaving_m50', '천의무봉', 'weaving', '숙달 기술 · 직조 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t3', '가죽 고르기', 'leatherwork', '가죽 공예 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t8', '무두 손질', 'leatherwork', '가죽 공예 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t13', '재단', 'leatherwork', '가죽 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_x13', '무두질', 'leatherwork', '추가 기술 · 가죽 공예 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t18', '박음질', 'leatherwork', '가죽 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t24', '기름 먹이기', 'leatherwork', '가죽 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_c24a', '경갑 재단', 'leatherwork', '택일 기술 · 가죽 공예 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_c24b', '덧댐 손질', 'leatherwork', '택일 기술 · 수리 도구로 가죽 공예로 만든 장비를 손보면 내구도를 전부 되살린다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t30', '비늘 엮기', 'leatherwork', '가죽 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_x30', '가죽 눈썰미', 'leatherwork', '추가 기술 · 가죽 공예 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t36', '덧대기', 'leatherwork', '가죽 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t43', '갖바치 솜씨', 'leatherwork', '가죽 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_c43a', '갖신 솜씨', 'leatherwork', '택일 기술 · 가죽 공예 제작 때 15% 확률로 하나 더', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_c43b', '짐틀 장인', 'leatherwork', '택일 기술 · 가죽 공예로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_t50', '갖바치 명인', 'leatherwork', '가죽 공예 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('leatherwork_m50', '천하 갖바치', 'leatherwork', '숙달 기술 · 가죽 공예 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_fine', '정밀 각인', 'wardcraft', '봉인 공예 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_master', '오방진 설계', 'wardcraft', '봉인 공예 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t13', '정갈한 획', 'wardcraft', '봉인 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_x13', '먹 고르기', 'wardcraft', '추가 기술 · 봉인 공예 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t18', '주사 다루기', 'wardcraft', '봉인 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t24', '부적 겹치기', 'wardcraft', '봉인 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_c24a', '정교한 각인', 'wardcraft', '택일 기술 · 봉인 공예 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_c24b', '부적 묶음', 'wardcraft', '택일 기술 · 부적(정화·회생 부적 같은 봉인 공예 소모품)을 만들면 만드는 개수 +25%(올림)', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t30', '팔괘 각인', 'wardcraft', '봉인 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_x30', '천하 각인', 'wardcraft', '추가 기술 · 봉인 공예 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t36', '결계 설계', 'wardcraft', '봉인 공예 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t43', '봉인 비문', 'wardcraft', '봉인 공예 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_c43a', '겹결계', 'wardcraft', '택일 기술 · 봉인 공예 제작 때 15% 확률로 하나 더', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_c43b', '부적 해체', 'wardcraft', '택일 기술 · 봉인 공예로 만든 장비를 분해하면 돌려받는 재료 가운데 하나를 하나 더', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_t50', '각인 명인', 'wardcraft', '봉인 공예 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('wardcraft_m50', '만법귀일', 'wardcraft', '숙달 기술 · 봉인 공예 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_mix', '안정 혼합', 'alchemy', '연금 제작 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_potent', '고농축 배합', 'alchemy', '연금 제작 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t13', '불 조절', 'alchemy', '연금 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_x13', '달이기', 'alchemy', '추가 기술 · 연금 제작 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t18', '증류', 'alchemy', '연금 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t24', '약성 끌어올리기', 'alchemy', '연금 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_c24a', '화후 조절', 'alchemy', '택일 기술 · 연금 제작 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_c24b', '약재 바탕 아끼기', 'alchemy', '택일 기술 · 약제 바탕·농축 약초액이 재료로 들어가면 30% 확률로 그 재료를 쓰지 않는다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t30', '단약 제련', 'alchemy', '연금 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_x30', '단약 감정', 'alchemy', '추가 기술 · 연금 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t36', '내단', 'alchemy', '연금 제작 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t43', '연단술', 'alchemy', '연금 제작 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_c43a', '농축', 'alchemy', '택일 기술 · 연금 제작 때 15% 확률로 하나 더', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_c43b', '금단', 'alchemy', '택일 기술 · 연금 제작 때 30% 확률로 가장 비싼 재료 하나를 돌려받는다', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_t50', '선단 명인', 'alchemy', '연금 제작 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('alchemy_m50', '구전금단', 'alchemy', '숙달 기술 · 연금 제작 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t3', '칼질', 'cooking', '요리 품질 +8.', '{"craft_quality": 8}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t8', '불 조절', 'cooking', '요리 품질 +6.', '{"craft_quality": 6}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t13', '간 맞추기', 'cooking', '요리 품질 +3.', '{"craft_quality": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_x13', '알뜰 장보기', 'cooking', '추가 기술 · 요리 때 10% 확률로 재료 한 종류를 하나 돌려받는다', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t18', '뜸 들이기', 'cooking', '요리 품질 +3.', '{"craft_quality": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t24', '양념 비법', 'cooking', '요리 품질 +4.', '{"craft_quality": 4}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_c24a', '두 번 맛보기', 'cooking', '택일 기술 · 요리 품질을 두 번 굴려 높은 쪽을 쓴다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_c24b', '생선 손질 솜씨', 'cooking', '택일 기술 · 손질한 생선을 만들면 30% 확률로 하나 더', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t30', '밥상 차림', 'cooking', '요리 품질 +4.', '{"craft_quality": 4}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_x30', '일품 요리', 'cooking', '추가 기술 · 요리 제작은 품질 80부터 우수품이 된다(보통 85). 개수는 바뀌지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t36', '손맛', 'cooking', '요리 품질 +4.', '{"craft_quality": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t43', '궁중 비법', 'cooking', '요리 품질 +3.', '{"craft_quality": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_c43a', '넉넉한 솥', 'cooking', '택일 기술 · 요리(소모품)를 만들면 15% 확률로 한 그릇 더', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_c43b', '든든한 한 끼', 'cooking', '택일 기술 · 내가 먹은 음식의 이로운 상태(든든함·속이 따뜻함·기운 충천·바다의 복)가 50% 더 오래 간다(world_use_item의 meal 상태 지속 시간에 곱함)', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_t50', '숙수 명인', 'cooking', '요리 품질 +5.', '{"craft_quality": 5}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('cooking_m50', '대령숙수', 'cooking', '숙달 기술 · 요리 때 10% 확률로 재료를 하나도 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('forage_select', '선별 채집', 'foraging', '채집 채집량 +3%.', '{"gather_qty_pct": 3}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('forage_preserve', '풀잎 감별', 'foraging', '채집 채집량 +3%.', '{"gather_qty_pct": 3}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t13', '빠른 손', 'foraging', '채집 채집량 +4%.', '{"gather_qty_pct": 4}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_x13', '눈썰미', 'foraging', '추가 기술 · 채집 때 10% 확률로 그 채집터의 다른 재료 하나 덤', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t18', '좋은 것만', 'foraging', '채집 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t24', '한 아름', 'foraging', '채집 채집량 +5%.', '{"gather_qty_pct": 5}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_c24a', '넓게 줍기', 'foraging', '택일 기술 · 채집 때 15% 확률로 두 번 거둔다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_c24b', '골라 줍기', 'foraging', '택일 기술 · 채집 때 10% 확률로 그 지역 희귀품 하나', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t30', '숨은 결실', 'foraging', '채집 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_x30', '길목 기억', 'foraging', '추가 기술 · 채집터를 다시 쓰는 대기 5분 → 4분, 채집 도구가 닳지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t36', '풍년', 'foraging', '채집 채집량 +5%.', '{"gather_qty_pct": 5}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t43', '산의 은혜', 'foraging', '채집 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_c43a', '대풍', 'foraging', '택일 기술 · 채집 때 10% 확률로 세 배 거둔다', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_c43b', '본초 감별', 'foraging', '택일 기술 · 약초 채집터에서 10% 확률로 농축 약초액, 영기 채집터에서 5% 확률로 응축 영핵 하나', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_t50', '채집 명인', 'foraging', '채집 채집량 +6%.', '{"gather_qty_pct": 6}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('foraging_m50', '산천의 은혜', 'foraging', '숙달 기술 · 채집 때 25% 확률로 탐색력을 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_vein', '맥 찾기', 'mining', '채광 채집량 +3%.', '{"gather_qty_pct": 3}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_refine', '정 다루기', 'mining', '채광 채집량 +3%.', '{"gather_qty_pct": 3}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t13', '쪼개기', 'mining', '채광 채집량 +4%.', '{"gather_qty_pct": 4}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_x13', '광맥 읽기', 'mining', '추가 기술 · 채광 때 10% 확률로 정련 숯 하나 덤', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t18', '맥 짚기', 'mining', '채광 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t24', '큰 덩이', 'mining', '채광 채집량 +5%.', '{"gather_qty_pct": 5}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_c24a', '힘껏 캐기', 'mining', '택일 기술 · 채광 때 15% 확률로 두 번 캔다', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_c24b', '옥석 가리기', 'mining', '택일 기술 · 채광 때 10% 확률로 월철 주괴 하나', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t30', '원석 감별', 'mining', '채광 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_x30', '갱도 감각', 'mining', '추가 기술 · 채광 때 도구가 닳지 않는다', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t36', '갱도 개척', 'mining', '채광 채집량 +5%.', '{"gather_qty_pct": 5}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t43', '광맥의 눈', 'mining', '채광 희귀품 +2%.', '{"rare_loot_pct": 2}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_c43a', '노다지', 'mining', '택일 기술 · 채광 때 5% 확률로 다섯 배', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_c43b', '보석 눈', 'mining', '택일 기술 · 채광 때 8% 확률로 강철 주괴 하나', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_t50', '채광 명인', 'mining', '채광 채집량 +6%.', '{"gather_qty_pct": 6}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('mining_m50', '지맥의 주인', 'mining', '숙달 기술 · 채광한 채집터는 다시 쓰는 대기가 절반', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t3', '찌 보기', 'fishing', '입질 +2%p.', '{"fish_bite_pct": 2}'::jsonb, 3, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t8', '물때 읽기', 'fishing', '입질 +2%p.', '{"fish_bite_pct": 2}'::jsonb, 8, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t13', '손맛', 'fishing', '물고기 크기 +3%.', '{"fish_size_pct": 3}'::jsonb, 13, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_x13', '두 마리', 'fishing', '추가 기술 · 낚을 때 8% 확률로 같은 물고기를 하나 더', '{}'::jsonb, 13, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t18', '물 밑 보기', 'fishing', '희귀 어종 +3%.', '{"fish_rare_pct": 3}'::jsonb, 18, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t24', '낚싯줄 고르기', 'fishing', '입질 +3%p.', '{"fish_bite_pct": 3}'::jsonb, 24, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_c24a', '재빠른 챔질', 'fishing', '택일 기술 · 찌를 다시 던지는 대기 20초 → 15초', '{}'::jsonb, 24, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_c24b', '놓친 고기 없다', 'fishing', '택일 기술 · 놓치면 탐색력 1을 돌려받는다', '{}'::jsonb, 24, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t30', '물결 읽기', 'fishing', '희귀 어종 +3%.', '{"fish_rare_pct": 3}'::jsonb, 30, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_x30', '때를 아는 낚시꾼', 'fishing', '추가 기술 · 잘 무는 시간대·날씨가 아닐 때 어종 무게 ×0.3 → ×0.6', '{}'::jsonb, 30, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t36', '대물 손맛', 'fishing', '물고기 크기 +4%.', '{"fish_size_pct": 4}'::jsonb, 36, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t43', '물속 눈', 'fishing', '희귀 어종 +3%.', '{"fish_rare_pct": 3}'::jsonb, 43, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_c43a', '대어의 길', 'fishing', '택일 기술 · 명품·신품 어종 무게 ×1.5', '{}'::jsonb, 43, 'a') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_c43b', '물때 맞추기', 'fishing', '택일 기술 · 잘 무는 시간대·날씨가 맞을 때 입질 +10%p', '{}'::jsonb, 43, 'b') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_t50', '어부 명인', 'fishing', '입질 +3%p · 물고기 크기 +3%.', '{"fish_bite_pct": 3, "fish_size_pct": 3}'::jsonb, 50, 'base') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('fishing_m50', '용왕의 손', 'fishing', '숙달 기술 · 낚시 때 25% 확률로 탐색력을 쓰지 않는다', '{}'::jsonb, 50, 'master') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values ('tracking_x36', '영초 감별', 'tracking', '추가 기술 · 위험도 7 이상 지역에서 탐색하거나 조사 지점을 살필 때 0.2% 확률로 귀령초 하나(한 번 얻으면 72시간 다시 나오지 않음)', '{}'::jsonb, 36, 'extra') on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_analysis_spirit_gathering', '영맥 판독', 'combo', '조합 기술(분석·채집 둘 다 18단계) · 영기 채집터에서 거둔 채집터는 다시 쓰는 대기가 절반', '{}'::jsonb, 18, 'combo', '{"analysis": 18, "foraging": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_first_aid_herbalism', '야전 약방', 'combo', '조합 기술(응급 처치·채집 둘 다 18단계) · 약초를 쓰면 약초액만큼(체력 22) 회복', '{}'::jsonb, 18, 'combo', '{"first_aid": 18, "foraging": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_foraging_alchemy', '현장 조제', 'combo', '조합 기술(채집·연금 둘 다 18단계) · 쉬기·야영 때 야령초 2개로 농축 약초액 하나를 저절로 만든다', '{}'::jsonb, 18, 'combo', '{"alchemy": 18, "foraging": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_guarding_mining', '바위 몸', 'combo', '조합 기술(막기·채광 둘 다 18단계) · 방어한 턴에 받은 피해의 30%만큼 체력 회복', '{}'::jsonb, 18, 'combo', '{"mining": 18, "guarding": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_sealing_wardcraft', '겹봉인', 'combo', '조합 기술(봉인술·봉인 공예 둘 다 18단계) · 봉인술로 묶으면 2턴 동안 움직이지 못한다', '{}'::jsonb, 18, 'combo', '{"sealing": 18, "wardcraft": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_mining_artifice', '영맥 세공', 'combo', '조합 기술(채광·법구 공예 둘 다 18단계) · 유물 채집터에서 거두면 15% 확률로 하나 더', '{}'::jsonb, 18, 'combo', '{"mining": 18, "artifice": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_mining_leatherwork', '짐꾼의 요령', 'combo', '조합 기술(채광·가죽 공예 둘 다 18단계) · 채집·채광 때 채집 도구가 닳지 않을 확률 50%', '{}'::jsonb, 18, 'combo', '{"mining": 18, "leatherwork": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_fishing_weaving', '그물 짓기', 'combo', '조합 기술(낚시·직조 둘 다 18단계) · 낚을 때 10% 확률로 같은 어종 하나 더(「두 마리」와 따로 굴리되 한 번에 하나만 더)', '{}'::jsonb, 18, 'combo', '{"fishing": 18, "weaving": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_fishing_cooking', '갯가 주방', 'combo', '조합 기술(낚시·요리 둘 다 18단계) · 물고기를 낚으면 20% 확률로 손질한 생선 하나를 함께 얻는다', '{}'::jsonb, 18, 'combo', '{"fishing": 18, "cooking": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot, requires) values ('combo_fishing_carpentry', '낚싯대 깎는 손', 'combo', '조합 기술(낚시·목공 둘 다 18단계) · 낚싯대 단계 덤(입질 단계마다 +6%p·희귀 +3%)을 3단계까지 받는다', '{}'::jsonb, 18, 'combo', '{"fishing": 18, "carpentry": 18}'::jsonb) on conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, requires = excluded.requires;
update public.world_skill_catalog set description = replace(replace(description, '결계 각인', '봉인 공예'), '일반 채집', '채집') where category = 'combo';
do $c$ begin
  if exists (select 1 from public.world_skill_catalog where category in ('smithing','carpentry','artifice','weaving','leatherwork','wardcraft','alchemy','cooking','foraging','mining','fishing')
             group by category, unlock_rank, slot having count(*) > 1) then raise exception '기술표 칸이 겹칩니다'; end if;
end $c$;
update public.world_crafting_recipes set required_skill = 'foraging' where required_skill in ('spirit_gathering', 'herbalism');

-- ── 제작법이 없는 장비의 계열(새 장비를 넣을 때도 한 줄) ─────────────────────

insert into public.world_gear_line_map(item_id, line)
select i.item_id, case
    when i.category = 'weapon' then case i.equipment_traits ->> 'weapon_type' when 'ranged' then 'carpentry' when 'magic' then 'artifice' else 'smithing' end
    when i.category = 'armor' then case when i.item_name ~ '(갑|찰|미늘|투구)' then 'smithing' when i.item_name like '%야행복%' then 'leatherwork' else 'weaving' end
    when i.category = 'hat' then case when i.item_name like '%투구%' then 'smithing' else 'weaving' end
    when i.category = 'shoes' then 'leatherwork'
    when i.category = 'norigae' then 'weaving'
    when i.category in ('amulet', 'mask') then 'wardcraft'
    when i.category = 'tool' then case (select tl.line from public.world_tool_lines tl where tl.item_id = i.item_id) when 'lantern' then 'artifice' when 'rod' then 'carpentry' else 'smithing' end
    else 'smithing' end
  from public.world_item_catalog i
 where i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
   and not exists (select 1 from public.world_crafting_recipes r where r.output_item = i.item_id)
on conflict (item_id) do nothing;

-- ── 기본 생산량(소모품·재료, 가구·장비는 1) ─────────────────────────────────

update public.world_crafting_recipes r set output_qty = greatest(r.output_qty, v.n) from (values ('brew_calm', 2), ('brew_grand_pill', 2), ('brew_purify_water', 2), ('brew_rejuv_pill', 2), ('clear_spirit_pill_recipe', 3), ('cook_bark_stew', 3), ('cook_carp_broth', 2), ('cook_catfish', 2), ('cook_croaker_soup', 2), ('cook_fish_porridge', 2), ('cook_goby', 2), ('cook_grilled_fish', 2), ('cook_gukbap', 2), ('cook_herb_fish', 2), ('cook_herb_rice', 3), ('cook_spicy_stew', 2), ('cook_sweetfish', 2), ('extract_herb', 2), ('fillet_bullhead', 3), ('fillet_canal_carp', 2), ('fillet_canal_eel', 2), ('fillet_dace', 2), ('fillet_filefish', 2), ('fillet_loach', 2), ('fillet_mackerel', 2), ('fillet_mandarin', 3), ('fillet_minnow', 2), ('fillet_rockfish', 2), ('fillet_shad', 2), ('fillet_smelt', 2), ('heavenly_dew_recipe', 2), ('make_ammo_arrow', 70), ('make_ammo_bolt', 60), ('make_ammo_dart', 70), ('make_lacquer', 3), ('make_lumber', 2), ('make_oil_lamp', 3), ('make_reinforced_leather', 2), ('make_resin', 2), ('make_rune_plate', 2), ('make_sealing_ink', 3), ('make_travel_ration', 5), ('melt_spirit_glass', 2), ('moonlight_essence_recipe', 2), ('r_treat_fish', 5), ('recipe_field_tonic', 3), ('recipe_revival_charm', 2), ('refine_iron', 3), ('reinforce_lumber', 2), ('repair_kit_recipe', 3), ('spin_spirit_thread', 3), ('spirit_qi_pill_recipe', 3), ('spirit_tea_recipe', 3), ('stew_lenok', 2), ('synth_spirit_core', 3), ('tonic_recipe', 2), ('ward_recipe', 3)) v(id, n) where r.recipe_id = v.id;
update public.world_crafting_recipes r set output_qty = ceil(r.output_qty * 1.5)::int
  from public.world_item_catalog i
 where i.item_id = r.output_item and i.category in ('consumable', 'material')
   and r.recipe_id not in ('brew_calm', 'brew_grand_pill', 'brew_purify_water', 'brew_rejuv_pill', 'clear_spirit_pill_recipe', 'cook_bark_stew', 'cook_carp_broth', 'cook_catfish', 'cook_croaker_soup', 'cook_fish_porridge', 'cook_goby', 'cook_grilled_fish', 'cook_gukbap', 'cook_herb_fish', 'cook_herb_rice', 'cook_spicy_stew', 'cook_sweetfish', 'extract_herb', 'fillet_bullhead', 'fillet_canal_carp', 'fillet_canal_eel', 'fillet_dace', 'fillet_filefish', 'fillet_loach', 'fillet_mackerel', 'fillet_mandarin', 'fillet_minnow', 'fillet_rockfish', 'fillet_shad', 'fillet_smelt', 'heavenly_dew_recipe', 'make_ammo_arrow', 'make_ammo_bolt', 'make_ammo_dart', 'make_lacquer', 'make_lumber', 'make_oil_lamp', 'make_reinforced_leather', 'make_resin', 'make_rune_plate', 'make_sealing_ink', 'make_travel_ration', 'melt_spirit_glass', 'moonlight_essence_recipe', 'r_treat_fish', 'recipe_field_tonic', 'recipe_revival_charm', 'refine_iron', 'reinforce_lumber', 'repair_kit_recipe', 'spin_spirit_thread', 'spirit_qi_pill_recipe', 'spirit_tea_recipe', 'stew_lenok', 'synth_spirit_core', 'tonic_recipe', 'ward_recipe');

-- ── 우수품(<id>_hq): 제작법이 있는 장비 + 수치 효과가 있는 소모품(탄·말린 생선포·노정 건량 제외) ──

do $h$ begin
  if exists (select 1 from public.world_item_catalog where item_id like '%\_hq' and base_item_id is null) then raise exception '이미 _hq로 끝나는 물품이 있습니다'; end if;
end $h$;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, required_stats, required_job, required_faction, minimum_level,
  rarity, acquisition_difficulty, drop_rate_modifier, equipment_traits, crafting_specialization, tradeable, reference_price, stack_size, base_item_id, quality_grade)
select i.item_id || '_hq', i.item_name || ' (우수)', i.category, i.tier, i.description || ' ' || public.world_item_hq_note(i.item_id, i.category), i.stackable,
  i.required_stats, i.required_job, i.required_faction, i.minimum_level, i.rarity, i.acquisition_difficulty, i.drop_rate_modifier,
  case when i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool') then public.world_item_hq_traits(i.equipment_traits) else i.equipment_traits end,
  i.crafting_specialization, i.tradeable, ceil(coalesce(i.reference_price, 0) * 1.3), i.stack_size, i.item_id, 1
  from public.world_item_catalog i
 where i.base_item_id is null
   and exists (select 1 from public.world_crafting_recipes r where r.output_item = i.item_id)
   and (i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
        or (i.category = 'consumable' and i.item_id not in ('ammo_arrow', 'ammo_bolt', 'ammo_dart', 'treat_fish', 'travel_ration')))
on conflict (item_id) do nothing;
-- 우수품 장비의 계열도 기본 물품을 따른다(world_gear_line이 base로 찾음)
insert into public.world_item_lore(item_id, lore)
select h.item_id, l.lore from public.world_item_catalog h join public.world_item_lore l on l.item_id = h.base_item_id
 where h.base_item_id is not null on conflict do nothing;
drop trigger if exists trg_world_item_hq_sync on public.world_item_catalog;
create trigger trg_world_item_hq_sync after update on public.world_item_catalog for each row execute function public.world_item_hq_sync();


-- ── 기술 칭호 32 ──────────────────────────────────────────────────────────

insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_smithing_15', '쇠를 아는 손', 'hammer', '쇳물의 빛깔로 온도를 읽는다.', '단조 기술 15단계', '{"cq_smithing": 3, "cs_smithing": 1}'::jsonb, true, false, '{"skill": "smithing", "n": 15}'::jsonb, 300, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_smithing_35', '백련강의 대장장이', 'hammer', '백 번을 접어 두드린 쇠는 휘지 않는다.', '단조 기술 35단계', '{"cq_smithing": 4, "cs_smithing": 2}'::jsonb, true, false, '{"skill": "smithing", "n": 35}'::jsonb, 301, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_smithing_50', '천하제일 야장', 'hammer', '이 손이 두드린 쇠는 이름을 얻는다.', '단조 기술 50단계', '{"cq_smithing": 6, "cx_smithing": 3, "cs_smithing": 2}'::jsonb, true, false, '{"skill": "smithing", "n": 50}'::jsonb, 302, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_carpentry_15', '결을 읽는 목수', 'hammer', '나뭇결을 거스르지 않는다.', '목공 기술 15단계', '{"cq_carpentry": 3, "cs_carpentry": 1}'::jsonb, true, false, '{"skill": "carpentry", "n": 15}'::jsonb, 303, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_carpentry_35', '도편수', 'hammer', '못 하나 없이 집을 세운다.', '목공 기술 35단계', '{"cq_carpentry": 4, "cs_carpentry": 2}'::jsonb, true, false, '{"skill": "carpentry", "n": 35}'::jsonb, 304, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_carpentry_50', '천년 목심의 주인', 'hammer', '천 년 묵은 나무도 이 손에서 다시 산다.', '목공 기술 50단계', '{"cq_carpentry": 6, "cx_carpentry": 3, "cs_carpentry": 2}'::jsonb, true, false, '{"skill": "carpentry", "n": 50}'::jsonb, 305, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_artifice_15', '영문 새기는 장인', 'hammer', '방울 하나에도 영문을 새긴다.', '법구 공예 기술 15단계', '{"cq_artifice": 3, "cs_artifice": 1}'::jsonb, true, false, '{"skill": "artifice", "n": 15}'::jsonb, 306, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_artifice_35', '혼천의 설계자', 'hammer', '하늘의 길을 법구에 옮긴다.', '법구 공예 기술 35단계', '{"cq_artifice": 4, "cs_artifice": 2}'::jsonb, true, false, '{"skill": "artifice", "n": 35}'::jsonb, 307, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_artifice_50', '신기를 빚는 자', 'hammer', '만든 법구가 스스로 운다.', '법구 공예 기술 50단계', '{"cq_artifice": 6, "cx_artifice": 3, "cs_artifice": 2}'::jsonb, true, false, '{"skill": "artifice", "n": 50}'::jsonb, 308, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_weaving_15', '고운 결 짓는 이', 'hammer', '씨실과 날실이 어긋나지 않는다.', '직조 기술 15단계', '{"cq_weaving": 3, "cs_weaving": 1}'::jsonb, true, false, '{"skill": "weaving", "n": 15}'::jsonb, 309, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_weaving_35', '비단 명장', 'hammer', '비단 한 필이 한 해 농사 값이다.', '직조 기술 35단계', '{"cq_weaving": 4, "cs_weaving": 2}'::jsonb, true, false, '{"skill": "weaving", "n": 35}'::jsonb, 310, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_weaving_50', '하늘 옷을 지은 자', 'hammer', '바늘땀이 보이지 않는 옷을 짓는다.', '직조 기술 50단계', '{"cq_weaving": 6, "cx_weaving": 3, "cs_weaving": 2}'::jsonb, true, false, '{"skill": "weaving", "n": 50}'::jsonb, 311, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_leatherwork_15', '가죽 다루는 손', 'hammer', '가죽이 손에서 부드러워진다.', '가죽 공예 기술 15단계', '{"cq_leatherwork": 3, "cs_leatherwork": 1}'::jsonb, true, false, '{"skill": "leatherwork", "n": 15}'::jsonb, 312, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_leatherwork_35', '경갑 명장', 'hammer', '가벼운 경갑이 쇠보다 질기다.', '가죽 공예 기술 35단계', '{"cq_leatherwork": 4, "cs_leatherwork": 2}'::jsonb, true, false, '{"skill": "leatherwork", "n": 35}'::jsonb, 313, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_leatherwork_50', '야행 갖바치', 'hammer', '야행국의 발은 모두 이 손을 거쳤다.', '가죽 공예 기술 50단계', '{"cq_leatherwork": 6, "cx_leatherwork": 3, "cs_leatherwork": 2}'::jsonb, true, false, '{"skill": "leatherwork", "n": 50}'::jsonb, 314, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_wardcraft_15', '부적 그리는 이', 'hammer', '획 하나 떨리지 않는 부적.', '봉인 공예 기술 15단계', '{"cq_wardcraft": 3, "cs_wardcraft": 1}'::jsonb, true, false, '{"skill": "wardcraft", "n": 15}'::jsonb, 315, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_wardcraft_35', '결계 설계자', 'hammer', '결계의 줄기를 미리 그린다.', '봉인 공예 기술 35단계', '{"cq_wardcraft": 4, "cs_wardcraft": 2}'::jsonb, true, false, '{"skill": "wardcraft", "n": 35}'::jsonb, 316, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_wardcraft_50', '만법을 새긴 자', 'hammer', '먹 한 방울에 만 가지 법이 담긴다.', '봉인 공예 기술 50단계', '{"cq_wardcraft": 6, "cx_wardcraft": 3, "cs_wardcraft": 2}'::jsonb, true, false, '{"skill": "wardcraft", "n": 50}'::jsonb, 317, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_alchemy_15', '달이는 손', 'hammer', '약탕관의 불을 끄지 않는다.', '연금 기술 15단계', '{"cq_alchemy": 3, "cs_alchemy": 1}'::jsonb, true, false, '{"skill": "alchemy", "n": 15}'::jsonb, 318, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_alchemy_35', '연단의 대가', 'hammer', '아홉 번 달여 한 알을 빚는다.', '연금 기술 35단계', '{"cq_alchemy": 4, "cs_alchemy": 2}'::jsonb, true, false, '{"skill": "alchemy", "n": 35}'::jsonb, 319, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_alchemy_50', '금단을 빚은 자', 'hammer', '금빛 단약이 이 손에서 났다.', '연금 기술 50단계', '{"cq_alchemy": 6, "cx_alchemy": 3, "cs_alchemy": 2}'::jsonb, true, false, '{"skill": "alchemy", "n": 50}'::jsonb, 320, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_cooking_15', '간 보는 손', 'hammer', '간을 보면 사람을 안다.', '요리 기술 15단계', '{"cq_cooking": 3, "cs_cooking": 1}'::jsonb, true, false, '{"skill": "cooking", "n": 15}'::jsonb, 321, '제작', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_cooking_35', '수라간 숙수', 'hammer', '수라간에 서도 부끄럽지 않다.', '요리 기술 35단계', '{"cq_cooking": 4, "cs_cooking": 2, "food_dur_pct": 5}'::jsonb, true, false, '{"skill": "cooking", "n": 35}'::jsonb, 322, '제작', 3) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_cooking_50', '팔도 밥상의 주인', 'hammer', '팔도의 밥상이 이 솥에서 났다.', '요리 기술 50단계', '{"cq_cooking": 6, "cx_cooking": 3, "cs_cooking": 2, "food_dur_pct": 10}'::jsonb, true, false, '{"skill": "cooking", "n": 50}'::jsonb, 323, '제작', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_foraging_25', '산야를 아는 손', 'leaf', '산과 들이 내어 줄 때를 안다.', '채집 기술 25단계', '{"gq_foraging": 3, "gr_foraging": 1}'::jsonb, true, false, '{"skill": "foraging", "n": 25}'::jsonb, 324, '채집', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_foraging_50', '산천을 거둔 자', 'leaf', '거둔 것이 산을 이룬다.', '채집 기술 50단계', '{"gq_foraging": 6, "gr_foraging": 3}'::jsonb, true, false, '{"skill": "foraging", "n": 50}'::jsonb, 325, '채집', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_mining_25', '맥을 짚는 광부', 'leaf', '돌 속의 맥을 손끝으로 짚는다.', '채광 기술 25단계', '{"gq_mining": 3, "gr_mining": 1}'::jsonb, true, false, '{"skill": "mining", "n": 25}'::jsonb, 326, '채집', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_mining_50', '지맥의 주인', 'leaf', '땅의 맥이 길을 내어 준다.', '채광 기술 50단계', '{"gq_mining": 6, "gr_mining": 3}'::jsonb, true, false, '{"skill": "mining", "n": 50}'::jsonb, 327, '채집', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_fishing_25', '찌를 읽는 낚시꾼', 'leaf', '찌가 움직이기 전에 안다.', '낚시 기술 25단계', '{"fish_bite_pct": 3, "fish_rare_pct": 2}'::jsonb, true, false, '{"skill": "fishing", "n": 25}'::jsonb, 328, '채집', 2) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_fishing_50', '용왕의 벗', 'leaf', '용왕이 벗이라 부른다.', '낚시 기술 50단계', '{"fish_rare_pct": 6, "fish_size_pct": 4, "fish_bite_pct": 3}'::jsonb, true, false, '{"skill": "fishing", "n": 50}'::jsonb, 329, '채집', 4) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('ct_all_50', '만공(萬工)의 주인', 'spark', '여덟 갈래 손재주를 끝까지 닦았다.', '제작 여덟 계열(단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리) 모두 50단계', '{"craft_quality": 6, "cs_all": 3, "cx_all": 2}'::jsonb, true, false, '{"skill_all": ["smithing", "carpentry", "artifice", "wardcraft", "weaving", "leatherwork", "alchemy", "cooking"], "n": 50}'::jsonb, 330, '성장', 5) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values ('gt_all_50', '천지를 거둔 자', 'spark', '산과 땅과 물을 모두 거두었다.', '채집·채광·낚시 모두 50단계', '{"gather_qty_pct": 6, "rare_loot_pct": 3, "fish_bite_pct": 4}'::jsonb, true, false, '{"skill_all": ["foraging", "mining", "fishing"], "n": 50}'::jsonb, 331, '성장', 5) on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text, bonus = excluded.bonus, rule = excluded.rule, category = excluded.category, grade = excluded.grade;
update public.world_title_catalog set rule = '{"titles": 23}'::jsonb, condition_text = '칭호 23개 획득' where title_key = 'title_collector';
update public.world_title_catalog set rule = '{"titles": 69}'::jsonb, condition_text = '칭호 69개 획득' where title_key = 'title_master';
-- ── 기존 함수 고치기(7.5.0, 앵커 바꾸기) ─────────────────────────────────────

-- 기록 트리거: 채집 기술 경험은 채집(foraging)·채광(mining), 제작은 그 제작법 분야 계열(요리 포함)
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$when k = 'gather' and coalesce(p ->> 'node', '') = 'herb' then 'herbalism'$o$,
  $n$when k = 'gather' and p ? 'line' then p ->> 'line'$n$);
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$when k = 'gather' and coalesce(p ->> 'node', '') = 'shrine' then 'spirit_gathering'$o$,
  $n$when k = 'gather' and coalesce(p ->> 'category', '') = 'relics' then 'mining'$n$);
select pg_temp.yh_patch('public.world_event_char_apply()',
  $o$select coalesce(required_skill, case craft_field when 'sealing' then 'wardcraft' when 'alchemy' then 'alchemy' when 'cooking' then '-' else 'smithing' end)$o$,
  $n$select public.world_craft_line_of(craft_field)$n$);

-- 물품 쓰기: 우수품(<id>_hq)은 기본 물품과 같은 효과에 회복 ×1.15(올림)·붙는 기운 지속 ×1.2
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$cures text[] := '{}'; cleared int := 0;$o$,
  $n$cures text[] := '{}'; v_base text := public.world_item_base(p_item_id); v_hq numeric := case when p_item_id like '%\_hq' then 1.15 else 1 end; v_dur numeric := 1; v_meal numeric := 1; cleared int := 0;$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id <> 'revival_charm' THEN$o$, $n$IF v_base <> 'revival_charm' THEN$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$UPDATE public.world_characters SET inventory = inv, health = 50, mental = least(100, mental + 20), spiritual_power = least(100, spiritual_power + 15),$o$,
  $n$UPDATE public.world_characters SET inventory = inv, health = ceil(50 * v_hq)::int, mental = least(100, mental + ceil(20 * v_hq)::int), spiritual_power = least(100, spiritual_power + ceil(15 * v_hq)::int),$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$'회생 부적이 타올라 다시 일어섰습니다. 체력 50')$o$, $n$'회생 부적이 타올라 다시 일어섰습니다. 체력 ' || ceil(50 * v_hq)::int)$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id = 'revival_charm' THEN RAISE EXCEPTION$o$, $n$IF v_base = 'revival_charm' THEN RAISE EXCEPTION$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$AND i.tradeable AND i.item_id !~ '^exg_'$o$, $n$AND i.tradeable AND i.item_id !~ '^exg_' AND i.base_item_id IS NULL$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$IF p_item_id NOT IN ('tonic', 'herbal_extract',$o$, $n$IF v_base NOT IN ('tonic', 'herbal_extract',$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$CASE p_item_id$o$, $n$CASE v_base$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$hp := round(hp * mul); mn := round(mn * mul); spg := round(spg * mul);$o$,
  $n$hp := round(ceil(hp * v_hq) * mul); mn := round(ceil(mn * v_hq) * mul); spg := round(ceil(spg * v_hq) * mul); er := ceil(er * v_hq)::int;
  v_dur := case when v_hq > 1 then 1.2 else 1 end;
  -- 든든한 한 끼(요리 43b)·칭호 food_dur_pct: 내가 먹은 음식 기운이 더 오래 간다
  v_meal := (case when 'cooking_c43b' = any (public.world_skill_procs(uid)) then 1.5 else 1 end) * (1 + public.world_title_bonus('food_dur_pct') / 100.0);$n$);
select pg_temp.yh_patch('public.world_use_item(text)',
  $o$make_interval(mins => (SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff))$o$,
  $n$make_interval(mins => ceil((SELECT duration_minutes FROM public.world_status_catalog WHERE status_key = buff) * v_dur * (CASE WHEN buff IN ('well_fed', 'warm_belly', 'vigor', 'sea_luck') THEN v_meal ELSE 1 END))::int)$n$, 2);

-- 현장 토벌 물품
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF it NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea',$o$,
  $n$IF public.world_item_base(it) NOT IN ('tonic', 'herbal_extract', 'herb', 'ward_talisman', 'spirit_tea',$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$IF it IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN$o$,
  $n$IF public.world_item_base(it) IN ('spirit_tea', 'clear_spirit_pill', 'spirit_qi_pill', 'moonlight_essence', 'heavenly_dew') THEN$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$heal := CASE it WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END;$o$,
  $n$heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'spirit_tea' THEN 10 WHEN 'clear_spirit_pill' THEN 20 WHEN 'spirit_qi_pill' THEN 35 WHEN 'moonlight_essence' THEN 55 ELSE 80 END)::int;$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$ELSIF it = 'ward_talisman' THEN$o$, $n$ELSIF public.world_item_base(it) = 'ward_talisman' THEN$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$mn := least(100, mn + 8);$o$, $n$mn := least(100, mn + ceil(8 * (CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END))::int);$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$heal := CASE it WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100$o$,
  $n$heal := ceil((CASE WHEN it LIKE '%\_hq' THEN 1.15 ELSE 1 END) * CASE public.world_item_base(it) WHEN 'tonic' THEN 35 WHEN 'herbal_extract' THEN 22 WHEN 'rejuv_pill' THEN 60 WHEN 'grand_pill' THEN 100$n$);
select pg_temp.yh_patch('public.world_battle_action(text,text)',
  $o$ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END;$o$,
  $n$ELSE CASE WHEN 'combo_first_aid_herbalism' = ANY (sk) THEN 22 ELSE 12 END END)::int;$n$);

-- 동료 돌보기
select pg_temp.yh_patch('public.world_party_use_item(uuid,text)',
  $o$case p_item_id$o$, $n$case public.world_item_base(p_item_id)$n$);
select pg_temp.yh_patch('public.world_party_use_item(uuid,text)',
  $o$hp := round(hp * mul); mn := round(mn * mul);$o$,
  $n$hp := round(ceil(hp * (case when p_item_id like '%\_hq' then 1.15 else 1 end)) * mul); mn := round(ceil(mn * (case when p_item_id like '%\_hq' then 1.15 else 1 end)) * mul); er := ceil(er * (case when p_item_id like '%\_hq' then 1.15 else 1 end))::int;$n$);

-- 귀허의 주인·비무회 회복품
select pg_temp.yh_patch('public.world_gw_act(uuid,text,uuid,text)',
  $o$coalesce(p_item, '') not in ('tonic',$o$, $n$public.world_item_base(coalesce(p_item, '')) not in ('tonic',$n$);
select pg_temp.yh_patch('public.world_gw_resolve(uuid)',
  $o$hv := case a ->> 'i' when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end$o$,
  $n$hv := ceil((case when a ->> 'i' like '%\_hq' then 1.15 else 1 end) * case public.world_item_base(a ->> 'i') when 'tonic' then 35 when 'herbal_extract' then 22 when 'rejuv_pill' then 60 when 'grand_pill' then 100 when 'banyo_salve' then 70 else 0 end)$n$);
select pg_temp.yh_patch('public.world_tourney_tactic(text,text,text[],text)',
  $o$x <> all (ok_items)$o$, $n$public.world_item_base(x) <> all (ok_items)$n$);
select pg_temp.yh_patch('public.world_tourney_duel(uuid,uuid,uuid)',
  $o$heal := round(mx[i] * case it when 'grand_pill'$o$,
  $n$heal := round(mx[i] * (case when it like '%\_hq' then 1.15 else 1 end) * case public.world_item_base(it) when 'grand_pill'$n$);

-- 원정 보급품: 기본 + 우수품을 함께 세고 우수품을 먼저 챙겨 먼저 쓴다
select pg_temp.yh_patch('public.world_expedition_start(uuid,integer,text)',
  $o$q := least(20, coalesce((inv ->> k)::int, 0),$o$, $n$q := least(20, coalesce((inv ->> k)::int, 0) + coalesce((inv ->> (k || '_hq'))::int, 0),$n$);
select pg_temp.yh_patch('public.world_expedition_start(uuid,integer,text)',
  $o$IF q > 0 THEN sup := sup || jsonb_build_object(k, q); inv := public.world_inv_add(inv, k, -q); END IF;$o$,
  $n$IF q > 0 AND coalesce((inv ->> (k || '_hq'))::int, 0) > 0 THEN
      sup := sup || jsonb_build_object(k || '_hq', least(q, (inv ->> (k || '_hq'))::int));
      inv := public.world_inv_add(inv, k || '_hq', -least(q, (inv ->> (k || '_hq'))::int));
      q := q - (sup ->> (k || '_hq'))::int;
    END IF;
    IF q > 0 THEN sup := sup || jsonb_build_object(k, q); inv := public.world_inv_add(inv, k, -q); END IF;$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$if er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then$o$,
  $n$if er >= 50 and coalesce((sup ->> 'ward_talisman_hq')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman_hq}', to_jsonb((sup ->> 'ward_talisman_hq')::int - 1)); er := er - 18; mn := mn + 6;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적 (우수)을 태웠습니다. 침식 -18 · 정신 +6');
    elsif er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$item := case when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'$o$,
  $n$item := case when coalesce((sup ->> 'tonic_hq')::int, 0) > 0 then 'tonic_hq' when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic'
                   when coalesce((sup ->> 'herbal_extract_hq')::int, 0) > 0 then 'herbal_extract_hq' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$heal := case item when 'tonic' then 35 when 'herbal_extract' then 22 else 12 end;$o$,
  $n$heal := case item when 'tonic' then 35 when 'tonic_hq' then 41 when 'herbal_extract' then 22 when 'herbal_extract_hq' then 26 else 12 end;$n$);
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$if coalesce((sup ->> 'revival_charm')::int, 0) > 0 then$o$,
  $n$if coalesce((sup ->> 'revival_charm_hq')::int, 0) > 0 then
        sup := jsonb_set(sup, '{revival_charm_hq}', to_jsonb((sup ->> 'revival_charm_hq')::int - 1)); hp := 35;
        lg := lg || jsonb_build_array('쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '쓰러지기 직전 회생 부적 (우수)이 타올라 몸을 일으켰습니다. 체력 35');
      elsif coalesce((sup ->> 'revival_charm')::int, 0) > 0 then$n$);
-- 원정 채집 몫에 채집 계열 기본 기술 채집량
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 20;$o$,
  $n$qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 20;
        qty := floor(qty * (1 + least(30, public.world_line_base(c.skill_progress, 'foraging', 'gather_qty_pct')) / 100.0) + random())::int;$n$);

-- 납품(퀘스트 넘김·의뢰): 우수품도 받고 기본을 먼저 가져간다
select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$have := coalesce((c.inventory ->> k)::int, 0);$o$, $n$have := coalesce((c.inventory ->> k)::int, 0) + coalesce((c.inventory ->> (k || '_hq'))::int, 0);$n$);
select pg_temp.yh_patch('public.world_quest_report(text)',
  $o$  for k, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;
    if coalesce((inv ->> k)::int, 0) - v < (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = k) then
      raise exception '장착 중인 물품은 넘길 수 없습니다.'; end if;
    inv := public.world_inv_add(inv, k, -v);
    if (inv ->> k)::int <= 0 then inv := inv - k; end if;
    msg := msg || '넘김: ' || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || v || ' · ';
  end loop;$o$,
  $n$  for a, v in select key, value::int from jsonb_each_text(coalesce(s.need -> 'give', '{}'::jsonb)) loop
   -- 기본 물품 먼저, 모자란 만큼 우수품(7.5.0)
   for k, lim in select x.k, x.q from (select a as k, least(v, greatest(0, coalesce((inv ->> a)::int, 0))) as q, 0 as o
                                        union all select a || '_hq', v - least(v, greatest(0, coalesce((inv ->> a)::int, 0))), 1) x where x.q > 0 order by x.o loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = k) then raise exception '잠근 물품은 넘길 수 없습니다. 잠금을 푼 뒤 다시 보고하세요.'; end if;
    if coalesce((inv ->> k)::int, 0) - lim < (select count(*) from public.world_character_equipment e where e.owner_id = uid and e.item_id = k) then
      raise exception '장착 중인 물품은 넘길 수 없습니다.'; end if;
    if coalesce((inv ->> k)::int, 0) < lim then raise exception '넘길 물품이 모자랍니다.'; end if;
    inv := public.world_inv_add(inv, k, -lim);
    if (inv ->> k)::int <= 0 then inv := inv - k; end if;
    msg := msg || '넘김: ' || (select item_name from public.world_item_catalog where item_id = k) || ' ×' || lim || ' · ';
   end loop;
  end loop;
  lim := null;$n$);
select pg_temp.yh_patch('public.world_commission_claim(integer)',
  $o$IF coalesce((inv ->> m.target_item)::int, 0) < m.need THEN RAISE EXCEPTION '납품할 물품이 모자랍니다.'; END IF;$o$,
  $n$IF coalesce((inv ->> m.target_item)::int, 0) + coalesce((inv ->> (m.target_item || '_hq'))::int, 0) < m.need THEN RAISE EXCEPTION '납품할 물품이 모자랍니다.'; END IF;$n$);
-- (이 함수는 줄 끝이 CRLF라 한 줄 앵커로) 기본을 먼저, 모자란 만큼 우수품
select pg_temp.yh_patch('public.world_commission_claim(integer)',
  $o$inv := public.world_inv_add(inv, m.target_item, -m.need);$o$,
  $n$inv := CASE WHEN coalesce((inv ->> m.target_item)::int, 0) >= m.need THEN public.world_inv_add(inv, m.target_item, -m.need)
      ELSE public.world_inv_add(public.world_inv_add(inv, m.target_item || '_hq', -(m.need - greatest(0, coalesce((inv ->> m.target_item)::int, 0)))), m.target_item, -greatest(0, coalesce((inv ->> m.target_item)::int, 0))) END;$n$);
select pg_temp.yh_patch('public.world_commission_board()',
  $o$least(m.need, coalesce((c.inventory ->> m.target_item)::int, 0))$o$,
  $n$least(m.need, coalesce((c.inventory ->> m.target_item)::int, 0) + coalesce((c.inventory ->> (m.target_item || '_hq'))::int, 0))$n$);

-- 칭호 규칙 'skill' {skill, n}·'skill_all' {skill_all:[…], n}
select pg_temp.yh_patch('public.world_title_rule_ok(uuid,jsonb)',
  $o$ELSIF p_rule ? 'survey_full' THEN$o$,
  $n$ELSIF p_rule ? 'skill' THEN
    SELECT coalesce((ch.skill_progress -> (p_rule ->> 'skill') ->> 'rank')::int, 1) INTO v FROM public.world_characters ch WHERE ch.owner_id = p_owner;
    RETURN coalesce(v, 0) >= n;
  ELSIF p_rule ? 'skill_all' THEN
    SELECT count(*) INTO v FROM public.world_characters ch, jsonb_array_elements_text(p_rule -> 'skill_all') s(k)
     WHERE ch.owner_id = p_owner AND coalesce((ch.skill_progress -> s.k ->> 'rank')::int, 1) >= n;
    RETURN v >= jsonb_array_length(p_rule -> 'skill_all');
  ELSIF p_rule ? 'survey_full' THEN$n$);
select pg_temp.yh_patch('public.world_title_rule_progress(uuid,jsonb)',
  $o$elsif p_rule ? 'survey_full' then$o$,
  $n$elsif p_rule ? 'skill' then
    select coalesce((ch.skill_progress -> (p_rule ->> 'skill') ->> 'rank')::int, 1) into v from public.world_characters ch where ch.owner_id = p_owner;
  elsif p_rule ? 'skill_all' then
    select count(*) into v from public.world_characters ch, jsonb_array_elements_text(p_rule -> 'skill_all') s(k)
     where ch.owner_id = p_owner and coalesce((ch.skill_progress -> s.k ->> 'rank')::int, 1) >= n;
    n := jsonb_array_length(p_rule -> 'skill_all');
  elsif p_rule ? 'survey_full' then$n$);
select pg_temp.yh_patch('public.world_title_award_check(uuid,text)',
  $o$    IF public.world_title_rule_ok(p_owner_id, r) THEN$o$,
  $n$    IF (r ? 'skill' OR r ? 'skill_all') AND p_event_type IS NOT NULL AND p_event_type NOT IN ('craft', 'dismantle', 'gather', 'fish', 'idle', 'skill') THEN CONTINUE; END IF;
    IF public.world_title_rule_ok(p_owner_id, r) THEN$n$);
-- 자율 정비를 받으면 기술 칭호를 판정한다
select pg_temp.yh_patch('public.world_claim_idle_activity()',
  $o$update public.world_idle_activities set status='claimed'$o$,
  $n$perform public.world_title_award_check(public.fn_owner_auth_uid(), 'idle');
  update public.world_idle_activities set status='claimed'$n$);

-- 조사 계열 36단계 「영초 감별」: 위험도 7 이상 지역의 탐색·조사 지점 살피기에서 0.2% 귀령초(world_gwiryeong_reserve 거침)
select pg_temp.yh_patch('public.world_field_search()',
  $o$  -- 침식: 위험한 곳·삼경·어두운 곳에서 쌓이고$o$,
  $n$  IF 'tracking_x36' = ANY (sk) AND coalesce(r.danger_level, 0) >= 7 AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking') THEN
    inv := public.world_inv_add(coalesce(inv, c.inventory, '{}'::jsonb), 'gwiryeong_cho', 1); txt := txt || ' 「영초 감별」 귀령초를 찾았다.'; payload := payload || jsonb_build_object('gwiryeong', 1);
  END IF;
  -- 침식: 위험한 곳·삼경·어두운 곳에서 쌓이고$n$);
select pg_temp.yh_patch('public.world_region_site_explore(text)',
  $o$ UPDATE public.world_characters SET inventory=inv,updated_at=now() WHERE owner_id=uid RETURNING * INTO c;$o$,
  $n$ IF 'tracking_x36' = ANY (public.world_skill_procs(uid)) AND coalesce(r.danger_level, 0) >= 7 AND random() < 0.002 AND public.world_gwiryeong_reserve(uid, 'skill_tracking') THEN
  inv := public.world_inv_add(inv, 'gwiryeong_cho', 1); result_text := result_text || ' 「영초 감별」 귀령초를 찾았다.';
 END IF;
 UPDATE public.world_characters SET inventory=inv,updated_at=now() WHERE owner_id=uid RETURNING * INTO c;$n$);

-- 무기 강화: 일품 단조(근접)·백보천양(원거리)·법륜 단련(술법)
select pg_temp.yh_patch('public.world_weapon_enhance()',
  $o$case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end$o$,
  $n$case when (case coalesce(it.equipment_traits ->> 'weapon_type', 'melee') when 'ranged' then 'carpentry_c43a' when 'magic' then 'artifice_c43a' else 'smithing_c43a' end) = any (public.world_skill_procs(uid)) then 10 else 0 end$n$);
select pg_temp.yh_patch('public.world_enhance_quote()',
  $o$case when 'smithing_c43a' = any (public.world_skill_procs(uid)) then 10 else 0 end$o$,
  $n$case when (case coalesce(it.equipment_traits ->> 'weapon_type', 'melee') when 'ranged' then 'carpentry_c43a' when 'magic' then 'artifice_c43a' else 'smithing_c43a' end) = any (public.world_skill_procs(uid)) then 10 else 0 end$n$);

-- 수리: 수리 도구 우수품 60%, 24b 「현장 수리」 등은 그 계열이 만든 장비만 전부, 대장간 단골(단조 43b)은 단조 장비만 반값
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$mx int; cur int; nxt int; cost int := 0; inv jsonb; msg text;$o$,
  $n$mx int; cur int; nxt int; cost int := 0; inv jsonb; msg text; kit text; gl text; full_fix boolean;$n$);
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$    IF coalesce((inv ->> 'repair_kit')::int, 0) < 1 THEN RAISE EXCEPTION '장비 수리 도구가 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; END IF;
    inv := public.world_inv_add(inv, 'repair_kit', -1);
    nxt := CASE WHEN 'smithing_c24b' = ANY (public.world_skill_procs(uid)) THEN mx ELSE least(mx, cur + ceil(mx * 0.5)::int) END;$o$,
  $n$    IF coalesce((inv ->> 'repair_kit')::int, 0) + coalesce((inv ->> 'repair_kit_hq')::int, 0) < 1 THEN RAISE EXCEPTION '장비 수리 도구가 없습니다. 안전지대 상점에서 사거나 만들 수 있습니다.'; END IF;
    gl := public.world_gear_line(p_item_id);
    full_fix := gl IN ('smithing', 'artifice', 'weaving', 'leatherwork') AND (gl || '_c24b') = ANY (public.world_skill_procs(uid));
    -- 전부 되살리는 기술이 있으면 보통 도구 먼저, 아니면 우수품(60%) 먼저
    kit := CASE WHEN full_fix THEN CASE WHEN coalesce((inv ->> 'repair_kit')::int, 0) > 0 THEN 'repair_kit' ELSE 'repair_kit_hq' END
                ELSE CASE WHEN coalesce((inv ->> 'repair_kit_hq')::int, 0) > 0 THEN 'repair_kit_hq' ELSE 'repair_kit' END END;
    inv := public.world_inv_add(inv, kit, -1);
    nxt := CASE WHEN full_fix THEN mx ELSE least(mx, cur + ceil(mx * CASE WHEN kit = 'repair_kit_hq' THEN 0.6 ELSE 0.5 END)::int) END;$n$);
select pg_temp.yh_patch('public.world_equipment_repair(text,text)',
  $o$IF 'smithing_c43b' = ANY (public.world_skill_procs(uid)) THEN cost := greatest(2, cost / 2); END IF;$o$,
  $n$IF 'smithing_c43b' = ANY (public.world_skill_procs(uid)) AND public.world_gear_line(p_item_id) = 'smithing' THEN cost := greatest(2, cost / 2); END IF;$n$);
select pg_temp.yh_patch('public.world_repair_quote()',
  $o$equipped, me.half$o$, $n$equipped, (me.half and public.world_gear_line(i.item_id) = 'smithing') as half$n$);

-- 얻는 곳: 우수품은 기본 물품의 제작법(품질 85 이상)
select pg_temp.yh_patch('public.world_item_sources(text)',
  $o$'craft', exists (select 1 from public.world_crafting_recipes where output_item = p_item),$o$,
  $n$'craft', exists (select 1 from public.world_crafting_recipes where output_item = public.world_item_base(p_item)), 'hq', p_item like '%\_hq',$n$);


-- ── 새 도우미 권한: 조사원이 직접 부를 필요는 없다. 값만 셈하는 순수 함수 셋은 부른 쪽 권한 함수에서도 쓰이게 authenticated에 남긴다 ──
do $g$
declare f text; r text;
begin
  foreach f in array array['public.world_craft_line(text)', 'public.world_line_base(jsonb,text,text)', 'public.world_gear_line(text)',
                           'public.world_item_hq_traits(jsonb)', 'public.world_item_hq_note(text,text)', 'public.world_item_hq_sync()',
                           'public.world_item_base(text)', 'public.world_craft_line_of(text)', 'public.world_line_name(text)', 'public.world_skill_name(text)'] loop
    execute format('revoke all on function %s from public, anon, authenticated', f);
    execute format('grant execute on function %s to postgres, service_role', f);
    for r in select rolname from pg_roles where rolname like 'fn_owner%' loop
      execute format('grant execute on function %s to %I', f, r);
    end loop;
  end loop;
  foreach f in array array['public.world_item_base(text)', 'public.world_craft_line_of(text)', 'public.world_line_name(text)'] loop
    execute format('grant execute on function %s to authenticated', f);
  end loop;
end $g$;


-- ── 쌓은 경험 이주·생활 전문화 정리·택일 무료 다시 고르기·칭호 판정(한 번만) ──────────────
do $m$
declare ch record; sp jsonb; relic int; fishn int; f int; h int; sg int; mi int; nprof_c text; nprof_g text; note text; fr text[];
  cnt jsonb; ln text; nx int; got text;
begin
  if exists (select 1 from public.world_app_meta where key = 'skills_750_migrated') then return; end if;
  perform set_config('yh.rank_sync', 'all', true);

  -- 합쳐지는 채집 계열의 택일은 채집의 같은 칸이 비었을 때만 옮긴다
  update public.world_skill_picks pk set picks = pk.picks || coalesce((
      select jsonb_object_agg('foraging:' || split_part(e.key, ':', 2), e.value) from jsonb_each(pk.picks) e
       where e.key ~ '^(herbalism|spirit_gathering):(24|43)$' and not pk.picks ? ('foraging:' || split_part(e.key, ':', 2))), '{}'::jsonb),
    updated_at = now()
   where pk.picks ?| array['herbalism:24', 'herbalism:43', 'spirit_gathering:24', 'spirit_gathering:43'];
  -- 효과가 바뀐 택일 칸은 한 번 무료로 다시 고른다(기한 없음, 롤백 때 함께 사라짐)
  update public.world_skill_picks pk set free_repick = array(select e.key from jsonb_each(pk.picks) e where e.key ~ '^(smithing|wardcraft|alchemy|foraging):(24|43)$' order by e.key)
   where exists (select 1 from jsonb_each(pk.picks) e where e.key ~ '^(smithing|wardcraft|alchemy|foraging):(24|43)$');

  for ch in select c.owner_id, c.skill_progress, c.cooking_xp, c.crafting_profession, c.gathering_profession from public.world_characters c loop
    sp := coalesce(ch.skill_progress, '{}'::jsonb);
    -- 새 제작 계열 넷 = 12 × 그 분야 제작 기록(단조 경험은 깎지 않음)
    select coalesce(jsonb_object_agg(x.fld, x.n), '{}'::jsonb) into cnt from (
      select r.craft_field fld, count(*)::int n from public.world_events e join public.world_crafting_recipes r on r.recipe_id = e.payload ->> 'recipe'
       where e.actor_id = ch.owner_id and e.event_type = 'craft' group by 1) x;
    foreach ln in array array['carpentry', 'artifice', 'weaving', 'leatherwork'] loop
      nx := 12 * coalesce((cnt ->> ln)::int, 0);
      if nx > coalesce((sp -> ln ->> 'xp')::int, 0) then sp := sp || jsonb_build_object(ln, coalesce(sp -> ln, '{}'::jsonb) || jsonb_build_object('xp', nx)); end if;
    end loop;
    -- 요리 계열 = 요리 숙련 경험(1:1)
    nx := coalesce(ch.cooking_xp, 0);
    if nx > coalesce((sp -> 'cooking' ->> 'xp')::int, 0) then sp := sp || jsonb_build_object('cooking', coalesce(sp -> 'cooking', '{}'::jsonb) || jsonb_build_object('xp', nx)); end if;
    -- 채집 = 일반 + 약초 + 영기 − 유물 몫(셋 가운데 가장 컸던 값 아래로는 내리지 않음) · 채광 = 광맥 + 8 × 유물 기록 · 낚시 = 8 × 낚시 기록
    select count(*) filter (where e.event_type = 'gather' and e.payload ->> 'category' = 'relics')::int, count(*) filter (where e.event_type = 'fish')::int
      into relic, fishn from public.world_events e where e.actor_id = ch.owner_id and e.event_type in ('gather', 'fish');
    f := coalesce((sp -> 'foraging' ->> 'xp')::int, 0); h := coalesce((sp -> 'herbalism' ->> 'xp')::int, 0);
    sg := coalesce((sp -> 'spirit_gathering' ->> 'xp')::int, 0); mi := coalesce((sp -> 'mining' ->> 'xp')::int, 0);
    sp := sp || jsonb_build_object('foraging', coalesce(sp -> 'foraging', '{}'::jsonb) || jsonb_build_object('xp', greatest(f, h, sg, f + h + sg - 8 * relic)));
    sp := sp || jsonb_build_object('mining', coalesce(sp -> 'mining', '{}'::jsonb) || jsonb_build_object('xp', mi + 8 * relic));
    if 8 * fishn > coalesce((sp -> 'fishing' ->> 'xp')::int, 0) then sp := sp || jsonb_build_object('fishing', coalesce(sp -> 'fishing', '{}'::jsonb) || jsonb_build_object('xp', 8 * fishn)); end if;
    -- 생활 전문화: 종합 제작 → 단조, 약초학·영기 채취 → 채집(바뀐 사람은 72시간 잠금 없이 바로 다시 고를 수 있게)
    nprof_c := case when ch.crafting_profession in ('smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking') then ch.crafting_profession else 'smithing' end;
    nprof_g := case when ch.gathering_profession in ('fieldwork', 'mining', 'fishing') then ch.gathering_profession else 'fieldwork' end;
    update public.world_characters set skill_progress = sp, crafting_profession = nprof_c, gathering_profession = nprof_g,
      life_changed_at = case when nprof_c is distinct from crafting_profession or nprof_g is distinct from gathering_profession then null else life_changed_at end,
      updated_at = now()
     where owner_id = ch.owner_id;
    -- 알림 한 번
    select free_repick into fr from public.world_skill_picks where owner_id = ch.owner_id;
    note := '제작은 단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리 여덟 계열, 채집은 채집·채광·낚시 세 계열로 나뉘었습니다. 지금까지 쌓은 경험을 옮겨 단계를 다시 매겼습니다. 캐릭터 › 기술에서 확인하세요.';
    if nprof_c is distinct from ch.crafting_profession then note := note || ' 종합 제작이 없어져 제작 분야가 단조로 정해졌습니다. 지금 한 번은 기다리지 않고 바로 바꿀 수 있습니다.';
    elsif nprof_g is distinct from ch.gathering_profession then note := note || ' 채집 분야가 「채집」으로 합쳐졌습니다. 지금 한 번은 기다리지 않고 바로 바꿀 수 있습니다.'; end if;
    if coalesce(cardinality(fr), 0) > 0 then note := note || ' 효과가 바뀐 택일 기술은 한 번 무료로 다시 고를 수 있습니다.'; end if;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (ch.owner_id, 'skill_rerank', '생산 기술이 바뀌었습니다(7.5.0)', note, jsonb_build_object('v', '7.5.0', 'free_repick', coalesce(to_jsonb(fr), '[]'::jsonb)));
  end loop;

  alter table public.world_characters add constraint world_characters_crafting_profession_chk
    check (crafting_profession is null or crafting_profession in ('smithing', 'carpentry', 'artifice', 'sealing', 'weaving', 'leatherwork', 'alchemy', 'cooking'));
  alter table public.world_characters add constraint world_characters_gathering_profession_chk
    check (gathering_profession is null or gathering_profession in ('fieldwork', 'mining', 'fishing'));

  -- 새 기술 칭호를 지금 단계로 한 번 판정하고, 이번에 생긴 칭호 알림은 한 사람에 한 번으로 묶는다
  for ch in select c.owner_id, c.character_name from public.world_characters c where not coalesce(c.is_dead, false) loop
    perform set_config('request.jwt.claim.sub', ch.owner_id::text, true);
    perform public.world_title_award_check(ch.owner_id, 'skill');
    select string_agg(n.content, ' ' order by n.id) into got from public.world_notifications n
     where n.user_id = ch.owner_id and n.kind = 'title' and n.created_at = now();
    if got is not null then
      delete from public.world_notifications n where n.user_id = ch.owner_id and n.kind = 'title' and n.created_at = now();
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (ch.owner_id, 'title', '기술 칭호를 얻었습니다', regexp_replace(got, ' · 캐릭터 › 칭호에서 장착할 수 있습니다\.', '', 'g') || ' · 캐릭터 › 칭호에서 장착할 수 있습니다.', '{}'::jsonb);
    end if;
  end loop;
  perform set_config('request.jwt.claim.sub', '', true);
  insert into public.world_app_meta(key, value) values ('skills_750_migrated', now()::text) on conflict (key) do nothing;
end $m$;


-- ── 패치노트 7.5.0 ─────────────────────────────────────────────────────────────
insert into public.world_patch_notes(note_id, title, body) values ('7.5.0', '7.5.0 생산 기술 개편 · 우수품', $N$
## 제작 기술: 분야마다 계열
- 제작 기술이 **단조·목공·법구 공예·봉인 공예·직조·가죽 공예·연금·요리** 여덟 계열로 나뉩니다. 그 분야 제작법을 만들 때 그 계열이 오르고, 계열 기술의 품질·덤 효과는 그 분야 제작에만 붙습니다.
- 「결계 각인」은 이름을 **봉인 공예**로 바꿨습니다. 요리 숙련은 요리 계열이 되었습니다(쌓은 요리 경험 그대로).
- 지금까지 쌓은 경험을 옮겨 단계를 다시 매겼습니다. 새 계열(목공·법구 공예·직조·가죽 공예)은 그 분야 제작 기록 한 번에 경험 12로 셌습니다.
- 제작 품질은 이제 쌓은 경험 총량이 아니라 **그 제작법 계열의 단계**를 따라 오릅니다.

## 채집 기술: 채집 · 채광 · 낚시
- 일반·약초·광맥·영기 채집 넷을 **채집**(약초·목재·보급품·물가·영기 채집터)·**채광**(광맥·유물 채집터)·**낚시** 셋으로 묶었습니다. 기본 기술의 채집량·희귀품은 그 계열 채집터에서만 붙습니다.
- 낚시도 한 번 던질 때마다(낚든 놓치든) 낚시 경험이 쌓이고, 낚시 계열 기술이 생겼습니다.

## 우수품
- 제작 품질이 **85 이상**이면 완성품이 「우수품」이 됩니다(30단계 추가 기술이 있으면 그 분야는 80부터). 품질은 이제 만드는 개수를 바꾸지 않습니다.
- 우수품 회복약·부적·요리는 회복량 +15%, 요리 기운은 20% 더 오래 갑니다. 우수품 장비는 수치 +5%·최대 내구도 +10%, 우수품 수리 도구는 내구도를 60% 되살립니다.
- 재료·가구·화살 같은 탄·노정 건량에는 우수품이 없습니다. 퀘스트·의뢰 납품에는 보통 물품을 먼저 가져가고, 원정에서는 우수품을 먼저 씁니다.
- 높은 계열 단계에서 그 분야를 전문으로 하는 사람이 만들 수 있게 맞췄습니다(계열 40단계 무렵부터 흔해집니다).

## 생산량
- 많이 쓰는 소모품·재료는 기본으로 만드는 개수를 늘렸습니다(예: 정화 부적 3, 노정 건량 5, 대부분의 요리 2, 청심환 2, 응축 영핵 3, 화살 70). 가구는 언제나 하나만 만듭니다.

## 분해
- 분해는 언제나 됩니다. 한 번에 그 장비 분야 계열 경험 12를 얻습니다.
- 그 계열 단계가 장비 단계 조건(1·3·6·9·12·15)보다 낮으면 재료는 돌려받지 못하고 경험만 얻습니다.

## 그 밖
- **생활 전문화**: 「종합 제작」을 없애고 제작 분야를 하나 고릅니다(정하지 않았으면 단조). 바뀐 분은 이번 한 번 기다리지 않고 바로 다시 고를 수 있습니다.
- 효과가 바뀐 택일 기술은 **한 번 무료로 다시 고를 수 있습니다**.
- 기술 칭호 32개: 제작 계열마다 15·35·50단계, 채집 계열마다 25·50단계, 모든 제작·모든 채집 50단계.
- 조합 기술을 채집·채광·낚시와 제작 계열을 잇는 것으로 고르게 맞췄습니다.
- 귀령초를 찾는 기술 「영초 감별」이 **탐사 36단계**로 옮겨 갔습니다(위험도 7 이상 지역 탐색·조사 지점).
- 제작 공구의 조건은 그 공구 분야 계열 단계로 봅니다.
- 무기 강화 기술은 근접(단조)·원거리(목공)·술법(법구 공예)로 나뉩니다.
- 무기·방어구 정보에 **어울리는 직업**을 적었습니다(이상혁 님 제보).
$N$)
on conflict (note_id) do update set title = excluded.title, body = excluded.body;


set local check_function_bodies = on;
do $v$ declare f oid; begin
  for f in select p.oid from pg_proc p join pg_language l on l.oid = p.prolang where p.pronamespace = 'public'::regnamespace and l.lanname = 'plpgsql' loop
    perform plpgsql_validator(f);
  end loop;
end $v$;

update public.world_app_meta set value = '20261104000000' where key = 'db_version';
