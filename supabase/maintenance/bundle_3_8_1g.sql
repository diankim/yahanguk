-- 배포 앞(운영 전용): 운영의 postgres는 슈퍼유저가 아니라 inherit 없는 함수 주인 역할(fn_owner_*)의 함수를 create or replace 할 수 없다.
-- 이 트랜잭션 동안만 inherit을 켜고, owner_inherit_end.sql이 같은 목록을 원래대로(inherit false) 되돌린다.
create temp table yh_inh on commit drop as
select distinct r.rolname::text as r from pg_proc p join pg_roles r on r.oid = p.proowner
 where p.pronamespace = 'public'::regnamespace and r.rolname like 'fn\_owner%' and not pg_has_role('postgres', r.oid, 'USAGE');
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit true', x); end loop; end $i$;

lock table public.world_app_meta, public.world_patch_notes, public.world_pets, public.world_spars in access exclusive mode;
grant create on schema public to fn_owner_field;
create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

select pg_temp.yh_fix('world_trade_direct_offer(uuid,jsonb,bigint,jsonb,bigint)', array[
$q$  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;$q$,
$q$  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if b.downed_at is not null or b.health <= 0 then raise exception '상대가 쓰러져 있어 거래를 제안할 수 없습니다.'; end if;$q$]);

select pg_temp.yh_fix('world_trade_direct_respond(uuid,boolean)', array[
$q$  if b.downed_at is not null or b.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;$q$,
$q$  if b.downed_at is not null or b.health <= 0 then raise exception '현재 상태에서는 거래할 수 없습니다.'; end if;
  if coalesce(a.is_dead, false) or a.downed_at is not null or a.health <= 0 then raise exception '제안한 조사원이 쓰러져 있어 거래할 수 없습니다.'; end if;$q$]);

update public.world_patch_notes set body = body || E'\n- [거래] 쓰러진 조사원에게는 직접 거래를 제안할 수 없고, 제안한 사람이 그 뒤 쓰러지면 수락해도 거래가 되지 않습니다.'
where note_id = '3.8.0' and position('쓰러진 조사원에게는 직접 거래를' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127080000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

create or replace function public.world_spar_watch_rules() returns jsonb language sql immutable set search_path = pg_catalog as $$
  select '{"keep_min": 10, "step_ms": 550, "active_min": 15}'::jsonb
$$;
alter function public.world_spar_watch_rules() owner to fn_owner_field;
revoke all on function public.world_spar_watch_rules() from public, anon, authenticated;
grant execute on function public.world_spar_watch_rules() to authenticated, service_role;

create or replace function public.world_spar_watch_ok(p_uid uuid, p_spar uuid) returns boolean language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return exists (select 1 from public.world_spars s join public.world_characters c on c.owner_id = p_uid
    where s.spar_id = p_spar and s.status = 'done'
      and (p_uid in (s.challenger_id, s.target_id)
        or (c.location = s.place and s.finished_at > now() - make_interval(mins => (public.world_spar_watch_rules() ->> 'keep_min')::int))));
end $$;
alter function public.world_spar_watch_ok(uuid, uuid) owner to fn_owner_field;
revoke all on function public.world_spar_watch_ok(uuid, uuid) from public, anon, authenticated;

create or replace function public.world_spar_watch_row(s public.world_spars) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare n int := coalesce(jsonb_array_length(s.result -> 'log'), 0); ends timestamptz;
begin
  ends := s.finished_at + make_interval(secs => n * (public.world_spar_watch_rules() ->> 'step_ms')::numeric / 1000);
  return jsonb_build_object('id', s.spar_id, 'names', s.result -> 'names', 'place', s.place, 'finished_at', s.finished_at, 'ends_at', ends,
    'live', now() < ends, 'winner', case when now() >= ends then s.result -> 'names' -> (coalesce((s.result ->> 'winner')::int, 1) - 1) end);
end $$;
alter function public.world_spar_watch_row(public.world_spars) owner to fn_owner_field;
revoke all on function public.world_spar_watch_row(public.world_spars) from public, anon, authenticated;

create or replace function public.world_spar_watch_list() returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); loc text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select c.location into loc from public.world_characters c where c.owner_id = uid;
  return jsonb_build_object('place', loc, 'list', coalesce((select jsonb_agg(public.world_spar_watch_row(s) order by s.finished_at desc)
    from public.world_spars s where s.status = 'done' and s.place = loc
      and s.finished_at > now() - make_interval(mins => (public.world_spar_watch_rules() ->> 'keep_min')::int)), '[]'::jsonb));
