import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261124040000'
rd = lambda *p: open(os.path.join(ROOT, *p), encoding='utf-8').read()
r = subprocess.run([sys.executable, os.path.join(ROOT, 'tools', 'portrait_art', 'gen.py')], capture_output=True, text=True)
sys.stderr.write(r.stdout + r.stderr)
if r.returncode:
    sys.exit(1)
pj = rd('supabase', 'gen_300', 'project', 'a_tables.sql')
pj = pj[:pj.index('create table if not exists public.world_projects')]
parts = [pj, rd('supabase', 'gen_portrait', 'items.sql'), rd('supabase', 'gen_portrait', 'engine.sql'), rd('supabase', 'gen_portrait', 'patch_note.sql'),
         f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_5_0_portraits.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts) + '\n')
print(out, os.path.getsize(out))
