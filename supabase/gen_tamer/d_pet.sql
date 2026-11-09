alter table public.world_pets add column win_day date, add column win_n integer not null default 0;

create or replace function public.world_pet_partner_rules()
 returns jsonb language sql immutable
as $function$
  select '{
    "pow_base": 0.3, "pow_k": 0.7, "aff_cap": 300, "master_min": 0.8, "master_mul": 1.2, "def_k": 0.2, "jitter": [0.85, 0.3],
    "groups": {
      "guard": {"name": "지키기", "kinds": ["ward", "shell", "giant"], "style": "melee", "mul": 0.24, "ward_base": 6, "ward_k": 8, "line": "앞을 막아섰다", "fx_line": "다음 공격을 막아 줍니다"},
      "bite": {"name": "물기", "kinds": ["shadow", "breaker", "wood"], "style": "melee", "mul": 0.22, "p": 15, "fx": "pierce", "n": 2, "line": "물어뜯었다", "fx_line": "물린 상처가 벌어졌다"},
      "peck": {"name": "쪼기", "kinds": ["bird", "sky"], "style": "ranged", "mul": 0.22, "p": 25, "fx": "broken", "n": 2, "line": "쪼았다", "fx_line": "틈이 벌어졌다(받는 피해 +20%)"},
      "charm": {"name": "홀리기", "kinds": ["ghost", "water", "venom", "swarm", "mirror"], "style": "magic", "mul": 0.21, "p": 20, "fx": "weak", "n": 2, "line": "홀렸다", "fx_line": "기세가 흐려졌다(공격 −20%)"}
    },
    "fav_kinds": ["swarm", "shadow"], "melee_vs": ["swarm"], "rank8_pct": 8, "x30_pct": 25, "c43a_hp": 0.3, "c43a_mul": 2, "c24b_hp": 50, "c24b_pct": 15,
    "whistle": {"mul": 1.2, "pet": 2},
    "win_aff": 1, "win_day": 10, "care_mul": 1.5, "guest_tamer": 2,
    "coop_base": 0.6, "coop_k": 0.4, "boss_expose": 5,
    "exp": {"atk": 5, "find": 20, "loot": 5, "win": 0.03, "bite_win": 0.02, "guard_dmg": 5, "peck_threat": 10, "charm_ml": 10},
    "first": ["nureong_puppy", "spotted_cat", "sparrow", "ladybug"], "first_food": 5
  }'::jsonb
$function$;
select pg_temp.yh_share('public.world_pet_partner_rules()');
grant execute on function public.world_pet_partner_rules() to authenticated;

create or replace function public.world_pet_partner_of(p_owner uuid)
 returns jsonb language plpgsql stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare c record; r jsonb := public.world_pet_partner_rules(); g text; gr jsonb; pw numeric; pct numeric; procs text[];
begin
  select ch.job_key, ch.skill_progress, f.pet_id, p.affinity, coalesce(p.nickname, s.pet_name) as nm, s.pet_name, s.kind into c
    from public.world_characters ch
    join public.world_pet_profile f on f.owner_id = ch.owner_id
    join public.world_pets p on p.owner_id = f.owner_id and p.pet_id = f.pet_id
    join public.world_pet_species s on s.pet_id = f.pet_id
   where ch.owner_id = p_owner;
  if not found or c.job_key is distinct from 'tamer' then return null; end if;
  select e.key, e.value into g, gr from jsonb_each(r -> 'groups') e where e.value -> 'kinds' ? c.kind limit 1;
  if g is null then return null; end if;
  procs := array(select x from unnest(public.world_skill_procs(p_owner)) x where x like 'taming\_%');
  pw := (r ->> 'pow_base')::numeric + (r ->> 'pow_k')::numeric * least(c.affinity, (r ->> 'aff_cap')::int) / (r ->> 'aff_cap')::numeric;
  if 'taming_m50' = any (procs) then pw := greatest(pw, (r ->> 'master_min')::numeric); end if;
  select coalesce(sum((sk.passive_effect ->> 'pet_pct')::numeric), 0) into pct from public.world_skill_catalog sk
   where sk.category = 'taming' and sk.passive_effect ? 'pet_pct'
     and public.world_skill_has(c.skill_progress, '{}'::jsonb, sk.category, sk.unlock_rank, sk.slot, sk.requires);
  return jsonb_build_object('id', c.pet_id, 'name', c.nm, 'species', c.pet_name, 'kind', c.kind, 'grp', g, 'grp_name', gr ->> 'name', 'style', gr ->> 'style',
    'pow', round(pw, 3), 'pct', pct,
    'mul', round((gr ->> 'mul')::numeric * pw * (1 + pct / 100.0) * case when 'taming_m50' = any (procs) then (r ->> 'master_mul')::numeric else 1 end, 4),
    'p', round(least(1, coalesce((gr ->> 'p')::numeric, 100) / 100.0 * pw * case when 'taming_c24a' = any (procs) then 1.5 else 1 end), 3),
    'procs', to_jsonb(procs), 'rank8', coalesce((c.skill_progress -> 'taming' ->> 'rank')::int, 1) >= 8);
end $function$;
select pg_temp.yh_share('public.world_pet_partner_of(uuid)');

