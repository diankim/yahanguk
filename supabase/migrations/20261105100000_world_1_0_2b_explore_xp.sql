do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_event_char_apply()'::regprocedure), E'\r\n', E'\n');
  a := $a$when 'gather' then 14 when 'explore' then 12$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.2b world_event_char_apply 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$when 'gather' then 14 when 'explore' then 8$x$);
end $w$;

update public.world_patch_notes set body = body || $pn$

## 1.0.2b · 탐색 경험치
- 탐색 한 번에 붙는 경험치를 12에서 8로 줄였습니다. 탐색만 되풀이해도 요괴 사냥·퀘스트보다 빨리 크던 것을 맞춘 것입니다. 탐색에서 만난 요괴·찾은 길과 채집터·퀘스트 보상은 그대로입니다.
$pn$
where note_id = '1.0.0' and position('## 1.0.2b' in body) = 0;

update public.world_app_meta set value = '20261105100000' where key = 'db_version';
