do $c$ begin
  if not exists (select 1 from public.world_patch_notes where note_id = '2.0.0' and position(E'이름이 흐려지는 나루의 일을 따라갑니다.\n' in body) > 0) then
    raise exception '2.0.0 패치노트 자리를 못 찾았습니다';
  end if;
end $c$;
update public.world_patch_notes set body = replace(body, E'이름이 흐려지는 나루의 일을 따라갑니다.\n', $N$이름이 흐려지는 나루의 일을 따라갑니다.
- 묵적록 보조 퀘스트 스무 편이 생겼습니다(Lv40~45). 나루 사람들의 이야기와 함께 묵적록 바깥까지 다녀오는 일도 있습니다.
- 그 가운데 여섯 편은 묵적록 명어를 쫓는 이야기입니다. 낚기 할 일은 그 명어를 낚은 기록으로 세고 명어를 거둬 가지 않습니다. 몇 편은 낚은 명어로 음식이나 약을 지어 건네야 합니다.
- 외전을 끝까지 마치면 희수·다온·월하의 뒷이야기가 세 편씩 열립니다(경험치 없음). 사람마다 마지막 편에서 칭호 하나와 별채 가구·내 모습 장신구를 하나씩 받습니다.
$N$) where note_id = '2.0.0';
