import os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261120010000'
head = open(os.path.join(ROOT, 'supabase', 'gen_210', 'meisho', 'a_head.sql'), encoding='utf-8').read()
parts = [head, open(os.path.join(HERE, 'fix.sql'), encoding='utf-8').read(), open(os.path.join(HERE, 'perf.sql'), encoding='utf-8').read(),
         f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_1_0b_sell_storage.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts) + '\n')
print(out)
