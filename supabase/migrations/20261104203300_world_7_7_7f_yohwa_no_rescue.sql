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

-- 7.7.7f-2 — 봉연의 그림자 「기운 모으기」를 끊는 데 필요한 피해를 지금 싸우는 사람 수(공격력 합)에 맞춘다(사용자 요청).
-- 전에는 최대 체력의 4%(최대 체력은 합류한 모든 사람의 공격력으로 정해져 자리를 비운 사람 몫까지 들어감) — 첫 회차 156번 중 한 번도 못 끊었다.
-- 이제 지난 2분 안에 행동한, 물러나지 않은 참가자 공격력 합 × 4(한 사람이 8초 동안 고르게 공격하면 낼 몫의 절반쯤), 최소 500. 결전은 그대로 4%.
create or replace function public.world_raid_charge_need(p_raid uuid, p_kind text, p_max_hp int)
returns int language plpgsql security definer set search_path to 'pg_catalog', 'public' as $function$
declare reg text; s numeric;
begin
  if p_kind <> 'world' then return round(p_max_hp * 0.04)::int; end if;
  select region_id into reg from public.world_raids where raid_id = p_raid;
  select coalesce(sum(greatest(1, coalesce((x.stats ->> 'attack')::numeric, 0))), 0) into s
    from public.world_raid_members x join public.world_characters ch on ch.owner_id = x.owner_id
   where x.raid_id = p_raid and x.out_until is null and public.world_raid_here(x.owner_id, reg)
     and x.last_action_at > now() - interval '120 seconds' and ch.health > 1;
  return greatest(500, round(s * 4))::int;
end $function$;
revoke all on function public.world_raid_charge_need(uuid, text, int) from public, anon, authenticated;
grant execute on function public.world_raid_charge_need(uuid, text, int) to fn_owner_field;

do $p$
declare d text; n int; own text;
begin
  d := replace(pg_get_functiondef('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure), E'\r\n', E'\n');
  if position('world_raid_charge_need' in d) > 0 then return; end if;
  n := (length(d) - length(replace(d, 'round(rd.max_hp * 0.04)', ''))) / length('round(rd.max_hp * 0.04)');
  if n <> 2 then raise exception '7.7.7f charge anchor (% of 2)', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, 'round(rd.max_hp * 0.04)', 'public.world_raid_charge_need(p_raid, rd.kind, rd.max_hp)');
end $p$;

update public.world_patch_notes set body = body || $N$
## 7.7.7f
- 요괴화가 끝나 쓰러진 조사원은 동료의 구조·본부 구조대·회생 부적으로 일으킬 수 없습니다. 쓰러진 본인이 「안전지대 봉인」을 골라 24시간 해독을 받아야 합니다(전에는 바로 구조되면 봉인을 고를 수 없게 되고 요화가 남아 다음 날 다시 쓰러졌습니다).
- 봉연의 그림자 「기운 모으기」를 끊는 데 필요한 피해가 이제 지금 싸우는 조사원 수(공격력 합)에 맞춰 정해집니다. 전에는 최대 체력의 4%라 자리를 비운 사람 몫까지 들어가 한 번도 끊기지 않았습니다.
$N$ where note_id = '7.7.0' and position('## 7.7.7f' in body) = 0;

update public.world_app_meta set value = '20261104203300' where key = 'db_version';
