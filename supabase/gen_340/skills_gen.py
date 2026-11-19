import json, os
from skills_data import LINES

HERE = os.path.dirname(os.path.abspath(__file__))


def T(s):
    return "'" + s.replace("'", "''") + "'"


rows = []
for line, (nm, cat, base, choices, master) in LINES.items():
    for r, name, fx, desc in base:
        rows.append(f"({T(f'{line}_t{r}')}, {T(name)}, {T(line)}, {T(desc)}, {T(json.dumps(fx))}::jsonb, {r}, 'base')")
    for r, a, b in choices:
        for slot, (n, grp, d) in (('a', a), ('b', b)):
            rows.append(f"({T(f'{line}_c{r}{slot}')}, {T(n)}, {T(line)}, {T(f'택일 기술({grp}) · {d}')}, '{{}}'::jsonb, {r}, {T(slot)})")
    rows.append(f"({T(f'{line}_m50')}, {T(master[0])}, {T(line)}, {T('숙달 기술 · ' + master[1])}, '{{}}'::jsonb, 50, 'master')")
sql = ("insert into public.world_skill_catalog(skill_id, skill_name, category, description, passive_effect, unlock_rank, slot) values\n" + ",\n".join(rows)
       + "\non conflict (skill_id) do update set skill_name = excluded.skill_name, description = excluded.description, passive_effect = excluded.passive_effect, unlock_rank = excluded.unlock_rank, slot = excluded.slot;\n")
tail = open(os.path.join(HERE, 'sql', 'f_skills.sql')).read().split('\nselect pg_temp.yh_fix', 1)[1]
open(os.path.join(HERE, 'sql', 'f_skills.sql'), 'w').write(sql + '\nselect pg_temp.yh_fix' + tail)
print(len(rows))
