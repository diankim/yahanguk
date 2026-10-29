-- 6.1.4 퀘스트 「단서 찾기」가 영영 안 나오던 것(제보 16): 탐색의 단서 결과는 지금 주 이야기 장의 못 찾은 단서가
-- 그 지역에 있을 때만 나와서, 보조 퀘스트(sq_* 10개)·세력 장면(흑련회 가입·야행청 등급) 「단서 찾기」가 다른 지역·다른 장에서는 막혔다.
-- 이제 그런 할 일이 걸려 있으면 이야기 단서가 없는 곳에서도 같은 확률로 「맡은 일의 실마리」(outcome clue, side_clue)를 찾는다.
-- 이야기 단서가 있는 곳에서는 지금처럼 이야기 단서가 먼저다.
lock table public.world_characters in access exclusive mode;

-- 걸려 있는 「단서 찾기」 할 일이 이 지역에서 진행되는가(보조·직업·소속 퀘스트의 지금 장면, 세력 가입·등급 장면)
create or replace function public.world_pending_clue_task(p_uid uuid, p_region text)
returns boolean language sql stable security definer set search_path = pg_catalog, public as $f$
  select exists (
      select 1 from public.world_quest_progress p
        join public.world_quest_steps s on s.quest_id = p.quest_id and s.step = p.step + 1
        cross join lateral jsonb_array_elements(coalesce(s.need -> 'tasks', '[]'::jsonb)) t
       where p.owner_id = p_uid and p.done_at is null and t ->> 't' = 'clue'
         and (not t ? 'r' or t -> 'r' ? p_region))
    or exists (
      select 1 from public.world_faction_progress fp
        join public.world_faction_scenes fs on fs.faction_id = fp.faction_id
        cross join lateral jsonb_array_elements(coalesce(fs.need -> 'tasks', '[]'::jsonb)) t
       where fp.owner_id = p_uid and t ->> 't' = 'clue' and (not t ? 'r' or t -> 'r' ? p_region)
         and ((fs.kind = 'join' and fp.join_done_at is null and fs.step between fp.join_step - 1 and fp.join_step + 1)
           or (fs.kind = 'rank' and fs.step = coalesce(fp.rank, 1) + 1)))
$f$;
alter function public.world_pending_clue_task(uuid, text) owner to fn_owner_field;
do $$ begin
  if not pg_has_role('postgres', 'fn_owner_field', 'usage') then grant fn_owner_field to postgres with inherit true, set true; end if;
end $$;
set role fn_owner_field;
revoke all on function public.world_pending_clue_task(uuid, text) from public, anon, authenticated;
reset role;

do $$ declare d text; a text; b text; n int;
begin
  d := pg_get_functiondef('public.world_field_search()'::regprocedure);
  if position('side_clue' in d) = 0 then
    a := E'  IF clue.clue_id IS NOT NULL THEN\n    w_clue := 16 + c.perception';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 단서 확률(%)', n; end if;
    d := replace(d, a, E'  IF clue.clue_id IS NOT NULL OR public.world_pending_clue_task(uid, r.region_id) THEN\n    w_clue := 16 + c.perception');
    a := E'  ELSIF outcome = ''clue'' THEN\n    INSERT INTO public.world_case_progress(owner_id, case_id, clues, combined)';
    n := (length(d) - length(replace(d, a, ''))) / length(a); if n <> 1 then raise exception '고칠 자리 없음: 단서 결과(%)', n; end if;
    b := E'  ELSIF outcome = ''clue'' AND clue.clue_id IS NULL THEN\n'
      || E'    -- 이야기 단서가 없는 곳: 맡은 퀘스트·세력 일의 실마리(퀘스트 「단서 찾기」로 센다)\n'
      || E'    txt := (ARRAY[''누군가 서둘러 남긴 표식을 찾았다. 맡은 일의 실마리가 될 듯하다.'', ''흙에 반쯤 묻힌 쪽지를 주웠다. 찾던 이야기와 이어지는 실마리다.'', ''낯선 발자국이 한곳에서 맴돈 흔적을 찾았다. 맡은 일과 닿아 있는 실마리다.''])[1 + floor(random() * 3)::int];\n'
      || E'    xp := 12; payload := jsonb_build_object(''side_clue'', true);\n'
      || E'    UPDATE public.world_characters SET investigation_xp = investigation_xp + 8, investigation_rank = public.world_skill_rank(investigation_xp + 8, ''investigation'') WHERE owner_id = uid;\n'
      || a;
    d := replace(d, a, b);
    execute d;
  end if;
end $$;

update public.world_patch_notes set body = body || E'\n### 6.1.4\n- **퀘스트 「단서 찾기」(제보)**: 보조 퀘스트·세력 퀘스트의 「단서 찾기」가 주 이야기 단서가 있는 지역에서만 나와, 다른 곳에서는 아무리 탐색해도 진행되지 않던 문제를 고쳤습니다. 이제 그런 할 일을 맡고 있으면 그 지역 탐색에서 「맡은 일의 실마리」를 찾을 수 있습니다(주 이야기 단서가 있는 곳은 그 단서가 먼저 나옵니다).\n'
 where note_id = '6.1.0' and position('### 6.1.4' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261031030000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
