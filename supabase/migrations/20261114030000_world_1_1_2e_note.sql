update public.world_patch_notes set body = body || E'\n\n## 1.1.2e\n- PC에서 귀허의 주인과 싸울 때 화면을 내리지 않아도 모든 칸이 한 화면에 들어오게 바꿨습니다. 왼쪽에는 주인·라운드 띠·내 행동(공격·방어·버티기·물품·협동 기술·이번 라운드만의 행동)을, 오른쪽에는 함께 선 이와 전투 기록을 따로 쌓습니다. 함께 선 이가 넷이어도 단추가 화면 아래로 밀려나지 않고, 기록 칸은 남은 높이에 맞춰 늘고 줄어듭니다.'
 where note_id = '1.1.0' and position('## 1.1.2e' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261114030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
