-- 7.3.4 덧붙임: 적월 교령 유리협곡에 작은 호수 낚시터(호수 어종). 지도 물길(water.js)에도 같은 자리에 못을 그린다.
insert into public.world_fish_grounds(region_id, habitat, ground_name, description)
values ('glass_canyon', 'lake', '월영 유리못', '유리 절벽 아래 고인 작은 못. 붉은 달이 뜨면 물빛이 핏빛으로 물들고, 유리 조각 그늘에 물고기가 숨습니다.')
on conflict do nothing;

update public.world_patch_notes set body = body || $n$
- 적월 교령 유리협곡 바닥에 작은 호수 「월영 유리못」이 생겨 낚시를 할 수 있습니다(호수 어종). 지도에도 못이 보입니다.
- 휴대폰에서 서신 쓰기 창이 두 칸으로 갈라져 비좁던 것을 한 줄로 쌓아 보이게 고쳤습니다.
$n$ where note_id = '7.2.0' and position('월영 유리못' in body) = 0;
update public.world_app_meta set value = '20261103190000' where key = 'db_version';
