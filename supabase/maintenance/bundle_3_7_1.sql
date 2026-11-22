-- 배포 앞(운영 전용): 운영의 postgres는 슈퍼유저가 아니라 inherit 없는 함수 주인 역할(fn_owner_*)의 함수를 create or replace 할 수 없다.
-- 이 트랜잭션 동안만 inherit을 켜고, owner_inherit_end.sql이 같은 목록을 원래대로(inherit false) 되돌린다.
create temp table yh_inh on commit drop as
select distinct r.rolname::text as r from pg_proc p join pg_roles r on r.oid = p.proowner
 where p.pronamespace = 'public'::regnamespace and r.rolname like 'fn\_owner%' and not pg_has_role('postgres', r.oid, 'USAGE');
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit true', x); end loop; end $i$;

create or replace function public.world_weapon_rank_rules() returns jsonb
language sql immutable set search_path to 'pg_catalog', 'public'
as $$ select '{"steps":[[1,1],[10,5],[14,10],[20,15],[32,25],[42,33],[47,38]]}'::jsonb $$;

create or replace function public.world_weapon_rank_need(p_level integer) returns integer
language sql immutable set search_path to 'pg_catalog', 'public'
as $$ select coalesce((select (s ->> 1)::int from jsonb_array_elements(public.world_weapon_rank_rules() -> 'steps') s
  where (s ->> 0)::int <= coalesce(p_level, 1) order by (s ->> 0)::int desc limit 1), 1) $$;

do $m$
declare src text; o text;
begin
  select prosrc into src from pg_proc where oid = 'public.world_equip_item(text)'::regprocedure;
  o := ' for stat_key,required in select key,value::text::int from jsonb_each(coalesce(it.required_stats,''{}''::jsonb)) loop';
  if position(o in src) = 0 then raise exception 'world_equip_item 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
    ' if it.category = ''weapon'' and coalesce((c.skill_progress -> public.world_job_line(c.job_key) ->> ''rank'')::int, 1) < public.world_weapon_rank_need(it.minimum_level) then' || chr(10) ||
    '   raise exception ''기술이 모자랍니다: % %단계 이상이어야 합니다(지금 %단계).'', public.world_line_name(public.world_job_line(c.job_key)), public.world_weapon_rank_need(it.minimum_level), coalesce((c.skill_progress -> public.world_job_line(c.job_key) ->> ''rank'')::int, 1) using hint = ''weapon_rank'';' || chr(10) ||
    ' end if;' || chr(10) ||
    ' for stat_key,required in select key,value::text::int from jsonb_each(case when it.category = ''weapon'' then ''{}''::jsonb else coalesce(it.required_stats,''{}''::jsonb) end) loop');
  execute format('create or replace function public.world_equip_item(p_item_id text) returns jsonb language plpgsql security definer set search_path to ''pg_catalog'', ''public'' as %L', src);
end $m$;

update public.world_item_catalog set required_stats = '{}'::jsonb where category = 'weapon' and required_stats is distinct from '{}'::jsonb;

do $m$
declare r record;
begin
  for r in select p.oid::regprocedure f, pg_get_userbyid(e.proowner) own from pg_proc p, pg_proc e
    where p.proname in ('world_weapon_rank_rules', 'world_weapon_rank_need') and p.pronamespace = 'public'::regnamespace
      and e.oid = 'public.world_equip_item(text)'::regprocedure loop
    execute format('revoke all on function %s from public, anon, authenticated', r.f);
    execute format('grant execute on function %s to %I', r.f, r.own);
  end loop;
end $m$;

update public.world_patch_notes set body = body || E'\n\n## 3.7.1\n- 무기 장착 조건이 능력치 대신 지금 직업의 전투 기술 단계로 바뀌었습니다. 장착 레벨은 그대로이고, 장착 레벨 10 이상 무기는 5단계, 14 이상은 10단계, 20 이상은 15단계, 32 이상은 25단계, 42 이상은 33단계, 47 이상은 38단계가 필요합니다. 직업을 바꾸면 새 직업의 기술을 키워야 높은 무기를 들 수 있습니다.\n- 이미 끼고 있는 무기는 기준에 못 미쳐도 그대로 씁니다. 장비 칸에 안내가 한 줄 뜨고, 내려놓으면 그 단계가 되기 전에는 다시 낄 수 없습니다.\n- 방어구·장신구의 능력치 조건은 그대로입니다.'
 where note_id = '3.7.0' and body not like '%## 3.7.1%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126010000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

