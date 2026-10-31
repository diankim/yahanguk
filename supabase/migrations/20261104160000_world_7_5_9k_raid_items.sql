-- 7.5.9k — 봉연 토벌의 물품·자리 비움(사용자 요청)
-- ① 토벌에서 싸우는 동안(물러남이 아니고 토벌 자리에 있을 때) 가방·퀵슬롯으로 물품을 바로 쓰지 못하게 한다(토벌 행동 간격과 상관없이 체력을 채우던 것).
--    토벌 화면의 「물품」(world_raid_action item)은 yh.raid_item을 켜고 같은 길(world_use_item)을 지나므로 그대로 된다.
-- ② 토벌 자리를 비우면(다른 곳에 있거나 이동·원정 중·전투불능) 물러난 것으로 본다: 요괴가 노리지 않고, 함께 거는 회복·북돋기도 받지 않으며,
--    가방·퀵슬롯도 쓸 수 있다(거점에 가서 쉬고 돌아오기). 참가 기록은 그대로라 돌아오면 다시 합류하지 않고 바로 싸우며(요괴 체력도 다시 늘지 않음),
--    쌓은 기여도대로 정산한다.
create or replace function public.world_raid_here(p_uid uuid, p_region text)
 returns boolean
 language plpgsql
 stable security definer
 set search_path to 'pg_catalog', 'public'
as $function$
begin
  return exists (select 1 from public.world_characters ch join public.world_map_regions r on r.region_name = ch.location
                  where ch.owner_id = p_uid and r.region_id = p_region and ch.travel_destination is null and ch.downed_at is null and ch.health > 0)
     and not exists (select 1 from public.world_expeditions where owner_id = p_uid and status = 'active');
end $function$;
revoke all on function public.world_raid_here(uuid, text) from public, anon, authenticated;
grant execute on function public.world_raid_here(uuid, text) to fn_owner_field;

do $p$
declare r record; d text; own text; inh boolean; n int;
begin
  for r in select * from (values
      ('public.world_use_item(text)'::regprocedure,
       $a$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;$a$,
       $b$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(current_setting('yh.raid_item', true), '') <> '1' AND EXISTS (
       SELECT 1 FROM public.world_raid_members m JOIN public.world_raids rd ON rd.raid_id = m.raid_id
        WHERE m.owner_id = uid AND rd.status = 'fight' AND coalesce(m.out_until, '-infinity'::timestamptz) <= now()
          AND public.world_raid_here(uid, rd.region_id)) THEN
    RAISE EXCEPTION '토벌에서 싸우는 동안에는 가방의 물품을 바로 쓸 수 없습니다. 토벌 화면의 「물품」으로 쓰세요(물러나 있거나 토벌 자리를 비운 동안에는 가방에서도 쓸 수 있습니다).';
  END IF;$b$, 'yh.raid_item', 1),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$    perform public.world_use_item(p_item);$a$,
       $b$    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);$b$, 'yh.raid_item', 1),
      -- 요괴의 표적·광역·사슬·함께 거는 효과·「모두 물러남」 판정에서 자리를 비운 사람을 뺀다
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$(x.out_until is null or x.out_until <= now())$a$,
       $b$(x.out_until is null or x.out_until <= now()) and public.world_raid_here(x.owner_id, rd.region_id)$b$, 'world_raid_here(x.owner_id', 10),
      -- 화면: 참가자마다 자리 비움, 나도 자리 비움
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'me', x.owner_id = uid,$a$,
       $b$'me', x.owner_id = uid, 'away', rd.status = 'fight' and not public.world_raid_here(x.owner_id, rd.region_id),$b$, '''away'', rd.status', 1),
      ('public.world_raid_snapshot_core(uuid)'::regprocedure,
       $a$'here', here = rd.region_id,$a$,
       $b$'here', here = rd.region_id, 'away', me.owner_id is not null and rd.status = 'fight' and not public.world_raid_here(uid, rd.region_id),$b$, '''away'', me.owner_id', 1)
    ) x(fn, a, b, mark, cnt)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> r.cnt then raise exception '7.5.9k anchor in % (% of %)', r.fn, n, r.cnt; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104160000' where key = 'db_version';
