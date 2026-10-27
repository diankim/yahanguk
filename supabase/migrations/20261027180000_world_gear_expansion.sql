-- 장비 확장: 관모·신·노리개·호신부·탈 다섯 칸 + 같은 단계 안의 여러 갈래 장비 + 이목(요괴가 먼저 노리는 정도)
-- - 장착 칸: 무기·방어구·도구에 관모(hat)·신(shoes)·노리개(norigae)·호신부(amulet)·탈(mask)을 더한다. 장비 해제(world_unequip_item)를 새로 둔다.
-- - 내구도: 무기(공격)·방어구(맞을 때)·도구(채집)에 더해 관모(맞을 때)·신(이동할 때)만 닳는다. 노리개·호신부·탈은 닳지 않는다.
-- - 장비 특성의 합(world_gear_total)을 상태 효과 합계(world_status_effect_total)에 더해 채집·제작·이동·회복·침식·조우·전리품 등에 함께 적용하고,
--   전투 능력치(world_combat_stats)에는 방어력·회피·치명타·달아나기·이목을 더한다. 부서진 장비는 효과가 없고, 많이 닳으면 80%만 낸다.
-- - 이목: 30 + 체력×0.8 − 민첩×0.4 + 방어구 방어력×0.6 + 장비 이목 (5~300). 파티 원정의 합동 전투에서 요괴는 이목^1.3에 비례해 표적을 고른다.
-- - 장비 드롭(world_gear_drops): 요괴 유형·레벨대·등급별 확률. 한 번에 최대 하나. 현장 토벌과 원정 전투 모두에서 떨어진다.
-- - 1~5단계 장비 150종, 제작법 104개, 상점 37줄. 5단계도 거래할 수 있다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 안전하다(이미 넣은 물품·제작법·드롭은 건너뛴다).

/* ── 1) 표 ─────────────────────────────────────────────── */
create table if not exists public.world_gear_drops (
  item_id text not null references public.world_item_catalog(item_id) deferrable initially deferred,
  mechanic_key text not null,
  level_min int not null,
  level_max int not null,
  chance_normal numeric not null default 0,
  chance_elite numeric not null default 0,
  chance_guardian numeric not null default 0,
  primary key (item_id, mechanic_key)
);
alter table public.world_gear_drops enable row level security;
revoke all on public.world_gear_drops from anon, authenticated;

-- 파티 원정 합동 전투에서 동료가 대신 맞은 피해(동료 자신의 정산 때 반영)
create table if not exists public.world_expedition_hits (
  hit_id bigint generated always as identity primary key,
  owner_id uuid not null references auth.users(id) on delete cascade,
  amount int not null check (amount > 0),
  created_at timestamptz not null default now()
);
create index if not exists world_expedition_hits_owner on public.world_expedition_hits(owner_id);
alter table public.world_expedition_hits enable row level security;
revoke all on public.world_expedition_hits from anon, authenticated;
grant select on public.world_gear_drops to fn_owner_field;
grant select, insert, delete on public.world_expedition_hits to fn_owner_field;

alter table public.world_character_equipment drop constraint if exists world_character_equipment_slot_check;
alter table public.world_character_equipment add constraint world_character_equipment_slot_check
  check (slot = any (array['tool', 'weapon', 'armor', 'charm', 'hat', 'shoes', 'norigae', 'amulet', 'mask']));
alter table public.world_item_catalog drop constraint if exists world_item_catalog_category_check;
alter table public.world_item_catalog add constraint world_item_catalog_category_check
  check (category = any (array['material', 'consumable', 'equipment', 'tool', 'weapon', 'armor', 'quest', 'hat', 'shoes', 'norigae', 'amulet', 'mask']));

/* ── 2) 내구도 최댓값: 관모·신 추가 ────────────────────────── */
create or replace function public.world_item_max_durability(p_item text)
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  SELECT CASE WHEN category IN ('weapon', 'armor') THEN 50 + coalesce(tier, 1) * 30
              WHEN category IN ('tool', 'hat', 'shoes') THEN 40 + coalesce(tier, 1) * 20 ELSE NULL END
  FROM public.world_item_catalog WHERE item_id = p_item
$$;

