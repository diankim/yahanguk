-- 6.0.2 버그 수정: 가설 확정이 「column reference "x" is ambiguous」로 막히던 문제
--   6.0.0에서 장 결말 대사를 붙이며 쓴 별칭 x가 world_story_combine의 변수 x(world_story_combos 행)와 겹쳤다. 별칭을 ep로 바꾼다.
--   (운영 DB에는 2026-10-29 오후에 바로 적용함 — 이 파일은 기록용·다시 돌려도 안전)
do $$ declare d text := pg_get_functiondef('public.world_story_combine(text)'::regprocedure);
  a text := 'SELECT DISTINCT x ->> ''s'' FROM jsonb_array_elements(q.epilogue) x WHERE x ->> ''s'' IS NOT NULL';
  b text := 'SELECT DISTINCT ep ->> ''s'' FROM jsonb_array_elements(q.epilogue) ep WHERE ep ->> ''s'' IS NOT NULL';
begin
  if position(a in d) = 0 then return; end if;
  execute replace(d, a, b);
end $$;
update public.world_patch_notes set body = body || E'\n### 6.0.2\n- 일지 › 사건에서 「가설 확정」을 누르면 오류(column reference "x" is ambiguous)가 나며 막히던 문제를 고쳤습니다. 오류가 난 시도는 아무것도 바뀌지 않았으니 다시 누르면 됩니다.\n'
 where note_id = '6.0.0' and position('### 6.0.2' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261030010000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
