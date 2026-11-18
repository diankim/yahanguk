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


grant execute on function public.world_busy_kind(uuid) to fn_owner_party_invite_v2;
grant execute on function public.world_busy_msg(uuid, text, boolean) to fn_owner_party_invite_v2;
grant update (status, cancelled_at) on public.world_travel_party_requests to fn_owner_party_invite_v2;

select pg_temp.yh_fix('world_travel_party_invite_v2', array[
  E'  IF c.location <> p.location THEN',
  E'  IF public.world_busy_kind(p_passenger_id) IS NOT NULL THEN\n    RAISE EXCEPTION ''%'', public.world_busy_msg(p_passenger_id, ''동승'', true);\n  END IF;\n  IF public.world_busy_kind(uid) IS NOT NULL THEN\n    RAISE EXCEPTION ''%'', public.world_busy_msg(uid, ''동승 요청'', false);\n  END IF;\n  IF c.location <> p.location THEN',
  E'  IF EXISTS (\n    SELECT 1 FROM public.world_travel_party_requests q\n    WHERE q.leader_id = uid AND q.passenger_id = p_passenger_id\n      AND q.status = ''pending''\n  ) THEN\n    RAISE EXCEPTION ''이미 처리 대기 중인 동승 요청이 있습니다.'';\n  END IF;',
  E'  UPDATE public.world_travel_party_requests q SET status = ''cancelled'', cancelled_at = now()\n   WHERE q.leader_id = uid AND q.passenger_id = p_passenger_id AND q.status = ''pending'';'
]);


update public.world_patch_notes set body = body || $N$
- 동승을 받는 쪽이 원정·자율 활동 중이라 수락이 안 되면 요청이 「대기 중」으로 남아 다시 보낼 수 없던 것을 고쳤습니다. 이제 원정·자율 활동 중인 동료에게는 처음부터 요청이 가지 않고, 같은 동료에게 다시 보내면 앞의 요청은 거두어집니다. 지난 알림에 남은 동승 요청도 「함께 타기」·「사양」으로 답할 수 있습니다.$N$
 where note_id = '3.0.0' and position('수락이 안 되면 요청이 「대기 중」' in body) = 0;


insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261121020000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
