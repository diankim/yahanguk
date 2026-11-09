import json, os, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.join(HERE, '..', '..')
VER = '20261116020000'
OUT = os.path.join(ROOT, 'supabase', 'migrations', f'{VER}_world_2_1_0_tamer.sql')
PARTS = ['a_head.sql', 'b_job.sql', 'c_kinds.sql', 'd_pet.sql', 'e_field.sql', 'f_boss.sql', 'g_exp.sql', 'h_care.sql', 'i_skills.sql', 'j_coop.sql', 'k_create.sql', 'm_quests.sql', 'l_misc.sql']


def avatar_sql():
    parts = open(os.path.join(ROOT, 'supabase', 'gen_avatar', 'parts.json'), encoding='utf-8').read()
    rules = json.loads(parts)
    tops = {k: v for k, v in rules['outfits'].items() if k in ('top:tamer', 'bottom:tamer')}
    if len(tops) != 2: sys.exit('parts.json에 조련사 옷이 없습니다(tools/avatar_art/gen.py).')
    rows = []
    for look, o in sorted(tops.items(), reverse=True):
        iid = 'of_' + look.replace(':', '_')
        rows.append(f"('{iid}', '{o['name']}', 'outfit', 2, '다른 직업의 차림입니다. 「내 모습」 옷장에 넣으면 언제든 골라 입을 수 있습니다.', false, true, 250, 1, '{{\"look\": \"{look}\"}}'::jsonb)")
    return '\n'.join([
        "create or replace function public.world_avatar_parts()\n returns jsonb language sql immutable\nas $f$ select '" + parts.replace("'", "''") + "'::jsonb $f$;",
        "insert into public.world_item_catalog(item_id, item_name, category, tier, description, stackable, tradeable, reference_price, stack_size, equipment_traits) values\n" + ',\n'.join(rows)
        + "\non conflict (item_id) do update set item_name = excluded.item_name, description = excluded.description, equipment_traits = excluded.equipment_traits;",
        "select pg_temp.yh_fix('world_outfit_rules', array[$q$\"of_top_shadow\", \"of_bottom_shadow\"]$q$, $q$\"of_top_shadow\", \"of_bottom_shadow\", \"of_top_tamer\", \"of_bottom_tamer\"]$q$]);",
    ]) + '\n'


def main():
    if subprocess.run([sys.executable, os.path.join(HERE, 'quests.py')]).returncode: sys.exit(1)
    body = []
    for p in PARTS:
        body.append('\n')
        body.append(open(os.path.join(HERE, p), encoding='utf-8').read())
    body.append('\n' + avatar_sql())
    body.append(f"\nupdate public.world_app_meta set value = '{VER}' where key = 'db_version';\n")
    open(OUT, 'w', encoding='utf-8').write(''.join(body).lstrip('\n'))
    print(OUT, sum(len(x) for x in body))


if __name__ == '__main__':
    main()
