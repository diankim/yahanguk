update public.world_patch_notes set body = body || $N$
- 지도에서 귀허도 영역 이름 아래에 날씨가 보이지 않던 것을 고쳤습니다(날씨 자체는 그대로입니다).$N$
 where note_id = '3.0.0' and position('귀허도 영역 이름 아래에 날씨가' in body) = 0;
