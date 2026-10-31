-- 7.5.9b — 채집 할 일 문구(사용자 전달 제보): 물품을 정한 채집은 처음부터 캔 개수(주 물품 qty + 덤 extra)로 세는데(6.1.1)
-- 문구가 「…에서 정제 황지 채집 1/3」이라 3번 채집해야 하는지 3개를 캐야 하는지 알 수 없었다. 개수인지 횟수인지 문구에 적는다.
do $p$
declare d text; a text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_quest_task_label(jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('캔 개수' in d) > 0 then return; end if;
  a := $o$|| coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' ', '') || '채집'$o$;
  n := (length(d) - length(replace(d, a, ''))) / length(a);
  if n <> 1 then raise exception '7.5.9b task label anchor %', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_quest_task_label(jsonb)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, a, $n$|| coalesce((select string_agg(i.item_name, '·') from public.world_item_catalog i where i.item_id in (select jsonb_array_elements_text(p_task -> 'items'))) || ' 모으기(캔 개수)', '채집하기(채집 횟수)')$n$);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

-- 패치노트는 사용자 요청으로 따로 번호를 두지 않고 7.5.0 본문 맨 끝(## 7.5.9 항목 아래)에 이어 쓴다
update public.world_patch_notes set body = rtrim(body, E'\n') || $N$
- 퀘스트의 채집 할 일 문구를 고쳤습니다. 물품을 정한 채집(예: 「정제 황지」)은 처음부터 **캔 개수**로 셌는데, 문구가 「…에서 정제 황지 채집 1/3」이라 3번 채집해야 하는지 헷갈렸습니다. 이제 「…에서 정제 황지 모으기(캔 개수)」처럼 적고, 한 번에 3개를 캐면 3이 오릅니다. 물품을 정하지 않은 채집은 「…에서 채집하기(채집 횟수)」로 적습니다.
- 알림음(설정 › 소리)이 울릴 때 화면 아래에도 글로 알려 줍니다: 탐색력 가득 · 잠깐 쉬기 가능 · 푹 쉬기 가능 · 자율 활동 끝. 전에는 소리만 나서 소리를 꺼 두었거나 못 들으면 알 수 없었습니다. 알림을 끈 종류는 글도 뜨지 않습니다.
$N$
 where note_id = '7.5.0' and position('(캔 개수)' in body) = 0;

update public.world_app_meta set value = '20261104090000' where key = 'db_version';
