lock table public.world_characters in access exclusive mode;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  if position('(' in p_name) > 0 then d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  else select pg_get_functiondef(p.oid) into strict d from pg_proc p where p.pronamespace = 'public'::regnamespace and p.proname = p_name; end if;
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


select pg_temp.yh_fix('world_shop_sell', array[
  E'if not coalesce(p_overflow, false) or room <= 0 then',
  E'if not coalesce(p_overflow, false) then',
  E'case when dropped > 0 then ''한도에 맞춰 ''',
  E'case when dropped > 0 and paid <= 0 then ''오늘 판매 한도가 차서 값을 받지 못했습니다('' || dropped || ''개는 버려짐)'' when dropped > 0 then ''한도에 맞춰 '''
]);

update public.world_patch_notes set body = body || $N$
- 상점 판매 한도가 다 찬 뒤에도 확인 창을 거쳐 팔 수 있습니다. 값은 받지 못하고 물품만 버려지지만, 「팔기」 할 일(수향연맹 가입 퀘스트 등)은 셉니다.
- 창고 창 「맡기기」 줄에도 창고에 이미 든 같은 물품 수가, 칸대로 나눠 본 「꺼내기」 줄에는 창고에 든 모두의 수가 보입니다.
- 낚시·제작·토벌 같은 행동 뒤 칭호 판정을 줄여 응답이 빨라졌습니다.$N$
 where note_id = '3.0.0' and position('판매 한도가 다 찬 뒤에도' in body) = 0;


create or replace function public.world_title_ev_hit(r jsonb, ev text, pl jsonb) returns boolean
language sql immutable set search_path = '' as $$
  select case
    when r ? 'all' then exists (select 1 from jsonb_array_elements(r -> 'all') s where public.world_title_ev_hit(s, ev, pl))
    when not (r ? 'ev') then true
    when r ->> 'ev' <> ev then false
    else (not r ? 'p' or pl @> (r -> 'p'))
     and (not r ? 'has' or pl ? (r ->> 'has'))
     and (not r ? 'phase' or coalesce(pl ->> 'env_phase', r ->> 'phase') = r ->> 'phase')
  end
$$;
revoke all on function public.world_title_ev_hit(jsonb, text, jsonb) from public, anon, authenticated;
alter function public.world_title_ev_hit(jsonb, text, jsonb) owner to fn_owner_field;

select pg_temp.yh_fix('world_title_award_check(uuid,text)', array[
  E'DECLARE t record; got int := 0; last_outcome text; r jsonb;',
  E'DECLARE t record; got int := 0; last_outcome text; r jsonb; ev_pl jsonb := nullif(current_setting(''yh.title_ev'', true), '''')::jsonb;',
  E'    IF r ? ''codex'' AND',
  E'    IF ev_pl IS NOT NULL AND NOT public.world_title_ev_hit(r, p_event_type, ev_pl) THEN CONTINUE; END IF;\n    IF r ? ''codex'' AND'
]);

select pg_temp.yh_fix('world_apply_activity_status()', array[
  E' perform public.world_title_award_check(new.actor_id,new.event_type);',
  E' perform set_config(''yh.title_ev'', coalesce(new.payload, ''{}''::jsonb)::text, true);\n perform public.world_title_award_check(new.actor_id,new.event_type);\n perform set_config(''yh.title_ev'', '''', true);'
]);

select pg_temp.yh_fix('world_fish()', array[
  E'  perform public.world_title_award_check(uid, ''fish'');\n  return jsonb_build_object(''ok'', true, ''caught'', true,',
  E'  return jsonb_build_object(''ok'', true, ''caught'', true,'
]);

select pg_temp.yh_fix('world_cosmetic_award_check(uuid,text)', array[
  E'declare t record; got int := 0; r jsonb; kname text;',
  E'declare t record; got int := 0; r jsonb; kname text; ev_pl jsonb := nullif(current_setting(''yh.title_ev'', true), '''')::jsonb;',
  E'      if r ? ''mounts'' and p_event_type not in',
  E'      if r ? ''tourney'' and p_event_type <> ''tourney'' then continue; end if;\n      if r ? ''home'' and p_event_type <> ''home'' then continue; end if;\n      if ev_pl is not null and not public.world_title_ev_hit(r, p_event_type, ev_pl) then continue; end if;\n      if r ? ''mounts'' and p_event_type not in'
]);


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261120010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
