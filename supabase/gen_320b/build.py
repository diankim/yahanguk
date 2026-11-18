import os
HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(os.path.dirname(HERE))
VER = '20261121010000'
rd = lambda p: open(p, encoding='utf-8').read()
parts = [rd(os.path.join(ROOT, 'supabase', 'gen_210', 'meisho', 'a_head.sql'))] + [rd(os.path.join(HERE, f)) for f in ('weather.sql', 'patch_note.sql')] + [
    f"insert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;"]
out = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_3_2_0b_gwiheo_weather.sql')
open(out, 'w', encoding='utf-8').write('\n\n'.join(parts) + '\n')
print(out)
