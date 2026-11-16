update public.world_patch_notes set body = body || '

## 2.4.1
- 별채·조사원 카드·그림 보기·도안첩에 따로 늘어서 있던 제보 단추를 오른쪽 위(조사원 카드는 오른쪽 아래) 작은 깃발 하나로 모았습니다. 깃발을 누르면 무엇을 제보할지 고릅니다.
- 묵적록 4장 「먹귀」 장면에서 이름이 지워진 글자로 나와야 할 자리에 「{깨진이름}」이 그대로 보이던 것을 고쳤습니다.
' where note_id = '2.4.0' and body not like '%## 2.4.1%';

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261118190000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
