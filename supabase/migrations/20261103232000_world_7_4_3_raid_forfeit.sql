-- 7.4.3 10장 결전 「포기하고 나오기」(사용자 요청, 여보가 혼자 연 결전에서 나올 길이 없어 20분을 기다려야 했다).
-- · 혼자 남은 사람이 포기하면: 시간이 끝났을 때와 같이 실패로 정리(world_raid_settle(false), 위로 보상 없음·다시 도전 가능).
-- · 여럿 중 한 사람이 포기하면: 그 사람만 빠진다(보상 없음). 남은 동료는 그대로 싸우고 보스 체력은 줄지 않는다.
--   모으는 중(signup)에 시작한 사람이 빠지면 남은 사람 가운데 먼저 들어온 이가 시작한 사람이 된다.
-- · 결전 체력(max(4716, 평균 공격력×100) × 인원 1·1.7·2.3·2.8)은 그대로 둔다: 혼자는 거의 불가능, 둘은 어렵지만 해볼 만하다(사용자 결정).
create or replace function public.world_raid_forfeit(p_raid uuid)
 returns jsonb
 language plpgsql
 security definer
 set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := auth.uid(); rd public.world_raids%rowtype; n int; nm text;
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
    perform public.world_raid_say(p_raid, 'phase', nm || ' — 결전을 포기하고 물러났습니다. ' || rd.boss_name || '이(가) 봉연 속으로 물러납니다.');
    perform public.world_raid_settle(p_raid, false);
  else
    delete from public.world_raid_members where raid_id = p_raid and owner_id = uid;
    perform public.world_raid_say(p_raid, 'fall', nm || ' — 결전을 포기하고 물러났습니다. 남은 동료가 싸움을 이어 갑니다.');
    if rd.leader_id = uid then
      update public.world_raids set leader_id = (select owner_id from public.world_raid_members where raid_id = p_raid order by joined_at limit 1), updated_at = now()
       where raid_id = p_raid;
    else
      update public.world_raids set updated_at = now() where raid_id = p_raid;
    end if;
  end if;
  return public.world_raid_snapshot(p_raid);
end
$function$;
revoke all on function public.world_raid_forfeit(uuid) from public, anon;
grant execute on function public.world_raid_forfeit(uuid) to authenticated;

update public.world_patch_notes set body = body || $N$
## 7.4.3
- **10장 결전 「포기하고 나오기」**: 결전 화면에서 언제든 물러날 수 있습니다. 혼자라면 결전이 실패로 끝나고(다시 도전 가능), 여럿이라면 나만 빠지고 남은 동료가 싸움을 이어 갑니다(보스 체력은 줄지 않습니다). 포기하면 보상은 없습니다.
- **결전을 열 때 확인 창**: 같은 곳에 있는 파티원 수에 맞춰 알려 드립니다. 구중 봉주는 넷이 함께 맞서도록 만든 최종 보스라, 혼자서는 거의 이길 수 없고 둘이서는 어렵지만 해볼 만합니다.
$N$ where note_id = '7.4.0' and position('## 7.4.3' in body) = 0;

update public.world_app_meta set value = '20261103232000' where key = 'db_version';
