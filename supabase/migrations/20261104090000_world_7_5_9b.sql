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

update public.world_patch_notes set body = body || $N$

## 7.5.9b
- 퀘스트의 채집 할 일 문구를 고쳤습니다. 물품을 정한 채집(예: 「정제 황지」)은 처음부터 **캔 개수**로 셌는데, 문구가 「…에서 정제 황지 채집 1/3」이라 3번 채집해야 하는지 헷갈렸습니다. 이제 「…에서 정제 황지 모으기(캔 개수)」처럼 적고, 한 번에 3개를 캐면 3이 오릅니다. 물품을 정하지 않은 채집은 「…에서 채집하기(채집 횟수)」로 적습니다.
$N$
 where note_id = '7.5.0' and position('## 7.5.9b' in body) = 0;

update public.world_app_meta set value = '20261104090000' where key = 'db_version';
