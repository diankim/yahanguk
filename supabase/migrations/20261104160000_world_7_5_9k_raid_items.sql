-- 7.5.9k — 토벌에서 싸우는 동안(물러남이 아닐 때) 가방·퀵슬롯으로 물품을 바로 쓰지 못하게(사용자 요청: 토벌 행동 간격과 상관없이 체력을 채우던 것).
-- 토벌 화면의 「물품」(world_raid_action item)은 yh.raid_item을 켜고 같은 길(world_use_item)을 지나므로 그대로 된다. 물러난 동안에는 가방에서도 쓸 수 있다.
do $p$
declare r record; d text; own text; inh boolean;
begin
  for r in select * from (values
      ('public.world_use_item(text)'::regprocedure,
       $a$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;$a$,
       $b$IF NOT FOUND THEN RAISE EXCEPTION '캐릭터를 먼저 만드세요.'; END IF;
  IF coalesce(current_setting('yh.raid_item', true), '') <> '1' AND EXISTS (
       SELECT 1 FROM public.world_raid_members m JOIN public.world_raids rd ON rd.raid_id = m.raid_id
        WHERE m.owner_id = uid AND rd.status = 'fight' AND coalesce(m.out_until, '-infinity'::timestamptz) <= now()) THEN
    RAISE EXCEPTION '토벌에서 싸우는 동안에는 가방의 물품을 바로 쓸 수 없습니다. 토벌 화면의 「물품」으로 쓰세요(물러나 있는 동안에는 가방에서도 쓸 수 있습니다).';
  END IF;$b$, 'yh.raid_item'),
      ('public.world_raid_action(uuid,text,text,uuid,text)'::regprocedure,
       $a$    perform public.world_use_item(p_item);$a$,
       $b$    perform set_config('yh.raid_item', '1', true);
    perform public.world_use_item(p_item);
    perform set_config('yh.raid_item', '', true);$b$, 'yh.raid_item')
    ) x(fn, a, b, mark)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.mark in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, r.a, ''))) / length(r.a) <> 1 then raise exception '7.5.9k anchor in %', r.fn; end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104160000' where key = 'db_version';
