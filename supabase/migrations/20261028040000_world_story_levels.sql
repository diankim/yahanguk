-- 이야기를 최고 레벨(30)까지 잇기 + 경험치 곡선 + 레벨 상한 30
--
-- 1) 레벨 상한 100 → 30(지도·요괴·이야기가 30까지라 그 위는 비어 있었다). 능력치 포인트 상한도 3×29 = 87.
-- 2) 경험치 곡선: 다음 레벨까지 100×레벨 → 100×레벨 + 12×레벨².
--    지금 곡선은 요괴 경험치(12 + 6×요괴 레벨)도 같이 늘어 레벨마다 같은 레벨 요괴 약 15마리로 거의 일정했다(높은 레벨에서도 느려지지 않음).
--    바꾼 곡선은 Lv5 약 19마리 · Lv10 31 · Lv15 41 · Lv20 52 · Lv25 62 · Lv29 70마리로 점점 느려지고, Lv30까지 약 1,170마리(원정·이야기·의뢰 경험치 별도).
--    이미 쌓인 레벨과 경험치는 그대로 두고, 앞으로 오를 때만 새 곡선을 쓴다.
-- 3) 이야기: 5장(Lv15)과 마지막 장(Lv30) 사이에 네 장을 넣는다. 지금까지 이야기가 지나가지 않던 지역 13곳을 잇는다.
--    6장 「월식의 문」 Lv18 — 적월 교령(흑사단 폐단·적월교 월식성)과 북령 뇌명봉
--    7장 「물 밑의 등불」 Lv21 — 수향 연맹령(천엽 연화늪·수경루·용잠 수궁)
--    8장 「재의 바다」 Lv24 — 남명 망국령(재의 해안·주혈 광산·구등대 군도)
--    9장 「등잔 밑」 Lv27 — 야행국 직할령으로 돌아온다(잿빛 들녘·백지교·폐쇄된 연화원·귀죽림)
--    10장 「구중 봉연」 Lv30 — 지금의 마지막 장(6장 → 10장으로 번호만 옮긴다)
-- 4) 장 보상: 가방 칸은 1~5장에만 둔다(가방이 가장 빠듯한 초반, 묶음 도입 후 기본 24칸 + 1~5장 +17칸).
--    6장부터는 가방 칸 대신 능력치 포인트·고유 탈것·고유 장비·낙관·강화 재료를 준다(10장의 가방 +5도 바꾼다).
--    보상 물품이 가방에 안 들어가면 마지막 가설 확정을 막고 가방을 비우라고 알린다(고유 보상이 버려지지 않게).
-- SQL Editor에서 이 파일 전체를 한 번 실행한다. 다시 실행해도 결과가 같다.

/* ── 1·2) 경험치 곡선과 레벨 상한 ─────────────────────── */
create or replace function public.world_xp_need(p_level int)
returns int language sql immutable set search_path to 'pg_catalog', 'public'
as $$ select (100 * greatest(1, p_level) + 12 * greatest(1, p_level) * greatest(1, p_level))::int $$;
grant execute on function public.world_xp_need(int) to public;
revoke execute on function public.world_xp_need(int) from anon;