/* ── 3) 장비 특성 합계 ────────────────────────────────────── */
-- 무기의 위력·피해, 방어구의 방어력·피해 감소, 도구의 채집 보너스, 낚싯대 특성은 각 기능이 따로 읽으므로 여기서 빼 두 번 세지 않는다.
create or replace function public.world_gear_total(p_owner uuid, p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  SELECT coalesce(sum(
    (i.equipment_traits ->> p_key)::numeric
    * CASE WHEN x.mx IS NULL THEN 1 WHEN coalesce(d.durability, x.mx) <= 0 THEN 0 WHEN coalesce(d.durability, x.mx) * 4 < x.mx THEN 0.8 ELSE 1 END
  ), 0)
  FROM public.world_character_equipment e
  JOIN public.world_item_catalog i ON i.item_id = e.item_id
  CROSS JOIN LATERAL (SELECT public.world_item_max_durability(e.item_id) AS mx) x
  LEFT JOIN public.world_item_durability d ON d.owner_id = e.owner_id AND d.item_id = e.item_id
  WHERE e.owner_id = p_owner AND p_owner IS NOT NULL
    AND (i.equipment_traits ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
    AND p_key NOT LIKE 'fish\_%'
    AND NOT (e.slot = 'weapon' AND p_key IN ('power', 'combat_damage_pct'))
    AND NOT (e.slot = 'armor' AND p_key IN ('defense', 'damage_reduction_pct'))
    AND NOT (e.slot = 'tool' AND p_key = 'gathering_bonus_pct')
$$;
alter function public.world_gear_total(uuid, text) owner to fn_owner_field;
revoke all on function public.world_gear_total(uuid, text) from public, anon, authenticated;

-- 로그인한 본인의 장비 합계(상태 효과 합계에서 쓴다)
create or replace function public.world_gear_self(p_key text)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  SELECT public.world_gear_total(public.fn_owner_auth_uid(), p_key)
$$;
alter function public.world_gear_self(text) owner to fn_owner_field;
revoke all on function public.world_gear_self(text) from anon;

create or replace function public.world_status_effect_total(p_effect_key text)
returns numeric language sql stable set search_path to 'pg_catalog', 'public' as $$
 select coalesce(sum(
   case when (cat.effects->>p_effect_key) ~ '^-?[0-9]+(\.[0-9]+)?$'
     then (cat.effects->>p_effect_key)::numeric * cs.potency
     else 0 end
 ),0) + public.world_env_total(public.fn_owner_auth_uid(), p_effect_key) + public.world_gear_self(p_effect_key)
 from public.world_character_statuses cs
 join public.world_status_catalog cat using(status_key)
 where cs.owner_id=public.fn_owner_auth_uid() and cs.expires_at>now()
$$;

/* ── 4) 장비 드롭 굴림: 요괴 유형·레벨·등급에 맞는 장비 하나(없으면 null) ── */
create or replace function public.world_gear_roll(p_mech text, p_level int, p_rank text, p_rare numeric default 0)
returns text language plpgsql volatile security definer set search_path to 'pg_catalog', 'public' as $$
declare total numeric; cap numeric; got text;
begin
  select coalesce(sum(case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end), 0)
    into total from public.world_gear_drops g
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max;
  if total <= 0 then return null; end if;
  cap := case p_rank when 'guardian' then 0.3 when 'elite' then 0.12 else 0.05 end;
  if random() >= least(cap, total) * greatest(0, 1 + coalesce(p_rare, 0) / 100.0) then return null; end if;
  select g.item_id into got from public.world_gear_drops g
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max
     and (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end) > 0
   order by -ln(greatest(random(), 1e-9)) / (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end)
   limit 1;
  return got;
end $$;
alter function public.world_gear_roll(text, int, text, numeric) owner to fn_owner_field;
revoke all on function public.world_gear_roll(text, int, text, numeric) from public, anon, authenticated;

/* ── 5) 전투 능력치: 장비 방어력·회피·치명타·달아나기와 이목 ───── */
create or replace function public.world_combat_stats(p_owner uuid, p_delta jsonb default '{}'::jsonb)
returns jsonb language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
DECLARE c public.world_characters%rowtype; s_str int; s_agi int; s_vit int; s_per int; s_wil int; s_spi int;
  w_id text; w_name text; w_tr jsonb; w_dur int; w_max int; a_id text; a_name text; a_tr jsonb; a_dur int; a_max int;
  style text := 'melee'; wpow numeric := 2; wbonus numeric := 0; adef numeric := 0; adr numeric := 0; w_state text := 'none'; a_state text := 'none';
  base numeric; mind numeric := 1; pct numeric; style_pct numeric; attack numeric; defense numeric; red numeric; inc numeric; eva numeric; crit numeric; flee numeric;
  skill_cat text; skill_pct numeric := 0; skill_crit numeric := 0; skills jsonb := '[]'::jsonb;
  g_def numeric; g_eva numeric; g_crit numeric; g_flee numeric; g_pres numeric; pres numeric;
BEGIN
  SELECT * INTO c FROM public.world_characters WHERE owner_id = p_owner;
  IF NOT FOUND THEN RETURN NULL; END IF;
  s_str := c.strength + coalesce((p_delta ->> 'strength')::int, 0); s_agi := c.agility + coalesce((p_delta ->> 'agility')::int, 0);
  s_vit := c.vitality + coalesce((p_delta ->> 'vitality')::int, 0); s_per := c.perception + coalesce((p_delta ->> 'perception')::int, 0);
  s_wil := c.willpower + coalesce((p_delta ->> 'willpower')::int, 0); s_spi := c.spirit_affinity + coalesce((p_delta ->> 'spirit_affinity')::int, 0);

  SELECT e.item_id, i.item_name, i.equipment_traits, d.durability INTO w_id, w_name, w_tr, w_dur
    FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    LEFT JOIN public.world_item_durability d ON d.owner_id = e.owner_id AND d.item_id = e.item_id WHERE e.owner_id = p_owner AND e.slot = 'weapon';
  IF w_id IS NOT NULL THEN
    w_max := public.world_item_max_durability(w_id); w_dur := coalesce(w_dur, w_max);
    style := coalesce(w_tr ->> 'weapon_type', 'melee');
    IF w_dur <= 0 THEN w_state := 'broken'; wpow := 2;
    ELSE
      wpow := coalesce((w_tr ->> 'power')::numeric, 2); wbonus := coalesce((w_tr ->> 'combat_damage_pct')::numeric, 0); w_state := 'ok';
      IF w_dur * 4 < w_max THEN wpow := wpow * 0.8; w_state := 'worn'; END IF;
    END IF;
  END IF;
  SELECT e.item_id, i.item_name, i.equipment_traits, d.durability INTO a_id, a_name, a_tr, a_dur
    FROM public.world_character_equipment e JOIN public.world_item_catalog i ON i.item_id = e.item_id
    LEFT JOIN public.world_item_durability d ON d.owner_id = e.owner_id AND d.item_id = e.item_id WHERE e.owner_id = p_owner AND e.slot = 'armor';
  IF a_id IS NOT NULL THEN
    a_max := public.world_item_max_durability(a_id); a_dur := coalesce(a_dur, a_max);
    IF a_dur <= 0 THEN a_state := 'broken';
    ELSE
      adef := coalesce((a_tr ->> 'defense')::numeric, 0); adr := coalesce((a_tr ->> 'damage_reduction_pct')::numeric, 0); a_state := 'ok';
      IF a_dur * 4 < a_max THEN adef := adef * 0.8; a_state := 'worn'; END IF;
    END IF;
  END IF;
  -- 그 밖의 장비가 더하는 전투 특성(관모·신·노리개·호신부·탈, 무기·방어구의 덧붙은 특성)
  g_def := public.world_gear_total(p_owner, 'defense'); g_eva := public.world_gear_total(p_owner, 'evasion_pct');
  g_crit := public.world_gear_total(p_owner, 'crit_pct'); g_flee := public.world_gear_total(p_owner, 'flee_pct');
  g_pres := public.world_gear_total(p_owner, 'presence');

  -- 익힌 전투 기술: 공격 방식에 맞는 계열(근접·원거리·봉인)과 분석 계열의 상시 효과
  skill_cat := CASE style WHEN 'ranged' THEN 'ranged' WHEN 'magic' THEN 'sealing' ELSE 'melee' END;
  SELECT coalesce(sum(CASE WHEN sk.category = skill_cat THEN coalesce((sk.passive_effect ->> 'damage_pct')::numeric, 0) ELSE 0 END), 0),
         coalesce(sum(coalesce((sk.passive_effect ->> 'crit_pct')::numeric, 0)), 0),
         coalesce(jsonb_agg(sk.skill_name), '[]'::jsonb)
    INTO skill_pct, skill_crit, skills
    FROM public.world_skill_catalog sk
    WHERE sk.category IN (skill_cat, 'analysis') AND coalesce((c.skill_progress -> sk.category ->> 'rank')::int, 1) >= sk.unlock_rank;

  base := CASE style
    WHEN 'ranged' THEN 6 + s_agi * 0.9 + s_per * 0.7 + wpow * 1.5 + c.level * 0.8
    WHEN 'magic' THEN 6 + s_spi * 1.1 + s_wil * 0.6 + wpow * 1.5 + c.level * 0.8
    ELSE 8 + s_str * 1.5 + wpow * 1.6 + c.level * 0.8 END;
  IF c.mental < 20 THEN mind := mind * 0.7; ELSIF c.mental < 40 THEN mind := mind * 0.85; END IF;
  IF c.erosion >= 80 THEN mind := mind * 0.7; ELSIF c.erosion >= 55 THEN mind := mind * 0.8; ELSIF c.erosion >= 30 THEN mind := mind * 0.9; END IF;
  style_pct := public.world_status_effect_total(style || '_pct') + public.world_title_bonus(style || '_pct');
  pct := public.world_status_effect_total('combat_damage_pct') + public.world_title_bonus('combat_damage_pct') + wbonus + style_pct + skill_pct;
  attack := base * (1 + coalesce(c.combat_rank, 1) * 0.015) * mind * (1 + pct / 100.0);
  defense := greatest(0, s_vit * 0.8 + adef + g_def + c.level * 0.5);
  red := 1 - (100.0 / (100 + defense * 3)) * (1 - adr / 100.0);
  inc := public.world_status_effect_total('incoming_damage_pct') + public.world_title_bonus('incoming_damage_pct');
  eva := greatest(0, least(40, 3 + s_agi * 0.35 + CASE WHEN c.job_key = 'scout' THEN 6 ELSE 0 END + g_eva));
  crit := greatest(0, least(60, 5 + s_per * 0.4 + CASE WHEN style = 'ranged' THEN 8 ELSE 0 END + CASE WHEN c.job_key = 'analyst' THEN 8 ELSE 0 END + skill_crit + g_crit));
  flee := greatest(10, least(95, 50 + s_agi + CASE WHEN c.job_key = 'scout' THEN 15 ELSE 0 END + g_flee));
  -- 이목: 요괴가 먼저 노리는 정도. 몸집(체력)과 갑옷이 무거울수록 높고, 날랠수록 낮다
  pres := greatest(5, least(300, 30 + s_vit * 0.8 - s_agi * 0.4 + adef * 0.6 + g_pres));
  RETURN jsonb_build_object(
    'style', style, 'attack', round(attack), 'attack_raw', attack, 'damage_pct', round(pct, 1), 'style_pct', round(style_pct, 1), 'skill_pct', skill_pct, 'skills', skills,
    'defense', round(defense, 1), 'reduction_pct', round(red * 100, 1), 'incoming_pct', round(inc, 1),
    'evasion_pct', round(eva, 1), 'crit_pct', round(crit, 1), 'crit_mult', 160, 'flee_pct', round(flee),
    'presence', round(pres), 'gear_presence', round(g_pres, 1),
    'spell_cost', CASE WHEN style = 'magic' THEN 3 ELSE 0 END, 'mind_mul', round(mind, 2),
    'weapon', CASE WHEN w_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', w_id, 'name', w_name, 'type', style, 'power', round(wpow, 1),
      'durability', w_dur, 'max', w_max, 'state', w_state) END,
    'armor', CASE WHEN a_id IS NULL THEN NULL ELSE jsonb_build_object('item_id', a_id, 'name', a_name, 'defense', round(adef, 1), 'reduction', adr,
      'durability', a_dur, 'max', a_max, 'state', a_state) END,
    'stats', jsonb_build_object('strength', s_str, 'agility', s_agi, 'vitality', s_vit, 'perception', s_per, 'willpower', s_wil, 'spirit_affinity', s_spi));
END $function$;

/* ── 6) 장착·해제 ─────────────────────────────────────────── */
grant fn_owner_18453 to postgres with inherit true;
create or replace function public.world_equip_item(p_item_id text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; it public.world_item_catalog%rowtype; inv jsonb; slot_name text; stat_key text; required int;
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid for update;
 if not found then raise exception '캐릭터를 먼저 생성하세요.'; end if;
 select * into it from public.world_item_catalog where item_id=p_item_id;
 if not found or it.category not in ('tool','weapon','armor','hat','shoes','norigae','amulet','mask') then raise exception '장착할 수 없는 아이템입니다.'; end if;
 inv:=coalesce(c.inventory,'{}'::jsonb);
 if coalesce((inv->>p_item_id)::int,0)<1 then raise exception '소지하지 않은 아이템입니다.'; end if;
 if coalesce(c.level,1)<coalesce(it.minimum_level,1) then raise exception '레벨 조건 미달: 필요 레벨 %',it.minimum_level; end if;
 if it.required_job is not null and c.job_key<>it.required_job then raise exception '직업 제한: % 전용 장비입니다.',public.world_job_name(it.required_job); end if;
 if it.required_faction is not null and c.faction_key<>it.required_faction then raise exception '소속 제한: % 전용 장비입니다.',public.world_faction_name(it.required_faction); end if;
 for stat_key,required in select key,value::text::int from jsonb_each(coalesce(it.required_stats,'{}'::jsonb)) loop
  if coalesce((to_jsonb(c)->>stat_key)::int,0)<required then raise exception '능력치 조건 미달: % % 필요',public.world_stat_name(stat_key),required; end if;
 end loop;
 slot_name:=it.category;
 insert into public.world_character_equipment(owner_id,slot,item_id) values(uid,slot_name,p_item_id) on conflict(owner_id,slot) do update set item_id=excluded.item_id,equipped_at=now();
 insert into public.world_events(actor_id,actor_name,event_type,content,payload) values(uid,c.character_name,'equip','장착: '||it.item_name,jsonb_build_object('item',p_item_id,'slot',slot_name));
 return jsonb_build_object('content','장착 완료: '||it.item_name,'slot',slot_name,'item',p_item_id);
end $function$;
grant fn_owner_18453 to postgres with inherit false;

create or replace function public.world_unequip_item(p_slot text)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; it text; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_slot not in ('tool', 'weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask') then raise exception '알 수 없는 장착 칸입니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if exists (select 1 from public.world_active_encounters a where a.owner_id = uid and not a.defeated and not coalesce(a.fled, false)) then
    raise exception '전투 중에는 장비를 벗을 수 없습니다.'; end if;
  if exists (select 1 from public.world_expeditions e where e.owner_id = uid and e.status = 'active') then
    raise exception '원정 중에는 장비를 벗을 수 없습니다.'; end if;
  delete from public.world_character_equipment q where q.owner_id = uid and q.slot = p_slot returning q.item_id into it;
  if it is null then raise exception '그 칸에는 장착한 것이 없습니다.'; end if;
  select item_name into nm from public.world_item_catalog where item_id = it;
  insert into public.world_events(actor_id, actor_name, event_type, content, payload)
  values (uid, c.character_name, 'unequip', '장착 해제: ' || nm, jsonb_build_object('item', it, 'slot', p_slot));
  return jsonb_build_object('ok', true, 'content', nm || '을(를) 벗었습니다.', 'slot', p_slot, 'item', it);
end $$;
alter function public.world_unequip_item(text) owner to fn_owner_field;
revoke all on function public.world_unequip_item(text) from public, anon;
grant execute on function public.world_unequip_item(text) to authenticated;

/* ── 7) 기존 함수 고치기(한 줄 기준점) ───────────────────────── */
do $patch$
declare d text; n text;
begin
  -- 현장 전투: 맞으면 관모도 닳고, 곡성의 정신 손실에 장비 보정, 치명타 상한 65%, 이긴 뒤 장비 드롭
  d := pg_get_functiondef('public.world_battle_action(text, text)'::regprocedure); n := d;
  if position('world_gear_roll' in n) = 0 then
    n := replace(n, 'wear := public.world_durability_wear(uid, ''armor'', 1);',
      'wear := public.world_durability_wear(uid, ''hat'', 1); IF coalesce((wear ->> ''broke'')::boolean, false) THEN lines := lines || jsonb_build_array((wear ->> ''name'') || ''이(가) 부서졌다!''); END IF; wear := public.world_durability_wear(uid, ''armor'', 1);');
    n := replace(n, 'IF v_intent = ''wail'' THEN mn := greatest(0, mn - 6);',
      'IF v_intent = ''wail'' THEN mn := greatest(0, mn - greatest(0, round(6 * (1 + public.world_status_effect_total(''mental_loss_pct'') / 100.0))::int));');
    n := replace(n, 'cc := least(0.55, crit_p / 100.0', 'cc := least(0.65, crit_p / 100.0');
    n := replace(n, 'IF a.rank <> ''normal'' AND random() < (CASE a.rank WHEN ''guardian'' THEN 1 ELSE 0.3 END) THEN loot := public.world_inv_add(loot, ''monster_core'', 1); END IF;',
      'IF a.rank <> ''normal'' AND random() < (CASE a.rank WHEN ''guardian'' THEN 1 ELSE 0.3 END) THEN loot := public.world_inv_add(loot, ''monster_core'', 1); END IF; sig := public.world_gear_roll(m.mechanic_key, a.mlevel, a.rank, rare); IF sig IS NOT NULL THEN loot := public.world_inv_add(loot, sig, 1); lines := lines || jsonb_build_array(''장비를 얻었다: '' || (SELECT item_name FROM public.world_item_catalog WHERE item_id = sig)); END IF;');
    if n = d or position('world_gear_roll' in n) = 0 or position('''hat''' in n) = 0 or position('mental_loss_pct' in n) = 0 or position('least(0.65' in n) = 0 then
      raise exception 'world_battle_action 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;

  -- 이동: 출발할 때 신이 구간 수만큼 닳는다(이동 시간 보정은 상태 효과 합계로 이미 들어간다)
  d := pg_get_functiondef('public.world_travel_route(text)'::regprocedure); n := d;
  if position('''shoes''' in n) = 0 then
    n := replace(n, 'arrives := now() + make_interval(secs => round(secs));',
      'PERFORM public.world_durability_wear(uid, ''shoes'', cardinality(path) - 1); arrives := now() + make_interval(secs => round(secs));');
    if n = d then raise exception 'world_travel_route 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;

  -- 수리: 관모·신도 고칠 수 있다
  d := pg_get_functiondef('public.world_equipment_repair(text, text)'::regprocedure); n := d;
  if position('''hat''' in n) = 0 then
    n := replace(n, 'it.category NOT IN (''weapon'', ''armor'', ''tool'')', 'it.category NOT IN (''weapon'', ''armor'', ''tool'', ''hat'', ''shoes'')');
    if n = d then raise exception 'world_equipment_repair 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;
end $patch$;

-- 상점에는 장비를 팔 수 없다(새 장비 종류도 같게). 거래소·직접 거래로는 사고판다.
grant fn_owner_18878 to postgres with inherit true;
do $patch2$
declare d text; n text;
begin
  d := pg_get_functiondef('public.world_shop_sell'::regproc); n := d;
  if position('''norigae''' in n) = 0 then
    n := replace(n, 'item.category in (''equipment'',''weapon'',''armor'',''tool'',''quest'')', 'item.category in (''equipment'',''weapon'',''armor'',''tool'',''quest'',''hat'',''shoes'',''norigae'',''amulet'',''mask'')');
    if n = d then raise exception 'world_shop_sell 고칠 곳을 찾지 못했습니다.'; end if;
    execute n;
  end if;
end $patch2$;
grant fn_owner_18878 to postgres with inherit false;

/* ── 8) 원정 회차 정산: 장비 특성·장비 드롭·파티 합동 전투(이목) ── */
create or replace function public.world_expedition_settle(p_exp uuid, p_upto int default null)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare
  e public.world_expeditions%rowtype; c public.world_characters%rowtype; n public.world_exploration_nodes%rowtype;
  r public.world_map_regions%rowtype; m public.world_region_monsters%rowtype;
  total int; target int; i int; last_i int; t timestamptz; span interval; roll float8; win_p float8; depth int; danger int;
  st jsonb; sup jsonb; loot jsonb; lg jsonb; jr jsonb := '[]'::jsonb; seq int := 0;
  hp int; mn int; er int; wins int; losses int; gathers int; finds int; hazards int; discovered int;
  xp int; cxp int; gxp int; ixp int; gil_gain int; jobn int; job_once boolean; weak_bonus float8; ended text; short int;
  wt int := 0; at_ int := 0; tt int := 0; power float8; defense float8; threat float8; dmg int; heal int;
  p_fight float8; dmg_mul float8; loot_mul float8; disc_mul float8; heal_at int;
  item text; qty int; pool text[]; rare_pool text[]; spirit_mech boolean; found_node uuid; found_spot uuid;
  me text; foe text; a_n int; b_n int; k int; ehp int; my_hit int; left_d int; part int; h0 int; h1 int;
  base_t timestamptz; won boolean;
  g_inc float8; g_ml float8; g_er float8; g_rare float8; pres float8; allies jsonb := '[]'::jsonb; act jsonb; al jsonb;
  nal int; sum_ally float8; tot_w float8; pick float8; my_taken int; gear_item text; who_n text; who_o uuid; pend int;
begin
  select * into e from public.world_expeditions where expedition_id = p_exp and status = 'active' for update;
  if not found then return 0; end if;
  total := case e.minutes when 30 then 3 when 60 then 6 when 120 then 10 when 240 then 16 else 24 end;
  target := coalesce(p_upto, floor(total * extract(epoch from least(now(), e.ends_at) - e.started_at) / (e.minutes * 60.0))::int);
  target := greatest(0, least(total, target));
  if target <= e.settled_rounds then return e.settled_rounds; end if;

  st := coalesce(e.state, jsonb_build_object('sup', e.supplies, 'loot', '{}'::jsonb, 'log', '[]'::jsonb, 'wins', 0, 'losses', 0, 'gathers', 0, 'finds', 0,
    'hazards', 0, 'discovered', 0, 'xp', 0, 'cxp', 0, 'gxp', 0, 'ixp', 0, 'gil', 0, 'jobn', 0, 'job_once', false, 'weak', 0, 'ended', 'complete', 'short', 0));
  if st ->> 'ended' in ('downed', 'exhausted') then return e.settled_rounds; end if;

  select * into c from public.world_characters where owner_id = e.owner_id for update;
  -- 동료 원정의 합동 전투에서 이 캐릭터가 대신 맞은 피해(쓰러뜨리지는 않는다)
  delete from public.world_expedition_hits where owner_id = e.owner_id and created_at < e.started_at;
  with d as (delete from public.world_expedition_hits where owner_id = e.owner_id returning amount) select coalesce(sum(amount), 0) into pend from d;
  if pend > 0 then c.health := greatest(1, c.health - pend); end if;
  select * into r from public.world_map_regions where region_id = e.region_id;
  select * into n from public.world_exploration_nodes where node_id = e.node_id;
  if n.node_id is null then select * into n from public.world_exploration_nodes where region_id = e.region_id and hierarchy_level = 2 limit 1; end if;
  depth := greatest(1, least(3, n.hierarchy_level - 1));
  danger := r.danger_level + n.hierarchy_level - 2;
  me := c.character_name;
  span := e.ends_at - e.started_at;

  select coalesce(max(case when eq.slot = 'weapon' then ic.tier end), 0), coalesce(max(case when eq.slot = 'armor' then ic.tier end), 0),
         coalesce(max(case when eq.slot = 'tool' then ic.tier end), 0)
    into wt, at_, tt from public.world_character_equipment eq join public.world_item_catalog ic on ic.item_id = eq.item_id where eq.owner_id = e.owner_id;
  power := 12 + c.level * 5 + c.strength * 2.5 + c.agility * 1.5 + c.perception + wt * 14 + coalesce(c.combat_rank, 1) * 3;
  if c.job_key = 'exorcist' then power := power * 1.12; end if;
  defense := c.level * 2 + c.vitality * 3 + at_ * 12;
  if c.major_faction_id = 'north_league' then defense := defense * 1.2; end if;
  -- 장비 특성: 관모·신·노리개·호신부·탈과 무기·방어구의 덧붙은 성능
  power := power * (1 + (public.world_gear_total(e.owner_id, 'combat_damage_pct') + public.world_gear_total(e.owner_id, 'crit_pct') * 0.5) / 100.0);
  defense := defense + public.world_gear_total(e.owner_id, 'defense') * 2;
  g_inc := public.world_gear_total(e.owner_id, 'incoming_damage_pct') - public.world_gear_total(e.owner_id, 'evasion_pct') * 0.5;
  g_ml := public.world_gear_total(e.owner_id, 'mental_loss_pct'); g_er := public.world_gear_total(e.owner_id, 'erosion_pct');
  g_rare := public.world_gear_total(e.owner_id, 'rare_loot_pct');
  pres := coalesce((public.world_combat_stats(e.owner_id) ->> 'presence')::float8, 30);
  -- 같은 지역으로 원정 중인 파티원: 같은 시각에 있으면 함께 싸우고, 요괴는 이목이 높은 쪽을 먼저 노린다
  select coalesce(jsonb_agg(jsonb_build_object('owner', pc.owner_id, 'name', pc.character_name,
      'power', 12 + pc.level * 5 + pc.strength * 2.5 + pc.agility * 1.5 + pc.perception + coalesce(w.tier, 0) * 14,
      'pres', coalesce((public.world_combat_stats(pc.owner_id) ->> 'presence')::float8, 30), 'from', pe.started_at, 'to', pe.ends_at)), '[]'::jsonb)
    into allies
    from public.world_party_members mp join public.world_party_members pm on pm.party_id = mp.party_id and pm.owner_id <> e.owner_id
    join public.world_expeditions pe on pe.owner_id = pm.owner_id and pe.status = 'active' and pe.region_id = e.region_id
      and coalesce(pe.state ->> 'ended', 'complete') not in ('downed', 'exhausted')
    join public.world_characters pc on pc.owner_id = pm.owner_id and pc.health > 0
    left join lateral (select ic.tier from public.world_character_equipment q join public.world_item_catalog ic on ic.item_id = q.item_id
      where q.owner_id = pm.owner_id and q.slot = 'weapon') w on true
   where mp.owner_id = e.owner_id;
  p_fight := case e.stance when 'cautious' then 0.22 when 'bold' then 0.5 else 0.35 end + danger * 0.012;
  dmg_mul := case e.stance when 'cautious' then 0.7 when 'bold' then 1.3 else 1.0 end;
  loot_mul := case e.stance when 'cautious' then 0.8 when 'bold' then 1.3 else 1.0 end * (1 + (depth - 1) * 0.15);
  if c.major_faction_id = 'red_moon_cult' and e.stance = 'bold' then loot_mul := loot_mul * 1.15; end if;
  disc_mul := case e.stance when 'cautious' then 0.85 when 'bold' then 1.2 else 1.0 end;
  if c.job_key = 'scout' then disc_mul := disc_mul * 1.2; end if;
  if c.major_faction_id = 'mandate_court' then disc_mul := disc_mul * 1.2; end if;
  heal_at := case e.stance when 'cautious' then 60 when 'bold' then 30 else 45 end;
  pool := array(select distinct x from public.world_gathering_spots s join public.world_exploration_nodes y on y.node_id = s.node_id, unnest(s.loot_items) x
                where y.region_id = r.region_id and y.hierarchy_level <= n.hierarchy_level + 1);
  rare_pool := array(select x from public.world_region_profiles p, unnest(p.signature_items) x join public.world_item_catalog ic on ic.item_id = x
                     where p.region_id = r.region_id and x not in ('courier_token', 'spirit_compass'));

  sup := st -> 'sup'; loot := st -> 'loot'; lg := st -> 'log';
  wins := (st ->> 'wins')::int; losses := (st ->> 'losses')::int; gathers := (st ->> 'gathers')::int; finds := (st ->> 'finds')::int;
  hazards := (st ->> 'hazards')::int; discovered := (st ->> 'discovered')::int; xp := (st ->> 'xp')::int; cxp := (st ->> 'cxp')::int;
  gxp := (st ->> 'gxp')::int; ixp := (st ->> 'ixp')::int; gil_gain := (st ->> 'gil')::int; jobn := (st ->> 'jobn')::int;
  job_once := (st ->> 'job_once')::boolean; weak_bonus := (st ->> 'weak')::float8; ended := st ->> 'ended'; short := (st ->> 'short')::int;
  hp := c.health; mn := c.mental; er := c.erosion;
  last_i := e.settled_rounds;

  for i in e.settled_rounds + 1 .. target loop
    t := e.started_at + span * i / total;
    base_t := t - interval '60 seconds';
    seq := 0;
    last_i := i;
    -- 한 시간마다 노정 건량
    h0 := floor(e.minutes * (i - 1) / total / 60.0)::int; h1 := floor(e.minutes * i / total / 60.0)::int;
    if h1 > h0 then
      if coalesce((sup ->> 'travel_ration')::int, 0) > 0 then sup := jsonb_set(sup, '{travel_ration}', to_jsonb((sup ->> 'travel_ration')::int - 1));
      else short := short + 1; mn := mn - 6;
        if short = 1 then lg := lg || jsonb_build_array('노정 건량이 모자라 허기진 채로 걸었습니다.'); end if;
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id, 'text', '허기 때문에 정신 -6');
      end if;
    end if;

    roll := random();
    if c.job_key = 'scout' and roll < p_fight and random() < 0.3 then
      roll := p_fight + 0.36; jobn := jobn + 1;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[흔적 추적] 요괴의 흔적을 먼저 읽고 길을 돌아 피했습니다.');
    end if;

    if roll < p_fight then
      select * into m from public.world_region_monsters where region_id = r.region_id and (role <> 'guardian' or depth >= 3)
        order by -ln(greatest(random(), 1e-9)) / case role when 'common' then 6 when 'guardian' then 0.6 else 4 end limit 1;
      if m.monster_id is not null then
        foe := m.monster_name;
        threat := ((70 + (n.min_level + 1) * 14) / 8.0 + (8 + (n.min_level + 1) * 1.1) * 2) * case when m.role = 'guardian' then 2.4 else 1 end * (1 + (depth - 1) * 0.25);
        spirit_mech := coalesce(m.mechanic_key, '') in ('spectral', 'warded', 'seal_breaker');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'fight', 'who', me, 'owner', e.owner_id,
          'text', foe || case when m.role = 'guardian' then '(우두머리)' else '' end || '와(과) 마주쳤습니다.');
        act := coalesce((select jsonb_agg(x) from jsonb_array_elements(allies) x where (x ->> 'from')::timestamptz <= t and (x ->> 'to')::timestamptz >= t), '[]'::jsonb);
        nal := jsonb_array_length(act);
        sum_ally := coalesce((select sum((x ->> 'power')::float8) from jsonb_array_elements(act) x), 0);
        if nal > 0 then
          threat := threat * (1 + 0.3 * nal);
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'fight', 'who', me, 'owner', e.owner_id,
            'text', (select string_agg(x ->> 'name', '·') from jsonb_array_elements(act) x) || '와(과) 함께 맞섭니다.');
        end if;
        win_p := (power + sum_ally * 0.6) / (power + sum_ally * 0.6 + threat);
        if spirit_mech then
          win_p := win_p + c.spirit_affinity * 0.004;
          if coalesce((sup ->> 'seal_paper')::int, 0) > 0 then
            sup := jsonb_set(sup, '{seal_paper}', to_jsonb((sup ->> 'seal_paper')::int - 1));
            win_p := win_p + case when c.job_key in ('sealmaster', 'exorcist') then 0.25 else 0.15 end;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '황지에 봉인 술식을 적어 요기를 누릅니다.');
          end if;
        end if;
        if weak_bonus > 0 then
          win_p := win_p + weak_bonus; weak_bonus := 0; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[약점 간파] 앞서 밀렸던 싸움에서 읽어 낸 약점을 노립니다.');
        end if;
        win_p := greatest(0.08, least(0.95, win_p));
        if c.job_key = 'exorcist' and spirit_mech and not job_once then
          win_p := 1; job_once := true; jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[파사 부적] ' || foe || '의 요기를 부적으로 단번에 꿰뚫었습니다.');
        end if;
        ehp := greatest(8, round(threat * 1.6)::int);
        won := random() < win_p;
        if won then
          wins := wins + 1; xp := xp + 10 + danger * 2; cxp := cxp + 16; gil_gain := gil_gain + 2 + danger;
          dmg := round((8 + n.min_level * 1.1) * 0.9 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
          if m.drops is not null and random() < 0.7 * loot_mul then
            select d.k into item from jsonb_each(m.drops) d(k, v) where exists (select 1 from public.world_item_catalog ic where ic.item_id = d.k) order by random() limit 1;
            if item is not null then loot := public.world_inv_add(loot, item, 1); end if;
          end if;
          gear_item := public.world_gear_roll(m.mechanic_key, n.min_level + 1, case when m.role = 'guardian' then 'guardian' else 'normal' end, (g_rare - 40)::numeric);
          if gear_item is not null then
            loot := public.world_inv_add(loot, gear_item, 1);
            lg := lg || jsonb_build_array(foe || '이(가) 지니고 있던 ' || (select item_name from public.world_item_catalog where item_id = gear_item) || '을(를) 챙겼습니다.');
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', foe || '이(가) 지니고 있던 장비를 챙겼습니다. (귀환 후 정리)');
          end if;
          if wins <= 3 then lg := lg || jsonb_build_array(foe || '을(를) 물리쳤습니다.'); end if;
          a_n := 1 + floor(random() * 3)::int; b_n := greatest(case when dmg > 0 then 1 else 0 end, a_n - 1);
        else
          losses := losses + 1;
          if c.job_key = 'analyst' then weak_bonus := 0.15; end if;
          dmg := round((8 + n.min_level * 1.1) * 2.4 * dmg_mul * (0.6 + random() * 0.6) * 100.0 / (100 + defense));
          lg := lg || jsonb_build_array(foe || '에게 밀려 물러났습니다.');
          a_n := 1 + floor(random() * 2)::int; b_n := a_n + 1;
        end if;
        -- 장비(호신부·회피)와 동료 수에 따른 피해. 동료가 있으면 요괴가 더 여러 번 공격하고, 이목에 따라 맞는 사람이 갈린다
        dmg := round(dmg * greatest(0.3, 1 + g_inc / 100.0) * (1 + 0.3 * nal));
        b_n := b_n + nal; a_n := a_n + nal; my_taken := 0;
        -- 주고받은 공격을 한 줄씩 적는다(공격의 합 = 요괴에게 준 피해, 요괴 공격의 합 = 받은 피해)
        left_d := dmg;
        for k in 1..greatest(a_n, b_n) loop
          if k <= a_n then
            -- 이긴 싸움은 마지막 공격으로 쓰러뜨리고, 진 싸움은 끝내 쓰러뜨리지 못한다
            my_hit := case when won and k = a_n then ehp else greatest(1, least(ehp - 1, round(ehp * (0.25 + random() * 0.3))::int)) end;
            if my_hit <= 0 then my_hit := 1; end if;
            ehp := ehp - my_hit;
            who_n := me; who_o := e.owner_id;
            if nal > 0 then
              pick := random() * (power + sum_ally);
              if pick >= power then
                pick := pick - power;
                for al in select x from jsonb_array_elements(act) x loop
                  who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
                  exit when pick < (al ->> 'power')::float8;
                  pick := pick - (al ->> 'power')::float8;
                end loop;
              end if;
            end if;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'atk', 'who', who_n, 'owner', who_o,
              'text', foe || '에게 ' || my_hit || ' 피해', 'value', my_hit);
          end if;
          if k <= b_n and left_d > 0 then
            part := case when k = b_n then left_d else greatest(1, round(left_d * (0.3 + random() * 0.3))::int) end;
            left_d := left_d - part;
            -- 이목(어그로): 무게 = 이목^1.3. 높을수록 요괴가 먼저 노린다
            who_n := me; who_o := e.owner_id;
            if nal > 0 then
              tot_w := (greatest(5, pres) ^ 1.3) + coalesce((select sum((greatest(5, (x ->> 'pres')::float8) ^ 1.3)) from jsonb_array_elements(act) x), 0);
              pick := random() * tot_w - (greatest(5, pres) ^ 1.3);
              if pick >= 0 then
                for al in select x from jsonb_array_elements(act) x loop
                  who_n := al ->> 'name'; who_o := (al ->> 'owner')::uuid;
                  exit when pick < (greatest(5, (al ->> 'pres')::float8) ^ 1.3);
                  pick := pick - (greatest(5, (al ->> 'pres')::float8) ^ 1.3);
                end loop;
              end if;
            end if;
            if who_o = e.owner_id then my_taken := my_taken + part;
            else insert into public.world_expedition_hits(owner_id, amount) values (who_o, part); end if;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', who_n, 'owner', who_o,
              'text', foe || '의 공격 · 체력 -' || part, 'value', part);
          end if;
        end loop;
        seq := seq + 1;
        jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id,
          'text', case when won then foe || '을(를) 물리쳤습니다.' else foe || '에게 밀려 물러났습니다.' end);
        hp := hp - my_taken;
        mn := mn - round((case when spirit_mech then 3 else 1 end) * greatest(0, 1 + g_ml / 100.0))::int;
      end if;
    elsif roll < p_fight + 0.35 then
      if cardinality(pool) > 0 then
        item := pool[1 + floor(random() * cardinality(pool))::int];
        qty := 1 + floor(random() * (1 + least(tt, 3)))::int + coalesce(c.gathering_rank, 1) / 10;
        if tt = 0 then qty := case when random() < 0.5 then 1 else 0 end; end if;
        qty := round(qty * loot_mul * (case when short > 0 then 0.9 else 1 end) * (1 + case when c.major_faction_id = 'southern_remnant' then 0.15 else 0 end
                + case when c.job_key in ('artificer', 'scout') then 0.15 else 0 end + c.perception * 0.005));
        if qty > 0 then
          gathers := gathers + 1; xp := xp + 4; gxp := gxp + 8; loot := public.world_inv_add(loot, item, qty);
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'gather', 'who', me, 'owner', e.owner_id, 'text', '채집터에서 재료를 거두었습니다. (수확은 귀환 후 정리)');
        else
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'walk', 'who', me, 'owner', e.owner_id, 'text', '채집할 만한 것을 찾았지만 도구가 마땅치 않아 지나칩니다.');
        end if;
        if c.job_key = 'artificer' and qty > 0 and random() < 0.25 then
          loot := public.world_inv_add(loot, item, 1); jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[현장 가공] 캔 재료를 손질해 쓸 만한 것을 하나 더 건졌습니다.');
        end if;
      end if;
    elsif roll < p_fight + 0.35 + 0.22 + c.perception * 0.002 then
      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      if random() < 0.55 * disc_mul then
        found_node := null; found_spot := null;
        select z.node_id into found_node from public.world_exploration_nodes z
          where z.region_id = r.region_id and z.hierarchy_level >= 2 and z.min_level <= c.level + 2
            and not exists (select 1 from public.world_exploration_discoveries d where d.owner_id = e.owner_id and d.node_id = z.node_id)
            and (z.hierarchy_level = 2 or exists (select 1 from public.world_exploration_discoveries d where d.owner_id = e.owner_id and d.node_id = z.parent_node_id))
          order by (z.parent_node_id = n.node_id) desc, random() limit 1;
        if found_node is not null and random() < 0.5 then
          insert into public.world_exploration_discoveries(owner_id, node_id) values (e.owner_id, found_node) on conflict do nothing;
          discovered := discovered + 1;
          if discovered <= 3 then lg := lg || jsonb_build_array('새로운 곳을 찾았습니다: ' || (select node_name from public.world_exploration_nodes where node_id = found_node)); end if;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id,
            'text', '새로운 곳을 찾았습니다: ' || (select node_name from public.world_exploration_nodes where node_id = found_node));
        else
          select s.spot_id into found_spot from public.world_gathering_spots s join public.world_exploration_discoveries d on d.node_id = s.node_id and d.owner_id = e.owner_id
            join public.world_exploration_nodes y on y.node_id = s.node_id
            where y.region_id = r.region_id and s.active and not exists (select 1 from public.world_gathering_discoveries g where g.owner_id = e.owner_id and g.spot_id = s.spot_id)
            order by (s.node_id = n.node_id) desc, random() limit 1;
          if found_spot is not null then
            insert into public.world_gathering_discoveries(owner_id, spot_id) values (e.owner_id, found_spot) on conflict do nothing;
            discovered := discovered + 1;
            if discovered <= 3 then lg := lg || jsonb_build_array('채집터를 찾았습니다: ' || (select spot_name from public.world_gathering_spots where spot_id = found_spot)); end if;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id,
              'text', '채집터를 찾았습니다: ' || (select spot_name from public.world_gathering_spots where spot_id = found_spot));
          else
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '쓸 만한 단서와 흔적을 기록했습니다.');
          end if;
        end if;
      else
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '쓸 만한 단서와 흔적을 기록했습니다.');
      end if;
      if cardinality(rare_pool) > 0 and random() < 0.04 + depth * 0.03 + (case when c.job_key = 'analyst' then 0.05 else 0 end) then
        item := rare_pool[1 + floor(random() * cardinality(rare_pool))::int];
        loot := public.world_inv_add(loot, item, 1);
        lg := lg || jsonb_build_array('숨겨진 곳에서 ' || (select item_name from public.world_item_catalog where item_id = item) || '을(를) 찾았습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'find', 'who', me, 'owner', e.owner_id, 'text', '숨겨진 곳에서 귀한 것을 찾아 챙겼습니다. (귀환 후 정리)');
      end if;
    else
      if random() < 0.6 then
        hazards := hazards + 1;
        if c.job_key = 'sealmaster' and random() < 0.5 then
          jobn := jobn + 1;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[결계 야영] 스며드는 요기를 결계로 막아 냈습니다.');
        else
          k := round((danger + depth) / 2.0 * (case when c.job_key = 'sealmaster' then 0.5 else 1 end) * greatest(0.3, 1 - c.willpower / 100.0));
          part := round((2 + floor(random() * 4)) * greatest(0, 1 + g_ml / 100.0))::int;
          k := round(k * greatest(0, 1 + g_er / 100.0))::int;
          er := er + k; mn := mn - part;
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'hurt', 'who', me, 'owner', e.owner_id,
            'text', '스며드는 요기에 휩쓸렸습니다. 침식 +' || k || ' · 정신 -' || part);
        end if;
      end if;
    end if;

    if er >= 50 and coalesce((sup ->> 'ward_talisman')::int, 0) > 0 then
      sup := jsonb_set(sup, '{ward_talisman}', to_jsonb((sup ->> 'ward_talisman')::int - 1)); er := er - 15; mn := mn + 5;
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '정화 부적을 태웠습니다. 침식 -15 · 정신 +5');
    end if;
    while hp < heal_at loop
      item := case when coalesce((sup ->> 'tonic')::int, 0) > 0 then 'tonic' when coalesce((sup ->> 'herbal_extract')::int, 0) > 0 then 'herbal_extract'
                   when coalesce((sup ->> 'herb')::int, 0) > 0 then 'herb' end;
      if item is null then
        if c.job_key = 'medic' and not job_once then
          hp := least(100, hp + 30); job_once := true; jobn := jobn + 1;
          lg := lg || jsonb_build_array('[야전 처치] 보급품이 떨어지자 주변 약초로 상처를 동여맸습니다. 체력 +30');
          seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '[야전 처치] 주변 약초로 상처를 동여맸습니다. 체력 +30');
        end if;
        exit;
      end if;
      heal := case item when 'tonic' then 35 when 'herbal_extract' then 22 else 12 end;
      if c.job_key = 'medic' then heal := round(heal * 1.5); end if;
      sup := jsonb_set(sup, array[item], to_jsonb((sup ->> item)::int - 1)); hp := least(100, hp + heal);
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id,
        'text', (select item_name from public.world_item_catalog where item_id = item) || '을(를) 썼습니다. 체력 +' || heal);
    end loop;
    if hp <= 0 then
      if coalesce((sup ->> 'revival_charm')::int, 0) > 0 then
        sup := jsonb_set(sup, '{revival_charm}', to_jsonb((sup ->> 'revival_charm')::int - 1)); hp := 30;
        lg := lg || jsonb_build_array('쓰러지기 직전 회생 부적이 타올라 몸을 일으켰습니다.');
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'heal', 'who', me, 'owner', e.owner_id, 'text', '쓰러지기 직전 회생 부적이 타올라 몸을 일으켰습니다. 체력 30');
      else
        hp := 0; ended := 'downed';
        lg := lg || jsonb_build_array('쓰러졌습니다. 챙긴 전리품 절반을 잃었습니다. 구조가 필요합니다.');
        select coalesce(jsonb_object_agg(lk, (lv::int / 2)) filter (where lv::int / 2 > 0), '{}'::jsonb) into loot from jsonb_each_text(loot) l(lk, lv);
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'down', 'who', me, 'owner', e.owner_id, 'text', '쓰러졌습니다. 더 나아갈 수 없습니다. 귀환해 구조를 받아야 합니다.');
        exit;
      end if;
    end if;
    if mn <= 0 then
      mn := 5; ended := case when ended = 'complete' then 'exhausted' else ended end;
      lg := lg || jsonb_build_array('정신이 바닥나 서둘러 돌아왔습니다.');
      seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'down', 'who', me, 'owner', e.owner_id, 'text', '정신이 바닥났습니다. 더 나아가지 못하고 돌아갈 채비를 합니다.');
      exit;
    end if;
  end loop;

  er := greatest(0, least(100, er)); mn := greatest(0, least(100, mn)); hp := greatest(0, least(100, hp));
  update public.world_characters set health = hp, mental = mn, erosion = er,
    erosion_stage = case when er >= 80 then 4 when er >= 55 then 3 when er >= 30 then 2 when er >= 10 then 1 else 0 end, updated_at = now()
   where owner_id = e.owner_id;
  st := jsonb_build_object('sup', sup, 'loot', loot, 'log', lg, 'wins', wins, 'losses', losses, 'gathers', gathers, 'finds', finds, 'hazards', hazards,
    'discovered', discovered, 'xp', xp, 'cxp', cxp, 'gxp', gxp, 'ixp', ixp, 'gil', gil_gain, 'jobn', jobn, 'job_once', job_once, 'weak', weak_bonus, 'ended', ended, 'short', short);
  update public.world_expeditions set settled_rounds = last_i, state = st, journal = coalesce(journal, '[]'::jsonb) || jr where expedition_id = e.expedition_id;
  return last_i;
