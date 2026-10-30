-- 7.4.3 10장 결전 「포기하고 나오기」(사용자 요청, 여보가 혼자 연 결전에서 나올 길이 없어 20분을 기다려야 했다).
-- · 혼자면: 시간이 끝났을 때와 같이 바로 실패로 정리(world_raid_settle(false), 보상 없음·다시 도전 가능).
-- · 여럿이면: 포기를 제안하고(60초), 결전의 모든 참가자가 동의하면 다 함께 물러난다(실패 정리). 한 사람이라도 반대하거나 60초가 지나면 그대로 싸운다.
--   제안은 world_raid_votes에 두고, world_raid_snapshot이 'vote'를 덧붙여 결전 화면이 동의 창을 띄운다(실시간: world_raids.updated_at을 건드림).
-- · 결전 체력(max(4716, 평균 공격력×100) × 인원 1·1.7·2.3·2.8)은 그대로 둔다: 혼자는 거의 불가능, 둘은 어렵지만 해볼 만하다(사용자 결정).

create table if not exists public.world_raid_votes (
  raid_id uuid primary key references public.world_raids(raid_id) on delete cascade,
  proposer uuid not null,
  yes uuid[] not null default '{}',
  expires_at timestamptz not null
);
alter table public.world_raid_votes enable row level security;
revoke all on public.world_raid_votes from public, anon, authenticated;

-- 결전 스냅샷에 포기 제안을 덧붙인다: 본래 함수는 world_raid_snapshot_core로 이름만 바꾼다(권한·주인 그대로)
do $do$
begin
  if to_regprocedure('public.world_raid_snapshot_core(uuid)') is null then
    alter function public.world_raid_snapshot(uuid) rename to world_raid_snapshot_core;
  end if;
end $do$;

create or replace function public.world_raid_snapshot(p_raid uuid default null)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare s jsonb; rid uuid; v public.world_raid_votes%rowtype; need int;
begin
  s := public.world_raid_snapshot_core(p_raid);
  rid := nullif(s #>> '{raid,id}', '')::uuid;
  if rid is null or (s #>> '{raid,status}') not in ('signup', 'fight') then return s; end if;
  select * into v from public.world_raid_votes where raid_id = rid and expires_at > now();
  if not found then return s; end if;
  select count(*) into need from public.world_raid_members where raid_id = rid;
  return s || jsonb_build_object('vote', jsonb_build_object(
    'by', (select name from public.world_raid_members where raid_id = rid and owner_id = v.proposer),
    'by_me', v.proposer = auth.uid(), 'mine', auth.uid() = any (v.yes),
    'yes', cardinality(v.yes), 'need', need, 'until', v.expires_at));
end
$function$;
revoke all on function public.world_raid_snapshot(uuid) from public, anon;
grant execute on function public.world_raid_snapshot(uuid) to authenticated;

-- 포기: 혼자면 바로 실패, 여럿이면 제안(이미 남이 낸 제안이 있으면 동의로 친다)
create or replace function public.world_raid_forfeit(p_raid uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); rd public.world_raids%rowtype; n int; nm text; v public.world_raid_votes%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found then raise exception '없는 결전입니다.'; end if;
  if rd.kind <> 'final' then raise exception '결전에서만 포기할 수 있습니다.'; end if;
  if rd.status not in ('signup', 'fight') then raise exception '이미 끝난 결전입니다.'; end if;
  select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = uid;
  if nm is null then raise exception '이 결전에 참가하고 있지 않습니다.'; end if;
  select count(*) into n from public.world_raid_members where raid_id = p_raid;
  if n <= 1 then
    delete from public.world_raid_votes where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'phase', nm || ' — 결전을 포기하고 물러났습니다. ' || rd.boss_name || '이(가) 봉연 속으로 물러납니다.');
    perform public.world_raid_settle(p_raid, false);
    return public.world_raid_snapshot(p_raid);
  end if;
  select * into v from public.world_raid_votes where raid_id = p_raid and expires_at > now();
  if found then return public.world_raid_forfeit_vote(p_raid, true); end if;
  insert into public.world_raid_votes(raid_id, proposer, yes, expires_at) values (p_raid, uid, array[uid], now() + interval '60 seconds')
  on conflict (raid_id) do update set proposer = excluded.proposer, yes = excluded.yes, expires_at = excluded.expires_at;
  perform public.world_raid_say(p_raid, 'info', nm || ' — 결전을 포기하자고 합니다. 60초 안에 모두 동의하면 다 함께 물러납니다.');
  insert into public.world_notifications(user_id, kind, title, content, payload)
  select m.owner_id, 'raid_vote', '결전 포기 제안', nm || ' 조사원이 구중 봉주와의 결전을 포기하자고 합니다. 결전 화면에서 60초 안에 답해 주세요.', jsonb_build_object('raid_id', p_raid)
    from public.world_raid_members m where m.raid_id = p_raid and m.owner_id <> uid;
  update public.world_raids set updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end
$function$;

-- 포기 제안에 답하기: 반대하면 제안이 사라지고, 모두 동의하면 실패로 정리해 다 함께 물러난다
create or replace function public.world_raid_forfeit_vote(p_raid uuid, p_agree boolean)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); rd public.world_raids%rowtype; nm text; v public.world_raid_votes%rowtype;
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into rd from public.world_raids where raid_id = p_raid for update;
  if not found or rd.status not in ('signup', 'fight') then raise exception '이미 끝난 결전입니다.'; end if;
  select name into nm from public.world_raid_members where raid_id = p_raid and owner_id = uid;
  if nm is null then raise exception '이 결전에 참가하고 있지 않습니다.'; end if;
  select * into v from public.world_raid_votes where raid_id = p_raid and expires_at > now();
  if not found then raise exception '포기 제안이 없거나 시간이 지났습니다.'; end if;
  if not p_agree then
    delete from public.world_raid_votes where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'info', nm || ' — 포기에 반대했습니다. 결전을 이어 갑니다.');
  else
    if not (uid = any (v.yes)) then v.yes := v.yes || uid; end if;
    if not exists (select 1 from public.world_raid_members m where m.raid_id = p_raid and not (m.owner_id = any (v.yes))) then
      delete from public.world_raid_votes where raid_id = p_raid;
      perform public.world_raid_say(p_raid, 'phase', '모두 동의해 결전을 포기하고 다 함께 물러납니다. ' || rd.boss_name || '이(가) 봉연 속으로 물러납니다.');
      perform public.world_raid_settle(p_raid, false);
      return public.world_raid_snapshot(p_raid);
    end if;
    update public.world_raid_votes set yes = v.yes where raid_id = p_raid;
    perform public.world_raid_say(p_raid, 'info', nm || ' — 포기에 동의했습니다.');
  end if;
  update public.world_raids set updated_at = now() where raid_id = p_raid;
  return public.world_raid_snapshot(p_raid);
