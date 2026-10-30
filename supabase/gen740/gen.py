# python3 gen.py → ../migrations/20261103220000_world_7_4_0_narration.sql
import os
from me_lines import LINES

def lit(s):
    return "'" + s.replace("'", "''") + "'"

out = ["-- 7.4.0 주인공 대사를 서술로(사용자 요청): 말하는 이가 'me'(조사원)인 줄 190개를 「나는 ~라고 했다 / ~를 물었다」 서술로 바꾼다.",
       "-- 원본 me_lines.py·gen.py(supabase/gen740). 그 자리 줄이 아직 'me'일 때만 바꾼다(다시 돌려도 그대로).",
       "do $do$",
       "declare n int := 0; k int;",
       "begin"]
for key, text in LINES.items():
    q, st, i = key.split('/')
    if st == 'ep':
        out.append(f"  update public.world_quests set epilogue = jsonb_set(epilogue, '{{{i}}}', (epilogue->{i}) || jsonb_build_object('s', null, 't', {lit(text)}))"
                   f" where quest_id = {lit(q)} and epilogue->{i}->>'s' = 'me';")
    else:
        out.append(f"  update public.world_quest_steps set lines = jsonb_set(lines, '{{{i}}}', (lines->{i}) || jsonb_build_object('s', null, 't', {lit(text)}))"
                   f" where quest_id = {lit(q)} and step = {int(st)} and lines->{i}->>'s' = 'me';")
    out.append("  get diagnostics k = row_count; n := n + k;")
out += ["  raise notice '바꾼 줄 %', n;",
        "  if exists (select 1 from public.world_quest_steps s, jsonb_array_elements(s.lines) l where l->>'s' = 'me')",
        "     or exists (select 1 from public.world_quests q, jsonb_array_elements(case when jsonb_typeof(q.epilogue) = 'array' then q.epilogue else '[]' end) l where l->>'s' = 'me') then",
        "    raise exception '아직 남은 주인공 대사가 있음';",
        "  end if;",
        "end $do$;",
        "",
        "update public.world_app_meta set value = '20261103220000' where key = 'db_version';",
        ""]
p = os.path.join(os.path.dirname(__file__), '..', 'migrations', '20261103220000_world_7_4_0_narration.sql')
open(p, 'w').write('\n'.join(out))
print(len(LINES), 'lines →', os.path.normpath(p))