do $m$
declare src text; o text; def text;
begin
  select prosrc into src from pg_proc where oid = 'public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean)'::regprocedure;
  o := 'if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, ab, ''guard'')); end if;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_cb_mitigate 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'if vby is not null and vby <> p_self::text then cr := cr || jsonb_build_array(jsonb_build_array(vby, ab, ''guard''), jsonb_build_array(vby, ab, ''shield'')); end if;');
  def := regexp_replace(pg_get_functiondef('public.world_cb_mitigate(numeric, jsonb, jsonb, uuid, boolean, boolean, text, boolean)'::regprocedure), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 봉연의 그림자·귀허류 싸움의 피해 기록 「회복」 칸에 동료에게 씌운 보호막이 막아 낸 피해가 함께 셈해지고, 막대와 숫자는 회복과 나눠 다른 색으로 보입니다.\n- 싸움 화면 참가자 칸과 피해 기록에 조련사·혈기사·여명 창객·진법가의 직업 색이 붙습니다.'
 where note_id = '3.7.0' and body not like '%동료에게 씌운 보호막이 막아 낸 피해가 함께%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126020000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function public.world_presence_rules() returns jsonb
language sql immutable
as $$
  select jsonb_build_object('cap', jsonb_build_object('artificer', 300, 'bloodknight', 300, 'sealmaster', 220), 'cap_other', 160, 'aggro_pow', 1.5)
$$;

create or replace function public.world_cb_aggro(p_pres numeric) returns numeric
language sql immutable
as $$ select power(greatest(5, coalesce(p_pres, 30)), (public.world_presence_rules() ->> 'aggro_pow')::numeric) $$;

create or replace function public.world_cb_pick_key(p_pres numeric) returns double precision
language sql volatile
as $$ select -ln(greatest(random(), 1e-9)) / power(greatest(5, coalesce(p_pres, 30)), (public.world_presence_rules() ->> 'aggro_pow')::numeric)::float8 $$;

do $m$
declare v jsonb := public.world_contrib_rules();
begin
  v := jsonb_set(jsonb_set(v, '{job_mul,bloodknight}', '1.2'), '{job_mul,spearman}', '1.0');
  execute format('create or replace function public.world_contrib_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
end $m$;

update public.world_patch_notes set body = body || E'\n- 합동 토벌·귀허류 싸움·파티 토벌·파티 원정에서 요괴가 이목이 높은 사람을 전보다 더 자주 노립니다.\n- 싸움 기여도의 직업 보정을 고쳤습니다. 혈기사는 올리고 여명 창객은 조금 내렸습니다.'
 where note_id = '3.7.0' and body not like '%이목이 높은 사람을 전보다 더 자주%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126030000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

do $m$
declare src text; def text; fn regprocedure; o text; n text;
begin
  fn := 'public.world_raid_action'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'h0 int; h1 int; amt int;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 선언 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'h0 int; h1 int; amt int; v_lh int := 0;');
  o := '  update public.world_characters set spiritual_power = sp, inventory = inv,' || chr(10) || '    health = case when health > 0 then least(100, health + coalesce(nullif(current_setting(''yh.leech'', true), '''')::int, 0)) else health end, updated_at = now() where owner_id = uid;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 피흡 자리 모양이 예상과 다릅니다'; end if;
  n := '  v_lh := coalesce(nullif(current_setting(''yh.leech'', true), '''')::int, 0);' || chr(10) ||
       '  if v_lh > 0 then select greatest(0, least(100 - x.health, v_lh)) into v_lh from public.world_characters x where x.owner_id = uid and x.health > 0; v_lh := coalesce(v_lh, 0); end if;' || chr(10) ||
       o || chr(10) ||
       '  if v_lh > 0 then mb.heal := mb.heal + v_lh; perform public.world_raid_credit(p_raid, uid, v_lh, ''heal_self''); end if;';
  src := replace(src, o, n);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_gw_resolve'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'declare cbr jsonb;';
  if position(o in src) = 0 then raise exception 'world_gw_resolve 선언 모양이 예상과 다릅니다'; end if;
  src := regexp_replace(src, '^(\s*)declare cbr jsonb;', E'\\1declare v_lh int; cbr jsonb;');
  o := 'update public.world_gw_members set hp = least(100, hp + public.world_leech_of(m.owner_id, d)) where fight_id = p_fight and owner_id = m.owner_id and out_rounds = 0 and hp > 0;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_gw_resolve 피흡 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
    'v_lh := null; select greatest(0, least(100 - x.hp, public.world_leech_of(m.owner_id, d))) into v_lh from public.world_gw_members x where x.fight_id = p_fight and x.owner_id = m.owner_id and x.out_rounds = 0 and x.hp > 0;' || chr(10) ||
    '          if coalesce(v_lh, 0) > 0 then update public.world_gw_members set hp = hp + v_lh, heal = heal + v_lh where fight_id = p_fight and owner_id = m.owner_id; perform public.world_gw_credit(p_fight, m.owner_id, v_lh, ''heal_self''); end if;');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 피해 기록 「회복」 칸에 혈기사가 피를 흡수해 되찾은 체력도 함께 셈해집니다.'
 where note_id = '3.7.0' and body not like '%피를 흡수해 되찾은 체력도%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126040000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

do $m$
declare v jsonb := public.world_shadow_rules() || '{"tank_pres": {"mul": 2, "jobs": ["artificer", "bloodknight"]}}'::jsonb;
  src text; def text; fn regprocedure := 'public.world_raid_action'::regproc::regprocedure; o text;
begin
  execute format('create or replace function public.world_shadow_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
  select prosrc into src from pg_proc where oid = fn;
  o := 'order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 표적 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric * case when rd.kind = ''world'' and public.world_shadow_rules() -> ''tank_pres'' -> ''jobs'' ? x.job_key then (public.world_shadow_rules() -> ''tank_pres'' ->> ''mul'')::numeric else 1 end + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

update public.world_patch_notes set body = body || E'\n- 봉연의 그림자는 호위 무사·혈기사를 다른 조사원보다 훨씬 자주 노립니다.'
 where note_id = '3.7.0' and body not like '%호위 무사·혈기사를 다른 조사원보다 훨씬 자주%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126050000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

do $m$
declare src text; def text; fn regprocedure; o text;
begin
  fn := 'public.world_battle_action'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'hp := least(100, hp + extra); lines := lines || jsonb_build_array(''흘린 피를 갈무리했다. 체력 +'' || extra);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_battle_action 피흡 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'PERFORM set_config(''yh.pf_leech'', (least(100, hp + extra) - hp)::text, true); ' || o);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_pfight_resolve'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'perform set_config(''yh.pf_cost'', '''', true);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pfight_resolve 차례 시작 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, o || ' perform set_config(''yh.pf_leech'', '''', true);');
  o := 'taken = pm.taken + greatest(0, coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health) - c.health - coalesce(nullif(current_setting(''yh.pf_cost'', true), '''')::int, 0)),' || chr(10) ||
       '        heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health))';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_pfight_resolve 회복 셈 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
       'taken = pm.taken + greatest(0, coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health) - (c.health - coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0)) - coalesce(nullif(current_setting(''yh.pf_cost'', true), '''')::int, 0)),' || chr(10) ||
       '        heal = pm.heal + greatest(0, c.health - coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0) - coalesce(nullif(current_setting(''yh.pf_hb'', true), '''')::int, c.health)) + coalesce(nullif(current_setting(''yh.pf_leech'', true), '''')::int, 0)');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126060000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

