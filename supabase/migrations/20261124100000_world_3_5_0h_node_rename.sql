update public.world_exploration_nodes set node_name = '바람 우는 빙하 균열' where node_name = '바람 우는 크레바스';
update public.world_region_profiles set visual_identity = replace(visual_identity, '크레바스', '빙하 균열') where visual_identity like '%크레바스%';

update public.world_patch_notes set body = rtrim(body, E'\n') || E'\n- 천년 빙하의 답사 지점 「바람 우는 크레바스」의 이름을 「바람 우는 빙하 균열」로 바꿨습니다.\n- 현장 토벌 화면의 요괴 갈래 칩도 지금 무기·직업에 유리하면 초록 ▲, 불리하면 빨강 ▼로 보입니다.\n'
 where note_id = '3.5.0' and position('바람 우는 빙하 균열' in body) = 0;

select public.world_quest_label_refresh();

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124100000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
