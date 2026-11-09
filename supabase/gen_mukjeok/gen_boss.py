import json
import re
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE.parents[0] / 'migrations' / '20261116010000_world_2_0_0_boss.sql'


def memories():
    frags = []
    for line in json.loads((HERE / 'ref' / 'mj_fight_lines.json').read_text(encoding='utf-8')):
        m = re.match(r'^\d+\.\s*기억 조각:\s*(.+)$', line)
        if m:
            frags.append(['기억 조각 — ' + m.group(1)])
            continue
        m = re.match(r'^-\s*([^:]+):\s*(.+)$', line)
        if not m or not frags:
            raise SystemExit(f'모르는 줄: {line}')
        who, text = m.group(1).strip(), m.group(2).strip()
        frags[-1].append(text if who == '서술' else f'{who}: {text}')
    if len(frags) != 6:
        raise SystemExit(f'기억 조각이 여섯이 아닙니다: {len(frags)}')
    return json.dumps(frags, ensure_ascii=False).replace("'", "''")


src = (HERE / 'boss.sql').read_text(encoding='utf-8').replace('__MK_MEMORIES__', memories())
OUT.write_text(src.rstrip() + "\n\nupdate public.world_app_meta set value = '20261116010000' where key = 'db_version';\n", encoding='utf-8')
print(OUT.name)