do $m$
declare v jsonb := public.world_shadow_rules() || jsonb_build_object('name', '사슬 벗은 그림자', 'mk2', jsonb_build_object(
    'brand', jsonb_build_object('every', 10, 'off', 3, 'delay', 6, 'mul', 5, 'streak', 0.5, 'cap', 2),
    'grip', jsonb_build_object('every', 8, 'off', 5, 'dmg', 6, 'beats', 10, 'pick', 3),
    'ink', jsonb_build_object('beats', 3, 'dmg', 2),
    'counter_mul', 2));
begin
  execute format('create or replace function public.world_shadow_rules() returns jsonb language sql immutable set search_path = pg_catalog as %L', ' select ' || quote_literal(v::text) || '::jsonb ');
end $m$;

create or replace function public.world_shadow_pres(p_kind text, p_job text, p_stats jsonb, p_fx jsonb) returns numeric
language sql stable set search_path = pg_catalog, public
as $$ select coalesce((p_stats ->> 'pres')::numeric, 30) * case when p_kind = 'world' and public.world_shadow_rules() -> 'tank_pres' -> 'jobs' ? p_job then (public.world_shadow_rules() -> 'tank_pres' ->> 'mul')::numeric else 1 end + coalesce((p_fx -> 'taunt' ->> 'pres')::numeric, 0) $$;
revoke all on function public.world_shadow_pres(text, text, jsonb, jsonb) from public, anon, authenticated;
grant execute on function public.world_shadow_pres(text, text, jsonb, jsonb) to fn_owner_field, service_role;

