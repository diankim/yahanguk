import re, json, sys
from pathlib import Path

SRC = Path(__file__).with_name('yoinrok_review.md')
SP = {'서술': None, '여울': 'q:g_yeoul', '묵호': 'q:g_mukho', '사공': 'q:g_sagong', '단이': 'q:g_dani', '주지': 'q:g_juji', '주인': 'q:g_lord', '기억 조각': 'q:g_memory'}


def scenes():
    chap = step = 0
    out = {}
    for line in SRC.read_text(encoding='utf-8').split('\n'):
        m = re.match(r'^# (\d)장 ', line)
        if m:
            chap, step = int(m.group(1)), 0
            continue
        m = re.match(r'^### 장면 (\d)', line)
        if m and chap:
            step = int(m.group(1))
            out[(chap, step)] = []
            continue
        m = re.match(r'^- ([^:]+): (.+)$', line)
        if m and chap and step:
            who, text = m.group(1), m.group(2).strip()
            if who == '할 일':
                continue
            assert who in SP, (chap, step, who)
            out[(chap, step)].append({'s': SP[who], 't': text})
    assert sorted(out) == [(c, s) for c in range(1, 6) for s in range(1, 5 if c < 5 else 4)], sorted(out)
    for k, v in out.items():
        assert v, k
    return out


def sql():
    rows = []
    for (c, s), lines in sorted(scenes().items()):
        j = json.dumps(lines, ensure_ascii=False).replace("'", "''")
        rows.append(f"update public.world_quest_steps set lines = '{j}'::jsonb where quest_id = 'gq_{c}' and step = {s};")
    return '\n'.join(rows) + '\n'


if __name__ == '__main__':
    out = sql()
    if len(sys.argv) > 2 and sys.argv[1] == '--check':
        body = Path(sys.argv[2]).read_text(encoding='utf-8')
        print('같음' if out in body else '다름')
        sys.exit(0 if out in body else 1)
    sys.stdout.write(out)
