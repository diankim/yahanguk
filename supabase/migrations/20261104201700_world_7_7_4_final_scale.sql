-- 7.7.4 — 10장 결전 「구중 봉주」: 받는 피해를 도전자 평균 레벨·평균 전투력에 맞춘다(사용자 요청 2026-11-01).
-- 전에는 맞는 사람 자신의 레벨로 피해를 정해(4 + 0.7×(Lv+3)) 같은 싸움에서도 높은 레벨일수록 더 아프게 맞고, 전투력은 피해에 들어가지 않았다.
-- 이제 결전(kind final)은 모든 참가자에게 같은 기준: (4 + 0.7×(평균 Lv+3)) × 전투력 배율.
--   전투력 배율 = 평균 공격력 ÷ (7.5 × 평균 Lv)를 0.75~1.5로 자름(Lv38 GM 공격 288·여보 274 ≈ 7.5×Lv가 1배).
-- 체력은 이미 평균 공격력 ×100(최소 4,716) × 인원 배율 1·1.7·2.3·2.8이라 그대로 둔다. 서버 보스(kind world)는 그대로.
create or replace function public.world_raid_boss_base(p_raid uuid, p_kind text, p_lv int)
returns numeric language plpgsql stable security definer set search_path to 'pg_catalog', 'public' as $function$
declare al numeric; aa numeric;
begin
  if p_kind is distinct from 'final' then return 4 + 0.7 * (coalesce(p_lv, 1) + 3); end if;
  select avg(level), avg(coalesce((stats ->> 'attack')::numeric, 50)) into al, aa from public.world_raid_members where raid_id = p_raid;
  al := coalesce(al, p_lv, 30);
  return (4 + 0.7 * (al + 3)) * least(1.5, greatest(0.75, coalesce(aa, 7.5 * al) / greatest(1, 7.5 * al)));
end $function$;
revoke all on function public.world_raid_boss_base(uuid, text, int) from public, anon, authenticated;
grant execute on function public.world_raid_boss_base(uuid, text, int) to fn_owner_field;

do $p$
declare d text; n1 int; n2 int; own text;
begin
  d := replace(pg_get_functiondef('public.world_raid_action'::regproc), E'\r\n', E'\n');
  if position('world_raid_boss_base' in d) > 0 then return; end if;
  n1 := (length(d) - length(replace(d, '(4 + 0.7 * (m.level + 3))', ''))) / length('(4 + 0.7 * (m.level + 3))');
  n2 := (length(d) - length(replace(d, '(4 + 0.7 * (lv + 3))', ''))) / length('(4 + 0.7 * (lv + 3))');
  if n1 <> 2 or n2 <> 1 then raise exception '7.7.4 final scale anchor (% / %)', n1, n2; end if;
  d := replace(d, '(4 + 0.7 * (m.level + 3))', 'public.world_raid_boss_base(p_raid, rd.kind, m.level)');
  d := replace(d, '(4 + 0.7 * (lv + 3))', 'public.world_raid_boss_base(p_raid, rd.kind, lv)');
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_raid_action'::regproc;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute d;
end $p$;

update public.world_app_meta set value = '20261104201700' where key = 'db_version';
