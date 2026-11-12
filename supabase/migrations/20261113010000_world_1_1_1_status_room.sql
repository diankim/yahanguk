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

create or replace function public.world_status_rules()
 returns jsonb language sql immutable set search_path to 'pg_catalog'
as $function$
  select '{"cap": 10, "outside": ["yohwa", "yohwa_seal", "yohwa_frenzy"]}'::jsonb
$function$;

create or replace function public.world_status_room(p_owner uuid, p_key text)
 returns boolean language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select coalesce((select s.polarity = 'negative' from public.world_status_catalog s where s.status_key = p_key), false)
      or (select count(*) from public.world_character_statuses x
           where x.owner_id = p_owner and x.expires_at > now()
             and not (public.world_status_rules() -> 'outside') ? x.status_key) < (public.world_status_rules() ->> 'cap')::int
$function$;

revoke all on function public.world_status_rules() from public, anon, authenticated;
revoke all on function public.world_status_room(uuid, text) from public, anon, authenticated;
grant execute on function public.world_status_rules() to fn_owner_field, fn_owner_20175, service_role;
grant execute on function public.world_status_room(uuid, text) to fn_owner_field, fn_owner_20175, service_role;

select pg_temp.yh_fix('world_status_roll', array[
$q$ elsif current_count<status_cap then$q$,
$q$ elsif public.world_status_room(uid, pick) then$q$]);

select pg_temp.yh_fix('world_field_status', array[
$q$  SELECT count(*) INTO cnt FROM public.world_character_statuses WHERE owner_id = p_owner;
  IF cnt >= 10 THEN RETURN false; END IF;$q$,
$q$  IF NOT public.world_status_room(p_owner, p_key) THEN RETURN false; END IF;$q$]);

select pg_temp.yh_fix('world_use_item', array[
$q$buffs text[] := '{}';$q$,
$q$buffs text[] := '{}'; v_full text[] := '{}';$q$,
$q$    RAISE EXCEPTION '지금은 쓸 필요가 없습니다.'; END IF;$q$,
$q$    RAISE EXCEPTION '지금은 쓸 필요가 없습니다.'; END IF;
  IF cardinality(buffs) > 0 AND stam = 0 AND cleared = 0 AND (hp = 0 OR c.health >= 100) AND (mn = 0 OR c.mental >= 100) AND (er = 0 OR c.erosion <= 0) AND (spg = 0 OR c.spiritual_power >= 100)
     AND NOT EXISTS (SELECT 1 FROM unnest(buffs) b WHERE public.world_status_room(uid, b)
                      OR EXISTS (SELECT 1 FROM public.world_character_statuses x WHERE x.owner_id = uid AND x.status_key = b AND x.expires_at > now())) THEN
    RAISE EXCEPTION '상태 칸이 가득 차 새 기운을 받을 수 없습니다.'; END IF;$q$,
$q$    ELSE
      INSERT INTO public.world_character_statuses(owner_id, status_key, source_activity, expires_at, metadata)
      VALUES (uid, buff, 'meal',$q$,
$q$    ELSIF NOT public.world_status_room(uid, buff) THEN
      v_full := v_full || buff;
    ELSE
      INSERT INTO public.world_character_statuses(owner_id, status_key, source_activity, expires_at, metadata)
      VALUES (uid, buff, 'meal',$q$,
$q$CASE WHEN cardinality(buffs) > 0 THEN ' · ' ||$q$,
$q$CASE WHEN cardinality(buffs) > cardinality(v_full) THEN ' · ' ||$q$,
$q$WHERE status_key = ANY (buffs)) ELSE '' END;$q$,
$q$WHERE status_key = ANY (buffs) AND status_key <> ALL (v_full)) ELSE '' END
    || CASE WHEN cardinality(v_full) > 0 THEN ' · 상태 칸이 가득 차 ' || (SELECT string_agg(status_name, '·') FROM public.world_status_catalog WHERE status_key = ANY (v_full)) || '은(는) 받지 못했습니다' ELSE '' END;$q$]);

update public.world_patch_notes set body = body || E'\n- 상태 칸(10칸)이 차 있어도 나쁜 상태는 붙습니다. 이로운 상태로 칸을 채워 나쁜 상태를 막을 수 없게 했습니다.\n- 음식·비약 기운도 상태 칸 10칸 안에서만 새로 붙습니다. 칸이 차 있으면 이미 받은 기운의 시간만 늘어나고, 새 기운은 받지 못합니다.'
where note_id = '1.1.0' and position('나쁜 상태는 붙습니다' in body) = 0;

update public.world_app_meta set value = '20261113010000' where key = 'db_version';
