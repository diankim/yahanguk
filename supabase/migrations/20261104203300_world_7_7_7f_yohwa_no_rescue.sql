-- 7.7.7f — 요화(요괴화가 끝나)로 쓰러진 조사원은 구조·본부 구조대·회생 부적으로 일으킬 수 없다(사용자 결정 2026-11-01).
-- 쓰러진 본인이 「안전지대 봉인」(world_yohwa_seal)을 고르는 길만 남긴다. 전에는 동료가 49초 만에 구조해
-- 봉인 단추가 사라지고 요화가 그대로 남아 다음 날 다시 쓰러졌다(연주, 2026-11-01).
-- 막는 자리: world_characters 갱신에서 downed_at이 풀리는 순간(WHEN으로 그때만 돈다 — 다른 갱신에는 비용 없음).
-- world_yohwa_seal은 요화 줄을 먼저 지우고 downed_at을 풀므로 걸리지 않는다. 귀령초 등으로 요화가 풀린 뒤면 구조할 수 있다.
create or replace function public.world_yohwa_down_guard()
returns trigger language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
begin
  if exists (select 1 from public.world_character_statuses s
              where s.owner_id = new.owner_id and s.status_key = 'yohwa'
                and abs(coalesce((s.metadata ->> 'down_epoch')::numeric, -1) - extract(epoch from old.downed_at)) < 2) then
    raise exception '요화로 쓰러진 조사원은 구조로 일으킬 수 없습니다. 쓰러진 본인이 「안전지대 봉인」을 골라야 합니다.';
  end if;
  return new;
end $function$;
revoke all on function public.world_yohwa_down_guard() from public, anon, authenticated;

drop trigger if exists trg_world_yohwa_down_guard on public.world_characters;
create trigger trg_world_yohwa_down_guard before update of downed_at on public.world_characters
  for each row when (old.downed_at is not null and new.downed_at is null)
  execute function public.world_yohwa_down_guard();

update public.world_patch_notes set body = body || $N$
## 7.7.7f
- 요괴화가 끝나 쓰러진 조사원은 동료의 구조·본부 구조대·회생 부적으로 일으킬 수 없습니다. 쓰러진 본인이 「안전지대 봉인」을 골라 24시간 해독을 받아야 합니다(전에는 바로 구조되면 봉인을 고를 수 없게 되고 요화가 남아 다음 날 다시 쓰러졌습니다).
$N$ where note_id = '7.7.0' and position('## 7.7.7f' in body) = 0;

update public.world_app_meta set value = '20261104203300' where key = 'db_version';
