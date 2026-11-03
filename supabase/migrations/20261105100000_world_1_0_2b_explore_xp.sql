do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_event_char_apply()'::regprocedure), E'\r\n', E'\n');
  a := $a$when 'gather' then 14 when 'explore' then 12$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.2b world_event_char_apply 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$when 'gather' then 14 when 'explore' then 8$x$);
end $w$;

create or replace function public.world_quest_xp_rules() returns jsonb language sql immutable as $f$
  select jsonb_build_object('grace', 3, 'mid', 6, 'mid_pct', 50, 'low_pct', 20,
    'band', jsonb_build_array(jsonb_build_array(1, 25), jsonb_build_array(6, 40), jsonb_build_array(11, 40), jsonb_build_array(16, 75),
                              jsonb_build_array(21, 90), jsonb_build_array(26, 75), jsonb_build_array(31, 100)))
$f$;

create or replace function public.world_quest_xp_mul(p_quest_lv integer, p_char_lv integer) returns numeric
language sql immutable as $f$
  select coalesce((select (b ->> 1)::numeric / 100 from jsonb_array_elements(public.world_quest_xp_rules() -> 'band') b
                     where (b ->> 0)::int <= coalesce(p_quest_lv, 1) order by (b ->> 0)::int desc limit 1), 1)
       * case when coalesce(p_char_lv, 1) - coalesce(p_quest_lv, 1) <= (public.world_quest_xp_rules() ->> 'grace')::int then 1
              when coalesce(p_char_lv, 1) - coalesce(p_quest_lv, 1) <= (public.world_quest_xp_rules() ->> 'mid')::int then (public.world_quest_xp_rules() ->> 'mid_pct')::numeric / 100
              else (public.world_quest_xp_rules() ->> 'low_pct')::numeric / 100 end
$f$;

revoke all on function public.world_quest_xp_rules() from public, anon, authenticated;
revoke all on function public.world_quest_xp_mul(integer, integer) from public, anon, authenticated;
grant execute on function public.world_quest_xp_rules() to fn_owner_field;
grant execute on function public.world_quest_xp_mul(integer, integer) to fn_owner_field;

do $w$
declare d text; a text;
begin
  d := replace(pg_get_functiondef('public.world_quest_report(text)'::regprocedure), E'\r\n', E'\n');
  a := $a$rw_xp := coalesce((s.reward ->> 'xp')::int, 0);$a$;
  if (length(d) - length(replace(d, a, ''))) / length(a) <> 1 then raise exception '1.0.2b world_quest_report 기준 문구가 없습니다'; end if;
  execute replace(d, a, $x$rw_xp := coalesce((s.reward ->> 'xp')::int, 0); if rw_xp > 0 then rw_xp := greatest(1, round(rw_xp * public.world_quest_xp_mul(q.min_level, c.level))::int); end if;$x$);
end $w$;

update public.world_patch_notes set body = body || $pn$

## 1.0.2b · 탐색·퀘스트 경험치
- 탐색 한 번에 붙는 경험치를 12에서 8로 줄였습니다. 탐색만 되풀이해도 요괴 사냥·퀘스트보다 빨리 크던 것을 맞춘 것입니다. 탐색에서 만난 요괴·찾은 길과 채집터는 그대로입니다.
- 퀘스트 경험치를 레벨 구간마다 다시 맞췄습니다. 낮은 레벨에는 퀘스트가 많아 퀘스트만으로 필요한 경험치의 2~3배가 나와 너무 빨리 크던 것을, 구간마다 퀘스트를 모두 해도 필요한 경험치의 60~80%가 되게 줄였습니다(Lv1~5 ¼·Lv6~15 40%·Lv16~20 75%·Lv21~25 90%·Lv26~30 75%, 외전은 그대로). 이미 받은 경험치는 그대로입니다.
- 그리고 퀘스트 경험치는 퀘스트 레벨에 맞춰 들어갑니다. 내 레벨이 퀘스트보다 3까지 높으면 그대로, 4~6 높으면 절반, 7 이상 높으면 ⅕만 받습니다(전·물품 보상은 그대로). 낮은 레벨 퀘스트는 그 레벨일 때 하는 것이 가장 이득입니다.
$pn$
where note_id = '1.0.0' and position('## 1.0.2b' in body) = 0;

update public.world_app_meta set value = '20261105100000' where key = 'db_version';
