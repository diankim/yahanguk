-- 장착한 장비는 가방 칸을 차지하지 않는다(2026-10-29).
--   장착해도 물품은 inventory에 남아 world_bag_count가 센다. 장비는 묶음 크기 1이라 장착한 수만큼 가방 용량을 더하면
--   「장착한 것은 세지 않음」과 같다. 가방 용량을 계산하는 곳(world_bag_limit·용량 트리거·원정 귀환·보따리·직접 거래)에 더한다.
--   화면(core.js bagUsed)은 쓴 칸에서 장착한 것을 뺀다.
grant fn_owner_field to postgres with inherit true, set true;
grant fn_owner_expedition to postgres with inherit true, set true;

create or replace function public.world_bag_limit(p_owner uuid)
returns integer language sql stable security definer set search_path to 'pg_catalog', 'public' as $$
  select c.bag_capacity + case when c.major_faction_id = 'river_alliance' then 6 else 0 end
       + (select count(*)::int from public.world_character_equipment e
           where e.owner_id = c.owner_id and coalesce((c.inventory ->> e.item_id)::numeric, 0) > 0)
  from public.world_characters c where c.owner_id = p_owner
$$;
grant execute on function public.world_bag_limit(uuid) to fn_owner_field;

do $$
declare pat record; d text;
begin
  for pat in select * from (values
    ('public.world_enforce_bag_capacity()',
     'cap int := new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END;',
     'cap int := new.bag_capacity + CASE WHEN new.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END
    + (SELECT count(*)::int FROM public.world_character_equipment e WHERE e.owner_id = new.owner_id AND coalesce((new.inventory ->> e.item_id)::numeric, 0) > 0);'),
    -- 원정 귀환은 원정 장비가 닳아 이름이 바뀐 뒤의 가방(inv)으로 센다
    ('public.world_expedition_complete(boolean)',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end
    + (select count(*)::int from public.world_character_equipment e where e.owner_id = c.owner_id and coalesce((inv ->> e.item_id)::numeric, 0) > 0);'),
    ('public.world_overflow_snapshot()',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;', 'cap := public.world_bag_limit(c.owner_id);'),
    ('public.world_overflow_take(text,integer)',
     'cap := c.bag_capacity + case when c.major_faction_id = ''river_alliance'' then 6 else 0 end;', 'cap := public.world_bag_limit(c.owner_id);'),
    ('public.world_trade_direct_respond(uuid,boolean)',
     'a.bag_capacity + case when a.major_faction_id = ''river_alliance'' then 6 else 0 end', 'public.world_bag_limit(a.owner_id)'),
    ('public.world_trade_direct_respond(uuid,boolean)',
     'b.bag_capacity + case when b.major_faction_id = ''river_alliance'' then 6 else 0 end', 'public.world_bag_limit(b.owner_id)')
  ) as t(fn, a, b) loop
    d := pg_get_functiondef(pat.fn::regprocedure);
    if position(pat.b in d) > 0 then continue; end if;
    if (length(d) - length(replace(d, pat.a, ''))) / length(pat.a) <> 1 then raise exception '가방 용량 고칠 자리가 하나가 아닙니다: % / %', pat.fn, left(pat.a, 60); end if;
    execute replace(d, pat.a, pat.b);
  end loop;
end $$;

grant fn_owner_field to postgres with inherit false, set false;
grant fn_owner_expedition to postgres with inherit false, set false;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261029030000', now())
on conflict (key) do update set value = excluded.value, changed_at = now();
