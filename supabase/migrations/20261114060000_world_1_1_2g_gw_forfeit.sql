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
create or replace function pg_temp.yh_own(p_fn text, p_role text) returns void language plpgsql as $f$
declare g boolean := not has_schema_privilege(p_role, 'public', 'CREATE');
begin
  if g then execute format('grant create on schema public to %I', p_role); end if;
  execute format('alter function %s owner to %I', p_fn, p_role);
  if g then execute format('revoke create on schema public from %I', p_role); end if;
end $f$;

create table if not exists public.world_gw_votes (
  fight_id uuid primary key references public.world_gw_fights(fight_id) on delete cascade,
  proposer uuid not null,
  yes uuid[] not null default '{}',
  expires_at timestamptz not null
);
alter table public.world_gw_votes enable row level security;
revoke all on public.world_gw_votes from public, anon, authenticated;
grant select, insert, update, delete on public.world_gw_votes to fn_owner_field;

create or replace function public.world_gw_vote_view(p_fight uuid, p_uid uuid)
 returns jsonb
 language sql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
  select jsonb_build_object('by', (select m.name from public.world_gw_members m where m.fight_id = v.fight_id and m.owner_id = v.proposer),
    'yes', cardinality(v.yes), 'need', (select count(*) from public.world_gw_members m where m.fight_id = v.fight_id),
    'until', v.expires_at, 'mine', p_uid = any (v.yes))
    from public.world_gw_votes v where v.fight_id = p_fight and v.expires_at > now()
$function$;

select pg_temp.yh_fix('world_gw_snapshot', array[
$q$'my_act', me.act, 'joined', me.owner_id is not null,$q$,
$q$'my_act', me.act, 'joined', me.owner_id is not null, 'vote', public.world_gw_vote_view(fid, uid),$q$]);

create or replace function public.world_gw_forfeit(p_fight uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; n int; nm text;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found then raise exception '없는 싸움입니다.'; end if;
  if f.status not in ('wait', 'fight') then raise exception '이미 끝난 싸움입니다.'; end if;
  select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = uid;
  if nm is null then raise exception '이 싸움에 함께하고 있지 않습니다.'; end if;
  select count(*) into n from public.world_gw_members where fight_id = p_fight;
  if n <= 1 then
    delete from public.world_gw_votes where fight_id = p_fight;
    perform public.world_gw_say(p_fight, f.round, 'phase', nm || ' — 싸움을 포기하고 물러났습니다.');
    perform public.world_gw_settle(p_fight, false);
    return public.world_gw_snapshot(p_fight);
  end if;
  if exists (select 1 from public.world_gw_votes where fight_id = p_fight and expires_at > now()) then
    return public.world_gw_forfeit_vote(p_fight, true);
  end if;
  insert into public.world_gw_votes(fight_id, proposer, yes, expires_at) values (p_fight, uid, array[uid], now() + interval '60 seconds')
  on conflict (fight_id) do update set proposer = excluded.proposer, yes = excluded.yes, expires_at = excluded.expires_at;
  perform public.world_gw_say(p_fight, f.round, 'info', nm || ' — 싸움을 포기하자고 합니다. 60초 안에 모두 동의하면 다 함께 물러납니다.');
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select m.owner_id, 'gw_vote', '포기 제안', nm || ' 조사원이 싸움을 포기하자고 합니다. 싸움 화면에서 60초 안에 답해 주세요.', jsonb_build_object('fight_id', p_fight)
    from public.world_gw_members m where m.fight_id = p_fight and m.owner_id <> uid;
  update public.world_gw_fights set updated_at = now() where fight_id = p_fight;
  return public.world_gw_snapshot(p_fight);
end $function$;

create or replace function public.world_gw_forfeit_vote(p_fight uuid, p_agree boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); f public.world_gw_fights%rowtype; nm text; v public.world_gw_votes%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into f from public.world_gw_fights where fight_id = p_fight for update;
  if not found or f.status not in ('wait', 'fight') then raise exception '이미 끝난 싸움입니다.'; end if;
  select name into nm from public.world_gw_members where fight_id = p_fight and owner_id = uid;
  if nm is null then raise exception '이 싸움에 함께하고 있지 않습니다.'; end if;
  select * into v from public.world_gw_votes where fight_id = p_fight and expires_at > now();
  if not found then raise exception '포기 제안이 없거나 시간이 지났습니다.'; end if;
  if not p_agree then
    delete from public.world_gw_votes where fight_id = p_fight;
    perform public.world_gw_say(p_fight, f.round, 'info', nm || ' — 포기에 반대했습니다. 싸움을 이어 갑니다.');
  else
    if not (uid = any (v.yes)) then v.yes := v.yes || uid; end if;
    if not exists (select 1 from public.world_gw_members m where m.fight_id = p_fight and not (m.owner_id = any (v.yes))) then
      delete from public.world_gw_votes where fight_id = p_fight;
      perform public.world_gw_say(p_fight, f.round, 'phase', '모두 동의해 싸움을 포기하고 다 함께 물러납니다.');
      perform public.world_gw_settle(p_fight, false);
      return public.world_gw_snapshot(p_fight);
    end if;
    update public.world_gw_votes set yes = v.yes where fight_id = p_fight;
    perform public.world_gw_say(p_fight, f.round, 'info', nm || ' — 포기에 동의했습니다.');
  end if;
  update public.world_gw_fights set updated_at = now() where fight_id = p_fight;
  return public.world_gw_snapshot(p_fight);
end $function$;

select pg_temp.yh_fix('world_notify_group', array[
$q$'gw', 'gw_invite')$q$, $q$'gw', 'gw_invite', 'gw_vote')$q$]);

revoke all on function public.world_gw_vote_view(uuid, uuid) from public, anon, authenticated;
grant execute on function public.world_gw_vote_view(uuid, uuid) to fn_owner_field;
select pg_temp.yh_own('public.world_gw_vote_view(uuid, uuid)', 'fn_owner_field');
select pg_temp.yh_own('public.world_gw_forfeit(uuid)', 'fn_owner_field');
select pg_temp.yh_own('public.world_gw_forfeit_vote(uuid, boolean)', 'fn_owner_field');
revoke all on function public.world_gw_forfeit(uuid) from public, anon;
revoke all on function public.world_gw_forfeit_vote(uuid, boolean) from public, anon;
grant execute on function public.world_gw_forfeit(uuid) to authenticated;
grant execute on function public.world_gw_forfeit_vote(uuid, boolean) to authenticated;

do $c$ begin
  if not exists (select 1 from public.world_patch_notes where note_id = '1.1.0') then raise exception '1.1.0 패치노트가 없습니다'; end if;
end $c$;
update public.world_patch_notes set body = body || E'\n- 귀허의 주인: 싸움 화면 머리의 「포기」로 중도에 물러날 수 있습니다. 혼자면 바로 실패로 끝나고, 함께면 60초 안에 모두 동의해야 물러납니다(실패와 똑같이 셈).'
 where note_id = '1.1.0' and position('귀허의 주인: 싸움 화면 머리의 「포기」' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261114060000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
