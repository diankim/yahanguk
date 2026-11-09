lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name;
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function pg_temp.yh_share(p_fn text) returns void language plpgsql as $f$
declare x text;
begin
  execute format('revoke all on function %s from public, anon, authenticated', p_fn);
  for x in select rolname from pg_roles where rolname like 'fn\_owner%' or rolname = 'service_role' loop
    execute format('grant execute on function %s to %I', p_fn, x);
  end loop;
end $f$;

create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

alter table public.world_characters drop constraint world_characters_job_key_check;
alter table public.world_characters add constraint world_characters_job_key_check
  check (job_key = any (array['exorcist', 'scout', 'medic', 'sealmaster', 'analyst', 'artificer', 'tamer']));

select pg_temp.yh_fix('world_job_base', array[$q$
    when 'analyst'    then$q$, $q$
    when 'tamer'      then '{"strength":4,"agility":7,"vitality":5,"perception":8,"willpower":3,"spirit_affinity":3}'
    when 'analyst'    then$q$]);

select pg_temp.yh_fix('world_job_effect', array[$q$
      when 'analyst'    then 0$q$, $q$
      when 'analyst'    then 0
      when 'tamer'      then 0$q$]);

select pg_temp.yh_fix('world_job_label', array[$q$ when 'artificer' then '호위 무사' end$q$, $q$ when 'artificer' then '호위 무사' when 'tamer' then '조련사' end$q$]);
select pg_temp.yh_fix('world_job_name', array[$q$ when 'artificer' then '호위 무사' else$q$, $q$ when 'artificer' then '호위 무사' when 'tamer' then '조련사' else$q$]);

create or replace function public.world_job_line(p_job text)
 returns text language sql immutable
as $function$
  select case p_job when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
    when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' when 'tamer' then 'taming' end
$function$;

create or replace function public.world_combat_lines()
 returns text[] language sql immutable
as $function$
  select array['melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine', 'taming']
$function$;
select pg_temp.yh_share('public.world_combat_lines()');
grant execute on function public.world_combat_lines() to authenticated;

select pg_temp.yh_fix('world_job_skill_rules', array[$q$ 'line', '{me}의 「약점 간파」: 상대의 빈틈을 읽었다.'))$q$, $q$ 'line', '{me}의 「약점 간파」: 상대의 빈틈을 읽었다.'),
    'tamer', jsonb_build_object('name', '휘파람', 'desc', '원거리 ×1.2로 쏘고, 이번 차례 동무의 동작이 반드시 터지며 동무 피해가 두 배가 됩니다.', 'duel', jsonb_build_object('kind', 'focus', 'n', 1, 'mul', 1.3), 'line', '{me}의 「휘파람」: 동무가 함께 달려들었다.'))$q$]);

select pg_temp.yh_fix('world_solo_aid', array[$q$
    when 'analyst'    then$q$, $q$
    when 'tamer'      then '{"solo_dmg": -25, "solo_guard": -46, "final_dmg": -47}'
    when 'analyst'    then$q$]);

create or replace function public.world_weapon_jobs_of(p_type text)
 returns jsonb language sql immutable
as $function$
  select case coalesce(p_type, 'melee') when 'ranged' then '["scout","tamer"]'::jsonb when 'magic' then '["exorcist","sealmaster","medic"]'::jsonb
    else '["artificer","analyst"]'::jsonb end
$function$;

update public.world_item_catalog set equipment_traits = jsonb_set(equipment_traits, '{jobs}', (equipment_traits -> 'jobs') || '["tamer"]'::jsonb)
 where category = 'weapon' and equipment_traits -> 'jobs' ? 'scout' and not equipment_traits -> 'jobs' ? 'tamer';

select pg_temp.yh_fix('world_craft_item', array[$q$ when 'artificer' then '호위 무사' else r.required_job end$q$, $q$ else coalesce(public.world_job_label(r.required_job), r.required_job) end$q$]);

select pg_temp.yh_fix('world_expedition_complete', array[$q$ when 'artificer' then '반격 태세' end;$q$, $q$ when 'artificer' then '반격 태세' when 'tamer' then '동무의 코' end;$q$]);
select pg_temp.yh_fix('world_expedition_progress', array[$q$ when 'artificer' then '반격 태세' end);$q$, $q$ when 'artificer' then '반격 태세' when 'tamer' then '동무의 코' end);$q$]);

select pg_temp.yh_fix('world_expedition_walk_lines', array[$q$
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$, $q$
    when 'tamer' then array['동무가 앞서 달려가 냄새를 맡고는 뒤를 돌아봅니다.', '동무의 이름을 낮게 불러 곁에 붙여 둡니다.', '동무가 귀를 세운 쪽을 눈여겨봅니다.']
    else array['주변을 살피며 천천히 나아갑니다.'] end;$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$
    when 'artificer' then '[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다' else null end;$q$, $q$
    when 'artificer' then '[호위 일격] 앞을 막아서며 {f}을(를) 베어 넘겼습니다'
    when 'tamer' then '[짝 사냥] 동무가 {f}에게 달려든 틈에 화살을 박아 넣었습니다' else null end;$q$]);

alter table public.world_monster_kinds add column job_keys text[] not null default '{}';
update public.world_monster_kinds set job_keys = case when job_key is null then '{}' else array[job_key] end;
update public.world_monster_kinds set job_keys = array['scout', 'tamer'] where kind_key = 'shadow';
update public.world_monster_kinds set job_keys = array['tamer'] where kind_key = 'swarm';

create or replace function public.world_kind_job_ok(p_kind text, p_job text)
 returns boolean language sql stable
 set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce((select p_job = any (k.job_keys) from public.world_monster_kinds k where k.kind_key = p_kind), false)
$function$;
select pg_temp.yh_share('public.world_kind_job_ok(text, text)');

create or replace function public.world_kind_jobs_label(p_jobs text[])
 returns text language sql immutable
 set search_path to 'pg_catalog', 'public'
as $function$
  select nullif(array_to_string(array(select public.world_job_label(j) from unnest(p_jobs) with ordinality u(j, o) order by o), '·'), '')
$function$;
select pg_temp.yh_share('public.world_kind_jobs_label(text[])');

select pg_temp.yh_fix('world_kind_mult', array[$q$ case when k.job_key = p_job then 1.2 else 1 end$q$, $q$ case when p_job = any (k.job_keys) then 1.2 else 1 end$q$]);

select pg_temp.yh_fix('world_field_battle_view', array[$q$'job', k.job_key)$q$, $q$'job', k.job_keys[1], 'jobs', to_jsonb(k.job_keys))$q$,
  $q$'known', coalesce(x.defeated, 0) > 0,$q$, $q$'known', coalesce(x.defeated, 0) > 0, 'pet', public.world_pet_partner_of(q.o),$q$]);

select pg_temp.yh_fix('world_monster_codex_snapshot', array[$q$'job', k.job_key,$q$, $q$'job', k.job_keys[1], 'jobs', to_jsonb(k.job_keys),$q$]);

select pg_temp.yh_fix('world_gimmick_tip', array[$q$ and k.job_key is not null then$q$, $q$ and cardinality(k.job_keys) > 0 then$q$,
  $q$coalesce(case k.job_key when 'exorcist' then '퇴마관' when 'sealmaster' then '봉인술사' when 'scout' then '월궁 사수' when 'analyst' then '암영 검객' when 'medic' then '의무관' when 'artificer' then '호위 무사' end, '')$q$,
  $q$coalesce(public.world_kind_jobs_label(k.job_keys), '')$q$]);

select pg_temp.yh_fix('world_exp_fight_story', array[$q$ else 'melee' end, k.job_key
          into gbest, gjob$q$, $q$ else 'melee' end, case when p_job = any (k.job_keys) then p_job end
          into gbest, gjob$q$]);

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

