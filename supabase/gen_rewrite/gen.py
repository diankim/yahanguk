import json, re, sys, os, hashlib

HERE = os.path.dirname(os.path.abspath(__file__))
FACTIONS = {'정통파': 'night_office', '적월': 'red_moon_cult', '흑련': 'black_lotus', '북령': 'north_league',
            '수향': 'river_alliance', '남명': 'southern_remnant', '천명': 'mandate_court'}
PARTS = [('hongin.md', 'hongin_orig.json'), ('yoinrok.md', 'yoinrok_orig.json')]


def tag_keys(tag):
    if '=' in tag:
        k, v = tag.split('=', 1)
        if k in ('job', 'affil'):
            return {k: v}, False
        return None, False
    m = re.match(r'^(\S+) 밖$', tag)
    if m and m.group(1) in FACTIONS:
        return {'fac_not': FACTIONS[m.group(1)], 'spec': 2}, True
    m = re.match(r'^(\S+) (\d)(?:~(\d))?$', tag)
    if m and m.group(1) in FACTIONS:
        return {'fac': FACTIONS[m.group(1)], 'rank': [int(m.group(2)), int(m.group(3) or m.group(2))], 'spec': 0}, True
    if tag in FACTIONS:
        return {'fac': FACTIONS[tag], 'spec': 1}, True
    return None, False


def parse_line(body, errs, where):
    m = re.match(r'^(?:\[([^\]]+)\] )?(.+?): (.+)$', body)
    if not m:
        errs.append(f'{where}: 줄 꼴이 틀림 — {body[:40]}')
        return None, False
    tag, sp, text = m.group(1), m.group(2).strip(), m.group(3).strip()
    if sp == '서술':
        d = {'s': None, 't': text}
    else:
        k = re.match(r'^.+\(([^()]+)\)$', sp)
        if not k:
            errs.append(f'{where}: 말하는이 키 없음 — {sp}')
            return None, False
        d = {'s': k.group(1), 't': text}
    fac = False
    if tag:
        keys, fac = tag_keys(tag)
        if keys is None:
            errs.append(f'{where}: 모르는 갈래 — {tag}')
        else:
            d.update(keys)
    return d, fac


def parse(md, errs):
    chapters = []
    cur = scene = None
    grp = 0
    in_grp = False
    for raw in open(os.path.join(HERE, md), encoding='utf-8').read().splitlines():
        line = raw.rstrip()
        if re.match(r'^# \d+장 「', line):
            cur = {'scenes': {}, 'epilogue': None}
            chapters.append(cur)
            scene = None
            continue
        if cur is None:
            continue
        m = re.match(r'^### 장면 (\d+)', line)
        if m:
            scene = cur['scenes'].setdefault(int(m.group(1)), [])
            grp = 0; in_grp = False
            continue
        if line.startswith('### 결말'):
            cur['epilogue'] = scene = []
            grp = 0; in_grp = False
            continue
        if scene is None:
            continue
        if line.startswith('- (') and line.endswith(')'):
            continue
        if line.startswith('- '):
            body = line[2:]
            if body.startswith('결말: '):
                body = body[4:]
                if body.startswith('('):
                    continue
            d, fac = parse_line(body, errs, f'{md} {len(chapters)}장')
            if d is None:
                continue
            if fac:
                if not in_grp:
                    grp += 1; in_grp = True
                d['grp'] = grp
            else:
                in_grp = False
            scene.append(d)
        elif line.strip():
            in_grp = False
    return chapters


def md5(v):
    return hashlib.md5(json.dumps(v, ensure_ascii=False, sort_keys=True).encode()).hexdigest()


def q(s):
    return "'" + s.replace("'", "''") + "'"


def main():
    errs, out = [], []
    keys_all = set()
    for md, orig in PARTS:
        src = json.load(open(os.path.join(HERE, orig), encoding='utf-8'))
        quests = src if isinstance(src, list) else [dict(qq, steps=[s for s in src['steps'] if s.get('quest_id', qq['quest_id']) == qq['quest_id']]) for qq in src['quests']]
        if isinstance(src, dict) and any('quest_id' not in s for s in src['steps']):
            errs.append(f'{orig}: steps에 quest_id 없음')
        chs = parse(md, errs)
        if len(chs) != len(quests):
            errs.append(f'{md}: 장 {len(chs)} · 원본 퀘스트 {len(quests)}')
            continue
        for qq, ch in zip(quests, chs):
            qid = qq['quest_id']
            steps = {s['step']: s for s in qq['steps']}
            if set(ch['scenes']) != set(steps):
                errs.append(f'{qid}: 장면 번호 {sorted(ch["scenes"])} · 원본 {sorted(steps)}')
                continue
            for k, lines in sorted(ch['scenes'].items()):
                if not lines:
                    errs.append(f'{qid} 장면 {k}: 줄 없음')
                old = {l['s'] for l in steps[k]['lines'] if l.get('s')}
                keys_all |= {l['s'] for l in lines if l.get('s')}
                out.append(f"update public.world_quest_steps set lines = {q(json.dumps(lines, ensure_ascii=False))}::jsonb "
                           f"where quest_id = {q(qid)} and step = {k} and md5(need::text) = md5({q(json.dumps(steps[k]['need'], ensure_ascii=False))}::jsonb::text);")
            ep = ch['epilogue']
            if ep:
                out.append(f"update public.world_quests set epilogue = {q(json.dumps(ep, ensure_ascii=False))}::jsonb where quest_id = {q(qid)};")
            elif qq.get('epilogue'):
                errs.append(f'{qid}: 원본에 결말이 있는데 대본에 없음')
    if errs:
        sys.stderr.write('\n'.join(errs) + '\n')
        sys.exit(1)
    body = out
    print('do $g$ declare n int; begin')
    print("  if (select count(*) from (select npc_key from public.world_quest_npcs union select npc_key from public.world_faction_npcs) n where n.npc_key = any(%s::text[])) <> %d then raise exception '홍인사·요인록 대본: 없는 말하는이 키'; end if;" % (q('{' + ','.join(sorted(keys_all)) + '}'), len(keys_all)))
    print('end $g$;')
    for l in body:
        if l.startswith('update public.world_quest_steps'):
            print('do $u$ declare n int; begin ' + l + ' get diagnostics n = row_count; if n <> 1 then raise exception \'대본을 넣을 장면이 원본과 다름: %\', ' + q(l.split("where ")[1][:60]) + '; end if; end $u$;')
        else:
            print(l)
    sys.stderr.write(f'장면 {sum(1 for l in body if "world_quest_steps" in l)} · 결말 {sum(1 for l in body if "world_quests set" in l)} · 말하는이 {len(keys_all)}\n')


main()
