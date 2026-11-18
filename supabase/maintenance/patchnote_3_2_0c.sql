update public.world_patch_notes set body = body || $N$
- 가구 짓기 창에서 가구 이름 뒤 「을(를)」이 받침에 맞지 않고 그대로 보이던 것을 고쳤습니다.$N$
 where note_id = '3.0.0' and position('가구 짓기 창에서 가구 이름 뒤' in body) = 0;
