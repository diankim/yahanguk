-- 7.7.3 — 퀘스트 채집 물품(사용자 요청 2026-11-01, 귀죽림 영맥 수피 0/3 문의)
-- ① world_field_gather: 맡은 퀘스트 지금 장면의 채집 할 일(물품 지정, 지역이 맞거나 지역 조건 없음)이 이 채집터에서 나오는 물품이면
--    그 물품을 뽑을 무게 ×3(7.3.2 처치 대상 요괴 ×3과 같은 방식). 예: 목재 채집터 나무·나무·송진·영맥 수피 25% → 50%.
-- ② world_quest_task_label: 지역·물품을 정한 채집 할 일 뒤에 그 지역에서 그 물품이 나오는 채집터 종류와 가장 낮은 출입 레벨을 붙인다
--    (「귀죽림에서 영맥 수피 모으기 (목재 채집터 Lv8~)」).
do $p$
declare r record; d text; n int; own text; inh boolean;
begin
  for r in
    select * from (values
      ('public.world_field_gather(uuid)'::regprocedure,
       $a$  sk text[]; line text; rg public.world_map_regions%rowtype;$a$,
       $b$  sk text[]; line text; rg public.world_map_regions%rowtype; v_qw text[];$b$),
      ('public.world_field_gather(uuid)'::regprocedure,
       $a$  it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];$a$,
       $b$  -- 맡은 퀘스트의 채집 물품은 무게 ×3(7.7.3)
  select array_agg(distinct qwi.v) into v_qw from public.world_quest_progress qp
    join public.world_quest_steps qs on qs.quest_id = qp.quest_id and qs.step = qp.step + 1
    cross join lateral jsonb_array_elements(case when jsonb_typeof(qs.need -> 'tasks') = 'array' then qs.need -> 'tasks' else '[]' end) qwt(v)
    cross join lateral jsonb_array_elements_text(case when jsonb_typeof(qwt.v -> 'items') = 'array' then qwt.v -> 'items' else '[]' end) qwi(v)
   where qp.owner_id = uid and qp.done_at is null and qwt.v ->> 't' = 'gather'
     and (not qwt.v ? 'r' or rg.region_id in (select jsonb_array_elements_text(qwt.v -> 'r')));
  if v_qw is not null and s.loot_items && v_qw then
    select qwl.v into it from unnest(s.loot_items) qwl(v) order by -ln(greatest(random(), 1e-9)) / (case when qwl.v = any (v_qw) then 3 else 1 end) limit 1;
  else
    it := s.loot_items[1 + floor(random() * cardinality(s.loot_items))::int];
  end if;$b$),
      ('public.world_quest_task_label(jsonb)'::regprocedure,
       $a$|| coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 모으기', '채집하기')$a$,
       $b$|| coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 모으기', '채집하기')
      -- 나오는 채집터 안내(7.7.3)
      || case when p_task ? 'items' and p_task ? 'r' then coalesce(' (' || (select string_agg(z.k || ' 채집터 Lv' || z.mn || '~', '·' order by z.mn) from (
           select case sp.category when 'herbs' then '약초' when 'wood' then '목재' when 'supplies' then '보급품' when 'water' then '물가'
                    when 'spirit' then '영기' when 'ore' then '광맥' when 'relics' then '유물' else sp.category end k, min(sp.min_level) mn
             from public.world_gathering_spots sp join public.world_exploration_nodes n on n.node_id = sp.node_id
            where sp.active and n.region_id in (select jsonb_array_elements_text(p_task -> 'r'))
              and sp.loot_items && array(select jsonb_array_elements_text(p_task -> 'items'))
            group by 1) z) || ')', '') else '' end$b$)
    ) x(fn, a, b)
  loop
    d := replace(pg_get_functiondef(r.fn), E'\r\n', E'\n');
    if position(r.b in d) > 0 then continue; end if;
    n := (length(d) - length(replace(d, r.a, ''))) / length(r.a);
    if n <> 1 then raise exception '7.7.3 anchor in % (% of 1): %', r.fn, n, left(r.a, 60); end if;
    select p.proowner::regrole::text into own from pg_proc p where p.oid = r.fn;
    select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
    if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
    execute replace(d, r.a, r.b);
    if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
  end loop;
end $p$;

update public.world_app_meta set value = '20261104201000' where key = 'db_version';