grant fn_owner_18473 to postgres with inherit true;
grant fn_owner_19181 to postgres with inherit true;
grant fn_owner_expedition to postgres with inherit true;
do $$
declare f text; d text; n text;
begin
  -- [함수, 바꿀 글, 새 글] — 바꿀 글이 없으면(이미 바꿨으면) 건너뛴다
  foreach f in array array['world_grant_xp', 'world_award_progression_from_event', 'world_claim_idle_activity', 'world_expedition_finish'] loop
    d := pg_get_functiondef(('public.' || f)::regproc);
    if position('world_xp_need' in d) > 0 then continue; end if;
    n := d;
    -- 일반 경험치(world_grant_xp)
    n := replace(n, 'WHILE lv < 100 AND xp >= lv * 100 LOOP xp := xp - lv * 100;', 'WHILE lv < 30 AND xp >= public.world_xp_need(lv) LOOP xp := xp - public.world_xp_need(lv);');
    n := replace(n, 'IF lv >= 100 THEN xp := 0; END IF;', 'IF lv >= 30 THEN xp := 0; END IF;');
    -- 행동 기록에서 주는 경험치
    n := replace(n, 'experience=case when level>=100 then 0 else experience+award end', 'experience=case when level>=30 then 0 else experience+award end');
    n := replace(n, 'if next_level<100 then', 'if next_level<30 then');
    n := replace(n, 'while next_level<100 and next_xp>=next_level*100 loop', 'while next_level<30 and next_xp>=public.world_xp_need(next_level) loop');
    n := replace(n, 'next_xp:=next_xp-next_level*100;', 'next_xp:=next_xp-public.world_xp_need(next_level);');
    n := replace(n, 'level=least(100,next_level),experience=case when next_level>=100 then 0', 'level=least(30,next_level),experience=case when next_level>=30 then 0');
    -- 자율 활동
    n := replace(n, 'case when c.level>=100 then 0', 'case when c.level>=30 then 0');
    n := replace(n, 'if v_new_level<100 then', 'if v_new_level<30 then');
    n := replace(n, 'while v_new_level<100 and v_xp>=v_new_level*100 loop v_xp:=v_xp-v_new_level*100;', 'while v_new_level<30 and v_xp>=public.world_xp_need(v_new_level) loop v_xp:=v_xp-public.world_xp_need(v_new_level);');
    n := replace(n, 'experience=case when v_new_level>=100 then 0', 'experience=case when v_new_level>=30 then 0');
    n := replace(n, '''level_cap'',100', '''level_cap'',30');
    -- 옛 원정 귀환
    n := replace(n, 'WHILE next_level < 100 AND next_xp >= next_level * 100 LOOP next_xp := next_xp - next_level * 100;', 'WHILE next_level < 30 AND next_xp >= public.world_xp_need(next_level) LOOP next_xp := next_xp - public.world_xp_need(next_level);');
    n := replace(n, 'IF next_level >= 100 THEN next_xp := 0; END IF;', 'IF next_level >= 30 THEN next_xp := 0; END IF;');
    n := replace(n, 'level = least(100, next_level)', 'level = least(30, next_level)');
    -- 능력치 포인트 상한
    n := replace(replace(n, 'least(297, ', 'least(87, '), 'least(297,', 'least(87,');
    if position('world_xp_need' in n) = 0 then raise exception '%: 경험치 줄을 찾지 못했습니다', f; end if;
    execute n;
  end loop;
end $$;
grant fn_owner_18473 to postgres with inherit false;
grant fn_owner_19181 to postgres with inherit false;
grant fn_owner_expedition to postgres with inherit false;

/* ── 3) 이야기 장 ─────────────────────────────────────── */
-- 마지막 장을 10장으로 옮기고 보상을 바꾼다(가방 +5 → 능력치 +3)
update public.world_story_chapters set seq = 10 where chapter_id = 'nine_gates' and seq <> 10;
update public.world_story_chapters
   set rewards = '{"xp": 3000, "gil": 6000, "stat": 3, "items": {"star_sand": 3, "spirit_core": 4}, "text": "경험치 3,000 · 6,000전 · 응축 영핵 4 · 성진사 3 · 능력치 포인트 +3"}'::jsonb,
       intro = '지맥의 뿌리, 흑조 균열, 백옥 천문탑, 그리고 구중 봉연. 남은 세 문과 마지막 문의 흔적을 모아, 붉은 인장을 품고 내려간 자보다 먼저 마지막 문을 닫아야 합니다.'
 where chapter_id = 'nine_gates' and rewards ? 'bag';

insert into public.world_story_chapters(chapter_id, seq, title, summary, intro, outro, min_level, rewards) values
('eclipse_gate', 6, '월식의 문', '종을 쫓아 적월교의 성채로 들어간다.',
 '종이 끌려간 뒤 적월교의 성채에서 달이 먹히는 밤이 이어지고 있습니다. 버려진 흑사단 폐단과 적월교 월식성, 그리고 벼락이 그치지 않는 북령의 뇌명봉에서 두 번째 문이 열린 흔적을 찾으세요.',
 '두 번째 문은 흑사단 전원의 이름을 바쳐 열렸습니다. 월식성의 거울에는 다음 문이 비쳤는데, 그 문은 물 밑에 잠겨 있었습니다.',
 18, '{"xp": 3500, "gil": 2500, "stat": 2, "items": {"steel_ingot": 3, "spirit_core": 1}, "text": "경험치 3,500 · 2,500전 · 강철 주괴 3 · 응축 영핵 · 능력치 포인트 +2"}'::jsonb),
('sunken_lantern', 7, '물 밑의 등불', '거울에 비친 물 밑의 문을 찾아 수향으로 간다.',
 '월식성의 거울에 비친 문은 수향의 물 밑에 있습니다. 천엽 연화늪의 연등이 물속으로 가라앉고, 수경루의 물시계가 거꾸로 흐르며, 용잠 수궁 깊은 곳에서 누군가 이름을 부르는 노래가 들린다고 합니다.',
 '세 번째 문은 용왕의 역린으로 잠겨 있었지만, 지워진 이름들의 노래가 열쇠를 돌렸습니다. 노래는 남쪽 바다 끝의 등대에서 흘러왔습니다. 수궁을 지키던 거북 한 마리가 당신을 따르기로 했습니다.',
 21, '{"xp": 4500, "gil": 3000, "mount": "lotus_turtle", "items": {"steel_ingot": 3, "spirit_core": 2}, "text": "경험치 4,500 · 3,000전 · 강철 주괴 3 · 응축 영핵 2 · 특별 탈것 연화 거북"}'::jsonb),
('ash_sea', 8, '재의 바다', '노래가 흘러온 남쪽 바다의 등대를 찾는다.',
 '남명 망국령의 바다는 망국의 마지막 날 재로 굳었습니다. 재의 해안과 주혈 광산, 아홉 등대가 선 구등대 군도에서 문이 열린 순서를 알아내야 합니다.',
 '아홉 등대는 아홉 문과 짝이었습니다. 흑련회가 등대를 하나씩 꺼 문을 열어 왔고, 이미 여섯째 문까지 열렸습니다. 그런데 등대를 끄라는 명령서에는 야행국 본부 정청의 인장이 찍혀 있었습니다. 마지막 등대지기는 꺼지지 않은 불씨를 노리개에 담아 건넸습니다.',
 24, '{"xp": 5500, "gil": 3500, "stat": 2, "items": {"n5_lighthouse": 1, "spirit_core": 2}, "text": "경험치 5,500 · 3,500전 · 응축 영핵 2 · 능력치 포인트 +2 · 고유 장비 구등대 등불 노리개"}'::jsonb),
('lamp_shadow', 9, '등잔 밑', '명령서의 인장을 쫓아 본부로 돌아온다.',
 '등대를 끄라는 명령은 야행국 안에서 내려졌습니다. 처음 길을 떠났던 잿빛 들녘과 백지교, 문을 닫아 둔 연화원, 귀신 대나무가 우는 귀죽림에 그 명령이 지나간 흔적이 남아 있습니다.',
 '흑련회의 뿌리는 본부의 연화원에 있었습니다. 스스로 이름을 지운 관리가 붉은 인장을 품고 구중 봉연으로 내려갔습니다. 남은 문은 셋, 그리고 마지막 문입니다.',
 27, '{"xp": 7000, "gil": 4500, "stat": 2, "items": {"steel_ingot": 4, "spirit_core": 3}, "text": "경험치 7,000 · 4,500전 · 강철 주괴 4 · 응축 영핵 3 · 능력치 포인트 +2 · 낙관 「燈」"}'::jsonb)
on conflict (chapter_id) do nothing;

insert into public.world_story_clues(clue_id, chapter_id, name, tag, region_id, description, sort) values
('eclipse_altar', 'eclipse_gate', '그을린 아홉 칸 제단', '의식', 'black_sand_temple', '제단 바닥에 아홉 칸 원이 그려져 있다. 두 칸만 검게 그을렸다.', 1),
('eclipse_roster', 'eclipse_gate', '흑사단 명부', '기록', 'black_sand_temple', '단원들의 이름이 모두 지워지고 「월식」 두 글자만 남았다.', 2),
('eclipse_mirror', 'eclipse_gate', '먹힌 달의 거울', '목격', 'red_moon_fort', '거울은 하늘의 달이 아니라 물 밑을 비춘다. 물속에 문 하나가 서 있다.', 3),
('eclipse_rod', 'eclipse_gate', '벼락 맞은 쇠막대', '물증', 'thunder_peak', '봉우리 꼭대기에 꽂힌 쇠막대. 벼락을 받아 문을 두드리는 망치로 쓰였다.', 4),
('lantern_sink', 'sunken_lantern', '거꾸로 뜬 연등', '목격', 'lotus_marsh', '늪 위의 연등이 물속으로 가라앉으며 불을 밝힌다. 불빛이 한쪽으로만 흘러간다.', 1),
('lantern_clock', 'sunken_lantern', '수경루 물시계 일지', '기록', 'mirror_pavilion', '사흘마다 물시계가 한 시진씩 거꾸로 흐른다. 그날마다 젖은 장부가 실려 왔다.', 2),
('lantern_scale', 'sunken_lantern', '거꾸로 박힌 역린', '물증', 'sunken_palace', '수궁 바닥 문고리 자리에 용의 비늘이 거꾸로 끼워져 있다.', 3),
('lantern_song', 'sunken_lantern', '물 밑의 노랫소리', '소리', 'sunken_palace', '수궁 깊은 곳에서 이름을 부르는 노래가 들린다. 장부에서 지워진 이름들이다.', 4),
('ash_wave', 'ash_sea', '재로 굳은 파도', '흔적', 'ash_coast', '부서지던 파도가 그대로 재가 되어 굳었다. 망국의 마지막 날이다.', 1),
('ash_ore', 'ash_sea', '맥동하는 붉은 광맥', '물증', 'crimson_mine', '광맥이 피처럼 붉게 뛴다. 녹인 봉인 사슬의 쇠가 섞여 있다.', 2),
('ash_keeper', 'ash_sea', '등대지기의 일지', '기록', 'nine_lighthouse', '아홉 등대 가운데 여섯이 꺼졌다. 꺼진 순서가 문이 열린 순서와 같다.', 3),
('ash_flame', 'ash_sea', '검은 불꽃', '목격', 'nine_lighthouse', '마지막 등대에 검은 불이 붙어 있다. 등잔에 검은 연꽃이 새겨져 있다.', 4),
('lamp_wheel', 'lamp_shadow', '끊긴 수레 자국', '흔적', 'field_outskirts', '본부 수레의 바퀴 자국이 들녘 한가운데서 끊겼다. 그 자리의 흙만 젖어 있다.', 1),
('lamp_order', 'lamp_shadow', '다리 밑의 명령서', '기록', 'paper_bridge', '흰 종이 다리 밑에 감춘 명령서. 「등을 꺼라」 아래 정청의 인장이 찍혀 있다.', 2),
('lamp_seed', 'lamp_shadow', '검은 연꽃 씨앗', '물증', 'sealed_garden', '닫아 둔 연화원 연못 바닥에 검은 연꽃 씨앗이 가득하다. 모두 싹이 텄다.', 3),
('lamp_whisper', 'lamp_shadow', '대숲의 속삭임', '증언', 'ghost_bamboo', '귀신 대나무가 본부 관리 한 사람의 이름을 되뇐다. 그 이름도 장부에서 지워졌다.', 4)
on conflict (clue_id) do nothing;

insert into public.world_story_combos(combo_id, chapter_id, name, needs, description, conclusion, sort) values
('eclipse_rite', 'eclipse_gate', '월식의 의식', array['eclipse_altar', 'eclipse_roster'], '그을린 제단과 지워진 명부를 맞춰 두 번째 문을 연 값을 밝힌다.',
 '적월교는 흑사단 전원의 이름을 바쳐 두 번째 문을 열었다. 아홉 칸 가운데 두 칸이 그렇게 탔다.', 1),
('eclipse_hammer', 'eclipse_gate', '벼락 망치와 거울', array['eclipse_mirror', 'eclipse_rod'], '벼락 맞은 쇠막대와 거울에 비친 문을 이어 다음 문의 자리를 짚는다.',
 '문은 뇌명봉의 벼락으로 두드려 열고, 월식성의 거울로 다음 문을 찾는다. 다음 문은 물 밑에 있다.', 2),
('lantern_way', 'sunken_lantern', '등불이 가리키는 길', array['lantern_sink', 'lantern_clock'], '가라앉는 연등과 거꾸로 흐르는 물시계를 맞춰 물 밑 문으로 가는 날을 찾는다.',
 '연등은 물시계가 거꾸로 흐르는 밤에만 수궁의 문을 비춘다. 젖은 장부도 그 밤에 물 밑으로 내려갔다.', 1),
('lantern_key', 'sunken_lantern', '역린의 문', array['lantern_scale', 'lantern_song'], '거꾸로 박힌 역린과 이름을 부르는 노래로 세 번째 문이 열린 방법을 밝힌다.',
 '세 번째 문은 용왕의 역린으로 잠겼고, 지워진 이름들의 노래가 열쇠를 돌렸다. 노래는 남쪽 바다에서 흘러왔다.', 2),
('ash_chain', 'ash_sea', '녹은 사슬', array['ash_wave', 'ash_ore'], '재로 굳은 파도와 붉은 광맥으로 망국을 덮친 재가 어디서 났는지 밝힌다.',
 '망국을 덮친 재는 봉인 사슬을 녹인 불에서 났다. 주혈 광산이 그 사슬을 녹였다.', 1),
('ash_lights', 'ash_sea', '꺼져 가는 등대', array['ash_keeper', 'ash_flame'], '등대지기의 일지와 검은 불꽃을 이어 누가 문을 열어 왔는지 밝힌다.',
 '아홉 등대는 아홉 문과 짝이다. 흑련회가 등대를 하나씩 꺼 문을 열어 왔고, 이미 여섯째 문까지 열렸다.', 2),
('lamp_inside', 'lamp_shadow', '안에서 내린 명령', array['lamp_wheel', 'lamp_order'], '끊긴 수레 자국과 다리 밑의 명령서로 명령이 어디서 나왔는지 밝힌다.',
 '등을 끄라는 명령은 본부 정청에서 나왔고, 본부 수레가 그 명령서를 들녘 밖으로 날랐다.', 1),
('lamp_root', 'lamp_shadow', '검은 연꽃의 뿌리', array['lamp_seed', 'lamp_whisper'], '연화원의 검은 씨앗과 대숲이 되뇌는 이름으로 흑련회의 뿌리를 찾는다.',
 '흑련회의 뿌리는 본부의 연화원에 있었다. 스스로 이름을 지운 관리가 붉은 인장을 품고 구중 봉연으로 내려갔다.', 2)
on conflict (combo_id) do nothing;

/* ── 4) 보상: 고유 탈것 · 고유 장비 · 낙관 ─────────────── */
insert into public.world_mount_catalog(mount_id, mount_name, speed_multiplier, unlock_level, unlock_reputation, price, description, tier, passenger_capacity, fare_tokens, fare_free, acquire_method)
values ('lotus_turtle', '연화 거북', 2.30, 21, 0, 0, '용잠 수궁을 지키던 늙은 거북. 등에 연꽃이 피어 있고, 물길과 뭍을 가리지 않는다. 7장 「물 밑의 등불」을 마치면 따른다.', '영물', 3, 1, false, 'event')
on conflict (mount_id) do nothing;

-- 구등대 등불 노리개: 5단계 노리개(희귀품 15 · 치명타 10 · 채집 15 중 하나)보다 여러 갈래를 고루 주는 고유 장비. 거래 불가.
-- 장착 조건은 장비 능력치 기준과 같은 식(Lv24, 영성 5 + 0.25×3×23 ≈ 22)
insert into public.world_item_catalog(item_id, item_name, category, tier, description, required_stats, minimum_level, rarity, equipment_traits, tradeable, reference_price, stack_size)
values ('n5_lighthouse', '구등대 등불 노리개', 'norigae', 5, '마지막 등대지기가 꺼지지 않은 불씨를 담아 건넨 노리개. 희귀품을 찾는 눈과 급소를 보는 눈, 단서를 놓치지 않는 눈을 함께 밝혀 준다.',
        '{"spirit_affinity": 22}'::jsonb, 24, 'legendary', '{"trait": "노리개", "rare_loot_pct": 10, "crit_pct": 6, "clue_bonus_pct": 8}'::jsonb, false, 6000, 1)
on conflict (item_id) do nothing;

insert into public.world_cosmetic_catalog(cosmetic_key, kind, tier, cosmetic_name, condition_text, category, rule, hidden, active, sort)
values ('sl_deung', 'seal', 'legend', '낙관 「燈」', '이야기 「등잔 밑」을 끝낸다', '이야기', '{"ev": "story", "p": {"chapter_id": "lamp_shadow"}}'::jsonb, false, true, 331)
on conflict (cosmetic_key) do nothing;

/* ── 보상 지급: 능력치 포인트·탈것, 보상이 가방에 안 들어가면 막기 ── */
do $$
declare d text; a text;
begin
  d := pg_get_functiondef('public.world_story_combine'::regproc);
  if position('''stat''' in d) > 0 then return; end if;
  a := 'FOR k, q IN SELECT key, value::text::int FROM jsonb_each(coalesce(rw -> ''items'', ''{}''::jsonb)) LOOP inv := public.world_inv_add(inv, k, q); END LOOP;';
  if position(a in d) = 0 then raise exception '이야기 보상 줄(물품)을 찾지 못했습니다'; end if;
  d := replace(d, a, a || chr(10) ||
    '    IF public.world_bag_count(inv) > greatest(c.bag_capacity + coalesce((rw ->> ''bag'')::int, 0) + CASE WHEN c.major_faction_id = ''river_alliance'' THEN 6 ELSE 0 END,' || chr(10) ||
    '         public.world_bag_count((SELECT inventory FROM public.world_characters WHERE owner_id = uid))) THEN' || chr(10) ||
    '      RAISE EXCEPTION ''장 보상을 받을 가방 자리가 모자랍니다. 가방을 조금 비운 뒤 마지막 가설을 다시 확정하세요.'';' || chr(10) ||
    '    END IF;');
  a := 'bag_capacity = least(400, bag_capacity + coalesce((rw ->> ''bag'')::int, 0)), updated_at = now() WHERE owner_id = uid;';
  if position(a in d) = 0 then raise exception '이야기 보상 줄(가방)을 찾지 못했습니다'; end if;
  d := replace(d, a, 'bag_capacity = least(400, bag_capacity + coalesce((rw ->> ''bag'')::int, 0)), stat_points = stat_points + coalesce((rw ->> ''stat'')::int, 0), updated_at = now() WHERE owner_id = uid;');
  a := 'PERFORM public.world_grant_xp(uid, coalesce((rw ->> ''xp'')::int, 0));';
  if position(a in d) = 0 then raise exception '이야기 보상 줄(경험치)을 찾지 못했습니다'; end if;
  d := replace(d, a, a || chr(10) ||
    '    IF rw ? ''mount'' THEN INSERT INTO public.world_owned_mounts(owner_id, mount_id, acquired_at) VALUES (uid, rw ->> ''mount'', now()) ON CONFLICT DO NOTHING; END IF;');
  execute d;
end $$;

-- 버전 올리기(접속 중인 화면에 새로고침 안내)
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261028040000', now())
  on conflict (key) do update set value = excluded.value, changed_at = now();

select seq, title, min_level, rewards ->> 'text' as reward,
       (select string_agg(distinct r.region_name, ', ') from public.world_story_clues k join public.world_map_regions r on r.region_id = k.region_id where k.chapter_id = ch.chapter_id) as regions
  from public.world_story_chapters ch order by seq;
