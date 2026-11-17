import importlib.util as _iu
import math
import os
import sys

HERE = os.path.dirname(os.path.abspath(__file__))
_sp = _iu.spec_from_file_location('pj_data', os.path.join(HERE, 'data.py'))
D = _iu.module_from_spec(_sp)
_sp.loader.exec_module(D)

MEMBERS = {
    'night_office': [39, 37, 37, 35, 28, 26, 24, 12, 12, 11, 9],
    'mandate_court': [40, 38, 38, 33],
    'river_alliance': [40, 36, 33, 26],
    'southern_remnant': [40, 39, 36],
    'black_lotus': [40, 39, 37],
    'red_moon_cult': [40, 40, 30],
    'north_league': [33],
}
COMMON = {'c:gwiheo': (19, 30), 'c:mukjeok': (12, 40), 'c:deungdo': (8, 45)}
F_STAGE_LV = [1, 8, 14, 20, 25]
C_STAGE_LV = [0, 1, 2, 3, 4]
SHOW = float(sys.argv[1]) if len(sys.argv) > 1 else 0.6
RATES = {'faction': (900, 1200, 1500), 'common': (1800, 2500, 3200)}


def per_day(rate, cap, fit):
    return min(cap, rate * fit)


def faction_rows():
    cap = D.PAY['faction']['day_cap']
    out = []
    for fac, lv in MEMBERS.items():
        n = len(lv)
        row = [fac, n]
        for i, base in enumerate(D.F_BASE):
            goal = base * max(1, math.sqrt(n))
            days = []
            for rate in RATES['faction']:
                daily = sum(per_day(rate, cap, 1 if l >= F_STAGE_LV[i] else 0.5) for l in lv) * SHOW
                days.append(goal / daily)
            row.append((round(goal), days))
        out.append(row)
    return out


def common_rows():
    cap = D.PAY['common']['day_cap']
    out = []
    for k, (n, lv) in COMMON.items():
        givers = max(1, round(n * 2 / 3))
        row = [k, n, givers]
        for base in D.C_BASE:
            goal = base * max(1, math.sqrt(n))
            days = [goal / (min(cap, rate) * givers * SHOW) for rate in RATES['common']]
            row.append((round(goal), days))
        out.append(row)
    return out


def fmt(d):
    return f"{d[0]:.1f}~{d[2]:.1f}"


if __name__ == '__main__':
    print(f'하루 넘기는 사람 비율 {SHOW} · 세력 1인 하루 {RATES["faction"]}몫(상한 {D.PAY["faction"]["day_cap"]}) · 공동 1인 하루 {RATES["common"]}몫(상한 {D.PAY["common"]["day_cap"]})')
    print()
    print('| 세력 | 인원 | ' + ' | '.join(f'{i + 1}단계 목표 · 날' for i in range(5)) + ' | 다섯 단계 합 |')
    print('|---|---|' + '---|' * 6)
    for r in faction_rows():
        tot = [sum(x[1][j] for x in r[2:]) for j in range(3)]
        print(f'| {r[0]} | {r[1]} | ' + ' | '.join(f'{g:,} · {fmt(d)}' for g, d in r[2:]) + f' | {fmt(tot)} |')
    print()
    print('| 공동 | 땅 열린 사람 | 넘기는 사람 | ' + ' | '.join(f'{i + 1}단계 목표 · 날' for i in range(5)) + ' | 다섯 단계 합 |')
    print('|---|---|---|' + '---|' * 6)
    for r in common_rows():
        tot = [sum(x[1][j] for x in r[3:]) for j in range(3)]
        print(f'| {r[0]} | {r[1]} | {r[2]} | ' + ' | '.join(f'{g:,} · {fmt(d)}' for g, d in r[3:]) + f' | {fmt(tot)} |')
