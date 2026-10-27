-- world_fish: power(random(), 1.6)가 double precision이라 round(…, 1)이 없어 낚을 때마다 오류가 나던 문제.
-- numeric으로 바꿔 계산한다. (운영 DB에는 2026-10-27에 같은 내용으로 적용함)
do $$ declare def text; nd text; begin
  def := pg_get_functiondef('public.world_fish()'::regprocedure);
  if position('power(random(), 1.6)::numeric' in def) > 0 then return; end if;
  nd := replace(def, 'power(random(), 1.6)', 'power(random(), 1.6)::numeric');
  if nd = def then raise exception 'world_fish 고칠 곳을 찾지 못했습니다.'; end if;
  execute nd;
end $$;
