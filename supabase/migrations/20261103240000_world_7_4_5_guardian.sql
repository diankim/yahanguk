-- 7.4.5 퀘스트의 「지역 우두머리 쓰러뜨리기」가 안 나온다는 제보(구중 봉연 사슬 끊는 자).
-- 우두머리는 답사 지도의 깊이 3 이상 칸에서 탐색할 때만(9%·깊이 4부터 16%) 나와, 얕은 칸에서는 아무리 탐색해도 만날 수 없었다.
-- ① 지금 장면 할 일이 그 지역 우두머리 처치인 조사원은: 깊이 3 이상 35%, 얕은 칸에서도 4%(사용자 결정: 얕은 데서는 드물게, 맞는 곳에선 나오게).
--    그 밖의 조사원은 그대로(9%·16%).
-- ② 그런 할 일의 문구에 「답사 지도 셋째 칸부터 깊은 곳에서 탐색」을 덧붙이고, 바로 앞 장면 끝에 같은 뜻의 서술 한 줄을 넣는다.

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

select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  'node_min int; v_intent text; v_qt text[];',
  'node_min int; v_intent text; v_qt text[]; v_gq boolean := false;');
select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  'IF (p_depth >= 3 AND random() < (CASE WHEN p_depth >= 4 THEN 0.16 ELSE 0.09 END))',
  '-- 지금 장면 할 일이 이 지역 우두머리 처치면 깊은 곳 35%, 얕은 곳 4%(7.4.5)
v_gq := EXISTS (SELECT 1 FROM public.world_quest_progress qp
  JOIN public.world_quest_steps qs ON qs.quest_id = qp.quest_id AND qs.step = qp.step + 1
  CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(qs.need -> ''tasks'') = ''array'' THEN qs.need -> ''tasks'' ELSE ''[]'' END) t
  WHERE qp.owner_id = p_owner AND qp.done_at IS NULL AND t ->> ''t'' = ''win'' AND t ->> ''rank'' = ''guardian''
    AND (t -> ''r'' IS NULL OR jsonb_typeof(t -> ''r'') <> ''array'' OR t -> ''r'' ? p_region OR (t -> ''r'' = ''[]''::jsonb AND qs.need -> ''at'' ? p_region)));
IF (p_depth >= 3 AND random() < (CASE WHEN v_gq THEN 0.35 WHEN p_depth >= 4 THEN 0.16 ELSE 0.09 END)) OR (v_gq AND p_depth < 3 AND random() < 0.04)');

-- 문구와 안내 줄
do $do$
declare s record; hint text := '나는 이런 우두머리는 얕은 곳에서는 좀처럼 나오지 않는다는 것을 떠올렸다. 답사 지도 셋째 칸부터, 안쪽 깊은 곳까지 들어가 탐색해야 모습을 드러낸다.';
begin
  for s in select quest_id, step from public.world_quest_steps where need::text like '%"rank": "guardian"%' loop
    update public.world_quest_steps set goal = goal || ' (답사 지도 셋째 칸부터 깊은 곳에서 탐색하면 나타남)'
     where quest_id = s.quest_id and step = s.step and position('셋째 칸부터' in goal) = 0;
    update public.world_quest_steps set lines = lines || jsonb_build_array(jsonb_build_object('s', null, 't', hint))
     where quest_id = s.quest_id and step = s.step - 1 and position('셋째 칸부터' in lines::text) = 0;
  end loop;
end $do$;

update public.world_patch_notes set body = body || $N$
## 7.4.5
- **지역 우두머리가 안 나오던 것**: 우두머리는 답사 지도의 깊은 곳(셋째 칸부터)에서 탐색할 때만 나와, 「○○의 우두머리를 쓰러뜨린다」 할 일(10장 사슬 끊는 자 등 15곳)이 얕은 곳에서는 끝나지 않았습니다. 그 할 일을 맡고 있으면 깊은 곳에서는 훨씬 자주(35%), 얕은 곳에서도 드물게 나타납니다. 할 일 문구와 앞 장면 대사에 「셋째 칸부터 깊은 곳」을 적었습니다.
$N$ where note_id = '7.4.0' and position('## 7.4.5' in body) = 0;

update public.world_app_meta set value = '20261103240000' where key = 'db_version';