select pg_temp.yh_fix('world_battle_action', array[
$q$pf_on boolean := coalesce(current_setting('yh.pf_resolve', true), '') = '1';$q$,
$q$pf_on boolean := coalesce(current_setting('yh.pf_resolve', true), '') = '1';
  pt jsonb; pgr jsonb; pr jsonb := public.world_pet_partner_rules(); pet_d int := 0; pet_brk int := 0; pet_x numeric; pet_eff boolean;$q$,

$q$  sk := public.world_skill_procs(uid);
$q$,
$q$  sk := public.world_skill_procs(uid);
  pt := st -> 'pet'; IF jsonb_typeof(pt) IS DISTINCT FROM 'object' THEN pt := NULL; END IF;
$q$,

$q$    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'artificer' ->> 'name';$q$,
$q$    ELSIF act = 'skill' AND c.job_key = 'artificer' THEN style := 'melee'; skill_name := public.world_job_skill_rules() -> 'artificer' ->> 'name';
    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN style := 'ranged'; skill_name := public.world_job_skill_rules() -> 'tamer' ->> 'name';$q$,

$q$    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;$q$,
$q$    ELSIF skill_name = '봉인술' THEN mul := mul * 1.1;
    ELSIF act = 'skill' AND c.job_key = 'tamer' THEN mul := mul * (pr -> 'whistle' ->> 'mul')::numeric;$q$,

$q$    v_pfx := v_pfx || jsonb_build_object('opened', true);$q$,
$q$    IF pt IS NOT NULL AND a.current_hp > 0 AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN
      pgr := pr -> 'groups' -> (pt ->> 'grp');
      pet_x := ((pr -> 'jitter' ->> 0)::numeric + random() * (pr -> 'jitter' ->> 1)::numeric) * public.world_kind_mult(m.kind, CASE WHEN pr -> 'melee_vs' ? m.kind THEN 'melee' ELSE pt ->> 'style' END, 'tamer');
      IF act = 'skill' THEN pet_x := pet_x * (pr -> 'whistle' ->> 'pet')::numeric; END IF;
      IF pr -> 'fav_kinds' ? m.kind THEN
        IF coalesce((pt ->> 'rank8')::boolean, false) THEN pet_x := pet_x * (1 + (pr ->> 'rank8_pct')::numeric / 100); END IF;
        IF 'taming_x30' = ANY (sk) THEN pet_x := pet_x * (1 + (pr ->> 'x30_pct')::numeric / 100); END IF;
      END IF;
      IF 'taming_c43a' = ANY (sk) AND a.current_hp < a.max_hp * (pr ->> 'c43a_hp')::numeric THEN pet_x := pet_x * (pr ->> 'c43a_mul')::numeric; END IF;
      IF coalesce((v_fx ->> 'airborne')::boolean, false) AND pt ->> 'grp' <> 'peck' THEN pet_x := pet_x * CASE pt ->> 'style' WHEN 'melee' THEN 0.4 ELSE 0.9 END; END IF;
      IF coalesce((v_fx ->> 'broken')::int, 0) > 0 THEN pet_x := pet_x * 1.2; END IF;
      pet_d := greatest(1, round((st ->> 'attack_raw')::numeric * (pt ->> 'mul')::numeric * pet_x - a.def * (pr ->> 'def_k')::numeric))::int;
      IF coalesce((v_fx ->> 'evade')::int, 0) > 0 AND pt ->> 'grp' <> 'peck' AND random() < 0.5 THEN pet_d := 0; END IF;
      IF pet_d > 0 AND coalesce((v_fx ->> 'barrier')::int, 0) > 0 THEN
        shield := (v_fx ->> 'barrier')::int - pet_d;
        IF shield > 0 THEN v_fx := v_fx || jsonb_build_object('barrier', shield); pet_d := 0; ELSE v_fx := v_fx - 'barrier'; pet_d := -shield; END IF;
      END IF;
      pet_eff := act = 'skill' OR (first_atk AND 'taming_x13' = ANY (sk)) OR pt ->> 'grp' = 'guard' OR random() < coalesce((pt ->> 'p')::numeric, 0);
      a.current_hp := greatest(0, a.current_hp - pet_d); ex_total := ex_total + pet_d;
      IF pt ->> 'grp' = 'charm' AND v_intent LIKE 'g:%' THEN pet_brk := pet_d; END IF;
      lines := lines || jsonb_build_array((pt ->> 'name') || '이(가) ' || (pgr ->> 'line') || CASE WHEN pet_d > 0 THEN ': ' || pet_d || ' 피해' ELSE '. 피해를 주지 못했다.' END);
      IF pet_eff AND a.current_hp > 0 THEN
        IF pt ->> 'grp' = 'guard' THEN v_pfx := v_pfx || jsonb_build_object('pet_ward', round((pgr ->> 'ward_base')::numeric + (pgr ->> 'ward_k')::numeric * (pt ->> 'pow')::numeric));
        ELSE v_fx := v_fx || jsonb_build_object(pgr ->> 'fx', greatest((pgr ->> 'n')::int, coalesce((v_fx ->> (pgr ->> 'fx'))::int, 0)));
          lines := lines || jsonb_build_array('「' || (pt ->> 'grp_name') || '」 ' || (pgr ->> 'fx_line') || '.'); END IF;
      END IF;
    END IF;
    v_pfx := v_pfx || jsonb_build_object('opened', true);$q$,

$q$IF dmg + ex_total + coalesce(nullif(current_setting('yh.pf_dmg', true), '')::int, 0) >= a.max_hp * brk THEN$q$,
$q$IF dmg + ex_total + pet_brk + coalesce(nullif(current_setting('yh.pf_dmg', true), '')::int, 0) >= a.max_hp * brk THEN$q$,

$q$        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;$q$,
$q$        IF coalesce((v_pfx ->> 'roar')::int, 0) > 0 THEN mdmg := round(mdmg * 0.85); END IF;
        IF coalesce((v_pfx ->> 'pet_ward')::int, 0) > 0 THEN mdmg := round(mdmg * (1 - (v_pfx ->> 'pet_ward')::numeric / 100)); v_pfx := v_pfx - 'pet_ward'; END IF;
        IF pt IS NOT NULL AND 'taming_c24b' = ANY (sk) AND hp < (pr ->> 'c24b_hp')::int AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN mdmg := round(mdmg * (1 - (pr ->> 'c24b_pct')::numeric / 100)); END IF;$q$,

$q$    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0$q$,
$q$    IF ended IS NULL AND hp <= 0 AND pt IS NOT NULL AND 'taming_c43b' = ANY (sk) AND NOT coalesce((v_pfx ->> 'pet_off')::boolean, false) THEN
      hp := 1; v_pfx := v_pfx || jsonb_build_object('pet_off', true); lines := lines || jsonb_build_array('「끝까지 곁에」 ' || (pt ->> 'name') || '이(가) 몸을 던져 쓰러질 일격을 막았다. 체력 1');
    END IF;
    IF ended IS NULL AND hp <= 0 THEN
      IF coalesce((inv ->> 'revival_charm')::int, 0) > 0$q$,

$q$    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');$q$,
$q$    lines := lines || jsonb_build_array(m.monster_name || '을(를) 쓰러뜨렸다.');
    IF pt IS NOT NULL THEN
      UPDATE public.world_pets SET win_n = CASE WHEN win_day = public.world_housing_today() THEN win_n + 1 ELSE 1 END, win_day = public.world_housing_today(),
        affinity = least((pr ->> 'aff_cap')::int, affinity + CASE WHEN win_day = public.world_housing_today() AND win_n >= (pr ->> 'win_day')::int THEN 0 ELSE (pr ->> 'win_aff')::int END)
       WHERE owner_id = uid AND pet_id = pt ->> 'id';
    END IF;$q$
]);

select pg_temp.yh_fix('world_raid_action', array[
$q$bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb;$q$,
$q$bt int; tick boolean := true; bnow numeric; cbr jsonb; cbc jsonb; pk jsonb; pd int; psolo numeric := 1;$q$,

$q$      f := f || public.world_cb_buff('crit_next', sk.effect, uid);$q$,
$q$      f := f || public.world_cb_buff(coalesce(sk.effect ->> 'type', 'crit_next'), sk.effect, uid);$q$,

$q$      mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')$q$,
$q$      psolo := (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_dmg')$q$,

$q$    elsif rd.kind = 'final' then mul := mul * (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;$q$,
$q$    elsif rd.kind = 'final' then psolo := (1 + coalesce((public.world_solo_aid(c.job_key) ->> 'final_all')::numeric, 0) / 100.0); end if;
    mul := mul * psolo;$q$,

$q$    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);$q$,
$q$    perform public.world_raid_say_n(p_raid, case when crit then 'crit' else 'atk' end, mb.name || ' — ' || dmg || '의 피해' || case when crit then '(치명타)' else '' end || '.', mb.name, dmg);
    pk := public.world_cb_pet_strike(st, f, rfx, uid, false);
    if pk is not null and rd.hp > 0 then
      f := pk -> 'fx'; rfx := pk -> 'bfx';
      pd := greatest(1, round((pk ->> 'd')::numeric * psolo))::int;
      rd.hp := greatest(case when rd.fx ? 'last_night' then ceil(rd.max_hp * 0.03)::int else 0 end, rd.hp - pd); mb.dmg := mb.dmg + pd; credit := credit + pd;
      if rfx ? 'charge' then rfx := jsonb_set(rfx, '{charge,got}', to_jsonb((rfx -> 'charge' ->> 'got')::int + pd * case when (pk ->> 'charm')::boolean then 2 else 1 end)); end if;
      perform public.world_raid_say_n(p_raid, 'atk', mb.name || ' — [동무] ' || (pk ->> 'line') || ': ' || pd || '의 피해.', mb.name, pd);
    end if;$q$,

$q$    k := sk.effect ->> 'type'; v := sk.effect;$q$,
$q$    k := sk.effect ->> 'type'; v := sk.effect;
    if c.job_key = 'tamer' and v ? 'pct' then
      v := v || jsonb_build_object('pct', round((v ->> 'pct')::numeric * ((public.world_pet_partner_rules() ->> 'coop_base')::numeric + (public.world_pet_partner_rules() ->> 'coop_k')::numeric * coalesce((st -> 'pet' ->> 'pow')::numeric, 0))));
    end if;$q$
]);

select pg_temp.yh_fix('world_raid_begin_fight', array[
$q$coalesce(sum((stats ->> 'attack')::numeric), 0), coalesce(avg((stats ->> 'attack')::numeric), 0)$q$,
$q$coalesce(sum(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric)), 0), coalesce(avg(coalesce((stats ->> 'hp_atk')::numeric, (stats ->> 'attack')::numeric)), 0)$q$]);

