# python3 gen.py → ../migrations/20261103220000_world_7_4_0_narration.sql
import os, json
from me_lines import LINES

def lit(s):
    return "'" + s.replace("'", "''") + "'"

m = json.dumps(LINES, ensure_ascii=False, separators=(',', ':'))
out = f"""-- 7.4.0 주인공 대사를 서술로(사용자 요청): 말하는 이가 'me'(조사원)인 줄 190개를 「나는 ~라고 했다 / ~를 물었다」 서술로 바꾼다.
-- 원본 me_lines.py·gen.py(supabase/gen740). 열쇠는 퀘스트/장면/줄(0부터), 결말은 퀘스트/ep/줄. 그 자리 줄이 아직 'me'일 때만 바꾸고,
-- 끝에 'me' 줄이 하나라도 남으면 전부 되돌린다(다시 돌려도 그대로).
do $do$
declare m jsonb := {lit(m)}::jsonb; e record; p text[]; n int := 0; k int;
begin
  for e in select key, value #>> '{{}}' as t from jsonb_each(m) loop
    p := string_to_array(e.key, '/');
    if p[2] = 'ep' then
      update public.world_quests set epilogue = jsonb_set(epilogue, array[p[3]], (epilogue -> p[3]::int) || jsonb_build_object('s', null, 't', e.t))
       where quest_id = p[1] and epilogue -> p[3]::int ->> 's' = 'me';
    else
      update public.world_quest_steps set lines = jsonb_set(lines, array[p[3]], (lines -> p[3]::int) || jsonb_build_object('s', null, 't', e.t))
       where quest_id = p[1] and step = p[2]::int and lines -> p[3]::int ->> 's' = 'me';
    end if;
    get diagnostics k = row_count; n := n + k;
  end loop;
  raise notice '바꾼 줄 %', n;
  if exists (select 1 from public.world_quest_steps s, jsonb_array_elements(s.lines) l where l->>'s' = 'me')
     or exists (select 1 from public.world_quests q, jsonb_array_elements(case when jsonb_typeof(q.epilogue) = 'array' then q.epilogue else '[]' end) l where l->>'s' = 'me') then
    raise exception '아직 남은 주인공 대사가 있음';
  end if;
end $do$;

update public.world_app_meta set value = '20261103220000' where key = 'db_version';
"""
p = os.path.join(os.path.dirname(__file__), '..', 'migrations', '20261103220000_world_7_4_0_narration.sql')
open(p, 'w').write(out)
print(len(LINES), 'lines →', os.path.normpath(p), len(out.encode()), 'bytes')
