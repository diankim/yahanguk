-- 2026-10-29 묶음 패치(배포 승인 뒤 한 번에 실행): 숙련·기술 통합과 기술 보상 확장 · 채집 테두리·칭호 이름 색 · 원정 완주 보상 · 요괴화 · 대련
-- 함수 주인으로 고치려면 그 역할을 잠깐 받는다(끝에서 거둔다)
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;
grant fn_owner_18451 to postgres with inherit true, set true;
grant fn_owner_18452 to postgres with inherit true, set true;
grant fn_owner_18925 to postgres with inherit true, set true;
grant fn_owner_20170 to postgres with inherit true, set true;
grant fn_owner_20175 to postgres with inherit true, set true;
grant fn_owner_18944 to postgres with inherit true, set true;
grant fn_owner_19180 to postgres with inherit true, set true;

/* ── 1. 숙련·기술 통합 ─────────────────────────────────────
   기술(14가지 세부 계열)이 실제로 쌓이는 단위다. 단계 r→r+1에 80+8r 경험(누적 4r²+76r−80), 최고 50단계.
   숙련(전투·채집·제작·조사)은 그 갈래 기술 가운데 가장 높은 단계다. 캐릭터 행이 바뀔 때 한곳(trg_world_skill_sync)에서 맞춘다.
   전투: 근접·원거리·봉인술·분석·수호·응급 / 채집: 채취·약초·채광·영기 / 제작: 단조·연금·결계 각인 / 조사: 추적 */
create or replace function public.world_skill_line_rank(p_xp integer)
returns integer language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select least(50, greatest(1, floor((-76 + sqrt(5776 + 16 * (80 + greatest(0, coalesce(p_xp, 0))))::numeric) / 8)::int))
$$;
create or replace function public.world_skill_line_xp(p_rank integer)
returns integer language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select 4 * greatest(1, p_rank) * greatest(1, p_rank) + 76 * greatest(1, p_rank) - 80
$$;

create or replace function public.world_skill_sync()
returns trigger language plpgsql set search_path to 'pg_catalog', 'public' as $$
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
    elsif k in ('foraging', 'herbalism', 'mining', 'spirit_gathering') then ga := greatest(ga, r);
    elsif k in ('smithing', 'alchemy', 'wardcraft') then cr := greatest(cr, r);
    elsif k = 'tracking' then iv := greatest(iv, r); end if;
  end loop;
  new.skill_progress := outp;
  new.combat_rank := cb; new.gathering_rank := ga; new.crafting_rank := cr; new.investigation_rank := iv;
  return new;
end $$;
drop trigger if exists trg_world_skill_sync on public.world_characters;
create trigger trg_world_skill_sync before insert or update on public.world_characters for each row execute function public.world_skill_sync();

-- 숙련 효과를 최고 50단계에 맞춰 다시 잰다(전에는 최고 20단계)
create or replace function public.world_dismantle_need(p_tier integer)
returns integer language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case coalesce(p_tier, 1) when 1 then 1 when 2 then 5 when 3 then 10 when 4 then 15 else 20 end
$$;
do $$
declare
  pat record; d text; n int;
begin
  for pat in select * from (values
    ('public.world_combat_stats(uuid,jsonb)', '(1 + coalesce(c.combat_rank, 1) * 0.015)', '(1 + (least(coalesce(c.combat_rank, 1), 50) - 1) * 0.006)'),
    ('public.world_craft_item(text)', '(case when r.craft_field = ''cooking'' then coalesce(c.cooking_rank, 1) else c.crafting_rank end)*3', '(case when r.craft_field = ''cooking'' then coalesce(c.cooking_rank, 1) * 3 else round(coalesce(c.crafting_rank, 1) * 1.2) end)'),
    ('public.world_expedition_settle(uuid,integer)', 'coalesce(c.combat_rank, 1) * 3', 'coalesce(c.combat_rank, 1) * 1.2'),
    ('public.world_expedition_settle(uuid,integer)', 'coalesce(c.gathering_rank, 1) / 10', 'coalesce(c.gathering_rank, 1) / 20'),
    ('public.world_expedition_finish(boolean)', 'coalesce(c.combat_rank, 1) * 3', 'coalesce(c.combat_rank, 1) * 1.2'),
    ('public.world_expedition_finish(boolean)', 'coalesce(c.gathering_rank, 1) / 10', 'coalesce(c.gathering_rank, 1) / 20'),
    ('public.world_expedition_finish(boolean)', 'least(coalesce(c.investigation_rank, 1), 10) / 2.0', 'least(coalesce(c.investigation_rank, 1), 30) / 6.0'),
    ('public.world_field_gather(uuid)', 'coalesce(c.gathering_rank, 1) / 8', 'coalesce(c.gathering_rank, 1) / 12'),
    ('public.world_gather_action(text)', 'least(3,floor(greatest(0,c.gathering_rank-1)/3)::int)', 'least(3,floor(greatest(0,c.gathering_rank-1)/12)::int)'),
    ('public.world_region_tactic_action(text)', 'floor(greatest(0,c.combat_rank-1)*0.8)', 'floor(greatest(0,c.combat_rank-1)*0.35)'),
    ('public.world_field_search()', 'least(coalesce(c.investigation_rank, 1), 20) * 0.6', 'least(coalesce(c.investigation_rank, 1), 50) * 0.24')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, pat.a, ''))) / length(pat.a);
    if n < 1 then raise exception '숙련 효과 고칠 자리를 찾지 못했습니다: % / %', pat.fn, pat.a; end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

/* ── 2. 기술 단계 보상 확장(13·18·24·30·36·43·50단계) ─────────
   피해·치명타는 world_combat_stats가 든 무기 계열·분석 계열로 더하고, 그 밖의 효과(채집량·희귀품·단서·회복량·받는 피해·정신 손실·침식·이동 시간·제작 품질)는
   world_skill_effect가 익힌 기술을 모두 더해(효과마다 상한) world_status_effect_total에 얹는다. */
insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, active_skill, recipe_id) values
('melee_t13','연환 베기','melee','근접 피해 +3%.','{"damage_pct": 3}'::jsonb,13,null,null),
('melee_t18','중심 무너뜨리기','melee','근접 피해 +2% · 치명타 +2%.','{"damage_pct": 2, "crit_pct": 2}'::jsonb,18,null,null),
('melee_t24','검기 응축','melee','근접 피해 +4%.','{"damage_pct": 4}'::jsonb,24,null,null),
('melee_t30','일섬','melee','치명타 +3%.','{"crit_pct": 3}'::jsonb,30,null,null),
('melee_t36','파진세','melee','근접 피해 +4%.','{"damage_pct": 4}'::jsonb,36,null,null),
('melee_t43','무형검','melee','근접 피해 +3% · 치명타 +2%.','{"damage_pct": 3, "crit_pct": 2}'::jsonb,43,null,null),
('melee_t50','검성지경','melee','근접 피해 +5% · 치명타 +3%.','{"damage_pct": 5, "crit_pct": 3}'::jsonb,50,null,null),
('ranged_t13','연사','ranged','원거리 피해 +3%.','{"damage_pct": 3}'::jsonb,13,null,null),
('ranged_t18','바람 읽기','ranged','치명타 +3%.','{"crit_pct": 3}'::jsonb,18,null,null),
('ranged_t24','관혈 사격','ranged','원거리 피해 +4%.','{"damage_pct": 4}'::jsonb,24,null,null),
('ranged_t30','매의 눈','ranged','치명타 +3%.','{"crit_pct": 3}'::jsonb,30,null,null),
('ranged_t36','뇌전시','ranged','원거리 피해 +4%.','{"damage_pct": 4}'::jsonb,36,null,null),
('ranged_t43','무음 사격','ranged','원거리 피해 +3% · 치명타 +2%.','{"damage_pct": 3, "crit_pct": 2}'::jsonb,43,null,null),
('ranged_t50','천리일시','ranged','원거리 피해 +5% · 치명타 +3%.','{"damage_pct": 5, "crit_pct": 3}'::jsonb,50,null,null),
('sealing_t13','오행 부적','sealing','술법 피해 +3%.','{"damage_pct": 3}'::jsonb,13,null,null),
('sealing_t18','정심 결인','sealing','침식 -5%.','{"erosion_pct": -5}'::jsonb,18,null,null),
('sealing_t24','뇌화 부적','sealing','술법 피해 +4%.','{"damage_pct": 4}'::jsonb,24,null,null),
('sealing_t30','혼백 속박','sealing','치명타 +3%.','{"crit_pct": 3}'::jsonb,30,null,null),
('sealing_t36','팔괘진','sealing','술법 피해 +4% · 침식 -5%.','{"damage_pct": 4, "erosion_pct": -5}'::jsonb,36,null,null),
('sealing_t43','귀문 봉쇄','sealing','술법 피해 +3% · 정신 손실 -5%.','{"damage_pct": 3, "mental_loss_pct": -5}'::jsonb,43,null,null),
('sealing_t50','천라지망','sealing','술법 피해 +5% · 치명타 +3%.','{"damage_pct": 5, "crit_pct": 3}'::jsonb,50,null,null),
('analysis_t13','습성 기록','analysis','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,13,null,null),
('analysis_t18','급소 짚기','analysis','치명타 +2%.','{"crit_pct": 2}'::jsonb,18,null,null),
('analysis_t24','요괴 해부','analysis','희귀품 +3%.','{"rare_loot_pct": 3}'::jsonb,24,null,null),
('analysis_t30','허점 예견','analysis','치명타 +2%.','{"crit_pct": 2}'::jsonb,30,null,null),
('analysis_t36','도감 완성','analysis','희귀품 +3% · 단서 발견 +3%.','{"rare_loot_pct": 3, "clue_bonus_pct": 3}'::jsonb,36,null,null),
('analysis_t43','천목','analysis','치명타 +2%.','{"crit_pct": 2}'::jsonb,43,null,null),
('analysis_t50','만물 통찰','analysis','치명타 +2% · 희귀품 +3%.','{"crit_pct": 2, "rare_loot_pct": 3}'::jsonb,50,null,null),
('guarding_t13','버티기','guarding','받는 피해 -3%.','{"incoming_damage_pct": -3}'::jsonb,13,null,null),
('guarding_t18','흘려 막기','guarding','받는 피해 -3%.','{"incoming_damage_pct": -3}'::jsonb,18,null,null),
('guarding_t24','금강신','guarding','받는 피해 -4%.','{"incoming_damage_pct": -4}'::jsonb,24,null,null),
('guarding_t30','부동심','guarding','정신 손실 -8%.','{"mental_loss_pct": -8}'::jsonb,30,null,null),
('guarding_t36','철옹성','guarding','받는 피해 -4%.','{"incoming_damage_pct": -4}'::jsonb,36,null,null),
('guarding_t43','호신강기','guarding','받는 피해 -3% · 정신 손실 -5%.','{"incoming_damage_pct": -3, "mental_loss_pct": -5}'::jsonb,43,null,null),
('guarding_t50','금종조','guarding','받는 피해 -5%.','{"incoming_damage_pct": -5}'::jsonb,50,null,null),
('first_aid_t13','지압','first_aid','회복량 +5%.','{"healing_pct": 5}'::jsonb,13,null,null),
('first_aid_t18','침술','first_aid','회복량 +5%.','{"healing_pct": 5}'::jsonb,18,null,null),
('first_aid_t24','해독 요령','first_aid','회복량 +5%.','{"healing_pct": 5}'::jsonb,24,null,null),
('first_aid_t30','야전 의술','first_aid','회복량 +6%.','{"healing_pct": 6}'::jsonb,30,null,null),
('first_aid_t36','명의의 손','first_aid','회복량 +6%.','{"healing_pct": 6}'::jsonb,36,null,null),
('first_aid_t43','기혈 순환','first_aid','회복량 +4% · 정신 손실 -5%.','{"healing_pct": 4, "mental_loss_pct": -5}'::jsonb,43,null,null),
('first_aid_t50','회춘술','first_aid','회복량 +8%.','{"healing_pct": 8}'::jsonb,50,null,null),
('tracking_t13','발자국 읽기','tracking','단서 발견 +3%.','{"clue_bonus_pct": 3}'::jsonb,13,null,null),
('tracking_t18','지름길','tracking','이동 시간 -4%.','{"travel_time_pct": -4}'::jsonb,18,null,null),
('tracking_t24','기척 감지','tracking','희귀품 +2% · 단서 발견 +3%.','{"rare_loot_pct": 2, "clue_bonus_pct": 3}'::jsonb,24,null,null),
('tracking_t30','산천 지리','tracking','이동 시간 -4%.','{"travel_time_pct": -4}'::jsonb,30,null,null),
('tracking_t36','귀신 길잡이','tracking','단서 발견 +4%.','{"clue_bonus_pct": 4}'::jsonb,36,null,null),
('tracking_t43','천리안','tracking','희귀품 +3%.','{"rare_loot_pct": 3}'::jsonb,43,null,null),
('tracking_t50','천하 행각','tracking','단서 발견 +4% · 이동 시간 -5%.','{"clue_bonus_pct": 4, "travel_time_pct": -5}'::jsonb,50,null,null),
('foraging_t13','빠른 손','foraging','채집량 +4%.','{"gather_qty_pct": 4}'::jsonb,13,null,null),
('foraging_t18','좋은 것만','foraging','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,18,null,null),
('foraging_t24','한 아름','foraging','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,24,null,null),
('foraging_t30','숨은 결실','foraging','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,30,null,null),
('foraging_t36','풍년','foraging','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,36,null,null),
('foraging_t43','산의 은혜','foraging','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,43,null,null),
('foraging_t50','채취 명인','foraging','채집량 +6%.','{"gather_qty_pct": 6}'::jsonb,50,null,null),
('herbalism_t13','약초 알아보기','herbalism','채집량 +4%.','{"gather_qty_pct": 4}'::jsonb,13,null,null),
('herbalism_t18','뿌리째 캐기','herbalism','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,18,null,null),
('herbalism_t24','약포','herbalism','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,24,null,null),
('herbalism_t30','영약 감별','herbalism','희귀품 +2% · 회복량 +3%.','{"rare_loot_pct": 2, "healing_pct": 3}'::jsonb,30,null,null),
('herbalism_t36','약초밭','herbalism','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,36,null,null),
('herbalism_t43','선초 찾기','herbalism','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,43,null,null),
('herbalism_t50','본초 명인','herbalism','채집량 +6%.','{"gather_qty_pct": 6}'::jsonb,50,null,null),
('mining_t13','정 다루기','mining','채집량 +4%.','{"gather_qty_pct": 4}'::jsonb,13,null,null),
('mining_t18','맥 짚기','mining','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,18,null,null),
('mining_t24','큰 덩이','mining','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,24,null,null),
('mining_t30','원석 감별','mining','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,30,null,null),
('mining_t36','갱도 개척','mining','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,36,null,null),
('mining_t43','광맥의 눈','mining','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,43,null,null),
('mining_t50','채광 명인','mining','채집량 +6%.','{"gather_qty_pct": 6}'::jsonb,50,null,null),
('spirit_gathering_t13','기운 모으기','spirit_gathering','채집량 +4%.','{"gather_qty_pct": 4}'::jsonb,13,null,null),
('spirit_gathering_t18','영기 감응','spirit_gathering','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,18,null,null),
('spirit_gathering_t24','영맥 흡수','spirit_gathering','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,24,null,null),
('spirit_gathering_t30','정수 응결','spirit_gathering','희귀품 +2% · 침식 -3%.','{"rare_loot_pct": 2, "erosion_pct": -3}'::jsonb,30,null,null),
('spirit_gathering_t36','영천','spirit_gathering','채집량 +5%.','{"gather_qty_pct": 5}'::jsonb,36,null,null),
('spirit_gathering_t43','천지 영기','spirit_gathering','희귀품 +2%.','{"rare_loot_pct": 2}'::jsonb,43,null,null),
('spirit_gathering_t50','영맥 명인','spirit_gathering','채집량 +6%.','{"gather_qty_pct": 6}'::jsonb,50,null,null),
('smithing_t13','담금질','smithing','제작 품질 +3.','{"craft_quality": 3}'::jsonb,13,null,null),
('smithing_t18','두드림','smithing','제작 품질 +3.','{"craft_quality": 3}'::jsonb,18,null,null),
('smithing_t24','불 다루기','smithing','제작 품질 +4.','{"craft_quality": 4}'::jsonb,24,null,null),
('smithing_t30','합금 비법','smithing','제작 품질 +4.','{"craft_quality": 4}'::jsonb,30,null,null),
('smithing_t36','명장의 손','smithing','제작 품질 +4.','{"craft_quality": 4}'::jsonb,36,null,null),
('smithing_t43','천공','smithing','제작 품질 +3.','{"craft_quality": 3}'::jsonb,43,null,null),
('smithing_t50','대장장 명인','smithing','제작 품질 +5.','{"craft_quality": 5}'::jsonb,50,null,null),
('alchemy_t13','불 조절','alchemy','제작 품질 +3.','{"craft_quality": 3}'::jsonb,13,null,null),
('alchemy_t18','증류','alchemy','제작 품질 +3.','{"craft_quality": 3}'::jsonb,18,null,null),
('alchemy_t24','약성 끌어올리기','alchemy','회복량 +4%.','{"healing_pct": 4}'::jsonb,24,null,null),
('alchemy_t30','단약 제련','alchemy','제작 품질 +4.','{"craft_quality": 4}'::jsonb,30,null,null),
('alchemy_t36','내단','alchemy','회복량 +4%.','{"healing_pct": 4}'::jsonb,36,null,null),
('alchemy_t43','연단술','alchemy','제작 품질 +4.','{"craft_quality": 4}'::jsonb,43,null,null),
('alchemy_t50','선단 명인','alchemy','제작 품질 +5 · 회복량 +4%.','{"craft_quality": 5, "healing_pct": 4}'::jsonb,50,null,null),
('wardcraft_t13','정갈한 획','wardcraft','제작 품질 +3.','{"craft_quality": 3}'::jsonb,13,null,null),
('wardcraft_t18','주사 다루기','wardcraft','제작 품질 +3.','{"craft_quality": 3}'::jsonb,18,null,null),
('wardcraft_t24','부적 겹치기','wardcraft','제작 품질 +4.','{"craft_quality": 4}'::jsonb,24,null,null),
('wardcraft_t30','팔괘 각인','wardcraft','제작 품질 +4 · 침식 -3%.','{"craft_quality": 4, "erosion_pct": -3}'::jsonb,30,null,null),
('wardcraft_t36','결계 설계','wardcraft','제작 품질 +4.','{"craft_quality": 4}'::jsonb,36,null,null),
('wardcraft_t43','봉인 비문','wardcraft','제작 품질 +3.','{"craft_quality": 3}'::jsonb,43,null,null),
('wardcraft_t50','각인 명인','wardcraft','제작 품질 +5.','{"craft_quality": 5}'::jsonb,50,null,null)
on conflict (skill_id) do update set skill_name = excluded.skill_name, category = excluded.category, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank;

create or replace function public.world_skill_effect(p_effect_key text)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid; v numeric;
begin
  if p_effect_key not in ('gather_qty_pct', 'rare_loot_pct', 'clue_bonus_pct', 'healing_pct', 'incoming_damage_pct', 'mental_loss_pct', 'erosion_pct', 'travel_time_pct', 'craft_quality') then return 0; end if;
  uid := public.fn_owner_auth_uid(); if uid is null then return 0; end if;
  select coalesce(sum((sk.passive_effect ->> p_effect_key)::numeric), 0) into v
    from public.world_skill_catalog sk join public.world_characters c on c.owner_id = uid
   where sk.passive_effect ? p_effect_key and coalesce((c.skill_progress -> sk.category ->> 'rank')::int, 1) >= sk.unlock_rank;
  -- 효과마다 상한: 한 갈래만 깊게 파도 넘치지 않게
  return case p_effect_key
    when 'gather_qty_pct' then least(v, 30) when 'rare_loot_pct' then least(v, 15) when 'clue_bonus_pct' then least(v, 20)
    when 'healing_pct' then least(v, 35) when 'craft_quality' then least(v, 30)
    when 'incoming_damage_pct' then greatest(v, -20) when 'mental_loss_pct' then greatest(v, -25)
    when 'erosion_pct' then greatest(v, -20) when 'travel_time_pct' then greatest(v, -15) else v end;
end $$;
alter function public.world_skill_effect(text) owner to fn_owner_field;
revoke all on function public.world_skill_effect(text) from public;
do $$ declare ro text; begin
  for ro in select r.rolname from pg_roles r where has_function_privilege(r.oid, 'public.world_title_extra(text)', 'execute') and r.rolname <> 'postgres' loop
    execute format('grant execute on function public.world_skill_effect(text) to %I', ro);
  end loop;
end $$;
do $$
declare d text := pg_get_functiondef('public.world_status_effect_total(text)'::regprocedure);
  a text := '+ public.world_trail_effect(p_effect_key)';
begin
  if position('world_skill_effect' in d) > 0 then return; end if;
  if position(a in d) = 0 then raise exception '상태 효과 합계에서 고칠 자리를 찾지 못했습니다'; end if;
  execute replace(d, a, a || ' + public.world_skill_effect(p_effect_key)');
end $$;

-- 지금 캐릭터의 기술 단계·숙련을 새 식으로 한 번 맞춘다(단계가 내려갈 수 있다: 2026-10-29 결정)
select set_config('yh.rank_sync', 'all', true);
update public.world_characters set updated_at = updated_at;
select set_config('yh.rank_sync', '', true);

/* ── 3. 원정: 긴 원정 완주 보상 · 장비 · 요괴 다양화 · 원정 경험을 기술로 ─────
   · 2시간 이상 끝까지 다녀오면 경험치·전·숙련 경험 +20%(4시간 +30%, 8시간 +40%) — 일찍 귀환하면 받지 못한다
   · 1시간 이상 끝까지 다녀오면 원정지 수준의 장비 하나(1시간 50%, 2시간 이상 반드시)
   · 원정 전투는 그 지역 요괴에 더해 같은 영역 이웃 지역(수준 ±3)의 일반 요괴도 드물게 나온다
   · 숙련이 기술 최고 단계가 되었으므로, 원정 전투·채집·조사 경험의 절반을 든 무기 계열·일반 채집·추적 기술에 더한다 */
create or replace function public.world_skill_add(p_sp jsonb, p_key text, p_xp integer)
returns jsonb language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case when p_key is null or coalesce(p_xp, 0) <= 0 then coalesce(p_sp, '{}'::jsonb)
    else coalesce(p_sp, '{}'::jsonb) || jsonb_build_object(p_key, coalesce(p_sp -> p_key, '{}'::jsonb)
      || jsonb_build_object('xp', coalesce((p_sp -> p_key ->> 'xp')::int, 0) + p_xp)) end
$$;
revoke all on function public.world_skill_add(jsonb, text, integer) from public, anon, authenticated;
-- 원정 정산 함수(주인 fn_owner_field)가 기술 경험을 적을 수 있게 그 열 하나만 쓰기 허용(클라이언트 권한은 그대로)
grant update (skill_progress) on public.world_characters to fn_owner_field;

-- 원정지 수준에 맞는 장비 하나(장비 드롭표에서 일반·정예 확률을 무게로)
create or replace function public.world_expedition_gear(p_level integer)
returns text language sql volatile security definer set search_path to 'pg_catalog', 'public' as $$
  select g.item_id from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where greatest(1, least(30, p_level)) between g.level_min and g.level_max and g.chance_normal + g.chance_elite > 0
   order by -ln(greatest(random(), 1e-9)) / (g.chance_normal + g.chance_elite) limit 1
$$;
alter function public.world_expedition_gear(integer) owner to fn_owner_field;
revoke all on function public.world_expedition_gear(integer) from public, anon, authenticated;
do $$ declare ro text; begin
  for ro in select pg_get_userbyid(p.proowner) from pg_proc p where p.oid = 'public.world_expedition_complete(boolean)'::regprocedure loop
    execute format('grant execute on function public.world_expedition_gear(integer) to %I', ro);
    execute format('grant execute on function public.world_skill_add(jsonb, text, integer) to %I', ro);
  end loop;
end $$;

do $$
declare
  pat record; d text; fn text;
begin
  for pat in select * from (values
    -- 요괴 다양화
    ('public.world_expedition_settle(uuid,integer)',
     'from public.world_region_monsters where region_id = r.region_id and (role <> ''guardian'' or depth >= 3)',
     'from public.world_region_monsters where (region_id = r.region_id or (role = ''common'' and region_id in (select x.region_id from public.world_map_regions x where x.territory_id = r.territory_id and x.region_id <> r.region_id and not coalesce(x.is_safe_zone, false) and abs(coalesce(x.min_level, 1) - coalesce(r.min_level, 1)) <= 3))) and (role <> ''guardian'' or depth >= 3)'),
    ('public.world_expedition_settle(uuid,integer)',
     'order by -ln(greatest(random(), 1e-9)) / case role when ''common'' then 6 when ''guardian'' then 0.6 else 4 end limit 1',
     'order by -ln(greatest(random(), 1e-9)) / (case role when ''common'' then 6 when ''guardian'' then 0.6 else 4 end * case when region_id = r.region_id then 1 else 0.3 end) limit 1'),
    -- 완주 보상
    ('public.world_expedition_complete(boolean)', 'trail_found boolean := false;', 'trail_found boolean := false; fb numeric := 0; full_gear text;'),
    ('public.world_expedition_complete(boolean)', '-- 이 원정지에 처음 끝까지 다녀오면 길잡이 등불',
     '-- 긴 원정 완주 보상(20261029000000)
  if e.settled_rounds >= total_rounds and ended = ''complete'' and e.minutes >= 120 then
    fb := case when e.minutes >= 480 then 0.4 when e.minutes >= 240 then 0.3 else 0.2 end;
    xp := round(xp * (1 + fb)); cxp := round(cxp * (1 + fb)); gxp := round(gxp * (1 + fb)); ixp := round(ixp * (1 + fb)); gil_gain := round(gil_gain * (1 + fb));
    lg := lg || jsonb_build_array(''끝까지 다녀온 긴 원정 — 경험치·전·숙련 경험 +'' || round(fb * 100) || ''%'');
  end if;
  if e.settled_rounds >= total_rounds and ended = ''complete'' and e.minutes >= 60 and (e.minutes >= 120 or random() < 0.5) then
    full_gear := public.world_expedition_gear(coalesce(n.min_level, r.min_level, c.level) + depth_ - 1);
    if full_gear is not null then
      loot := public.world_inv_add(loot, full_gear, 1);
      lg := lg || jsonb_build_array(''원정 끝에 '' || (select item_name from public.world_item_catalog where item_id = full_gear) || ''을(를) 챙겼습니다.'');
    end if;
  end if;
  -- 이 원정지에 처음 끝까지 다녀오면 길잡이 등불'),
    ('public.world_expedition_complete(boolean)', '''trail'', trail_found,', '''trail'', trail_found, ''full_bonus'', round(fb * 100), ''full_gear'', full_gear,'),
    -- 원정 경험을 기술로
    ('public.world_expedition_complete(boolean)', 'combat_xp = combat_xp + cxp, combat_rank = public.world_skill_rank(combat_xp + cxp, ''combat''),',
     'skill_progress = public.world_skill_add(public.world_skill_add(public.world_skill_add(skill_progress, public.world_idle_skill_for(uid, ''training''), cxp / 2), ''foraging'', gxp / 2), ''tracking'', ixp / 2),
    combat_xp = combat_xp + cxp, combat_rank = public.world_skill_rank(combat_xp + cxp, ''combat''),')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '원정 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

/* ── 4. 요화(妖化) · 정화 부적 조정 ─────────────────────────
   · 침식이 80·90·100에 처음 닿을 때 한 번씩 0.1%·1%·5%로 판정한다(내려갔다가 다시 닿으면 다시 판정).
   · 1단계 요기 스밈(3일) → 2단계 요문 발현(2일) → 3단계 반요(1일) → 전투불능. 3단계는 풀기 전까지 하루마다 다시 쓰러뜨린다.
   · 요화로 쓰러지면 목숨을 잃지 않는다(world_death_sweep이 그 쓰러짐은 건너뛴다). 쓰러진 채 「안전지대 봉인」을 고르면
     가장 가까운 안전지대로 옮겨져 봉인술사들이 24시간 요기를 해독한다(world_yohwa_seal). 그동안은 채팅만 되고 활동은 막히며(yohwa_seal 상태),
     끝나면 요화가 풀리고 침식이 40 아래로 내려간 채 원래대로 움직인다.
   · 요화·봉인은 상태 칸(10칸)을 차지하지 않고 상태판에 따로 늘 보인다.
   · 효과는 단계만큼 커진다(상태 세기 = 단계): 회복량 −10%·정신 손실 +10%·받는 피해 +6%·침식 +8%, 요기의 힘으로 주는 피해 +4%.
   · 귀령초(위험도 7 이상 지역의 희귀 채집·원정 발견물, 거래 가능)로만 풀린다. 쓰면 요화가 사라지고 침식 −20.
   · 상태 행은 world_character_statuses(status_key 'yohwa')에 두고, 만료 정리에서 빼며, 단계 진행은 5분마다 world_yohwa_tick이 한다.
   · 정화 부적(캐릭터 › 상태의 부적 정화)은 75전에 침식 −25로 침식 관리를 너무 쉽게 만들어 침식 −18·정신 +6으로 줄인다. */
insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, triggers, effects, max_stacks, active, icon, cure, cure_items)
values ('yohwa', '요화', 'negative', '깊은 침식 속에서 몸에 요기가 스며들어 요괴로 변해 갑니다. 단계가 오를수록 효과가 커지고, 3단계가 끝나면 쓰러집니다.',
  4320, '{}', '{"healing_pct": -10, "mental_loss_pct": 10, "incoming_damage_pct": 6, "erosion_pct": 8, "combat_damage_pct": 4}'::jsonb, 3, true, 'mask',
  '고위험 지역에서 드물게 나는 귀령초로만 풀 수 있습니다.', '{gwiryeong_cho}')
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, effects = excluded.effects,
  max_stacks = excluded.max_stacks, icon = excluded.icon, cure = excluded.cure, cure_items = excluded.cure_items, triggers = excluded.triggers;

insert into public.world_status_catalog(status_key, status_name, polarity, description, duration_minutes, triggers, effects, max_stacks, active, icon, cure, cure_items)
values ('yohwa_seal', '봉인 해독', 'negative', '안전지대의 봉인술사들이 몸에 스민 요기를 걷어내는 중입니다. 끝날 때까지 채팅 말고는 아무것도 할 수 없습니다.',
  1440, '{}', '{}'::jsonb, 1, true, 'shield', '24시간이 지나면 끝납니다.', '{}')
on conflict (status_key) do update set status_name = excluded.status_name, description = excluded.description, effects = excluded.effects, icon = excluded.icon, cure = excluded.cure;

insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, rarity, acquisition_difficulty, drop_rate_modifier, tradeable, reference_price, stack_size, minimum_level)
values ('gwiryeong_cho', '귀령초', 'consumable', 4, '혼이 제자리로 돌아오게 한다는 약초. 위험도 높은 땅의 그늘에서만 자란다. 요화를 풀고 침식을 20 낮춘다.', true, 'epic', 5, 1, true, 900, 3, 1)
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, rarity = excluded.rarity, tradeable = excluded.tradeable,
  reference_price = excluded.reference_price, stack_size = excluded.stack_size;
-- 위험도 7 이상 지역 채집터의 희귀 발견물에 더한다(탐색·원정이 함께 쓰는 목록)
update public.world_region_sites s set rare_bonus = jsonb_set(coalesce(s.rare_bonus, '{}'::jsonb), '{items}', coalesce(s.rare_bonus -> 'items', '[]'::jsonb) || '["gwiryeong_cho"]'::jsonb)
  from public.world_map_regions r
 where r.region_id = s.region_id and r.danger_level >= 7 and not coalesce(r.is_safe_zone, false)
   and not coalesce(s.rare_bonus -> 'items', '[]'::jsonb) ? 'gwiryeong_cho';

-- 요화 시작: 침식이 80·90·100에 닿는 순간에만 판정한다(조건이 맞을 때만 함수가 돈다)
create or replace function public.world_yohwa_onset()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare hit boolean := false;
begin
  if exists (select 1 from public.world_character_statuses where owner_id = new.owner_id and status_key in ('yohwa', 'yohwa_seal')) then return null; end if;
  if old.erosion < 80 and new.erosion >= 80 and random() < 0.001 then hit := true; end if;
  if not hit and old.erosion < 90 and new.erosion >= 90 and random() < 0.01 then hit := true; end if;
  if not hit and old.erosion < 100 and new.erosion >= 100 and random() < 0.05 then hit := true; end if;
  if not hit then return null; end if;
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
  values (new.owner_id, 'yohwa', 1, 1, 'erosion', now() + interval '3 days', jsonb_build_object('stage', 1, 'started_at', now()));
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (new.owner_id, 'yohwa', '요화: 1단계 요기 스밈', '깊은 침식 속에서 요기가 몸에 스며들었습니다. 3일 뒤 2단계로 나빠집니다. 귀령초로만 풀 수 있습니다.', jsonb_build_object('stage', 1));
  return null;
end $$;
alter function public.world_yohwa_onset() owner to fn_owner_field;
revoke all on function public.world_yohwa_onset() from public, anon, authenticated;
drop trigger if exists trg_world_yohwa_onset on public.world_characters;
create trigger trg_world_yohwa_onset after update of erosion on public.world_characters
  for each row when ((old.erosion < 80 and new.erosion >= 80) or (old.erosion < 90 and new.erosion >= 90) or (old.erosion < 100 and new.erosion >= 100))
  execute function public.world_yohwa_onset();

-- 단계 진행(pg_cron 5분마다): 1→2(2일)·2→3(1일)·3단계 끝 → 전투불능(원정 중이면 1시간 미룸), 3단계를 하루 더
create or replace function public.world_yohwa_tick()
returns integer language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare s record; n int := 0; busy boolean; dat timestamptz;
begin
  for s in select cs.status_id, cs.owner_id, cs.potency from public.world_character_statuses cs
            where cs.status_key = 'yohwa' and cs.expires_at <= now() for update skip locked loop
    n := n + 1;
    if s.potency < 3 then
      update public.world_character_statuses set potency = s.potency + 1, stacks = s.potency + 1, applied_at = now(),
        expires_at = now() + case when s.potency = 1 then interval '2 days' else interval '1 day' end,
        metadata = metadata || jsonb_build_object('stage', s.potency + 1)
       where status_id = s.status_id;
      insert into public.world_notifications(user_id, kind, title, content, payload)
      values (s.owner_id, 'yohwa', case when s.potency = 1 then '요화: 2단계 요문 발현' else '요화: 3단계 반요' end,
        case when s.potency = 1 then '살갗에 요기의 무늬가 떠올랐습니다. 2일 뒤 마지막 단계로 넘어갑니다.' else '반쯤 요괴가 되었습니다. 하루 안에 귀령초를 쓰지 않으면 쓰러집니다.' end,
        jsonb_build_object('stage', s.potency + 1));
    else
      busy := exists (select 1 from public.world_expeditions where owner_id = s.owner_id and status = 'active');
      if busy then
        update public.world_character_statuses set expires_at = now() + interval '1 hour' where status_id = s.status_id;
      else
        update public.world_characters set health = 0, downed_at = now(), updated_at = now()
         where owner_id = s.owner_id and coalesce(health, 0) > 0 and downed_at is null
        returning downed_at into dat;
        -- 요화로 쓰러진 때를 적어 두면 사망 처리(world_death_sweep)가 그 쓰러짐을 건너뛴다
        update public.world_character_statuses set expires_at = now() + interval '1 day', applied_at = now(),
          metadata = metadata || case when dat is not null then jsonb_build_object('down_epoch', extract(epoch from dat)) else '{}'::jsonb end
         where status_id = s.status_id;
        insert into public.world_notifications(user_id, kind, title, content, payload)
        values (s.owner_id, 'yohwa', '요화로 쓰러졌습니다', '요기를 이기지 못해 쓰러졌습니다. 목숨은 잃지 않습니다. 「안전지대 봉인」으로 24시간 해독을 받거나, 구조·회생 부적으로 일어나 귀령초로 풀 수 있습니다.', jsonb_build_object('stage', 3, 'downed', true));
      end if;
    end if;
  end loop;
  return n;
end $$;
alter function public.world_yohwa_tick() owner to fn_owner_field;
revoke all on function public.world_yohwa_tick() from public, anon, authenticated;
do $$ begin
  if exists (select 1 from cron.job where jobname = 'yh-yohwa') then perform cron.unschedule('yh-yohwa'); end if;
  perform cron.schedule('yh-yohwa', '*/5 * * * *', 'select public.world_yohwa_tick()');
end $$;

-- 만료 정리에서 요화는 빼고(단계 진행이 맡는다), 귀령초는 물품 사용으로 쓴다
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('public.world_status_snapshot()', 'delete from public.world_character_statuses where owner_id=uid and expires_at<=now();',
     'delete from public.world_character_statuses where owner_id=uid and expires_at<=now() and status_key<>''yohwa'';'),
    ('public.world_apply_activity_status()', 'delete from public.world_character_statuses where owner_id=new.actor_id and expires_at<=now();',
     'delete from public.world_character_statuses where owner_id=new.actor_id and expires_at<=now() and status_key<>''yohwa'';'),
    ('public.world_use_item(text)', 'IF p_item_id = ''revival_charm'' THEN RAISE EXCEPTION ''회생 부적은 쓰러졌을 때 씁니다.''; END IF;',
     'IF p_item_id = ''revival_charm'' THEN RAISE EXCEPTION ''회생 부적은 쓰러졌을 때 씁니다.''; END IF;
  IF p_item_id = ''gwiryeong_cho'' THEN
    IF NOT EXISTS (SELECT 1 FROM public.world_character_statuses WHERE owner_id = uid AND status_key = ''yohwa'') THEN RAISE EXCEPTION ''요화에 걸리지 않았습니다. 귀령초는 요화를 풀 때 씁니다.''; END IF;
    DELETE FROM public.world_character_statuses WHERE owner_id = uid AND status_key = ''yohwa'';
    er := greatest(0, coalesce(c.erosion, 0) - 20);
    UPDATE public.world_characters SET inventory = public.world_inv_add(inv, p_item_id, -1), erosion = er,
      erosion_stage = CASE WHEN er >= 80 THEN 4 WHEN er >= 55 THEN 3 WHEN er >= 30 THEN 2 WHEN er >= 10 THEN 1 ELSE 0 END, updated_at = now() WHERE owner_id = uid;
    INSERT INTO public.world_events(actor_id, actor_name, event_type, content, payload)
    VALUES (uid, c.character_name, ''use_item'', c.character_name || ''이(가) 귀령초로 요화를 풀었습니다.'', jsonb_build_object(''v2'', true, ''item_id'', p_item_id, ''cured'', ''yohwa''));
    RETURN jsonb_build_object(''ok'', true, ''content'', ''귀령초를 달여 마시자 몸에 스민 요기가 빠져나갔습니다. 요화가 풀리고 침식 -20'');
  END IF;'),
    -- 정화 부적 조정
    ('public.world_survival_action(text)', 'er:=greatest(0,c.erosion-25);', 'er:=greatest(0,c.erosion-18);'),
    ('public.world_survival_action(text)', 'mental=least(100,mental+8),updated_at=now() where owner_id=uid returning * into c;', 'mental=least(100,mental+6),updated_at=now() where owner_id=uid returning * into c;'),
    ('public.world_survival_action(text)', '침식 -25, 정신 안정도 +8.', '침식 -18, 정신 안정도 +6.')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '요화 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- 안전지대 봉인: 요화를 지닌 채 쓰러졌을 때 고른다. 가장 가까운 안전지대로 옮겨 24시간 해독(채팅만 됨) 뒤 원래대로.
create or replace function public.world_yohwa_seal()
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; z public.world_map_regions%rowtype; er int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found or coalesce(c.is_dead, false) then raise exception '봉인을 받을 수 없습니다.'; end if;
  if not exists (select 1 from public.world_character_statuses where owner_id = uid and status_key = 'yohwa') then raise exception '요화에 걸리지 않았습니다.'; end if;
  if c.downed_at is null and coalesce(c.health, 0) > 0 then raise exception '안전지대 봉인은 요화로 쓰러졌을 때 고를 수 있습니다. 서 있다면 귀령초로 푸세요.'; end if;
  r := public.world_field_region(c.location);
  select * into z from public.world_map_regions x where x.is_safe_zone and x.active and x.min_level <= c.level
   order by (x.world_x - coalesce(r.world_x, 480)) ^ 2 + (x.world_y - coalesce(r.world_y, 360)) ^ 2 limit 1;
  er := least(coalesce(c.erosion, 0), 40);
  delete from public.world_active_encounters where owner_id = uid;
  delete from public.world_character_statuses where owner_id = uid and status_key = 'yohwa';
  insert into public.world_character_statuses(owner_id, status_key, stacks, potency, source_activity, expires_at, metadata)
  values (uid, 'yohwa_seal', 1, 1, 'yohwa', now() + interval '24 hours', jsonb_build_object('place', z.region_name));
  update public.world_characters set health = 50, mental = greatest(mental, 30), downed_at = null, erosion = er,
    erosion_stage = case when er >= 30 then 2 when er >= 10 then 1 else 0 end,
    location = z.region_name, current_exploration_node_id = null, travel_destination = null, travel_arrives_at = null, updated_at = now()
   where owner_id = uid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (uid, 'yohwa', '안전지대 봉인', z.region_name || '의 봉인술사들이 요기를 해독합니다. 24시간 동안은 채팅만 할 수 있고, 끝나면 원래대로 움직일 수 있습니다.', jsonb_build_object('seal', true));
  return jsonb_build_object('ok', true, 'location', z.region_name, 'content', z.region_name || '(으)로 옮겨져 봉인 해독을 받습니다. 24시간 뒤 원래대로 움직일 수 있습니다.');
end $$;
alter function public.world_yohwa_seal() owner to fn_owner_field;
revoke all on function public.world_yohwa_seal() from public, anon, authenticated;
grant execute on function public.world_yohwa_seal() to authenticated;

-- 행동 막기(world_guard_action_context)·자율 시작 함수의 주인이 봉인 상태를 읽을 수 있게(읽기만)
grant select on public.world_character_statuses to fn_owner_expedition, fn_owner_19180;
-- 요화로 쓰러진 것은 사망 처리하지 않는다 · 봉인 중에는 활동을 막는다 · 요화·봉인은 상태 칸에 세지 않는다 · 상태판에 단계 정보를 보낸다
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('public.world_death_sweep()', 'AND downed_at < now() - interval ''4 hours'' FOR UPDATE SKIP LOCKED LOOP',
     'AND downed_at < now() - interval ''4 hours''
             AND NOT EXISTS (SELECT 1 FROM public.world_character_statuses ys WHERE ys.owner_id = world_characters.owner_id AND ys.status_key = ''yohwa''
                             AND (ys.metadata ->> ''down_epoch'')::numeric = extract(epoch FROM world_characters.downed_at))
             FOR UPDATE SKIP LOCKED LOOP'),
    ('public.world_guard_action_context()', '  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN',
     '  IF k <> ''progression'' AND EXISTS (SELECT 1 FROM public.world_character_statuses ys WHERE ys.owner_id = new.actor_id AND ys.status_key = ''yohwa_seal'' AND ys.expires_at > now()) THEN
    RAISE EXCEPTION ''봉인 해독 중에는 채팅 말고는 할 수 없습니다. 해독이 끝나면 다시 움직일 수 있습니다.'';
  END IF;
  IF r.region_id IS NOT NULL AND r.is_safe_zone AND k IN (''encounter'', ''combat'') THEN'),
    ('public.world_start_idle_activity(text,integer)', ' if v_char.health<=0 or v_char.downed_at is not null then raise exception ''전투불능 상태에서는 자율 활동을 시작할 수 없습니다.''; end if;',
     ' if v_char.health<=0 or v_char.downed_at is not null then raise exception ''전투불능 상태에서는 자율 활동을 시작할 수 없습니다.''; end if;
 if exists (select 1 from public.world_character_statuses where owner_id = v_char.owner_id and status_key = ''yohwa_seal'' and expires_at > now()) then raise exception ''봉인 해독 중에는 자율 활동을 할 수 없습니다.''; end if;'),
    ('public.world_status_roll(text,jsonb)', 'select count(*) into current_count from public.world_character_statuses where owner_id=uid and expires_at>now();',
     'select count(*) into current_count from public.world_character_statuses where owner_id=uid and expires_at>now() and status_key not in (''yohwa'',''yohwa_seal'');'),
    ('public.world_hud_snapshot()', '''stacks'', s.stacks,', '''stacks'', s.stacks, ''metadata'', s.metadata,')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '봉인 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

/* ── 5. 본부 구조대 부활 대가 ───────────────────────────────
   구조대를 불러 안전지대에서 일어나면 전(30%·최소 50)에 더해 지금 레벨에 필요한 경험치의 5%를 잃는다(레벨은 내려가지 않는다).
   동료 구조·회생 부적으로 일어나면 잃지 않는다. */
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('fee bigint;', 'fee bigint; xp_loss int := 0;'),
    ('fee := least(c.gil, greatest(50, c.gil * 3 / 10));', 'fee := least(c.gil, greatest(50, c.gil * 3 / 10));
  xp_loss := least(coalesce(c.experience, 0), round(public.world_xp_need(c.level) * 0.05)::int);'),
    ('SET gil = gil - fee, health = 30,', 'SET gil = gil - fee, experience = greatest(0, experience - xp_loss), health = 30,'),
    ('jsonb_build_object(''self'', true, ''fee'', fee, ''to'', s.region_id)', 'jsonb_build_object(''self'', true, ''fee'', fee, ''xp_loss'', xp_loss, ''to'', s.region_id)'),
    ('fee || ''전을 냈습니다. 체력 30''', 'fee || ''전을 냈습니다.'' || case when xp_loss > 0 then '' 경험치 -'' || xp_loss || ''.'' else '''' end || '' 체력 30''')
  ) as t(a, b) loop
    d := pg_get_functiondef('public.world_call_rescue()'::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '구조대 고칠 자리가 하나가 아닙니다: %', left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

/* ── 6. 채팅 얼굴 테두리 · 칭호로 여는 특별 이름 색 ─────────────
   · 채팅 얼굴(world_chat_faces)에 꾸미기 테두리(frame)도 돌려준다. 화면은 얼굴 크기를 그대로 두고 바깥에 얇은 테 한 줄만 두른다.
   · 특별 이름 색은 profile.chat_hue에 1001~1015로 둔다(일반 색은 0~359). 이미 chat_hue를 찍는 곳(world_chat_stamp_title·world_circle_send·world_party_chat_snapshot)이 그대로 옮긴다.
     1001~1015 15가지(등급·칭호 수·분류별 칭호 수로 연다, world_name_styles). world_set_name_style이 서버에서 확인한다. */
create or replace function public.world_chat_faces(p_ids uuid[])
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select coalesce(jsonb_object_agg(c.owner_id::text, jsonb_strip_nulls(jsonb_build_object(
      'avatar', c.profile ->> 'avatar', 'emblem', c.profile ->> 'emblem', 'color', c.profile ->> 'color', 'frame', c.profile ->> 'frame'))), '{}'::jsonb)
  from public.world_characters c
  where public.fn_owner_auth_uid() is not null
    and c.owner_id = any (p_ids[1:60]);
$$;

-- 이름 색마다 여는 조건: 등급(명품·신품 이상 칭호), 칭호 수, 분류별 칭호 수
create or replace function public.world_name_styles()
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  with rules(style, kind, arg, n) as (values
    (1001, 'grade', '4', 1), (1002, 'grade', '5', 1), (1003, 'count', '', 30), (1004, 'count', '', 15),
    (1005, 'cat', '낚시', 3), (1006, 'cat', '이야기', 5), (1007, 'cat', '비밀', 5), (1008, 'cat', '탐사', 5),
    (1009, 'cat', '채집', 3), (1010, 'cat', '제작', 3), (1011, 'cat', '전투', 6), (1012, 'cat', '비무', 3),
    (1013, 'cat', '교류', 2), (1014, 'cat', '이동', 4), (1015, 'cat', '성장', 4)),
  mine as (select k.grade, k.category from public.world_character_titles t join public.world_title_catalog k using (title_key)
            where t.owner_id = public.fn_owner_auth_uid())
  select coalesce(jsonb_object_agg(r.style::text, (case r.kind
      when 'grade' then (select count(*) from mine where grade >= r.arg::int)
      when 'count' then (select count(*) from mine)
      else (select count(*) from mine where category = r.arg) end) >= r.n), '{}'::jsonb)
  from rules r
$$;
alter function public.world_name_styles() owner to fn_owner_field;
revoke all on function public.world_name_styles() from public, anon, authenticated;
grant execute on function public.world_name_styles() to authenticated;

create or replace function public.world_set_name_style(p_style integer)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid();
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_style is null or p_style < 1001 or p_style > 1015 then raise exception '고를 수 없는 이름 색입니다.'; end if;
  if not coalesce((public.world_name_styles() ->> p_style::text)::boolean, false) then
    raise exception '이 이름 색을 여는 칭호 조건을 아직 채우지 못했습니다.'; end if;
  update public.world_characters set profile = jsonb_set(coalesce(profile, '{}'::jsonb), '{chat_hue}', to_jsonb(p_style)) where owner_id = uid;
  if not found then raise exception '캐릭터가 없습니다.'; end if;
  return jsonb_build_object('ok', true, 'hue', p_style);
end $$;
alter function public.world_set_name_style(integer) owner to fn_owner_field;
revoke all on function public.world_set_name_style(integer) from public, anon, authenticated;
grant execute on function public.world_set_name_style(integer) to authenticated;

/* ── 7. 비무(比武): 같은 곳에 있는 조사원끼리 겨루기 ────────────
   · 조사원 카드에서 신청 → 상대가 알림 팝업에서 받으면 서버가 그 자리에서 겨룬다(5분 안에 답하지 않으면 사라짐).
   · 목숨을 걸지 않는 겨루기다. 둘 다 겨루기 기세(100 + 8×레벨)로 서로 10합까지 주고받고(공격·치명타·회피·피해 감소는 world_combat_stats 그대로),
     먼저 쓰러뜨리거나 남은 체력이 많은 쪽이 이긴다. 실제 체력·물품·전·경험치는 그대로 두며, 같은 상대와는 3분에 한 번.
   · 둘 다 같은 곳, 전투불능·원정·자율 활동·이동·요괴 전투 중이 아니어야 하고, 어느 쪽이든 차단했으면 할 수 없다. */
create table if not exists public.world_spars (
  spar_id uuid primary key default gen_random_uuid(),
  challenger_id uuid not null references public.world_characters(owner_id) on delete cascade,
  target_id uuid not null references public.world_characters(owner_id) on delete cascade,
  status text not null default 'pending' check (status in ('pending', 'done', 'declined', 'expired', 'cancelled')),
  place text,
  winner_id uuid,
  result jsonb,
  created_at timestamptz not null default now(),
  expires_at timestamptz not null default now() + interval '5 minutes',
  finished_at timestamptz
);
create index if not exists idx_world_spars_target on public.world_spars(target_id, status);
create index if not exists idx_world_spars_challenger on public.world_spars(challenger_id, created_at desc);
alter table public.world_spars enable row level security;
drop policy if exists world_spars_read on public.world_spars;
create policy world_spars_read on public.world_spars for select to authenticated
  using ((select public.fn_owner_auth_uid()) in (challenger_id, target_id));
revoke all on public.world_spars from anon, authenticated;
grant select on public.world_spars to authenticated;
grant select, insert, update on public.world_spars to fn_owner_field;

-- 겨룰 수 있는 상태인지(안 되면 까닭)
create or replace function public.world_spar_block_reason(p_id uuid)
returns text language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case
    when c.owner_id is null then '조사원을 찾을 수 없습니다.'
    when coalesce(c.is_dead, false) or c.downed_at is not null or coalesce(c.health, 0) <= 0 then c.character_name || '은(는) 지금 싸울 수 없는 상태입니다.'
    when exists (select 1 from public.world_character_statuses x where x.owner_id = c.owner_id and x.status_key = 'yohwa_seal' and x.expires_at > now()) then c.character_name || '은(는) 봉인 해독 중입니다.'
    when c.travel_arrives_at is not null and c.travel_arrives_at > now() then c.character_name || '은(는) 이동 중입니다.'
    when exists (select 1 from public.world_expeditions x where x.owner_id = c.owner_id and x.status = 'active') then c.character_name || '은(는) 원정 중입니다.'
    when exists (select 1 from public.world_idle_activities x where x.owner_id = c.owner_id and x.status = 'active') then c.character_name || '은(는) 자율 활동 중입니다.'
    when exists (select 1 from public.world_active_encounters x where x.owner_id = c.owner_id and not coalesce(x.defeated, false) and not coalesce(x.fled, false) and x.result is null) then c.character_name || '은(는) 요괴와 싸우는 중입니다.'
  end
  from (select p_id as id) q left join public.world_characters c on c.owner_id = q.id
$$;
alter function public.world_spar_block_reason(uuid) owner to fn_owner_field;
revoke all on function public.world_spar_block_reason(uuid) from public, anon, authenticated;

create or replace function public.world_spar_challenge(p_target uuid)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare uid uuid := public.fn_owner_auth_uid(); me public.world_characters%rowtype; t public.world_characters%rowtype; why text; sid uuid;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  if p_target is null or p_target = uid then raise exception '비무 상대를 고르세요.'; end if;
  select * into me from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select * into t from public.world_characters where owner_id = p_target;
  if not found then raise exception '조사원을 찾을 수 없습니다.'; end if;
  if exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = p_target) or (b.owner_id = p_target and b.blocked_id = uid)) then
    raise exception '이 조사원과는 비무를 할 수 없습니다.'; end if;
  if coalesce(me.location, '') <> coalesce(t.location, '-') then raise exception '같은 곳에 있는 조사원과만 비무를 할 수 있습니다.'; end if;
  why := coalesce(public.world_spar_block_reason(uid), public.world_spar_block_reason(p_target));
  if why is not null then raise exception '%', why; end if;
  if exists (select 1 from public.world_spars s where s.status = 'done' and s.finished_at > now() - interval '3 minutes'
              and ((s.challenger_id = uid and s.target_id = p_target) or (s.challenger_id = p_target and s.target_id = uid))) then
    raise exception '같은 상대와는 3분에 한 번 겨룰 수 있습니다.'; end if;
  -- 신청은 한 번에 하나: 앞서 보낸 것은 거둔다
  update public.world_spars set status = 'cancelled', finished_at = now() where challenger_id = uid and status = 'pending';
  if exists (select 1 from public.world_spars s where s.challenger_id = p_target and s.target_id = uid and s.status = 'pending' and s.expires_at > now()) then
    raise exception '상대가 이미 비무를 신청했습니다. 알림에서 받아 주세요.'; end if;
  insert into public.world_spars(challenger_id, target_id, place) values (uid, p_target, me.location) returning spar_id into sid;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (p_target, 'spar_request', '비무 신청', me.character_name || '(Lv.' || me.level || ')이(가) 비무를 청합니다. 목숨을 걸지 않는 겨루기로, 체력·물품은 줄지 않습니다.',
    jsonb_build_object('spar_id', sid, 'from_id', uid, 'from_name', me.character_name));
  return jsonb_build_object('ok', true, 'spar_id', sid, 'content', t.character_name || '에게 비무를 청했습니다. 5분 안에 받으면 바로 겨룹니다.');
end $$;
alter function public.world_spar_challenge(uuid) owner to fn_owner_field;
revoke all on function public.world_spar_challenge(uuid) from public, anon, authenticated;
grant execute on function public.world_spar_challenge(uuid) to authenticated;

create or replace function public.world_spar_respond(p_spar uuid, p_accept boolean)
returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public' as $$
declare
  uid uuid := public.fn_owner_auth_uid(); s public.world_spars%rowtype; a public.world_characters%rowtype; b public.world_characters%rowtype;
  why text; sa jsonb; sb jsonb; hp numeric[] := array[100, 100]; atk numeric[]; crit numeric[]; cm numeric[]; eva numeric[]; red numeric[];
  nm text[]; ids uuid[]; lg jsonb := '[]'::jsonb; turn int; i int; j int; dmg numeric; first int; win int; hits int[] := array[0, 0]; crits int[] := array[0, 0];
  claims text := current_setting('request.jwt.claims', true); sub text := current_setting('request.jwt.claim.sub', true); summary text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into s from public.world_spars where spar_id = p_spar for update;
  if not found or s.target_id <> uid then raise exception '받을 수 있는 비무 신청이 아닙니다.'; end if;
  if s.status <> 'pending' then raise exception '이미 끝난 비무 신청입니다.'; end if;
  if s.expires_at <= now() then
    update public.world_spars set status = 'expired', finished_at = now() where spar_id = s.spar_id;
    raise exception '비무 신청이 시간이 지나 사라졌습니다.';
  end if;
  if not coalesce(p_accept, false) then
    update public.world_spars set status = 'declined', finished_at = now() where spar_id = s.spar_id;
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (s.challenger_id, 'spar_result', '비무를 사양했습니다', (select character_name from public.world_characters where owner_id = uid) || '이(가) 이번 비무를 사양했습니다.', jsonb_build_object('spar_id', s.spar_id));
    return jsonb_build_object('ok', true, 'content', '비무를 사양했습니다.');
  end if;
  -- 두 사람을 같은 순서로 잠근다(동시에 서로 받아도 엉키지 않게)
  perform 1 from public.world_characters where owner_id in (s.challenger_id, s.target_id) order by owner_id for update;
  select * into a from public.world_characters where owner_id = s.challenger_id;
  select * into b from public.world_characters where owner_id = s.target_id;
  if coalesce(a.location, '') <> coalesce(b.location, '-') then raise exception '두 사람이 같은 곳에 있어야 겨룰 수 있습니다.'; end if;
  why := coalesce(public.world_spar_block_reason(a.owner_id), public.world_spar_block_reason(b.owner_id));
  if why is not null then raise exception '%', why; end if;

  -- 전투 능력은 각자 자기 상태 효과로 잰다(효과 합계가 요청한 사람 기준이라 잠깐 바꿔 읽고 되돌린다)
  perform set_config('request.jwt.claim.sub', a.owner_id::text, true); sa := public.world_combat_stats(a.owner_id, null);
  perform set_config('request.jwt.claim.sub', b.owner_id::text, true); sb := public.world_combat_stats(b.owner_id, null);
  perform set_config('request.jwt.claim.sub', coalesce(sub, ''), true); perform set_config('request.jwt.claims', coalesce(claims, ''), true);
  if public.fn_owner_auth_uid() is distinct from uid then raise exception '비무 계산 중 오류가 났습니다.'; end if;

  nm := array[a.character_name, b.character_name]; ids := array[a.owner_id, b.owner_id];
  hp := array[100 + coalesce(a.level, 1) * 8, 100 + coalesce(b.level, 1) * 8];
  atk := array[greatest(1, coalesce((sa ->> 'attack')::numeric, 10)), greatest(1, coalesce((sb ->> 'attack')::numeric, 10))];
  crit := array[least(60, coalesce((sa ->> 'crit_pct')::numeric, 5)), least(60, coalesce((sb ->> 'crit_pct')::numeric, 5))];
  cm := array[coalesce((sa ->> 'crit_mult')::numeric, 150) / 100, coalesce((sb ->> 'crit_mult')::numeric, 150) / 100];
  eva := array[least(40, coalesce((sa ->> 'evasion_pct')::numeric, 0)), least(40, coalesce((sb ->> 'evasion_pct')::numeric, 0))];
  red := array[least(60, coalesce((sa ->> 'reduction_pct')::numeric, 0)), least(60, coalesce((sb ->> 'reduction_pct')::numeric, 0))];
  first := case when a.agility > b.agility then 1 when b.agility > a.agility then 2 when random() < 0.5 then 1 else 2 end;
  lg := lg || jsonb_build_array(jsonb_build_object('kind', 'start', 'text', nm[1] || '과(와) ' || nm[2] || '이(가) ' || coalesce(a.location, '그 자리') || '에서 마주 섰습니다. ' || nm[first] || '이(가) 먼저 나섭니다.'));
  <<duel>> for turn in 1..10 loop
    for j in 0..1 loop
      i := case when j = 0 then first else 3 - first end;
      if random() * 100 < eva[3 - i] then
        lg := lg || jsonb_build_array(jsonb_build_object('kind', 'miss', 'who', i, 'text', nm[3 - i] || '이(가) ' || nm[i] || '의 공격을 흘려 피했습니다.'));
        continue;
      end if;
      dmg := atk[i] * (0.85 + random() * 0.3) * (1 - red[3 - i] / 100.0);
      if random() * 100 < crit[i] then dmg := dmg * cm[i]; crits[i] := crits[i] + 1;
        lg := lg || jsonb_build_array(jsonb_build_object('kind', 'crit', 'who', i, 'dmg', round(dmg), 'text', nm[i] || '의 일격이 빈틈을 꿰뚫었습니다! ' || round(dmg) || ' 피해'));
      else
        lg := lg || jsonb_build_array(jsonb_build_object('kind', 'hit', 'who', i, 'dmg', round(dmg), 'text', nm[i] || '이(가) ' || nm[3 - i] || '에게 ' || round(dmg) || ' 피해'));
      end if;
      hits[i] := hits[i] + 1;
      hp[3 - i] := greatest(0, hp[3 - i] - round(dmg));
      if hp[3 - i] <= 0 then win := i; exit duel; end if;
    end loop;
  end loop;
  if win is null then win := case when hp[1] > hp[2] then 1 when hp[2] > hp[1] then 2 else first end; end if;
  summary := nm[win] || case when hp[3 - win] <= 0 then '이(가) 상대를 무릎 꿇렸습니다.' else '이(가) 판정으로 이겼습니다.' end
    || ' (남은 기세 ' || nm[1] || ' ' || hp[1] || ' · ' || nm[2] || ' ' || hp[2] || ')';
  lg := lg || jsonb_build_array(jsonb_build_object('kind', 'end', 'who', win, 'text', summary));
  update public.world_spars set status = 'done', finished_at = now(), winner_id = ids[win],
    result = jsonb_build_object('names', to_jsonb(nm), 'ids', to_jsonb(ids), 'levels', jsonb_build_array(a.level, b.level), 'hp', to_jsonb(hp), 'hits', to_jsonb(hits), 'crits', to_jsonb(crits), 'winner', win,
      'ko', hp[3 - win] <= 0, 'log', lg, 'summary', summary)
   where spar_id = s.spar_id;
  insert into public.world_notifications(user_id, kind, title, content, payload)
  values (s.challenger_id, 'spar_result', case when win = 1 then '비무에서 이겼습니다' else '비무에서 졌습니다' end, summary, jsonb_build_object('spar_id', s.spar_id));
  -- 비무 칭호(규칙 'spar'는 world_spars를 센다)
  perform public.world_title_award_check(s.challenger_id, 'spar');
  perform public.world_title_award_check(s.target_id, 'spar');
  -- 전투 기록 이벤트는 남기지 않는다(토벌·칭호·기술 경험으로 세지 않게). 같은 곳의 소식으로만 남긴다.
  return jsonb_build_object('ok', true, 'spar_id', s.spar_id, 'content', summary,
    'result', (select result from public.world_spars where spar_id = s.spar_id));
end $$;
alter function public.world_spar_respond(uuid, boolean) owner to fn_owner_field;
revoke all on function public.world_spar_respond(uuid, boolean) from public, anon, authenticated;
grant execute on function public.world_spar_respond(uuid, boolean) to authenticated;

-- 비무 칭호 규칙: {"spar":"all"|"distinct", "n":개수, "won":true/false, "ko":true/false, "gap":상대가 높은 레벨 차}
create or replace function public.world_spar_rule_count(p_owner uuid, p_rule jsonb)
returns numeric language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select case when p_rule ->> 'spar' = 'distinct'
      then count(distinct case when s.challenger_id = p_owner then s.target_id else s.challenger_id end)
      else count(*) end::numeric
    from public.world_spars s
   where s.status = 'done' and p_owner in (s.challenger_id, s.target_id)
     and (not p_rule ? 'won' or (s.winner_id = p_owner) = (p_rule ->> 'won')::boolean)
     and (not p_rule ? 'ko' or coalesce((s.result ->> 'ko')::boolean, false) = (p_rule ->> 'ko')::boolean)
     and (not p_rule ? 'gap' or coalesce(case when s.challenger_id = p_owner
           then (s.result -> 'levels' ->> 1)::int - (s.result -> 'levels' ->> 0)::int
           else (s.result -> 'levels' ->> 0)::int - (s.result -> 'levels' ->> 1)::int end, -99) >= (p_rule ->> 'gap')::int)
$$;
alter function public.world_spar_rule_count(uuid, jsonb) owner to fn_owner_field;
revoke all on function public.world_spar_rule_count(uuid, jsonb) from public, anon, authenticated;
do $$ declare ro text; begin
  for ro in select distinct pg_get_userbyid(p.proowner) from pg_proc p
             where p.oid in ('public.world_title_rule_ok(uuid,jsonb)'::regprocedure, 'public.world_title_rule_progress(uuid,jsonb)'::regprocedure) loop
    execute format('grant execute on function public.world_spar_rule_count(uuid, jsonb) to %I', ro);
  end loop;
end $$;
do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('public.world_title_rule_ok(uuid,jsonb)', '  ELSIF p_rule ? ''survey_full'' THEN',
     '  ELSIF p_rule ? ''spar'' THEN
    RETURN public.world_spar_rule_count(p_owner, p_rule) >= n;
  ELSIF p_rule ? ''survey_full'' THEN'),
    ('public.world_title_rule_progress(uuid,jsonb)', '  elsif p_rule ? ''survey_full'' then',
     '  elsif p_rule ? ''spar'' then
    v := public.world_spar_rule_count(p_owner, p_rule);
  elsif p_rule ? ''survey_full'' then'),
    ('public.world_title_award_check(uuid,text)', '    IF r ? ''distinct'' AND p_event_type IS NOT NULL AND r ->> ''distinct'' <> p_event_type THEN CONTINUE; END IF;',
     '    IF r ? ''distinct'' AND p_event_type IS NOT NULL AND r ->> ''distinct'' <> p_event_type THEN CONTINUE; END IF;
    IF r ? ''spar'' AND p_event_type IS NOT NULL AND p_event_type <> ''spar'' THEN CONTINUE; END IF;')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '칭호 규칙 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

-- 비무 칭호 10가지(분류 비무, 둘은 숨김)
insert into public.world_title_catalog(title_key, title_name, icon, description, condition_text, bonus, active, hidden, rule, sort, category, grade) values
('spar_first', '초출 무인', 'sword', '처음으로 남과 칼을 맞대 보았다.', '비무 1번', '{"presence": 3}'::jsonb, true, false, '{"spar": "all", "n": 1}'::jsonb, 108, '비무', 1),
('spar_win1', '첫 승리의 맛', 'sword', '이긴다는 것이 이런 기분이다.', '비무에서 1번 이기기', '{"crit_pct": 1}'::jsonb, true, false, '{"spar": "all", "won": true, "n": 1}'::jsonb, 109, '비무', 1),
('spar_20', '연무장 단골', 'sword', '오늘도 누군가와 겨루러 나왔다.', '비무 20번', '{"defense": 2, "evasion_pct": 1}'::jsonb, true, false, '{"spar": "all", "n": 20}'::jsonb, 110, '비무', 2),
('spar_win10', '무명 고수', 'sword', '이름은 몰라도 솜씨는 안다.', '비무에서 10번 이기기', '{"combat_damage_pct": 2, "crit_pct": 1}'::jsonb, true, false, '{"spar": "all", "won": true, "n": 10}'::jsonb, 111, '비무', 2),
('spar_ko10', '일격필살', 'sword', '판정까지 갈 일이 없다.', '비무에서 상대를 쓰러뜨려 10번 이기기', '{"crit_pct": 3, "melee_pct": 2}'::jsonb, true, false, '{"spar": "all", "won": true, "ko": true, "n": 10}'::jsonb, 112, '비무', 3),
('spar_rivals10', '천하 주유', 'sword', '열 사람의 솜씨를 직접 겪어 보았다.', '서로 다른 조사원 10명과 비무', '{"presence": 4, "evasion_pct": 1, "travel_time_pct": -3}'::jsonb, true, false, '{"spar": "distinct", "n": 10}'::jsonb, 113, '비무', 3),
('spar_100', '백전노장', 'sword', '겨룬 횟수를 세는 것도 그만두었다.', '비무 100번', '{"defense": 3, "presence": 5, "incoming_damage_pct": -3}'::jsonb, true, false, '{"spar": "all", "n": 100}'::jsonb, 114, '비무', 3),
('spar_win50', '무림 명숙', 'sword', '그 이름을 들으면 다들 한 수 접는다.', '비무에서 50번 이기기', '{"combat_damage_pct": 4, "crit_pct": 2, "evasion_pct": 1}'::jsonb, true, false, '{"spar": "all", "won": true, "n": 50}'::jsonb, 115, '비무', 4),
('spar_upset', '하극상', 'sword', '레벨은 숫자일 뿐이었다.', '나보다 5레벨 이상 높은 조사원을 비무에서 이기기', '{"combat_damage_pct": 3, "crit_pct": 2, "magic_pct": 2}'::jsonb, true, true, '{"spar": "all", "won": true, "gap": 5, "n": 1}'::jsonb, 116, '비무', 4),
('spar_lose30', '칠전팔기', 'sword', '지는 법을 아는 자가 끝내 일어선다.', '비무에서 30번 지기', '{"mental_loss_pct": -5, "incoming_damage_pct": -2}'::jsonb, true, true, '{"spar": "all", "won": false, "n": 30}'::jsonb, 117, '비무', 3)
on conflict (title_key) do update set title_name = excluded.title_name, description = excluded.description, condition_text = excluded.condition_text,
  bonus = excluded.bonus, hidden = excluded.hidden, rule = excluded.rule, sort = excluded.sort, category = excluded.category, grade = excluded.grade;

-- 결과 다시 보기(두 사람만, 알림에서 연다)
create or replace function public.world_spar_view(p_spar uuid)
returns jsonb language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select jsonb_build_object('ok', true, 'status', s.status, 'result', s.result, 'place', s.place, 'finished_at', s.finished_at)
    from public.world_spars s where s.spar_id = p_spar and public.fn_owner_auth_uid() in (s.challenger_id, s.target_id)
$$;
alter function public.world_spar_view(uuid) owner to fn_owner_field;
revoke all on function public.world_spar_view(uuid) from public, anon, authenticated;
grant execute on function public.world_spar_view(uuid) to authenticated;

-- 잠깐 받은 함수 주인 역할을 거둔다
grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;
grant fn_owner_18451 to postgres with inherit false, set false;
grant fn_owner_18452 to postgres with inherit false, set false;
grant fn_owner_18925 to postgres with inherit false, set false;
grant fn_owner_20170 to postgres with inherit false, set false;
grant fn_owner_20175 to postgres with inherit false, set false;
grant fn_owner_18944 to postgres with inherit false, set false;
grant fn_owner_19180 to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029000000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