select pg_temp.yh_fix('world_raid_join', array[
$q$hp_add := round(coalesce((public.world_raid_stats(uid) ->> 'attack')::numeric, 0)$q$,
$q$hp_add := round(coalesce((select coalesce((z.s ->> 'hp_atk')::numeric, (z.s ->> 'attack')::numeric) from (select public.world_raid_stats(uid) as s) z), 0)$q$]);

select pg_temp.yh_fix('world_gw_start', array[
$q$sa := sa + coalesce((s ->> 'attack')::numeric, 50);$q$,
$q$sa := sa + coalesce((s ->> 'hp_atk')::numeric, (s ->> 'attack')::numeric, 50);$q$]);

select pg_temp.yh_fix('world_gw_resolve', array[
$q$v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid;$q$,
$q$v_mb text; v_mp numeric; v_eb text; v_ep numeric; v_cb text; v_cp numeric; v_cn text; v_brk uuid; pk jsonb; pd numeric;$q$,

$q$    e := sk.effect;
$q$,
$q$    e := sk.effect;
    if m.job_key = 'tamer' and e ? 'pct' then
      e := e || jsonb_build_object('pct', round((e ->> 'pct')::numeric * ((public.world_pet_partner_rules() ->> 'coop_base')::numeric + (public.world_pet_partner_rules() ->> 'coop_k')::numeric * coalesce((m.stats -> 'pet' ->> 'pow')::numeric, 0))));
    end if;
$q$,

$q$      when 'delay' then vbfx := vbfx ||$q$,
$q$      when 'pet_strike' then update public.world_gw_members set fx = fx || public.world_cb_buff('pet_strike', e, m.owner_id) where fight_id = p_fight and owner_id = tgt;
      when 'delay' then vbfx := vbfx ||$q$,

$q$        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);$q$,
$q$        perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — ' || round(d) || case when cr then '의 치명타.' else '의 피해.' end);
        pk := public.world_cb_pet_strike(m.stats, vfx, vbfx, m.owner_id, false);
        if pk is not null then
          vfx := pk -> 'fx'; vbfx := pk -> 'bfx';
          update public.world_gw_members set fx = vfx where fight_id = p_fight and owner_id = m.owner_id;
          pd := (pk ->> 'd')::numeric * (1 + coalesce((m.stats ->> 'solo_dmg')::numeric, 0) / 100.0);
          if k = 'vortex' and m.owner_id::text <> f.mech ->> 'tank' then vsum := vsum + pd * case when (pk ->> 'charm')::boolean then 2 else 1 end; end if;
          boss_dmg := boss_dmg + pd;
          update public.world_gw_members set dmg = dmg + round(pd)::int where fight_id = p_fight and owner_id = m.owner_id;
          perform public.world_gw_credit(p_fight, m.owner_id, pd, 'dmg');
          perform public.world_gw_say(p_fight, r, 'atk', m.name || ' — [동무] ' || (pk ->> 'line') || ': ' || round(pd) || '의 피해.');
        end if;$q$
]);

select pg_temp.yh_fix('world_expedition_settle', array[
$q$v_fkey text; fk text; pfd jsonb;$q$,
$q$ptn jsonb; ptr jsonb := public.world_pet_partner_rules() -> 'exp'; ppw float8 := 0; v_fkey text; fk text; pfd jsonb;$q$,

$q$  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> 'atk')::float8, 0) / 100.0);$q$,
$q$  skf := public.world_exp_skill_fx(e.owner_id); power := power * (1 + coalesce((skf ->> 'atk')::float8, 0) / 100.0);
  ptn := case when c.job_key = 'tamer' then public.world_pet_partner_of(e.owner_id) end;
  if ptn is not null then
    ppw := (ptn ->> 'pow')::float8;
    power := power * (1 + (ptr ->> 'atk')::float8 / 100.0 * ppw);
    if ptn ->> 'grp' = 'charm' then g_ml := g_ml - (ptr ->> 'charm_ml')::float8 * ppw; end if;
  end if;$q$,

$q$  disc_mul := disc_mul * (1 + coalesce((skf ->> 'find')::float8, 0) / 100.0);$q$,
$q$  disc_mul := disc_mul * (1 + coalesce((skf ->> 'find')::float8, 0) / 100.0);
  if ptn is not null then disc_mul := disc_mul * (1 + (ptr ->> 'find')::float8 / 100.0 * (0.5 + 0.5 * ppw)); loot_mul := loot_mul * (1 + (ptr ->> 'loot')::float8 / 100.0); end if;$q$,

$q$        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);$q$,
$q$        threat := threat / power(public.world_kind_mult(m.kind, wtype, c.job_key)::float8, 0.6);
        if ptn is not null and ptn ->> 'grp' = 'peck' and m.kind in ('bird', 'sky') then threat := threat * (1 - (ptr ->> 'peck_threat')::float8 / 100.0 * ppw); end if;$q$,

$q$        if c.job_key = 'analyst' and random() < 0.25 then$q$,
$q$        if ptn is not null then
          win_p := win_p + (ptr ->> 'win')::float8 * ppw + case when ptn ->> 'grp' = 'bite' then (ptr ->> 'bite_win')::float8 * ppw else 0 end;
          if random() < 0.3 then
            jobn := jobn + 1;
            seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[동무의 코] ' || (ptn ->> 'name') || '이(가) ' || foe
              || case ptn ->> 'grp' when 'guard' then '의 기척을 먼저 알아채고 앞을 막아섰습니다.' when 'bite' then '의 발목을 물고 늘어졌습니다.' when 'peck' then '의 눈앞을 쪼아 댔습니다.' else '의 기세를 흐려 놓았습니다.' end);
          end if;
        end if;
        if c.job_key = 'analyst' and random() < 0.25 then$q$,

$q$ * (1 - coalesce((skf ->> 'guard')::float8, 0) / 100.0));
        my_taken := 0;$q$,
$q$ * (1 - coalesce((skf ->> 'guard')::float8, 0) / 100.0) * case when ptn ->> 'grp' = 'guard' then 1 - (ptr ->> 'guard_dmg')::float8 / 100.0 * ppw else 1 end);
        my_taken := 0;$q$,

$q$      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;$q$,
$q$      finds := finds + 1; xp := xp + 6; ixp := ixp + 10;
      if ptn is not null and random() < 0.2 then
        seq := seq + 1; jr := jr || jsonb_build_object('at', base_t + make_interval(secs => seq * 2), 'kind', 'skill', 'who', me, 'owner', e.owner_id, 'text', '[동무의 코] ' || (ptn ->> 'name') || '이(가) 풀숲 밑 갈림길을 먼저 찾아냈습니다.');
      end if;$q$
]);

create or replace function public.world_pet_care_gain(p_uid uuid, p_act text, p_n integer, p_item text, p_likes text)
 returns integer language plpgsql stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare base int; tm boolean := exists (select 1 from public.world_characters c where c.owner_id = p_uid and c.job_key = 'tamer'); r jsonb := public.world_pet_partner_rules();
begin
  base := case p_act
    when 'pat' then case when p_n <= 5 then 2 else 0 end
    when 'play' then case when p_n <= 3 then 3 else 0 end
    when 'feed' then case when p_item = p_likes then 12 when p_item = 'pet_food' then 4 else 6 end
    when 'guest' then 1 else 0 end;
  if not tm or base = 0 then return base; end if;
  if p_act = 'guest' then return (r ->> 'guest_tamer')::int; end if;
  return ceil(base * (r ->> 'care_mul')::numeric)::int;
end $function$;
select pg_temp.yh_share('public.world_pet_care_gain(uuid, text, integer, text, text)');

select pg_temp.yh_fix('world_pet_act', array[
$q$c public.world_characters%rowtype; have int; was_adult boolean;$q$,
$q$c public.world_characters%rowtype; have int; was_adult boolean; carry boolean := false;$q$,

$q$  select * into h from public.world_housing where owner_id = p_owner;
  if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
  if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
  why := public.world_housing_can_view(uid, p_owner, h.gate);
  if why is not null then raise exception '%', why; end if;$q$,
$q$  if p_owner is null then
    select f.pet_id into h.pet_id from public.world_pet_profile f where f.owner_id = uid;
    if h.pet_id is null then raise exception '데리고 다니는 동무가 없습니다.'; end if;
    p_owner := uid; carry := true;
  else
    select * into h from public.world_housing where owner_id = p_owner;
    if not found or h.pet_id is null then raise exception '이 별채에는 동무가 없습니다.'; end if;
    if h.pet_out then raise exception '동무가 주인과 함께 나가 있습니다.'; end if;
    why := public.world_housing_can_view(uid, p_owner, h.gate);
    if why is not null then raise exception '%', why; end if;
  end if;$q$,

$q$gain := case when pt.pat_n <= 5 then 2 else 0 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'pat', pt.pat_n, null, null);$q$,

$q$gain := case when pt.play_n <= 3 then 3 else 0 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'play', pt.play_n, null, null);$q$,

$q$gain := case when p_item = sp.likes then 12 when p_item = 'pet_food' then 4 else 6 end;$q$,
$q$gain := public.world_pet_care_gain(uid, 'feed', pt.feed_n, p_item, sp.likes);$q$,

$q$    gain := 1; react := case$q$,
$q$    gain := public.world_pet_care_gain(uid, 'guest', 1, null, null); react := case$q$,

$q$  if p_act <> 'feed' and coalesce($q$,
$q$  if p_act <> 'feed' and not carry and coalesce($q$
]);

insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values
  ('taming_t3', '눈 맞춤', 'taming', '원거리 피해 +2% · 치명타 +3% · 동무 피해 +4%.', '{"damage_pct": 2, "crit_pct": 3, "pet_pct": 4}', 3, 'base'),
  ('taming_t8', '같이 겨누기', 'taming', '원거리 피해 +6% · 동무 피해 +12%, 군충·은형 요괴에게 동무 피해 +8% 더.', '{"damage_pct": 6, "pet_pct": 12}', 8, 'base'),
  ('taming_t13', '발맞춤', 'taming', '원거리 피해 +2% · 동무 피해 +3%.', '{"damage_pct": 2, "pet_pct": 3}', 13, 'base'),
  ('taming_x13', '눈짓', 'taming', '추가 기술 · 전투의 첫 공격 차례에 동무의 동작이 반드시 터진다', '{}', 13, 'extra'),
  ('taming_t18', '냄새 맡기', 'taming', '치명타 +3%.', '{"crit_pct": 3}', 18, 'base'),
  ('taming_c24a', '물고 늘어지기', 'taming', '택일 기술(사냥) · 동무의 동작이 터질 확률 ×1.5', '{}', 24, 'a'),
  ('taming_c24b', '몸 낮춰', 'taming', '택일 기술(돌봄) · 내 체력이 50 아래면 동무가 막아서 받는 피해 −15%', '{}', 24, 'b'),
  ('taming_t24', '몰이 사냥', 'taming', '원거리 피해 +2% · 동무 피해 +4%.', '{"damage_pct": 2, "pet_pct": 4}', 24, 'base'),
  ('taming_t30', '짝눈', 'taming', '치명타 +3%.', '{"crit_pct": 3}', 30, 'base'),
  ('taming_x30', '군충몰이', 'taming', '추가 기술 · 군충·은형 요괴에게 동무 피해 +25%', '{}', 30, 'extra'),
  ('taming_t36', '앞서 달리기', 'taming', '원거리 피해 +2% · 동무 피해 +4%.', '{"damage_pct": 2, "pet_pct": 4}', 36, 'base'),
  ('taming_c43a', '사냥 본능', 'taming', '택일 기술(사냥) · 요괴 체력이 30% 아래면 동무 피해 ×2', '{}', 43, 'a'),
  ('taming_c43b', '끝까지 곁에', 'taming', '택일 기술(돌봄) · 쓰러질 피해를 받으면 한 전투에 한 번 동무가 막아 체력 1로 버틴다(그 전투 동안 동무는 쉰다)', '{}', 43, 'b'),
  ('taming_t43', '소리 없는 몰이', 'taming', '원거리 피해 +2% · 치명타 +2% · 동무 피해 +2%.', '{"damage_pct": 2, "crit_pct": 2, "pet_pct": 2}', 43, 'base'),
  ('taming_t50', '한 호흡', 'taming', '원거리 피해 +2% · 치명타 +3% · 동무 피해 +6%.', '{"damage_pct": 2, "crit_pct": 3, "pet_pct": 6}', 50, 'base'),
  ('taming_m50', '이름의 끈', 'taming', '숙달 기술 · 동무의 힘이 친밀도와 상관없이 0.8 아래로 내려가지 않고, 동무 피해 ×1.2', '{}', 50, 'master');

create or replace function public.world_skill_line_ok(p_cat text, p_req jsonb, p_job text)
 returns boolean language sql immutable
as $function$
  select case when p_job is null then true
    when p_cat = any (public.world_combat_lines()) then p_cat = coalesce(public.world_job_line(p_job), p_cat)
    when p_cat = 'combo' then not ((coalesce(p_req, '{}'::jsonb) - coalesce(public.world_job_line(p_job), '')) ?| public.world_combat_lines())
    else true end
$function$;