end $$;

/* ── 9) 장비 150종·제작법·드롭·상점 ───────────────────────── */
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, rarity, minimum_level, acquisition_difficulty, tradeable, reference_price, equipment_traits) values
  ('w_melee1_heavy', '무쇠 철퇴', 'weapon', 1, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'common', 1, 1, true, 80, '{"trait": "근접", "weapon_type": "melee", "power": 7.2, "presence": 6}'::jsonb),
  ('w_melee1_keen', '날선 단도', 'weapon', 1, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'common', 1, 1, true, 80, '{"trait": "근접", "weapon_type": "melee", "power": 5.4, "crit_pct": 3}'::jsonb),
  ('w_melee1_silent', '그림자 비수', 'weapon', 1, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'common', 1, 1, true, 80, '{"trait": "근접", "weapon_type": "melee", "power": 5.7, "presence": -6, "evasion_pct": 1.5}'::jsonb),
  ('w_melee2_heavy', '쌍날 대부', 'weapon', 2, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "근접", "weapon_type": "melee", "power": 13.8, "presence": 12}'::jsonb),
  ('w_melee2_keen', '은월 장검', 'weapon', 2, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "근접", "weapon_type": "melee", "power": 10.3, "crit_pct": 6}'::jsonb),
  ('w_melee2_silent', '연막 단검', 'weapon', 2, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "근접", "weapon_type": "melee", "power": 10.9, "presence": -12, "evasion_pct": 3}'::jsonb),
  ('w_melee3_heavy', '파산 철편', 'weapon', 3, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'rare', 10, 3, true, 900, '{"trait": "근접", "weapon_type": "melee", "power": 23.4, "presence": 18}'::jsonb),
  ('w_melee3_keen', '청강 쌍검', 'weapon', 3, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'rare', 10, 3, true, 900, '{"trait": "근접", "weapon_type": "melee", "power": 17.6, "crit_pct": 9}'::jsonb),
  ('w_melee3_silent', '무영 소도', 'weapon', 3, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'rare', 10, 3, true, 900, '{"trait": "근접", "weapon_type": "melee", "power": 18.5, "presence": -18, "evasion_pct": 4.5}'::jsonb),
  ('w_melee4_heavy', '진산 대철퇴', 'weapon', 4, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'epic', 15, 4, true, 2600, '{"trait": "근접", "weapon_type": "melee", "power": 33.6, "presence": 24}'::jsonb),
  ('w_melee4_keen', '비연 청룡검', 'weapon', 4, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "근접", "weapon_type": "melee", "power": 25.2, "crit_pct": 12}'::jsonb),
  ('w_melee4_silent', '야음 비수', 'weapon', 4, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "근접", "weapon_type": "melee", "power": 26.6, "presence": -24, "evasion_pct": 6}'::jsonb),
  ('w_melee4_base', '용린 대도', 'weapon', 4, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'epic', 15, 4, true, 2989, '{"trait": "근접", "weapon_type": "melee", "power": 28, "combat_damage_pct": 10}'::jsonb),
  ('w_melee5_heavy', '붕산 금강저', 'weapon', 5, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "근접", "weapon_type": "melee", "power": 45.6, "presence": 30}'::jsonb),
  ('w_melee5_keen', '일섬 신검', 'weapon', 5, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "근접", "weapon_type": "melee", "power": 34.2, "crit_pct": 15}'::jsonb),
  ('w_melee5_silent', '무형 귀도', 'weapon', 5, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "근접", "weapon_type": "melee", "power": 36.1, "presence": -30, "evasion_pct": 7.5}'::jsonb),
  ('w_melee5_base', '천뢰 언월도', 'weapon', 5, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'legendary', 20, 5, true, 8049, '{"trait": "근접", "weapon_type": "melee", "power": 38, "combat_damage_pct": 15}'::jsonb),
  ('w_ranged1_heavy', '박달 강궁', 'weapon', 1, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'common', 1, 1, true, 80, '{"trait": "원거리", "weapon_type": "ranged", "power": 7.2, "presence": 6}'::jsonb),
  ('w_ranged1_keen', '매눈 활', 'weapon', 1, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'common', 1, 1, true, 80, '{"trait": "원거리", "weapon_type": "ranged", "power": 5.4, "crit_pct": 3}'::jsonb),
  ('w_ranged1_silent', '소리 없는 소궁', 'weapon', 1, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'common', 1, 1, true, 80, '{"trait": "원거리", "weapon_type": "ranged", "power": 5.7, "presence": -6, "evasion_pct": 1.5}'::jsonb),
  ('w_ranged2_heavy', '철태 쇠뇌', 'weapon', 2, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "원거리", "weapon_type": "ranged", "power": 13.8, "presence": 12}'::jsonb),
  ('w_ranged2_keen', '학익 각궁', 'weapon', 2, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "원거리", "weapon_type": "ranged", "power": 10.3, "crit_pct": 6}'::jsonb),
  ('w_ranged2_silent', '갈대 취관', 'weapon', 2, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "원거리", "weapon_type": "ranged", "power": 10.9, "presence": -12, "evasion_pct": 3}'::jsonb),
  ('w_ranged3_heavy', '연발 쇠뇌', 'weapon', 3, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'rare', 10, 3, true, 900, '{"trait": "원거리", "weapon_type": "ranged", "power": 23.4, "presence": 18}'::jsonb),
  ('w_ranged3_keen', '천리 각궁', 'weapon', 3, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'rare', 10, 3, true, 900, '{"trait": "원거리", "weapon_type": "ranged", "power": 17.6, "crit_pct": 9}'::jsonb),
  ('w_ranged3_silent', '무음 비궁', 'weapon', 3, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'rare', 10, 3, true, 900, '{"trait": "원거리", "weapon_type": "ranged", "power": 18.5, "presence": -18, "evasion_pct": 4.5}'::jsonb),
  ('w_ranged4_heavy', '팔우 대노', 'weapon', 4, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'epic', 15, 4, true, 2600, '{"trait": "원거리", "weapon_type": "ranged", "power": 33.6, "presence": 24}'::jsonb),
  ('w_ranged4_keen', '관일궁', 'weapon', 4, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "원거리", "weapon_type": "ranged", "power": 25.2, "crit_pct": 12}'::jsonb),
  ('w_ranged4_silent', '월영 단궁', 'weapon', 4, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "원거리", "weapon_type": "ranged", "power": 26.6, "presence": -24, "evasion_pct": 6}'::jsonb),
  ('w_ranged4_base', '흑룡 장궁', 'weapon', 4, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'epic', 15, 4, true, 2989, '{"trait": "원거리", "weapon_type": "ranged", "power": 28, "combat_damage_pct": 10}'::jsonb),
  ('w_ranged5_heavy', '천균 신노', 'weapon', 5, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "원거리", "weapon_type": "ranged", "power": 45.6, "presence": 30}'::jsonb),
  ('w_ranged5_keen', '성시 신궁', 'weapon', 5, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "원거리", "weapon_type": "ranged", "power": 34.2, "crit_pct": 15}'::jsonb),
  ('w_ranged5_silent', '허공 비궁', 'weapon', 5, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "원거리", "weapon_type": "ranged", "power": 36.1, "presence": -30, "evasion_pct": 7.5}'::jsonb),
  ('w_ranged5_base', '사일궁', 'weapon', 5, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'legendary', 20, 5, true, 8049, '{"trait": "원거리", "weapon_type": "ranged", "power": 38, "combat_damage_pct": 15}'::jsonb),
  ('w_magic1_heavy', '무쇠 금강령', 'weapon', 1, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'common', 1, 1, true, 80, '{"trait": "술법", "weapon_type": "magic", "power": 7.2, "presence": 6}'::jsonb),
  ('w_magic1_keen', '복사 산가지', 'weapon', 1, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'common', 1, 1, true, 80, '{"trait": "술법", "weapon_type": "magic", "power": 5.4, "crit_pct": 3}'::jsonb),
  ('w_magic1_silent', '먹 부채', 'weapon', 1, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'common', 1, 1, true, 80, '{"trait": "술법", "weapon_type": "magic", "power": 5.7, "presence": -6, "evasion_pct": 1.5}'::jsonb),
  ('w_magic2_heavy', '청동 법륜', 'weapon', 2, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "술법", "weapon_type": "magic", "power": 13.8, "presence": 12}'::jsonb),
  ('w_magic2_keen', '팔괘 나경', 'weapon', 2, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "술법", "weapon_type": "magic", "power": 10.3, "crit_pct": 6}'::jsonb),
  ('w_magic2_silent', '연기 향로', 'weapon', 2, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "술법", "weapon_type": "magic", "power": 10.9, "presence": -12, "evasion_pct": 3}'::jsonb),
  ('w_magic3_heavy', '뇌문 법인', 'weapon', 3, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'rare', 10, 3, true, 900, '{"trait": "술법", "weapon_type": "magic", "power": 23.4, "presence": 18}'::jsonb),
  ('w_magic3_keen', '북두 칠성 법검', 'weapon', 3, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'rare', 10, 3, true, 900, '{"trait": "술법", "weapon_type": "magic", "power": 17.6, "crit_pct": 9}'::jsonb),
  ('w_magic3_silent', '몽환 법선', 'weapon', 3, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'rare', 10, 3, true, 900, '{"trait": "술법", "weapon_type": "magic", "power": 18.5, "presence": -18, "evasion_pct": 4.5}'::jsonb),
  ('w_magic4_heavy', '진령 대종', 'weapon', 4, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'epic', 15, 4, true, 2600, '{"trait": "술법", "weapon_type": "magic", "power": 33.6, "presence": 24}'::jsonb),
  ('w_magic4_keen', '천기 산반', 'weapon', 4, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "술법", "weapon_type": "magic", "power": 25.2, "crit_pct": 12}'::jsonb),
  ('w_magic4_silent', '유령 등롱', 'weapon', 4, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'epic', 15, 4, true, 2600, '{"trait": "술법", "weapon_type": "magic", "power": 26.6, "presence": -24, "evasion_pct": 6}'::jsonb),
  ('w_magic4_base', '현무 법경', 'weapon', 4, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'epic', 15, 4, true, 2989, '{"trait": "술법", "weapon_type": "magic", "power": 28, "combat_damage_pct": 10}'::jsonb),
  ('w_magic5_heavy', '개천 신종', 'weapon', 5, '묵직하게 내리쳐 요괴의 이목을 끈다. 위력이 높지만 노려지기 쉽다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "술법", "weapon_type": "magic", "power": 45.6, "presence": 30}'::jsonb),
  ('w_magic5_keen', '천명 신산', 'weapon', 5, '날이 예리해 급소를 잘 찌른다. 치명타가 잘 터진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "술법", "weapon_type": "magic", "power": 34.2, "crit_pct": 15}'::jsonb),
  ('w_magic5_silent', '허무 법등', 'weapon', 5, '소리 없이 다루어 요괴의 눈에 덜 띈다. 몸놀림도 가벼워진다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "술법", "weapon_type": "magic", "power": 36.1, "presence": -30, "evasion_pct": 7.5}'::jsonb),
  ('w_magic5_base', '태극 법륜', 'weapon', 5, '오래 전해 내려온 이름난 무기. 고르게 강하다.', false, 'legendary', 20, 5, true, 8049, '{"trait": "술법", "weapon_type": "magic", "power": 38, "combat_damage_pct": 15}'::jsonb),
  ('a1_iron', '쇠미늘 갑옷', 'armor', 1, '두꺼운 쇠미늘로 몸을 감싼다. 단단하지만 요괴의 이목을 끈다.', false, 'common', 1, 1, true, 80, '{"trait": "방호", "defense": 5.6, "presence": 8, "evasion_pct": -1}'::jsonb),
  ('a1_light', '무명 철릭', 'armor', 1, '가볍게 지은 갑옷. 몸을 틀어 피하기 좋다.', false, 'common', 1, 1, true, 80, '{"trait": "방호", "defense": 3.4, "evasion_pct": 1.5}'::jsonb),
  ('a1_robe', '삼베 도포', 'armor', 1, '술식을 수놓은 도포. 받는 피해를 덜고 요기를 막는다.', false, 'common', 1, 1, true, 80, '{"trait": "방호", "defense": 2.8, "damage_reduction_pct": 2, "erosion_pct": -3}'::jsonb),
  ('a1_shade', '검은 무명옷', 'armor', 1, '밤빛에 섞이는 옷. 요괴의 눈을 피하고 빈틈을 노린다.', false, 'common', 1, 1, true, 80, '{"trait": "방호", "defense": 2.4, "presence": -8, "evasion_pct": 1, "crit_pct": 1}'::jsonb),
  ('a2_iron', '두정갑', 'armor', 2, '두꺼운 쇠미늘로 몸을 감싼다. 단단하지만 요괴의 이목을 끈다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "방호", "defense": 9.8, "presence": 16, "evasion_pct": -2}'::jsonb),
  ('a2_light', '가죽 철릭', 'armor', 2, '가볍게 지은 갑옷. 몸을 틀어 피하기 좋다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "방호", "defense": 6.0, "evasion_pct": 3}'::jsonb),
  ('a2_robe', '수결 도포', 'armor', 2, '술식을 수놓은 도포. 받는 피해를 덜고 요기를 막는다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "방호", "defense": 4.9, "damage_reduction_pct": 4, "erosion_pct": -6}'::jsonb),
  ('a2_shade', '야행 경의', 'armor', 2, '밤빛에 섞이는 옷. 요괴의 눈을 피하고 빈틈을 노린다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "방호", "defense": 4.2, "presence": -16, "evasion_pct": 2, "crit_pct": 2}'::jsonb),
  ('a3_iron', '철찰갑', 'armor', 3, '두꺼운 쇠미늘로 몸을 감싼다. 단단하지만 요괴의 이목을 끈다.', false, 'rare', 10, 3, true, 900, '{"trait": "방호", "defense": 16.8, "presence": 24, "evasion_pct": -3}'::jsonb),
  ('a3_light', '영사 철릭', 'armor', 3, '가볍게 지은 갑옷. 몸을 틀어 피하기 좋다.', false, 'rare', 10, 3, true, 900, '{"trait": "방호", "defense": 10.2, "evasion_pct": 4.5}'::jsonb),
  ('a3_robe', '운학 법의', 'armor', 3, '술식을 수놓은 도포. 받는 피해를 덜고 요기를 막는다.', false, 'rare', 10, 3, true, 900, '{"trait": "방호", "defense": 8.4, "damage_reduction_pct": 6, "erosion_pct": -9}'::jsonb),
  ('a3_shade', '묵영 야행복', 'armor', 3, '밤빛에 섞이는 옷. 요괴의 눈을 피하고 빈틈을 노린다.', false, 'rare', 10, 3, true, 900, '{"trait": "방호", "defense": 7.2, "presence": -24, "evasion_pct": 3, "crit_pct": 3}'::jsonb),
  ('a4_iron', '흑철 두정갑', 'armor', 4, '두꺼운 쇠미늘로 몸을 감싼다. 단단하지만 요괴의 이목을 끈다.', false, 'epic', 15, 4, true, 2600, '{"trait": "방호", "defense": 25.2, "presence": 32, "evasion_pct": -4}'::jsonb),
  ('a4_light', '비연 경갑', 'armor', 4, '가볍게 지은 갑옷. 몸을 틀어 피하기 좋다.', false, 'epic', 15, 4, true, 2600, '{"trait": "방호", "defense": 15.3, "evasion_pct": 6}'::jsonb),
  ('a4_robe', '청룡 법포', 'armor', 4, '술식을 수놓은 도포. 받는 피해를 덜고 요기를 막는다.', false, 'epic', 15, 4, true, 2600, '{"trait": "방호", "defense": 12.6, "damage_reduction_pct": 8, "erosion_pct": -12}'::jsonb),
  ('a4_shade', '월영 은신복', 'armor', 4, '밤빛에 섞이는 옷. 요괴의 눈을 피하고 빈틈을 노린다.', false, 'epic', 15, 4, true, 2600, '{"trait": "방호", "defense": 10.8, "presence": -32, "evasion_pct": 4, "crit_pct": 4}'::jsonb),
  ('a5_iron', '금강 철찰갑', 'armor', 5, '두꺼운 쇠미늘로 몸을 감싼다. 단단하지만 요괴의 이목을 끈다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "방호", "defense": 35, "presence": 40, "evasion_pct": -5}'::jsonb),
  ('a5_light', '천의 경갑', 'armor', 5, '가볍게 지은 갑옷. 몸을 틀어 피하기 좋다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "방호", "defense": 21.2, "evasion_pct": 7.5}'::jsonb),
  ('a5_robe', '태을 법포', 'armor', 5, '술식을 수놓은 도포. 받는 피해를 덜고 요기를 막는다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "방호", "defense": 17.5, "damage_reduction_pct": 10, "erosion_pct": -15}'::jsonb),
  ('a5_shade', '무영 야행복', 'armor', 5, '밤빛에 섞이는 옷. 요괴의 눈을 피하고 빈틈을 노린다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "방호", "defense": 15, "presence": -40, "evasion_pct": 5, "crit_pct": 5}'::jsonb),
  ('t2_gather', '약초꾼 망태', 'tool', 2, '채집할 때 더 많이 거둔다. 귀한 것도 잘 눈에 띈다.', false, 'uncommon', 5, 2, true, 240, '{"trait": "정밀 채집", "gathering_bonus_pct": 8, "rare_loot_pct": 2}'::jsonb),
  ('t3_gather', '청강 채집도', 'tool', 3, '채집할 때 더 많이 거둔다.', false, 'rare', 10, 3, true, 900, '{"trait": "정밀 채집", "gathering_bonus_pct": 12}'::jsonb),
  ('t4_gather', '영맥 곡괭이', 'tool', 4, '채집할 때 더 많이 거둔다. 귀한 것도 잘 눈에 띈다.', false, 'epic', 15, 4, true, 2600, '{"trait": "정밀 채집", "gathering_bonus_pct": 16, "rare_loot_pct": 4}'::jsonb),
  ('t5_gather', '천공 채집도', 'tool', 5, '채집할 때 더 많이 거둔다. 귀한 것도 잘 눈에 띈다.', false, 'legendary', 20, 5, true, 7000, '{"trait": "정밀 채집", "gathering_bonus_pct": 22, "rare_loot_pct": 6}'::jsonb),
  ('h1_guard', '무명 두건', 'hat', 1, '머리를 단단히 지킨다. 앞장서는 이에게 어울린다.', false, 'common', 1, 1, true, 56, '{"trait": "관모", "defense": 2, "presence": 5}'::jsonb),
  ('h1_calm', '유건', 'hat', 1, '마음을 가라앉혀 요기와 두려움을 막는다.', false, 'common', 1, 1, true, 56, '{"trait": "관모", "erosion_pct": -4, "mental_loss_pct": -6}'::jsonb),
  ('h1_wise', '탕건', 'hat', 1, '학식 있는 이의 관. 단서가 잘 보이고 급소를 읽는다.', false, 'common', 1, 1, true, 56, '{"trait": "관모", "clue_bonus_pct": 4, "crit_pct": 1}'::jsonb),
  ('h2_guard', '전립', 'hat', 2, '머리를 단단히 지킨다. 앞장서는 이에게 어울린다.', false, 'uncommon', 5, 2, true, 168, '{"trait": "관모", "defense": 4, "presence": 10}'::jsonb),
  ('h2_calm', '흑립', 'hat', 2, '마음을 가라앉혀 요기와 두려움을 막는다.', false, 'uncommon', 5, 2, true, 168, '{"trait": "관모", "erosion_pct": -8, "mental_loss_pct": -12}'::jsonb),
  ('h2_wise', '정자관', 'hat', 2, '학식 있는 이의 관. 단서가 잘 보이고 급소를 읽는다.', false, 'uncommon', 5, 2, true, 168, '{"trait": "관모", "clue_bonus_pct": 8, "crit_pct": 2}'::jsonb),
  ('h3_guard', '철전립', 'hat', 3, '머리를 단단히 지킨다. 앞장서는 이에게 어울린다.', false, 'rare', 10, 3, true, 630, '{"trait": "관모", "defense": 6, "presence": 15}'::jsonb),
  ('h3_calm', '학창 관모', 'hat', 3, '마음을 가라앉혀 요기와 두려움을 막는다.', false, 'rare', 10, 3, true, 630, '{"trait": "관모", "erosion_pct": -12, "mental_loss_pct": -18}'::jsonb),
  ('h3_wise', '동파관', 'hat', 3, '학식 있는 이의 관. 단서가 잘 보이고 급소를 읽는다.', false, 'rare', 10, 3, true, 630, '{"trait": "관모", "clue_bonus_pct": 12, "crit_pct": 3}'::jsonb),
  ('h4_guard', '주작 투구', 'hat', 4, '머리를 단단히 지킨다. 앞장서는 이에게 어울린다.', false, 'epic', 15, 4, true, 1819, '{"trait": "관모", "defense": 8, "presence": 20}'::jsonb),
  ('h4_calm', '백옥 관모', 'hat', 4, '마음을 가라앉혀 요기와 두려움을 막는다.', false, 'epic', 15, 4, true, 1819, '{"trait": "관모", "erosion_pct": -16, "mental_loss_pct": -24}'::jsonb),
  ('h4_wise', '문사 금관', 'hat', 4, '학식 있는 이의 관. 단서가 잘 보이고 급소를 읽는다.', false, 'epic', 15, 4, true, 1819, '{"trait": "관모", "clue_bonus_pct": 16, "crit_pct": 4}'::jsonb),
  ('h5_guard', '금강 투구', 'hat', 5, '머리를 단단히 지킨다. 앞장서는 이에게 어울린다.', false, 'legendary', 20, 5, true, 4900, '{"trait": "관모", "defense": 10, "presence": 25}'::jsonb),
  ('h5_calm', '야행 관모', 'hat', 5, '마음을 가라앉혀 요기와 두려움을 막는다.', false, 'legendary', 20, 5, true, 4900, '{"trait": "관모", "erosion_pct": -20, "mental_loss_pct": -30}'::jsonb),
  ('h5_wise', '천기 익선관', 'hat', 5, '학식 있는 이의 관. 단서가 잘 보이고 급소를 읽는다.', false, 'legendary', 20, 5, true, 4900, '{"trait": "관모", "clue_bonus_pct": 20, "crit_pct": 5}'::jsonb),
  ('s1_road', '짚신', 'shoes', 1, '먼 길을 덜 지치게 걷는다. 이동 시간이 줄어든다.', false, 'common', 1, 1, true, 48, '{"trait": "신", "travel_time_pct": -4}'::jsonb),
  ('s1_swift', '미투리', 'shoes', 1, '발이 가벼워 피하고 달아나기 좋다.', false, 'common', 1, 1, true, 48, '{"trait": "신", "evasion_pct": 1.5, "flee_pct": 3}'::jsonb),
  ('s1_sturdy', '나막신', 'shoes', 1, '땅을 굳게 딛는다. 버티며 앞을 막는 이에게 어울린다.', false, 'common', 1, 1, true, 48, '{"trait": "신", "defense": 1.5, "presence": 4}'::jsonb),
  ('s2_road', '행전 짚신', 'shoes', 2, '먼 길을 덜 지치게 걷는다. 이동 시간이 줄어든다.', false, 'uncommon', 5, 2, true, 144, '{"trait": "신", "travel_time_pct": -8}'::jsonb),
  ('s2_swift', '가죽 미투리', 'shoes', 2, '발이 가벼워 피하고 달아나기 좋다.', false, 'uncommon', 5, 2, true, 144, '{"trait": "신", "evasion_pct": 3, "flee_pct": 6}'::jsonb),
  ('s2_sturdy', '쇠징 신', 'shoes', 2, '땅을 굳게 딛는다. 버티며 앞을 막는 이에게 어울린다.', false, 'uncommon', 5, 2, true, 144, '{"trait": "신", "defense": 3, "presence": 8}'::jsonb),
  ('s3_road', '구름 목화', 'shoes', 3, '먼 길을 덜 지치게 걷는다. 이동 시간이 줄어든다.', false, 'rare', 10, 3, true, 540, '{"trait": "신", "travel_time_pct": -12}'::jsonb),
  ('s3_swift', '비연화', 'shoes', 3, '발이 가벼워 피하고 달아나기 좋다.', false, 'rare', 10, 3, true, 540, '{"trait": "신", "evasion_pct": 4.5, "flee_pct": 9}'::jsonb),
  ('s3_sturdy', '철목화', 'shoes', 3, '땅을 굳게 딛는다. 버티며 앞을 막는 이에게 어울린다.', false, 'rare', 10, 3, true, 540, '{"trait": "신", "defense": 4.5, "presence": 12}'::jsonb),
  ('s4_road', '운혜', 'shoes', 4, '먼 길을 덜 지치게 걷는다. 이동 시간이 줄어든다.', false, 'epic', 15, 4, true, 1560, '{"trait": "신", "travel_time_pct": -16}'::jsonb),
  ('s4_swift', '풍운화', 'shoes', 4, '발이 가벼워 피하고 달아나기 좋다.', false, 'epic', 15, 4, true, 1560, '{"trait": "신", "evasion_pct": 6, "flee_pct": 12}'::jsonb),
  ('s4_sturdy', '흑철화', 'shoes', 4, '땅을 굳게 딛는다. 버티며 앞을 막는 이에게 어울린다.', false, 'epic', 15, 4, true, 1560, '{"trait": "신", "defense": 6, "presence": 16}'::jsonb),
  ('s5_road', '축지 당혜', 'shoes', 5, '먼 길을 덜 지치게 걷는다. 이동 시간이 줄어든다.', false, 'legendary', 20, 5, true, 4200, '{"trait": "신", "travel_time_pct": -20}'::jsonb),
  ('s5_swift', '비천화', 'shoes', 5, '발이 가벼워 피하고 달아나기 좋다.', false, 'legendary', 20, 5, true, 4200, '{"trait": "신", "evasion_pct": 7.5, "flee_pct": 15}'::jsonb),
  ('s5_sturdy', '태산화', 'shoes', 5, '땅을 굳게 딛는다. 버티며 앞을 막는 이에게 어울린다.', false, 'legendary', 20, 5, true, 4200, '{"trait": "신", "defense": 7.5, "presence": 20}'::jsonb),
  ('n1_luck', '매듭 노리개', 'norigae', 1, '복을 부르는 노리개. 귀한 전리품이 잘 나온다.', false, 'common', 1, 1, true, 64, '{"trait": "노리개", "rare_loot_pct": 3}'::jsonb),
  ('n1_keen', '은방울 노리개', 'norigae', 1, '작은 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', false, 'common', 1, 1, true, 64, '{"trait": "노리개", "crit_pct": 2}'::jsonb),
  ('n1_plenty', '술 노리개', 'norigae', 1, '풍요를 비는 노리개. 거두는 양과 솜씨가 는다.', false, 'common', 1, 1, true, 64, '{"trait": "노리개", "gather_qty_pct": 3, "craft_quality": 1}'::jsonb),
  ('n2_luck', '호박 노리개', 'norigae', 2, '복을 부르는 노리개. 귀한 전리품이 잘 나온다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "노리개", "rare_loot_pct": 6}'::jsonb),
  ('n2_keen', '은장도 노리개', 'norigae', 2, '작은 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "노리개", "crit_pct": 4}'::jsonb),
  ('n2_plenty', '오색 술 노리개', 'norigae', 2, '풍요를 비는 노리개. 거두는 양과 솜씨가 는다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "노리개", "gather_qty_pct": 6, "craft_quality": 2}'::jsonb),
  ('n3_luck', '비취 노리개', 'norigae', 3, '복을 부르는 노리개. 귀한 전리품이 잘 나온다.', false, 'rare', 10, 3, true, 720, '{"trait": "노리개", "rare_loot_pct": 9}'::jsonb),
  ('n3_keen', '칠보 장도 노리개', 'norigae', 3, '작은 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', false, 'rare', 10, 3, true, 720, '{"trait": "노리개", "crit_pct": 6}'::jsonb),
  ('n3_plenty', '산호 노리개', 'norigae', 3, '풍요를 비는 노리개. 거두는 양과 솜씨가 는다.', false, 'rare', 10, 3, true, 720, '{"trait": "노리개", "gather_qty_pct": 9, "craft_quality": 3}'::jsonb),
  ('n4_luck', '금박 박쥐 노리개', 'norigae', 4, '복을 부르는 노리개. 귀한 전리품이 잘 나온다.', false, 'epic', 15, 4, true, 2080, '{"trait": "노리개", "rare_loot_pct": 12}'::jsonb),
  ('n4_keen', '백옥 장도 노리개', 'norigae', 4, '작은 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', false, 'epic', 15, 4, true, 2080, '{"trait": "노리개", "crit_pct": 8}'::jsonb),
  ('n4_plenty', '옥나비 노리개', 'norigae', 4, '풍요를 비는 노리개. 거두는 양과 솜씨가 는다.', false, 'epic', 15, 4, true, 2080, '{"trait": "노리개", "gather_qty_pct": 12, "craft_quality": 4}'::jsonb),
  ('n5_luck', '삼작 노리개', 'norigae', 5, '복을 부르는 노리개. 귀한 전리품이 잘 나온다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "노리개", "rare_loot_pct": 15}'::jsonb),
  ('n5_keen', '용각 장도 노리개', 'norigae', 5, '작은 장도를 단 노리개. 급소를 노리는 눈이 밝아진다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "노리개", "crit_pct": 10}'::jsonb),
  ('n5_plenty', '천도 노리개', 'norigae', 5, '풍요를 비는 노리개. 거두는 양과 솜씨가 는다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "노리개", "gather_qty_pct": 15, "craft_quality": 5}'::jsonb),
  ('m1_spell', '무명 부적낭', 'amulet', 1, '술식을 적은 부적을 품는다. 술법이 세진다.', false, 'common', 1, 1, true, 64, '{"trait": "호신부", "magic_pct": 3}'::jsonb),
  ('m1_ward', '주사 호신부', 'amulet', 1, '몸을 지키는 패. 받는 피해가 줄고 요괴가 먼저 노린다.', false, 'common', 1, 1, true, 64, '{"trait": "호신부", "incoming_damage_pct": -2, "presence": 4}'::jsonb),
  ('m1_purify', '쑥 향낭', 'amulet', 1, '맑은 향이 요기를 씻어 낸다. 침식이 덜하고 회복이 잘 된다.', false, 'common', 1, 1, true, 64, '{"trait": "호신부", "erosion_pct": -3, "healing_pct": 3}'::jsonb),
  ('m2_spell', '오색 부적낭', 'amulet', 2, '술식을 적은 부적을 품는다. 술법이 세진다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "호신부", "magic_pct": 6}'::jsonb),
  ('m2_ward', '동패 호신부', 'amulet', 2, '몸을 지키는 패. 받는 피해가 줄고 요괴가 먼저 노린다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "호신부", "incoming_damage_pct": -4, "presence": 8}'::jsonb),
  ('m2_purify', '백단 향낭', 'amulet', 2, '맑은 향이 요기를 씻어 낸다. 침식이 덜하고 회복이 잘 된다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "호신부", "erosion_pct": -6, "healing_pct": 6}'::jsonb),
  ('m3_spell', '비단 부적낭', 'amulet', 3, '술식을 적은 부적을 품는다. 술법이 세진다.', false, 'rare', 10, 3, true, 720, '{"trait": "호신부", "magic_pct": 9}'::jsonb),
  ('m3_ward', '철패 호신부', 'amulet', 3, '몸을 지키는 패. 받는 피해가 줄고 요괴가 먼저 노린다.', false, 'rare', 10, 3, true, 720, '{"trait": "호신부", "incoming_damage_pct": -6, "presence": 12}'::jsonb),
  ('m3_purify', '침향 향낭', 'amulet', 3, '맑은 향이 요기를 씻어 낸다. 침식이 덜하고 회복이 잘 된다.', false, 'rare', 10, 3, true, 720, '{"trait": "호신부", "erosion_pct": -9, "healing_pct": 9}'::jsonb),
  ('m4_spell', '옥 부적낭', 'amulet', 4, '술식을 적은 부적을 품는다. 술법이 세진다.', false, 'epic', 15, 4, true, 2080, '{"trait": "호신부", "magic_pct": 12}'::jsonb),
  ('m4_ward', '금강 호신부', 'amulet', 4, '몸을 지키는 패. 받는 피해가 줄고 요괴가 먼저 노린다.', false, 'epic', 15, 4, true, 2080, '{"trait": "호신부", "incoming_damage_pct": -8, "presence": 16}'::jsonb),
  ('m4_purify', '용연향 향낭', 'amulet', 4, '맑은 향이 요기를 씻어 낸다. 침식이 덜하고 회복이 잘 된다.', false, 'epic', 15, 4, true, 2080, '{"trait": "호신부", "erosion_pct": -12, "healing_pct": 12}'::jsonb),
  ('m5_spell', '천사 부적낭', 'amulet', 5, '술식을 적은 부적을 품는다. 술법이 세진다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "호신부", "magic_pct": 15}'::jsonb),
  ('m5_ward', '사천왕 호신부', 'amulet', 5, '몸을 지키는 패. 받는 피해가 줄고 요괴가 먼저 노린다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "호신부", "incoming_damage_pct": -10, "presence": 20}'::jsonb),
  ('m5_purify', '감로 향낭', 'amulet', 5, '맑은 향이 요기를 씻어 낸다. 침식이 덜하고 회복이 잘 된다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "호신부", "erosion_pct": -15, "healing_pct": 15}'::jsonb),
  ('k1_hide', '각시탈', 'mask', 1, '얼굴을 감추고 기척을 죽인다. 요괴의 눈에 덜 띄고 덜 마주친다.', false, 'common', 1, 1, true, 64, '{"trait": "탈", "presence": -10, "encounter_pct": -3}'::jsonb),
  ('k1_awe', '양반탈', 'mask', 1, '무서운 얼굴로 요괴를 노려본다. 요괴가 먼저 덤비지만 기세가 오른다.', false, 'common', 1, 1, true, 64, '{"trait": "탈", "presence": 10, "combat_damage_pct": 1.5}'::jsonb),
  ('k1_ghost', '말뚝이탈', 'mask', 1, '귀신 얼굴의 탈. 요괴를 불러들이고 귀한 것을 끌어낸다.', false, 'common', 1, 1, true, 64, '{"trait": "탈", "encounter_pct": 3, "rare_loot_pct": 2}'::jsonb),
  ('k2_hide', '부네탈', 'mask', 2, '얼굴을 감추고 기척을 죽인다. 요괴의 눈에 덜 띄고 덜 마주친다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "탈", "presence": -20, "encounter_pct": -6}'::jsonb),
  ('k2_awe', '장군탈', 'mask', 2, '무서운 얼굴로 요괴를 노려본다. 요괴가 먼저 덤비지만 기세가 오른다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "탈", "presence": 20, "combat_damage_pct": 3}'::jsonb),
  ('k2_ghost', '취발이탈', 'mask', 2, '귀신 얼굴의 탈. 요괴를 불러들이고 귀한 것을 끌어낸다.', false, 'uncommon', 5, 2, true, 192, '{"trait": "탈", "encounter_pct": 6, "rare_loot_pct": 4}'::jsonb),
  ('k3_hide', '소무탈', 'mask', 3, '얼굴을 감추고 기척을 죽인다. 요괴의 눈에 덜 띄고 덜 마주친다.', false, 'rare', 10, 3, true, 720, '{"trait": "탈", "presence": -30, "encounter_pct": -9}'::jsonb),
  ('k3_awe', '방상씨탈', 'mask', 3, '무서운 얼굴로 요괴를 노려본다. 요괴가 먼저 덤비지만 기세가 오른다.', false, 'rare', 10, 3, true, 720, '{"trait": "탈", "presence": 30, "combat_damage_pct": 4.5}'::jsonb),
  ('k3_ghost', '먹중탈', 'mask', 3, '귀신 얼굴의 탈. 요괴를 불러들이고 귀한 것을 끌어낸다.', false, 'rare', 10, 3, true, 720, '{"trait": "탈", "encounter_pct": 9, "rare_loot_pct": 6}'::jsonb),
  ('k4_hide', '처용탈', 'mask', 4, '얼굴을 감추고 기척을 죽인다. 요괴의 눈에 덜 띄고 덜 마주친다.', false, 'epic', 15, 4, true, 2080, '{"trait": "탈", "presence": -40, "encounter_pct": -12}'::jsonb),
  ('k4_awe', '사자탈', 'mask', 4, '무서운 얼굴로 요괴를 노려본다. 요괴가 먼저 덤비지만 기세가 오른다.', false, 'epic', 15, 4, true, 2080, '{"trait": "탈", "presence": 40, "combat_damage_pct": 6}'::jsonb),
  ('k4_ghost', '노장탈', 'mask', 4, '귀신 얼굴의 탈. 요괴를 불러들이고 귀한 것을 끌어낸다.', false, 'epic', 15, 4, true, 2080, '{"trait": "탈", "encounter_pct": 12, "rare_loot_pct": 8}'::jsonb),
  ('k5_hide', '무면탈', 'mask', 5, '얼굴을 감추고 기척을 죽인다. 요괴의 눈에 덜 띄고 덜 마주친다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "탈", "presence": -50, "encounter_pct": -15}'::jsonb),
  ('k5_awe', '야차탈', 'mask', 5, '무서운 얼굴로 요괴를 노려본다. 요괴가 먼저 덤비지만 기세가 오른다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "탈", "presence": 50, "combat_damage_pct": 7.5}'::jsonb),
  ('k5_ghost', '나찰탈', 'mask', 5, '귀신 얼굴의 탈. 요괴를 불러들이고 귀한 것을 끌어낸다.', false, 'legendary', 20, 5, true, 5600, '{"trait": "탈", "encounter_pct": 15, "rare_loot_pct": 10}'::jsonb)