do $m$
declare src text; def text; fn regprocedure; o text; n text;
begin
  fn := 'public.world_raid_hit'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := '  if f ? ''cover'' and (f -> ''cover'' ->> ''until'')::timestamptz > now() then';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 대신 막기 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '  if p_kind not in (''grip'', ''ink'') and f ? ''cover'' and (f -> ''cover'' ->> ''until'')::timestamptz > now() then');
  o := '  if rk = ''world'' then p_raw := p_raw *';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 세기 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '  if p_kind in (''grip'', ''ink'') then st := ''{}''::jsonb; end if;' || chr(10) || '  if rk = ''world'' and p_kind not in (''grip'', ''ink'') then p_raw := p_raw *');
  o := 'r := public.world_cb_mitigate(p_raw, st, m.fx, who, p_kind in (''slam'', ''burst''), p_kind = ''burst'', null, p_kind = ''single'');';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 경감 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'r := public.world_cb_mitigate(p_raw, st, m.fx, who, p_kind in (''slam'', ''burst''), p_kind in (''burst'', ''buster''), null, p_kind = ''single'');');
  o := '  if p_kind = ''single'' and not coalesce((r ->> ''taunt'')::boolean, false) then';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 받아 냄 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '  if p_kind in (''single'', ''buster'') and not coalesce((r ->> ''taunt'')::boolean, false) then');
  o := '  if p_kind = ''single'' then' || chr(10) || '    self_guard';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 스스로 막음 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '  if p_kind in (''single'', ''buster'') then' || chr(10) || '    self_guard');
  o := 'perform public.world_raid_say_n(p_raid, ''hit'', nm || '' — '' || d || ''의 피해'' || ''.'', nm, d);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_hit 기록 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'perform public.world_raid_say_n(p_raid, ''hit'', nm || '' — '' || case p_kind when ''grip'' then ''손아귀에 짓눌려 '' when ''ink'' then ''묵흔이 번져 '' when ''buster'' then ''검은 낙인에 '' else '''' end || d || ''의 피해'' || ''.'', nm, d);');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_raid_action'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := 'bt int; tick boolean := true;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 선언 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, 'bt int; mk jsonb; gx int; tick boolean := true;');

  o := '    mul := mul * psolo;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 공격 배율 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, o || chr(10) || '    if f ? ''grip'' then mul := mul * 0.5; end if;');

  o := '    mb.heal := mb.heal + greatest(0, h1 - h0); credit := greatest(0, h1 - h0);';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 물품 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, o || chr(10) || '    if h1 > h0 and f ? ''ink'' then perform public.world_raid_credit(p_raid, uid, coalesce((f -> ''ink'' ->> ''n'')::int, 0) * (public.world_shadow_rules() -> ''mk2'' -> ''ink'' ->> ''dmg'')::numeric, ''heal_self''); f := f - ''ink''; end if;');

  o := '    if sk.target in (''ally'', ''self'') and tgt = uid then';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 기술 대상 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o,
    '    if rd.kind = ''world'' then' || chr(10) ||
    '      mk := public.world_shadow_rules() -> ''mk2'';' || chr(10) ||
    '      if k in (''heal'', ''cleanse_heal'') then' || chr(10) ||
    '        select coalesce((x.fx -> ''ink'' ->> ''n'')::int, 0) into gx from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = tgt;' || chr(10) ||
    '        if coalesce(gx, 0) > 0 then perform public.world_raid_credit(p_raid, uid, gx * (mk -> ''ink'' ->> ''dmg'')::numeric, case when tgt = uid then ''heal_self'' else ''heal'' end);' || chr(10) ||
    '          if tgt = uid then f := f - ''ink''; else update public.world_raid_members set fx = fx - ''ink'' where raid_id = p_raid and owner_id = tgt; end if; end if;' || chr(10) ||
    '      elsif k = ''heal_all'' then' || chr(10) ||
    '        select coalesce(sum((x.fx -> ''ink'' ->> ''n'')::int), 0) into gx from public.world_raid_members x where x.raid_id = p_raid and x.fx ? ''ink'' and x.out_until is null;' || chr(10) ||
    '        if gx > 0 then perform public.world_raid_credit(p_raid, uid, gx * (mk -> ''ink'' ->> ''dmg'')::numeric, ''heal''); end if;' || chr(10) ||
    '        update public.world_raid_members set fx = fx - ''ink'' where raid_id = p_raid and owner_id <> uid and fx ? ''ink'' and out_until is null; f := f - ''ink'';' || chr(10) ||
    '      end if;' || chr(10) ||
    '      if rfx ? ''grip'' and ((k in (''cover'', ''cleanse_heal'') and tgt::text = rfx -> ''grip'' ->> ''tgt'') or (k = ''taunt'' and c.job_key in (''artificer'', ''bloodknight''))) then' || chr(10) ||
    '        select coalesce((x.fx -> ''grip'' ->> ''left'')::int, 0) into gx from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = (rfx -> ''grip'' ->> ''tgt'')::uuid;' || chr(10) ||
    '        perform public.world_raid_credit(p_raid, uid, coalesce(gx, 0) * (mk -> ''grip'' ->> ''dmg'')::numeric, ''guard'');' || chr(10) ||
    '        if (rfx -> ''grip'' ->> ''tgt'')::uuid = uid then f := f - ''grip''; else update public.world_raid_members set fx = fx - ''grip'' where raid_id = p_raid and owner_id = (rfx -> ''grip'' ->> ''tgt'')::uuid; end if;' || chr(10) ||
    '        perform public.world_raid_say(p_raid, ''good'', mb.name || '' — 그림자 손아귀를 떼어 냈습니다.'');' || chr(10) ||
    '        rfx := rfx - ''grip'';' || chr(10) ||
    '      end if;' || chr(10) ||
    '    end if;' || chr(10) || o);

  o := '        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul, ''single'');';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 반격 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * case when rd.kind = ''world'' then (public.world_shadow_rules() -> ''mk2'' ->> ''counter_mul'')::numeric else 1 end, ''single'');');

  o := '     order by public.world_cb_pick_key((x.stats ->> ''pres'')::numeric * case when rd.kind = ''world'' and public.world_shadow_rules() -> ''tank_pres'' -> ''jobs'' ? x.job_key then (public.world_shadow_rules() -> ''tank_pres'' ->> ''mul'')::numeric else 1 end + coalesce((x.fx -> ''taunt'' ->> ''pres'')::numeric, 0)) limit 1;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 표적 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '     order by public.world_cb_pick_key(public.world_shadow_pres(rd.kind, x.job_key, x.stats, x.fx)) limit 1;');

  o := '      perform public.world_raid_hit(p_raid, m.owner_id, raw, ''slam'');' || chr(10) || '    end loop;';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 광역 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '      perform public.world_raid_hit(p_raid, m.owner_id, raw, ''slam'');' || chr(10) ||
    '      if rd.kind = ''world'' then update public.world_raid_members set fx = fx || jsonb_build_object(''ink'', jsonb_build_object(''n'', (public.world_shadow_rules() -> ''mk2'' -> ''ink'' ->> ''beats'')::int, ''b'', bt)) where raid_id = p_raid and owner_id = m.owner_id and out_until is null; end if;' || chr(10) ||
    '    end loop;');

  o := '  if rd.kind = ''final'' and not exists (select 1 from public.world_raid_members x where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, rd.region_id)) then';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 결전 끝 자리 모양이 예상과 다릅니다'; end if;
  n :=
    '  if rd.kind = ''world'' then' || chr(10) ||
    '    mk := public.world_shadow_rules() -> ''mk2'';' || chr(10) ||
    '    if rfx ? ''brand'' and bnow >= (rfx -> ''brand'' ->> ''at'')::numeric then' || chr(10) ||
    '      select x.owner_id, x.level, x.name into pick, lv, nm from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id' || chr(10) ||
    '       where x.raid_id = p_raid and x.out_until is null and x.left_at is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval ''120 seconds'' and ch.health > 1' || chr(10) ||
    '       order by public.world_shadow_pres(rd.kind, x.job_key, x.stats, x.fx) desc, random() limit 1;' || chr(10) ||
    '      update public.world_raid_members set fx = fx - ''brand'' where raid_id = p_raid and fx ? ''brand'';' || chr(10) ||
    '      if pick is not null then' || chr(10) ||
    '        gx := case when pick::text = rfx ->> ''brand_last'' then least((mk -> ''brand'' ->> ''cap'')::int, coalesce((rfx ->> ''brand_streak'')::int, 0) + 1) else 0 end;' || chr(10) ||
    '        perform public.world_raid_say(p_raid, ''boss'', ''검은 낙인이 '' || nm || ''에게 내리꽂힙니다'' || case when gx > 0 then ''(잇달아 받아 더 아픕니다)'' else '''' end || ''!'');' || chr(10) ||
    '        perform public.world_raid_hit(p_raid, pick, public.world_raid_boss_base(p_raid, rd.kind, lv) * ph_mul * (mk -> ''brand'' ->> ''mul'')::numeric * (1 + (mk -> ''brand'' ->> ''streak'')::numeric * gx), ''buster'');' || chr(10) ||
    '        rfx := rfx || jsonb_build_object(''brand_last'', pick, ''brand_streak'', gx);' || chr(10) ||
    '      end if;' || chr(10) ||
    '      rfx := rfx - ''brand'';' || chr(10) ||
    '    elsif tick and not (rfx ? ''brand'') and bt % (mk -> ''brand'' ->> ''every'')::int = (mk -> ''brand'' ->> ''off'')::int then' || chr(10) ||
    '      select x.owner_id, x.name into pick, nm from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id' || chr(10) ||
    '       where x.raid_id = p_raid and x.out_until is null and x.left_at is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval ''120 seconds'' and ch.health > 1' || chr(10) ||
    '       order by public.world_shadow_pres(rd.kind, x.job_key, x.stats, x.fx) desc, random() limit 1;' || chr(10) ||
    '      if pick is not null then' || chr(10) ||
    '        rfx := rfx || jsonb_build_object(''brand'', jsonb_build_object(''at'', round(bnow + (mk -> ''brand'' ->> ''delay'')::numeric, 2), ''tgt'', pick));' || chr(10) ||
    '        update public.world_raid_members set fx = fx || ''{"brand": true}''::jsonb where raid_id = p_raid and owner_id = pick;' || chr(10) ||
    '        perform public.world_raid_say(p_raid, ''boss'', ''검은 낙인이 '' || nm || ''에게 새겨집니다. '' || (mk -> ''brand'' ->> ''delay'') || ''초 뒤 그때 이목이 가장 높은 이에게 내리꽂힙니다. 방어하세요!'');' || chr(10) ||
    '      end if;' || chr(10) ||
    '    end if;' || chr(10) ||
    '    if tick then' || chr(10) ||
    '      for m in select x.owner_id from public.world_raid_members x where x.raid_id = p_raid and x.fx ? ''ink'' and x.out_until is null and coalesce((x.fx -> ''ink'' ->> ''b'')::int, -1) < bt loop' || chr(10) ||
    '        perform public.world_raid_hit(p_raid, m.owner_id, (mk -> ''ink'' ->> ''dmg'')::numeric, ''ink'');' || chr(10) ||
    '        update public.world_raid_members set fx = case when coalesce((fx -> ''ink'' ->> ''n'')::int, 1) <= 1 then fx - ''ink'' else jsonb_set(fx, ''{ink,n}'', to_jsonb((fx -> ''ink'' ->> ''n'')::int - 1)) end' || chr(10) ||
    '         where raid_id = p_raid and owner_id = m.owner_id and fx ? ''ink'';' || chr(10) ||
    '      end loop;' || chr(10) ||
    '      if rfx ? ''grip'' then' || chr(10) ||
    '        select x.owner_id, coalesce((x.fx -> ''grip'' ->> ''left'')::int, 0) into pick, gx from public.world_raid_members x where x.raid_id = p_raid and x.owner_id = (rfx -> ''grip'' ->> ''tgt'')::uuid and x.fx ? ''grip'' and x.out_until is null;' || chr(10) ||
    '        if pick is null or gx <= 0 then' || chr(10) ||
    '          update public.world_raid_members set fx = fx - ''grip'' where raid_id = p_raid and fx ? ''grip'';' || chr(10) ||
    '          rfx := rfx - ''grip'';' || chr(10) ||
    '        else' || chr(10) ||
    '          perform public.world_raid_hit(p_raid, pick, (mk -> ''grip'' ->> ''dmg'')::numeric, ''grip'');' || chr(10) ||
    '          update public.world_raid_members set fx = case when gx <= 1 or out_until is not null then fx - ''grip'' else jsonb_set(fx, ''{grip,left}'', to_jsonb(gx - 1)) end where raid_id = p_raid and owner_id = pick;' || chr(10) ||
    '          if gx <= 1 then rfx := rfx - ''grip''; end if;' || chr(10) ||
    '        end if;' || chr(10) ||
    '      elsif bt % (mk -> ''grip'' ->> ''every'')::int = (mk -> ''grip'' ->> ''off'')::int then' || chr(10) ||
    '        select z.owner_id, z.name into pick, nm from (select x.owner_id, x.name from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id' || chr(10) ||
    '           where x.raid_id = p_raid and x.out_until is null and x.left_at is null and public.world_raid_here(x.owner_id, rd.region_id) and x.last_action_at > now() - interval ''120 seconds'' and ch.health > 1' || chr(10) ||
    '           order by public.world_shadow_pres(rd.kind, x.job_key, x.stats, x.fx) asc, random() limit (mk -> ''grip'' ->> ''pick'')::int) z order by random() limit 1;' || chr(10) ||
    '        if pick is not null then' || chr(10) ||
    '          rfx := rfx || jsonb_build_object(''grip'', jsonb_build_object(''tgt'', pick));' || chr(10) ||
    '          update public.world_raid_members set fx = fx || jsonb_build_object(''grip'', jsonb_build_object(''left'', (mk -> ''grip'' ->> ''beats'')::int)) where raid_id = p_raid and owner_id = pick;' || chr(10) ||
    '          perform public.world_raid_say(p_raid, ''boss'', ''그림자 손아귀가 '' || nm || ''을(를) 움켜쥡니다(2초마다 체력 −'' || (mk -> ''grip'' ->> ''dmg'') || ''·공격 절반). 대신 막기·철벽 수호·꺾이지 않는 몸이나 해독 침으로 떼어 내세요!'');' || chr(10) ||
    '        end if;' || chr(10) ||
    '      end if;' || chr(10) ||
    '    end if;' || chr(10) ||
    '  end if;' || chr(10) || o;
  src := replace(src, o, n);

  o := '        when (bt + 1) % 7 = 0 then';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_action 낌새 자리 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '        when rfx ? ''brand'' then ''검은 낙인 — '' || greatest(0, ceil((rfx -> ''brand'' ->> ''at'')::numeric - extract(epoch from now())))::int || ''초 뒤 이목이 가장 높은 이에게 내리꽂힌다'' ' || chr(10) || o);
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';

  fn := 'public.world_raid_snapshot_core'::regproc::regprocedure;
  select prosrc into src from pg_proc where oid = fn;
  o := '''boss_fx'', (select coalesce(jsonb_agg(k), ''[]''::jsonb) from jsonb_object_keys(rd.fx) k where k <> ''charge'')),';
  if (length(src) - length(replace(src, o, ''))) / length(o) <> 1 then raise exception 'world_raid_snapshot_core 모양이 예상과 다릅니다'; end if;
  src := replace(src, o, '''boss_fx'', (select coalesce(jsonb_agg(k), ''[]''::jsonb) from jsonb_object_keys(rd.fx) k where k <> ''charge''),' || chr(10) ||
    '      ''brand'', case when rd.kind = ''world'' and rd.fx ? ''brand'' then jsonb_build_object(''tgt'', rd.fx -> ''brand'' ->> ''tgt'', ''secs'', greatest(0, round((rd.fx -> ''brand'' ->> ''at'')::numeric - extract(epoch from now())::numeric, 1))) end,' || chr(10) ||
    '      ''grip'', case when rd.kind = ''world'' and rd.fx ? ''grip'' then rd.fx -> ''grip'' ->> ''tgt'' end),');
  def := regexp_replace(pg_get_functiondef(fn), 'AS \$function\$.*\$function\$', '', 's');
  execute def || ' AS $fn$' || src || '$fn$';
