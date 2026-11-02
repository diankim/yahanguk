-- 1.0.0e — 오픈 직전 GM 점검에서 나온 것
--  ① 1장 첫 퀘스트가 장서각 지하서고(Lv2)·폐쇄 사당(Lv2)으로 보내는데 Lv1이면 못 들어가 진행이 막히던 것:
--     두 지역을 Lv1로(지역·답사 지점·채집터·원정지·요괴·그 지역 보조 퀘스트 sq_를 한 칸 내림, 직업·소속 퀘스트는 그대로)
lock table public.world_characters in access exclusive mode;

create temp table yh_lvshift(region_id text primary key, d int) on commit drop;
insert into yh_lvshift values ('hq_archive', -1), ('shrine_ruins', -1);
update public.world_map_regions r set min_level = greatest(1, r.min_level + x.d) from yh_lvshift x where x.region_id = r.region_id;
update public.world_exploration_nodes n set min_level = greatest(1, n.min_level + x.d) from yh_lvshift x where x.region_id = n.region_id;
update public.world_gathering_spots g set min_level = greatest(1, g.min_level + x.d)
  from public.world_exploration_nodes n, yh_lvshift x where n.node_id = g.node_id and x.region_id = n.region_id;
update public.world_expedition_grounds e set min_level = greatest(1, e.min_level + x.d) from yh_lvshift x where x.region_id = e.region_id;
update public.world_region_monsters m set
    hp = round(m.hp * (70 + greatest(1, m.min_level + x.d) * 14.0) / (70 + m.min_level * 14.0)),
    attack_power = round(m.attack_power * (8 + greatest(1, m.min_level + x.d) * 1.1) / (8 + m.min_level * 1.1)),
    min_level = greatest(1, m.min_level + x.d), max_level = greatest(1, m.max_level + x.d)
  from yh_lvshift x where x.region_id = m.region_id;
update public.world_quest_steps s set reward = s.reward
      || case when s.reward ? 'xp' then jsonb_build_object('xp', round((s.reward ->> 'xp')::numeric * (100 * greatest(1, q.min_level + x.d) + 12 * greatest(1, q.min_level + x.d) ^ 2) / (100 * q.min_level + 12 * q.min_level ^ 2))::int) else '{}'::jsonb end
      || case when s.reward ? 'gil' then jsonb_build_object('gil', round((s.reward ->> 'gil')::numeric * (5 + 4 * greatest(1, q.min_level + x.d)) / (5 + 4 * q.min_level))::int) else '{}'::jsonb end
  from public.world_quests q, yh_lvshift x
 where q.quest_id = s.quest_id and q.region_id = x.region_id and q.quest_id like 'sq\_%' and s.reward is not null and s.reward <> '{}'::jsonb;
update public.world_quests q set min_level = greatest(1, q.min_level + x.d) from yh_lvshift x where x.region_id = q.region_id and q.quest_id like 'sq\_%';

update public.world_app_meta set value = '20261105040000' where key = 'db_version';
