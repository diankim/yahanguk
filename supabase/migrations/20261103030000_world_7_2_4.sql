-- 7.2.4 서버 부담 줄이기(결과는 같고 셈만 바꿈)
-- ① 퀘스트 판(world_quest_board): 퀘스트마다·앞 퀘스트마다 「마쳤는가」를 다시 묻던 것(퀘스트 124개 × 최대 3번)을 처음 한 번만 모아 쓴다
-- ② 세계 지도(world_map_snapshot): 지역마다 답사 기록을 11번·지역 소개를 9번·귀허도 열림을 두 번 읽던 것을 한 번씩만

create or replace function pg_temp.yh_owner_set(p_fn text) returns void language plpgsql as $f$
declare o text := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
begin
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
end $f$;
select pg_temp.yh_owner_set('public.world_quest_board()');

create or replace function public.world_quest_board()
 returns jsonb language plpgsql security definer set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid := public.fn_owner_auth_uid(); c public.world_characters%rowtype; q record; st jsonb; act jsonb := '[]'::jsonb; avail jsonb := '[]'::jsonb;
  here_id text; ok boolean; nsteps int; clues jsonb; ndone int := 0; ntotal int := 0; fac jsonb; dn text[];
begin
  if uid is null then raise exception '로그인이 필요합니다.'; end if;
  select * into c from public.world_characters where owner_id = uid;
  if not found then raise exception '캐릭터를 먼저 만드세요.'; end if;
  select region_id into here_id from public.world_map_regions where region_name = c.location limit 1;
  -- 마친 퀘스트를 한 번만 모은다(주 이야기는 장 마침, 그 밖은 done_at)
  dn := array(select x.quest_id from public.world_quests x where public.world_quest_done(uid, x.quest_id));
  for q in select x.*, g.step gstep, g.done_at, g.owner_id has_prog, m.region_name,
                  (select count(*) from public.world_quest_steps s where s.quest_id = x.quest_id) nst
             from public.world_quests x left join public.world_quest_progress g on g.quest_id = x.quest_id and g.owner_id = uid
             left join public.world_map_regions m on m.region_id = x.region_id
            where x.active and (x.job_key is null or x.job_key = c.job_key) and (x.faction_key is null or x.faction_key = c.faction_key) order by (x.kind = 'main') desc, x.min_level, x.sort, x.quest_id loop
    ntotal := ntotal + 1;
    if q.quest_id = any(dn) then ndone := ndone + 1; continue; end if;
    nsteps := q.nst;
    if q.has_prog is not null and coalesce(q.gstep, 0) >= 1 then
      if q.kind = 'main' and coalesce(q.gstep, 0) >= nsteps then
        -- 장면을 다 마친 주 이야기: 단서 찾기·가설 확정 단계
        select jsonb_build_object('found', count(*) filter (where exists (select 1 from public.world_case_progress p where p.owner_id = uid and p.case_id = k.chapter_id
                                     and p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id)))), 'total', count(*),
                 'regions', jsonb_agg(distinct k.region_id), 'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id)))
          into clues from public.world_story_clues k where k.chapter_id = q.chapter_id;
        act := act || jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'clues', 'clues', clues,
          'step', nsteps, 'steps', nsteps);
      else
        st := public.world_quest_step_state(uid, q.quest_id);
        act := act || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary, 'phase', 'step') || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
      end if;
    else
      -- 앞 퀘스트를 다 마쳤는가(q.after ⊆ dn)
      ok := c.level >= q.min_level and q.after <@ dn;
      -- 주 이야기는 앞 장을 마쳤으면 레벨이 모자라도 보인다(언제 열리는지 알려 준다)
      if ok or (q.kind = 'main' and q.after <@ dn) then
        st := public.world_quest_step_state(uid, q.quest_id);
        avail := avail || (jsonb_build_object('quest_id', q.quest_id, 'kind', q.kind, 'cat', q.cat, 'title', q.title, 'summary', q.summary,
          'region_id', q.region_id, 'region_name', q.region_name, 'min_level', q.min_level, 'locked', not ok, 'here', q.region_id = here_id) || coalesce(st, '{}'::jsonb) || jsonb_build_object('title', q.title, 'step_title', st ->> 'title'));
      end if;
    end if;
  end loop;
  -- 세력 퀘스트(가입·등급)도 현장 퀘스트 칸에 함께 보인다. 열람만 하므로 등급 장면을 열지(쓰지) 않는다
  if c.major_faction_id is not null and exists (select 1 from public.world_faction_progress p where p.owner_id = uid and p.faction_id = c.major_faction_id and not p.rejoin_pending) then
    fac := public.world_faction_current(uid, false);
    if fac is not null then
      fac := fac || jsonb_build_object('faction_id', c.major_faction_id,
        'regions', (select coalesce(jsonb_agg(distinct x), '[]'::jsonb) from public.world_faction_scenes s,
                      lateral (select jsonb_array_elements_text(t -> 'r') x from jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
                               union select jsonb_array_elements_text(coalesce(s.need -> 'at', '[]'::jsonb))) z
                     where s.scene_key = fac ->> 'scene_key'));
    end if;
  end if;
  return jsonb_build_object('active', act, 'available', avail, 'faction', fac, 'done', ndone, 'total', ntotal, 'here_id', here_id, 'level', c.level);
