-- 장비 능력치 조건: 낮은 레벨이 높은 단계 장비를 거래로 얻어 끼고 약한 요괴를 쓸어 버리지 못하게(양학 방지),
-- 장착 레벨에 맞는 주 능력치를 요구한다. 레벨마다 능력치 포인트 3점을 받으므로 레벨 L에서 쓸 수 있는 포인트는 3×(L−1)점이다.
-- - 무기·방어구: 5 + 0.35 × 3 × (장착 레벨 − 1)  → Lv.5 9 · Lv.10 14 · Lv.15 20 · Lv.20 25 (그 갈래의 주 능력치에 35%를 투자하면 맞춘다)
-- - 관모·신·노리개·호신부·탈·채집 도구: 5 + 0.25 × 3 × (장착 레벨 − 1) → Lv.5 8 · Lv.10 12 · Lv.15 16 · Lv.20 19
-- - 주 능력치: 무기 근접 근력 · 원거리 민첩 · 술법 영성 / 방어구 쇠미늘·옛 갑옷 체질 · 철릭·야행복 민첩 · 도포·법의 의지
--   관모 수호 체질 · 침착 의지 · 지혜 감각 / 신 몸놀림 민첩 · 그 밖 체질 / 노리개 행운 영성 · 예리 감각 · 풍요 체질
--   호신부 술법 영성 · 그 밖 의지 / 탈 은신 민첩 · 위엄 근력 · 귀신 영성 / 채집 도구 감각
-- - 이미 있던 조건이 더 높으면 그대로 둔다(예: 월식도 근력 8, 호신 도포 의지·영성 7). 기준이 5 이하(Lv.1 장비)면 조건을 붙이지 않는다.
-- - 지금 장착 중인 장비 중 이 기준에 걸리는 것은 없다(적용 전 확인). 레벨과 능력치는 내려가지 않으므로 장착할 때 한 번 검사하면 된다.
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

with m as (
  select i.item_id,
    case
      when i.category = 'weapon' then case i.equipment_traits->>'weapon_type' when 'ranged' then 'agility' when 'magic' then 'spirit_affinity' else 'strength' end
      when i.category = 'armor' then case when i.item_id ~ '_(light|shade)$' then 'agility' when i.item_id ~ '_robe$' or i.item_id = 'spirit_mail' then 'willpower' else 'vitality' end
      when i.category = 'hat' then case when i.item_id ~ '_calm$' then 'willpower' when i.item_id ~ '_wise$' then 'perception' else 'vitality' end
      when i.category = 'shoes' then case when i.item_id ~ '_swift$' then 'agility' else 'vitality' end
      when i.category = 'norigae' then case when i.item_id ~ '_luck$' then 'spirit_affinity' when i.item_id ~ '_keen$' then 'perception' else 'vitality' end
      when i.category = 'amulet' then case when i.item_id ~ '_spell$' then 'spirit_affinity' else 'willpower' end
      when i.category = 'mask' then case when i.item_id ~ '_hide$' then 'agility' when i.item_id ~ '_awe$' then 'strength' else 'spirit_affinity' end
      when i.category = 'tool' and i.item_id ~ '^t[2-5]_gather$' then 'perception'
    end as stat,
    (5 + round(case when i.category in ('weapon', 'armor') then 0.35 else 0.25 end * 3 * (coalesce(i.minimum_level, 1) - 1)))::int as need
  from public.world_item_catalog i
  where i.category in ('weapon', 'armor', 'hat', 'shoes', 'norigae', 'amulet', 'mask', 'tool')
)
update public.world_item_catalog i
   set required_stats = coalesce(i.required_stats, '{}'::jsonb) || jsonb_build_object(m.stat, greatest(m.need, coalesce((i.required_stats ->> m.stat)::int, 0)))
  from m
 where m.item_id = i.item_id and m.stat is not null and m.need > 5
   and coalesce((i.required_stats ->> m.stat)::int, 0) < m.need;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261027234000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select category, minimum_level, required_stats, count(*) from public.world_item_catalog
 where required_stats is not null and required_stats <> '{}'::jsonb group by 1, 2, 3 order by 1, 2 limit 60;