end $$;
alter function public.world_spar_watch_list() owner to fn_owner_field;
revoke all on function public.world_spar_watch_list() from public, anon, authenticated;
grant execute on function public.world_spar_watch_list() to authenticated, service_role;

select pg_temp.yh_fix('world_spar_view(uuid)', array[
$q$jsonb_build_object('ok', true, 'status', s.status, 'result', s.result, 'place', s.place, 'finished_at', s.finished_at)$q$,
$q$jsonb_build_object('ok', true, 'status', s.status, 'result', s.result, 'place', s.place, 'finished_at', s.finished_at, 'watch', public.fn_owner_auth_uid() not in (s.challenger_id, s.target_id), 'now', now())$q$,
$q$public.fn_owner_auth_uid() in (s.challenger_id, s.target_id)$q$,
$q$(public.fn_owner_auth_uid() in (s.challenger_id, s.target_id) or public.world_spar_watch_ok(public.fn_owner_auth_uid(), s.spar_id))$q$]);

select pg_temp.yh_fix('world_notify_group(text)', array[
$q$    when p_kind in ('spar_request', 'spar_result',$q$,
$q$    when p_kind in ('spar_watch') then 'spar_watch'
    when p_kind in ('spar_request', 'spar_result',$q$]);

select pg_temp.yh_fix('world_notify_prefs_set(text[])', array[
$q$'housing', 'meisho')$q$,
$q$'housing', 'meisho', 'project', 'spar_watch')$q$]);

create or replace function public.world_spar_watch_note() returns trigger language plpgsql security definer set search_path = pg_catalog, public as $$
declare nm jsonb := new.result -> 'names';
begin
  if new.status <> 'done' or old.status = 'done' or new.place is null or nm is null then return null; end if;
  perform realtime.send(jsonb_build_object('spar', public.world_spar_watch_row(new)), 'msg', 'chat:region:' || new.place, true);
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select c.owner_id, 'spar_watch', '비무 관전', public.world_josa(nm ->> 0, '과', '와') || ' ' || (nm ->> 1) || '의 비무가 ' || new.place || '에서 벌어지고 있습니다.',
         jsonb_build_object('spar_id', new.spar_id, 'place', new.place)
    from public.world_characters c
   where c.location = new.place and c.owner_id not in (new.challenger_id, new.target_id) and not coalesce(c.is_dead, false)
     and c.updated_at > now() - make_interval(mins => (public.world_spar_watch_rules() ->> 'active_min')::int)
     and not exists (select 1 from public.world_blocks b where (b.owner_id = c.owner_id and b.blocked_id in (new.challenger_id, new.target_id)));
  return null;
end $$;
alter function public.world_spar_watch_note() owner to postgres;
revoke all on function public.world_spar_watch_note() from public, anon, authenticated;
drop trigger if exists trg_world_spar_watch on public.world_spars;
create trigger trg_world_spar_watch after update of status on public.world_spars for each row execute function public.world_spar_watch_note();

