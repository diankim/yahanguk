import os, subprocess, sys
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261120000000'
head = open(os.path.join(ROOT, 'supabase', 'gen_210', 'meisho', 'a_head.sql'), encoding='utf-8').read()
r = subprocess.run([sys.executable, os.path.join(HERE, 'gen.py')], capture_output=True, text=True)
sys.stderr.write(r.stderr)
if r.returncode:
    sys.exit(1)
parts = [head,
         open(os.path.join(HERE, 'engine.sql'), encoding='utf-8').read(),
         open(os.path.join(HERE, 'fix_commission.sql'), encoding='utf-8').read(),
         r.stdout,
         'select public.world_quest_label_refresh();',
         open(os.path.join(HERE, 'patch_note.sql'), encoding='utf-8').read(),
         f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_1_0_epilogue.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts) + '\n')
print(out, os.path.getsize(out))
