-- 6.0.4 버그 수정(제보 11 · 퀘스트 보고 권한)
-- ① 보조 퀘스트 마지막 보고: world_quest_report(주인 fn_owner_field)가 완료 알림 문구에 world_josa를 부르는데 실행 권한이 없어
--    「이 작업을 할 권한이 없습니다」로 막혔다(보조 퀘스트 완료 0건). 순수 문자열 함수라 그 함수를 부르는 주인 역할에만 준다.
do $$ declare r text; begin
  for r in select distinct pg_get_userbyid(p.proowner) from pg_proc p
            where p.pronamespace = 'public'::regnamespace and p.prokind = 'f' and p.proname <> 'world_josa'
              and pg_get_functiondef(p.oid) like '%world_josa(%' loop
    if r like 'fn_owner%' then execute format('grant execute on function public.world_josa(text, text, text) to %I', r); end if;
  end loop;
end $$;

-- ② 제보 11: 지역에 막 도착하면(현장 위치가 아직 정해지지 않음) 현장 화면은 그 지역 들머리의 채집터(「어귀의 …」)를 보여 주는데,
--    채집은 지금 위치와 같은 곳의 채집터만 받아 「지금 있는 곳의 채집터가 아닙니다」가 났다. 화면과 같은 기준으로 들머리 채집터를 받는다.
do $$ declare d text := pg_get_functiondef('public.world_field_gather(uuid)'::regprocedure);
  a text := 'SELECT * INTO s FROM public.world_gathering_spots WHERE spot_id = p_spot_id AND active AND node_id = c.current_exploration_node_id;';
  b text := 'SELECT * INTO s FROM public.world_gathering_spots WHERE spot_id = p_spot_id AND active AND (node_id = c.current_exploration_node_id OR (node_id = (SELECT n0.node_id FROM public.world_exploration_nodes n0 JOIN public.world_map_regions r0 ON r0.region_id = n0.region_id WHERE r0.region_name = c.location AND n0.hierarchy_level = 1 LIMIT 1) AND NOT EXISTS (SELECT 1 FROM public.world_exploration_nodes n1 JOIN public.world_map_regions r1 ON r1.region_id = n1.region_id WHERE n1.node_id = c.current_exploration_node_id AND r1.region_name = c.location)));';
begin
  if position('n0.hierarchy_level = 1' in d) > 0 then return; end if;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '고칠 자리 없음: 들머리 채집'; end if;
  execute replace(d, a, b);
end $$;

update public.world_patch_notes set body = body || E'\n### 6.0.4\n- **보조 퀘스트의 마지막 장면을 보고하면 「이 작업을 할 권한이 없습니다」가 나며 마칠 수 없던 문제**를 고쳤습니다. 막힌 보고는 아무것도 바뀌지 않았으니 같은 곳에서 다시 「보고하기」를 누르면 보상과 함께 마칩니다.\n- 지역에 막 도착했을 때 보이는 들머리 채집터(「어귀의 …」)를 누르면 「지금 있는 곳의 채집터가 아닙니다」가 나던 문제를 고쳤습니다.\n'
 where note_id = '6.0.0' and position('### 6.0.4' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261030030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
