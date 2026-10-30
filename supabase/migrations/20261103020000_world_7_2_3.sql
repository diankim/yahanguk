-- 7.2.3 점검 묶음
-- ① 대화 보관 3일 → 2일(전체·지역·세력 채팅·귓속말·모임·파티). 매일 04:13 KST world_housekeeping이 지운다.
create or replace function public.world_housekeeping()
returns jsonb language plpgsql security definer set search_path = pg_catalog, public as $$
declare a int; b int; c int; t int; m int; p int;
begin
  delete from public.world_notifications where read_at is not null and read_at < now() - interval '14 days';
  get diagnostics a = row_count;
  delete from public.world_chat_messages where created_at < now() - interval '2 days';
  get diagnostics b = row_count;
  delete from public.world_circle_messages where created_at < now() - interval '2 days';
  get diagnostics m = row_count;
  delete from public.world_party_messages where created_at < now() - interval '2 days';
  get diagnostics p = row_count;
  delete from public.world_economy_ledger where created_at < now() - interval '60 days';
  get diagnostics c = row_count;
  delete from public.world_hidden_trails where expires_at < now() - interval '1 day';
  get diagnostics t = row_count;
  perform public.world_letter_prune(x.recipient_id) from (select distinct recipient_id from public.world_letters where not pinned and created_at < now() - interval '3 days') x;
  delete from public.world_letter_sends where day < (now() at time zone 'Asia/Seoul')::date - 2;
  return jsonb_build_object('notifications', a, 'chat', b, 'circle', m, 'party', p, 'ledger', c, 'trails', t);
end $$;

-- ② 지도: 영향력이 없는 기본 지도(본래 주인)에서 세력 땅·중립 직할령이 다른 칸에 끊기지 않게, 세력마다 레벨 구간(1~5·6~10·11~15·16~20)이 다 있게
--  · 흑조 균열(Lv20) → 남명회: 이웃이 잔불촌·불씨 고개·혈엽림. 남명회에 없던 16~20 구간(흑련회는 지맥의 뿌리 Lv17이 남음)
--  · 옥문 협로(Lv10) → 천명원: 이웃이 물시계 터·별바라기 언덕. 별바라기 언덕도 천명원 본토와 이어진다
--  · 회산 관문(Lv7) → 정통파: 정통파의 6~10 구간(북령맹은 철벽 고찰 Lv9가 남음)
--  · 칸 자리만 맞바꿈(소속·레벨·길 연결은 그대로): 구룡 폐수로 ↔ 귀죽림, 서문 폐성벽 ↔ 회산 관문 — 중립 직할령 여덟 곳이 한 덩어리가 된다
--  쌓인 영향력은 그대로 두고, 새 주인의 기본 150으로 지배가 바로 넘어간다(옮긴 곳들은 그 세력 영향력이 150 아래)
update public.world_map_regions m set home_faction_id = x.f, control_faction_id = x.f, faction_control = public.world_mf_name(x.f), contested = false,
       territory_id = x.t, territory_name = (select territory_name from public.world_map_regions o where o.territory_id = x.t and o.region_id <> m.region_id limit 1)
  from (values ('black_tide_rift', 'southern_remnant', 'south'), ('jade_pass', 'mandate_court', 'heavenward'), ('ash_mountain', 'night_office', 'capital')) as x(r, f, t)
 where m.region_id = x.r;
update public.world_map_regions set world_x = 408, world_y = 286 where region_id = 'old_canal';
update public.world_map_regions set world_x = 418, world_y = 420 where region_id = 'ghost_bamboo';
update public.world_map_regions set world_x = 355, world_y = 215 where region_id = 'west_gate';
update public.world_map_regions set world_x = 335, world_y = 312 where region_id = 'ash_mountain';
--  정통파 본토 다섯 곳의 세력 이름이 「야행국」으로 남아 범례에 정통파가 보이지 않던 것
update public.world_map_regions set faction_control = '야행국 정통파'
 where control_faction_id = 'night_office' and faction_control = '야행국';

-- ③ 서버 부담: 탐색 한 번에 드는 시간의 대부분이던 꾸미기·칭호의 「완전 답사」 계산을 줄인다(결과는 같고 셈만 바꿈)
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

