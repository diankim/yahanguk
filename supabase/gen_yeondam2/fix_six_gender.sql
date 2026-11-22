do $$
declare r record; n int := 0;
begin
  for r in select * from (values
    ('mdq_8', 6, 8, '다른 하나는 검은 두건을 쓴 사내였다. 사내가 우리를 보고 손가락 여섯 개를 펴 보였다. 그 사내는 흑련 채무 추적자 여섯째였다.', '다른 하나는 검은 두건을 쓴 사람이었다. 그 사람이 우리를 보고 손가락 여섯 개를 펴 보였다. 흑련 채무 추적자 여섯째였다.'),
    ('ep_lotus_2', 1, 1, '책상 옆 벽에는 여섯째가 등을 대고 서 있었다. 검은 옷을 입은 말 없는 사내였다. 왼손 손등에 점 여섯이 새겨져 있었는데, 그 가운데 하나는 지워져 있었다.', '책상 옆 벽에는 여섯째가 등을 대고 서 있었다. 검은 옷을 입고 말이 없었다. 왼손 손등에 점 여섯이 새겨져 있었는데, 그 가운데 하나는 지워져 있었다.'),
    ('ep_lotus_2', 3, 23, '그럼 그때까진 여섯째 양반이라고 부르지 뭐. 들어와. 심지는 오늘부터 꼴 테니까 차라도 한잔하고 가. 둘 다.', '그럼 그때까진 여섯째 씨라고 부르지 뭐. 들어와. 심지는 오늘부터 꼴 테니까 차라도 한잔하고 가. 둘 다.'),
    ('ep_lotus_5', 2, 8, '여섯째 양반. 이름 아직 입에 안 붙었수?', '여섯째 씨. 이름 아직 입에 안 붙었수?')
  ) v(q, st, i, old, new) loop
    update public.world_quest_steps s set lines = jsonb_set(s.lines, array[r.i::text, 't'], to_jsonb(r.new))
     where s.quest_id = r.q and s.step = r.st and s.lines->r.i->>'t' = r.old;
    if not found then raise exception 'six gender fix miss % % %', r.q, r.st, r.i; end if;
    n := n + 1;
  end loop;
end $$;
