import json, re, sys, os

HERE = os.path.dirname(os.path.abspath(__file__))
NPCS = {'hanseol': '한설', 'yeoul': '여울', 'wolha': '월하', 'daon': '다온', 'hisu': '희수', 'danbi': '단비',
        'unbi': '여운비', 'cheongpa': '청파', 'galmae': '갈매', 'haram': '서하람', 'munsu': '문수'}
BY_NAME = {v: k for k, v in NPCS.items()}
KEY = re.compile(r'^### ([a-z][a-z0-9_]*)\b')
LINE = re.compile(r'^- ([^:]{1,8}): (.+)$')
REQUIRED = ['bond_make', 'bond_again', 'bond_break', 'first_dawn', 'first_noon', 'first_dusk', 'first_night',
            'w_clear', 'w_cloudy', 'w_rain', 'w_drizzle', 'w_fog', 'w_wind', 'w_snow', 'w_bloodmist',
            'me_yohwa', 'me_erosion_80', 'me_erosion_55', 'me_erosion_30', 'me_hp_low', 'me_rescued',
            'me_exp_back', 'me_far_travel', 'me_levelup', 'home_portrait', 'home_pet', 'home_new_furn', 'home_mate',
            't_days_7', 't_days_30', 't_days_100', 't_long_away', 't_last_today', 'idle',
            'gift_field', 'gift_hq', 'gift_other', 'gift_reward']


def bundles(lines, who):
    out, cur = [], []
    for ln in lines:
        if not ln.strip():
            continue
        m = LINE.match(ln.strip())
        if not m:
            raise SystemExit(f'형식 밖 줄({who}): {ln[:60]}')
        sp, tx = m.group(1), m.group(2).strip()
        if sp == '서술':
            if cur and any(s for s, _ in cur):
                out.append(cur)
                cur = []
            cur.append(['', tx])
        elif sp == who:
            cur.append([sp, tx])
        else:
            raise SystemExit(f'말하는 이가 다름: {who} / {sp}: {tx[:30]}')
    if cur:
        out.append(cur)
    return out


def parse_npc(k):
    who = NPCS[k]
    txt = open(os.path.join(HERE, f'talk_{k}.md'), encoding='utf-8').read().splitlines()
    keys, key, buf = {}, None, []
    for ln in txt:
        if ln.startswith('## '):
            if key:
                keys[key] = bundles(buf, who)
            key, buf = None, []
            continue
        m = KEY.match(ln)
        if m:
            if key:
                keys[key] = bundles(buf, who)
            key, buf = m.group(1), []
            continue
        if ln.startswith('### '):
            if key:
                keys[key] = bundles(buf, who)
            key, buf = None, []
            continue
        if key:
            buf.append(ln)
    if key:
        keys[key] = bundles(buf, who)
    return keys


def parse_mates():
    txt = open(os.path.join(HERE, 'talk_mates.md'), encoding='utf-8').read().splitlines()
    out, npc, key, buf = {}, None, None, []

    def flush():
        if npc and key:
            out.setdefault(npc, {})[key] = bundles(buf, NPCS[npc])
    for ln in txt:
        if ln.startswith('## '):
            flush()
            npc, key, buf = BY_NAME.get(ln[3:].strip()), None, []
            continue
        m = KEY.match(ln)
        if m:
            flush()
            key, buf = m.group(1), []
            continue
        if key:
            buf.append(ln)
    flush()
    return out


def main():
    talk = {k: parse_npc(k) for k in NPCS}
    for k, d in parse_mates().items():
        talk[k].update(d)
    bad = []
    for k, d in talk.items():
        for r in REQUIRED:
            if not d.get(r):
                bad.append(f'{k}:{r}')
        for o in NPCS:
            if o != k and not d.get('mate_' + o):
                bad.append(f'{k}:mate_{o}')
        for key, bs in d.items():
            for b in bs:
                if not any(s for s, _ in b):
                    bad.append(f'{k}:{key} 대사 없는 묶음')
    if bad:
        raise SystemExit('빠짐: ' + ', '.join(bad))
    json.dump(talk, open(os.path.join(HERE, 'talk.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=0)
    n = sum(len(b) for d in talk.values() for b in d.values())
    print('인물', len(talk), '묶음', n, '키', sorted({x for d in talk.values() for x in d}))


main()
