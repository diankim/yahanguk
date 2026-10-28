-- 긴급 수정 기록(2026-10-28 23:05 KST, 운영 DB에 바로 적용함 — 다시 돌릴 필요 없음, 다시 돌려도 고칠 자리가 없어 멈춘다)
-- 이야기 마지막 가설 확정(world_story_combine)과 정인 선물(world_bond_gift)이 가방 칸을 셀 때 장착한 장비까지 세고
-- 용량도 bag_capacity로 따로 계산해, 자리가 있는데도 「가방 자리가 모자랍니다」로 막혔다(제보 3: 관혁 8장 보상 미지급).
-- 다른 곳과 같은 world_bag_limit(장착 장비 수만큼 더함)으로 맞췄다. 관혁의 8장 「녹은 사슬」은 같은 처리에서 확정해 보상을 지급했다.
grant fn_owner_field to postgres with inherit true, set true;
do $$
declare p record; d text; n int;
begin
  for p in select * from (values
    (1, 'world_story_combine', $a$greatest(c.bag_capacity + coalesce((rw ->> 'bag')::int, 0) + CASE WHEN c.major_faction_id = 'river_alliance' THEN 6 ELSE 0 END,$a$,
        $a$greatest(public.world_bag_limit(uid) + coalesce((rw ->> 'bag')::int, 0),$a$),
    (2, 'world_bond_gift', $a$public.world_bag_room(pc.inventory, p_item, pc.bag_capacity + (case when pc.major_faction_id = 'river_alliance' then 6 else 0 end))$a$,
        $a$public.world_bag_room(pc.inventory, p_item, public.world_bag_limit(pc.owner_id))$a$)
  ) v(ord, fn, old, new) order by ord loop
    select pg_get_functiondef(oid) into d from pg_proc where proname = p.fn and pronamespace = 'public'::regnamespace limit 1;
    n := (length(d) - length(replace(d, p.old, ''))) / length(p.old);
    if n <> 1 then raise exception '고칠 자리 %: %곳', p.ord, n; end if;
    execute replace(d, p.old, p.new);
  end loop;
end $$;
grant fn_owner_field to postgres with inherit false, set false;
