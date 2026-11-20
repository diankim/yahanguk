create or replace function pg_temp.rf(p_fn regprocedure, p_pairs text[]) returns void language plpgsql as $g$
declare src text := pg_get_functiondef(p_fn); i int; n int;
begin
  for i in 1 .. array_length(p_pairs, 1) / 2 loop
    n := (length(src) - length(replace(src, p_pairs[2 * i - 1], ''))) / greatest(length(p_pairs[2 * i - 1]), 1);
    if n <> 1 then raise exception '% 조각 %: % 번 나옴', p_fn, i, n; end if;
    src := replace(src, p_pairs[2 * i - 1], p_pairs[2 * i]);
  end loop;
  execute src;
end $g$;

select pg_temp.rf('public.world_quest_board()', array[
$o$        'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id))
      )$o$,
$n$        'region_names', jsonb_agg(distinct (select region_name from public.world_map_regions where region_id = k.region_id)),
        'list', jsonb_agg(jsonb_build_object('rg', k.region_id, 'rn', (select region_name from public.world_map_regions where region_id = k.region_id),
          'found', exists (select 1 from public.world_case_progress p where p.owner_id = uid and p.case_id = k.chapter_id
            and p.clues @> jsonb_build_array(jsonb_build_object('id', k.clue_id))),
          'id', k.clue_id) order by k.sort),
        'combos', (select jsonb_agg(jsonb_build_object('id', y.combo_id, 'name', y.name, 'needs', to_jsonb(y.needs),
            'done', coalesce((select p.combined ? y.combo_id from public.world_case_progress p where p.owner_id = uid and p.case_id = q.chapter_id), false)) order by y.sort)
          from public.world_story_combos y where y.chapter_id = q.chapter_id)
      )$n$]);
update public.world_patch_notes set body = replace(body, $o$## 고친 것
$o$, $n$## 본편 단서 안내
- 본편 장의 장면을 모두 마치면 현장 퀘스트 칸에 남은 단서와 찾을 곳(지도 바로 가기)이 보입니다.
- 모인 단서로 세울 수 있는 가설은 퀘스트 칸에서 바로 「가설 확정」을 누를 수 있습니다. 일지에 들어가지 않아도 장을 마칠 수 있습니다.

## 고친 것
$n$)
 where note_id = '3.5.0' and position('## 본편 단서 안내' in body) = 0;

insert into public.world_app_meta(key, value, changed_at) values ('db_version', '20261124050000', now())
on conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;
