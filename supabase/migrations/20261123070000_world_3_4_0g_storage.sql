create or replace function public.world_storage_rules() returns jsonb language sql immutable as $function$
  select jsonb_build_object(
    'base', 70, 'step', 4,
    'prices', jsonb_build_array(1000, 2500, 5000, 10000, 20000, 35000, 50000, 80000),
    'story', 2,
    'arcs', jsonb_build_object('gq_1', 2, 'gq_2', 2, 'gq_3', 2, 'gq_4', 2, 'gq_5', 2, 'mkq_1', 2, 'mkq_2', 2, 'mkq_3', 2, 'mkq_4', 2, 'mkq_5', 2,
                               'mdq_3', 3, 'mdq_6', 3, 'mdq_9', 3, 'mdq_12', 3, 'mdq_15', 3),
    'faction', jsonb_build_object('steps', jsonb_build_array(300, 600, 1000), 'cells', 2),
    'survey', jsonb_build_object('per', 10, 'cells', 2, 'max', 8),
    'jobs', jsonb_build_object('rank', 15, 'cells', 4, 'max', 5),
    'regular', jsonb_build_object('cells', 1))
$function$;
grant execute on function public.world_storage_rules() to fn_owner_field;
alter table public.world_storage drop constraint if exists world_storage_bought_check;
alter table public.world_storage add constraint world_storage_bought_check check (bought >= 0 and bought <= 8);

do $m$
declare s boolean := not pg_has_role(current_user, 'fn_owner_field', 'SET'); g boolean := not has_schema_privilege('fn_owner_field', 'public', 'CREATE');
begin
  if s then execute 'grant fn_owner_field to ' || quote_ident(current_user) || ' with set true'; end if;
  if g then execute 'grant create on schema public to fn_owner_field'; end if;
  execute 'set role fn_owner_field';
  execute $f$
CREATE OR REPLACE FUNCTION public.world_storage_capacity(p_uid uuid)
 RETURNS jsonb
 LANGUAGE sql
 STABLE SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
  with r as (select public.world_storage_rules() j)
  select jsonb_build_object('base', (r.j ->> 'base')::int, 'bought', b.v, 'story', st.v, 'arc', ar.v, 'faction', fa.v, 'survey', sv.v, 'jobs', jb.v, 'regular', rg.v,
           'total', (r.j ->> 'base')::int + b.v + st.v + ar.v + fa.v + sv.v + jb.v + rg.v, 'bought_steps', b.n, 'surveyed', sv.n,
           'job_lines', jb.n, 'regular_done', rg.n,
           'next_price', (r.j -> 'prices' ->> b.n)::int)
    from r,
         lateral (select coalesce((select s.bought from public.world_storage s where s.owner_id = p_uid), 0) n) b0,
         lateral (select b0.n n, b0.n * (r.j ->> 'step')::int v) b,
         lateral (select (r.j ->> 'story')::int * count(*)::int v from public.world_story_chapters ch join public.world_case_progress p
                    on p.owner_id = p_uid and p.case_id = ch.chapter_id
                   where ch.seq between 6 and 10 and coalesce(p.combined, '[]'::jsonb) ? (ch.chapter_id || '_completed')) st,
         lateral (select coalesce(sum((r.j -> 'arcs' ->> g.quest_id)::int), 0)::int v from public.world_quest_progress g
                   where g.owner_id = p_uid and g.done_at is not null and (r.j -> 'arcs') ? g.quest_id) ar,
         lateral (select case when c.major_faction_id is null then 0
                    else (r.j -> 'faction' ->> 'cells')::int * (select count(*)::int from jsonb_array_elements_text(r.j -> 'faction' -> 'steps') t
                                                                 where coalesce(c.faction_reputation, 0) >= t::int) end v
                    from public.world_characters c where c.owner_id = p_uid) fa,
         lateral (select x.n, (r.j -> 'survey' ->> 'cells')::int * least((r.j -> 'survey' ->> 'max')::int, x.n / (r.j -> 'survey' ->> 'per')::int) v
                    from (select count(*)::int n from public.world_region_progress rp where rp.owner_id = p_uid and 'complete' = any (rp.milestones)) x) sv,
         lateral (select x.n, (r.j -> 'jobs' ->> 'cells')::int * least((r.j -> 'jobs' ->> 'max')::int, greatest(0, x.n - 1)) v
                    from (select count(*)::int n from public.world_characters c, unnest(public.world_combat_lines()) l
                           where c.owner_id = p_uid and coalesce((c.skill_progress -> l ->> 'rank')::int, 1) >= (r.j -> 'jobs' ->> 'rank')::int) x) jb,
         lateral (select x.n, (r.j -> 'regular' ->> 'cells')::int * x.n v
                    from (select count(*)::int n from public.world_quest_progress g
                           where g.owner_id = p_uid and g.done_at is not null and g.quest_id like 'rg\_%\_5') x) rg
$function$
$f$;
  execute $f$
CREATE OR REPLACE FUNCTION public.world_storage_expand()
 RETURNS jsonb
 LANGUAGE plpgsql
 SECURITY DEFINER
 SET search_path TO 'pg_catalog', 'public'
AS $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; s public.world_storage%rowtype; price int; rl jsonb := public.world_storage_rules();
begin
  perform public.world_seal_guard();
  c := public.world_storage_check(uid, true);
  insert into public.world_storage(owner_id) values (uid) on conflict (owner_id) do nothing;
  select * into s from public.world_storage where owner_id = uid for update;
  if s.bought >= jsonb_array_length(rl -> 'prices') then raise exception '창고는 전으로 더 넓힐 수 없습니다. 이야기·세력 평판·지역 답사·직업 숙련·연담으로 넓어집니다.'; end if;
  price := (rl -> 'prices' ->> s.bought)::int;
  if c.gil < price then raise exception '전이 모자랍니다(%전 필요).', price; end if;
  update public.world_characters set gil = gil - price, updated_at = now() where owner_id = uid;
  update public.world_storage set bought = bought + 1, updated_at = now() where owner_id = uid;
  return jsonb_build_object('ok', true, 'price', price,
    'content', format('창고를 %s전에 넓혔습니다(+%s칸, 이제 %s칸).', price, rl ->> 'step', (public.world_storage_capacity(uid) ->> 'total')));
end $function$
$f$;
  execute 'reset role';
  if g then execute 'revoke create on schema public from fn_owner_field'; end if;
  if s then execute 'grant fn_owner_field to ' || quote_ident(current_user) || ' with set false'; end if;
end $m$;

update public.world_patch_notes set body = body || $N$
### 창고
- 창고를 최대 200칸까지 넓힐 수 있습니다(전에는 143칸).
- 전으로 넓히기가 네 번 더 늘었습니다(20,000·35,000·50,000·80,000전, +4칸씩).
- 직업 전투 기술 계열이 15단계에 닿을 때마다, 두 번째 계열부터 +4칸씩(다섯 계열까지) 늘어납니다.
- 지역 완전 답사는 40·50·60·70·80곳에서도 +2칸씩 늘어납니다.
- 연담 인물의 이야기 다섯 편을 모두 마칠 때마다 +1칸씩 늘어납니다.
$N$
 where note_id = '3.0.0' and position('창고를 최대 200칸까지' in body) = 0;

update public.world_app_meta set value = '20261123070000' where key = 'db_version';
