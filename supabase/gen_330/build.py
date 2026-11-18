import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261122000000'
sys.path.insert(0, HERE)
import data as RD

rd = lambda *p: open(os.path.join(ROOT, *p), encoding='utf-8').read()
head = rd('supabase', 'gen_210', 'meisho', 'a_head.sql')
pj = rd('supabase', 'gen_300', 'project', 'a_tables.sql')
pj = pj[:pj.index('create table if not exists public.world_projects')]
r = subprocess.run([sys.executable, os.path.join(HERE, 'gen.py')], capture_output=True, text=True)
sys.stderr.write(r.stderr)
if r.returncode:
    sys.exit(1)
rules = json.dumps(RD.rules(), ensure_ascii=False, sort_keys=True)
rules_sql = f"""create or replace function public.world_regular_rules()
 returns jsonb language sql immutable set search_path = pg_catalog, public
as $f$ select {"'" + rules.replace("'", "''") + "'"}::jsonb $f$;
select pg_temp.pj_share('public.world_regular_rules()');"""
parts_json = rd('supabase', 'gen_avatar', 'parts.json')
src = {}
for n in RD.NPCS:
    tr = RD.REWARDS[n['k']]['item'][4]
    if 'look' in tr:
        src[tr['look']] = f"연담 · {n['short']} 다섯째 이야기"
avatar_sql = f"""select pg_temp.yh_pj_setjson('public.world_avatar_parts()'::regprocedure, {"'" + parts_json.replace("'", "''") + "'"}::jsonb);
select pg_temp.yh_pj_setjson('public.world_outfit_rules()'::regprocedure, jsonb_set(public.world_outfit_rules(), '{{src}}', (public.world_outfit_rules() -> 'src') || {"'" + json.dumps(src, ensure_ascii=False) + "'"}::jsonb));"""
parts = [head, pj, rules_sql,
         rd('supabase', 'gen_330', 'engine.sql'),
         r.stdout,
         avatar_sql,
         rd('supabase', 'gen_330', 'project_lap.sql'),
         'select public.world_quest_label_refresh();',
         rd('supabase', 'gen_330', 'patch_note.sql'),
         f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_3_0_yeondam.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts) + '\n')
print(out, os.path.getsize(out))
