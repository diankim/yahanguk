-- 7.5.1 — 7.5.0 뒤 제보 묶음
-- 제보 45(조의신): 요리 택일 기술 「든든한 한 끼」 설명에 안쪽 함수 이름이 보이던 것
update public.world_skill_catalog
   set description = replace(description, '(world_use_item의 meal 상태 지속 시간에 곱함)', '')
 where skill_id = 'cooking_c43b';

-- 제보 46(디디): 가방이 가득 차면 요괴를 쓰러뜨리는 한 방이 거절됨.
-- 마지막 턴에 화살·회복품이 줄면서 전리품이 늘어 world_enforce_bag_capacity가 「맞바꾸기」로 보고 오류를 냈다.
-- 토벌은 얻기만 하는 행동이므로 넘친 전리품은 버리고 알림(yh.bag_drop = on).
do $m$
declare d text; a text := 'IF uid IS NULL THEN RAISE EXCEPTION ''로그인이 필요합니다.''; END IF;';
begin
  d := replace(pg_get_functiondef('public.world_battle_action(text,text)'::regprocedure), E'\r\n', E'\n');
  if position('yh.bag_drop' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '7.5.1 battle anchor'; end if;
    execute replace(d, a, a || E'\n  PERFORM set_config(''yh.bag_drop'', ''on'', true);');
  end if;
  d := replace(pg_get_functiondef('public.world_enforce_bag_capacity()'::regprocedure), E'\r\n', E'\n');
  a := 'IF exchange AND NOT stash THEN';
  if position('yh.bag_drop' in d) = 0 then
    if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '7.5.1 bag anchor'; end if;
    execute replace(d, a, 'IF exchange AND NOT stash AND coalesce(current_setting(''yh.bag_drop'', true), '''') <> ''on'' THEN');
  end if;
end $m$;

-- 패치노트: 7.5.0 본문 맨 아래에 덧붙임
update public.world_patch_notes set body = body || $N$

## 7.5.1
- 가방이 가득 찬 채 요괴를 쓰러뜨리면 마지막 공격이 「가방이 가득 찼습니다」로 거절되던 것을 고쳤습니다. 이제 이기고, 들어가지 않는 전리품만 버린 뒤 알려 드립니다(디디 님 제보). 화살·회복품을 쓰는 턴에 생기던 문제입니다.
- 요리 기술 「든든한 한 끼」 설명에 안쪽 이름이 보이던 것을 고쳤습니다(조의신 님 제보).
- 현장 퀘스트 칸을 분야별·장소별로 묶어 볼 때 묶음마다 접고 펼 수 있습니다. 접은 묶음은 이 기기에 남습니다(아도니스 님 제보).
- 캐릭터 › 상태에서 퀵슬롯을 맨 위로 올렸습니다.
- 상점 팔기에 「전부」 단추를 달았습니다. 누르면 가진 만큼(장착 중 하나는 남김) 고르고, 다시 누르면 비웁니다(디디 님 제보).
$N$
 where note_id = '7.5.0' and position('## 7.5.1' in body) = 0;

update public.world_app_meta set value = '20261104010000' where key = 'db_version';
