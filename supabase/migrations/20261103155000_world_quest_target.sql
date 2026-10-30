-- 퀘스트 대상 요괴 우대(제보 29): 맡은 퀘스트의 지금 장면에 「이 요괴 처치」(win, m)가 있으면
--   그 요괴가 나올 무게를 3배로 올린다. 주혈 광산 갱도 원령이면 20% → 약 43%.
--   world_battle_open(탐색·야영 조우)이 고를 때만 쓰고, 우두머리 판정은 그대로다.

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
  '  node_min int; v_intent text;',
  '  node_min int; v_intent text; v_qt text[];');

select pg_temp.yh_patch('public.world_battle_open(uuid,text,uuid,integer,integer)',
  '    SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role IN (''common'', ''main'')
    ORDER BY -ln(greatest(random(), 1e-9)) / CASE role WHEN ''common'' THEN 6 ELSE 4 END LIMIT 1;',
  '    -- 맡은 퀘스트 지금 장면의 처치 대상(제보 29: 대상 요괴 무게 ×3)
    SELECT array_agg(DISTINCT x) INTO v_qt FROM public.world_quest_progress qp
      JOIN public.world_quest_steps qs ON qs.quest_id = qp.quest_id AND qs.step = qp.step + 1
      CROSS JOIN LATERAL jsonb_array_elements(CASE WHEN jsonb_typeof(qs.need -> ''tasks'') = ''array'' THEN qs.need -> ''tasks'' ELSE ''[]'' END) t
      CROSS JOIN LATERAL jsonb_array_elements_text(CASE WHEN jsonb_typeof(t -> ''m'') = ''array'' THEN t -> ''m'' ELSE ''[]'' END) x
      WHERE qp.owner_id = p_owner AND qp.done_at IS NULL AND t ->> ''t'' = ''win'';
    SELECT * INTO m FROM public.world_region_monsters WHERE region_id = p_region AND role IN (''common'', ''main'')
    ORDER BY -ln(greatest(random(), 1e-9)) / (CASE role WHEN ''common'' THEN 6 ELSE 4 END * CASE WHEN monster_id = ANY (coalesce(v_qt, ''{}'')) THEN 3 ELSE 1 END) LIMIT 1;');
