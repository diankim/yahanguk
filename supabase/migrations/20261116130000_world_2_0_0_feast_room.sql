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

create or replace function public.world_feast_room(p_owner uuid, p_key text)
 returns boolean language sql stable set search_path to 'pg_catalog', 'public'
as $function$
  select exists (select 1 from public.world_character_statuses s where s.owner_id = p_owner and s.status_key = p_key and s.expires_at > now())
      or public.world_status_room(p_owner, p_key)
$function$;
revoke all on function public.world_feast_room(uuid, text) from public, anon, authenticated;
grant execute on function public.world_feast_room(uuid, text) to fn_owner_field, service_role;

select pg_temp.yh_fix('world_feast_tick', array[
$q$n int := 0; nm text;$q$,
$q$n int := 0; nm text; fk text; cap text := public.world_status_rules() ->> 'cap';$q$,
$q$'」 기운을 ' || (ru ->> 'buff_h') || '시간 동안 받습니다.', jsonb_build_object('feast', f.feast_id)$q$,
$q$'」 기운을 ' || (ru ->> 'buff_h') || '시간 동안 받습니다. 끝날 때 상태 칸 ' || cap || '칸이 모두 차 있으면 받지 못하니 미리 비워 두세요(이로운 상태는 상태 창에서 끌 수 있습니다).', jsonb_build_object('feast', f.feast_id)$q$,
$q$'이(가) 열립니다. 세력과 상관없이 누구나 함께할 수 있습니다.');$q$,
$q$'이(가) 열립니다. 세력과 상관없이 누구나 함께할 수 있습니다. 끝날 때 상태 칸 ' || cap || '칸이 모두 차 있으면 기운을 받지 못합니다.');$q$,
$q$    if now() >= f.ends_at then
      for m in$q$,
$q$    if now() >= f.ends_at then
      fk := (select e ->> 'key' from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key);
      for m in$q$,
$q$        delete from public.world_character_statuses where owner_id = m.owner_id and status_key = (select e ->> 'key' from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key);$q$,
$q$        if not public.world_feast_room(m.owner_id, fk) then
          insert into public.world_notifications(user_id, kind, title, content, payload)
          select m.owner_id, 'feast', e ->> 'name' || '이(가) 끝났습니다', '상태 칸 ' || cap || '칸이 모두 차 있어 「' || (e ->> 'buff') || '」 기운을 받지 못했습니다.', jsonb_build_object('feast', f.feast_id)
            from jsonb_array_elements(ru -> 'feasts') e where e ->> 'faction' = f.faction_key;
          continue;
        end if;
        delete from public.world_character_statuses where owner_id = m.owner_id and status_key = fk;$q$]);

select pg_temp.yh_fix('world_feast_view', array[
$q$'rules', public.world_feast_rules() - 'feasts', 'pet', pet,$q$,
$q$'rules', public.world_feast_rules() - 'feasts', 'pet', pet, 'full', not public.world_feast_room(uid, t ->> 'key'), 'cap', (public.world_status_rules() ->> 'cap')::int,$q$]);

update public.world_patch_notes set body = replace(body,
  E'- 30분 전에 그 세력 조사원에게 알림이 가고,',
  E'- 상태 칸 10칸이 모두 차 있으면 행사 기운을 받지 못합니다(이미 받은 같은 기운은 새로 이어집니다). 행사 창과 미리 가는 알림에서 알려 주니, 이로운 상태를 상태 창에서 꺼 칸을 비워 두세요.\n- 30분 전에 그 세력 조사원에게 알림이 가고,')
where note_id = '2.0.0' and position('행사 기운을 받지 못합니다' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261116130000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