select pg_temp.yh_fix('world_skill_pending', array[
$q$(s.category not in ('melee', 'ranged', 'sealing', 'dagger', 'exorcism', 'medicine') or$q$,
$q$(not s.category = any (public.world_combat_lines()) or$q$]);

select pg_temp.yh_fix('world_skill_sync', array[
$q$k = (case new.job_key when 'artificer' then 'melee' when 'scout' then 'ranged' when 'sealmaster' then 'sealing'
        when 'exorcist' then 'exorcism' when 'analyst' then 'dagger' when 'medic' then 'medicine' else k end)$q$,
$q$k = coalesce(public.world_job_line(new.job_key), k)$q$]);

select pg_temp.yh_fix('world_line_name', array[
$q$when 'medicine' then '의술' when$q$, $q$when 'medicine' then '의술' when 'taming' then '조련' when$q$]);

select pg_temp.yh_fix('world_initialize_skill_tracks', array[
$q$ 'medicine',coalesce(new.skill_progress->'medicine','{"xp":0,"rank":1}'::jsonb),$q$,
$q$ 'medicine',coalesce(new.skill_progress->'medicine','{"xp":0,"rank":1}'::jsonb),
 'taming',coalesce(new.skill_progress->'taming','{"xp":0,"rank":1}'::jsonb),$q$]);

insert into public.world_coop_skills(skill_id, job_key, unlock_rank, skill_name, description, target, effect, cost, cooldown_s, exp_win, exp_heal, exp_text, sort) values
  ('tm_fetch', 'tamer', 3, '물어 와', '동무를 보스에게 곧바로 보내 화살과 함께 한 번 공격한다. 이번 동무 공격은 두 배.', 'self', '{"type": "pet_strike", "strike": true, "x": 2}', 4, 8, 0.04, 0, '동무를 보내 요괴에게 달려들게 했습니다', 1),
  ('tm_guard', 'tamer', 8, '곁 지키기', '동무를 동료 곁에 보낸다. 그 동료를 노린 다음 두 번 공격의 피해 −30%(동무의 힘에 따라 줄어든다).', 'ally', '{"type": "ward", "n": 2, "pct": 30}', 5, 12, 0.04, 0, '동무를 동료 곁에 붙여 지키게 했습니다', 2),
  ('tm_herd', 'tamer', 18, '몰이', '동무가 보스 둘레를 돌며 몬다. 다음 반격 한 번을 막고, 보스가 받는 피해가 네 번 동안 +10%(동무의 힘에 따라 줄어든다, 봉연의 그림자에서는 사람이 많을수록 더 여러 번).', 'boss', '{"type": "expose", "n": 4, "pct": 10, "stagger": 1}', 9, 20, 0.06, 0, '동무가 요괴를 몰아 빈틈을 만들었습니다', 3),
  ('tm_pack', 'tamer', 36, '한 몸 사냥', '내 다음 세 번 공격 +25%(동무의 힘에 따라 줄어든다), 그동안 동무 공격은 두 배.', 'self', '{"type": "might", "n": 3, "pct": 25, "pet_x2": true}', 14, 30, 0.07, 0, '동무와 한 몸처럼 몰아쳤습니다', 4);

create or replace function public.world_pet_start(p_owner uuid, p_pet text)
 returns void language plpgsql security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  insert into public.world_pets(owner_id, pet_id, source) values (p_owner, p_pet, 'tamer_start')
  on conflict (owner_id, pet_id) do update set affinity = least(300, public.world_pets.affinity + 30);
  insert into public.world_pet_profile(owner_id, pet_id) values (p_owner, p_pet) on conflict (owner_id) do update set pet_id = excluded.pet_id, set_at = now();
  update public.world_housing set pet_id = null, pet_out = false, updated_at = now() where owner_id = p_owner and pet_id = p_pet;
end $function$;
select pg_temp.yh_own('public.world_pet_start(uuid, text)', 'fn_owner_field');
select pg_temp.yh_share('public.world_pet_start(uuid, text)');

drop function public.world_create_character_v2(text, text, text);
create function public.world_create_character_v2(p_name text, p_job text, p_faction text, p_pet text default null)
 returns jsonb language plpgsql security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare
  uid uuid := public.fn_owner_auth_uid();
  nm text := btrim(coalesce(p_name, ''));
  r public.world_characters%rowtype;
  job_label text; b jsonb; kit jsonb; inv jsonb; it record; pr jsonb := public.world_pet_partner_rules();
begin
  if uid is null then raise exception '로그인이 필요합니다.' using errcode = '28000'; end if;
  perform public.world_open_gate(uid);
  if exists (select 1 from public.world_characters where owner_id = uid) then
    raise exception '이미 캐릭터가 있습니다. 이름·직업·소속은 생성 후 변경할 수 없습니다.';
  end if;
  if char_length(nm) < 2 or char_length(nm) > 12 then raise exception '이름은 2~12자로 입력하세요.'; end if;
  if nm !~ '^[가-힣A-Za-z0-9 ]+$' then raise exception '이름에는 한글·영문·숫자·공백만 사용할 수 있습니다.'; end if;
  if replace(nm, ' ', '') = any (select replace(x, ' ', '') from unnest(public.world_sys_chat_names()) x) then raise exception '채팅 알림에 쓰는 이름이라 고를 수 없습니다.'; end if;
  job_label := public.world_job_label(p_job);
  if job_label is null then raise exception '직업을 선택하세요.'; end if;
  if p_job = 'tamer' and not coalesce(pr -> 'first' ? p_pet, false) then raise exception '함께 시작할 꼬마 동무를 고르세요.'; end if;
  if p_faction is null or p_faction not in ('headquarters','fieldbureau','archivebureau','sealbureau','medicalbureau','independent') then
    raise exception '소속을 선택하세요.';
  end if;
  if exists (select 1 from public.world_characters where lower(btrim(character_name)) = lower(nm)) then
    raise exception '이미 사용 중인 이름입니다.';
  end if;
  b := public.world_job_base(p_job);
  kit := case p_job
    when 'artificer'  then '{"weapon":"iron_sword","armor":"a1_iron","hat":"h1_guard","amulet":"m1_ward","tool":"field_knife"}'
    when 'scout'      then '{"weapon":"w_ranged1_keen","armor":"a1_light","shoes":"s1_swift","tool":"field_knife"}'
    when 'tamer'      then '{"weapon":"short_bow","armor":"a1_light","shoes":"s1_swift","tool":"field_knife"}'
    when 'exorcist'   then '{"weapon":"spirit_bell","armor":"a1_robe","amulet":"m1_spell","tool":"field_knife"}'
    when 'medic'      then '{"weapon":"w_magic1_silent","armor":"a1_robe","amulet":"m1_purify","tool":"field_knife"}'
    when 'sealmaster' then '{"weapon":"w_magic1_heavy","armor":"padded_coat","hat":"h1_calm","tool":"field_knife"}'
    else                   '{"weapon":"w_melee1_keen","armor":"padded_coat","norigae":"n1_keen","shoes":"s1_road","tool":"field_knife"}' end::jsonb;
  inv := '{"herb":2,"ward_talisman":1,"ore_pick":1,"seal_paper":1,"wood":0,"ore":0}'::jsonb;
  for it in select value v from jsonb_each_text(kit) loop inv := inv || jsonb_build_object(it.v, coalesce((inv ->> it.v)::int, 0) + 1); end loop;
  inv := inv || case p_job
    when 'scout'      then '{"ammo_arrow":100}'
    when 'tamer'      then jsonb_build_object('ammo_arrow', 100, 'pet_food', (pr ->> 'first_food')::int)
    when 'medic'      then '{"herb":5,"tonic":3}'
    when 'sealmaster' then '{"seal_paper":4,"ward_talisman":2}'
    when 'analyst'    then '{"tonic":2}'
    else '{}' end::jsonb;
  begin
    insert into public.world_characters(owner_id, character_name, occupation, inventory, job_key, faction_key,
                                        strength, agility, vitality, perception, willpower, spirit_affinity)
    values (uid, nm, job_label, inv, p_job, p_faction,
            (b ->> 'strength')::int, (b ->> 'agility')::int, (b ->> 'vitality')::int, (b ->> 'perception')::int, (b ->> 'willpower')::int, (b ->> 'spirit_affinity')::int)
    returning * into r;
  exception when unique_violation then
    raise exception '이미 사용 중인 이름이거나 캐릭터가 이미 있습니다.';
  end;
  insert into public.world_character_equipment(owner_id, slot, item_id)
  select uid, k.key, k.value from jsonb_each_text(kit) k
  on conflict (owner_id, slot) do nothing;
  if p_job = 'tamer' then perform public.world_pet_start(uid, p_pet); end if;
  return jsonb_build_object('ok', true, 'character_name', r.character_name, 'job_key', r.job_key, 'faction_key', r.faction_key, 'pet', case when p_job = 'tamer' then p_pet end);
end
$function$;
select pg_temp.yh_own('public.world_create_character_v2(text, text, text, text)', 'fn_owner_19111');
revoke all on function public.world_create_character_v2(text, text, text, text) from public, anon;
grant execute on function public.world_create_character_v2(text, text, text, text) to authenticated, service_role;

insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:dh_gomsil', '조련사 곰실', '객사 뒤뜰 동무 우리를 지키는 늙은 조련사. 젊을 때 옛 의금부 옥사에서 일했다.') on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_duseok', '옥사의 영 두석', '옥사가 버려지기 전에 죽은 열네 살 죄수의 영.') on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quest_npcs(npc_key, npc_name, bio) values ('q:sx_galdae', '반요 갈대지기', '서른 해 전 섬으로 보내진 늙은 반요. 갈대숲 가에서 수달 한 마리와 산다.') on conflict (npc_key) do update set npc_name = excluded.npc_name, bio = excluded.bio;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq_tamer', 'side', '직업·조련사', '이름 없는 불씨', '객사 뒤뜰의 늙은 조련사 곰실이 동무가 사람을 따르는 까닭을 일러 준다', 'hq_dorm', 3, '{}'::text[], null, 907, '[]'::jsonb, true, 'tamer', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_tamer', 1, '객사 뒤뜰의 동무 우리', '객사 뒤뜰의 동무 우리', '{"at": ["hq_dorm"]}'::jsonb, '[{"s": null, "t": "본부 객사 뒤뜰 담 밑에 작은 우리가 여러 칸 늘어서 있었다. 허리가 굽은 노파 하나가 우리마다 주먹밥을 한 덩이씩 밀어 넣고 있었다."}, {"s": null, "t": "노파는 내 발치에 붙어 선 동무를 보더니 손을 털고 일어섰다."}, {"s": "q:dh_gomsil", "t": "객사에 새 조련사가 왔다더니 너로구나. 나는 곰실이다. 이 뒤뜰 우리를 지키는 늙은이지."}, {"s": "q:dh_gomsil", "t": "그 녀석은 아직 제 이름이 낯선가 보다. 부를 때마다 반 박자씩 늦게 돌아보잖아."}, {"s": null, "t": "나는 처음 만난 동무가 왜 나를 따라다니는지 물었다."}, {"s": null, "t": "곰실은 우리 하나에 기대앉아 그 안에서 웅크린 작은 짐승들을 손가락으로 가리켰다."}, {"s": "q:dh_gomsil", "t": "밤에 나는 작은 것들은 다 요기를 조금씩 머금고 태어난다. 처음엔 이름이 없어서 사람들은 저것들을 갈래로 부르지. 도감에 갈래로 적히는 것도 그래서다."}, {"s": "q:dh_gomsil", "t": "이름 없는 것은 쉽게 흩어지고 큰 요괴한테 먹히기도 쉽다. 그런데 누가 이름을 지어서 날마다 불러 주면, 그 목소리가 가는 줄 한 가닥이 된다. 사람으로 치면 명줄이지."}, {"s": "q:dh_gomsil", "t": "그러니까 걔들은 길들여져서 따라오는 게 아니야. 제 이름을 불러 주는 목소리를 놓치기 싫어서 붙어 다니는 거다."}, {"s": "q:dh_gomsil", "t": "잿빛 들녘에 들쥐 요괴 떼가 들끓는다. 가서 세 번 쫓아내라. 싸우는 동안 동무 이름을 크게 불러. 이름은 싸울 때 더 단단히 묶이거든."}, {"s": null, "t": "나는 동무를 데리고 잿빛 들녘으로 가겠다고 했다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_tamer', 2, '크게 부른 이름', '들쥐 요괴 떼을(를) 물리친다', '{"at": ["hq_dorm"], "tasks": [{"t": "win", "m": ["g_field_outskirts"], "n": 3}]}'::jsonb, '[{"s": null, "t": "내가 뒤뜰로 돌아오자 동무가 먼저 곰실의 발치로 달려가 코를 비볐다. 곰실은 동무의 털에 묻은 들풀 씨를 털어 주었다."}, {"s": "q:dh_gomsil", "t": "잘 불렀구나. 이제는 한 번만 불러도 바로 돌아보네."}, {"s": "q:dh_gomsil", "t": "그런데 들녘에서 이상한 것은 못 봤냐? 밤길 나그네 뒤를 졸졸 따라다니는 작은 불씨가 있다더라. 이름 없는 도깨비불이다."}, {"s": "q:dh_gomsil", "t": "돌길잠복귀가 그 불씨를 노린다는 말도 들었다. 이름 없는 것은 그런 놈한테 한입거리지."}, {"s": "q:dh_gomsil", "t": "들녘을 세 번쯤 뒤져서 불씨를 찾아 봐라. 돌길잠복귀가 보이면 한 놈은 꼭 쓰러뜨리고."}]'::jsonb, '{"xp": 81}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq_tamer', 3, '이름을 받은 불씨', '잿빛 들녘을(를) 살핀다, 돌길잠복귀을(를) 물리친다', '{"at": ["hq_dorm"], "tasks": [{"t": "search", "r": ["field_outskirts"], "n": 3}, {"t": "win", "m": ["m_outskirts_2"], "n": 1}]}'::jsonb, '[{"s": null, "t": "돌길잠복귀가 무너진 돌무더기 틈에서 엄지만 한 불씨 하나가 기어 나왔다. 불씨는 객사로 돌아오는 내내 내 뒤를 따라왔다."}, {"s": null, "t": "곰실은 내 어깨 너머로 불씨를 보더니 한숨을 쉬었다."}, {"s": "q:dh_gomsil", "t": "네가 불렀냐?"}, {"s": null, "t": "나는 부르지 않았고, 잠복귀를 쫓아낸 뒤 한 번 돌아보았을 뿐이라고 했다."}, {"s": null, "t": "곰실은 쪼그려 앉아 불씨 앞에 손바닥을 펴 보였다. 불씨가 그 손바닥 위로 조심스럽게 올라앉았다."}, {"s": "q:dh_gomsil", "t": "그거면 충분하다. 이름 없는 것들은 저를 한 번 봐 준 사람을 따라온다. 이름을 받고 싶어서."}, {"s": null, "t": "나는 이 불씨에게도 내가 이름을 지어 주어야 하느냐고 물었다."}, {"s": null, "t": "곰실은 고개를 젓더니 내 동무 쪽으로 턱짓을 했다."}, {"s": "q:dh_gomsil", "t": "너는 이미 날마다 부를 이름이 하나 있잖아. 이름은 짓는 날보다 부르는 날이 훨씬 길다. 반쯤 불리다 끊긴 줄이 제일 아픈 법이야."}, {"s": "q:dh_gomsil", "t": "이 녀석은 내가 맡으마. 깜부기. 꺼질 듯 꺼지지 않으니까 깜부기다."}, {"s": null, "t": "불씨가 곰실의 손바닥 위에서 한 번 크게 일렁였다. 우리 안의 동무들이 모두 그쪽으로 고개를 돌렸다."}, {"s": null, "t": "곰실은 깜부기를 빈 우리에 옮겨 놓고 나를 돌아보았다."}, {"s": "q:dh_gomsil", "t": "{이름}, 네 동무 이름은 하루에 한 번은 꼭 불러 줘라. 그게 조련사 일이다. 화살 쏘는 건 그다음이고."}]'::jsonb, '{"xp": 81, "gil": 17, "items": {"ammo_arrow": 60, "pet_food": 3}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq2_tamer', 'side', '직업·조련사', '옥사에 남은 족제비', '옛 의금부 옥사의 쥐 떼 속에서 이름을 잃어 가는 족제비', 'old_prison', 18, '{jq_tamer}'::text[], null, 1116, '[]'::jsonb, true, 'tamer', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_tamer', 1, '닳은 나무패', '닳은 나무패', '{"at": ["hq_dorm"]}'::jsonb, '[{"s": null, "t": "객사 뒤뜰 우리 한 칸에서 깜부기가 등잔불만큼 밝게 타고 있었다. 곰실은 그 앞에 앉아 낡은 목줄 하나를 만지작거리고 있었다."}, {"s": "q:dh_gomsil", "t": "왔냐. 깜부기 좀 봐라. 날마다 불렀더니 이만큼 컸다."}, {"s": null, "t": "곰실은 목줄을 내 손에 쥐여 주었다. 목줄 끝 나무패에 「꼬미」라는 글자가 반쯤 닳아 있었다."}, {"s": "q:dh_gomsil", "t": "젊을 때 나는 옛 의금부 옥사에서 일했다. 죄수들 틈에 숨은 요괴를 동무 코로 가려내는 일이었지. 꼬미는 그때 데리고 다니던 족제비다."}, {"s": "q:dh_gomsil", "t": "옥사가 버려지던 밤에 꼬미는 나오지 않았다. 두석이라는 어린 죄수가 제 몫 밥을 덜어 먹이던 감방 앞에서 버텼지. 나는 다리를 다쳐 업혀 나왔고, 그 뒤로 다시 들어가지 못했다."}, {"s": "q:dh_gomsil", "t": "그런데 요즘 옥사 쥐 떼 사이에 족제비 한 마리가 섞여 다닌다는 말이 객사에 돈다."}, {"s": null, "t": "곰실은 지팡이를 짚고 천천히 일어섰다."}, {"s": "q:dh_gomsil", "t": "이번엔 나도 가야겠다. 다리가 느리니 네가 앞서서 옥사를 세 번쯤 돌며 꼬미 흔적부터 찾아 다오."}, {"s": null, "t": "나는 곰실을 부축해 옛 의금부 옥사로 향했다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_tamer', 2, '벽에 새긴 이름', '옛 의금부 옥사을(를) 살핀다', '{"at": ["old_prison"], "tasks": [{"t": "search", "r": ["old_prison"], "n": 3}]}'::jsonb, '[{"s": null, "t": "옥사 맨 안쪽 감방 문틀에 작은 발톱 자국이 수없이 나 있었다. 감방 벽에는 서툰 글씨로 「두석」이라는 이름이 새겨져 있었고, 그 아래에 작은 발바닥 모양이 하나 그려져 있었다."}, {"s": null, "t": "곰실은 벽의 글씨를 손끝으로 더듬다가 숨을 길게 내쉬었다."}, {"s": "q:dh_gomsil", "t": "제 손으로 새긴 이름이다. 이름이 이렇게 남아 있으면 그 애는 아직 영으로 여기 있을 거다."}, {"s": null, "t": "그때 복도 끝으로 쥐 떼가 우르르 지나갔다. 그 틈에 꼬리가 긴 짐승 한 마리가 섞여 있었다."}, {"s": null, "t": "곰실이 지팡이를 내려놓고 목소리를 높였다."}, {"s": "q:dh_gomsil", "t": "꼬미야!"}, {"s": null, "t": "족제비는 돌아보지 않았다. 족제비는 쥐 떼와 같은 쪽으로, 같은 걸음으로 어둠 속에 묻혀 갔다."}, {"s": null, "t": "곰실은 한참 동안 복도 끝을 바라보다가 낮게 말을 이었다."}, {"s": "q:dh_gomsil", "t": "너무 오래 아무도 안 불렀어. 동무는 이름이 닳으면 다시 갈래로 돌아간다. 저러다가는 쥐 떼 속에서 그냥 떼가 돼 버린다."}, {"s": "q:dh_gomsil", "t": "옥사 쥐 떼를 떼어 내 다오. 쥐들 틈에서 빠져나와야 내 목소리가 닿는다. 네 마리쯤 쓰러뜨리면 저 무리가 흩어질 거다."}]'::jsonb, '{"xp": 758}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_tamer', 3, '이름 대신 번호', '옥사 쥐 떼을(를) 물리친다', '{"at": ["old_prison"], "tasks": [{"t": "win", "m": ["r71_prison_2"], "n": 4}]}'::jsonb, '[{"s": null, "t": "쥐 떼가 흩어지자 족제비 한 마리가 홀로 감방 문 앞에 남았다. 족제비는 털이 듬성듬성 빠져 갈비뼈가 드러나 있었다."}, {"s": null, "t": "감방 안 어둠 속에는 머리를 짧게 깎은 소년의 영이 무릎을 안고 앉아 있었다. 소년은 족제비 쪽으로 손을 뻗은 채 입술만 달싹였다."}, {"s": "q:sx_duseok", "t": "꼬미야… 꼬미야."}, {"s": null, "t": "소년이 부를 때마다 복도 저편에서 쇠사슬 소리가 철컥철컥 울렸다. 쇠사슬 옥졸이 사슬을 흔들어 소년의 목소리를 덮고 있었다."}, {"s": null, "t": "소년의 영은 사슬 소리에 몸을 움츠리며 나를 올려다보았다."}, {"s": "q:sx_duseok", "t": "여기서는 이름을 부르면 안 돼요. 옥졸들이 저희를 번호로만 불렀어요. 저는 일흔세 번이었어요."}, {"s": "q:sx_duseok", "t": "제가 꼬미를 부를 때마다 저 사슬이 울어요. 그래서 제 목소리가 꼬미한테 안 닿아요."}, {"s": null, "t": "곰실이 감방 창살을 붙잡고 소년의 얼굴을 들여다보았다."}, {"s": "q:dh_gomsil", "t": "두석아, 너는 아직 네 이름을 기억하는구나. 벽에 새겨 둔 덕이다."}, {"s": null, "t": "곰실은 창살에서 손을 떼고 내 쪽으로 돌아섰다."}, {"s": "q:dh_gomsil", "t": "옥졸 두 놈만 쓰러뜨리면 사슬 소리가 그친다. 그리고 옥사에서 부적실을 세 타래 거둬 다오. 꼬미 목줄을 새로 매야겠다. 이렇게 닳은 패로는 이름이 붙어 있지 못해."}]'::jsonb, '{"xp": 758}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq2_tamer', 4, '두 목소리', '쇠사슬 옥졸을(를) 물리친다, 부적실을(를) 모은다, 부적실을(를) 넘긴다', '{"at": ["old_prison"], "tasks": [{"t": "win", "m": ["r71_prison_4"], "n": 2}, {"t": "gather", "items": ["talisman_thread"], "r": ["old_prison"], "n": 3}], "give": {"talisman_thread": 3}}'::jsonb, '[{"s": null, "t": "마지막 옥졸이 쓰러지자 복도의 사슬 소리가 뚝 그쳤다. 옥사 안이 귀가 먹먹할 만큼 조용해졌다."}, {"s": null, "t": "곰실은 내가 건넨 부적실로 새 목줄을 매고, 새 나무패에 「꼬미」라고 또박또박 새겼다. 그러고는 창살 너머 소년에게 눈짓을 했다."}, {"s": "q:dh_gomsil", "t": "같이 부르자, 두석아. 하나, 둘."}, {"s": null, "t": "곰실과 소년의 영이 한목소리로 꼬미를 불렀다. 족제비가 반 박자 늦게 고개를 들더니, 곧바로 달려와 곰실의 무릎과 창살 사이를 오가며 두 사람의 손에 번갈아 코를 비볐다."}, {"s": null, "t": "소년의 영은 창살 사이로 손을 내밀어 꼬미의 등을 쓸었다. 소년의 손은 털을 스치지 못하고 그대로 지나갔다. 소년은 그래도 웃었다."}, {"s": "q:sx_duseok", "t": "저는 여기서 못 나가요. 제 이름이 이 벽에 있으니까요. 그래도 괜찮아요. 이름이 남아 있으면 잊힌 게 아니라고 들었어요."}, {"s": "q:sx_duseok", "t": "아주머니가 꼬미를 데려가서 날마다 불러 주세요. 저 대신요. 꼬미가 다시 쥐 떼가 되지 않게요."}, {"s": null, "t": "곰실은 목줄을 꼬미 목에 걸어 주고 창살 앞에 주먹밥 한 덩이를 놓았다."}, {"s": "q:dh_gomsil", "t": "그러마. 그리고 너도 부르러 오마. 철마다 한 번씩, 꼬미 데리고."}, {"s": null, "t": "옥사를 나서는 길에 곰실은 꼬미를 품에 안은 채 내 쪽을 돌아보았다."}, {"s": "q:dh_gomsil", "t": "오늘 봤지. 동무는 저를 부르는 목소리가 끊기면 길을 잃는다. 그런데 부르는 사람이 둘이면 하나가 끊겨도 버틴다."}, {"s": "q:dh_gomsil", "t": "내 옛 짝 무던도 그랬으면 좋았을 텐데. 그 사람은 요기를 너무 많이 입어서 서른 해 전에 바다 건너 섬으로 보내졌다. 내가 안겨 준 수달 한 마리를 끝까지 품에 안고 갔지."}, {"s": "q:dh_gomsil", "t": "네가 언젠가 그 섬까지 가게 되거든, 무던이라는 이름을 아는 사람이 있는지 물어봐 다오."}]'::jsonb, '{"xp": 758, "gil": 77, "items": {"tonic": 2, "travel_ration": 1}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quests(quest_id, kind, cat, title, summary, region_id, min_level, after, chapter_id, sort, epilogue, active, job_key, faction_key)
values ('jq3_tamer', 'side', '직업·조련사', '서로 부르는 이름', '섬으로 보내진 곰실의 옛 짝과, 그 이름을 놓지 않은 수달', 'ash_reeds', 32, '{jq2_tamer,mq_nine_gates}'::text[], null, 1183, '[]'::jsonb, true, 'tamer', null)
on conflict (quest_id) do update set cat = excluded.cat, title = excluded.title, summary = excluded.summary, region_id = excluded.region_id, min_level = excluded.min_level, after = excluded.after, sort = excluded.sort, active = true, job_key = excluded.job_key;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_tamer', 1, '비워 둔 줄', '비워 둔 줄', '{"at": ["banyo_village"]}'::jsonb, '[{"s": null, "t": "반요촌 문패장이 솔뫼의 마당에는 깎다 만 문패 판자가 처마 밑까지 쌓여 있었다. 솔뫼는 판자 하나에 이름 두 줄을 새기다 말고 나를 올려다보았다."}, {"s": "q:sx_solmoe", "t": "섬 밖에서 오신 조사원이네요. 문패장이한테 오셨으면 찾는 이름이 있으시겠네요?"}, {"s": null, "t": "나는 곰실에게 들은 이야기를 했다. 서른 해 전에 수달 한 마리를 안고 섬으로 건너온 조련사가 있고, 그 사람의 이름이 무던이라고 했다."}, {"s": null, "t": "솔뫼는 끌을 내려놓고 문패 판자 더미를 한참 뒤적였다."}, {"s": "q:sx_solmoe", "t": "무던이라는 이름은 제 문패에 없어요. 그런데 갈대숲 가에 수달 한 마리를 데리고 사는 반요 할아버지가 한 분 계세요. 섬에서 지은 이름은 「갈대지기」예요."}, {"s": "q:sx_solmoe", "t": "그분 문패는 제가 새겼는데, 바깥 이름 줄은 비워 뒀어요. 할아버지가 아무리 애써도 바깥 이름을 떠올리지 못하셨거든요."}, {"s": "q:sx_solmoe", "t": "이상한 건 수달이에요. 해 질 녘마다 갈대숲 여기저기로 달려가서 무언가를 파내고 와요. 그 수달이 가는 데를 몇 번 따라가 보세요. 저도 판자 하나 들고 같이 갈게요."}, {"s": null, "t": "솔뫼는 빈 판자 하나를 옆구리에 끼고 나를 따라나섰다."}]'::jsonb, '{}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_tamer', 2, '수달이 파낸 나무패', '잿빛 갈대숲을(를) 살핀다', '{"at": ["ash_reeds"], "tasks": [{"t": "search", "r": ["ash_reeds"], "n": 3}]}'::jsonb, '[{"s": null, "t": "수달은 갈대 뿌리 사이를 파헤쳐 진흙투성이 나무패 하나를 물고 나왔다. 나무패 앞면에는 「달봉」, 뒷면에는 손톱으로 긁은 듯한 글씨로 「무던」이 새겨져 있었다."}, {"s": null, "t": "내가 「달봉」을 소리 내어 읽자 수달이 꼬리를 세우고 짧게 울었다. 내가 「무던」을 읽자 수달은 갈대숲 안쪽으로 쏜살같이 달려갔다."}, {"s": null, "t": "수달이 달려간 물가에는 갈대 잎 같은 요문이 목덜미까지 돋은 노인이 서 있었다. 노인은 수달이 다리에 몸을 비비자 한 박자 늦게 고개를 숙였다."}, {"s": "q:sx_galdae", "t": "…누가 부른 것 같았소. 누가 부른 것 같았소."}, {"s": null, "t": "솔뫼가 내 옆으로 다가와 나무패를 들여다보았다."}, {"s": "q:sx_solmoe", "t": "수달이 이름 둘을 다 알아들었어요. 제 이름도, 할아버지 이름도요."}, {"s": null, "t": "그때 물가 갈대가 한꺼번에 노인 쪽으로 쏠렸다. 물속에서 갈대를 휘감은 물귀신들이 노인의 발목을 향해 손을 뻗었다."}, {"s": null, "t": "솔뫼는 들고 온 판자를 방패처럼 쳐들고 노인 앞을 가로막았다."}, {"s": "q:sx_solmoe", "t": "갈대 물귀신이에요! 이름이 흐린 사람은 저것들한테 쉽게 끌려가요. 네 마리쯤 쫓아내 주세요."}]'::jsonb, '{"xp": 2065}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_tamer', 3, '동무가 쥐고 있던 이름', '갈대 물귀신을(를) 물리친다', '{"at": ["ash_reeds"], "tasks": [{"t": "win", "m": ["gw_reed_1"], "n": 4}]}'::jsonb, '[{"s": null, "t": "물귀신들이 물속으로 흩어지자 노인은 물가에 주저앉았다. 수달은 노인의 무릎 위에 올라가 젖은 몸을 둥글게 말았다."}, {"s": "q:sx_galdae", "t": "이 녀석 이름을 모르겠소. 서른 해를 같이 살았는데도 모르겠소. 그래도 이 녀석은 늘 내 곁에 있었소."}, {"s": null, "t": "솔뫼는 노인 옆에 쪼그려 앉아 나무패를 노인의 손에 쥐여 주었다."}, {"s": "q:sx_solmoe", "t": "할아버지, 동무는 제 이름을 지어 준 사람의 이름을 잊지 않는대요. 말을 못 하니까 그 이름이 불리는 쪽으로 대신 달려가는 거래요. 아까 이 수달이 그랬어요."}, {"s": null, "t": "나는 곰실의 말을 떠올렸다. 동무는 저를 부르는 목소리를 붙들려고 사람을 따라다닌다. 그렇다면 이 수달은 노인이 제 이름을 잊은 서른 해 동안 그 이름을 대신 붙들고 있었던 셈이었다."}, {"s": null, "t": "솔뫼는 빈 판자를 무릎에 올려놓고 끌로 판자 귀퉁이를 톡톡 두드렸다."}, {"s": "q:sx_solmoe", "t": "섬에서는 문패에 이름 둘을 적어요. 바깥 이름이 흐려질 때를 대비해서요. 오늘은 비워 둔 줄을 채울 수 있겠어요."}, {"s": "q:sx_solmoe", "t": "그런데 갈대숲 깊은 데서 잿빛 갈대 어미가 이 물가 갈대를 다 휘어잡고 있어요. 저게 있으면 문패를 걸어도 밤마다 갈대에 뜯겨 나가요. 어미를 한 번 쓰러뜨려 주세요. 그리고 이 숲에서 부적목을 세 토막만 거둬서 반요촌 제 마당으로 가져다 주세요. 그 나무에 새겨야 섬 바람을 견뎌요."}]'::jsonb, '{"xp": 2065}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_quest_steps(quest_id, step, title, goal, need, lines, reward) values ('jq3_tamer', 4, '서로 부르는 이름', '잿빛 갈대 어미을(를) 물리친다, 부적목을(를) 모은다, 부적목을(를) 넘긴다', '{"at": ["banyo_village"], "tasks": [{"t": "win", "m": ["gw_reed_5"], "n": 1}, {"t": "gather", "items": ["wood"], "r": ["ash_reeds"], "n": 3}], "give": {"wood": 3}}'::jsonb, '[{"s": null, "t": "솔뫼는 마당에서 부적목을 다듬어 새 문패를 깎았다. 솔뫼는 윗줄에 「무던」, 아랫줄에 「갈대지기」를 새기고, 문패 끝에 작은 글씨로 「달봉」을 덧붙였다."}, {"s": null, "t": "노인은 문패 앞에 서서 글자를 손끝으로 한 자씩 짚었다. 수달은 그 발치에 앉아 노인을 올려다보았다."}, {"s": "q:sx_galdae", "t": "무던… 무던. 그래, 곰실이 나를 그렇게 불렀소. 이 녀석을 내 품에 안겨 주던 날에도 그렇게 불렀소."}, {"s": null, "t": "노인은 허리를 굽혀 수달을 두 손으로 안아 올렸다. 노인의 목소리는 떨렸지만 끝까지 또렷했다."}, {"s": "q:sx_galdae", "t": "달봉아."}, {"s": null, "t": "수달이 노인의 턱 밑에 머리를 묻었다. 노인은 서른 해 만에 처음으로 그 이름을 불렀고, 수달은 그동안 지켜 온 이름의 주인을 향해 몸을 기댔다."}, {"s": null, "t": "솔뫼는 끌을 내려놓고 두 손을 무릎에 얹은 채 그 모습을 지켜보았다."}, {"s": "q:sx_solmoe", "t": "이제 두 분이 서로를 부를 수 있네요. 한 분이 잊어도 다른 한 분이 부르면 되니까, 이 문패는 오래갈 거예요."}, {"s": null, "t": "노인은 문패를 제 집 문설주에 걸고 내 쪽으로 돌아섰다."}, {"s": "q:sx_galdae", "t": "곰실한테 전해 주오. 무던은 아직 여기 있다고. 이름을 잃었다가 이 녀석 덕에 도로 찾았다고."}, {"s": "q:sx_galdae", "t": "그리고 조련사 양반, 당신 동무 이름도 날마다 불러 주시오. 언젠가 당신이 당신 이름을 놓칠 날이 오면, 그 녀석이 대신 쥐고 있을 테니."}]'::jsonb, '{"xp": 2065, "gil": 133, "items": {"moonlight_essence": 2, "travel_ration": 2}}'::jsonb)
on conflict (quest_id, step) do update set title = excluded.title, goal = excluded.goal, need = excluded.need, lines = excluded.lines, reward = excluded.reward;
insert into public.world_pet_sources(source, pet_id) values ('quest:jq2_tamer', 'little_ferret') on conflict do nothing;
select public.world_quest_label_refresh();

update public.world_pet_species set grade = 3, how = '퀘스트 「옥사에 남은 족제비」을(를) 마친다 · 빛나는 알' where pet_id = 'little_ferret';

alter table public.world_monster_kinds drop column job_key;

insert into public.world_patch_notes(note_id, title, body) values ('2.1.0', '2.1.0 · 새 직업 「조련사」', $n$새 직업 「조련사(調練師)」가 문을 엽니다. 활로 쏘는 원거리 공격수이면서, 데리고 다니는 꼬마 동무와 함께 싸우는 직업입니다.

## 조련사
- 조사원을 만들 때 고를 수 있고, 「환골탈태 서첩」으로 직업을 바꿀 때도 고를 수 있습니다.
- 처음 만들 때 함께 시작할 꼬마 동무를 넷 가운데 하나 고릅니다(누렁 강아지·얼룩 고양이·참새·무당벌레). 동무 주먹밥 다섯 개도 함께 받습니다.
- 기본 능력치는 월궁 사수에서 민첩 한 점을 체질로 옮긴 꼴(민첩 7·감각 8·체질 5)입니다. 무기는 활·쇠뇌·취관 같은 원거리 무기를 월궁 사수와 함께 씁니다.
- 직업 효과는 따로 없고, 그 몫이 모두 동무에게 갑니다. 공격하는 차례마다 데리고 다니는 동무가 한 번 덧붙어 싸웁니다.
- 동무의 힘은 등급이 아니라 친밀도로만 정해집니다. 친밀도가 오를수록 동무가 더 세게, 더 자주 제 몫을 합니다.
- 동무는 무리마다 하는 일이 다릅니다: 지키는 동무(금주·갑각·거괴)는 다음 공격을 막아서고, 무는 동무(은형·파봉·목령)는 물린 상처를 남기며, 쪼는 동무(비금·천상)는 허상·공중에 막히지 않고 틈을 벌리고, 홀리는 동무(영귀·수귀·독충·군충·경요)는 요괴의 기세를 흐립니다.
- 현장 기술 「휘파람」: 원거리 ×1.2로 쏘고, 그 차례 동무의 동작이 반드시 터지며 동무 피해가 두 배가 됩니다.
- 원정 기술 「동무의 코」: 원정에서 길·채집터·숨은 것을 더 잘 찾고, 싸움에서도 동무가 조금 거듭니다.
- 군충·은형 요괴에 강합니다. 은형은 월궁 사수와 함께 유리한 갈래가 되었습니다.
- 기술 계열 「조련」이 새로 생겼습니다. 화살 쪽은 사격보다 덜 오르고 동무 피해가 오릅니다. 24·43단계 택일은 「사냥」과 「돌봄」 갈래, 50단계 숙달은 「이름의 끈」입니다.
- 협동 기술 넷(물어 와·곁 지키기·몰이·한 몸 사냥)은 모두 동무를 거칩니다.
- 혼자 귀허의 주인·10장 결전에 도전할 때의 직업 보정이 조련사에게도 붙습니다. 보스 체력은 동무의 몫까지 함께 셈합니다.
- 직업 퀘스트 세 편: 본부 객사 「이름 없는 불씨」(Lv3), 옛 의금부 옥사 「옥사에 남은 족제비」(Lv18), 잿빛 갈대숲 「서로 부르는 이름」(Lv32). 둘째 편을 마치면 꼬마 족제비가 동무가 됩니다.
- 조련사 기본 옷 한 벌이 「내 모습」에 더해졌습니다.

## 꼬마 동무
- 데리고 다니는 동무도 별채 동무처럼 쓰다듬고 놀아 주고 먹이를 줄 수 있습니다(모든 직업, 별채가 없어도 됩니다). 별채 › 동무 도감의 「데리고 다니는 동무」 칸에서 「돌보기」를 누르세요. 하루 횟수는 그 동무 몫으로 함께 셉니다.
- 조련사가 돌보면 친밀도가 1.5배로 오르고, 남의 별채 동무를 돌볼 때도 2씩 오릅니다. 함께 이긴 토벌마다 친밀도가 1 오릅니다(하루 10까지).
- 꼬마 족제비는 진품이 되었습니다. 이제 「빛나는 알」에서 나오고, 「얼룩무늬 알」에서는 나오지 않습니다.
$n$) on conflict (note_id) do update set title = excluded.title, body = excluded.body;

create or replace function public.world_avatar_parts()
 returns jsonb language sql immutable
as $f$ select '{"free":{"skins":["deep","fair","tan","warm"],"hair":["buns","calm","cloud","curly","curtain","fluffy","halfup","layered","long","pony","princess","sports","twintail"],"hairColors":["black","brown","chestnut","gold","indigo","peach","red","silver"],"eyes":["cat","dot","droopy","round","sharp","sleepy","smile","sparkle","teary","wink"],"eyeColors":["amber","blue","brown","crimson","dark","jade"],"mouth":["cat","grin","open","pout","small","smile"]},"outfits":{"top:guard":{"slot":"top","name":"쇠미늘 갑옷","grade":1},"top:scout":{"slot":"top","name":"무명 철릭","grade":1},"top:exorcist":{"slot":"top","name":"삼베 도포","grade":1},"top:medic":{"slot":"top","name":"쑥빛 앞치마 도포","grade":1},"top:seal":{"slot":"top","name":"누비 전포","grade":1},"top:shadow":{"slot":"top","name":"먹빛 누비 전포","grade":1},"top:tamer":{"slot":"top","name":"털깃 사냥 저고리","grade":1},"top:jeogori":{"slot":"top","name":"연분홍 저고리","grade":1},"top:vest":{"slot":"top","name":"무명 조끼","grade":1},"top:magoja":{"slot":"top","name":"짧은 마고자","grade":1},"top:jeoksam":{"slot":"top","name":"짧은 적삼","grade":1},"bottom:guard":{"slot":"bottom","name":"검은 바지와 가죽 장화","grade":1},"bottom:scout":{"slot":"bottom","name":"고동 바지와 미투리","grade":1},"bottom:exorcist":{"slot":"bottom","name":"쪽빛 대님 바지","grade":1},"bottom:medic":{"slot":"bottom","name":"무명 대님 바지","grade":1},"bottom:seal":{"slot":"bottom","name":"검은 바지","grade":1},"bottom:shadow":{"slot":"bottom","name":"먹빛 바지와 짚신","grade":1},"bottom:tamer":{"slot":"bottom","name":"각반 바지와 미투리","grade":1},"bottom:chima":{"slot":"bottom","name":"남빛 치마","grade":1},"acc:flowerpin":{"slot":"acc","name":"꽃 머리핀","grade":1},"acc:glasses":{"slot":"acc","name":"둥근 안경","grade":1},"acc:earring":{"slot":"acc","name":"구슬 귀걸이","grade":1},"acc:scarf":{"slot":"acc","name":"목도리","grade":1},"acc:norigae":{"slot":"acc","name":"노리개","grade":1},"acc:foxmask":{"slot":"acc","name":"여우 탈","grade":1}},"job":{"artificer":{"top":"guard","bottom":"guard"},"scout":{"top":"scout","bottom":"scout"},"exorcist":{"top":"exorcist","bottom":"exorcist"},"medic":{"top":"medic","bottom":"medic"},"sealmaster":{"top":"seal","bottom":"seal"},"analyst":{"top":"shadow","bottom":"shadow"},"tamer":{"top":"tamer","bottom":"tamer"}},"masks":{"top:guard":{"n":40,"deco":3},"top:scout":{"n":70,"deco":3},"top:exorcist":{"n":79,"deco":3},"top:medic":{"n":46,"deco":3},"top:seal":{"n":42,"deco":3},"top:shadow":{"n":58,"deco":3},"top:tamer":{"n":64,"deco":3},"top:jeogori":{"n":35,"deco":3},"top:vest":{"n":28,"deco":3},"top:magoja":{"n":44,"deco":2},"top:jeoksam":{"n":47,"deco":2},"bottom:guard":{"n":20,"deco":1},"bottom:scout":{"n":32,"deco":1},"bottom:exorcist":{"n":30,"deco":2},"bottom:medic":{"n":30,"deco":2},"bottom:seal":{"n":32,"deco":1},"bottom:shadow":{"n":32,"deco":1},"bottom:tamer":{"n":32,"deco":1},"bottom:chima":{"n":64,"deco":1}}}'::jsonb $f$;
insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values
('of_top_tamer', '털깃 사냥 저고리', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "top:tamer"}'::jsonb),
('of_bottom_tamer', '각반 바지와 미투리', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{"look": "bottom:tamer"}'::jsonb)
on conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, equipment_traits = excluded.equipment_traits;
select pg_temp.yh_fix('world_outfit_rules', array[$q$"of_top_shadow", "of_bottom_shadow"]$q$, $q$"of_top_shadow", "of_bottom_shadow", "of_top_tamer", "of_bottom_tamer"]$q$]);

update public.world_app_meta set value = '20261116020000' where key = 'db_version';
