-- 원정이 원정지(ground) 대신 탐색 장소(node)를 쓰게 바뀌면서 ground_id를 비워 두므로 NOT NULL을 푼다.
-- (적용 기록: 2026-10-27 SQL 도구로 실행. 데이터 변경 없음. 화면·조회 함수는 이미 node_id → ground_id 순으로 이름을 찾는다.)
ALTER TABLE public.world_expeditions ALTER COLUMN ground_id DROP NOT NULL;
