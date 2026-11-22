do $m$
declare v jsonb; n int;
begin
  select lines into v from public.world_quest_steps where quest_id = 'mdq_12' and step = 5 for update;
  if v -> 9 ->> 't' is distinct from '청파가 그 줄을 읽다가 입을 꾹 다물었다. 갈매는 서하람의 얼굴을 보지 않고 그 글씨만 노려보았다.'
     or v -> 10 ->> 't' is distinct from '할머니 말씀 그대로네요. 관측관은 기록을 믿어야죠. …믿기 싫어도요.' then
    raise exception 'mdq_12 다섯째 장면 모양이 예상과 다릅니다';
  end if;
  n := jsonb_array_length(v);
  update public.world_quest_steps set lines =
    (select coalesce(jsonb_agg(e order by o), '[]'::jsonb) from jsonb_array_elements(v) with ordinality x(e, o) where o <= 9)
    || $j$[
      {"s": null, "t": "서하람이 그 줄을 소리 내어 읽다가 끝에서 멈췄다. 기록판을 짚던 손이 천천히 올라가 제 눈두덩을 가만히 눌렀다."},
      {"s": "q:r71_seoharam", "t": "이 별을 보던 눈이면… 제 눈이에요. 스무 해 동안 밤마다 이 별 하나만 봤으니까요. 진을 풀어서 제 별이 타면, 저는 앞을 못 보게 되는 거예요."},
      {"s": null, "t": "청파가 「하람 형님…」 하고 부르다 말고 입을 꾹 다물었다. 청파 손에 들린 등잔 불빛이 바르르 떨렸다."},
      {"s": null, "t": "갈매는 서하람의 얼굴을 보지 않고 그 글씨만 노려보았다. 칼자루를 쥔 손등에 힘줄이 불거졌다."},
      {"s": "southern_remnant:galmae", "t": "…진짜로 적혀 있네. 할머니 말이 틀리기를 바랐는데."},
      {"s": "q:r71_seoharam", "t": "관측관은 기록을 믿어야죠. …믿기 싫어도요."},
      {"s": null, "t": "서하람은 웃으려다 말고 입술을 깨물었다. 눈가가 금세 붉어졌지만, 서하람은 눈을 한 번도 감지 않고 그 글씨를 끝까지 들여다보았다."}
    ]$j$::jsonb
    || (select coalesce(jsonb_agg(e order by o), '[]'::jsonb) from jsonb_array_elements(v) with ordinality x(e, o) where o >= 12)
  where quest_id = 'mdq_12' and step = 5;
  if (select jsonb_array_length(lines) from public.world_quest_steps where quest_id = 'mdq_12' and step = 5) <> n + 5 then
    raise exception 'mdq_12 다섯째 장면 줄 수가 맞지 않습니다';
  end if;
end $m$;

update public.world_patch_notes set body = replace(body, E'- 세력 기부 물품을 고르는 창에서 받을 공훈이 바로 보입니다.\n', E'- 세력 기부 물품을 고르는 창에서 받을 공훈이 바로 보입니다.\n- 명등기 12장 「잘못 읽은 별」의 기록판 장면 대사를 다듬었습니다.\n')
 where note_id = '3.5.0' and body like '%## 3.6.3%' and body not like '%기록판 장면 대사를%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261125060000', now()) on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
