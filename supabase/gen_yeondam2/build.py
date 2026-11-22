import json, os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261125070000'
sys.path.insert(0, HERE)
import data as RD

rd = lambda *p: open(os.path.join(ROOT, *p), encoding='utf-8').read()
pj = rd('supabase', 'gen_300', 'project', 'a_tables.sql')
pj = pj[:pj.index('create table if not exists public.world_projects')]
r = subprocess.run([sys.executable, os.path.join(HERE, 'gen.py')], capture_output=True, text=True)
sys.stderr.write(r.stderr)
if r.returncode:
    sys.exit(1)
lit = lambda s: "'" + s.replace("'", "''") + "'"
rules = json.dumps(RD.rules(), ensure_ascii=False, sort_keys=True)
rules_sql = f"""create or replace function public.world_regular_rules()
 returns jsonb language sql immutable set search_path = pg_catalog, public
as $f$ select {lit(rules)}::jsonb $f$;
select pg_temp.pj_share('public.world_regular_rules()');"""
parts = json.load(open(os.path.join(ROOT, 'supabase', 'gen_avatar', 'parts.json'), encoding='utf-8'))
src, outfits = {}, {}
for n in RD.NPCS:
    tr = RD.REWARDS[n['k']]['item'][4]
    if 'look' in tr:
        src[tr['look']] = f"연담 · {n['short']} 다섯째 이야기"
        outfits[tr['look']] = parts['outfits'][tr['look']]
avatar_sql = f"""select pg_temp.yh_pj_setjson('public.world_avatar_parts()'::regprocedure, jsonb_set(public.world_avatar_parts(), '{{outfits}}', (public.world_avatar_parts() -> 'outfits') || {lit(json.dumps(outfits, ensure_ascii=False))}::jsonb));
select pg_temp.yh_pj_setjson('public.world_outfit_rules()'::regprocedure, jsonb_set(public.world_outfit_rules(), '{{src}}', (public.world_outfit_rules() -> 'src') || {lit(json.dumps(src, ensure_ascii=False))}::jsonb));"""
fix_sql = '\n'.join(f"update public.world_title_catalog set description = {lit(v)} where title_key = {lit(k)};" for k, v in RD.OLD_FIX.items())
parts_sql = [pj, rules_sql,
         rd('supabase', 'gen_yeondam2', 'engine.sql'),
         r.stdout,
         fix_sql,
         avatar_sql,
         rd('supabase', 'gen_yeondam2', 'fix_six_gender.sql'),
         'select public.world_quest_label_refresh();',
         rd('supabase', 'gen_yeondam2', 'patch_note.sql'),
         f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_7_0_yeondam4.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts_sql) + '\n')
print(out, os.path.getsize(out))