end
$function$;

revoke all on function public.world_raid_forfeit(uuid) from public, anon;
revoke all on function public.world_raid_forfeit_vote(uuid, boolean) from public, anon;
grant execute on function public.world_raid_forfeit(uuid) to authenticated;
grant execute on function public.world_raid_forfeit_vote(uuid, boolean) to authenticated;

-- 새 알림 종류 raid_vote를 알림 설정의 「토벌」 갈래에 넣는다
do $do$
declare d text; o text; old text := 'when p_kind in (''raid_invite'', ''raid'', ''gw'', ''gw_invite'') then ''raid''';
begin
  d := pg_get_functiondef('public.world_notify_group(text)'::regprocedure);
  if position('raid_vote' in d) > 0 then return; end if;
  if position(old in d) = 0 then raise exception 'world_notify_group의 토벌 줄을 찾지 못함'; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = 'public.world_notify_group(text)'::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, old, 'when p_kind in (''raid_invite'', ''raid_vote'', ''raid'', ''gw'', ''gw_invite'') then ''raid''');
end $do$;

update public.world_patch_notes set body = body || $N$
## 7.4.3
- **10장 결전 「포기하고 나오기」**: 결전 화면 위의 단추로 물러날 수 있습니다. 혼자라면 바로 실패로 끝나고(다시 도전 가능), 함께라면 동료들에게 포기를 제안합니다. 60초 안에 모두 동의하면 다 함께 물러나고, 한 사람이라도 반대하면 결전을 이어 갑니다. 포기하면 보상은 없습니다.
- **결전을 열 때 확인 창**: 같은 곳에 있는 파티원 수에 맞춰 알려 드립니다. 구중 봉주는 넷이 함께 맞서도록 만든 최종 보스라, 혼자서는 거의 이길 수 없고 둘이서는 어렵지만 해볼 만합니다.
$N$ where note_id = '7.4.0' and position('## 7.4.3' in body) = 0;

update public.world_app_meta set value = '20261103232000' where key = 'db_version';