select pg_temp.yh_fix('world_combat_stats', array[$q$'presence', round(pres), 'gear_presence', round(g_pres, 1),$q$,
  $q$'presence', round(pres), 'gear_presence', round(g_pres, 1), 'pet', public.world_pet_partner_of(p_owner),$q$]);

select pg_temp.yh_fix('world_raid_stats', array[$q$'pres', coalesce((s ->> 'presence')::numeric, 30), 'style', coalesce(s ->> 'style', 'melee'), 'heal', coalesce((s ->> 'heal_pct')::numeric, 0));$q$,
  $q$'pres', coalesce((s ->> 'presence')::numeric, 30), 'style', coalesce(s ->> 'style', 'melee'), 'heal', coalesce((s ->> 'heal_pct')::numeric, 0))
    || case when jsonb_typeof(s -> 'pet') = 'object' then jsonb_build_object('pet', s -> 'pet', 'hp_atk', round(coalesce((s ->> 'attack')::numeric, 10) * (1 + (s -> 'pet' ->> 'mul')::numeric / (1 + coalesce((s ->> 'crit_pct')::numeric, 5) / 200.0)), 1)) else '{}'::jsonb end;$q$]);

create or replace function public.world_cb_buff(p_type text, p_eff jsonb, p_by uuid)
 returns jsonb language sql immutable
as $function$
  select case p_type
    when 'ward' then jsonb_build_object('ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'ward_all' then jsonb_build_object('ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'might' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
      || case when coalesce((p_eff ->> 'pet_x2')::boolean, false) then jsonb_build_object('pet_x2', p_eff -> 'n') else '{}'::jsonb end
    when 'might_all' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'rally' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', coalesce(p_eff -> 'n', '1'::jsonb), 'by', p_by))
    when 'resonance' then jsonb_build_object('might', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by), 'ward', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'crit_all' then jsonb_build_object('crit', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'evade' then jsonb_build_object('evade', jsonb_build_object('pct', p_eff -> 'pct', 'n', p_eff -> 'n', 'by', p_by))
    when 'gward' then jsonb_build_object('gward', jsonb_build_object('pct', coalesce(p_eff -> 'pct', '50'::jsonb), 'by', p_by))
    when 'crit_next' then jsonb_build_object('crit_next', p_by)
    when 'pet_strike' then jsonb_build_object('pet_fetch', coalesce(p_eff -> 'x', '2'::jsonb))
    when 'taunt' then jsonb_build_object('taunt', jsonb_build_object('pres', p_eff -> 'pres', 'pct', p_eff -> 'pct', 'n', p_eff -> 'n'))
  end
$function$;

create or replace function public.world_cb_pet_strike(p_stats jsonb, p_fx jsonb, p_bfx jsonb, p_by uuid, p_whistle boolean default false)
 returns jsonb language plpgsql
 set search_path to 'pg_catalog', 'public'
as $function$
declare r jsonb := public.world_pet_partner_rules(); pt jsonb := p_stats -> 'pet'; gr jsonb; f jsonb := coalesce(p_fx, '{}'::jsonb); b jsonb := coalesce(p_bfx, '{}'::jsonb);
  x numeric := 1; d numeric; eff boolean; n int; ln text; pw numeric;
begin
  if jsonb_typeof(pt) is distinct from 'object' then return null; end if;
  gr := r -> 'groups' -> (pt ->> 'grp'); pw := coalesce((pt ->> 'pow')::numeric, 0);
  if f ? 'pet_fetch' then x := x * (f ->> 'pet_fetch')::numeric; f := f - 'pet_fetch'; end if;
  n := coalesce((f ->> 'pet_x2')::int, 0);
  if n > 0 then x := x * 2; f := case when n > 1 then f || jsonb_build_object('pet_x2', n - 1) else f - 'pet_x2' end; end if;
  if p_whistle then x := x * (r -> 'whistle' ->> 'pet')::numeric; end if;
  d := coalesce((p_stats ->> 'attack')::numeric, 50) * (pt ->> 'mul')::numeric * x * ((r -> 'jitter' ->> 0)::numeric + random() * (r -> 'jitter' ->> 1)::numeric);
  eff := p_whistle or random() < coalesce((pt ->> 'p')::numeric, 0);
  ln := (pt ->> 'name') || '이(가) ' || (gr ->> 'line');
  if pt ->> 'grp' = 'guard' then
    if not f ? 'ward' then f := f || jsonb_build_object('ward', jsonb_build_object('pct', round((gr ->> 'ward_base')::numeric + (gr ->> 'ward_k')::numeric * pw), 'n', 1, 'by', p_by)); end if;
    eff := true;
  elsif pt ->> 'grp' = 'bite' and eff and not b ? 'expose' then
    b := b || jsonb_build_object('expose', jsonb_build_object('pct', round((r ->> 'boss_expose')::numeric * greatest(pw, 0.2), 1), 'n', 1, 'by', p_by));
  end if;
  return jsonb_build_object('d', greatest(1, round(d)), 'fx', f, 'bfx', b, 'grp', pt ->> 'grp', 'eff', eff, 'charm', pt ->> 'grp' = 'charm', 'line', ln, 'name', pt ->> 'name');
end $function$;
select pg_temp.yh_share('public.world_cb_pet_strike(jsonb, jsonb, jsonb, uuid, boolean)');
