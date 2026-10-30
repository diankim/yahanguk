-- 7.2.6
-- ① 원정에서 물리친 요괴도 퀘스트·세력 할 일의 「요괴 물리치기」에 센다
--    원정 일지의 승리 줄에 요괴(mid)·등급(rank: 우두머리 guardian, 그 밖 normal)·원정 지역(rg)을 함께 남기고(앞으로의 원정부터),
--    world_exp_win_count가 할 일이 열린 뒤의 내 승리 줄을 할 일 조건(m·r·rank)대로 센다. 현장 토벌 기록은 그대로 센다.
-- ② 퀘스트 칸(world_quest_board): 받을 수 있는 퀘스트 카드는 이름·요약·지역·레벨만 쓰므로 할 일·넘길 물품 계산을 뺀다(진행 중인 것은 그대로)
-- ③ 완전 답사 수(world_survey_full_count): 내가 하나라도 찾은 지역만 센다(아무것도 못 찾은 지역은 완전 답사일 수 없어 결과는 같다)

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

-- ① 원정 일지 승리 줄에 요괴·등급·지역
select pg_temp.yh_patch('public.world_expedition_settle(uuid,integer)',
  $o$'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id,$o$,
  $o$'kind', case when won then 'win' else 'lose' end, 'who', me, 'owner', e.owner_id, 'mid', m.monster_id, 'rank', case when m.role = 'guardian' then 'guardian' else 'normal' end, 'rg', r.region_id,$o$);

create or replace function public.world_exp_win_count(p_uid uuid, p_task jsonb, p_since timestamptz)
returns int language plpgsql stable security definer set search_path = pg_catalog, public as $f$
begin
  if p_uid is null or p_since is null then return 0; end if;
  return (select count(*)::int from public.world_expeditions x, jsonb_array_elements(coalesce(x.journal, '[]'::jsonb)) j
    where x.owner_id = p_uid and x.started_at >= p_since - interval '9 hours'
      and j ->> 'kind' = 'win' and j ? 'mid' and j ->> 'owner' = p_uid::text and (j ->> 'at')::timestamptz >= p_since
      and (not p_task ? 'm' or j ->> 'mid' in (select jsonb_array_elements_text(p_task -> 'm')))
      and (not p_task ? 'r' or j ->> 'rg' in (select jsonb_array_elements_text(p_task -> 'r')))
      and (not p_task ? 'rank' or j ->> 'rank' = p_task ->> 'rank'));
end $f$;
alter function public.world_exp_win_count(uuid, jsonb, timestamptz) owner to fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_exp_win_count(uuid, jsonb, timestamptz) from public, anon, authenticated;
reset role;

select pg_temp.yh_patch('public.world_quest_task_count(uuid,jsonb,timestamp with time zone)',
  $o$    when p_task ->> 't' in ('win', 'gather', 'craft', 'fish') then ($o$,
  $o$    when p_task ->> 't' = 'win' then (select count(*)::int from public.world_events e
     where e.actor_id = p_uid and e.created_at >= p_since and e.event_type = 'combat' and coalesce((e.payload ->> 'defeated')::boolean, false)
       and (not p_task ? 'm' or e.payload ->> 'monster_id' in (select jsonb_array_elements_text(p_task -> 'm')))
       and (not p_task ? 'r' or e.payload ->> 'region_id' in (select jsonb_array_elements_text(p_task -> 'r')))
       and (not p_task ? 'rank' or e.payload ->> 'rank' = p_task ->> 'rank')) + public.world_exp_win_count(p_uid, p_task, p_since)
    when p_task ->> 't' in ('win', 'gather', 'craft', 'fish') then ($o$);
select pg_temp.yh_patch('public.world_faction_task_count(uuid,jsonb,timestamp with time zone)',
  $o$else (select count(*) from ok)::int end$o$,
  $o$else (select count(*) from ok)::int + case when p_task ->> 't' = 'win' and not p_task ? 'phase' and not p_task ? 'weather' then public.world_exp_win_count(p_uid, p_task, p_since) else 0 end end$o$);

-- ② 받을 수 있는 퀘스트는 할 일 계산을 하지 않는다
select pg_temp.yh_patch('public.world_quest_board()',
  $o$        st := public.world_quest_step_state(uid, q.quest_id);
        avail := avail || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
          'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id) || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));$o$,
  $o$        avail := avail || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
          'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id, 'steps', nsteps);$o$);

-- ③ 완전 답사 수: 내가 찾은 것이 있는 지역만
create or replace function public.world_survey_full_count(p_owner uuid)
returns int language plpgsql stable set search_path = pg_catalog, public as $f$
begin
  return (with dr as materialized (
           select x.region_id from public.world_exploration_discoveries d join public.world_exploration_nodes x on x.node_id = d.node_id where d.owner_id = p_owner
           union select y.region_id from public.world_gathering_discoveries d join public.world_gathering_spots g on g.spot_id = d.spot_id join public.world_exploration_nodes y on y.node_id = g.node_id where d.owner_id = p_owner),
       n as (select x.region_id, count(*) t, count(d.node_id) f from public.world_exploration_nodes x
               left join public.world_exploration_discoveries d on d.node_id = x.node_id and d.owner_id = p_owner
              where x.hierarchy_level >= 2 and x.region_id in (select region_id from dr) group by 1),
       s as (select y.region_id, count(*) t, count(d.spot_id) f from public.world_gathering_spots x
               join public.world_exploration_nodes y on y.node_id = x.node_id
               left join public.world_gathering_discoveries d on d.spot_id = x.spot_id and d.owner_id = p_owner
              where x.active and y.region_id in (select region_id from dr) group by 1)
  select count(*)::int from public.world_map_regions r
    left join n on n.region_id = r.region_id left join s on s.region_id = r.region_id
   where r.active and not coalesce(r.is_safe_zone, false) and r.region_id in (select region_id from dr)
     and coalesce(n.t, 0) + coalesce(s.t, 0) > 0
     and coalesce(n.f, 0) + coalesce(s.f, 0) >= coalesce(n.t, 0) + coalesce(s.t, 0));
end $f$;

-- 패치노트: 7.2.0 본문 맨 아래에 덧붙임(공지 없이)
update public.world_patch_notes set body = body || $n$

## 7.2.6
- 원정에서 물리친 요괴도 퀘스트·세력 퀘스트의 「요괴 물리치기」 할 일에 셉니다(이번 패치 뒤 원정에서 물리친 요괴부터, 할 일을 받은 뒤 물리친 것).
- 퀘스트 칸·칭호 화면을 여는 계산을 더 가볍게 했습니다.
$n$ where note_id = '7.2.0' and position('## 7.2.6' in body) = 0;

update public.world_app_meta set value = '20261103050000' where key = 'db_version';
