create or replace function public.world_weapon_rules() returns jsonb language sql immutable as $$
  select jsonb_build_object('drop_job_mul', 4, 'ammo', jsonb_build_object('arrow', jsonb_build_array('각궁', '단궁'), 'dart', jsonb_build_array('쇠뇌', '취관')),
    'kinds', jsonb_build_object('base', '기본 — 주는 피해', 'heavy', '묵직 — 이목·받는 피해 감소', 'keen', '예리 — 치명타', 'silent', '소리 없음 — 회피·이목 낮춤'),
    'forms', jsonb_build_object('artificer', jsonb_build_array(jsonb_build_array('등패와 환도', 'base'), jsonb_build_array('등패와 철퇴', 'heavy')), 'bloodknight', jsonb_build_array(jsonb_build_array('도끼', 'heavy'), jsonb_build_array('대검', 'base')), 'analyst', jsonb_build_array(jsonb_build_array('단도', 'keen'), jsonb_build_array('수리검', 'base')), 'spearman', jsonb_build_array(jsonb_build_array('언월도', 'base'), jsonb_build_array('장창', 'keen')), 'scout', jsonb_build_array(jsonb_build_array('각궁', 'keen'), jsonb_build_array('쇠뇌', 'base')), 'tamer', jsonb_build_array(jsonb_build_array('단궁', 'base'), jsonb_build_array('취관', 'keen')), 'exorcist', jsonb_build_array(jsonb_build_array('방울', 'base'), jsonb_build_array('법경', 'keen')), 'sealmaster', jsonb_build_array(jsonb_build_array('금강령', 'silent'), jsonb_build_array('사슬', 'base')), 'medic', jsonb_build_array(jsonb_build_array('부채', 'silent'), jsonb_build_array('침통', 'base')), 'formation', jsonb_build_array(jsonb_build_array('산가지', 'base'), jsonb_build_array('나경', 'silent'))))
$$;

create or replace function public.world_gear_roll(p_mech text, p_level integer, p_rank text, p_rare numeric DEFAULT 0)
 returns text language plpgsql security definer set search_path = pg_catalog, public as $$
declare total numeric; cap numeric; got text; v_job text;
begin
  select coalesce(sum(case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end), 0)
    into total from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2);
  if total <= 0 then return null; end if;
  cap := case p_rank when 'guardian' then 0.15 when 'elite' then 0.05 else 0.01 end;
  if random() >= least(cap, total) * greatest(0, 1 + coalesce(p_rare, 0) / 100.0) then return null; end if;
  select c.job_key into v_job from public.world_characters c where c.owner_id = public.fn_owner_auth_uid();
  select g.item_id into got from public.world_gear_drops g join public.world_item_catalog i on i.item_id = g.item_id
   where g.mechanic_key = p_mech and p_level between g.level_min and g.level_max and (p_rank = 'guardian' or coalesce(i.tier, 1) <= 2)
     and (case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end) > 0
   order by -ln(greatest(random(), 1e-9)) / ((case p_rank when 'guardian' then g.chance_guardian when 'elite' then g.chance_elite else g.chance_normal end)
     * case when v_job is not null and i.category = 'weapon' and i.equipment_traits -> 'jobs' ? v_job
              and jsonb_array_length(i.equipment_traits -> 'jobs') = 1 then coalesce((public.world_weapon_rules() ->> 'drop_job_mul')::numeric, 4) else 1 end)
   limit 1;
  return got;
end $$;