--  완전 답사한 지역 수: 지역마다 world_field_survey를 부르던 것(48번)을 질의 하나로. 기준은 같다(답사 길 2단계 이상 + 쓰는 채집터를 모두 찾음, 안전지대 제외)
create or replace function public.world_survey_full_count(p_owner uuid)
returns int language sql stable set search_path = pg_catalog, public as $f$
  with n as (select x.region_id, count(*) t, count(d.node_id) f from public.world_exploration_nodes x
               left join public.world_exploration_discoveries d on d.node_id = x.node_id and d.owner_id = p_owner
              where x.hierarchy_level >= 2 group by 1),
       s as (select y.region_id, count(*) t, count(d.spot_id) f from public.world_gathering_spots x
               join public.world_exploration_nodes y on y.node_id = x.node_id
               left join public.world_gathering_discoveries d on d.spot_id = x.spot_id and d.owner_id = p_owner
              where x.active group by 1)
  select count(*)::int from public.world_map_regions r
    left join n on n.region_id = r.region_id left join s on s.region_id = r.region_id
   where r.active and not coalesce(r.is_safe_zone, false)
     and coalesce(n.t, 0) + coalesce(s.t, 0) > 0
     and coalesce(n.f, 0) + coalesce(s.f, 0) >= coalesce(n.t, 0) + coalesce(s.t, 0)
$f$;
alter function public.world_survey_full_count(uuid) owner to fn_owner_field;
set role fn_owner_field;
revoke all on function public.world_survey_full_count(uuid) from public, anon, authenticated;
reset role;

select pg_temp.yh_patch('public.world_title_rule_ok(uuid,jsonb)',
  'WHERE r.active AND NOT coalesce(r.is_safe_zone, false) AND coalesce((public.world_field_survey(p_owner, r.region_id) ->> ''pct'')::int, 0) >= 100;',
  'WHERE false; v := public.world_survey_full_count(p_owner);');
select pg_temp.yh_patch('public.world_title_rule_progress(uuid,jsonb)',
  'where r.active and not coalesce(r.is_safe_zone, false) and coalesce((public.world_field_survey(p_owner, r.region_id) ->> ''pct'')::int, 0) >= 100;',
  'where false; v := public.world_survey_full_count(p_owner);');

--  꾸미기 판정: 답사 규칙(완전 답사·길·채집터 수)은 칭호 판정처럼 탐색에서 길·채집터를 찾았을 때와 원정 귀환 때만 센다(전에는 탐색마다)
select pg_temp.yh_patch('public.world_cosmetic_award_check(uuid,text)',
  'declare t record; got int := 0; r jsonb; kname text;',
  'declare t record; got int := 0; r jsonb; kname text; last_outcome text := case when p_event_type = ''explore'' then (select e.payload ->> ''outcome'' from public.world_events e where e.actor_id = p_owner order by e.created_at desc, e.id desc limit 1) end;');
select pg_temp.yh_patch('public.world_cosmetic_award_check(uuid,text)',
  'if (r ? ''survey_full'' or r ? ''nodes'' or r ? ''spots'') and p_event_type not in (''explore'', ''expedition_end'') then continue; end if;',
  'if (r ? ''survey_full'' or r ? ''nodes'' or r ? ''spots'') and p_event_type <> ''expedition_end'' and not (p_event_type = ''explore'' and last_outcome in (''path'', ''spot'')) then continue; end if;');

--  날씨·시간대 효과: 환경 표의 줄마다 날씨·시간대·영역을 다시 계산하던 것을 한 번만(효과를 쓰는 모든 계산이 함께 빨라짐)
create or replace function public.world_env_total(p_owner uuid, p_key text)
returns numeric language sql stable security definer set search_path = pg_catalog, public as $f$
  select coalesce(sum(case when (e.effects ->> p_key) ~ '^-?[0-9]+(\.[0-9]+)?$' then (e.effects ->> p_key)::numeric else 0 end), 0)
    from (select public.world_time_phase(now()) tp, public.world_weather_key(public.world_owner_territory(p_owner), now()) wk where p_owner is not null) k
    join public.world_environment_catalog e on e.env_key in (k.tp, k.wk)
$f$;

update public.world_app_meta set value = '20261103020000' where key = 'db_version';
