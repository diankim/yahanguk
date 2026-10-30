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
