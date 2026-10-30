-- 7.4.4 외전 5장 「귀허의 주인」(gq_5) 결말 칸 비우기(사용자 요청).
-- 7.0.0 생성기가 결말 6줄을 마지막 장면 「귀허를 닫다」 끝에 이미 붙여 두었고(게임은 그 장면에서 한 번 보인다),
-- 보조 퀘스트의 결말 칸은 어디서도 읽지 않아 같은 글이 두 번 적혀 있었다. 장면 쪽에 붙은 줄이 그대로인지 확인하고 지운다.
do $do$
declare ep jsonb; ln jsonb; n int;
begin
  select epilogue into ep from public.world_quests where quest_id = 'gq_5';
  if ep is null or jsonb_array_length(ep) = 0 then return; end if;
  select lines into ln from public.world_quest_steps where quest_id = 'gq_5' and step = 3;
  n := jsonb_array_length(ep);
  if (select jsonb_agg(x order by i) from jsonb_array_elements(ln) with ordinality t(x, i) where i > jsonb_array_length(ln) - n) is distinct from ep then
    raise exception 'gq_5 마지막 장면 끝에 결말 줄이 없어 지우지 않음';
  end if;
  update public.world_quests set epilogue = '[]'::jsonb where quest_id = 'gq_5';
end $do$;

update public.world_app_meta set value = '20261103233000' where key = 'db_version';
