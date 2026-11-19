CREATE OR REPLACE FUNCTION public.world_regular_give(p_npc text, p_order integer, p_fine boolean DEFAULT false)
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); nr jsonb := public.world_regular_rule(p_npc); r jsonb := public.world_regular_rules(); c public.world_characters%rowtype;
  g public.world_regular_progress%rowtype; today date := (now() at time zone 'Asia/Seoul')::date; o jsonb; id text; q int; nm text; inv jsonb; st jsonb; st_ok boolean;
  free_inv int; take_inv int; take_st int; rk int; xp int; v_gil int; add int; aff0 int; aff1 int; s0 int; s1 int; dn int; v_done int[]; used_st jsonb := '{}'::jsonb; line text; ids text[]; cid text; need int; got int;
begin
  perform public.world_travel_guard('연담 납품');
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  perform public.world_seal_guard();
  if nr is null then raise exception '없는 연담 상대입니다.'; end if;
  if not public.world_regular_open(uid, p_npc) then raise exception '아직 연담을 맺은 사람이 아닙니다.'; end if;
  select * into c from public.world_characters where owner_id = uid for update;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  if coalesce(c.is_dead, false) or c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 넘길 수 없습니다.'; end if;
  if (public.world_region_at(c.location)).region_id is distinct from nr ->> 'region' then
    raise exception '%에서 넘깁니다.', (select m.region_name from public.world_map_regions m where m.region_id = nr ->> 'region');
  end if;
  insert into public.world_regular_day(owner_id, day, n) values (uid, today, 0) on conflict (owner_id) do update set day = excluded.day, n = 0 where world_regular_day.day <> excluded.day;
  select d.n into dn from public.world_regular_day d where d.owner_id = uid for update;
  if dn >= (r ->> 'day_n')::int then raise exception '오늘 납품은 다 했습니다(모든 연담을 합쳐 하루 %번). 내일 다시 오세요.', r ->> 'day_n'; end if;
  insert into public.world_regular_progress(owner_id, npc, day) values (uid, p_npc, today) on conflict do nothing;
  select * into g from public.world_regular_progress where owner_id = uid and npc = p_npc for update;
  v_done := case when g.day = today then g.done else '{}' end;
  if p_order = any (v_done) then raise exception '이 주문은 오늘 이미 넘겼습니다.'; end if;
  select x into o from jsonb_array_elements(public.world_regular_orders(uid, p_npc, today)) x where (x ->> 'i')::int = p_order;
  if o is null then raise exception '없는 주문입니다.'; end if;
  id := o ->> 'id'; q := (o ->> 'qty')::int;
  if coalesce(p_fine, false) then
    if not exists (select 1 from public.world_item_catalog h where h.item_id = id || '_hq') then raise exception '우수품이 없는 물품입니다.'; end if;
    id := id || '_hq';
  end if;
  ids := case when coalesce(p_fine, false) then array[id]
              when exists (select 1 from public.world_item_catalog h where h.item_id = id || '_hq') then array[id, id || '_hq'] else array[id] end;
  nm := coalesce((select item_name from public.world_item_catalog where item_id = id), id);
  st_ok := public.world_project_st_ok(uid);
  if st_ok then
    insert into public.world_storage(owner_id) values (uid) on conflict do nothing;
    select s.items into st from public.world_storage s where s.owner_id = uid for update;
  end if;
  inv := coalesce(c.inventory, '{}'::jsonb);
  need := q; got := 0;
  foreach cid in array ids loop
    if exists (select 1 from public.world_item_locks l where l.owner_id = uid and l.item_id = cid) then continue; end if;
    free_inv := public.world_give_check(uid, cid, inv);
    take_inv := least(need, free_inv);
    if take_inv > 0 then inv := public.world_inv_add(inv, cid, -take_inv); need := need - take_inv; end if;
    if need > 0 and st_ok then
      take_st := least(need, greatest(0, coalesce((st ->> cid)::int, 0)));
      if take_st > 0 then
        st := case when coalesce((st ->> cid)::int, 0) - take_st <= 0 then st - cid else jsonb_set(st, array[cid], to_jsonb(coalesce((st ->> cid)::int, 0) - take_st)) end;
        used_st := used_st || jsonb_build_object(cid, take_st); need := need - take_st;
      end if;
    end if;
    exit when need <= 0;
  end loop;
  if need > 0 then
    raise exception '「%」이(가) 모자랍니다(%개 필요, 넘길 수 있는 것 %개 — 잠근 것·장착 중·강화한 것은 빠집니다).', nm, q, q - need;
  end if;
  line := nr ->> 'line';
  rk := public.world_regular_rank(uid, line);
  xp := public.world_regular_xp(rk, coalesce(p_fine, false));
  v_gil := floor(coalesce((select reference_price from public.world_item_catalog where item_id = o ->> 'id'), 0) * q * (r -> 'gil' ->> 'rate')::numeric + (r -> 'gil' ->> 'base')::numeric)::int;
  add := case when coalesce(p_fine, false) then (r -> 'aff' ->> 'hq')::int else (r -> 'aff' ->> 'give')::int end;
  aff0 := g.aff; aff1 := least((r -> 'aff' ->> 'cap')::int, aff0 + add);
  s0 := public.world_regular_stage(aff0); s1 := public.world_regular_stage(aff1);
  perform set_config('yh.wear_leaves', 'on', true);
  update public.world_characters set inventory = inv, gil = gil + v_gil,
    skill_progress = public.world_skill_add(skill_progress, line, xp), updated_at = now() where owner_id = uid;
  if used_st <> '{}'::jsonb then update public.world_storage set items = st, updated_at = now() where owner_id = uid; end if;
  update public.world_regular_progress set aff = aff1, total = total + 1, day = today, done = v_done || p_order, updated_at = now() where owner_id = uid and npc = p_npc;
  update public.world_regular_day set n = n + 1 where owner_id = uid;
  insert into public.world_economy_ledger(owner_id, action, currency_delta, sink, details)
  values (uid, 'regular_give', v_gil, false, jsonb_build_object('npc', p_npc, 'item', id, 'qty', q));
  if s1 > s0 then
    insert into public.world_notifications(user_id, kind, title, content, payload)
    values (uid, 'regular_stage', (nr ->> 'short') || ' · 친밀도 ' || s1 || '단계',
      case when s1 >= 5 and aff1 >= (r -> 'aff' ->> 'cap')::int then public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 가장 높은 단계에 닿았습니다. 마지막 이야기가 열렸습니다.'
           else public.world_josa(nr ->> 'short', '과', '와') || '의 친밀도가 ' || s1 || '단계가 되었습니다. 새 이야기가 열렸습니다.' end,
      jsonb_build_object('npc', p_npc, 'stage', s1, 'quest', (nr ->> 'key') || '_' || s1));
  end if;
  if aff1 >= (r -> 'aff' ->> 'cap')::int and aff0 < (r -> 'aff' ->> 'cap')::int then perform public.world_title_award_check(uid, 'regular'); end if;
  return jsonb_build_object('npc', p_npc, 'item', id, 'qty', q, 'xp', xp, 'gil', v_gil, 'aff', aff1, 'add', aff1 - aff0, 'stage', s1, 'stage_up', s1 > s0,
    'from_storage', used_st, 'today', dn + 1, 'cap', (r ->> 'day_n')::int,
    'content', public.world_josa(nr ->> 'short', '에게', '에게') || ' 「' || nm || '」 ' || q || '개를 넘겼습니다 · ' || public.world_line_name(line) || ' 경험 +' || xp || ' · ' || to_char(v_gil, 'FM999,999,990') || '전 · 친밀도 +' || (aff1 - aff0) ||
      case when s1 > s0 then ' · 친밀도 ' || s1 || '단계 — 새 이야기가 열렸습니다!' else '' end || ' · 오늘 ' || (dn + 1) || '/' || (r ->> 'day_n'),
    'view', public.world_regular_view(p_npc));
end $function$;
update public.world_patch_notes set body = body || E'\n- 연담 납품이 보통 물품과 우수품을 따로 세어, 둘을 합치면 넉넉한데도 넘길 수 없던 것을 고쳤습니다. 이제 보통 물품을 먼저 쓰고 모자라는 몫을 우수품으로 채웁니다(「우수품 넘기기」는 그대로 우수품만 씁니다).'
where note_id = '3.0.0' and position('보통 물품과 우수품을 따로 세어' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261122040000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
