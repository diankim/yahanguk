import pathlib
HERE = pathlib.Path(__file__).resolve().parent
FILES = ['0_head', 'a_weapons', 'b_weapon_migrate', 'c_gear_roll', 'd_jobs', 'e_field', 'f_skills', 'g_coop', 'h_exp', 'i_gearsets', 'j_scroll', 'k_idle', 'l_quests', 'n_outfits', 'm_patch_note']
VER = '20261123000000'
body = '\n'.join((HERE / 'sql' / f'{f}.sql').read_text() for f in FILES)
body += f"\ninsert into public.world_app_meta(key, value, changed_at) values ('db_version', '{VER}', now())\non conflict (key) do update set value = excluded.value, changed_at = excluded.changed_at;\n"
out = HERE.parents[0] / 'migrations' / f'{VER}_world_3_4_0_jobs.sql'
out.write_text(body)
print(out.name, len(body))
