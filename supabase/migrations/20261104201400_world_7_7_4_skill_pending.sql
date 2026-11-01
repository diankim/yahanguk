-- 7.7.4 — 고를 택일 기술이 있으면 캐릭터 탭에 빨간 점(제보 78). 화면(titledot.js)이 새 칭호 수와 함께 읽는다.
-- 단계에 닿았는데 아직 고르지 않은 택일 칸(slot a·b) + 무료 다시 고르기 칸 수만 센다(world_skill_snapshot과 같은 기준, 가볍게).
create or replace function public.world_skill_pending()
returns int language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare uid uuid := public.fn_owner_auth_uid(); sp jsonb; pk jsonb; fr text[];
begin
  if uid is null then return 0; end if;
  select skill_progress into sp from public.world_characters where owner_id = uid;
  select picks, free_repick into pk, fr from public.world_skill_picks where owner_id = uid;
  sp := coalesce(sp, '{}'::jsonb); pk := coalesce(pk, '{}'::jsonb); fr := coalesce(fr, '{}');
  return (select count(*) from (select distinct s.category, s.unlock_rank from public.world_skill_catalog s
     where s.slot = 'a' and s.category <> 'combo'
       and coalesce((sp -> s.category ->> 'rank')::int, 1) >= s.unlock_rank
       and (coalesce(pk ->> (s.category || ':' || s.unlock_rank), '') = '' or (s.category || ':' || s.unlock_rank) = any (fr))) z)::int;
end $function$;
revoke all on function public.world_skill_pending() from public, anon;
grant execute on function public.world_skill_pending() to authenticated;

update public.world_app_meta set value = '20261104201400' where key = 'db_version';