update public.world_patch_notes set body = body || E'\n- [비무] 같은 지역에서 벌어진 비무를 관전할 수 있습니다. 비무가 끝나면 그 자리에 있던 조사원에게 알림이 가고, 현장 띠의 「비무 관전」에서 10분 동안 여러 판을 골라 볼 수 있습니다. 알림은 설정 › 알림 「비무 관전」에서 끌 수 있습니다.\n- [알림] 설정 › 알림에서 「사업」을 꺼도 저장되지 않던 것을 고쳤습니다.'
where note_id = '3.8.0' and position('같은 지역에서 벌어진 비무를 관전' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127090000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

create or replace function pg_temp.yh_fix(p_name text, p_pairs text[]) returns void language plpgsql as $f$
declare d text; i int; n int;
begin
  d := pg_get_functiondef(('public.' || p_name)::regprocedure);
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(d) - length(replace(d, p_pairs[2 * i - 1], ''))) / length(p_pairs[2 * i - 1]);
    if n <> 1 then raise exception '함수 % 모양이 예상과 다릅니다(조각 %: % 곳)', p_name, i, n; end if;
    d := replace(d, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute d;
end $f$;

alter table public.world_pets add column if not exists skin text;

create or replace function public.world_pet_skin_rules() returns jsonb language sql immutable set search_path = pg_catalog as $$
  select '{"skins": {"snow_calico": {"pet": "spotted_cat", "how": "pet"}}}'::jsonb
$$;
alter function public.world_pet_skin_rules() owner to fn_owner_field;
revoke all on function public.world_pet_skin_rules() from public, anon, authenticated;
grant execute on function public.world_pet_skin_rules() to authenticated, service_role;

create or replace function public.world_pet_skins_for(p_uid uuid, p_pet text) returns jsonb language plpgsql stable security definer set search_path = pg_catalog, public as $$
begin
  return coalesce((select jsonb_agg(k.key order by k.key) from jsonb_each(public.world_pet_skin_rules() -> 'skins') k
    where k.value ->> 'pet' = p_pet and k.value ->> 'how' = 'pet'
      and exists (select 1 from public.world_pets p where p.owner_id = p_uid and p.pet_id = p_pet)), '[]'::jsonb);
end $$;
alter function public.world_pet_skins_for(uuid, text) owner to fn_owner_field;
revoke all on function public.world_pet_skins_for(uuid, text) from public, anon, authenticated;

create or replace function public.world_pet_skin(p_pet text, p_skin text) returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare uid uuid := public.fn_owner_auth_uid(); sk text := nullif(btrim(coalesce(p_skin, '')), '');
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform 1 from public.world_pets where owner_id = uid and pet_id = p_pet for update;
  if not found then raise exception '함께하는 동무가 아닙니다.'; end if;
  if sk is not null and not (public.world_pet_skins_for(uid, p_pet) ? sk) then raise exception '이 동무가 입을 수 없는 무늬입니다.'; end if;
  update public.world_pets set skin = sk where owner_id = uid and pet_id = p_pet;
  return jsonb_build_object('ok', true, 'skin', sk, 'content', case when sk is null then '원래 무늬로 돌아갔습니다.' else '무늬를 바꿨습니다.' end);
end $$;
alter function public.world_pet_skin(text, text) owner to fn_owner_field;
revoke all on function public.world_pet_skin(text, text) from public, anon, authenticated;
grant execute on function public.world_pet_skin(text, text) to authenticated, service_role;

select pg_temp.yh_fix('world_pet_profile_of(uuid)', array[
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'affinity', p.affinity)$q$,
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'affinity', p.affinity, 'skin', p.skin)$q$]);

select pg_temp.yh_fix('world_housing_pets_view(uuid,uuid)', array[
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'grown'$q$,
$q$'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'skin', p.skin, 'grown'$q$]);

select pg_temp.yh_fix('world_pet_snapshot()', array[
$q$'baby', p.baby_look, 'got_at', p.got_at$q$,
$q$'baby', p.baby_look, 'skin', p.skin, 'skins', public.world_pet_skins_for(uid, p.pet_id), 'got_at', p.got_at$q$]);

select pg_temp.yh_fix('world_scene_folks(jsonb)', array[
$q$jsonb_build_object('id', f.pet_id, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look))$q$,
$q$jsonb_build_object('id', f.pet_id, 'adult', public.world_pet_look_adult(p.affinity, p.baby_look), 'skin', p.skin)$q$]);

update public.world_patch_notes set body = body || E'\n- [동무] 꼬마 동무 도감에서 「무늬」로 동무의 무늬를 바꿀 수 있습니다. 얼룩 고양이에게 「눈송이 삼색」 무늬가 생겼습니다.'
where note_id = '3.8.0' and position('「눈송이 삼색」' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;

revoke create on schema public from fn_owner_field;
-- 배포 끝: 앞에서 켠 inherit을 원래대로
do $i$ declare x text; begin for x in select r from yh_inh loop execute format('grant %I to postgres with inherit false', x); end loop; end $i$;
drop table yh_inh;
