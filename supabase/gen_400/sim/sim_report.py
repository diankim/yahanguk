import json, sys, collections

def key(d):
    if d.get('kind') == 'raid':
        return ('raid', d['boss'], d['pol'], 'n%d' % d['n'], '')
    o = d.get('opt') or {}
    ex = ' '.join('%s=%s' % (k, o[k]) for k in sorted(o) if k in ('hold', 'tier', 'enh', 'start', 'start2'))
    return (d['mode'], d['boss'], d['pol'], ','.join(d['jobs']), ex)

def bot_miss(d):
    if d.get('kind') == 'raid':
        m = (d.get('info') or {}).get('miss') or {}
        return sum(m.get(k, 0) for k in ('regrow', 'burst', 'core', 'stiff', 'ebb', 'alone'))
    n = d.get('notes') or {}
    return max(0, d.get('mech', 0) - d.get('head_phase', 0) - n.get('pull_forced', 0))

rows = collections.OrderedDict()
errs = []
for path in sys.argv[1:]:
    for line in open(path):
        line = line.strip()
        if not line:
            continue
        d = json.loads(line)
        if 'err' in d:
            errs.append(d); continue
        rows.setdefault(key(d), []).append(d)

hdr = ['판', '보스', '정책', '조합', '옵션', '판수', '승', '승률', '평균 라운드/분', '봇 놓침(합)', '놓침 판', '약화(합)', '낙사/쓰러짐', '돌주먹', '머리 옮김', '끌개 못 막는 칸', '기여(평균 %)']
print('| ' + ' | '.join(hdr) + ' |')
print('|' + '---|' * len(hdr))
for k, ds in rows.items():
    n = len(ds); w = sum(1 for d in ds if d.get('won'))
    if k[0] == 'raid':
        t = sum(float(d['secs']) for d in ds) / n / 60
        tl = '%.1f분' % t
        fell = sum(d.get('falls') or 0 for d in ds)
        weak = fist = hp = pf = '-'
        sh = collections.defaultdict(list)
        for d in ds:
            for j, v in ((d.get('info') or {}).get('shares') or {}).items():
                sh[j].append(float(v))
    else:
        tl = '%.0f' % (sum(d['round'] for d in ds) / n)
        fell = '%d/%d' % (sum(d.get('fell') or 0 for d in ds), sum(d.get('falls') or 0 for d in ds))
        weak = sum(d.get('weak') or 0 for d in ds); fist = sum(d.get('fist') or 0 for d in ds)
        hp = sum(d.get('head_phase') or 0 for d in ds); pf = sum((d.get('notes') or {}).get('pull_forced', 0) for d in ds)
        sh = collections.defaultdict(list)
        for d in ds:
            for j, v in (d.get('shares') or {}).items():
                sh[j].append(float(v))
    bm = [bot_miss(d) for d in ds]
    share = ' '.join('%s %.0f' % (j, sum(v) / len(v)) for j, v in sorted(sh.items())) or '-'
    print('| ' + ' | '.join(str(x) for x in [k[0], k[1], k[2], k[3], k[4] or '-', n, w, '%d%%' % round(100 * w / n), tl, sum(bm), sum(1 for x in bm if x), weak, fell, fist, hp, pf, share]) + ' |')
if errs:
    print('\n실행 오류 %d판:' % len(errs))
    for e in errs[:20]:
        print('-', e['err'], '::', (e.get('msg') or '').replace('\n', ' ')[:200])
print('\n봇 놓침: 정석(perfect)·best 정책이면 0이어야 함. 0이 아니면 결과를 쓰기 전에 그 판 기록을 본다.')