end $function$;

create or replace function public.world_map_snapshot()
 returns jsonb language plpgsql set search_path to 'pg_catalog', 'public'
as $function$
declare uid uuid:=public.fn_owner_auth_uid(); c public.world_characters%rowtype; regions jsonb; current_region text; gw boolean; reach text[];
begin
 if uid is null then raise exception '로그인이 필요합니다.'; end if;
 select * into c from public.world_characters where owner_id=uid;
 select region_id into current_region from public.world_map_regions where region_name=c.location or region_id=c.location or (c.location in ('야행국 본부 · 정청','야행국 본부 정청','본부 로비') and region_id='hq_yard') limit 1;
 gw := public.world_gwiheo_open(uid);
 reach := coalesce((select x.travel_from from public.world_map_regions x where x.region_id=current_region),'{}');
 select coalesce(jsonb_agg(jsonb_build_object('region_id',r.region_id,'territory_id',r.territory_id,'territory_name',r.territory_name,'region_name',r.region_name,'region_type',r.region_type,'danger_level',r.danger_level,'min_level',r.min_level,'level_locked',coalesce(c.level,1)<r.min_level,
 'description',CASE WHEN v.n>0 THEN r.description ELSE '미답사 지역. 직접 방문하면 상세 정보가 공개됩니다.' END,
 'biome_name',CASE WHEN v.n>0 THEN p.biome_name ELSE '미확인 지형' END,
 'visual_identity',CASE WHEN v.n>0 THEN p.visual_identity ELSE NULL END,
 'survival_hazard',CASE WHEN v.n>=2 THEN p.survival_hazard ELSE NULL END,
 'signature_resources',CASE WHEN v.n>=2 THEN to_jsonb(p.signature_resources) ELSE '[]'::jsonb END,
 'signature_items',CASE WHEN coalesce(i.investigations_completed,0)>0 THEN to_jsonb(p.signature_items) ELSE '[]'::jsonb END,
 'signature_clue',CASE WHEN v.n>=3 THEN p.signature_clue ELSE NULL END,
 'signature_event',CASE WHEN v.n>0 THEN p.signature_event ELSE '미확인 사건 기록' END,
 'faction_style',CASE WHEN v.n>=2 THEN p.faction_style ELSE '현지 세력 미확인' END,
 'visits',v.n,
 'travel_discount',least(0.30,v.n*0.06),
 'travel_from',case when gw then r.travel_from else array(select x from unnest(r.travel_from) x where x not in ('banyo_village','ash_reeds','inverted_shrine','moonless_market','gwiheo_core')) end,'gather_nodes',r.gather_nodes,'faction_control',r.faction_control,'is_starting_area',r.is_starting_area,'world_x',r.world_x,'world_y',r.world_y,'elevation',r.elevation,'terrain_cost',r.terrain_cost,'rest_spot_type',r.rest_spot_type,'rest_spot_name',r.rest_spot_name,'rest_quality',r.rest_quality,'rest_fee',r.rest_fee,'rest_risk',r.rest_risk,'reachable',r.region_id=any(reach),'monsters',coalesce((select jsonb_agg(jsonb_build_object('monster_id',m.monster_id,'monster_name',m.monster_name,'min_level',m.min_level,'max_level',m.max_level,'description',m.description,'hp',m.hp,'attack_power',m.attack_power) order by m.min_level) from public.world_region_monsters m where m.region_id=r.region_id),'[]'::jsonb)) order by r.territory_id,r.world_y,r.world_x),'[]'::jsonb) into regions
   from public.world_map_regions r
   left join public.world_region_intel i on i.owner_id=uid and i.region_id=r.region_id
   left join public.world_region_profiles p on p.region_id=r.region_id
   cross join lateral (select coalesce(i.visits,0) n) v
  where r.active and (r.territory_id is distinct from 'gwiheo' or gw);
 return jsonb_build_object('regions',regions,'location',c.location,'level',c.level,'major_faction_id',c.major_faction_id,'faction_reputation',c.faction_reputation,'current_region_id',current_region);
end $function$;

-- 패치노트: 7.2.0 본문 맨 아래에 덧붙임(소수점 둘째 자리 패치는 공지 없이)
update public.world_patch_notes set body = body || $n$

## 7.2.4
- 서버 부담 줄이기: 세계 지도·퀘스트 칸을 여는 계산을 가볍게 했고, 능력치를 올릴 때 미리 보기는 + / − 를 다 누른 뒤 한 번만 묻습니다.
- 파티 채팅은 내 파티의 말만 받습니다(파티가 없으면 받지 않음).
- 합동 토벌·귀허의 주인·파티 토벌의 「전투 기록」이 비어 있을 때 글이 좁은 칸에 세로로 깨지던 것, 파티 토벌 기록이 좁게 보이던 것을 고쳤습니다.
- 현장 토벌·파티 토벌의 회복품 목록을 하나로 맞췄습니다.
$n$ where note_id = '7.2.0' and position('## 7.2.4' in body) = 0;

update public.world_app_meta set value = '20261103030000' where key = 'db_version';
