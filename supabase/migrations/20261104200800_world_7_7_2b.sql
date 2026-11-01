-- 7.7.2b — 싸우는 중에는 퀵슬롯·가방의 물품도 턴을 쓴다(사용자 요청 2026-11-01).
-- 현장 토벌·파티 토벌·귀허의 주인 결전에 든 동안 world_use_item(가방·퀵슬롯·상태 창)과 world_party_use_item(동료 돌보기)을 거절한다.
-- 그 싸움의 물품은 전투 화면의 「물품」 행동(world_battle_action·world_pfight_act·world_gw_act)으로만 쓴다 — 그쪽은 world_use_item을 부르지 않는다.
-- 화면은 퀵슬롯·가방에서 누른 물품을 떠 있는 전투 화면의 「물품」 행동으로 돌린다(core.js battleItemRoute).
-- 합동 토벌(world_raid_action)은 7.6.0의 yh.raid_item 그대로.
do $p$
declare
  r record; d text; n int; own text; inh boolean;
  chk text := $c$
  -- 싸우는 중에는 그 싸움의 「물품」 행동으로만(7.7.2b): 가방·퀵슬롯으로 턴 없이 회복하던 것
  IF EXISTS (SELECT 1 FROM public.world_active_encounters ae WHERE ae.owner_id = uid AND ae.result IS NULL AND NOT ae.defeated AND NOT coalesce(ae.fled, false) AND ae.mlevel IS NOT NULL) THEN
    RAISE EXCEPTION '요괴와 싸우는 중에는 전투 화면의 「물품」으로 쓰세요. 물품을 쓰면 한 턴이 지나갑니다.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.world_pfight_members pm JOIN public.world_pfights pf ON pf.fight_id = pm.fight_id WHERE pm.owner_id = uid AND pm.out_reason IS NULL AND pf.status = 'fight') THEN
    RAISE EXCEPTION '파티 토벌 중에는 토벌 화면의 「물품」으로 쓰세요. 물품을 쓰면 그 라운드의 행동이 됩니다.';
  END IF;
  IF EXISTS (SELECT 1 FROM public.world_gw_members gm JOIN public.world_gw_fights gf ON gf.fight_id = gm.fight_id WHERE gm.owner_id = uid AND gf.status = 'fight') THEN
    RAISE EXCEPTION '귀허의 주인과 싸우는 중에는 결전 화면의 「물품」으로 쓰세요. 물품을 쓰면 그 라운드의 행동이 됩니다.';
  END IF;$c$;
begin
  for r in
    select * from (values
      ('public.world_use_item(text)'::regprocedure,
       $a$IF v_base = 'revival_charm' THEN RAISE EXCEPTION '회생 부적은 쓰러졌을 때 씁니다.'; END IF;$a$),
      ('public.world_party_use_item(uuid,text)'::regprocedure,
       $a$perform public.world_seal_guard();$a$)
    ) x(fn, a)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position('(7.7.2b)' in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.2b anchor in % (% of 1)', r.fn, n; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.a || chk);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_patch_notes set body = rtrim(body, E'\n') || $N$

## 7.7.2b
- 싸우는 동안 퀵슬롯·가방·상태 창에서 물품을 쓰면 턴 없이 회복되던 것을 고쳤습니다. 이제 현장 토벌·파티 토벌·귀허의 주인 결전 중에 퀵슬롯이나 가방의 물품을 누르면 전투의 「물품」 행동으로 쓰여 한 턴(파티 토벌·결전은 그 라운드의 행동)이 지나갑니다. 전투에 쓸 수 없는 물품(음식 등)은 싸우는 동안 쓸 수 없고, 싸우는 중에 동료 「돌보기」도 할 수 없습니다.
$N$
 where note_id = '7.7.0' and position('## 7.7.2b' in body) = 0;

update public.world_app_meta set value = '20261104200800' where key = 'db_version';
