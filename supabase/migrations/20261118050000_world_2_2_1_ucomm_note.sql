alter table public.world_user_commissions add column if not exists note text, add column if not exists note_removed boolean not null default false;

create or replace function public.world_ucomm_rules() returns jsonb language sql immutable set search_path = '' as $r$ select '{"note_max": 60}'::jsonb $r$;
revoke all on function public.world_ucomm_rules() from public, anon;
grant execute on function public.world_ucomm_rules() to authenticated, service_role;

do $p$
declare src text := pg_get_functiondef('public.world_ucomm_post(text,integer,integer)'::regprocedure); n int;
begin
  src := replace(src, 'world_ucomm_post(p_item text, p_qty integer, p_reward integer)', 'world_ucomm_post(p_item text, p_qty integer, p_reward integer, p_note text DEFAULT NULL::text)');
  src := replace(src, 'minr int; new_id bigint;', 'minr int; new_id bigint; note text := nullif(btrim(regexp_replace(coalesce(p_note, ''''), ''[[:space:][:cntrl:]]+'', '' '', ''g'')), ''''); nmax int := (public.world_ucomm_rules() ->> ''note_max'')::int;');
  src := replace(src, '  if p_qty is null or p_qty < 1', '  if char_length(note) > nmax then raise exception ''의뢰 글은 %자까지 적을 수 있습니다.'', nmax; end if;
  if p_qty is null or p_qty < 1');
  src := replace(src, 'region_id, fee_faction)
    values (uid, c.character_name, it.item_id, p_qty, p_reward, r.region_id, coalesce(r.control_faction_id, r.home_faction_id))',
    'region_id, fee_faction, note)
    values (uid, c.character_name, it.item_id, p_qty, p_reward, r.region_id, coalesce(r.control_faction_id, r.home_faction_id), note)');
  if position('p_note text' in src) = 0 or position('nmax int' in src) = 0 or position('%자까지' in src) = 0 or position('fee_faction, note)' in src) = 0 or position('home_faction_id), note)' in src) = 0 then
    raise exception 'ucomm_post 고치기 실패';
  end if;
  drop function public.world_ucomm_post(text, integer, integer);
  execute src;
end $p$;
revoke all on function public.world_ucomm_post(text, integer, integer, text) from public, anon;
grant execute on function public.world_ucomm_post(text, integer, integer, text) to authenticated, service_role;

CREATE OR REPLACE FUNCTION public.world_ucomm_board()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO ''
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; r public.world_map_regions%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; xp_used int;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  update public.world_user_commissions set status = 'expired' where status = 'open' and expires_at <= now();
  r := public.world_field_region(c.location);
  select count(*) into xp_used from public.world_events e where e.actor_id = uid and e.event_type = 'commission' and e.payload ? 'ucomm'
    and e.created_at >= (today::timestamp at time zone 'Asia/Seoul');
  return jsonb_build_object(
    'fee_pct', 10, 'note_max', (public.world_ucomm_rules() ->> 'note_max')::int, 'staff', exists (select 1 from public.world_staff s where s.owner_id = uid), 'xp_left', greatest(0, 3 - xp_used), 'xp', 20 + c.level * 3, 'max_open', 5,
    'here', jsonb_build_object('safe', coalesce(r.is_safe_zone, false) and not public.world_weak_safe(r.region_id), 'region', r.region_name,
      'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = coalesce(r.control_faction_id, r.home_faction_id))),
    'open', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'owner', u.owner_name, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'expires_at', u.expires_at, 'note', u.note,
        'have', coalesce((c.inventory ->> u.item_id)::int, 0) + coalesce((c.inventory ->> (u.item_id || '_hq'))::int, 0)) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.status = 'open' and u.owner_id <> uid
        and not exists (select 1 from public.world_blocks b where (b.owner_id = uid and b.blocked_id = u.owner_id) or (b.owner_id = u.owner_id and b.blocked_id = uid))),
    'mine', (select coalesce(jsonb_agg(jsonb_build_object('id', u.id, 'item', u.item_id, 'qty', u.qty, 'reward', u.reward, 'status', u.status,
        'region', (select region_name from public.world_map_regions where region_id = u.region_id), 'faction', (select mf.faction_name from public.world_major_factions mf where mf.faction_id = u.fee_faction),
        'fulfiller', u.fulfiller_name, 'delivered', u.delivered, 'expires_at', u.expires_at, 'done_at', u.done_at, 'settled', u.settled_at is not null, 'note', u.note, 'note_removed', u.note_removed) order by u.created_at desc), '[]'::jsonb)
      from public.world_user_commissions u
      where u.owner_id = uid and (u.settled_at is null or u.settled_at > now() - interval '3 days')));
end $function$;

create or replace function public.world_ucomm_note_remove(p_id bigint) returns jsonb
language plpgsql security definer set search_path = '' as $f$
declare uid uuid := public.fn_owner_auth_uid(); u public.world_user_commissions%rowtype;
begin
  if uid is null or not exists (select 1 from public.world_staff where owner_id = uid) then raise exception '운영진만 할 수 있습니다.'; end if;
  select * into u from public.world_user_commissions where id = p_id for update;
  if not found then raise exception '의뢰를 찾을 수 없습니다.'; end if;
  if u.note is null then return jsonb_build_object('ok', true, 'content', '이미 글이 없는 의뢰입니다.'); end if;
  update public.world_user_commissions set note = null, note_removed = true where id = p_id;
  insert into public.world_notifications (user_id, kind, title, content, payload)
  values (u.owner_id, 'ucomm_note_removed', '의뢰 글이 내려졌습니다', '운영진이 조사원 의뢰 「' || coalesce((select item_name from public.world_item_catalog where item_id = u.item_id), u.item_id) || ' ×' || u.qty || '」에 남긴 글을 내렸습니다. 의뢰는 그대로 게시판에 남습니다.', jsonb_build_object('ucomm', p_id));
  return jsonb_build_object('ok', true, 'content', '의뢰 글을 내렸습니다.');
end $f$;
revoke all on function public.world_ucomm_note_remove(bigint) from public, anon;
grant execute on function public.world_ucomm_note_remove(bigint) to authenticated, service_role;

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n\n## 2.2.1\n- 조사원 의뢰를 올릴 때 짧은 글(60자까지)을 남길 수 있습니다. 쓰지 않아도 되고, 남긴 글은 게시판의 그 의뢰 아래에 보입니다. 차단한 사이에는 의뢰가 서로 보이지 않고, 알맞지 않은 글은 운영진이 내릴 수 있습니다.\n'
 where note_id = '2.2.0' and body not like '%## 2.2.1%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
