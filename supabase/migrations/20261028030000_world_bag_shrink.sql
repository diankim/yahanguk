-- 가방 칸 줄이기: 같은 물품이 한 칸에 묶음으로 쌓이게 되어(20261028020000) 가방이 너무 넉넉해졌다.
-- 기본 칸부터 얻는 칸까지 같은 비율로 줄인다.
-- - 새 캐릭터 기본 60 → 24칸
-- - 이야기 장 해결 +10 → +3 · 「아홉 개의 문」 +20 → +5 · 붉은 인장 사건 +20 → +5
-- - 지역 답사 보고서 +20 → +4 · 지역 완전 답사 +1(그대로, 옛 원정 귀환 함수의 +5도 +1로 맞춘다)
-- - 수향연맹 소속 +20 → +6
-- - 이미 있는 캐릭터: 24 + (지금 칸 − 60) × 0.3 (반올림, 적어도 24). 한 번만 적용한다(world_app_meta 'bag_shrink_20261028').
--   지금 쓰는 칸보다 줄어드는 캐릭터는 없다(적용 전 확인: 가장 많이 쓴 캐릭터 29칸 → 새 한도 36칸).
--   한도를 넘더라도 가진 물품은 사라지지 않고, 새로 얻는 것만 막힌다.
-- - 칭호 「수집광」(가방 120칸) → 가방 45칸
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

alter table public.world_characters alter column bag_capacity set default 24;

do $$
begin
  if not exists (select 1 from public.world_app_meta where key = 'bag_shrink_20261028') then
    update public.world_characters set bag_capacity = greatest(24, 24 + round((bag_capacity - 60) * 0.3)::int);
    insert into public.world_app_meta(key, value, changed_at) values ('bag_shrink_20261028', 'done', now());
  end if;
end $$;

-- 이야기 장 보상
update public.world_story_chapters
   set rewards = jsonb_set(rewards, '{bag}', to_jsonb(case when (rewards ->> 'bag')::int >= 20 then 5 else 3 end))
               || jsonb_build_object('text', replace(replace(rewards ->> 'text', '가방 +20칸', '가방 +5칸'), '가방 +10칸', '가방 +3칸'))
 where (rewards ->> 'bag')::int in (10, 20);
update public.world_story_chapters set rewards = rewards || jsonb_build_object('text', replace(rewards ->> 'text', '가방 +20칸', '가방 +5칸'))
 where chapter_id = 'red_seal' and rewards ->> 'text' like '%가방 +20칸%';

update public.world_title_catalog set rule = jsonb_set(rule, '{n}', '45'), condition_text = '가방 45칸'
 where title_key = 'hoarder' and (rule ->> 'n')::int = 120;

-- 함수 안의 칸 수 바꾸기
grant fn_owner_expedition to postgres with inherit true;
do $$
declare f text; d text; n text;
begin
  -- 수향연맹 +20 → +6 (가방 한도를 계산하는 모든 곳)
  foreach f in array array['world_bag_limit', 'world_enforce_bag_capacity', 'world_trade_direct_respond', 'world_expedition_complete', 'world_bond_gift'] loop
    d := pg_get_functiondef(('public.' || f)::regproc);
    n := regexp_replace(d, $r$(river_alliance'\s+then\s+)20(\s+else\s+0)$r$, '\16\2', 'gi');
    if n <> d then execute n; end if;
  end loop;

  -- 지역 답사 보고서 +20 → +4(첫 번째), 붉은 인장 사건 +20 → +5(두 번째)
  d := pg_get_functiondef('public.world_reward_case_resolution'::regproc);
  if position('bag_capacity + 20' in d) > 0 then
    n := regexp_replace(d, 'bag_capacity \+ 20\)', 'bag_capacity + 4)');          -- 'g' 없이: 첫 번째만
    n := regexp_replace(n, 'bag_capacity \+ 20\)', 'bag_capacity + 5)');
    n := replace(n, '가방 용량이 20칸 늘었습니다.', '가방 용량이 4칸 늘었습니다.');
    n := replace(n, '가방 용량이 20칸 늘고,', '가방 용량이 5칸 늘고,');
    execute n;
  end if;

  -- 옛 원정 귀환 함수의 완전 답사 +5 → +1(새 함수와 같게)
  d := pg_get_functiondef('public.world_expedition_finish'::regproc);
  if position('bag_capacity + 5)' in d) > 0 then
    execute replace(replace(d, 'bag_capacity + 5)', 'bag_capacity + 1)'), '가방 용량 +5', '가방 용량 +1');
  end if;
end $$;
grant fn_owner_expedition to postgres with inherit false;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028030000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select (select string_agg(bag_capacity::text, ', ' order by bag_capacity desc) from public.world_characters) as bags,
       (select string_agg(chapter_id || ' +' || (rewards ->> 'bag'), ', ') from public.world_story_chapters where rewards ? 'bag') as story,
       (select count(*) from pg_proc where prokind = 'f' and pronamespace = 'public'::regnamespace and pg_get_functiondef(oid) ~* $r$river_alliance'\s+then\s+20$r$) as river_left;
