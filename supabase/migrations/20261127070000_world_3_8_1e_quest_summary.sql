update public.world_quests q set summary = v.s from (values
('rg_kangducheol_1', '교관 강두철이 막는 법은 맞아 봐야 안다고 한다.'),
('rg_kangducheol_2', '산문 수련장의 버팀돌을 아래 터로 옮긴다.'),
('rg_kangducheol_3', '스승의 목인 팔을 달 새 목인을 세운다.'),
('rg_kangducheol_4', '이번 겨울 막내에게 맞는 갑옷이 없다.'),
('rg_kangducheol_5', '산문 수련이 끝나 강두철이 하산한다.'),
('rg_mogaram_1', '손이 굳은 모가람이 요괴 버릇 기록을 새로 엮으려 한다.'),
('rg_mogaram_2', '불러 준 요괴 이름 하나가 틀렸다.'),
('rg_mogaram_3', '모가람이 서른 해 전 제 글씨 이야기를 꺼낸다.'),
('rg_mogaram_4', '기록에 끝내 못 채운 칸이 하나 남았다.'),
('rg_mogaram_5', '요괴 버릇 기록의 마지막 장을 쓴다.'),
('rg_yeonseohui_1', '서당 아이가 무릎을 깨 오고 약상자는 비어 있다.'),
('rg_yeonseohui_2', '처치 장부의 「독」 칸만 비어 있다.'),
('rg_yeonseohui_3', '연서희의 약상자에 회춘단이 떨어졌다.'),
('rg_yeonseohui_4', '쉬는 날, 연서희가 빌려준 우산을 길에서 돌려받겠다고 한다.'),
('rg_yeonseohui_5', '연서희가 서당 처마에 등을 건다.'),
('rg_yeoseotjjae_1', '셈 수첩이 지워진 채무 추적자 여섯째가 조사원을 붙든다.'),
('rg_yeoseotjjae_2', '여섯째의 손가락 셈이 하나 어긋난다.'),
('rg_yeoseotjjae_3', '장날 밤, 좌판 집 아이가 사라진다.'),
('rg_yeoseotjjae_4', '흑련 장부고 지붕에 금줄귀가 들어앉았다.'),
('rg_yeoseotjjae_5', '첫눈 내린 밤, 여섯째가 산가지를 깎는다.')
) v(id, s) where q.quest_id = v.id and q.summary <> v.s;
update public.world_patch_notes set body = body || E'\n- [퀘스트] 연담 강두철·모가람·연서희·여섯째 이야기 카드의 소개 글이 줄거리를 길게 늘어놓던 것을 한 줄로 줄였습니다.'
where note_id = '3.8.0' and position('여섯째 이야기 카드의 소개 글' in body) = 0;
insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261127070000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