end $m$;

do $m$
declare r record; src text; def text;
begin
  for r in select p.oid::regprocedure fn from pg_proc p where p.pronamespace = 'public'::regnamespace and p.prosrc like '%봉연의 그림자%'
             and p.proname in ('world_raid_tick', 'world_raid_schedule_next', 'world_housing_raid_trg', 'world_mentor_rules', 'world_outfit_rules', 'world_quest_task_label') loop
    select prosrc into src from pg_proc where oid = r.fn;
    src := replace(src, '봉연의 그림자', '사슬 벗은 그림자');
    def := regexp_replace(pg_get_functiondef(r.fn), 'AS \$function\$.*\$function\$', '', 's');
    execute def || ' AS $fn$' || src || '$fn$';
  end loop;
end $m$;

update public.world_raids set boss_name = '사슬 벗은 그림자' where kind = 'world' and status in ('announced', 'signup', 'fight') and boss_name = '봉연의 그림자';
update public.world_title_catalog set description = replace(description, '봉연의 그림자', '사슬 벗은 그림자'), condition_text = replace(condition_text, '봉연의 그림자', '사슬 벗은 그림자')
 where description like '%봉연의 그림자%' or condition_text like '%봉연의 그림자%';
update public.world_coop_skills set description = replace(description, '봉연의 그림자', '사슬 벗은 그림자') where description like '%봉연의 그림자%';
update public.world_item_catalog set description = replace(description, '봉연의 그림자', '사슬 벗은 그림자') where description like '%봉연의 그림자%';
update public.world_title_lore set lines = replace(lines::text, '봉연의 그림자', '사슬 벗은 그림자')::jsonb where lines::text like '%봉연의 그림자%';

