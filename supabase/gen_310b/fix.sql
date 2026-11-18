select pg_temp.yh_fix('world_shop_sell', array[
  E'if not coalesce(p_overflow, false) or room <= 0 then',
  E'if not coalesce(p_overflow, false) then',
  E'case when dropped > 0 then ''한도에 맞춰 ''',
  E'case when dropped > 0 and paid <= 0 then ''오늘 판매 한도가 차서 값을 받지 못했습니다('' || dropped || ''개는 버려짐)'' when dropped > 0 then ''한도에 맞춰 '''
]);

update public.world_patch_notes set body = body || $N$
- 상점 판매 한도가 다 찬 뒤에도 확인 창을 거쳐 팔 수 있습니다. 값은 받지 못하고 물품만 버려지지만, 「팔기」 할 일(수향연맹 가입 퀘스트 등)은 셉니다.
- 창고 창 「맡기기」 줄에도 창고에 이미 든 같은 물품 수가, 칸대로 나눠 본 「꺼내기」 줄에는 창고에 든 모두의 수가 보입니다.
- 낚시·제작·토벌 같은 행동 뒤 칭호 판정을 줄여 응답이 빨라졌습니다.$N$
 where note_id = '3.0.0' and position('판매 한도가 다 찬 뒤에도' in body) = 0;
