-- 7.5.9e — 퀘스트 채집 할 일 문구에서 「(캔 개수)」「(채집 횟수)」를 뺀다(사용자 요청). 단위는 화면(quests.js unitOf)이 수 뒤에 「개」「회」로 붙인다.
do $p$
declare d text; n int; own text; inh boolean;
begin
  d := replace(pg_get_functiondef('public.world_quest_task_label(jsonb)'::regprocedure), E'\r\n', E'\n');
  if position('(캔 개수)' in d) = 0 then return; end if;
  n := (length(d) - length(replace(d, $o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$, ''))) / length($o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$);
  if n <> 1 then raise exception '7.5.9e label anchor %', n; end if;
  select p.proowner::regrole::text into own from pg_proc p where p.oid = 'public.world_quest_task_label(jsonb)'::regprocedure;
  select am.inherit_option into inh from pg_auth_members am where am.roleid = own::regrole and am.member = 'postgres'::regrole;
  if own <> 'postgres' and not pg_has_role('postgres', own, 'USAGE') then execute format('grant %I to postgres with inherit true', own); end if;
  execute replace(d, $o$' 모으기(캔 개수)', '채집하기(채집 횟수)'$o$, $o$' 모으기', '채집하기'$o$);
  if inh is not null and not inh then execute format('grant %I to postgres with inherit false', own); end if;
end $p$;

update public.world_app_meta set value = '20261104120000' where key = 'db_version';
