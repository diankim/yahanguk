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

update public.world_patch_notes set body = body || E'\n- 봉연의 그림자·귀허류 싸움의 피해 기록에 「보호막」 칸이 생겨, 동료에게 씌운 보호막이 막아 낸 피해가 따로 보입니다.\n- 싸움 화면 참가자 칸과 피해 기록에 조련사·혈기사·여명 창객·진법가의 직업 색이 붙습니다.'
 where note_id = '3.7.0' and body not like '%「보호막」 칸이 생겨%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261126020000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;


-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
