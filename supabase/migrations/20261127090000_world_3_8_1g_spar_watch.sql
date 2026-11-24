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
