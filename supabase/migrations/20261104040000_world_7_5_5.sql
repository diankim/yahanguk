-- 7.5.5 — 이동 중 퀘스트 받기·보고 막기(제보) + PC 가방 › 장비 좌우 배치(화면만) 패치노트
-- 이동 중(travel_arrives_at이 남아 있는 동안)에는 world_quest_report(받기·장면 보고)·world_faction_report(세력 퀘스트 보고)를 거절한다.
-- 전에는 출발한 곳(location)이 그대로 남아 있어 이동 중에도 그곳 인물에게 받기·보고가 됐다.
do $p$
declare d text; a text; n int; f text;
begin
  -- 보조·주 이야기 퀘스트
  f := 'public.world_quest_report(text)';
  d := replace(pg_get_functiondef(f::regprocedure), E'\r\n', E'\n');
  if position('이동 중에는 퀘스트를' in d) = 0 then
    a := $o$  if c.health <= 0 or c.downed_at is not null then raise exception '전투불능 상태에서는 보고할 수 없습니다.'; end if;$o$;
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '7.5.5 quest_report anchor %', n; end if;
    execute replace(d, a, a || $n$
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 퀘스트를 받거나 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$n$);
  end if;
  -- 세력 퀘스트
  f := 'public.world_faction_report()';
  d := replace(pg_get_functiondef(f::regprocedure), E'\r\n', E'\n');
  if position('이동 중에는 세력 퀘스트를' in d) = 0 then
    a := $o$  if c.major_faction_id is null then raise exception '대세력에 들어야 합니다.'; end if;$o$;
    n := (length(d) - length(replace(d, a, ''))) / length(a);
    if n <> 1 then raise exception '7.5.5 faction_report anchor %', n; end if;
    execute replace(d, a, a || $n$
  if c.travel_arrives_at is not null and c.travel_arrives_at > now() then raise exception '이동 중에는 세력 퀘스트를 보고할 수 없습니다. 도착한 뒤에 하세요.'; end if;$n$);
  end if;
end $p$;

update public.world_patch_notes set body = body || $N$

## 7.5.5
- PC 가방 › 장비를 왼쪽 「장착 중인 장비」 칸과 오른쪽 「고른 부위」(지금 장비·수리·벗기·바꿔 낄 장비)로 나란히 보이게 바꿨습니다. 왼쪽 칸을 누르면 오른쪽이 그 부위로 바뀌어, 벗은 뒤 바로 옆에서 다시 낄 수 있습니다.
- 이동 중에는 퀘스트를 받거나 보고할 수 없게 했습니다(세력 퀘스트 포함). 전에는 떠나온 곳의 인물에게 이동 중에도 받기·보고가 됐습니다. 도착한 뒤에 하세요.
$N$
 where note_id = '7.5.0' and position('## 7.5.5' in body) = 0;

update public.world_app_meta set value = '20261104040000' where key = 'db_version';