update public.world_patch_notes set body = body || E'\n\n## 사슬 벗은 그림자\n- 봉연의 그림자가 봉연의 사슬을 끊고 「사슬 벗은 그림자」가 되었습니다. 나타나는 때·곳·보상은 그대로입니다.\n- 검은 낙인: 그림자가 이목이 가장 높은 이에게 낙인을 새기고, 몇 초 뒤 그때 이목이 가장 높은 이에게 큰 한 방을 내리꽂습니다. 방어 태세와 방패 직업의 기술로 크게 줄일 수 있고, 같은 사람이 잇달아 받으면 더 아픕니다.\n- 그림자 손아귀: 이목이 낮은 이 하나를 움켜쥐어 체력을 조금씩 깎고 공격을 약하게 합니다. 방패 직업의 대신 막기·철벽 수호·꺾이지 않는 몸이나 의무관의 해독 침으로 떼어 낼 수 있습니다.\n- 번지는 묵흔: 모두를 덮치는 공격을 맞으면 묵흔이 남아 잠시 체력이 깎입니다. 회복을 받으면 바로 지워집니다.\n- 한 사람을 노리는 반격이 더 아파졌습니다.'
 where note_id = '3.7.0' and body not like '%## 사슬 벗은 그림자%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126070000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;


-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
