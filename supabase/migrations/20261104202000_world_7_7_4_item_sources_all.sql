-- 7.7.4 — 물품 「얻는 곳」 전체 목록(제보 82, 이상혁).
-- 물품 정보 창은 갈래마다 두 곳 + 「외 n곳」만 보이고(world_item_sources는 갈래마다 6곳까지), 「외 n곳」을 누르면 겹쳐 뜨는 창에 모두 보인다.
-- world_item_sources와 같은 계산에서 「limit 6」만 뺀 함수를 따로 둔다(누를 때만 부름).
do $p$
declare d text; n int;
begin
  d := replace(pg_get_functiondef('public.world_item_sources(text)'::regprocedure), E'\r\n', E'\n');
  n := (length(d) - length(replace(d, ' limit 6) x)', ''))) / length(' limit 6) x)');
  if n <> 4 then raise exception '7.7.4 item sources all: limit 6 anchors %', n; end if;
  d := replace(d, ' limit 6) x)', ') x)');
  d := replace(d, 'FUNCTION public.world_item_sources(', 'FUNCTION public.world_item_sources_all(');
  if position('world_item_sources_all(' in d) = 0 then raise exception '7.7.4 item sources all: name'; end if;
  execute d;
end $p$;
revoke all on function public.world_item_sources_all(text) from public, anon;
grant execute on function public.world_item_sources_all(text) to authenticated;

update public.world_app_meta set value = '20261104202000' where key = 'db_version';
