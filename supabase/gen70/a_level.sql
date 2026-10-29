-- ─────────────────────────────────────────────────────────────
-- A. 만렙 40 · 쌓아 둘 능력치 포인트 117 · 기술 30단계부터 가파르게 · 깊이별 레벨 되살림
-- ─────────────────────────────────────────────────────────────

-- 함수 본문 고치기 도우미: 고칠 자리(old)가 정확히 n번 있어야 바꾼다. 이미 바뀌어 있으면 건너뛴다.
create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not pg_has_role('postgres', o, 'usage') then execute format('grant %I to postgres with inherit true, set true', o); end if;
  execute replace(d, p_old, p_new);
end $$;

select pg_temp.yh_patch('public.world_event_char_apply()', 'nl >= 30', 'nl >= 40', 2);
select pg_temp.yh_patch('public.world_event_char_apply()', 'nl < 30', 'nl < 40', 2);
select pg_temp.yh_patch('public.world_event_char_apply()', 'level = least(30, nl)', 'level = least(40, nl)');
select pg_temp.yh_patch('public.world_event_char_apply()', 'least(87, stat_points + gained * 3)', 'least(117, stat_points + gained * 3)');
-- 탐색 한 번 추적 경험 8 → 5(기술 50단계를 늦춤)
select pg_temp.yh_patch('public.world_event_char_apply()', 'when ''craft'' then 12 when ''explore'' then 8 when', 'when ''craft'' then 12 when ''explore'' then 5 when');

select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'lv < 30', 'lv < 40');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'lv >= 30', 'lv >= 40');
select pg_temp.yh_patch('public.world_grant_xp(uuid,integer)', 'least(87,', 'least(117,');

select pg_temp.yh_patch('public.world_claim_idle_activity()', 'c.level>=30', 'c.level>=40');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level<30', 'v_new_level<40', 2);
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'v_new_level>=30', 'v_new_level>=40');
select pg_temp.yh_patch('public.world_claim_idle_activity()', 'least(87,', 'least(117,');
select pg_temp.yh_patch('public.world_claim_idle_activity()', '''level_cap'',30', '''level_cap'',40');

select pg_temp.yh_patch('public.world_expedition_gear(integer)', 'least(30, p_level)', 'least(40, p_level)');

-- 기술 단계: r → r+1에 80+8r, 30단계부터 6×(r−29)²를 더한다.
-- 누적 경험(단계 R에 닿는 데) = 4R²+76R−80 + n(n+1)(2n+1) (n = R−30, 30 아래는 0) — 30단계 5,800 · 40단계 11,670 · 50단계 30,940
create or replace function public.world_skill_line_xp(p_rank integer) returns integer
language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select 4 * greatest(1, p_rank) * greatest(1, p_rank) + 76 * greatest(1, p_rank) - 80
       + greatest(0, p_rank - 30) * (greatest(0, p_rank - 30) + 1) * (2 * greatest(0, p_rank - 30) + 1)
$$;
create or replace function public.world_skill_line_rank(p_xp integer) returns integer
language sql immutable set search_path to 'pg_catalog', 'public' as $$
  select case when coalesce(p_xp, 0) < 5800
              then least(30, greatest(1, floor((-76 + sqrt(5776 + 16 * (80 + greatest(0, coalesce(p_xp, 0))))::numeric) / 8)::int))
              else (select max(r) from generate_series(30, 50) r where public.world_skill_line_xp(r) <= p_xp) end
$$;

-- 지금 단계를 적어 두고 모두 다시 매긴 뒤 내려간 사람에게 알린다(경험은 그대로)
create temp table yh_old_ranks on commit drop as
  select c.owner_id, s.key, coalesce((s.value ->> 'rank')::int, 1) old_rank
    from public.world_characters c, jsonb_each(coalesce(c.skill_progress, '{}'::jsonb)) s where jsonb_typeof(s.value) = 'object';
select set_config('yh.rank_sync', 'all', true);
update public.world_characters set skill_progress = skill_progress where skill_progress is not null and skill_progress <> '{}'::jsonb;
select set_config('yh.rank_sync', '', true);
insert into public.world_notifications(user_id, kind, title, content, payload)
select o.owner_id, 'skill_rerank', '기술 단계가 다시 매겨졌습니다',
       '7.0에서 기술 30단계부터 필요한 경험이 늘어 단계를 다시 매겼습니다(쌓은 경험은 그대로입니다): '
       || string_agg(coalesce(nullif(k.n, ''), o.key) || ' ' || o.old_rank || '→' || n.new_rank, ' · ' order by o.key)
       || '. 다시 오르면 그 단계 기술도 곧바로 살아납니다(고른 택일 기술은 그대로).',
       jsonb_build_object('changes', jsonb_object_agg(o.key, jsonb_build_array(o.old_rank, n.new_rank)))
  from yh_old_ranks o
  join lateral (select coalesce((c.skill_progress -> o.key ->> 'rank')::int, 1) new_rank from public.world_characters c where c.owner_id = o.owner_id) n on true
  left join lateral (select case o.key when 'melee' then '근접' when 'ranged' then '원거리' when 'sealing' then '봉인술' when 'analysis' then '분석' when 'guarding' then '막기'
       when 'first_aid' then '응급 처치' when 'foraging' then '일반 채집' when 'herbalism' then '약초 채집' when 'mining' then '광맥 채집' when 'spirit_gathering' then '영기 채집'
       when 'smithing' then '단조' when 'alchemy' then '연금' when 'wardcraft' then '결계 각인' when 'tracking' then '추적' else '' end n) k on true
 where n.new_rank < o.old_rank
 group by o.owner_id;

-- 깊이별 레벨 되살림(4.0.4에서 최고 레벨 30으로 묶었던 구중 봉연·무극 관성대): 지역 레벨 + 깊이마다 2
update public.world_exploration_nodes n set min_level = least(40, r.min_level + greatest(0, n.hierarchy_level - 2) * 2)
  from public.world_map_regions r where r.region_id = n.region_id and r.region_id in ('sealed_abyss', 'star_observatory');
update public.world_gathering_spots s set min_level = n.min_level
  from public.world_exploration_nodes n where n.node_id = s.node_id and n.region_id in ('sealed_abyss', 'star_observatory') and s.spot_name not like '어귀의 %';
update public.world_expedition_grounds g set min_level = least(40, r.min_level + (g.depth - 1) * 2)
  from public.world_map_regions r where r.region_id = g.region_id and r.region_id in ('sealed_abyss', 'star_observatory');
