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


-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