on conflict (item_id) do nothing;

insert into public.world_crafting_recipes(recipe_id, recipe_name, output_item, output_qty, ingredients, required_tool, required_tool_tier, required_location, description, minimum_level, recipe_difficulty) values
  ('r_w_melee2_heavy', '쌍날 대부 만들기', 'w_melee2_heavy', 1, '{"iron_ingot": 3, "lumber": 1}'::jsonb, null, 1, '철벽 고찰', '쌍날 대부을(를) 만든다.', 5, 2),
  ('r_w_melee2_keen', '은월 장검 만들기', 'w_melee2_keen', 1, '{"iron_ingot": 3, "lumber": 1}'::jsonb, null, 1, '철벽 고찰', '은월 장검을(를) 만든다.', 5, 2),
  ('r_w_melee2_silent', '연막 단검 만들기', 'w_melee2_silent', 1, '{"iron_ingot": 3, "lumber": 1}'::jsonb, null, 1, '철벽 고찰', '연막 단검을(를) 만든다.', 5, 2),
  ('r_w_melee3_heavy', '파산 철편 만들기', 'w_melee3_heavy', 1, '{"steel_ingot": 2, "reinforced_lumber": 1, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '파산 철편을(를) 만든다.', 10, 3),
  ('r_w_melee3_keen', '청강 쌍검 만들기', 'w_melee3_keen', 1, '{"steel_ingot": 2, "reinforced_lumber": 1, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '청강 쌍검을(를) 만든다.', 10, 3),
  ('r_w_melee3_silent', '무영 소도 만들기', 'w_melee3_silent', 1, '{"steel_ingot": 2, "reinforced_lumber": 1, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '무영 소도을(를) 만든다.', 10, 3),
  ('r_w_melee4_heavy', '진산 대철퇴 만들기', 'w_melee4_heavy', 1, '{"steel_ingot": 3, "thunder_ore": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '진산 대철퇴을(를) 만든다.', 15, 4),
  ('r_w_melee4_keen', '비연 청룡검 만들기', 'w_melee4_keen', 1, '{"steel_ingot": 3, "thunder_ore": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '비연 청룡검을(를) 만든다.', 15, 4),
  ('r_w_melee4_silent', '야음 비수 만들기', 'w_melee4_silent', 1, '{"steel_ingot": 3, "thunder_ore": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '야음 비수을(를) 만든다.', 15, 4),
  ('r_w_melee4_base', '용린 대도 만들기', 'w_melee4_base', 1, '{"steel_ingot": 3, "thunder_ore": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '용린 대도을(를) 만든다.', 15, 4),
  ('r_w_melee5_keen', '일섬 신검 만들기', 'w_melee5_keen', 1, '{"thunder_ore": 4, "steel_ingot": 3, "spirit_core": 2, "monster_core": 2}'::jsonb, null, 1, '무극 관성대', '일섬 신검을(를) 만든다.', 20, 5),
  ('r_w_melee5_base', '천뢰 언월도 만들기', 'w_melee5_base', 1, '{"thunder_ore": 4, "steel_ingot": 3, "spirit_core": 2, "monster_core": 2}'::jsonb, null, 1, '무극 관성대', '천뢰 언월도을(를) 만든다.', 20, 5),
  ('r_w_ranged2_heavy', '철태 쇠뇌 만들기', 'w_ranged2_heavy', 1, '{"reinforced_lumber": 2, "spirit_thread": 1}'::jsonb, null, 1, '철벽 고찰', '철태 쇠뇌을(를) 만든다.', 5, 2),
  ('r_w_ranged2_keen', '학익 각궁 만들기', 'w_ranged2_keen', 1, '{"reinforced_lumber": 2, "spirit_thread": 1}'::jsonb, null, 1, '철벽 고찰', '학익 각궁을(를) 만든다.', 5, 2),
  ('r_w_ranged2_silent', '갈대 취관 만들기', 'w_ranged2_silent', 1, '{"reinforced_lumber": 2, "spirit_thread": 1}'::jsonb, null, 1, '철벽 고찰', '갈대 취관을(를) 만든다.', 5, 2),
  ('r_w_ranged3_heavy', '연발 쇠뇌 만들기', 'w_ranged3_heavy', 1, '{"reinforced_lumber": 2, "sky_feather": 2, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '연발 쇠뇌을(를) 만든다.', 10, 3),
  ('r_w_ranged3_keen', '천리 각궁 만들기', 'w_ranged3_keen', 1, '{"reinforced_lumber": 2, "sky_feather": 2, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '천리 각궁을(를) 만든다.', 10, 3),
  ('r_w_ranged3_silent', '무음 비궁 만들기', 'w_ranged3_silent', 1, '{"reinforced_lumber": 2, "sky_feather": 2, "monster_core": 1}'::jsonb, null, 1, '철벽 고찰', '무음 비궁을(를) 만든다.', 10, 3),
  ('r_w_ranged4_heavy', '팔우 대노 만들기', 'w_ranged4_heavy', 1, '{"spirit_bark": 2, "sky_feather": 3, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '팔우 대노을(를) 만든다.', 15, 4),
  ('r_w_ranged4_keen', '관일궁 만들기', 'w_ranged4_keen', 1, '{"spirit_bark": 2, "sky_feather": 3, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '관일궁을(를) 만든다.', 15, 4),
  ('r_w_ranged4_silent', '월영 단궁 만들기', 'w_ranged4_silent', 1, '{"spirit_bark": 2, "sky_feather": 3, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '월영 단궁을(를) 만든다.', 15, 4),
  ('r_w_ranged4_base', '흑룡 장궁 만들기', 'w_ranged4_base', 1, '{"spirit_bark": 2, "sky_feather": 3, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '흑룡 장궁을(를) 만든다.', 15, 4),
  ('r_w_ranged5_keen', '성시 신궁 만들기', 'w_ranged5_keen', 1, '{"spirit_bark": 3, "sky_feather": 4, "spirit_core": 2, "star_sand": 2}'::jsonb, null, 1, '무극 관성대', '성시 신궁을(를) 만든다.', 20, 5),
  ('r_w_ranged5_base', '사일궁 만들기', 'w_ranged5_base', 1, '{"spirit_bark": 3, "sky_feather": 4, "spirit_core": 2, "star_sand": 2}'::jsonb, null, 1, '무극 관성대', '사일궁을(를) 만든다.', 20, 5),
  ('r_w_magic2_heavy', '청동 법륜 만들기', 'w_magic2_heavy', 1, '{"spirit_glass": 2, "seal_paper": 2}'::jsonb, null, 1, '철벽 고찰', '청동 법륜을(를) 만든다.', 5, 2),
  ('r_w_magic2_keen', '팔괘 나경 만들기', 'w_magic2_keen', 1, '{"spirit_glass": 2, "seal_paper": 2}'::jsonb, null, 1, '철벽 고찰', '팔괘 나경을(를) 만든다.', 5, 2),
  ('r_w_magic2_silent', '연기 향로 만들기', 'w_magic2_silent', 1, '{"spirit_glass": 2, "seal_paper": 2}'::jsonb, null, 1, '철벽 고찰', '연기 향로을(를) 만든다.', 5, 2),
  ('r_w_magic3_heavy', '뇌문 법인 만들기', 'w_magic3_heavy', 1, '{"mirror_shard": 2, "rune_plate": 1, "spirit_glass": 1}'::jsonb, null, 1, '철벽 고찰', '뇌문 법인을(를) 만든다.', 10, 3),
  ('r_w_magic3_keen', '북두 칠성 법검 만들기', 'w_magic3_keen', 1, '{"mirror_shard": 2, "rune_plate": 1, "spirit_glass": 1}'::jsonb, null, 1, '철벽 고찰', '북두 칠성 법검을(를) 만든다.', 10, 3),
  ('r_w_magic3_silent', '몽환 법선 만들기', 'w_magic3_silent', 1, '{"mirror_shard": 2, "rune_plate": 1, "spirit_glass": 1}'::jsonb, null, 1, '철벽 고찰', '몽환 법선을(를) 만든다.', 10, 3),
  ('r_w_magic4_heavy', '진령 대종 만들기', 'w_magic4_heavy', 1, '{"rune_plate": 2, "star_sand": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '진령 대종을(를) 만든다.', 15, 4),
  ('r_w_magic4_keen', '천기 산반 만들기', 'w_magic4_keen', 1, '{"rune_plate": 2, "star_sand": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '천기 산반을(를) 만든다.', 15, 4),
  ('r_w_magic4_silent', '유령 등롱 만들기', 'w_magic4_silent', 1, '{"rune_plate": 2, "star_sand": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '유령 등롱을(를) 만든다.', 15, 4),
  ('r_w_magic4_base', '현무 법경 만들기', 'w_magic4_base', 1, '{"rune_plate": 2, "star_sand": 2, "spirit_core": 1}'::jsonb, null, 1, '철벽 고찰', '현무 법경을(를) 만든다.', 15, 4),
  ('r_w_magic5_keen', '천명 신산 만들기', 'w_magic5_keen', 1, '{"rune_plate": 3, "star_sand": 3, "spirit_core": 2, "mirror_shard": 2}'::jsonb, null, 1, '무극 관성대', '천명 신산을(를) 만든다.', 20, 5),
  ('r_w_magic5_base', '태극 법륜 만들기', 'w_magic5_base', 1, '{"rune_plate": 3, "star_sand": 3, "spirit_core": 2, "mirror_shard": 2}'::jsonb, null, 1, '무극 관성대', '태극 법륜을(를) 만든다.', 20, 5),
  ('r_a2_iron', '두정갑 만들기', 'a2_iron', 1, '{"beast_hide": 3, "iron_ingot": 1}'::jsonb, null, 1, '백골 장터', '두정갑을(를) 만든다.', 5, 2),
  ('r_a2_light', '가죽 철릭 만들기', 'a2_light', 1, '{"beast_hide": 3, "iron_ingot": 1}'::jsonb, null, 1, '백골 장터', '가죽 철릭을(를) 만든다.', 5, 2),
  ('r_a2_robe', '수결 도포 만들기', 'a2_robe', 1, '{"beast_hide": 3, "iron_ingot": 1}'::jsonb, null, 1, '백골 장터', '수결 도포을(를) 만든다.', 5, 2),
  ('r_a2_shade', '야행 경의 만들기', 'a2_shade', 1, '{"beast_hide": 3, "iron_ingot": 1}'::jsonb, null, 1, '백골 장터', '야행 경의을(를) 만든다.', 5, 2),
  ('r_a3_iron', '철찰갑 만들기', 'a3_iron', 1, '{"reinforced_leather": 2, "steel_ingot": 1, "silk": 2}'::jsonb, null, 1, '백골 장터', '철찰갑을(를) 만든다.', 10, 3),
  ('r_a3_light', '영사 철릭 만들기', 'a3_light', 1, '{"reinforced_leather": 2, "steel_ingot": 1, "silk": 2}'::jsonb, null, 1, '백골 장터', '영사 철릭을(를) 만든다.', 10, 3),
  ('r_a3_robe', '운학 법의 만들기', 'a3_robe', 1, '{"reinforced_leather": 2, "steel_ingot": 1, "silk": 2}'::jsonb, null, 1, '백골 장터', '운학 법의을(를) 만든다.', 10, 3),
  ('r_a3_shade', '묵영 야행복 만들기', 'a3_shade', 1, '{"reinforced_leather": 2, "steel_ingot": 1, "silk": 2}'::jsonb, null, 1, '백골 장터', '묵영 야행복을(를) 만든다.', 10, 3),
  ('r_a4_iron', '흑철 두정갑 만들기', 'a4_iron', 1, '{"reinforced_leather": 3, "steel_ingot": 2, "spirit_core": 1}'::jsonb, null, 1, '백골 장터', '흑철 두정갑을(를) 만든다.', 15, 4),
  ('r_a4_light', '비연 경갑 만들기', 'a4_light', 1, '{"reinforced_leather": 3, "steel_ingot": 2, "spirit_core": 1}'::jsonb, null, 1, '백골 장터', '비연 경갑을(를) 만든다.', 15, 4),
  ('r_a4_robe', '청룡 법포 만들기', 'a4_robe', 1, '{"reinforced_leather": 3, "steel_ingot": 2, "spirit_core": 1}'::jsonb, null, 1, '백골 장터', '청룡 법포을(를) 만든다.', 15, 4),
  ('r_a4_shade', '월영 은신복 만들기', 'a4_shade', 1, '{"reinforced_leather": 3, "steel_ingot": 2, "spirit_core": 1}'::jsonb, null, 1, '백골 장터', '월영 은신복을(를) 만든다.', 15, 4),
  ('r_a5_light', '천의 경갑 만들기', 'a5_light', 1, '{"reinforced_leather": 4, "steel_ingot": 3, "spirit_core": 2, "jade_shard": 2}'::jsonb, null, 1, '무극 관성대', '천의 경갑을(를) 만든다.', 20, 5),
  ('r_t2_gather', '약초꾼 망태 만들기', 't2_gather', 1, '{"river_reed": 3, "talisman_thread": 1}'::jsonb, null, 1, '야행국 본부 정청', '약초꾼 망태을(를) 만든다.', 5, 2),
  ('r_t3_gather', '청강 채집도 만들기', 't3_gather', 1, '{"steel_ingot": 1, "reinforced_lumber": 1}'::jsonb, null, 1, '야행국 본부 정청', '청강 채집도을(를) 만든다.', 10, 3),
  ('r_t4_gather', '영맥 곡괭이 만들기', 't4_gather', 1, '{"steel_ingot": 2, "thunder_ore": 1, "spirit_bark": 1}'::jsonb, null, 1, '야행국 본부 정청', '영맥 곡괭이을(를) 만든다.', 15, 4),
  ('r_t5_gather', '천공 채집도 만들기', 't5_gather', 1, '{"thunder_ore": 2, "spirit_core": 1, "star_sand": 1}'::jsonb, null, 1, '무극 관성대', '천공 채집도을(를) 만든다.', 20, 5),
  ('r_h2_guard', '전립 만들기', 'h2_guard', 1, '{"silk": 2, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '전립을(를) 만든다.', 5, 2),
  ('r_h2_calm', '흑립 만들기', 'h2_calm', 1, '{"silk": 2, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '흑립을(를) 만든다.', 5, 2),
  ('r_h2_wise', '정자관 만들기', 'h2_wise', 1, '{"silk": 2, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '정자관을(를) 만든다.', 5, 2),
  ('r_h3_guard', '철전립 만들기', 'h3_guard', 1, '{"silk": 2, "jade_shard": 1, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '철전립을(를) 만든다.', 10, 3),
  ('r_h3_calm', '학창 관모 만들기', 'h3_calm', 1, '{"silk": 2, "jade_shard": 1, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '학창 관모을(를) 만든다.', 10, 3),
  ('r_h3_wise', '동파관 만들기', 'h3_wise', 1, '{"silk": 2, "jade_shard": 1, "lacquer": 1}'::jsonb, null, 1, '백등 야시장', '동파관을(를) 만든다.', 10, 3),
  ('r_h4_guard', '주작 투구 만들기', 'h4_guard', 1, '{"spirit_thread": 2, "jade_shard": 2, "spirit_core": 1}'::jsonb, null, 1, '백등 야시장', '주작 투구을(를) 만든다.', 15, 4),
  ('r_h4_calm', '백옥 관모 만들기', 'h4_calm', 1, '{"spirit_thread": 2, "jade_shard": 2, "spirit_core": 1}'::jsonb, null, 1, '백등 야시장', '백옥 관모을(를) 만든다.', 15, 4),
  ('r_h4_wise', '문사 금관 만들기', 'h4_wise', 1, '{"spirit_thread": 2, "jade_shard": 2, "spirit_core": 1}'::jsonb, null, 1, '백등 야시장', '문사 금관을(를) 만든다.', 15, 4),
  ('r_h5_calm', '야행 관모 만들기', 'h5_calm', 1, '{"spirit_thread": 3, "jade_shard": 3, "spirit_core": 1, "star_sand": 1}'::jsonb, null, 1, '무극 관성대', '야행 관모을(를) 만든다.', 20, 5),
  ('r_s2_road', '행전 짚신 만들기', 's2_road', 1, '{"beast_hide": 2, "river_reed": 2}'::jsonb, null, 1, '구름나루', '행전 짚신을(를) 만든다.', 5, 2),
  ('r_s2_swift', '가죽 미투리 만들기', 's2_swift', 1, '{"beast_hide": 2, "river_reed": 2}'::jsonb, null, 1, '구름나루', '가죽 미투리을(를) 만든다.', 5, 2),
  ('r_s2_sturdy', '쇠징 신 만들기', 's2_sturdy', 1, '{"beast_hide": 2, "river_reed": 2}'::jsonb, null, 1, '구름나루', '쇠징 신을(를) 만든다.', 5, 2),
  ('r_s3_road', '구름 목화 만들기', 's3_road', 1, '{"reinforced_leather": 1, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '구름 목화을(를) 만든다.', 10, 3),
  ('r_s3_swift', '비연화 만들기', 's3_swift', 1, '{"reinforced_leather": 1, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '비연화을(를) 만든다.', 10, 3),
  ('r_s3_sturdy', '철목화 만들기', 's3_sturdy', 1, '{"reinforced_leather": 1, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '철목화을(를) 만든다.', 10, 3),
  ('r_s4_road', '운혜 만들기', 's4_road', 1, '{"reinforced_leather": 2, "sky_feather": 2, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '운혜을(를) 만든다.', 15, 4),
  ('r_s4_swift', '풍운화 만들기', 's4_swift', 1, '{"reinforced_leather": 2, "sky_feather": 2, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '풍운화을(를) 만든다.', 15, 4),
  ('r_s4_sturdy', '흑철화 만들기', 's4_sturdy', 1, '{"reinforced_leather": 2, "sky_feather": 2, "cloud_cotton": 2}'::jsonb, null, 1, '구름나루', '흑철화을(를) 만든다.', 15, 4),
  ('r_s5_swift', '비천화 만들기', 's5_swift', 1, '{"reinforced_leather": 3, "sky_feather": 3, "spirit_core": 1}'::jsonb, null, 1, '무극 관성대', '비천화을(를) 만든다.', 20, 5),
  ('r_n2_luck', '호박 노리개 만들기', 'n2_luck', 1, '{"talisman_thread": 2, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '호박 노리개을(를) 만든다.', 5, 2),
  ('r_n2_keen', '은장도 노리개 만들기', 'n2_keen', 1, '{"talisman_thread": 2, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '은장도 노리개을(를) 만든다.', 5, 2),
  ('r_n2_plenty', '오색 술 노리개 만들기', 'n2_plenty', 1, '{"talisman_thread": 2, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '오색 술 노리개을(를) 만든다.', 5, 2),
  ('r_n3_luck', '비취 노리개 만들기', 'n3_luck', 1, '{"jade_shard": 1, "silk": 1, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '비취 노리개을(를) 만든다.', 10, 3),
  ('r_n3_keen', '칠보 장도 노리개 만들기', 'n3_keen', 1, '{"jade_shard": 1, "silk": 1, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '칠보 장도 노리개을(를) 만든다.', 10, 3),
  ('r_n3_plenty', '산호 노리개 만들기', 'n3_plenty', 1, '{"jade_shard": 1, "silk": 1, "cinnabar": 1}'::jsonb, null, 1, '십삼문 암시장', '산호 노리개을(를) 만든다.', 10, 3),
  ('r_n4_luck', '금박 박쥐 노리개 만들기', 'n4_luck', 1, '{"jade_shard": 2, "ember_crystal": 1, "spirit_thread": 1}'::jsonb, null, 1, '십삼문 암시장', '금박 박쥐 노리개을(를) 만든다.', 15, 4),
  ('r_n4_keen', '백옥 장도 노리개 만들기', 'n4_keen', 1, '{"jade_shard": 2, "ember_crystal": 1, "spirit_thread": 1}'::jsonb, null, 1, '십삼문 암시장', '백옥 장도 노리개을(를) 만든다.', 15, 4),
  ('r_n4_plenty', '옥나비 노리개 만들기', 'n4_plenty', 1, '{"jade_shard": 2, "ember_crystal": 1, "spirit_thread": 1}'::jsonb, null, 1, '십삼문 암시장', '옥나비 노리개을(를) 만든다.', 15, 4),
  ('r_n5_luck', '삼작 노리개 만들기', 'n5_luck', 1, '{"jade_shard": 3, "ember_crystal": 2, "star_sand": 1}'::jsonb, null, 1, '무극 관성대', '삼작 노리개을(를) 만든다.', 20, 5),
  ('r_n5_keen', '용각 장도 노리개 만들기', 'n5_keen', 1, '{"jade_shard": 3, "ember_crystal": 2, "star_sand": 1}'::jsonb, null, 1, '무극 관성대', '용각 장도 노리개을(를) 만든다.', 20, 5),
  ('r_m2_spell', '오색 부적낭 만들기', 'm2_spell', 1, '{"seal_paper": 2, "cinnabar": 1}'::jsonb, null, 1, '장서각 지하서고', '오색 부적낭을(를) 만든다.', 5, 2),
  ('r_m2_ward', '동패 호신부 만들기', 'm2_ward', 1, '{"seal_paper": 2, "cinnabar": 1}'::jsonb, null, 1, '장서각 지하서고', '동패 호신부을(를) 만든다.', 5, 2),
  ('r_m2_purify', '백단 향낭 만들기', 'm2_purify', 1, '{"seal_paper": 2, "cinnabar": 1}'::jsonb, null, 1, '장서각 지하서고', '백단 향낭을(를) 만든다.', 5, 2),
  ('r_m3_spell', '비단 부적낭 만들기', 'm3_spell', 1, '{"fine_paper": 2, "sealing_ink": 1, "ward_fragment": 1}'::jsonb, null, 1, '장서각 지하서고', '비단 부적낭을(를) 만든다.', 10, 3),
  ('r_m3_ward', '철패 호신부 만들기', 'm3_ward', 1, '{"fine_paper": 2, "sealing_ink": 1, "ward_fragment": 1}'::jsonb, null, 1, '장서각 지하서고', '철패 호신부을(를) 만든다.', 10, 3),
  ('r_m3_purify', '침향 향낭 만들기', 'm3_purify', 1, '{"fine_paper": 2, "sealing_ink": 1, "ward_fragment": 1}'::jsonb, null, 1, '장서각 지하서고', '침향 향낭을(를) 만든다.', 10, 3),
  ('r_m4_spell', '옥 부적낭 만들기', 'm4_spell', 1, '{"fine_paper": 2, "ward_fragment": 2, "spirit_core": 1}'::jsonb, null, 1, '장서각 지하서고', '옥 부적낭을(를) 만든다.', 15, 4),
  ('r_m4_ward', '금강 호신부 만들기', 'm4_ward', 1, '{"fine_paper": 2, "ward_fragment": 2, "spirit_core": 1}'::jsonb, null, 1, '장서각 지하서고', '금강 호신부을(를) 만든다.', 15, 4),
  ('r_m4_purify', '용연향 향낭 만들기', 'm4_purify', 1, '{"fine_paper": 2, "ward_fragment": 2, "spirit_core": 1}'::jsonb, null, 1, '장서각 지하서고', '용연향 향낭을(를) 만든다.', 15, 4),
  ('r_m5_spell', '천사 부적낭 만들기', 'm5_spell', 1, '{"ward_fragment": 3, "spirit_core": 2, "star_sand": 1}'::jsonb, null, 1, '무극 관성대', '천사 부적낭을(를) 만든다.', 20, 5),
  ('r_k2_hide', '부네탈 만들기', 'k2_hide', 1, '{"lumber": 2, "lacquer": 1}'::jsonb, null, 1, '잔불촌', '부네탈을(를) 만든다.', 5, 2),
  ('r_k2_awe', '장군탈 만들기', 'k2_awe', 1, '{"lumber": 2, "lacquer": 1}'::jsonb, null, 1, '잔불촌', '장군탈을(를) 만든다.', 5, 2),
  ('r_k2_ghost', '취발이탈 만들기', 'k2_ghost', 1, '{"lumber": 2, "lacquer": 1}'::jsonb, null, 1, '잔불촌', '취발이탈을(를) 만든다.', 5, 2),
  ('r_k3_hide', '소무탈 만들기', 'k3_hide', 1, '{"lumber": 1, "lacquer": 1, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '소무탈을(를) 만든다.', 10, 3),
  ('r_k3_awe', '방상씨탈 만들기', 'k3_awe', 1, '{"lumber": 1, "lacquer": 1, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '방상씨탈을(를) 만든다.', 10, 3),
  ('r_k3_ghost', '먹중탈 만들기', 'k3_ghost', 1, '{"lumber": 1, "lacquer": 1, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '먹중탈을(를) 만든다.', 10, 3),
  ('r_k4_hide', '처용탈 만들기', 'k4_hide', 1, '{"spirit_bark": 1, "shadow_fang": 2, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '처용탈을(를) 만든다.', 15, 4),
  ('r_k4_awe', '사자탈 만들기', 'k4_awe', 1, '{"spirit_bark": 1, "shadow_fang": 2, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '사자탈을(를) 만든다.', 15, 4),
  ('r_k4_ghost', '노장탈 만들기', 'k4_ghost', 1, '{"spirit_bark": 1, "shadow_fang": 2, "ghost_ash": 2}'::jsonb, null, 1, '잔불촌', '노장탈을(를) 만든다.', 15, 4),
  ('r_k5_hide', '무면탈 만들기', 'k5_hide', 1, '{"spirit_bark": 2, "shadow_fang": 3, "spirit_core": 1}'::jsonb, null, 1, '무극 관성대', '무면탈을(를) 만든다.', 20, 5)
on conflict (recipe_id) do nothing;

insert into public.world_gear_drops(item_id, mechanic_key, level_min, level_max, chance_normal, chance_elite, chance_guardian) values
  ('w_melee1_heavy', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee1_heavy', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee1_keen', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee1_keen', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee1_silent', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee1_silent', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('w_melee2_heavy', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee2_heavy', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee2_keen', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee2_keen', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee2_silent', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee2_silent', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('w_melee3_heavy', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee3_heavy', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee3_keen', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee3_keen', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee3_silent', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee3_silent', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('w_melee4_heavy', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_heavy', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_keen', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_keen', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_silent', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_silent', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_base', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee4_base', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('w_melee5_heavy', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_heavy', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_heavy', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_melee5_keen', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_keen', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_keen', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_melee5_silent', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_silent', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_silent', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_melee5_base', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_base', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('w_melee5_base', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_ranged1_heavy', 'aerial', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged1_heavy', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged1_keen', 'aerial', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged1_keen', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged1_silent', 'aerial', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged1_silent', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('w_ranged2_heavy', 'aerial', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged2_heavy', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged2_keen', 'aerial', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged2_keen', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged2_silent', 'aerial', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged2_silent', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('w_ranged3_heavy', 'aerial', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged3_heavy', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged3_keen', 'aerial', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged3_keen', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged3_silent', 'aerial', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged3_silent', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('w_ranged4_heavy', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_heavy', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_keen', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_keen', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_silent', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_silent', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_base', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged4_base', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('w_ranged5_heavy', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_heavy', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_heavy', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_ranged5_keen', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_keen', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_keen', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_ranged5_silent', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_silent', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_silent', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_ranged5_base', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_base', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('w_ranged5_base', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_magic1_heavy', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_heavy', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_heavy', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_keen', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_keen', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_keen', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_silent', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_silent', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic1_silent', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05),
  ('w_magic2_heavy', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_heavy', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_heavy', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_keen', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_keen', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_keen', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_silent', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_silent', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic2_silent', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06),
  ('w_magic3_heavy', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_heavy', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_heavy', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_keen', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_keen', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_keen', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_silent', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_silent', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic3_silent', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05),
  ('w_magic4_heavy', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_heavy', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_heavy', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_keen', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_keen', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_keen', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_silent', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_silent', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_silent', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_base', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_base', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic4_base', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('w_magic5_heavy', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_heavy', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_heavy', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_heavy', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_magic5_keen', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_keen', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_keen', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_keen', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_magic5_silent', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_silent', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_silent', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_silent', 'boss', 20, 40, 0, 0.01, 0.03),
  ('w_magic5_base', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_base', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_base', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('w_magic5_base', 'boss', 20, 40, 0, 0.01, 0.03),
  ('a1_iron', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('a1_light', 'aerial', 1, 6, 0.015, 0.03, 0.05),
  ('a1_light', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('a1_robe', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('a1_robe', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('a1_shade', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('a2_iron', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('a2_light', 'aerial', 3, 12, 0.012, 0.03, 0.06),
  ('a2_light', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('a2_robe', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('a2_robe', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('a2_shade', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('a3_iron', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('a3_light', 'aerial', 8, 18, 0.006, 0.025, 0.05),
  ('a3_light', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('a3_robe', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('a3_robe', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('a3_shade', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('a4_iron', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('a4_light', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('a4_light', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('a4_robe', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('a4_robe', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('a4_shade', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('a5_iron', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('a5_iron', 'boss', 20, 40, 0, 0.01, 0.03),
  ('a5_light', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('a5_light', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('a5_light', 'boss', 20, 40, 0, 0.01, 0.03),
  ('a5_robe', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('a5_robe', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('a5_robe', 'boss', 20, 40, 0, 0.01, 0.03),
  ('a5_shade', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('a5_shade', 'boss', 20, 40, 0, 0.01, 0.03),
  ('t2_gather', 'toxic', 3, 12, 0.012, 0.03, 0.06),
  ('t2_gather', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('t3_gather', 'toxic', 8, 18, 0.006, 0.025, 0.05),
  ('t3_gather', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('t4_gather', 'toxic', 13, 24, 0.004, 0.012, 0.05),
  ('t4_gather', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('t5_gather', 'toxic', 20, 40, 0.002, 0.006, 0.03),
  ('t5_gather', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('t5_gather', 'boss', 20, 40, 0, 0.01, 0.03),
  ('h1_guard', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('h1_calm', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('h1_calm', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05),
  ('h1_wise', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('h1_wise', 'reflect', 1, 6, 0.015, 0.03, 0.05),
  ('h2_guard', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('h2_calm', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('h2_calm', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06),
  ('h2_wise', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('h2_wise', 'reflect', 3, 12, 0.012, 0.03, 0.06),
  ('h3_guard', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('h3_calm', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('h3_calm', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05),
  ('h3_wise', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('h3_wise', 'reflect', 8, 18, 0.006, 0.025, 0.05),
  ('h4_guard', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('h4_calm', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('h4_calm', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('h4_wise', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('h4_wise', 'reflect', 13, 24, 0.004, 0.012, 0.05),
  ('h5_guard', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('h5_guard', 'boss', 20, 40, 0, 0.01, 0.03),
  ('h5_calm', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('h5_calm', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('h5_calm', 'boss', 20, 40, 0, 0.01, 0.03),
  ('h5_wise', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('h5_wise', 'reflect', 20, 40, 0.002, 0.006, 0.03),
  ('h5_wise', 'boss', 20, 40, 0, 0.01, 0.03),
  ('s1_road', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('s1_road', 'tide', 1, 6, 0.015, 0.03, 0.05),
  ('s1_swift', 'aerial', 1, 6, 0.015, 0.03, 0.05),
  ('s1_sturdy', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('s2_road', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('s2_road', 'tide', 3, 12, 0.012, 0.03, 0.06),
  ('s2_swift', 'aerial', 3, 12, 0.012, 0.03, 0.06),
  ('s2_sturdy', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('s3_road', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('s3_road', 'tide', 8, 18, 0.006, 0.025, 0.05),
  ('s3_swift', 'aerial', 8, 18, 0.006, 0.025, 0.05),
  ('s3_sturdy', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('s4_road', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('s4_road', 'tide', 13, 24, 0.004, 0.012, 0.05),
  ('s4_swift', 'aerial', 13, 24, 0.004, 0.012, 0.05),
  ('s4_sturdy', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('s5_road', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('s5_road', 'tide', 20, 40, 0.002, 0.006, 0.03),
  ('s5_road', 'boss', 20, 40, 0, 0.01, 0.03),
  ('s5_swift', 'aerial', 20, 40, 0.002, 0.006, 0.03),
  ('s5_swift', 'boss', 20, 40, 0, 0.01, 0.03),
  ('s5_sturdy', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('s5_sturdy', 'boss', 20, 40, 0, 0.01, 0.03),
  ('n1_luck', 'tide', 1, 6, 0.015, 0.03, 0.05),
  ('n1_luck', 'reflect', 1, 6, 0.015, 0.03, 0.05),
  ('n1_keen', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('n1_plenty', 'toxic', 1, 6, 0.015, 0.03, 0.05),
  ('n1_plenty', 'swarm', 1, 6, 0.015, 0.03, 0.05),
  ('n2_luck', 'tide', 3, 12, 0.012, 0.03, 0.06),
  ('n2_luck', 'reflect', 3, 12, 0.012, 0.03, 0.06),
  ('n2_keen', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('n2_plenty', 'toxic', 3, 12, 0.012, 0.03, 0.06),
  ('n2_plenty', 'swarm', 3, 12, 0.012, 0.03, 0.06),
  ('n3_luck', 'tide', 8, 18, 0.006, 0.025, 0.05),
  ('n3_luck', 'reflect', 8, 18, 0.006, 0.025, 0.05),
  ('n3_keen', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('n3_plenty', 'toxic', 8, 18, 0.006, 0.025, 0.05),
  ('n3_plenty', 'swarm', 8, 18, 0.006, 0.025, 0.05),
  ('n4_luck', 'tide', 13, 24, 0.004, 0.012, 0.05),
  ('n4_luck', 'reflect', 13, 24, 0.004, 0.012, 0.05),
  ('n4_keen', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('n4_plenty', 'toxic', 13, 24, 0.004, 0.012, 0.05),
  ('n4_plenty', 'swarm', 13, 24, 0.004, 0.012, 0.05),
  ('n5_luck', 'tide', 20, 40, 0.002, 0.006, 0.03),
  ('n5_luck', 'reflect', 20, 40, 0.002, 0.006, 0.03),
  ('n5_luck', 'boss', 20, 40, 0, 0.01, 0.03),
  ('n5_keen', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('n5_keen', 'boss', 20, 40, 0, 0.01, 0.03),
  ('n5_plenty', 'toxic', 20, 40, 0.002, 0.006, 0.03),
  ('n5_plenty', 'swarm', 20, 40, 0.002, 0.006, 0.03),
  ('n5_plenty', 'boss', 20, 40, 0, 0.01, 0.03),
  ('m1_spell', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('m1_ward', 'seal_breaker', 1, 6, 0.015, 0.03, 0.05),
  ('m1_ward', 'warded', 1, 6, 0.015, 0.03, 0.05),
  ('m1_purify', 'toxic', 1, 6, 0.015, 0.03, 0.05),
  ('m2_spell', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('m2_ward', 'seal_breaker', 3, 12, 0.012, 0.03, 0.06),
  ('m2_ward', 'warded', 3, 12, 0.012, 0.03, 0.06),
  ('m2_purify', 'toxic', 3, 12, 0.012, 0.03, 0.06),
  ('m3_spell', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('m3_ward', 'seal_breaker', 8, 18, 0.006, 0.025, 0.05),
  ('m3_ward', 'warded', 8, 18, 0.006, 0.025, 0.05),
  ('m3_purify', 'toxic', 8, 18, 0.006, 0.025, 0.05),
  ('m4_spell', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('m4_ward', 'seal_breaker', 13, 24, 0.004, 0.012, 0.05),
  ('m4_ward', 'warded', 13, 24, 0.004, 0.012, 0.05),
  ('m4_purify', 'toxic', 13, 24, 0.004, 0.012, 0.05),
  ('m5_spell', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('m5_spell', 'boss', 20, 40, 0, 0.01, 0.03),
  ('m5_ward', 'seal_breaker', 20, 40, 0.002, 0.006, 0.03),
  ('m5_ward', 'warded', 20, 40, 0.002, 0.006, 0.03),
  ('m5_ward', 'boss', 20, 40, 0, 0.01, 0.03),
  ('m5_purify', 'toxic', 20, 40, 0.002, 0.006, 0.03),
  ('m5_purify', 'boss', 20, 40, 0, 0.01, 0.03),
  ('k1_hide', 'ambush', 1, 6, 0.015, 0.03, 0.05),
  ('k1_awe', 'armored', 1, 6, 0.015, 0.03, 0.05),
  ('k1_awe', 'boss', 1, 6, 0.015, 0.03, 0.05),
  ('k1_ghost', 'spectral', 1, 6, 0.015, 0.03, 0.05),
  ('k1_ghost', 'reflect', 1, 6, 0.015, 0.03, 0.05),
  ('k2_hide', 'ambush', 3, 12, 0.012, 0.03, 0.06),
  ('k2_awe', 'armored', 3, 12, 0.012, 0.03, 0.06),
  ('k2_awe', 'boss', 3, 12, 0.012, 0.03, 0.06),
  ('k2_ghost', 'spectral', 3, 12, 0.012, 0.03, 0.06),
  ('k2_ghost', 'reflect', 3, 12, 0.012, 0.03, 0.06),
  ('k3_hide', 'ambush', 8, 18, 0.006, 0.025, 0.05),
  ('k3_awe', 'armored', 8, 18, 0.006, 0.025, 0.05),
  ('k3_awe', 'boss', 8, 18, 0.006, 0.025, 0.05),
  ('k3_ghost', 'spectral', 8, 18, 0.006, 0.025, 0.05),
  ('k3_ghost', 'reflect', 8, 18, 0.006, 0.025, 0.05),
  ('k4_hide', 'ambush', 13, 24, 0.004, 0.012, 0.05),
  ('k4_awe', 'armored', 13, 24, 0.004, 0.012, 0.05),
  ('k4_awe', 'boss', 13, 24, 0.004, 0.012, 0.05),
  ('k4_ghost', 'spectral', 13, 24, 0.004, 0.012, 0.05),
  ('k4_ghost', 'reflect', 13, 24, 0.004, 0.012, 0.05),
  ('k5_hide', 'ambush', 20, 40, 0.002, 0.006, 0.03),
  ('k5_hide', 'boss', 20, 40, 0, 0.01, 0.03),
  ('k5_awe', 'armored', 20, 40, 0.002, 0.006, 0.03),
  ('k5_awe', 'boss', 20, 40, 0.002, 0.006, 0.03),
  ('k5_awe', 'boss', 20, 40, 0, 0.01, 0.03),
  ('k5_ghost', 'spectral', 20, 40, 0.002, 0.006, 0.03),
  ('k5_ghost', 'reflect', 20, 40, 0.002, 0.006, 0.03),
  ('k5_ghost', 'boss', 20, 40, 0, 0.01, 0.03)
on conflict (item_id, mechanic_key) do nothing;

insert into public.world_shop_catalog(shop_id, item_id, base_price, stock_min, stock_max) values
  ('night_office_store', 'h1_guard', 56, 1, 4),
  ('night_office_store', 'h1_calm', 56, 1, 4),
  ('night_office_store', 's1_road', 48, 1, 4),
  ('night_office_store', 'm1_ward', 64, 1, 4),
  ('capital_market', 'n1_luck', 64, 1, 4),
  ('capital_market', 'n1_keen', 64, 1, 4),
  ('capital_market', 'k1_hide', 64, 1, 4),
  ('capital_market', 'k1_awe', 64, 1, 4),
  ('capital_market', 's1_swift', 48, 1, 4),
  ('river_market', 's1_road', 48, 1, 4),
  ('river_market', 's1_sturdy', 48, 1, 4),
  ('river_market', 'm1_purify', 64, 1, 4),
  ('river_market', 'n1_plenty', 64, 1, 4),
  ('frontier_market', 'a1_iron', 80, 1, 4),
  ('frontier_market', 'a1_light', 80, 1, 4),
  ('frontier_market', 'a1_robe', 80, 1, 4),
  ('frontier_market', 'a1_shade', 80, 1, 4),
  ('frontier_market', 'h1_wise', 56, 1, 4),
  ('south_market', 'w_melee1_heavy', 80, 1, 4),
  ('south_market', 'w_melee1_keen', 80, 1, 4),
  ('south_market', 'w_ranged1_keen', 80, 1, 4),
  ('south_market', 'w_magic1_silent', 80, 1, 4),
  ('south_market', 'k1_ghost', 64, 1, 4),
  ('south_market', 'm1_spell', 64, 1, 4),
  ('north_market', 'a2_iron', 240, 1, 3),
  ('north_market', 'h2_guard', 168, 1, 3),
  ('north_market', 's2_sturdy', 144, 1, 3),
  ('north_market', 'w_melee2_heavy', 240, 1, 3),
  ('underworld_market', 'k2_hide', 192, 1, 3),
  ('underworld_market', 'n2_keen', 192, 1, 3),
  ('underworld_market', 'a2_shade', 240, 1, 3),
  ('underworld_market', 'w_ranged2_silent', 240, 1, 3),
  ('astral_market', 'm2_spell', 192, 1, 3),
  ('astral_market', 'm2_purify', 192, 1, 3),
  ('astral_market', 'h2_calm', 168, 1, 3),
  ('astral_market', 'n2_luck', 192, 1, 3),
  ('astral_market', 'w_magic2_keen', 240, 1, 3)
on conflict do nothing;

/* ── 10) 확인 ─────────────────────────────────────────────── */
select (select count(*) from public.world_item_catalog where category in ('hat', 'shoes', 'norigae', 'amulet', 'mask')) as new_slot_items,
       (select count(*) from public.world_item_catalog where item_id ~ '^(w_|a[1-5]_|t[2-5]_|h[1-5]_|s[1-5]_|n[1-5]_|m[1-5]_|k[1-5]_)') as gear_items,
       (select count(*) from public.world_crafting_recipes where recipe_id like 'r\_%' and output_item ~ '^(w_|a[1-5]_|t[2-5]_|h[1-5]_|s[1-5]_|n[1-5]_|m[1-5]_|k[1-5]_)') as gear_recipes,
       (select count(*) from public.world_gear_drops) as gear_drops,
       position('world_gear_roll' in pg_get_functiondef('public.world_battle_action(text, text)'::regprocedure)) > 0 as battle_patched,
       position('''shoes''' in pg_get_functiondef('public.world_travel_route(text)'::regprocedure)) > 0 as travel_patched,
       position('world_expedition_hits' in pg_get_functiondef('public.world_expedition_settle(uuid, integer)'::regprocedure)) > 0 as expedition_patched;
