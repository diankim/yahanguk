begin;
create temp table yh_ms(job text, lv int, tier int, enh int, attack numeric, crit numeric, defense numeric, weapon text, armor text);
do $$
declare
  u uuid := (select owner_id from public.world_characters where level >= 50 order by owner_id limit 1);
  j text; cfg record; base jsonb; pri text[]; pts int; cap int; k text; give int;
  s jsonb; best_v numeric; best_i text; sl text; cand text; v numeric;
begin
  for cfg in select * from (values (55, 9, 10), (55, 8, 5), (50, 8, 10)) t(lv, tier, enh) loop
  for j in select unnest(array['artificer','scout','exorcist','medic','sealmaster','analyst','tamer','bloodknight','spearman','formation']) loop
    base := public.world_job_base(j);
    pri := case when j in ('artificer','bloodknight','analyst','spearman') then array['strength','vitality','agility']
                when j in ('scout','tamer') then array['agility','perception','vitality']
                else array['spirit_affinity','willpower','vitality'] end;
    update public.world_characters set job_key = j, level = cfg.lv, strength = (base->>'strength')::int, agility = (base->>'agility')::int, vitality = (base->>'vitality')::int,
      perception = (base->>'perception')::int, willpower = (base->>'willpower')::int, spirit_affinity = (base->>'spirit_affinity')::int, stat_points = 0,
      skill_progress = coalesce(skill_progress, '{}') || jsonb_build_object(public.world_job_line(j), jsonb_build_object('xp', 30940, 'rank', 50)), downed_at = null, health = 100
     where owner_id = u;
    pts := 3 * (cfg.lv - 1);
    foreach k in array pri loop
      cap := public.world_stat_cap_of(j, k, cfg.lv);
      execute format('select %I from public.world_characters where owner_id = $1', k) into give using u;
      give := least(pts, greatest(0, cap - give));
      execute format('update public.world_characters set %I = %I + $1 where owner_id = $2', k, k) using give, u;
      pts := pts - give;
    end loop;
    delete from public.world_character_equipment where owner_id = u;
    delete from public.world_gear_enhance where owner_id = u;
    foreach sl in array array['weapon','armor','hat','shoes','norigae','amulet','mask'] loop
      best_v := -1; best_i := null;
      for cand in select item_id from public.world_item_catalog where tier = cfg.tier and category = sl and base_item_id is null
                    and (sl <> 'weapon' or equipment_traits->'jobs' ? j) loop
        delete from public.world_character_equipment where owner_id = u and world_character_equipment.slot = sl;
        insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, cand);
        if sl = 'weapon' then insert into public.world_gear_enhance(owner_id, item_id, level) values (u, cand, cfg.enh) on conflict do nothing; end if;
        s := public.world_combat_stats(u, null);
        v := (s->>'attack')::numeric + (s->>'crit_pct')::numeric * 2 + (s->>'defense')::numeric * 0.05;
        if v > best_v then best_v := v; best_i := cand; end if;
      end loop;
      delete from public.world_character_equipment where owner_id = u and world_character_equipment.slot = sl;
      if best_i is not null then insert into public.world_character_equipment(owner_id, slot, item_id) values (u, sl, best_i); end if;
    end loop;
    s := public.world_combat_stats(u, null);
    insert into yh_ms values (j, cfg.lv, cfg.tier, cfg.enh, (s->>'attack')::numeric, (s->>'crit_pct')::numeric, (s->>'defense')::numeric, s->'weapon'->>'item_id', s->'armor'->>'item_id');
  end loop; end loop;
end $$;
select * from yh_ms order by tier desc, enh desc, job;
rollback;
