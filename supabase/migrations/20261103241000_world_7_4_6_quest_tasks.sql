-- 7.4.6 퀘스트 할 일 줄의 바로 가기(제작법 단추)를 위해 world_quest_step_state가 할 일마다 종류(t)와 물품(items)을 함께 돌려준다.
-- 지역(regions)은 전부터 돌려줬다. 진행 판정·보상은 그대로.

create or replace function pg_temp.yh_patch(p_fn text, p_old text, p_new text, p_n int default 1) returns void
language plpgsql as $f$
declare d text; o text; k int;
begin
  d := pg_get_functiondef(p_fn::regprocedure);
  k := (length(d) - length(replace(d, p_old, ''))) / greatest(1, length(p_old));
  if k = 0 and position(p_new in d) > 0 then return; end if;
  if k <> p_n then raise exception '고칠 자리 수가 다름: % (%번 기대, %번)', p_fn, p_n, k; end if;
  o := pg_get_userbyid((select proowner from pg_proc where oid = p_fn::regprocedure));
  if o like 'fn_owner%' and not exists (select 1 from pg_auth_members am where am.roleid = o::regrole and am.member = 'postgres'::regrole and am.set_option) then
    execute format('grant %I to postgres with set true', o);
  end if;
  execute replace(d, p_old, p_new);
end $f$;

select pg_temp.yh_patch('public.world_quest_step_state(uuid,text)',
  $o$'regions', coalesce(t -> 'r', '[]'::jsonb));$o$,
  $n$'regions', coalesce(t -> 'r', '[]'::jsonb), 't', t ->> 't', 'items', t -> 'items');$n$);

update public.world_patch_notes set body = body || $N$
## 7.4.6
- **배포 예고 띠**: 큰 업데이트 전에 화면 맨 위에 「곧 업데이트 · 잠시 행동을 멈춰 주세요」 같은 안내가 뜹니다.
- **알림에서 바로 가기**: 칭호·꾸미기·보상·가방·기술 등 단추가 없던 알림에 「보러 가기」를 달아 관련 화면으로 바로 갑니다.
- **물품 정보 창**: 들어가는 제작법이 넷 이상이면 접어 두고, 누르면 펼칩니다.
- **퀘스트 바로 가기**: 할 일 줄에 그 지역 지도 단추와(만들기·넘길 물품은) 제작법 단추를 달았습니다. 제작법 단추는 제작 화면 검색칸에 이름을 넣어 줍니다. 일지의 퀘스트 카드는 접혀 있어도 지금 할 일과 장소가 보입니다. 현장 퀘스트 칸은 「분야별」「장소별」로 묶어 볼 수 있습니다.
- 채팅 칭호가 말줄임(…)으로 잘리던 것, 가방·제작 검색칸에 한 글자만 쳐도 키보드가 내려가던 것을 고쳤습니다.
$N$ where note_id = '7.4.0' and position('## 7.4.6' in body) = 0;

update public.world_app_meta set value = '20261103241000' where key = 'db_version';
