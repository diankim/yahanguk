import re, json
src = open('supabase/gen_side110/yoinrok_review.md', encoding='utf-8').read()
SP = {'서술': None, '여울': 'q:g_yeoul', '묵호': 'q:g_mukho', '사공': 'q:g_sagong', '단이': 'q:g_dani', '주지': 'q:g_juji', '주인': 'q:g_lord', '기억 조각': 'q:g_memory'}
chap = 0; step = 0; out = {}
for line in src.split('\n'):
    m = re.match(r'^# (\d)장 ', line)
    if m: chap = int(m.group(1)); step = 0; continue
    m = re.match(r'^### 장면 (\d)', line)
    if m and chap: step = int(m.group(1)); out[(chap, step)] = []; continue
    m = re.match(r'^- ([^:]+): (.+)$', line)
    if m and chap and step:
        who, text = m.group(1), m.group(2).strip()
        if who == '할 일': continue
        assert who in SP, (chap, step, who)
        out[(chap, step)].append({'s': SP[who], 't': text})
assert sorted(out) == [(c, s) for c in range(1, 6) for s in range(1, 5 if c < 5 else 4)], sorted(out)
for k, v in out.items(): assert v, k
sql = []
for (c, s), lines in sorted(out.items()):
    j = json.dumps(lines, ensure_ascii=False).replace("'", "''")
    sql.append(f"update public.world_quest_steps set lines = '{j}'::jsonb where quest_id = 'gq_{c}' and step = {s};")
sql.append("update public.world_app_meta set value = '20261108120000' where key = 'db_version';")
open('supabase/migrations/20261108120000_world_1_1_0c_yoinrok_lines.sql', 'w', encoding='utf-8').write('\n'.join(sql) + '\n')
print({f'{c}-{s}': len(v) for (c, s), v in sorted(out.items())})
